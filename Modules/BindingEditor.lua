local Bars = BootyActionBars
local UI = Bars.UI.Components
local BindingEditor = {}
Bars.Modules.BindingEditor = BindingEditor
local state = {editing = false, active = false, confirming = false, dirty = false, pendingCount = 0,
    conflictCount = 0, preview = "", message = "Bindings are unchanged until Save."}
local service, capture, confirmation, selectedButton, observer, windowOwner
local Notify, CaptureKeys, EndMode

local function Run(callback, first, second, third)
    local previousThis, previousEvent, previousArg = this, event, arg1
    local ran, result, reason = pcall(callback, first, second, third)
    this, event, arg1 = previousThis, previousEvent, previousArg
    if not ran then return false, tostring(result) end
    if result == false then return false, reason end
    return true
end
local function Failure(reason)
    state.failure, state.message = tostring(reason), tostring(reason)
    if observer then Run(observer, state) end
    return false, reason
end
local function Summary()
    if service then
        local current = service.GetState()
        state.pendingCount, state.conflictCount = current.changedCount, current.conflictCount
        state.dirty, state.preview = current.changedCount > 0, service.GetPreview()
    end
    local command = state.command or state.lastCommand
    if command and service and state.editing then
        local ok, first, second = service.GetKeys(command)
        if not ok then return false, first end
        state.firstKey, state.secondKey = first, second
    else state.firstKey, state.secondKey = nil, nil end
    return true
end
Notify = function()
    local ok, failure = Summary()
    if not ok then return Failure(failure) end
    if capture and capture.label then
        local label = state.command and ((state.barId == 7 and "Pet" or state.barId == 8 and "Form" or "Bar " .. state.barId)
            .. ", button " .. state.index) or "Click a button or choose it in the panel"
        capture.label:SetText("Keybindings: " .. label .. ". Press a key; Escape clears. Save / Cancel in /bab.")
    end
    if observer then
        ok, failure = Run(observer, state)
        if not ok then return Failure(failure) end
    end
    return true
end
local function RefreshVisibility()
    local engine = Bars.Core.Engine.GetState()
    local editor = Bars.Modules.Editor
    local layoutEditing = editor and editor.IsEditing and editor.IsEditing() or false
    local firstFailure
    for _, view in pairs(engine.views or {}) do
        if view.SetEditing then
            local ok, failure = Run(view.SetEditing, view, layoutEditing)
            if not ok and not firstFailure then firstFailure = failure end
        end
    end
    local special = Bars.Modules.SpecialBars
    if special and special.RefreshButtonVisibility then
        local ok, failure = Run(special.RefreshButtonVisibility)
        if not ok and not firstFailure then firstFailure = failure end
    end
    return firstFailure == nil, firstFailure
end
local function CancelInput()
    local firstFailure
    local engine = Bars.Core.Engine.GetState()
    for _, view in pairs(engine.views or {}) do
        if view.CancelInput then
            local ok, failure = Run(view.CancelInput, view)
            if not ok and not firstFailure then firstFailure = failure end
        end
    end
    local special = Bars.Modules.SpecialBars
    if special and special.GetView then
        for id = 7, 8 do
            local view = special.GetView(id)
            if view and view.CancelInput then
                local ok, failure = Run(view.CancelInput, view)
                if not ok and not firstFailure then firstFailure = failure end
            end
        end
    end
    return firstFailure == nil, firstFailure
end
function BindingEditor.GetDraftKey(command, nativeKey)
    if state.editing and service then
        local known, first, second = service.GetDraftKeys(command)
        if known then return first, second, true end
    end
    return nativeKey, nil, false
end
function BindingEditor.RefreshDraft(saved)
    local firstFailure
    local engine = Bars.Core.Engine.GetState()
    for _, view in pairs(engine.views or {}) do
        if view.RefreshBindingDraft then
            local ok, reason = Run(view.RefreshBindingDraft, view, saved)
            if not ok and not firstFailure then firstFailure = reason end
        end
    end
    local special = Bars.Modules.SpecialBars
    if special and special.GetView then
        for id = 7, 8 do
            local view = special.GetView(id)
            if view and view.RefreshBindingDraft then
                local ok, reason = Run(view.RefreshBindingDraft, view, saved)
                if not ok and not firstFailure then firstFailure = reason end
            end
        end
    end
    return firstFailure == nil, firstFailure
end
local function SelectedFeedback(button, selected)
    if not button then return true end
    local firstFailure
    button.bindingSelected = selected == true
    if button.bar and button.bar.SetBindingSelected then
        local ok, reason = Run(button.bar.SetBindingSelected, button.bar, button.index, selected)
        if not ok then firstFailure = reason end
    elseif button.pressFeedback then
        local ok, reason = Run(selected and button.pressFeedback.Show or button.pressFeedback.Hide, button.pressFeedback)
        if not ok then firstFailure = reason end
    end
    local callback = selected and button.LockHighlight or button.UnlockHighlight
    if callback then
        local ok, reason = Run(callback, button)
        if not ok and not firstFailure then firstFailure = reason end
    end
    return firstFailure == nil, firstFailure
