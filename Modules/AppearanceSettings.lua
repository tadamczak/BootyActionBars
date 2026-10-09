local Bars = BootyActionBars
local UI = Bars.UI.Components
local Appearance = {}
Bars.Modules.AppearanceSettings = Appearance

local function NaturalWidth(label)
    local text = label:GetText()
    local font, size, flags = label:GetFont()
    if label.babMeasureText == text and label.babMeasureFont == font and label.babMeasureSize == size
        and label.babMeasureFlags == flags and label.babMeasureWidth then return label.babMeasureWidth end
    local previousWidth = label:GetWidth()
    label:SetWidth(0)
    local width = math.max(1, math.ceil(label:GetStringWidth()) + 2)
    label:SetWidth(previousWidth)
    label.babMeasureText, label.babMeasureFont, label.babMeasureSize, label.babMeasureFlags = text, font, size, flags
    label.babMeasureWidth = width
    return width
end
local function SliderWidth(row)
    local control, name = row.control, row.control:GetName()
    local label, low, high = getglobal(name .. "Text"), getglobal(name .. "Low"), getglobal(name .. "High")
    local font, size, flags = label:GetFont()
    local minimum, maximum = low:GetText(), high:GetText()
    if row.babSliderFont == font and row.babSliderSize == size and row.babSliderFlags == flags
        and row.babSliderMinimum == minimum and row.babSliderMaximum == maximum and row.babSliderWidth then return row.babSliderWidth end
    local current = label:GetText()
    label:SetText(control.settingLabel .. ": " .. minimum); local width = NaturalWidth(label)
    label:SetText(control.settingLabel .. ": " .. maximum); width = math.max(width, NaturalWidth(label))
    label:SetText(current)
    width = math.max(170, width + 8, NaturalWidth(low) + NaturalWidth(high) + 32)
    row.babSliderFont, row.babSliderSize, row.babSliderFlags = font, size, flags
    row.babSliderMinimum, row.babSliderMaximum, row.babSliderWidth = minimum, maximum, width
    return width
end
function Appearance.MeasureRow(row)
    local control = row.control
    if row.kind == "slider" then return SliderWidth(row) end
    if row.kind == "choice" then
        local width = NaturalWidth(control.label) + 30
        for _, option in ipairs(control.panel.options) do width = math.max(width, NaturalWidth(option.label) + 30) end
        row.babChoiceWidth = width
        return math.max(width, NaturalWidth(row.label))
    end
    return (row.kind == "color" and 26 or control:GetWidth() + 7) + NaturalWidth(control.label)
end
local function LabelHeight(label, width, minimum)
    width = math.max(1, width)
    minimum = minimum or 0
    local text = label:GetText()
    local font, size, flags = label:GetFont()
    if label.babHeightText == text and label.babHeightFont == font and label.babHeightSize == size
        and label.babHeightFlags == flags and label.babHeightWidth == width and label.babHeightMinimum == minimum
        and label.babHeight then return label.babHeight end
    label:SetWidth(width); label:SetJustifyH("LEFT")
    local height = math.max(minimum, UI.MeasureTextHeight(label, width))
    label:SetHeight(height)
    label.babHeightText, label.babHeightFont, label.babHeightSize, label.babHeightFlags = text, font, size, flags
    label.babHeightWidth, label.babHeightMinimum, label.babHeight = width, minimum, height
    return height
