local Bars = BootyActionBars
local UI = Bars.UI.Components
local Overview = {}
Bars.Modules.Overview = Overview
local message = "The main bar follows pages/forms; extra bars keep fixed slots. Keys are under BootyActionBars. Edit layout to move bars."

function Overview.Create(parent, host)
    local page = UI.CreateContainer(nil, parent)
    page:SetAllPoints(parent)
    local view = {frame = page, selectedBar = 2, lastScale = 100, lastColumns = 12, lastSpacing = 4}
    local function Complete(ok, failure)
        if not ok and failure then host.Print(failure) end
        view:Refresh()
        return ok, failure
    end
    local function EndEdit()
        local ok, failure = Bars.Core.Runtime.SetEditEnabled(false)
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
    local native = UI.CreateButton(page, nil, "Replace native buttons", 180, 24)
    UI.StyleActionButton(native)
    native:SetPoint("TOPLEFT", trial, "BOTTOMLEFT", 0, -12)
    native:SetScript("OnClick", function()
        local store = Bars.Database.Ensure()
        if store then Bars.Core.Runtime.SetNativeEnabled(not store.nativeMainBarEnabled) end
    end)
    local controls = UI.CreateContainer(nil, page)
    controls:SetPoint("TOPLEFT", native, "BOTTOMLEFT", 0, -16)
    controls:SetHeight(24)
    local choices = {}
    for id = 1, 6 do
        choices[table.getn(choices) + 1] = {value = id,
            text = id == 1 and "Main bar (pages/forms)" or "Bar " .. id .. " (slots " .. ((id - 1) * 12 + 1) .. "-" .. (id * 12) .. ")"}
    end
    local _, choice = UI.CreateChoiceField({parent = controls, x = 0, y = 0,
        label = "Bar", initialText = choices[2].text, width = 200, height = 146,
        firstY = -7, step = 20, buttonOffset = 70, labelValue = true, choices = choices,
        getValue = function() return view.selectedBar end,
        onSelect = function(value) view.selectedBar = value end,
        onChanged = function() view:Refresh() end})
    local add = UI.CreateButton(page, nil, "Add", 56, 24)
    UI.StyleActionButton(add); add:SetPoint("TOPLEFT", controls, "BOTTOMLEFT", 0, -12)
    local remove = UI.CreateButton(page, nil, "Remove", 72, 24)
    UI.StyleActionButton(remove); remove:SetPoint("LEFT", add, "RIGHT", 12, 0)
    local status = UI.CreateComponentLabel(page, "", "white")
    status:SetPoint("TOPLEFT", add, "BOTTOMLEFT", 0, -10)
    status:SetJustifyH("LEFT"); status:SetJustifyV("TOP")
    add:SetScript("OnClick", function()
        if view.selectedBar ~= 1 then Complete(Bars.Core.Runtime.SetCustomBar(view.selectedBar, true)) end
    end)
    remove:SetScript("OnClick", function()
        if view.selectedBar ~= 1 then Complete(Bars.Core.Runtime.SetCustomBar(view.selectedBar, false)) end
    end)
    local editOwner = UI.CreateContainer(nil, page)
    editOwner:SetHeight(26)
    local edit = UI.Settings.CreateCheckbox(editOwner, 0, -2, "Edit layout", "editing", nil, {
        ensure = function() end,
        get = function() return Bars.Core.Runtime.IsEditing() end,
        set = function(_, enabled) Complete(Bars.Core.Runtime.SetEditEnabled(enabled)) end,
    })
    UI.AttachTooltip(edit, "Edit layout", "Unlock the visible bars to move them. Closing this window locks the bars and cancels an unfinished move.")
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
    UI.AttachTooltip(reset, "Reset bar layout", "Restore the selected bar's position, scale, columns and spacing. Actions and assigned keys are retained.")
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
    local endPage = function() choice.panel:Hide(); EndEdit() end
    page:SetScript("OnHide", endPage)
    view.settingsButton, view.trialButton, view.nativeButton = settings, trial, native
    view.barChoice, view.addBarButton, view.removeBarButton, view.barStatus = choice, add, remove, status
    view.body, view.editCheckbox, view.scaleSlider, view.resetLayoutButton = body, edit, scale, reset
    view.columnsSlider, view.spacingSlider = columns, spacing
    local firstRow, barActions, scaleRow = {trial, settings}, {add, remove, editOwner}, {scaleOwner, reset}
    local gridRow = {columnsOwner, spacingOwner}
    function view:OnResize()
        local width = UI.GetFrameSpan(parent)
        width = math.max(1, width - 32)
        title:SetWidth(width); body:SetWidth(width); controls:SetWidth(width); status:SetWidth(width)
        body:SetHeight(UI.MeasureTextHeight(body, width))
        status:SetHeight(UI.MeasureTextHeight(status, width))
        editOwner:SetWidth(edit:GetWidth() + 2 + edit.label:GetStringWidth() + 5)
        local top = UI.LayoutFlow(page, firstRow, 16, 52 + body:GetHeight() + 16, width, 12) + 12
        native:ClearAllPoints(); native:SetPoint("TOPLEFT", page, "TOPLEFT", 16, -top)
        top = top + native:GetHeight() + 16
        controls:ClearAllPoints(); controls:SetPoint("TOPLEFT", page, "TOPLEFT", 16, -top)
        top = UI.LayoutFlow(page, barActions, 16, top + controls:GetHeight() + 12, width, 8) + 12
        top = UI.LayoutFlow(page, scaleRow, 16, top, width, 8) + 12
        top = UI.LayoutFlow(page, gridRow, 16, top, width, 8) + 10
        status:ClearAllPoints(); status:SetPoint("TOPLEFT", page, "TOPLEFT", 16, -top)
        self.contentHeight = top + status:GetHeight() + 16
    end
    function view:Refresh()
        if page:IsVisible() then
            local store, failure = Bars.Database.Ensure()
            trial.label:SetText(store and store.trialBarEnabled and "Disable test bar" or "Enable test bar")
            native.label:SetText(store and store.nativeMainBarEnabled and "Restore native buttons" or "Replace native buttons")
            local main = self.selectedBar == 1
            local configured = store and (main or store.customBars[self.selectedBar] == true)
            UI.SetButtonEnabled(add, store ~= nil and not main and not configured)
            UI.SetButtonEnabled(remove, not main and configured == true)
            local layout, layoutFailure = Bars.Core.Runtime.GetBarLayout(self.selectedBar)
            if layout then
                self.lastScale, self.lastColumns, self.lastSpacing = layout.scalePct, layout.columns, layout.spacing
            end
            UI.Settings.SynchronizeSlider(scale, self.lastScale)
            UI.Settings.SynchronizeSlider(columns, self.lastColumns)
            UI.Settings.SynchronizeSlider(spacing, self.lastSpacing)
            UI.Settings.SetSliderEnabled(scale, configured == true and layout ~= nil)
            UI.Settings.SetSliderEnabled(columns, configured == true and layout ~= nil)
            UI.Settings.SetSliderEnabled(spacing, configured == true and layout ~= nil)
            UI.SetButtonEnabled(reset, configured == true and layout ~= nil)
            edit:SetChecked(Bars.Core.Runtime.IsEditing() and 1 or nil)
            UI.Settings.SetCheckboxEnabled(edit, Bars.Core.Runtime.IsAvailable() and Bars.Core.Engine.GetState().active == true)
            status:SetText(not store and failure or not layout and layoutFailure or main and
                "Main bar. Actions and keys follow the visible page or form."
                or configured and "Added. Removing this bar keeps its actions and assigned keys."
                or "Not added. Enable the test bars to show configured bars.")
            self:OnResize()
        end
    end
    function view:Show()
        if not Bars.Core.Runtime.IsAvailable() then return false end
        page:Show(); self:Refresh(); return true
    end
    function view:Hide() choice.panel:Hide(); EndEdit(); page:Hide() end
    page:Hide()
    return view
end