end
local function Deselect()
    if state.command then state.lastCommand = state.command end
    state.command, state.armed = nil, false
    local ok, failure = SelectedFeedback(selectedButton, false)
    if ok then selectedButton = nil end
    return ok, failure
end
local function Choose(barId, index, button)
    if not state.editing or state.confirming then return false, "Begin binding mode before choosing a button." end
    local command = Bars.Services.BindingService.Command(barId, index)
    if not command then return Failure("Choose a known bar and a valid button index.") end
    local ok, reason = Deselect()
    if not ok then return Failure(reason) end
    state.barId, state.index, state.command, state.armed = barId, index, command, true
    selectedButton = button
    ok, reason = SelectedFeedback(button, true)
    if not ok then return Failure(reason) end
    state.failure, state.message = nil, "Button selected. Press its next key; the draft is shown immediately."
    return Notify()
end
local function KeyDownBody()
    local key = arg1
    if not state.editing or state.confirming then return end
    if key == "ESCAPE" then BindingEditor.ClearSelection(); return end
    if type(key) ~= "string" or key == "UNKNOWN" or key == "SHIFT" or key == "CTRL" or key == "ALT"
        or key == "LSHIFT" or key == "RSHIFT" or key == "LCTRL" or key == "RCTRL" or key == "LALT" or key == "RALT" then return end
    -- Match the canonical stock 1.12 modifier prefix order.
    local shift = type(IsShiftKeyDown) == "function" and IsShiftKeyDown()
    local control = type(IsControlKeyDown) == "function" and IsControlKeyDown()
    local alt = type(IsAltKeyDown) == "function" and IsAltKeyDown()
    if shift and shift ~= 0 then key = "SHIFT-" .. key end
    if control and control ~= 0 then key = "CTRL-" .. key end
    if alt and alt ~= 0 then key = "ALT-" .. key end
    BindingEditor.StageKey(key)
end
local function KeyDown()
    local ok, failure = Run(KeyDownBody)
    if not ok then Failure(failure) end
end
local function CreateCapture()
    if capture and capture.ready then return true end
    if not capture then capture = UI.CreateContainer("BootyActionBarsBindingCapture", UIParent) end
    capture:SetAllPoints(UIParent); capture:SetFrameStrata("FULLSCREEN_DIALOG")
    capture:EnableMouse(false); capture:EnableKeyboard(false)
    if not capture.label then capture.label = UI.CreateComponentLabel(capture, "", "white") end
    capture.label:SetPoint("TOP", UIParent, "TOP", 0, -36)
    capture.label:SetWidth(760); capture.label:SetHeight(36)
    capture:Hide()
    capture.ready = true
    return true
end
CaptureKeys = function(enabled)
    if not capture then return true end
    if not enabled then
        -- A failing client setter must not keep the remaining input resources
        -- alive. Each cleanup is attempted, and the original failure survives.
        local ok, firstFailure = Run(capture.EnableKeyboard, capture, false)
        local detached, reason = Run(capture.SetScript, capture, "OnKeyDown", nil)
        if not detached and not firstFailure then firstFailure = reason end
        local hidden, hideFailure = Run(capture.Hide, capture)
        if not hidden and not firstFailure then firstFailure = hideFailure end
        return firstFailure == nil, firstFailure
    end
    capture:EnableKeyboard(enabled)
    capture:SetScript("OnKeyDown", enabled and KeyDown or nil)
    if enabled then capture:Show() else capture:Hide() end
    return true
end
function BindingEditor.SetObserver(callback) observer = callback end
function BindingEditor.IsEditing() return state.editing end
BindingEditor.IsActive = BindingEditor.IsEditing
function BindingEditor.GetState() return state end
function BindingEditor.Begin(owner)
    if owner then windowOwner = owner end
    if state.editing then return true end
    if not service then service = Bars.Services.BindingService.Create() end
    local ok, failure = service.Begin()
    if not ok then return Failure(failure) end
    ok, failure = Run(CreateCapture)
    if ok then ok, failure = CancelInput() end
    if not ok then service.Cancel(); return Failure(failure) end
    state.editing, state.active, state.confirming, state.failure = true, true, false, nil
    ok, failure = Run(CaptureKeys, true)
    if ok then ok, failure = RefreshVisibility() end
    if not ok then BindingEditor.Cancel(); return Failure(failure) end
    ok, failure = BindingEditor.RefreshDraft(false)
    if not ok then BindingEditor.Cancel(); return Failure(failure) end
    state.lastCommand, state.armed = nil, false
    state.message = "Click a button or select its bar/index, then press a key. Save applies staged bindings."
    ok, failure = Run(Notify)
    if not ok then BindingEditor.Cancel(); return Failure(failure) end
    return true
