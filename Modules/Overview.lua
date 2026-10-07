local Bars = BootyActionBars
local UI = Bars.UI.Components
local Overview = {}
Bars.Modules.Overview = Overview
local message = "The main bar follows pages/forms; extra bars keep fixed slots. Assign action, pet and form keys under BootyActionBars. Edit layout to move bars."

function Overview.Create(parent, host)
    local frame = UI.CreateContainer(nil, parent)
    frame:SetAllPoints(parent)
    local page = UI.CreateResponsiveCanvas(frame, "BootyActionBarsOverviewScroll")
    local view = {frame = frame, canvas = page, selectedBar = 2, lastScale = 100, lastColumns = 12, lastSpacing = 4,
        lastTitle = true, lastHotkeys = true, lastCounts = true, lastMacroNames = true, lastEmpty = true,
        lastButtonSize = 40, lastIconInset = 4, lastOpacity = 100, lastLabelSize = 10, bindingIndex = 1}
    local function Complete(ok, failure)
        if not ok and failure then host.Print(failure) end
        view:Refresh()
        return ok, failure
    end
    local function EndEdit()
        local ok, failure = Bars.Core.Runtime.SetEditEnabled(false)
        if Bars.Modules.BindingEditor then
            local cancelled, reason = Bars.Modules.BindingEditor.Cancel()
            if not cancelled then
                failure = failure and tostring(failure) .. " Binding cleanup: " .. tostring(reason) or reason
                ok = false
            end
        end
        if not ok and failure then host.Print(failure) end
        return ok, failure
    end
    local title = UI.CreateHeading(page, "Action Bars", 2, "gold")
    title:SetPoint("TOPLEFT", page, "TOPLEFT", 16, -16)
    title:SetHeight(24)
    local body = UI.CreateComponentLabel(page, message, "white")
    body:SetJustifyH("LEFT"); body:SetJustifyV("TOP")
    body:SetPoint("TOPLEFT", title, "BOTTOMLEFT", 0, -12)
    local trial = UI.CreateButton(page, nil, "Enable test bar", 140, 24)
    UI.StyleActionButton(trial)
    trial:SetPoint("TOPLEFT", body, "BOTTOMLEFT", 0, -16)
    trial:SetScript("OnClick", function()
        local store = Bars.Database.Ensure()
        if store then Bars.Core.Runtime.SetTrialEnabled(not store.trialBarEnabled) end
    end)
    local settings = UI.CreateButton(page, nil, "Settings", 100, 24)
    UI.StyleActionButton(settings)
    settings:SetPoint("LEFT", trial, "RIGHT", 12, 0)
    settings:SetScript("OnClick", host.OpenSettings)
    local native = UI.CreateButton(page, nil, "Hide native buttons", 180, 24)
    UI.StyleActionButton(native)
    native:SetPoint("TOPLEFT", trial, "BOTTOMLEFT", 0, -12)
    native:SetScript("OnClick", function()
        local store = Bars.Database.Ensure()
        if store then Bars.Core.Runtime.SetNativeEnabled(not store.nativeMainBarEnabled) end
    end)
    UI.AttachTooltip(native, "Native buttons", "Hide supported main buttons and native pet/form bars when the matching BootyActionBars bar is visible. Show restores native controls and keeps assigned keys.")
    local controls = UI.CreateContainer(nil, page)
    controls:SetPoint("TOPLEFT", native, "BOTTOMLEFT", 0, -16)
    controls:SetHeight(24)
    local choices = {}
    for id = 1, 6 do
        choices[table.getn(choices) + 1] = {value = id,
            text = id == 1 and "Main bar (pages/forms)" or "Bar " .. id .. " (slots " .. ((id - 1) * 12 + 1) .. "-" .. (id * 12) .. ")"}
    end
    table.insert(choices, {value = 7, text = "Pet bar"})
    table.insert(choices, {value = 8, text = "Forms / stances"})
    local _, choice = UI.CreateChoiceField({parent = controls, x = 0, y = 0,
        label = "Bar", initialText = choices[2].text, width = 200, height = 186,
        firstY = -7, step = 20, buttonOffset = 70, labelValue = true, choices = choices,
        getValue = function() return view.selectedBar end,
        onSelect = function(value)
            view.selectedBar = value
            view.bindingIndex = math.min(view.bindingIndex, value >= 7 and 10 or 12)
            local editor = Bars.Modules.BindingEditor
            if editor and editor.IsEditing() then editor.SetSelection(value, view.bindingIndex) end
        end,
        onChanged = function() view:Refresh() end})
    local add = UI.CreateButton(page, nil, "Show", 56, 24)
    UI.StyleActionButton(add); add:SetPoint("TOPLEFT", controls, "BOTTOMLEFT", 0, -12)
    local remove = UI.CreateButton(page, nil, "Hide", 72, 24)
    UI.StyleActionButton(remove); remove:SetPoint("LEFT", add, "RIGHT", 12, 0)
    UI.AttachTooltip(remove, "Hide bar", "Hide this bar while keeping its position, scale, layout, actions and assigned keys. Show restores the same bar.")
    local status = UI.CreateComponentLabel(page, "", "white")
    status:SetPoint("TOPLEFT", add, "BOTTOMLEFT", 0, -10)
    status:SetJustifyH("LEFT"); status:SetJustifyV("TOP")
    add:SetScript("OnClick", function()
        if view.selectedBar >= 7 then Complete(Bars.Core.Runtime.SetSpecialBar(view.selectedBar == 7 and "pet" or "stance", true))
        elseif view.selectedBar ~= 1 then Complete(Bars.Core.Runtime.SetCustomBar(view.selectedBar, true)) end
    end)
    remove:SetScript("OnClick", function()
        if view.selectedBar >= 7 then Complete(Bars.Core.Runtime.SetSpecialBar(view.selectedBar == 7 and "pet" or "stance", false))
        elseif view.selectedBar ~= 1 then Complete(Bars.Core.Runtime.SetCustomBar(view.selectedBar, false)) end
    end)
    local editOwner = UI.CreateContainer(nil, page)
    editOwner:SetHeight(26)
    local edit = UI.Settings.CreateCheckbox(editOwner, 0, -2, "Unlock", "editing", nil, {
        ensure = function() end,
        get = function() return Bars.Core.Runtime.IsEditing() end,
        set = function(_, enabled) Complete(Bars.Core.Runtime.SetEditEnabled(enabled)) end,
    })
    UI.AttachTooltip(edit, "Unlock", "Drag anywhere on a visible bar to move it. Action input is blocked while unlocked. Show anchors reveals hidden bars; closing this window locks the layout.")
    local function LayoutTool(caption, key)
        local owner = UI.CreateContainer(nil, page); owner:SetHeight(26)
        local control = UI.Settings.CreateCheckbox(owner, 0, -2, caption, key, nil, {
            ensure = function() end,
            get = function()
                local store = Bars.Database.Ensure()
                return store and store.editorOptions and store.editorOptions[key] == true or false
            end,
            set = function(_, value) Complete(Bars.Core.Runtime.SetEditorOption(key, value)) end,
        })
        return owner, control
    end
    local gridOwner, showGrid = LayoutTool("Show grid", "showGrid")
    local anchorsOwner, showAnchors = LayoutTool("Show anchors", "showAnchors")
    UI.AttachTooltip(showGrid, "Show grid", "Show a static positioning grid while the layout is unlocked.")
    UI.AttachTooltip(showAnchors, "Show anchors", "Show movable placeholders for hidden or unavailable bars without enabling their actions.")
    local scaleOwner = UI.CreateContainer(nil, page)
    scaleOwner:SetWidth(220); scaleOwner:SetHeight(52)
    local scale = UI.Settings.CreateSlider(scaleOwner, "BootyActionBarsLayoutScale", 0, -18,
        "Scale (%)", "scalePct", 50, 200, nil, {
            ensure = function() end,
            get = function()
                local layout = Bars.Core.Runtime.GetBarLayout(view.selectedBar)
                if layout then view.lastScale = layout.scalePct end
                return view.lastScale
            end,
            set = function(_, value) Complete(Bars.Core.Runtime.SetBarScale(view.selectedBar, value)) end,
        })
    local reset = UI.CreateButton(page, nil, "Reset", 72, 24)
    UI.StyleActionButton(reset)
    UI.AttachTooltip(reset, "Reset bar layout", "Restore the selected bar's position, geometry, appearance and visible labels. Actions and assigned keys are retained.")
    reset:SetScript("OnClick", function() Complete(Bars.Core.Runtime.ResetBarLayout(view.selectedBar)) end)
    local function GridSlider(name, caption, key, lastKey, minimum, maximum, setter)
        local owner = UI.CreateContainer(nil, page)
        owner:SetWidth(140); owner:SetHeight(52)
        local slider = UI.Settings.CreateSlider(owner, name, 0, -18, caption, key, minimum, maximum, nil, {
            ensure = function() end,
            get = function()
                local layout = Bars.Core.Runtime.GetBarLayout(view.selectedBar)
                if layout then view[lastKey] = layout[key] end
                return view[lastKey]
            end,
            set = function(_, value) setter(value) end,
        })
        slider:SetWidth(140)
        return owner, slider
    end
    local columnsOwner, columns = GridSlider("BootyActionBarsLayoutColumns", "Columns", "columns", "lastColumns", 1, 12,
        function(value) Complete(Bars.Core.Runtime.SetBarColumns(view.selectedBar, value)) end)
    local spacingOwner, spacing = GridSlider("BootyActionBarsLayoutSpacing", "Spacing", "spacing", "lastSpacing", 0, 20,
        function(value) Complete(Bars.Core.Runtime.SetBarSpacing(view.selectedBar, value)) end)
    UI.AttachTooltip(columns, "Columns", "Arrange the same twelve action buttons in this many columns. The final row starts at the left edge.")
    UI.AttachTooltip(spacing, "Button spacing", "Set the gap between action buttons, from 0 to 20. Button size and assigned keys stay unchanged.")
    local function DisplayCheckbox(caption, key, lastKey)
        local owner = UI.CreateContainer(nil, page)
        owner:SetHeight(26)
        local checkbox = UI.Settings.CreateCheckbox(owner, 0, -2, caption, key, nil, {
            ensure = function() end,
            get = function()
                local layout = Bars.Core.Runtime.GetBarLayout(view.selectedBar)
                if layout then view[lastKey] = layout[key] end
                return view[lastKey]
            end,
            set = function(_, enabled) Complete(Bars.Core.Runtime.SetBarDisplay(view.selectedBar, key, enabled)) end,
        })
        return owner, checkbox
    end
    local titleOwner, titleCheck = DisplayCheckbox("Title", "showTitle", "lastTitle")
    local hotkeysOwner, hotkeysCheck = DisplayCheckbox("Hotkeys", "showHotkeys", "lastHotkeys")
    local countsOwner, countsCheck = DisplayCheckbox("Counts", "showCounts", "lastCounts")
    local namesOwner, namesCheck = DisplayCheckbox("Macro names", "showMacroNames", "lastMacroNames")
    local emptyOwner, emptyCheck = DisplayCheckbox("Empty buttons", "showEmptyButtons", "lastEmpty")
    UI.AttachTooltip(titleCheck, "Bar title", "Show the title above the selected bar.")
    UI.AttachTooltip(hotkeysCheck, "Assigned keys", "Show key labels on the selected bar. Assigned keys continue working when their labels are hidden.")
    UI.AttachTooltip(countsCheck, "Action counts", "Show item and action counts on the selected bar.")
    UI.AttachTooltip(namesCheck, "Macro names", "Show the native macro name on ordinary action buttons. Spell and pet/form buttons have no macro name.")
    UI.AttachTooltip(emptyCheck, "Empty buttons", "Show empty action slots. Edit layout reveals empty ordinary slots for placement without changing this preference.")
    local appearanceRow = {}
    local appearance = {}
    local function AppearanceSlider(name, caption, key, cache, minimum, maximum)
        local owner, slider = GridSlider(name, caption, key, cache, minimum, maximum,
            function(value) Complete(Bars.Core.Runtime.SetBarAppearance(view.selectedBar, key, value)) end)
        table.insert(appearanceRow, owner); appearance[key] = slider
    end
    AppearanceSlider("BootyActionBarsButtonSize", "Button size", "buttonSize", "lastButtonSize", 24, 64)
    AppearanceSlider("BootyActionBarsIconInset", "Icon inset", "iconInset", "lastIconInset", 0, 8)
    AppearanceSlider("BootyActionBarsOpacity", "Opacity (%)", "opacityPct", "lastOpacity", 20, 100)
    AppearanceSlider("BootyActionBarsLabelSize", "Label size", "labelFontSize", "lastLabelSize", 8, 16)
    local bindingHeading = UI.CreateHeading(page, "Keybindings", 3, "gold")
    local bind = UI.CreateButton(page, nil, "Assign keys", 104, 24); UI.StyleActionButton(bind)
    bind:SetScript("OnClick", function() Complete(Bars.Core.Runtime.SetBindingEditing(true)) end)
    local bindingIndexOwner = UI.CreateContainer(nil, page); bindingIndexOwner:SetWidth(140); bindingIndexOwner:SetHeight(52)
    local bindingIndex = UI.Settings.CreateSlider(bindingIndexOwner, "BootyActionBarsBindingIndex", 0, -18, "Button", "index", 1, 12, nil, {
        ensure = function() end, get = function() return view.bindingIndex end,
        set = function(_, value)
            view.bindingIndex = value
            if Bars.Modules.BindingEditor and Bars.Modules.BindingEditor.IsEditing() then
                Complete(Bars.Modules.BindingEditor.SetSelection(view.selectedBar, value))
            end
        end,
    }); bindingIndex:SetWidth(140)
    local bindingSave = UI.CreateButton(page, nil, "Save keys", 88, 24); UI.StyleActionButton(bindingSave)
    local bindingCancel = UI.CreateButton(page, nil, "Cancel", 72, 24); UI.StyleActionButton(bindingCancel)
    local bindingClear = UI.CreateButton(page, nil, "Clear button", 104, 24); UI.StyleActionButton(bindingClear)
    bindingSave:SetScript("OnClick", function() Complete(Bars.Modules.BindingEditor.Save()) end)
    bindingCancel:SetScript("OnClick", function() Complete(Bars.Modules.BindingEditor.Cancel()) end)
    bindingClear:SetScript("OnClick", function() Complete(Bars.Modules.BindingEditor.ClearSelection()) end)
    local bindingStatus = UI.CreateComponentLabel(page, "", "white"); bindingStatus:SetJustifyH("LEFT"); bindingStatus:SetJustifyV("TOP")
    local profileHeading = UI.CreateHeading(page, "Layout profiles", 3, "gold")
    local profileOwner = UI.CreateContainer(nil, page); profileOwner:SetWidth(300); profileOwner:SetHeight(24)
    local profileChoices = {}
    for index = 1, 20 do profileChoices[index] = {value = index, text = ""} end
    local _, profileChoice = UI.CreateChoiceField({parent = profileOwner, x = 0, y = 0, label = "Profile", initialText = "Choose layout",
        width = 200, height = 416, firstY = -7, step = 20, buttonOffset = 58, labelValue = true, choices = profileChoices,
        getValue = function() return view.selectedProfileIndex or 0 end,
        onSelect = function(index)
            view.selectedProfileIndex = index; view.selectedProfile = view.profileNames and view.profileNames[index]
            if view.profileNameField then view.profileNameField:SetText(view.selectedProfile or "") end
        end,
        onChanged = function() view:Refresh() end,
    })
    local profileName = UI.CreateFramedEditBox(page, "BootyActionBarsLayoutProfileName", 240)
    profileName:SetMaxLetters(64); profileName:SetAutoFocus(false)
    profileName:SetScript("OnEditFocusGained", function() if Bars.Modules.BindingEditor then Bars.Modules.BindingEditor.Cancel() end end)
    profileName:SetScript("OnEscapePressed", function() this:ClearFocus() end)
    local profileSave = UI.CreateButton(page, nil, "Save layout", 100, 24); UI.StyleActionButton(profileSave)
    local profileLoad = UI.CreateButton(page, nil, "Load", 64, 24); UI.StyleActionButton(profileLoad)
    local profileDelete = UI.CreateButton(page, nil, "Delete", 72, 24); UI.StyleActionButton(profileDelete)
    local profileUndo = UI.CreateButton(page, nil, "Undo load", 88, 24); UI.StyleActionButton(profileUndo)
    local profileStatus = UI.CreateComponentLabel(page, "Save geometry, appearance and shown bars. Client actions, keys and master/native switches stay unchanged.", "white")
    profileStatus:SetJustifyH("LEFT"); profileStatus:SetJustifyV("TOP")
    local function Confirm(titleText, messageText, actionText, action)
        if not view.profileConfirm then
            view.profileConfirm = UI.Window.CreateProjectConfirmation("BootyActionBarsLayoutConfirmation", titleText, actionText, "archive")
        end
        if UI.WindowStack then UI.WindowStack.SetOwner(view.profileConfirm, host.window or frame) end
        view.profileConfirm.title:SetText(titleText); view.profileConfirm.yes:SetText(actionText)
        view.profileConfirm:Open(messageText, action)
    end
    profileSave:SetScript("OnClick", function()
        local name, failure = Bars.Services.LayoutProfiles.Name(profileName:GetText())
        if not name then Complete(false, failure); return end
        local store = Bars.Database.Ensure()
        if store and store.layoutProfiles[name] then
            Confirm("Replace layout", "Replace layout " .. name .. " with the current bars?", "Save", function() Complete(Bars.Core.Runtime.SaveLayoutProfile(name, true)) end)
        else Complete(Bars.Core.Runtime.SaveLayoutProfile(name, false)) end
    end)
    profileLoad:SetScript("OnClick", function()
        local name = view.selectedProfile
        if not name then return end
        Confirm("Load layout", "Replace the current layout with " .. name .. "? Unsaved layout changes can be recovered with Undo load.", "Load",
            function() Complete(Bars.Core.Runtime.LoadLayoutProfile(name)) end)
    end)
    profileDelete:SetScript("OnClick", function()
        local name = view.selectedProfile
        if name then Confirm("Delete layout", "Delete layout profile " .. name .. "? The current bars remain.", "Delete",
            function() Complete(Bars.Core.Runtime.DeleteLayoutProfile(name)) end) end
    end)
    profileUndo:SetScript("OnClick", function() Complete(Bars.Core.Runtime.UndoLayoutProfile()) end)
    local endPage = function()
        choice.panel:Hide(); profileChoice.panel:Hide(); profileName:ClearFocus()
        if view.profileConfirm then view.profileConfirm:Hide() end
        EndEdit()
    end
    frame:SetScript("OnHide", endPage)
    view.settingsButton, view.trialButton, view.nativeButton = settings, trial, native
    view.barChoice, view.addBarButton, view.removeBarButton, view.barStatus = choice, add, remove, status
    view.body, view.editCheckbox, view.scaleSlider, view.resetLayoutButton = body, edit, scale, reset
    view.columnsSlider, view.spacingSlider = columns, spacing
    view.showGridCheckbox, view.showAnchorsCheckbox = showGrid, showAnchors
    view.titleCheckbox, view.hotkeysCheckbox, view.countsCheckbox = titleCheck, hotkeysCheck, countsCheck
    view.macroNamesCheckbox, view.emptyButtonsCheckbox, view.appearanceSliders = namesCheck, emptyCheck, appearance
    view.bindingButton, view.bindingIndexSlider, view.bindingSaveButton, view.bindingCancelButton = bind, bindingIndex, bindingSave, bindingCancel
    view.bindingClearButton, view.bindingStatus = bindingClear, bindingStatus
    view.profileChoice, view.profileNameField, view.profileNames = profileChoice, profileName, {}
    view.profileSaveButton, view.profileLoadButton, view.profileDeleteButton, view.profileUndoButton = profileSave, profileLoad, profileDelete, profileUndo
    local firstRow, barActions, scaleRow = {trial, settings}, {add, remove, editOwner}, {scaleOwner, reset}
    local gridRow = {columnsOwner, spacingOwner}
    local toolsRow = {gridOwner, anchorsOwner}
    local displayRow = {titleOwner, hotkeysOwner, countsOwner, namesOwner, emptyOwner}
    local bindingRow, bindingActions = {bind, bindingIndexOwner}, {bindingSave, bindingCancel, bindingClear}
    local profileActions = {profileSave, profileLoad, profileDelete, profileUndo}
    local function CheckboxWidth(owner, checkbox)
        owner:SetWidth(checkbox:GetWidth() + 2 + checkbox.label:GetStringWidth() + 5)
    end
    -- Lua5.0 limits a closure to 32 captured values. Keep the page's pooled
    -- layout references together rather than capturing every control separately.
    local drawing = {title = title, body = body, controls = controls, status = status,
        editOwner = editOwner, edit = edit, titleOwner = titleOwner, titleCheck = titleCheck,
        hotkeysOwner = hotkeysOwner, hotkeysCheck = hotkeysCheck, countsOwner = countsOwner, countsCheck = countsCheck,
        namesOwner = namesOwner, namesCheck = namesCheck, emptyOwner = emptyOwner, emptyCheck = emptyCheck,
        firstRow = firstRow, native = native, barActions = barActions, scaleRow = scaleRow, gridRow = gridRow,
        displayRow = displayRow, appearanceRow = appearanceRow, toolsRow = toolsRow,
        gridOwner = gridOwner, showGrid = showGrid, anchorsOwner = anchorsOwner, showAnchors = showAnchors,
        bindingHeading = bindingHeading,
        bindingRow = bindingRow, bindingActions = bindingActions, bindingStatus = bindingStatus,
        profileHeading = profileHeading, profileOwner = profileOwner, profileName = profileName,
        profileActions = profileActions, profileStatus = profileStatus}
    local function Measure(width)
        local title, body, controls, status = drawing.title, drawing.body, drawing.controls, drawing.status
        local editOwner, edit = drawing.editOwner, drawing.edit
        local titleOwner, titleCheck, hotkeysOwner, hotkeysCheck = drawing.titleOwner, drawing.titleCheck, drawing.hotkeysOwner, drawing.hotkeysCheck
        local countsOwner, countsCheck, namesOwner, namesCheck = drawing.countsOwner, drawing.countsCheck, drawing.namesOwner, drawing.namesCheck
        local emptyOwner, emptyCheck = drawing.emptyOwner, drawing.emptyCheck
        local firstRow, native, barActions, scaleRow, gridRow = drawing.firstRow, drawing.native, drawing.barActions, drawing.scaleRow, drawing.gridRow
        local displayRow, appearanceRow, bindingHeading = drawing.displayRow, drawing.appearanceRow, drawing.bindingHeading
        local bindingRow, bindingActions, bindingStatus = drawing.bindingRow, drawing.bindingActions, drawing.bindingStatus
        local profileHeading, profileOwner, profileName = drawing.profileHeading, drawing.profileOwner, drawing.profileName
        local profileActions, profileStatus = drawing.profileActions, drawing.profileStatus
        width = math.max(1, width - 32)
        title:SetWidth(width); body:SetWidth(width); controls:SetWidth(width); status:SetWidth(width)
        body:SetHeight(UI.MeasureTextHeight(body, width))
        status:SetHeight(UI.MeasureTextHeight(status, width))
        CheckboxWidth(editOwner, edit)
        CheckboxWidth(titleOwner, titleCheck); CheckboxWidth(hotkeysOwner, hotkeysCheck); CheckboxWidth(countsOwner, countsCheck)
        CheckboxWidth(namesOwner, namesCheck); CheckboxWidth(emptyOwner, emptyCheck)
        CheckboxWidth(drawing.gridOwner, drawing.showGrid); CheckboxWidth(drawing.anchorsOwner, drawing.showAnchors)
        local top = UI.LayoutFlow(page, firstRow, 16, 52 + body:GetHeight() + 16, width, 12) + 12
        native:ClearAllPoints(); native:SetPoint("TOPLEFT", page, "TOPLEFT", 16, -top)
        top = top + native:GetHeight() + 16
        controls:ClearAllPoints(); controls:SetPoint("TOPLEFT", page, "TOPLEFT", 16, -top)
        top = UI.LayoutFlow(page, barActions, 16, top + controls:GetHeight() + 12, width, 8) + 12
        top = UI.LayoutFlow(page, drawing.toolsRow, 16, top, width, 8) + 12
        top = UI.LayoutFlow(page, scaleRow, 16, top, width, 8) + 12
        top = UI.LayoutFlow(page, gridRow, 16, top, width, 8) + 12
        top = UI.LayoutFlow(page, displayRow, 16, top, width, 8) + 10
        top = UI.LayoutFlow(page, appearanceRow, 16, top, width, 8) + 12
        bindingHeading:ClearAllPoints(); bindingHeading:SetPoint("TOPLEFT", page, "TOPLEFT", 16, -top)
        bindingHeading:SetWidth(width); bindingHeading:SetHeight(20); top = top + 28
        top = UI.LayoutFlow(page, bindingRow, 16, top, width, 8) + 8
        top = UI.LayoutFlow(page, bindingActions, 16, top, width, 8) + 8
        bindingStatus:SetWidth(width); bindingStatus:SetHeight(UI.MeasureTextHeight(bindingStatus, width))
        bindingStatus:ClearAllPoints(); bindingStatus:SetPoint("TOPLEFT", page, "TOPLEFT", 16, -top)
        top = top + bindingStatus:GetHeight() + 16
        profileHeading:ClearAllPoints(); profileHeading:SetPoint("TOPLEFT", page, "TOPLEFT", 16, -top)
        profileHeading:SetWidth(width); profileHeading:SetHeight(20); top = top + 28
        profileOwner:ClearAllPoints(); profileOwner:SetPoint("TOPLEFT", page, "TOPLEFT", 16, -top)
        profileOwner:SetWidth(width); top = top + 34
        profileName:SetWidth(math.min(240, width)); profileName:ClearAllPoints(); profileName:SetPoint("TOPLEFT", page, "TOPLEFT", 16, -top)
        top = top + profileName:GetHeight() + 10
        top = UI.LayoutFlow(page, profileActions, 16, top, width, 8) + 10
        profileStatus:SetWidth(width); profileStatus:SetHeight(UI.MeasureTextHeight(profileStatus, width))
        profileStatus:ClearAllPoints(); profileStatus:SetPoint("TOPLEFT", page, "TOPLEFT", 16, -top)
        top = top + profileStatus:GetHeight() + 14
        status:ClearAllPoints(); status:SetPoint("TOPLEFT", page, "TOPLEFT", 16, -top)
        view.contentHeight = top + status:GetHeight() + 16
        return view.contentHeight
    end
    function view:RefreshBindings()
        local editor = Bars.Modules.BindingEditor
        local active = editor and editor.IsEditing() or false
        if self.lastBindingActive ~= active then
            UI.SetButtonEnabled(bindingSave, active); UI.SetButtonEnabled(bindingCancel, active); UI.SetButtonEnabled(bindingClear, active)
            self.lastBindingActive = active
        end
        local binding = editor and editor.GetState() or nil
        local text = "Click a button, then press a key. The selected button releases after assignment and shows the draft. Save commits; Cancel restores."
        if active and binding then
            text = (binding.barId == 7 and "Pet" or binding.barId == 8 and "Form" or "Bar " .. tostring(binding.barId or "?"))
                .. ", button " .. tostring(binding.index or "?") .. ": " .. (binding.firstKey or "unassigned")
                .. (binding.secondKey and " / " .. binding.secondKey or "") .. ". " .. tostring(binding.pendingCount or 0) .. " pending changes. "
                .. (binding.message or "Press a key. Escape clears; Save commits; Cancel discards.")
        elseif binding and binding.failure then text = "Keybindings: " .. tostring(binding.failure)
        end
        if self.lastBindingText ~= text then
            self.lastBindingText = text; bindingStatus:SetText(text)
            local height = UI.MeasureTextHeight(bindingStatus, math.max(1, bindingStatus:GetWidth()))
            if height ~= bindingStatus:GetHeight() and frame:IsVisible() then self:OnResize() end
        end
    end
    local function RefreshProfiles(store)
        local revision = Bars.Core.Runtime.GetState().profileRevision or 0
        if view.profileRevision ~= revision or view.profileSource ~= store.layoutProfiles then
            local names, failure = Bars.Services.LayoutProfiles.Names(store.layoutProfiles)
            if not names then host.Print(failure); names = {} end
            view.profileNames, view.profileRevision, view.profileSource = names, revision, store.layoutProfiles
            view.selectedProfileIndex = nil
            for index = 1, 20 do
                local name, option = names[index], profileChoice.panel.options[index]
                profileChoices[index].text = name or ""
                option.choiceValue, option.choiceText = index, name or ""
                option.label:SetText(name or "")
                if name then option:Show() else option:Hide() end
                if name == view.selectedProfile then view.selectedProfileIndex = index end
            end
            if not view.selectedProfileIndex then view.selectedProfile = nil end
            profileChoice.panel:SetHeight(math.max(32, table.getn(names) * 20 + 14))
        end
        profileChoice.label:SetText(view.selectedProfile or "Choose layout")
        UI.SetButtonEnabled(profileChoice, table.getn(view.profileNames) > 0)
        UI.SetButtonEnabled(profileLoad, view.selectedProfile ~= nil)
        UI.SetButtonEnabled(profileDelete, view.selectedProfile ~= nil)
        UI.SetButtonEnabled(profileUndo, Bars.Core.Runtime.GetState().layoutUndo ~= nil)
    end
    function view:OnResize()
        if not frame:IsVisible() then return end
        local width, height = UI.GetFrameSpan(parent)
        width, height = math.max(1, width), math.max(1, height)
        frame:SetWidth(width); frame:SetHeight(height)
        UI.LayoutResponsiveCanvas(page, Measure, nil, width, height)
    end
    function view:Refresh()
        if frame:IsVisible() then
            local store, failure = Bars.Database.Ensure()
            trial.label:SetText(store and store.trialBarEnabled and "Disable test bar" or "Enable test bar")
            native.label:SetText(store and store.nativeMainBarEnabled and "Show native buttons" or "Hide native buttons")
            local main = self.selectedBar == 1
            local special = self.selectedBar == 7 or self.selectedBar == 8
            local configured = store and (main or special and store.specialBars[self.selectedBar == 7 and "pet" or "stance"] == true
                or not special and store.customBars[self.selectedBar] == true)
            UI.SetButtonEnabled(add, store ~= nil and not main and not configured)
            UI.SetButtonEnabled(remove, not main and configured == true)
            local layout, layoutFailure = Bars.Core.Runtime.GetBarLayout(self.selectedBar)
            if layout then
                self.lastScale, self.lastColumns, self.lastSpacing = layout.scalePct, layout.columns, layout.spacing
                self.lastTitle, self.lastHotkeys, self.lastCounts = layout.showTitle, layout.showHotkeys, layout.showCounts
                self.lastMacroNames, self.lastEmpty = layout.showMacroNames, layout.showEmptyButtons
                self.lastButtonSize, self.lastIconInset = layout.buttonSize, layout.iconInset
                self.lastOpacity, self.lastLabelSize = layout.opacityPct, layout.labelFontSize
            end
            UI.Settings.SynchronizeSlider(scale, self.lastScale)
            local synchronizing = columns.mosSynchronizing
            columns.mosSynchronizing = true
            columns:SetMinMaxValues(1, special and 10 or 12)
            columns.mosSynchronizing = synchronizing
            getglobal("BootyActionBarsLayoutColumnsHigh"):SetText(tostring(special and 10 or 12))
            UI.Settings.SynchronizeSlider(columns, self.lastColumns)
            UI.Settings.SynchronizeSlider(spacing, self.lastSpacing)
            UI.Settings.SetSliderEnabled(scale, configured == true and layout ~= nil)
            UI.Settings.SetSliderEnabled(columns, configured == true and layout ~= nil)
            UI.Settings.SetSliderEnabled(spacing, configured == true and layout ~= nil)
            titleCheck:SetChecked(self.lastTitle and 1 or nil)
            hotkeysCheck:SetChecked(self.lastHotkeys and 1 or nil)
            countsCheck:SetChecked(self.lastCounts and 1 or nil)
            namesCheck:SetChecked(self.lastMacroNames and 1 or nil); emptyCheck:SetChecked(self.lastEmpty and 1 or nil)
            UI.Settings.SetCheckboxEnabled(titleCheck, configured == true and layout ~= nil)
            UI.Settings.SetCheckboxEnabled(hotkeysCheck, configured == true and layout ~= nil)
            UI.Settings.SetCheckboxEnabled(countsCheck, configured == true and layout ~= nil and not special)
            UI.Settings.SetCheckboxEnabled(namesCheck, configured == true and layout ~= nil and not special)
            UI.Settings.SetCheckboxEnabled(emptyCheck, configured == true and layout ~= nil)
            for key, slider in pairs(appearance) do
                UI.Settings.SynchronizeSlider(slider, layout and layout[key] or key == "buttonSize" and 40 or key == "iconInset" and 4 or key == "opacityPct" and 100 or 10)
                UI.Settings.SetSliderEnabled(slider, configured == true and layout ~= nil)
            end
            local bindingEditor = Bars.Modules.BindingEditor
            UI.SetButtonEnabled(bind, Bars.Core.Runtime.IsAvailable() and bindingEditor ~= nil)
            local bindingMaximum = special and 10 or 12
            self.bindingIndex = math.min(self.bindingIndex, bindingMaximum)
            local syncing = bindingIndex.mosSynchronizing; bindingIndex.mosSynchronizing = true
            bindingIndex:SetMinMaxValues(1, bindingMaximum); bindingIndex.mosSynchronizing = syncing
            getglobal("BootyActionBarsBindingIndexHigh"):SetText(tostring(bindingMaximum))
            UI.Settings.SynchronizeSlider(bindingIndex, self.bindingIndex)
            if store then RefreshProfiles(store) end
            self:RefreshBindings()
            UI.SetButtonEnabled(reset, configured == true and layout ~= nil)
            edit:SetChecked(Bars.Core.Runtime.IsEditing() and 1 or nil)
            showGrid:SetChecked(store and store.editorOptions and store.editorOptions.showGrid and 1 or nil)
            showAnchors:SetChecked(store and store.editorOptions and store.editorOptions.showAnchors and 1 or nil)
            UI.Settings.SetCheckboxEnabled(showGrid, store ~= nil)
            UI.Settings.SetCheckboxEnabled(showAnchors, store ~= nil)
            UI.Settings.SetCheckboxEnabled(edit, Bars.Core.Runtime.IsAvailable() and Bars.Core.Engine.GetState().active == true)
            status:SetText(not store and failure or not layout and layoutFailure or main and
                "Main bar. Actions and keys follow the visible page or form."
                or special and configured and "Shown when a pet or forms are available. Assign its keys under BootyActionBars; Edit layout also shows unavailable bars."
                or configured and "Shown. Hide keeps its layout, actions and assigned keys."
                or "Hidden. Layout, actions and assigned keys are retained; Show restores this bar.")
            self:OnResize()
        end
    end
    function view:Show()
        if not Bars.Core.Runtime.IsAvailable() then return false end
        frame:Show(); self:Refresh(); return true
    end
    function view:Hide() endPage(); frame:Hide() end
    if Bars.Modules.BindingEditor then Bars.Modules.BindingEditor.SetObserver(function() if frame:IsVisible() then view:RefreshBindings() end end) end
    frame:Hide()
    return view
end
