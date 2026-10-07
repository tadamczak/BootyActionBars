local Bars = BootyActionBars
local UI = Bars.UI.Components
local Appearance = {}
Bars.Modules.AppearanceSettings = Appearance

function Appearance.Create(parent, context)
    local view = {rows = {}, sliders = {}, checks = {}, choices = {}, colors = {}}
    local function Complete(ok, failure) return context.Complete(ok, failure) end
    local function Row(height)
        local row = UI.CreateContainer(nil, parent); row:SetHeight(height)
        table.insert(view.rows, row); return row
    end
    local function Section(text)
        local row = Row(30)
        row.kind, row.control = "heading", UI.CreateHeading(row, text, 3, "gold")
        row.control:SetPoint("TOPLEFT", row, "TOPLEFT", 0, -4); row.control:SetHeight(20)
    end
    local function Slider(key, caption, low, high, getter, setter)
        local row = Row(58)
        local control = UI.Settings.CreateSlider(row, "BootyActionBarsAppearance" .. key, 0, -18,
            caption, key, low, high, nil, {ensure = function() end,
                get = getter or function() local layout = context.GetLayout(); return layout and layout[key] or low end,
                set = function(_, value) Complete((setter or function(item) return context.SetPreference(key, item) end)(value)) end})
        row.kind, row.control, row.key = "slider", control, key
        view.sliders[key] = control; return control
    end
    local function Checkbox(key, caption)
        local row = Row(32)
        local control = UI.Settings.CreateCheckbox(row, 0, 0, caption, key, nil,
            {ensure = function() end, get = function() local layout = context.GetLayout(); return layout and layout[key] == true end,
                set = function(_, value) Complete(context.SetPreference(key, value)) end})
        row.kind, row.control, row.key = "check", control, key; view.checks[key] = control
    end
    local function Choice(key, caption, options)
        local row = Row(56)
        local label = UI.CreateComponentLabel(row, caption, "white")
        label:SetPoint("TOPLEFT", row, "TOPLEFT", 0, 0); label:SetHeight(18)
        local _, control = UI.CreateChoiceField({parent = row, x = 0, y = -22, label = "", initialText = options[1].text,
            width = 180, height = table.getn(options) * 22 + 14, firstY = -7, step = 22, buttonOffset = 0,
            labelValue = true, choices = options, getValue = function() local layout = context.GetLayout(); return layout and layout[key] end,
            onSelect = function(value) Complete(context.SetPreference(key, value)) end,
            onChanged = function() view:Refresh(context.GetLayout()) end})
        row.kind, row.control, row.key, row.label = "choice", control, key, label
        view.choices[key] = {control = control, options = options}
    end
    local function LayoutFor(id)
        if id == "global" then return Bars.Core.Runtime.GetGlobalLayout() end
        return Bars.Core.Runtime.GetBarLayout(id)
    end
    local function Owns(entry)
        return view.picker == entry and ColorPickerFrame
            and ColorPickerFrame.func == entry.func and ColorPickerFrame.cancelFunc == entry.cancel
    end
    local function Run(callback)
        local previousThis, previousEvent, previousArg = this, event, arg1
        local ok, failure = pcall(callback)
        this, event, arg1 = previousThis, previousEvent, previousArg
        if not ok then Complete(false, tostring(failure)) end
        return ok, failure
    end
    function view:Close()
        local entry, ok, failure = self.picker, true, nil
        if entry and Owns(entry) and ColorPickerFrame:IsShown() then
            ok, failure = Run(entry.cancel); ColorPickerFrame:Hide()
        end
        if entry then entry.active = false end
        self.picker = nil
        for _, choice in pairs(self.choices) do choice.control.panel:Hide() end
        return ok, failure
    end
    local function Color(group, caption)
        local row = Row(30)
        local control
        control = UI.Settings.CreateColor(row, 0, 0, caption, group, function()
            view:Refresh(context.GetLayout())
        end, {ensure = function() end,
            get = function()
                local layout = context.GetLayout()
                return {layout and layout[group .. "R"] or 1, layout and layout[group .. "G"] or 1, layout and layout[group .. "B"] or 1}
            end,
            set = function(_, rgb)
                local entry = view.picker
                -- Native SetColorRGB may deliver OnColorSelect while opening.
                -- Initializing the shared picker is a read, not a layout edit.
                if entry and entry.active and entry.opening then return true end
                if not entry or not entry.active or not Owns(entry) then
                    return Complete(false, "Color picker ownership changed. Open the color again.")
                end
                local layout, failure = LayoutFor(entry.id)
                if not layout then return Complete(false, failure) end
                local store = BootyActionBarsDB
                if store ~= entry.store or store.barLayouts ~= entry.layouts or store.globalLayout ~= entry.global
                    or type(entry.id) == "number" and store.barLayouts[entry.id] ~= entry.record
                    or layout[group .. "R"] ~= entry.red or layout[group .. "G"] ~= entry.green
                    or layout[group .. "B"] ~= entry.blue or layout[group .. "A"] ~= entry.alpha then
                    entry.active = false
                    return Complete(false, "Color settings ownership changed. Open the color again.")
                end
                local ok, reason = context.SetColor(entry.id, group, {rgb[1], rgb[2], rgb[3], entry.alpha})
                if ok and BootyActionBarsDB == entry.store then
                    entry.layouts, entry.global = store.barLayouts, store.globalLayout
                    entry.record = type(entry.id) == "number" and store.barLayouts[entry.id] or nil
                    entry.red, entry.green, entry.blue = rgb[1], rgb[2], rgb[3]
                end
                return Complete(ok, reason)
            end})
        row.kind, row.control = "color", control; view.colors[group] = control
        local click = control:GetScript("OnClick")
        control:SetScript("OnClick", function()
            local closed = view:Close(); if not closed then return end
            local entry = {id = context.GetSelection(), active = true, opening = true}
            local layout, failure = LayoutFor(entry.id)
            if not layout then Complete(false, failure); return end
            entry.store = BootyActionBarsDB
            entry.layouts, entry.global = entry.store.barLayouts, entry.store.globalLayout
            entry.record = type(entry.id) == "number" and entry.layouts[entry.id] or nil
            entry.red, entry.green, entry.blue, entry.alpha = layout[group .. "R"], layout[group .. "G"], layout[group .. "B"], layout[group .. "A"]
            view.picker = entry
            local ok = Run(click)
            if not ok then entry.active = false; view.picker = nil; return end
            local nativeFunc, nativeCancel = ColorPickerFrame.func, ColorPickerFrame.cancelFunc
            entry.func = function() if entry.active and Owns(entry) then return nativeFunc() end end
            entry.cancel = function() if entry.active and Owns(entry) then return nativeCancel() end end
            ColorPickerFrame.func, ColorPickerFrame.cancelFunc = entry.func, entry.cancel
            entry.opening = false
        end)
        local alphaKey = group .. "A"
        Slider(alphaKey, "Color opacity (%)", 0, 100, function()
            local layout = context.GetLayout(); return math.floor((layout and layout[alphaKey] or 1) * 100 + 0.5)
        end, function(percent)
            local layout = context.GetLayout(); if not layout then return false, "Choose a bar or Global." end
            return context.SetColor(context.GetSelection(), group, {layout[group .. "R"], layout[group .. "G"], layout[group .. "B"], percent / 100})
        end)
    end
    Section("Range colors"); Color("rangeIn", "In range"); Color("rangeOut", "Out of range")
    Section("Hover")
    Choice("hoverMode", "Effect", {{value = "default", text = "Default"}, {value = "border", text = "Border"}, {value = "shadow", text = "Shadow"}})
    Color("hover", "Hover color"); Slider("hoverSize", "Effect size", 1, 6)
    Section("Button border")
    Checkbox("showButtonBorder", "Show button border"); Color("border", "Border color")
    Slider("borderSize", "Border size", 1, 6); Checkbox("buttonBackground", "Button background")
    Section("Cooldown")
    Checkbox("showCooldownText", "Cooldown numbers"); Color("cooldown", "Text color")
    Slider("cooldownFontSize", "Font size", 8, 32)
    Section("Decoration")
    Checkbox("nativeTexture", "Native menu texture")
    Choice("gryphons", "Gryphons", {{value = "none", text = "None"}, {value = "left", text = "Left"},
        {value = "right", text = "Right"}, {value = "both", text = "Both"}})
    function view:Refresh(layout)
        if not layout then return end
        for key, slider in pairs(self.sliders) do
            local value = layout[key]
            if string.sub(key, -1) == "A" then value = math.floor(value * 100 + 0.5) end
            UI.Settings.SynchronizeSlider(slider, value)
            UI.Settings.SetSliderEnabled(slider, context.IsAvailable())
        end
        for key, check in pairs(self.checks) do check:SetChecked(layout[key] and 1 or nil); UI.Settings.SetCheckboxEnabled(check, context.IsAvailable()) end
        for key, choice in pairs(self.choices) do
            for _, option in ipairs(choice.options) do if option.value == layout[key] then choice.control.label:SetText(option.text) end end
            UI.SetButtonEnabled(choice.control, context.IsAvailable())
        end
        for group, control in pairs(self.colors) do
            control.swatch:SetTexture(layout[group .. "R"], layout[group .. "G"], layout[group .. "B"], 1)
            UI.SetButtonEnabled(control, context.IsAvailable())
        end
    end
    return view
end
