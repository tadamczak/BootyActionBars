local Bars = BootyActionBars
local UI = Bars.UI.Components
local General = {}
Bars.Modules.GeneralSettings = General

function General.Create(parent, host, ownerView)
    local frame = UI.CreateContainer(nil, parent)
    frame:SetAllPoints(parent)
    local page = UI.CreateResponsiveCanvas(frame, "BootyActionBarsGeneralScroll")
    local view = {frame = frame, canvas = page, confirmationRevision = 0}
    local function Complete(ok, failure)
        if ownerView.Complete then return ownerView.Complete(ok, failure) end
        if not ok and failure then host.Print(failure) end
        view:Refresh()
        return ok, failure
    end
    local title = UI.CreateHeading(page, "General", 2, "gold")
    local visibilityHeading = UI.CreateHeading(page, "Show bars", 3, "gold")
    local visibilityHelp = UI.CreateComponentLabel(page,
        "Choose which action buttons are shown. Hiding native buttons preserves their assigned keys.", "white")
    visibilityHelp:SetJustifyH("LEFT"); visibilityHelp:SetJustifyV("TOP")
    local trialOwner = UI.CreateContainer(nil, page)
    local trial = UI.Settings.CreateCheckbox(trialOwner, 0, -2, "Show BootyActionBars", "trialBarEnabled", nil, {
        ensure = function() end,
        get = function()
            local store = Bars.Database.Ensure()
            return store and store.trialBarEnabled == true or false
        end,
        set = function(_, value) Complete(Bars.Core.Runtime.SetTrialEnabled(value)) end,
    })
    local nativeOwner = UI.CreateContainer(nil, page)
    local native = UI.Settings.CreateCheckbox(nativeOwner, 0, -2, "Show Native buttons", "nativeMainBarEnabled", nil, {
        ensure = function() end,
        get = function()
            local store = Bars.Database.Ensure()
            return not (store and store.nativeMainBarEnabled == true)
        end,
        set = function(_, value) Complete(Bars.Core.Runtime.SetNativeEnabled(not value)) end,
    })
    UI.AttachTooltip(native, "Native buttons", "Enable BootyActionBars before hiding native buttons. Show restores native controls and keeps their assigned keys.")
    local profileHeading = UI.CreateHeading(page, "Layout profiles", 3, "gold")
    local profileHelp = UI.CreateComponentLabel(page,
        "Save all bar layouts, global appearance and shown bars. Profiles leave client actions, keys and master/native switches unchanged.", "white")
    profileHelp:SetJustifyH("LEFT"); profileHelp:SetJustifyV("TOP")
    local profileOwner = UI.CreateContainer(nil, page)
    profileOwner:SetWidth(300); profileOwner:SetHeight(26)
    local profileChoices = {}
    for index = 1, 20 do profileChoices[index] = {value = index, text = ""} end
    local _, profileChoice = UI.CreateChoiceField({parent = profileOwner, x = 0, y = 0,
        label = "Profile", initialText = "Choose layout", width = 200, height = 416,
        firstY = -7, step = 20, buttonOffset = 58, labelValue = true, choices = profileChoices,
        getValue = function() return ownerView.selectedProfileIndex or 0 end,
        onSelect = function(index)
            ownerView.selectedProfileIndex = index
            ownerView.selectedProfile = ownerView.profileNames and ownerView.profileNames[index]
            ownerView.profileNameField:SetText(ownerView.selectedProfile or "")
        end,
        onChanged = function() view:Refresh() end,
    })
    local nameLabel = UI.CreateComponentLabel(page, "Profile name", "white")
    local profileName = UI.CreateFramedEditBox(page, "BootyActionBarsLayoutProfileName", 240)
    profileName:SetMaxLetters(64); profileName:SetAutoFocus(false)
    profileName:SetScript("OnEditFocusGained", function()
        local editor = Bars.Modules.BindingEditor
        if editor and editor.IsEditing() then Complete(editor.Cancel()) end
    end)
    profileName:SetScript("OnEscapePressed", function() this:ClearFocus() end)
    local function Action(text, width)
        local button = UI.CreateButton(page, nil, text, width, 24)
        UI.StyleActionButton(button); button.mosFlowWidth = width
        return button
    end
    local profileSave, profileLoad = Action("Save layout", 100), Action("Load", 64)
    local profileDelete, profileUndo = Action("Delete", 72), Action("Undo load", 88)
    local profileStatus = UI.CreateComponentLabel(page, "", "white")
    profileStatus:SetJustifyH("LEFT"); profileStatus:SetJustifyV("TOP")
    local function Confirm(titleText, messageText, actionText, action)
        if not ownerView.profileConfirm then
            ownerView.profileConfirm = UI.Window.CreateProjectConfirmation(
                "BootyActionBarsLayoutConfirmation", titleText, actionText, "archive")
        end
        local confirmation = ownerView.profileConfirm
        if UI.WindowStack then UI.WindowStack.SetOwner(confirmation, host.window or frame) end
        confirmation.title:SetText(titleText); confirmation.yes:SetText(actionText)
        view.confirmationRevision = view.confirmationRevision + 1
        local revision = view.confirmationRevision
        confirmation:Open(messageText, function()
            -- A retained approval must not mutate layouts after leaving this page.
            if revision ~= view.confirmationRevision or not frame:IsVisible() then return false end
            return action()
        end)
    end
    profileSave:SetScript("OnClick", function()
        local name, failure = Bars.Services.LayoutProfiles.Name(profileName:GetText())
        if not name then Complete(false, failure); return end
        local store, reason = Bars.Database.Ensure()
        if not store then Complete(false, reason or "Action bar settings are unavailable."); return end
        if store.layoutProfiles and store.layoutProfiles[name] then
            Confirm("Replace layout", "Replace layout " .. name .. " with the current bars?", "Save",
                function() return Complete(Bars.Core.Runtime.SaveLayoutProfile(name, true)) end)
        else Complete(Bars.Core.Runtime.SaveLayoutProfile(name, false)) end
    end)
    profileLoad:SetScript("OnClick", function()
        local name = ownerView.selectedProfile
        if name then
            Confirm("Load layout", "Replace the current layout with " .. name .. "? Unsaved layout changes can be recovered with Undo load.", "Load",
                function() return Complete(Bars.Core.Runtime.LoadLayoutProfile(name)) end)
        end
    end)
    profileDelete:SetScript("OnClick", function()
        local name = ownerView.selectedProfile
        if name then
            Confirm("Delete layout", "Delete layout profile " .. name .. "? The current bars remain.", "Delete",
                function() return Complete(Bars.Core.Runtime.DeleteLayoutProfile(name)) end)
        end
    end)
    profileUndo:SetScript("OnClick", function() Complete(Bars.Core.Runtime.UndoLayoutProfile()) end)
    ownerView.showBarsCheckbox, ownerView.showNativeCheckbox = trial, native
    ownerView.trialCheckbox, ownerView.nativeCheckbox = trial, native
    ownerView.profileChoice, ownerView.profileNameField = profileChoice, profileName
    ownerView.profileNames = ownerView.profileNames or {}
    ownerView.profileSaveButton, ownerView.profileLoadButton = profileSave, profileLoad
    ownerView.profileDeleteButton, ownerView.profileUndoButton, ownerView.profileStatus = profileDelete, profileUndo, profileStatus
    local actions = {profileSave, profileLoad, profileDelete, profileUndo}
    local function Position(control, top, width, height)
        control:ClearAllPoints(); control:SetPoint("TOPLEFT", page, "TOPLEFT", 16, -top)
        control:SetWidth(width); control:SetHeight(height)
        return top + height
    end
    local function Text(control, top, width)
        return Position(control, top, width, UI.MeasureTextHeight(control, width))
    end
    local function Checkbox(owner, control, top, width)
        local labelWidth = math.max(1, width - control:GetWidth() - 7)
        control.label:SetWidth(labelWidth); control.labelHit:SetWidth(labelWidth + 5)
        local height = math.max(26, UI.MeasureTextHeight(control.label, labelWidth))
        return Position(owner, top, width, height)
    end
    local function Measure(available)
        local width = math.max(1, available - 32)
        local top = Position(title, 16, width, 24) + 20
        top = Position(visibilityHeading, top, width, 20) + 8
        top = Text(visibilityHelp, top, width) + 12
        top = Checkbox(trialOwner, trial, top, width) + 8
        top = Checkbox(nativeOwner, native, top, width) + 24
        top = Position(profileHeading, top, width, 20) + 8
        top = Text(profileHelp, top, width) + 14
        top = Position(profileOwner, top, width, 26) + 12
        profileChoice:SetWidth(math.max(1, math.min(200, width - 58)))
        top = Position(nameLabel, top, width, 18) + 4
        top = Position(profileName, top, math.min(240, width), profileName:GetHeight()) + 12
        top = UI.LayoutFlow(page, actions, 16, top, width, 8) + 12
        view.contentHeight = Text(profileStatus, top, width) + 16
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
        local store, failure = Bars.Database.Ensure()
        local runtime = Bars.Core.Runtime
        local available = runtime.IsAvailable() and store ~= nil
        trial:SetChecked(store and store.trialBarEnabled and 1 or nil)
        native:SetChecked(not (store and store.nativeMainBarEnabled) and 1 or nil)
        UI.Settings.SetCheckboxEnabled(trial, available)
        UI.Settings.SetCheckboxEnabled(native, available and (store.nativeMainBarEnabled == true
            or store.trialBarEnabled == true and Bars.Core.Engine.GetState().active == true))
        local names = ownerView.profileNames
        local profileFailure
        local revision = runtime.GetState().profileRevision or 0
        if store and (view.profileRevision ~= revision or view.profileSource ~= store.layoutProfiles) then
            names, profileFailure = Bars.Services.LayoutProfiles.Names(store.layoutProfiles)
            if not names then names = {}; if profileFailure then host.Print(profileFailure) end end
            ownerView.profileNames = names
            view.profileRevision, view.profileSource, view.profileFailure = revision, store.layoutProfiles, profileFailure
            ownerView.selectedProfileIndex = nil
            for index = 1, 20 do
                local name, option = names[index], profileChoice.panel.options[index]
                profileChoices[index].text = name or ""
                option.choiceValue, option.choiceText = index, name or ""
                option.label:SetText(name or "")
                if name then option:Show() else option:Hide() end
                if name == ownerView.selectedProfile then ownerView.selectedProfileIndex = index end
            end
            if not ownerView.selectedProfileIndex then ownerView.selectedProfile = nil end
            profileChoice.panel:SetHeight(math.max(32, table.getn(names) * 20 + 14))
        end
        profileChoice.label:SetText(ownerView.selectedProfile or "Choose layout")
        UI.SetButtonEnabled(profileChoice, available and table.getn(names) > 0 and not view.profileFailure)
        UI.SetButtonEnabled(profileSave, available and not view.profileFailure)
        UI.SetButtonEnabled(profileLoad, available and ownerView.selectedProfile ~= nil and not view.profileFailure)
        UI.SetButtonEnabled(profileDelete, available and ownerView.selectedProfile ~= nil and not view.profileFailure)
        UI.SetButtonEnabled(profileUndo, available and runtime.GetState().layoutUndo ~= nil)
        profileStatus:SetText(failure or view.profileFailure or
            (runtime.GetState().layoutUndo and "Undo load restores the layout from before the last load." or "Choose a profile to load, or enter a name to save the current layout."))
        self:Layout(self.width, self.height)
    end
    local function Cleanup()
        view.confirmationRevision = view.confirmationRevision + 1
        profileChoice.panel:Hide(); profileName:ClearFocus()
        if ownerView.profileConfirm then ownerView.profileConfirm:Hide() end
    end
    frame:SetScript("OnHide", Cleanup)
    function view:Show()
        if not Bars.Core.Runtime.IsAvailable() then return false end
        frame:Show(); self:Refresh(); return true
    end
    function view:Hide()
        Cleanup(); frame:Hide()
    end
    frame:Hide()
    return view
end