end
function Appearance.LayoutRow(row, parent, x, y, width)
    local control, height = row.control, row.babBaseHeight
    row:ClearAllPoints(); row:SetPoint("TOPLEFT", parent, "TOPLEFT", x, y); row:SetWidth(width)
    if row.kind == "slider" then
        local name = control:GetName()
        local label, low, high = getglobal(name .. "Text"), getglobal(name .. "Low"), getglobal(name .. "High")
        local titleHeight = LabelHeight(label, width, 14)
        control:ClearAllPoints(); control:SetPoint("TOPLEFT", row, "TOPLEFT", 0, -(titleHeight + 1)); control:SetWidth(width)
        label:ClearAllPoints(); label:SetPoint("BOTTOMLEFT", control, "TOPLEFT", 0, 1)
        local lowHeight = LabelHeight(low, NaturalWidth(low))
        local highHeight = LabelHeight(high, NaturalWidth(high))
        height = math.max(height, titleHeight + 1 + control:GetHeight() + math.max(lowHeight, highHeight) + 1)
    elseif row.kind == "choice" then
        local labelHeight = LabelHeight(row.label, width, 14)
        local choiceWidth = math.min(width, row.babChoiceWidth)
        control:ClearAllPoints(); control:SetPoint("TOPLEFT", row, "TOPLEFT", 0, -(labelHeight + 4)); control:SetWidth(choiceWidth)
        UI.ReflowControlText(control)
        control.panel:SetWidth(choiceWidth)
        for _, option in ipairs(control.panel.options) do
            option:SetWidth(math.max(1, choiceWidth - 14)); option.label:SetWidth(math.max(1, choiceWidth - 30))
        end
        height = math.max(height, labelHeight + 4 + control:GetHeight() + 4)
    else
        local color = row.kind == "color"
        local inset = color and 26 or control:GetWidth() + 7
        local labelHeight = LabelHeight(control.label, width - inset)
        control.label:ClearAllPoints()
        if color then
            control:SetWidth(width)
            if labelHeight > control:GetHeight() then control.label:SetPoint("TOPLEFT", control, "TOPLEFT", 26, 0)
            else control.label:SetPoint("LEFT", control.swatchBorder, "RIGHT", 6, 0) end
        elseif labelHeight > control:GetHeight() then control.label:SetPoint("TOPLEFT", control, "TOPRIGHT", 6, 0)
        else control.label:SetPoint("LEFT", control, "RIGHT", 6, 0) end
        if control.labelHit then
            control.labelHit:SetWidth(math.max(1, width - control:GetWidth() - 2)); control.labelHit:SetHeight(math.max(control:GetHeight(), labelHeight))
            control.labelHit:ClearAllPoints()
            if labelHeight > control:GetHeight() then control.labelHit:SetPoint("TOPLEFT", control, "TOPRIGHT", 1, 0)
            else control.labelHit:SetPoint("LEFT", control, "RIGHT", 1, 0) end
        end
        height = math.max(height, labelHeight + 4)
    end
    row:SetHeight(height)
    return height
end

local sectionIcons = {Geometry = "settings", Appearance = "settings", Decoration = "groups", ["Labels and slots"] = "list",
    ["Range colors"] = "health", Hover = "settings", ["Button border"] = "settings", Cooldown = "analyze", Behaviors = "list", ["Text fonts"] = "list"}
local controlKinds = {"check", "choice", "color", "slider"}
function Appearance.Section(parent, caption, context)
    local row = UI.CreateContainer(nil, parent); row:SetHeight(24)
    row.kind = "heading"
    row.control = UI.Settings.CreateSectionAccordion(row, caption, 0, 0, 3, sectionIcons[caption] or "settings")
    row.control:SetExpanded(true); row.control.label:SetText("-  " .. caption)
    local group = {caption = caption, heading = row, rows = {}, expanded = true, content = UI.CreateContainer(nil, parent), scratch = {}}
    row.control:SetScript("OnClick", function()
        if context.Close then local ok, reason = context.Close(); if ok == false then return context.Complete(false, reason) end end
        group.expanded = not group.expanded
        row.control:SetExpanded(group.expanded); row.control.label:SetText((group.expanded and "-  " or "+  ") .. caption)
        return context.Complete(true)
    end)
    return group
