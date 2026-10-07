local Bars = BootyActionBars
local UI = Bars.UI.Components
local Keybindings = {}
Bars.Modules.KeybindingSettings = Keybindings

function Keybindings.Create(parent, host, ownerView)
    local frame = UI.CreateContainer(nil, parent)
    frame:SetAllPoints(parent)
    local page = UI.CreateResponsiveCanvas(frame, "BootyActionBarsKeybindingsScroll")
    local view = {frame = frame, canvas = page}
    ownerView.bindingSelectedBar = ownerView.bindingSelectedBar or ownerView.selectedBar or 2
    ownerView.bindingIndex = ownerView.bindingIndex or 1
    local function Complete(ok, failure)
        if ownerView.Complete then return ownerView.Complete(ok, failure) end
        if not ok and failure then host.Print(failure) end
        view:Refresh()
        return ok, failure
    end
    local title = UI.CreateHeading(page, "Keybindings", 2, "gold")
    local help = UI.CreateComponentLabel(page,
        "Assign keys, then click an action button or choose its bar and number below. Press a key to stage it. Select the next button before assigning another key. Save applies the draft; Cancel keeps the current bindings.", "white")
    help:SetJustifyH("LEFT"); help:SetJustifyV("TOP")
    local choiceOwner = UI.CreateContainer(nil, page)
    choiceOwner:SetWidth(300); choiceOwner:SetHeight(26)
    local choices = {}
    for id = 1, 6 do
        choices[id] = {value = id, text = id == 1 and "Main bar (pages/forms)"
            or "Bar " .. id .. " (slots " .. ((id - 1) * 12 + 1) .. "-" .. (id * 12) .. ")"}
    end
    choices[7], choices[8] = {value = 7, text = "Pet bar"}, {value = 8, text = "Forms / stances"}
    local function Select()
        local editor = Bars.Modules.BindingEditor
        if editor and editor.IsEditing() and not editor.GetState().confirming then
            return Complete(editor.SetSelection(ownerView.bindingSelectedBar, ownerView.bindingIndex))
        end
        view:Refresh()
        return true
    end
    local _, choice = UI.CreateChoiceField({parent = choiceOwner, x = 0, y = 0,
        label = "Bar", initialText = choices[ownerView.bindingSelectedBar].text,
        width = 220, height = 186, firstY = -7, step = 20, buttonOffset = 40,
        labelValue = true, choices = choices,
        getValue = function() return ownerView.bindingSelectedBar end,
        onSelect = function(value)
            ownerView.bindingSelectedBar = value
            ownerView.bindingIndex = math.min(ownerView.bindingIndex, value >= 7 and 10 or 12)
            Select()
        end,
        onChanged = function() view:Refresh() end,
    })
    local indexOwner = UI.CreateContainer(nil, page)
    indexOwner:SetWidth(180); indexOwner:SetHeight(52)
    local index = UI.Settings.CreateSlider(indexOwner, "BootyActionBarsBindingIndex", 0, -18,
        "Button", "index", 1, 12, nil, {
            ensure = function() end,
            get = function() return ownerView.bindingIndex end,
            set = function(_, value) ownerView.bindingIndex = value; Select() end,
        })
    index:SetWidth(180)
    local function Action(text, width)
        local button = UI.CreateButton(page, nil, text, width, 24)
        UI.StyleActionButton(button); button.mosFlowWidth = width
        return button
    end
    local bind, save = Action("Assign keys", 104), Action("Save keys", 88)
    local cancel, clear = Action("Cancel", 72), Action("Clear button", 104)
    bind:SetScript("OnClick", function() Complete(Bars.Core.Runtime.SetBindingEditing(true)) end)
    save:SetScript("OnClick", function()
        local editor = Bars.Modules.BindingEditor
        if editor then Complete(editor.Save()) end
    end)
    cancel:SetScript("OnClick", function()
        local editor = Bars.Modules.BindingEditor
        if editor then Complete(editor.Cancel()) end
    end)
    clear:SetScript("OnClick", function()
        local editor = Bars.Modules.BindingEditor
        local state = editor and editor.GetState()
        if state and state.editing and state.armed and not state.confirming then Complete(editor.ClearSelection()) end
    end)
    local statusHeading = UI.CreateHeading(page, "Binding draft", 3, "gold")
    local status = UI.CreateComponentLabel(page, "", "white")
    status:SetJustifyH("LEFT"); status:SetJustifyV("TOP")
    ownerView.bindingBarChoice, ownerView.bindingIndexSlider = choice, index
    ownerView.bindingButton, ownerView.bindingSaveButton, ownerView.bindingCancelButton = bind, save, cancel
    ownerView.bindingClearButton, ownerView.bindingStatus = clear, status
    local actions = {bind, save, cancel, clear}
    local function Position(control, top, width, height)
        control:ClearAllPoints(); control:SetPoint("TOPLEFT", page, "TOPLEFT", 16, -top)
        control:SetWidth(width); control:SetHeight(height)
        return top + height
    end
    local function Measure(available)
        local width = math.max(1, available - 32)
        local top = Position(title, 16, width, 24) + 12
        top = Position(help, top, width, UI.MeasureTextHeight(help, width)) + 20
        top = Position(choiceOwner, top, width, 26) + 14
        choice:SetWidth(math.max(1, math.min(220, width - 40)))
        top = Position(indexOwner, top, math.min(180, width), 52) + 12
        index:SetWidth(math.min(180, width))
        top = UI.LayoutFlow(page, actions, 16, top, width, 8) + 24
        top = Position(statusHeading, top, width, 20) + 8
        view.contentHeight = Position(status, top, width, UI.MeasureTextHeight(status, width)) + 16
        return view.contentHeight
    end
    function view:Layout(width, height)
        if not frame:IsVisible() then return end
        if not width or not height then width, height = UI.GetFrameSpan(parent) end
        width, height = math.max(1, width), math.max(1, height)
        self.width, self.height = width, height
        frame:SetWidth(width); frame:SetHeight(height)
        UI.LayoutResponsiveCanvas(page, Measure, nil, width, height)
    end
    function view:Refresh()
        if not frame:IsVisible() then return end
        local editor = Bars.Modules.BindingEditor
        local state = editor and editor.GetState()
        local active = editor and editor.IsEditing() or false
        local confirming = state and state.confirming == true
        if active and state and state.barId then
            ownerView.bindingSelectedBar, ownerView.bindingIndex = state.barId, state.index or ownerView.bindingIndex
        end
        local maximum = ownerView.bindingSelectedBar >= 7 and 10 or 12
        ownerView.bindingIndex = math.min(ownerView.bindingIndex, maximum)
        local synchronizing = index.mosSynchronizing
        index.mosSynchronizing = true; index:SetMinMaxValues(1, maximum); index.mosSynchronizing = synchronizing
        getglobal("BootyActionBarsBindingIndexHigh"):SetText(tostring(maximum))
        UI.Settings.SynchronizeSlider(index, ownerView.bindingIndex)
        choice.label:SetText(choices[ownerView.bindingSelectedBar].text)
        UI.SetButtonEnabled(choice, editor ~= nil and not confirming)
        UI.Settings.SetSliderEnabled(index, editor ~= nil and not confirming)
        UI.SetButtonEnabled(bind, Bars.Core.Runtime.IsAvailable() and editor ~= nil and not active)
        UI.SetButtonEnabled(save, active and not confirming)
        UI.SetButtonEnabled(cancel, active)
        UI.SetButtonEnabled(clear, active and state and state.armed == true and not confirming)
        local text = "Choose Assign keys to start. Client bindings remain unchanged until Save."
        if active and state then
            local selected = state.barId and ((state.barId == 7 and "Pet" or state.barId == 8 and "Form" or "Bar " .. state.barId)
                .. ", button " .. tostring(state.index or "?") .. ": " .. (state.firstKey or "unassigned")
                .. (state.secondKey and " / " .. state.secondKey or "") .. ". ") or ""
            text = selected .. tostring(state.pendingCount or 0) .. " pending changes. "
                .. tostring(state.conflictCount or 0) .. " conflicts. "
                .. (state.message or "Select a button, then press a key.")
        elseif state and state.failure then text = "Keybindings: " .. tostring(state.failure)
        elseif state and state.message then text = state.message end
        if self.lastText ~= text then self.lastText = text; status:SetText(text) end
        self:Layout(self.width, self.height)
    end
    view.RefreshBindings = view.Refresh
    local function Cleanup()
        choice.panel:Hide()
        local editor = Bars.Modules.BindingEditor
        if editor and editor.IsEditing() then
            local ok, failure = editor.Cancel()
            if not ok and failure then host.Print(failure) end
            return ok, failure
        end
        return true
    end
    frame:SetScript("OnHide", Cleanup)
    function view:Show()
        if not Bars.Core.Runtime.IsAvailable() then return false end
        frame:Show(); self:Refresh(); return true
    end
    function view:Hide()
        local ok, failure = Cleanup()
        frame:Hide()
        return ok, failure
    end
    frame:Hide()
    return view
end