end
function BindingEditor.SetSelection(barId, index)
    local view
    if barId == 7 or barId == 8 then
        local special = Bars.Modules.SpecialBars
        view = special and special.GetView and special.GetView(barId)
    else view = Bars.Core.Engine.GetState().views[barId] end
    return Choose(barId, index, view and view.buttons and view.buttons[index])
end
function BindingEditor.SelectButton(button, barId, index)
    if not state.editing or state.confirming then return false end
    if selectedButton == button and state.barId == barId and state.index == index then return true end
    return Choose(barId, index, button)
end
function BindingEditor.StageKey(key)
    if not state.editing or state.confirming or not state.command then return Failure("Select a button before pressing a key.") end
    local ok, failure = service.StageKey(state.command, key)
    if not ok then return Failure(failure) end
    ok, failure = Deselect()
    local summarized, summaryFailure = Summary()
    local refreshed, reason = BindingEditor.RefreshDraft(false)
    if not ok or not summarized or not refreshed then return Failure(failure or summaryFailure or reason) end
    state.failure, state.message = nil, "Key staged. Save applies it; Cancel leaves client bindings unchanged."
    return Notify()
end
function BindingEditor.ClearSelection()
    if not state.editing or state.confirming or not state.command then return Failure("Select a button before clearing its keys.") end
    local ok, failure = service.Clear(state.command)
    if not ok then return Failure(failure) end
    ok, failure = Deselect()
    local summarized, summaryFailure = Summary()
    local refreshed, reason = BindingEditor.RefreshDraft(false)
    if not ok or not summarized or not refreshed then return Failure(failure or summaryFailure or reason) end
    state.failure, state.message = nil, "Selected button keys cleared in the preview. Save applies this change."
    return Notify()
end
EndMode = function(saved)
    state.editing, state.active, state.confirming = false, false, false
    local ok, failure = Run(CaptureKeys, false)
    if confirmation then
        local hidden, reason = Run(confirmation.Hide, confirmation)
        if not hidden and not failure then failure = reason end
    end
    local deselected, selectionFailure = Deselect()
    if not deselected and not failure then failure = selectionFailure end
    if service then service.Cancel() end
    state.command, state.lastCommand, state.barId, state.index = nil, nil, nil, nil
    local drafted, draftFailure = BindingEditor.RefreshDraft(saved)
    if not drafted and not failure then failure = draftFailure end
    local visible, reason = RefreshVisibility()
    if not visible and not failure then failure = reason end
    local input, inputFailure = CancelInput()
    if not input and not failure then failure = inputFailure end
    state.message = saved and "Bindings saved." or "Binding changes cancelled; client keys are unchanged."
    if not failure then state.failure = nil end
    local notified, notifyFailure = Run(Notify)
    if not notified and not failure then failure = notifyFailure end
    if failure then return Failure(failure) end
    return ok
end
function BindingEditor.Cancel() return EndMode(false) end
BindingEditor.End = BindingEditor.Cancel
local function ApplySave()
    if not state.editing then return false, "Binding mode closed before saving." end
    local ok, failure = service.Commit(true)
    if not ok then CaptureKeys(state.editing); return Failure(failure) end
    return EndMode(true)
end
local function ConfirmSave()
    if not state.editing or not state.reviewRevision or service.GetState().revision ~= state.reviewRevision then
        CaptureKeys(state.editing); return Failure("The preview changed. Review bindings again before saving.")
    end
    return ApplySave()
end
local function CreateConfirmation()
    if confirmation then return true end
    confirmation = UI.Window.CreateProjectConfirmation("BootyActionBarsBindingConfirmation", "Replace existing keybindings", "Replace / Save", "link")
    confirmation:SetWidth(520)
    local originalHide = confirmation:GetScript("OnHide")
    confirmation:SetScript("OnHide", function()
        if originalHide then originalHide() end
        state.confirming = false
        if state.editing then CaptureKeys(true); Notify() end
    end)
    return true
end
function BindingEditor.Save()
    if not state.editing or state.confirming then return false, "Binding editing is inactive or awaiting confirmation." end
    local current = service.GetState()
    if current.conflictCount == 0 then return ApplySave() end
    if current.conflictCount > 8 then return Failure("Save a smaller batch: at most eight foreign key conflicts can be reviewed at once.") end
    local ok, failure = Run(CreateConfirmation)
    if not ok then return Failure(failure) end
    if windowOwner and UI.WindowStack then
        ok, failure = Run(UI.WindowStack.SetOwner, confirmation, windowOwner)
        if not ok then return Failure(failure) end
    end
    state.reviewRevision, state.confirming = current.revision, true
    ok, failure = Run(CaptureKeys, false)
    if not ok then state.confirming = false; return Failure(failure) end
    local message = "These keys replace existing commands. Other keys are retained.\n\n" .. service.GetConflictPreview()
    ok, failure = Run(confirmation.Open, confirmation, message, ConfirmSave)
    if not ok then state.confirming = false; CaptureKeys(true); return Failure(failure) end
    Notify()
    return true, "confirmation"
end