end
function Appearance.LayoutSection(group, parent, top, width)
    local heading, body = group.heading, group.content
    heading:ClearAllPoints(); heading:SetPoint("TOPLEFT", parent, "TOPLEFT", 0, -top); heading:SetWidth(width)
    heading.control:SetWidth(width)
    top = top + heading:GetHeight()
    if not group.expanded then body:Hide(); return top + 6 end
    body:Show(); body:ClearAllPoints(); body:SetPoint("TOPLEFT", parent, "TOPLEFT", 0, -top); body:SetWidth(width)
    local offset, lastBlock, rows = 0, nil, group.scratch
    local blockRows = group.blockRows or {}; group.blockRows = blockRows
    rows.bootyMaxColumns = 3; rows.bootyMeasureItem, rows.bootyLayoutItem = Appearance.MeasureRow, Appearance.LayoutRow
    while table.getn(rows) > 0 do table.remove(rows) end
    while table.getn(blockRows) > 0 do table.remove(blockRows) end
    local function Flush()
        for _, kind in ipairs(controlKinds) do
            for _, row in ipairs(blockRows) do if row.kind == kind then table.insert(rows, row) end end
            if table.getn(rows) > 0 then offset = offset + UI.Settings.LayoutGrid(body, rows, 0, -offset, width, 0) end
            while table.getn(rows) > 0 do table.remove(rows) end
        end
        while table.getn(blockRows) > 0 do table.remove(blockRows) end
    end
    for _, row in ipairs(group.rows) do
        if row:IsShown() then
            if row.babBlock ~= lastBlock then Flush(); if offset > 0 then offset = offset + 8 end end
            if row:GetParent() ~= body then row:SetParent(body) end
            table.insert(blockRows, row); lastBlock = row.babBlock
        end
    end
    Flush(); body:SetHeight(offset)
    return top + offset + 8
