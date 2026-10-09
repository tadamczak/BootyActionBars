local Bars = BootyActionBars
local UI, Runtime, Utility = Bars.UI.Components, Bars.Core.Runtime, Bars.Services.UtilityLayout
local Settings = {}
Bars.Modules.UtilitySettings = Settings

function Settings.Create(parent, context)
    local frame = UI.CreateContainer(nil, parent); frame.bootyTextSizeDelta = -2
    local view = {frame = frame, rows = {}, sliders = {}}
    local function Complete(ok, failure, skipRefresh) return context.Complete(ok, failure, skipRefresh) end
    local function Available()
        local id = context.GetSelection()
        return Runtime.IsAvailable() and (Runtime.GetMergeOwner(id) == id or not Runtime.GetUseGroupSettings(id))
    end
    local function Update(key, value)
        local id = context.GetSelection()
        if not Utility.ValidID(id) then return Complete(false, "Choose a listed utility bar.") end
        local ok, failure = Runtime.SetUtilityPreference(id, key, value)
        return Complete(ok, failure, ok == true)
    end
    local geometry = Bars.Modules.AppearanceSettings.Section(frame, "Geometry", {Complete = Complete})
    view.geometry = geometry
    local row = UI.CreateContainer(nil, frame); row:SetHeight(32)
    local shown = UI.Settings.CreateCheckbox(row, 0, 0, "Show bar", "shown", nil, {
        ensure = function() end,
        get = function() return view.layout and view.layout.shown == true end,
        set = function(_, value) return Update("shown", value) end})
    row.kind, row.control, row.babBaseHeight = "check", shown, 32
    table.insert(geometry.rows, row); view.shown = shown
    UI.AttachTooltip(shown, "Show utility bar", "The primary bar controls visibility of its entire merged group. Native actions and scripts keep working.")
    for _, definition in ipairs({{"scalePct", "Scale (%)", 50, 200}, {"columns", "Columns", 1, 8}, {"spacing", "Spacing", 0, 20}}) do
        local key, caption, minimum, maximum = definition[1], definition[2], definition[3], definition[4]
        local item = UI.CreateContainer(nil, frame); item:SetHeight(44)
        local slider = UI.Settings.CreateSlider(item, "BootyActionBarsUtility" .. key, 0, -15,
            caption, key, minimum, maximum, nil, {ensure = function() end,
                get = function() return view.layout and view.layout[key] or minimum end,
                set = function(_, value)
                    local control = view.sliders[key]
                    if control and control.babDragging then control.babPending = value
                    else return Update(key, value) end
                end})
        item.control, item.key, item.kind, item.babBaseHeight = slider, key, "slider", 44
        view.sliders[key] = slider
        do
            Bars.Modules.BarSettings.ConfigureColumnSlider(slider, function(value) Update(key, value) end,
                function() return view.layout and view.layout[key] end)
        end
        table.insert(view.rows, item); table.insert(geometry.rows, item)
    end
    local appearance = Bars.Modules.AppearanceSettings.Create(frame, {
        OnlyDecoration = true, ControlPrefix = "BootyActionBarsUtilityAppearance",
        GetSelection = context.GetSelection, GetLayout = function() return view.layout end,
        SetPreference = function(key, value) return Runtime.SetUtilityPreference(context.GetSelection(), key, value) end,
        IsAvailable = Available, Complete = Complete})
    view.appearance = appearance
    local reset = UI.CreateButton(frame, nil, "Reset layout", 112, 24); UI.StyleActionButton(reset)
    reset:SetScript("OnClick", function() return Complete(Runtime.ResetUtilityLayout(context.GetSelection())) end)
    UI.AttachTooltip(reset, "Reset utility layout", "Reset this utility bar's position, scale and appearance. Its visibility is preserved.")
    local status = UI.CreateComponentLabel(frame, "", "white"); status:SetJustifyH("LEFT"); status:SetJustifyV("TOP")
    view.reset, view.status = reset, status
    function view:Refresh()
        local id = context.GetSelection()
        if not Utility.ValidID(id) then self.layout = nil; frame:Hide(); return true end
        local layout, failure = Runtime.GetUtilityLayout(id)
        self.layout, self.failure = layout, failure
        shown.label:SetText("Show " .. Utility.Name(id)); shown:SetChecked(layout and layout.shown and 1 or nil)
        local primary, available = Runtime.GetMergeOwner(id), Available() and layout ~= nil
        UI.Settings.SetCheckboxEnabled(shown, available and primary == id)
        UI.SetButtonEnabled(reset, available and primary == id)
        local grid = id == "bags" or id == "micro"
        for _, item in ipairs(self.rows) do
            if item.key == "scalePct" or grid then item:Show() else item:Hide() end
            if layout then
                if item.key == "columns" then
                    local maximum = Utility.Definition(id).count
                    local syncing = item.control.bootySynchronizing; item.control.bootySynchronizing = true
                    item.control:SetMinMaxValues(1, maximum); item.control.bootySynchronizing = syncing
                    getglobal(item.control:GetName() .. "High"):SetText(tostring(maximum))
                end
                UI.Settings.SynchronizeSlider(item.control, layout[item.key])
            end
            UI.Settings.SetSliderEnabled(item.control, available)
        end
        if layout then appearance:Refresh(layout) end
        status:SetText(failure or ""); if failure then status:Show() else status:Hide() end
        frame:Show(); return layout ~= nil, failure
    end
    function view:Layout(width)
        local top = Bars.Modules.AppearanceSettings.LayoutSection(geometry, frame, 0, width)
        for _, section in ipairs(appearance.sections) do top = Bars.Modules.AppearanceSettings.LayoutSection(section, frame, top, width) end
        reset:ClearAllPoints(); reset:SetPoint("TOPLEFT", frame, "TOPLEFT", 0, -top); reset:SetWidth(math.min(112, width))
        top = top + reset:GetHeight() + 8
        if status:IsShown() then
            status:ClearAllPoints(); status:SetPoint("TOPLEFT", frame, "TOPLEFT", 0, -top)
            status:SetWidth(width); status:SetHeight(UI.MeasureTextHeight(status, width)); top = top + status:GetHeight() + 8
        end
        frame:SetWidth(width); frame:SetHeight(top); return top
    end
    function view:CancelPending()
        for _, control in pairs(self.sliders) do control.babCancelPending() end
        return appearance:Close()
    end
    function view:Hide() self:CancelPending(); frame:Hide() end
    frame:Hide(); return view
end
