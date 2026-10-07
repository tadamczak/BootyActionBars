local Bars = BootyActionBars
local UI, Runtime, Utility = Bars.UI.Components, Bars.Core.Runtime, Bars.Services.UtilityLayout
local Settings = {}
Bars.Modules.UtilitySettings = Settings

function Settings.Create(parent, context)
    local frame = UI.CreateContainer(nil, parent); frame.mosTextSizeDelta = -2
    local view = {frame = frame, rows = {}, sliders = {}}
    local function Complete(ok, failure) return context.Complete(ok, failure) end
    local function Update(key, value)
        local id = context.GetSelection()
        if not Utility.ValidID(id) then return Complete(false, "Choose a listed utility bar.") end
        if type(Runtime.SetUtilityPreference) ~= "function" then return Complete(false, "Utility-bar settings are unavailable.") end
        return Complete(Runtime.SetUtilityPreference(id, key, value))
    end
    local shown = UI.Settings.CreateCheckbox(frame, 0, 0, "Show bar", "shown", nil, {
        ensure = function() end,
        get = function() return view.layout and view.layout.shown == true end,
        set = function(_, value) return Update("shown", value) end,
    })
    view.shown = shown
    UI.AttachTooltip(shown, "Show utility bar", "Move and scale these native controls separately. Their original actions and scripts keep working.")
    local nativeTexture = UI.Settings.CreateCheckbox(frame, 0, 0, "Native menu texture", "nativeTexture", nil, {
        ensure = function() end,
        get = function() return view.layout and view.layout.nativeTexture == true end,
        set = function(_, value) return Update("nativeTexture", value) end,
    })
    view.nativeTexture = nativeTexture
    UI.AttachTooltip(nativeTexture, "Native menu texture", "Show this control group's native background. It follows the selected layout and scale.")
    for _, definition in ipairs({{"scalePct", "Scale (%)", 50, 200}, {"columns", "Columns", 1, 8}, {"spacing", "Spacing", 0, 20}}) do
        local key, caption, minimum, maximum = definition[1], definition[2], definition[3], definition[4]
        local row = UI.CreateContainer(nil, frame); row:SetHeight(44)
        local slider = UI.Settings.CreateSlider(row, "BootyActionBarsUtility" .. key, 0, -15,
            caption, key, minimum, maximum, nil, {ensure = function() end,
                get = function() return view.layout and view.layout[key] or minimum end,
                set = function(_, value) return Update(key, value) end})
        row.control, row.key = slider, key; view.sliders[key] = slider; table.insert(view.rows, row)
    end
    local reset = UI.CreateButton(frame, nil, "Reset layout", 112, 24); UI.StyleActionButton(reset)
    reset:SetScript("OnClick", function()
        local id = context.GetSelection()
        if not Utility.ValidID(id) then return Complete(false, "Choose a listed utility bar.") end
        if type(Runtime.ResetUtilityLayout) ~= "function" then return Complete(false, "Utility-bar settings are unavailable.") end
        return Complete(Runtime.ResetUtilityLayout(id))
    end)
    UI.AttachTooltip(reset, "Reset utility layout", "Reset this utility bar's position, scale and arrangement. Its visibility is preserved.")
    local status = UI.CreateComponentLabel(frame, "", "white"); status:SetJustifyH("LEFT"); status:SetJustifyV("TOP")
    view.reset, view.status = reset, status
    function view:Refresh()
        local id = context.GetSelection()
        if not Utility.ValidID(id) then self.layout = nil; frame:Hide(); return true end
        local layout, failure
        if type(Runtime.GetUtilityLayout) == "function" then layout, failure = Runtime.GetUtilityLayout(id)
        else failure = "Utility-bar settings are unavailable." end
        self.layout, self.failure = layout, failure
        shown.label:SetText("Show " .. Utility.Name(id)); shown:SetChecked(layout and layout.shown and 1 or nil)
        local available = Runtime.IsAvailable() and layout ~= nil
        UI.Settings.SetCheckboxEnabled(shown, available); UI.SetButtonEnabled(reset, available)
        if Utility.SupportsNativeTexture(id) then nativeTexture:Show() else nativeTexture:Hide() end
        nativeTexture:SetChecked(layout and layout.nativeTexture and 1 or nil)
        UI.Settings.SetCheckboxEnabled(nativeTexture, available and Utility.SupportsNativeTexture(id))
        local grid = id == "bags" or id == "micro"
        for _, row in ipairs(self.rows) do
            if row.key == "scalePct" or grid then row:Show() else row:Hide() end
            if layout then
                if row.key == "columns" then
                    local maximum = Utility.Definition(id).count
                    local syncing = row.control.mosSynchronizing; row.control.mosSynchronizing = true
                    row.control:SetMinMaxValues(1, maximum); row.control.mosSynchronizing = syncing
                    getglobal(row.control:GetName() .. "High"):SetText(tostring(maximum))
                end
                UI.Settings.SynchronizeSlider(row.control, layout[row.key])
            end
            UI.Settings.SetSliderEnabled(row.control, available)
        end
        status:SetText(failure or ""); if failure then status:Show() else status:Hide() end
        frame:Show(); return layout ~= nil, failure
    end
    local function CheckboxLayout(control, width, top)
        control:ClearAllPoints(); control:SetPoint("TOPLEFT", frame, "TOPLEFT", 0, -top)
        local labelWidth = math.max(1, width - control:GetWidth() - 7)
        control.label:SetWidth(labelWidth); control.label:SetHeight(UI.MeasureTextHeight(control.label, labelWidth))
        control.labelHit:SetWidth(labelWidth + 5); control.labelHit:SetHeight(math.max(control:GetHeight(), control.label:GetHeight()))
        control.label:ClearAllPoints(); control.labelHit:ClearAllPoints()
        local wrapped = control.label:GetHeight() > control:GetHeight()
        control.label:SetPoint(wrapped and "TOPLEFT" or "LEFT", control, wrapped and "TOPRIGHT" or "RIGHT", 6, 0)
        control.labelHit:SetPoint(wrapped and "TOPLEFT" or "LEFT", control, wrapped and "TOPRIGHT" or "RIGHT", 1, 0)
        return top + math.max(26, control.label:GetHeight() + 4) + 8
    end
    function view:Layout(width)
        local top = CheckboxLayout(shown, width, 0)
        if nativeTexture:IsShown() then top = CheckboxLayout(nativeTexture, width, top) end
        for _, row in ipairs(self.rows) do
            if row:IsShown() then
                row:ClearAllPoints(); row:SetPoint("TOPLEFT", frame, "TOPLEFT", 0, -top); row:SetWidth(width)
                row.control:SetWidth(math.min(200, width)); top = top + row:GetHeight()
            end
        end
        reset:ClearAllPoints(); reset:SetPoint("TOPLEFT", frame, "TOPLEFT", 0, -top); reset:SetWidth(math.min(112, width))
        top = top + reset:GetHeight() + 8
        if status:IsShown() then
            status:ClearAllPoints(); status:SetPoint("TOPLEFT", frame, "TOPLEFT", 0, -top)
            status:SetWidth(width); status:SetHeight(UI.MeasureTextHeight(status, width)); top = top + status:GetHeight() + 8
        end
        frame:SetWidth(width); frame:SetHeight(top); return top
    end
    function view:Hide() frame:Hide() end
    frame:Hide(); return view
end
