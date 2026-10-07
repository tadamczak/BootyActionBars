local Bars = BootyActionBars
local UI, Runtime = Bars.UI.Components, Bars.Core.Runtime
local BarSettings = {}
Bars.Modules.BarSettings = BarSettings
local sliders = {{"scalePct", "Scale (%)", 50, 200}, {"columns", "Columns", 1, 12},
    {"spacing", "Spacing", 0, 20}, {"buttonSize", "Button size", 24, 64},
    {"iconInset", "Icon inset", 0, 8}, {"opacityPct", "Opacity (%)", 20, 100}, {"labelFontSize", "Label size", 8, 16}}
local checks = {{"showTitle", "Title"}, {"showHotkeys", "Hotkeys"}, {"showCounts", "Counts"},
    {"showMacroNames", "Macro names"}, {"showEmptyButtons", "Empty buttons"}}
local identities = {"layout", "global", 1, 2, 3, 4, 5, 6, 7, 8}
local function Name(id)
    return id == "layout" and "Layout" or id == "global" and "Global"
        or id == 7 and "Pet" or id == 8 and "Forms / stances" or "Action Bar " .. id
end
function BarSettings.Create(parent, host, owner)
    local frame = UI.CreateContainer(nil, parent); frame:SetAllPoints(parent)
    local left, right = UI.CreateContainer(nil, frame), UI.CreateContainer(nil, frame)
    local list = UI.CreateResponsiveCanvas(left, "BootyActionBarsBarListScroll")
    local canvas = UI.CreateResponsiveCanvas(right, "BootyActionBarsBarSettingsScroll")
    local view = {frame = frame, canvas = canvas, selected = "layout", buttons = {}, sliders = {}, checks = {}, rows = {}}
    local title = UI.CreateHeading(canvas, "Layout", 2, "gold")
    local description = UI.CreateComponentLabel(canvas, "", "white"); description:SetJustifyH("LEFT"); description:SetJustifyV("TOP")
    local tools, settings = UI.CreateContainer(nil, canvas), UI.CreateContainer(nil, canvas)
    local visibility, inherited = UI.CreateContainer(nil, canvas), UI.CreateContainer(nil, canvas)
    visibility:SetHeight(28); inherited:SetHeight(28)
    local function Complete(ok, failure) return owner.Complete(ok, failure) end
    local function Checkbox(parentFrame, caption, key, getter, setter)
        return UI.Settings.CreateCheckbox(parentFrame, 0, 0, caption, key, nil,
            {ensure = function() end, get = getter, set = function(_, value) Complete(setter(value)) end})
    end
    local function GetLayout()
        if view.selected == "global" then return Runtime.GetGlobalLayout() end
        if type(view.selected) == "number" then return Runtime.GetBarLayout(view.selected) end
    end
    local function SetPreference(key, value)
        if view.selected == "global" then return Runtime.SetGlobalLayout(key, value) end
        if key == "scalePct" then return Runtime.SetBarScale(view.selected, value) end
        if key == "columns" then return Runtime.SetBarColumns(view.selected, value) end
        if key == "spacing" then return Runtime.SetBarSpacing(view.selected, value) end
        if Bars.Services.BarLayout.ValidDisplayKey(key) then return Runtime.SetBarDisplay(view.selected, key, value) end
        return Runtime.SetBarAppearance(view.selected, key, value)
    end
    local unlock = Checkbox(tools, "Unlock", "editing", Runtime.IsEditing, Runtime.SetEditEnabled)
    local grid = Checkbox(tools, "Show grid", "showGrid", function()
        local store = Bars.Database.Ensure(); return store and store.editorOptions.showGrid == true
    end, function(value) return Runtime.SetEditorOption("showGrid", value) end)
    local anchors = Checkbox(tools, "Show anchors", "showAnchors", function()
        local store = Bars.Database.Ensure(); return store and store.editorOptions.showAnchors == true
    end, function(value) return Runtime.SetEditorOption("showAnchors", value) end)
    grid:SetPoint("TOPLEFT", tools, "TOPLEFT", 0, -34); anchors:SetPoint("TOPLEFT", tools, "TOPLEFT", 0, -68); tools:SetHeight(100)
    UI.AttachTooltip(unlock, "Unlock", "Drag anywhere on the normal bar. Mouse actions and icon dragging are blocked until you lock it.")
    UI.AttachTooltip(grid, "Show grid", "Show a static positioning grid while unlocked.")
    UI.AttachTooltip(anchors, "Show anchors", "Move placeholders for hidden or unavailable bars without enabling their buttons.")
    local function IsShown()
        local store, id = Bars.Database.Ensure(), view.selected
        if not store or type(id) ~= "number" then return false end
        return id == 1 and store.mainBarShown ~= false or id == 7 and store.specialBars.pet == true
            or id == 8 and store.specialBars.stance == true or id > 1 and id < 7 and store.customBars[id] == true
    end
    local show = Checkbox(visibility, "Show Action Bar", "visible", IsShown, function(value)
        local id = view.selected
        if id == 1 then return Runtime.SetMainBarShown(value) end
        if id >= 7 then return Runtime.SetSpecialBar(id == 7 and "pet" or "stance", value) end
        return Runtime.SetCustomBar(id, value)
    end)
    local useGlobal = Checkbox(inherited, "Use Global Layout", "useGlobalLayout", function()
        local layout = GetLayout(); return layout and layout.useGlobalLayout == true
    end, function(value) return Runtime.SetUseGlobalLayout(view.selected, value) end)
    local reset = UI.CreateButton(canvas, nil, "Reset local layout", 136, 24); UI.StyleActionButton(reset)
    reset:SetScript("OnClick", function() Complete(Runtime.ResetBarLayout(view.selected)) end)
    UI.AttachTooltip(reset, "Reset local layout", "Reset position and individual layout. Global choice, actions and keys are retained.")
    local function Section(caption)
        local row = UI.CreateContainer(nil, settings); row:SetHeight(28)
        row.control = UI.CreateHeading(row, caption, 3, "gold")
        row.control:SetPoint("TOPLEFT", row, "TOPLEFT", 0, -2); row.control:SetHeight(20)
        row.kind = "heading"; table.insert(view.rows, row)
    end
    for _, definition in ipairs(sliders) do
        local key, caption, minimum, maximum = definition[1], definition[2], definition[3], definition[4]
        if key == "scalePct" then Section("Geometry") elseif key == "buttonSize" then Section("Appearance") end
        local row = UI.CreateContainer(nil, settings); row:SetHeight(58)
        local slider = UI.Settings.CreateSlider(row, "BootyActionBarsLayout" .. key, 0, -18, caption, key, minimum, maximum, nil,
            {ensure = function() end, get = function() local layout = GetLayout(); return layout and layout[key] or minimum end,
                set = function(_, value) Complete(SetPreference(key, value)) end})
        row.control, row.key, row.kind = slider, key, "slider"; table.insert(view.rows, row); view.sliders[key] = slider
    end
    Section("Labels and slots")
    for _, definition in ipairs(checks) do
        local key, caption = definition[1], definition[2]
        local row = UI.CreateContainer(nil, settings); row:SetHeight(30)
        local check = Checkbox(row, caption, key, function() local layout = GetLayout(); return layout and layout[key] == true end,
            function(value) return SetPreference(key, value) end)
        row.control, row.key, row.kind = check, key, "check"; table.insert(view.rows, row); view.checks[key] = check
    end
    local appearance = Bars.Modules.AppearanceSettings.Create(settings, {
        GetLayout = GetLayout, GetSelection = function() return view.selected end,
        SetPreference = SetPreference, Complete = Complete, IsAvailable = Runtime.IsAvailable,
        SetColor = function(id, group, rgba)
            if id == "global" then return Runtime.SetGlobalColor(group, rgba) end
            return Runtime.SetBarColor(id, group, rgba)
        end,
    })
    for _, row in ipairs(appearance.rows) do table.insert(view.rows, row) end
    view.appearance = appearance
    for _, id in ipairs(identities) do
        local button = UI.CreateSelectionButton(list, nil, Name(id), 124, 26); UI.SetButtonLabelInsets(button, 8, 4)
        button:SetScript("OnClick", function() view:Select(id) end); view.buttons[id] = button
    end
    local function MeasureList(width)
        local columns = view.compact and 2 or 1
        local columnWidth = math.max(1, (width - (columns - 1) * 4) / columns)
        for index, id in ipairs(identities) do
            local button = view.buttons[id]; button:SetWidth(math.max(1, columnWidth - 4))
            button.label:SetText(view.compact and (type(id) == "number" and id <= 6 and "Bar " .. id or id == 8 and "Forms" or Name(id)) or Name(id))
            button:ClearAllPoints(); button:SetPoint("TOPLEFT", list, "TOPLEFT", math.mod(index - 1, columns) * (columnWidth + 4), -math.floor((index - 1) / columns) * 30)
        end
        return math.ceil(table.getn(identities) / columns) * 30
    end
    local function Place(region, width, top)
        region:ClearAllPoints(); region:SetPoint("TOPLEFT", canvas, "TOPLEFT", 12, -top); region:SetWidth(width)
        return top + region:GetHeight()
    end
    local function Measure(width)
        local usable = math.max(1, width - 24)
        title:SetHeight(24); Place(title, usable, 8)
        description:SetHeight(UI.MeasureTextHeight(description, usable)); local top = Place(description, usable, 40) + 16
        if view.selected == "layout" then return Place(tools, usable, top) + 12 end
        if view.selected ~= "global" then top = Place(visibility, usable, top) + 6; top = Place(inherited, usable, top) + 8 end
        if settings:IsShown() then
            local content = 0
            for _, row in ipairs(view.rows) do
                if row:IsShown() then
                    row:ClearAllPoints(); row:SetPoint("TOPLEFT", settings, "TOPLEFT", 0, -content); row:SetWidth(usable)
                    if row.kind == "slider" then row.control:SetWidth(math.min(260, usable))
                    elseif row.kind == "heading" or row.kind == "choice" or row.kind == "color" then row.control:SetWidth(usable) end
                    if row.label then row.label:SetWidth(usable) end
                    if row.kind == "check" then
                        local labelWidth = math.max(1, usable - row.control:GetWidth() - 7)
                        row.control.label:SetWidth(labelWidth)
                        local labelHeight = UI.MeasureTextHeight(row.control.label, labelWidth)
                        row.control.label:SetHeight(labelHeight); row.control.label:ClearAllPoints()
                        if labelHeight > row.control:GetHeight() then
                            row.control.label:SetPoint("TOPLEFT", row.control, "TOPRIGHT", 6, 0)
                        else row.control.label:SetPoint("LEFT", row.control, "RIGHT", 6, 0) end
                        if row.control.labelHit then
                            row.control.labelHit:SetWidth(labelWidth + 5)
                            row.control.labelHit:SetHeight(math.max(row.control:GetHeight(), labelHeight))
                        end
                        row:SetHeight(math.max(32, labelHeight + 4))
                    end
                    content = content + row:GetHeight()
                end
            end
            settings:SetHeight(content); top = Place(settings, usable, top) + 8
        end
        if reset:IsShown() then
            reset:SetWidth(math.min(136, usable)); reset:ClearAllPoints(); reset:SetPoint("TOPLEFT", canvas, "TOPLEFT", 12, -top); top = top + 34
        end
        return top + 12
    end
    function view:Layout(width, height)
        if not frame:IsVisible() then return end
        view.compact = width < 300
        local listWidth = view.compact and math.max(1, width - 16) or width < 440 and 108 or 132
        local listHeight = view.compact and math.min(92, math.max(32, height / 3)) or math.max(1, height - 16)
        left:ClearAllPoints(); left:SetPoint("TOPLEFT", frame, "TOPLEFT", 8, -8); left:SetWidth(listWidth); left:SetHeight(listHeight)
        right:ClearAllPoints()
        local rightWidth, rightHeight
        if view.compact then
            right:SetPoint("TOPLEFT", frame, "TOPLEFT", 0, -(listHeight + 16))
            rightWidth, rightHeight = width, math.max(1, height - listHeight - 16)
        else
            right:SetPoint("TOPLEFT", frame, "TOPLEFT", listWidth + 20, 0)
            rightWidth, rightHeight = math.max(1, width - listWidth - 28), height
        end
        right:SetWidth(rightWidth); right:SetHeight(rightHeight)
        UI.LayoutResponsiveCanvas(list, MeasureList, nil, listWidth, listHeight)
        UI.LayoutResponsiveCanvas(canvas, Measure, nil, rightWidth, rightHeight)
    end
    function view:Select(id)
        if not self.buttons[id] then return false, "Choose a listed bar or Layout/Global." end
        local closed, failure = appearance:Close(); if not closed then return false, failure end
        self.selected = id; if type(id) == "number" then owner.selectedBar = id end
        self:Refresh(); return true
    end
    function view:Refresh()
        if not frame:IsVisible() then return end
        local id, store = self.selected, Bars.Database.Ensure()
        local isLayout, isGlobal = id == "layout", id == "global"
        for key, button in pairs(self.buttons) do UI.StyleWarmListRow(button, key == id) end
        title:SetText(Name(id))
        description:SetText(isLayout and "Unlock to position bars. Show anchors also reveals hidden bars."
            or isGlobal and "Shared appearance for bars using Global Layout. Each bar keeps its own position."
            or id == 1 and "Actions follow the page or form. Hiding this bar keeps other bars active."
            or id >= 7 and "Shown when a pet or form is available. Use Layout and Show anchors to position it while absent."
            or "Actions use fixed slots. Hiding preserves layout, actions and keys.")
        if isLayout then tools:Show() else tools:Hide() end
        if not isLayout and not isGlobal then visibility:Show(); inherited:Show(); reset:Show()
        else visibility:Hide(); inherited:Hide(); reset:Hide() end
        local layout = GetLayout()
        if layout and (isGlobal or not layout.useGlobalLayout) then settings:Show() else settings:Hide() end
        if layout then
            appearance:Refresh(layout)
            for key, slider in pairs(self.sliders) do
                if key == "columns" then
                    local maximum = type(id) == "number" and id >= 7 and 10 or 12
                    local syncing = slider.mosSynchronizing; slider.mosSynchronizing = true
                    slider:SetMinMaxValues(1, maximum); slider.mosSynchronizing = syncing
                    getglobal(slider:GetName() .. "High"):SetText(tostring(maximum))
                end
                UI.Settings.SynchronizeSlider(slider, layout[key]); UI.Settings.SetSliderEnabled(slider, Runtime.IsAvailable())
            end
            for key, check in pairs(self.checks) do
                local relevant = isGlobal or id < 7 or key ~= "showCounts" and key ~= "showMacroNames"
                if relevant then check:GetParent():Show() else check:GetParent():Hide() end
                check:SetChecked(layout[key] and 1 or nil); UI.Settings.SetCheckboxEnabled(check, Runtime.IsAvailable())
            end
            useGlobal:SetChecked(layout.useGlobalLayout and 1 or nil)
        end
        if type(id) == "number" then
            show.label:SetText(id < 7 and "Show Action Bar " .. id or id == 7 and "Show Pet Bar" or "Show Form Bar")
            show:SetChecked(IsShown() and 1 or nil)
        end
        unlock:SetChecked(Runtime.IsEditing() and 1 or nil)
        grid:SetChecked(store and store.editorOptions.showGrid and 1 or nil); anchors:SetChecked(store and store.editorOptions.showAnchors and 1 or nil)
        UI.Settings.SetCheckboxEnabled(unlock, Runtime.IsAvailable() and Bars.Core.Engine.GetState().active == true)
        UI.Settings.SetCheckboxEnabled(grid, store ~= nil); UI.Settings.SetCheckboxEnabled(anchors, store ~= nil)
        UI.Settings.SetCheckboxEnabled(show, Runtime.IsAvailable()); UI.Settings.SetCheckboxEnabled(useGlobal, Runtime.IsAvailable())
        owner:OnResize()
    end
    function view:Show() frame:Show(); self:Refresh(); return true end
    function view:Hide()
        local ok, failure = appearance:Close(); frame:Hide(); return ok, failure
    end
    frame:SetScript("OnHide", function() appearance:Close() end)
    owner.barButtons, owner.showBarCheckbox, owner.useGlobalCheckbox = view.buttons, show, useGlobal
    owner.editCheckbox, owner.showGridCheckbox, owner.showAnchorsCheckbox = unlock, grid, anchors
    owner.scaleSlider, owner.columnsSlider, owner.spacingSlider = view.sliders.scalePct, view.sliders.columns, view.sliders.spacing
    owner.titleCheckbox, owner.hotkeysCheckbox, owner.countsCheckbox = view.checks.showTitle, view.checks.showHotkeys, view.checks.showCounts
    owner.macroNamesCheckbox, owner.emptyButtonsCheckbox = view.checks.showMacroNames, view.checks.showEmptyButtons
    owner.appearanceSliders, owner.resetLayoutButton = view.sliders, reset
    owner.visualSliders, owner.visualCheckboxes = appearance.sliders, appearance.checks
    owner.colorControls, owner.visualChoices = appearance.colors, appearance.choices
    view.visibility, view.inherited, view.settings, view.description = visibility, inherited, settings, description
    frame:Hide(); return view
end