end
function Appearance.Create(parent, context)
    local view = {rows = {}, sections = {}, sliders = {}, checks = {}, choices = {}, colors = {}}
    local section, block
    local function Complete(ok, failure) return context.Complete(ok, failure) end
    local function Row(height)
        local row = UI.CreateContainer(nil, parent); row:SetHeight(height)
        row.babBaseHeight = height
        row.babBlock = block
        row.bootyTextSizeDelta = math.min(-2, UI.GetTextSizeDelta(parent))
        table.insert(view.rows, row)
        if section then table.insert(section.rows, row) end
        return row
    end
    local function Section(text)
        block = nil
        section = Appearance.Section(parent, text, {Complete = Complete, Close = function() return view:Close() end})
        table.insert(view.sections, section)
    end
    local function Slider(key, caption, low, high, getter, setter)
        local row = Row(44)
        local control = UI.Settings.CreateSlider(row, (context.ControlPrefix or "BootyActionBarsAppearance") .. key, 0, -15,
            caption, key, low, high, nil, {ensure = function() end,
                get = getter or function() local layout = context.GetLayout(); return layout and layout[key] or low end,
                set = function(_, value)
                    local control = view.sliders[key]
                    if control and control.babDragging then control.babPending = value
                    else Complete((setter or function(item) return context.SetPreference(key, item) end)(value)) end
                end})
        row.kind, row.control, row.key = "slider", control, key
        view.sliders[key] = control
        Bars.Modules.BarSettings.ConfigureColumnSlider(control, function(value)
            Complete((setter or function(item) return context.SetPreference(key, item) end)(value))
        end, getter or function() local layout = context.GetLayout(); return layout and layout[key] or low end)
        return control
    end
    local function Checkbox(key, caption)
        local row = Row(32)
        local control = UI.Settings.CreateCheckbox(row, 0, 0, caption, key, nil,
            {ensure = function() end, get = function() local layout = context.GetLayout(); return layout and layout[key] == true end,
                set = function(_, value) Complete(context.SetPreference(key, value)) end})
        row.kind, row.control, row.key = "check", control, key; view.checks[key] = control
        return control
    end
    local function Choice(key, caption, options)
        local row = Row(46)
        local label = UI.CreateComponentLabel(row, caption, "white")
        label:SetPoint("TOPLEFT", row, "TOPLEFT", 0, 0); label:SetHeight(14)
        local _, control = UI.CreateChoiceField({parent = row, x = 0, y = -18, label = "", initialText = options[1].text,
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
        local row = Row(26)
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
        Slider(alphaKey, caption .. " opacity (%)", 0, 100, function()
            local layout = context.GetLayout(); return math.floor((layout and layout[alphaKey] or 1) * 100 + 0.5)
        end, function(percent)
            local layout = context.GetLayout(); if not layout then return false, "Choose a bar or Global." end
            return context.SetColor(context.GetSelection(), group, {layout[group .. "R"], layout[group .. "G"], layout[group .. "B"], percent / 100})
        end)
    end
    Section("Decoration")
    block = "background"
    Checkbox("nativeBackground", "Native bar background")
    local textureScale = Slider("nativeTextureScalePct", "Background scale (%)", 50, 200)
    UI.AttachTooltip(textureScale, "Background scale (%)", "Scale only the native stone background.")
    block = "nativeBorder"
    Checkbox("nativeBorder", "Native bar border")
    Slider("nativeBorderScalePct", "Border scale (%)", 50, 200)
    block = "nativeButtons"
    local nativeBackground = Checkbox("nativeSlotArtwork", "Native button background")
    UI.AttachTooltip(nativeBackground, "Native button background", "Show native recessed slot artwork independently from the bar background, behind occupied and empty buttons.")
    Slider("nativeButtonScalePct", "Button texture scale (%)", 50, 200)
    block = "gryphons"
    Choice("gryphons", "Gryphons", {{value = "none", text = "None"}, {value = "left", text = "Left"},
        {value = "right", text = "Right"}, {value = "both", text = "Both"}})
    Slider("gryphonScalePct", "Gryphon scale (%)", 50, 200)
    if not context.OnlyDecoration then
    Section("Range colors"); Color("rangeIn", "In range"); Color("rangeOut", "Out of range")
    Section("Hover")
    for _, effect in ipairs({{"hoverBackgroundShadow", "hoverBackground", "Background shadow"},
        {"hoverBorderShadow", "hoverShadow", "Border shadow"}, {"hoverBorder", "hoverOutline", "Border"}}) do
        block = effect[2]
        Checkbox(effect[1], effect[3]); Color(effect[2], effect[3] .. " color")
        Slider(effect[2] .. "Size", "Effect size", 1, 10)
        Slider(effect[2] .. "Radius", "Corner radius", 0, 10)
        if effect[2] == "hoverOutline" then Slider("hoverBorderSize", "Border thickness", 1, 10) end
    end
    Section("Button border")
    Checkbox("showButtonBorder", "Show button border"); Color("border", "Border color")
    Slider("borderSize", "Border size", 1, 6); Checkbox("buttonBackground", "Button background")
    Section("Cooldown")
    block = "numbers"
    Checkbox("showCooldownText", "Cooldown numbers"); Color("cooldown", "Text color")
    Color("cooldownUnder10", "Text below 10 seconds"); Color("cooldownUnder5", "Text below 5 seconds")
    local precision = Checkbox("cooldownFullSeconds", "Full seconds")
    UI.AttachTooltip(precision, "Full seconds", "On: whole seconds. Off: one digit after the decimal point.")
    Choice("cooldownFont", "Cooldown font", Bars.Services.TextStyle.Options)
    Slider("cooldownFontSize", "Font size", 8, 32)
    block = "indicator"
    Choice("cooldownEffectMode", "Cooldown indicator", {{value = "circle", text = "Circle"}, {value = "vertical", text = "Top to bottom"}})
    Color("cooldownEffect", "Indicator color")
    block = "blink"
    Checkbox("cooldownFlash", "Blink in last 3 seconds")
    Color("cooldownFlash", "Blink color")
    Section("Text fonts")
    for _, item in ipairs({{"titleFont", "Title font"}, {"hotkeyFont", "Keybinding font"}, {"countFont", "Count font"}, {"macroFont", "Macro name font"}}) do
        Choice(item[1], item[2], Bars.Services.TextStyle.Options)
    end
    end
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
