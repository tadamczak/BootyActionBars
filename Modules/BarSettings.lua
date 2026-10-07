local Bars = BootyActionBars
local UI, Runtime = Bars.UI.Components, Bars.Core.Runtime
local BarSettings = {}
Bars.Modules.BarSettings = BarSettings
local Utility = Bars.Services.UtilityLayout
local sliders = {{"scalePct", "Scale (%)", 50, 200}, {"columns", "Columns", 1, 12},
    {"spacing", "Spacing", 0, 20}, {"buttonSize", "Button size", 24, 64},
    {"iconInset", "Icon inset", 0, 8}, {"opacityPct", "Opacity (%)", 20, 100}, {"labelFontSize", "Label size", 8, 16}}
local checks = {{"showTitle", "Title"}, {"showHotkeys", "Hotkeys"}, {"showCounts", "Counts"},
    {"showMacroNames", "Macro names"}, {"showEmptyButtons", "Empty buttons"}}
local identities = {"layout", "global", 1, 2, 3, 4, 5, 6, 7, 8}
if Utility then for _, id in ipairs(Utility.Keys) do table.insert(identities, id) end end
local function IsUtility(id) return Utility and Utility.ValidID(id) end
local function Name(id)
    return id == "layout" and "Layout" or id == "global" and "Global Settings"
        or id == 1 and "Main Action Bar" or id == 7 and "Pet Bar" or id == 8 and "Forms / stances"
        or IsUtility(id) and Utility.Name(id) or "Action Bar " .. id
end
local function SelectListedBar()
    local view = this.barSettingsView
    local ok, failure = view:Select(this.barSelectionId)
    if not ok then view.Complete(ok, failure, true) end
    return ok, failure
end
function BarSettings.Create(parent, host, owner)
    local frame = UI.CreateContainer(nil, parent); frame:SetAllPoints(parent); frame.mosTextSizeDelta = -2
    local left, right = UI.CreateContainer(nil, frame), UI.CreateContainer(nil, frame)
    local list = UI.CreateResponsiveCanvas(left, "BootyActionBarsBarListScroll")
    local canvas = UI.CreateResponsiveCanvas(right, "BootyActionBarsBarSettingsScroll")
    local view = {frame = frame, canvas = canvas, selected = "layout", buttons = {}, sliders = {}, checks = {}, rows = {}, sections = {}}
    local title = UI.CreateHeading(canvas, "Layout", 2, "gold")
    local description = UI.CreateComponentLabel(canvas, "", "white"); description:SetJustifyH("LEFT"); description:SetJustifyV("TOP")
    local tools, settings = UI.CreateContainer(nil, canvas), UI.CreateContainer(nil, canvas)
    local visibility, inherited = UI.CreateContainer(nil, canvas), UI.CreateContainer(nil, canvas)
    local function Complete(ok, failure, skipRefresh) return owner.Complete(ok, failure, skipRefresh) end
    view.Complete = Complete
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
        if type(view.selected) ~= "number" then return false, "Choose an action bar or Global Settings." end
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
    local toolChecks = {unlock, grid, anchors}
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
        if type(id) ~= "number" then return false, "Choose an action bar." end
        if id == 1 then return Runtime.SetMainBarShown(value) end
        if id >= 7 then return Runtime.SetSpecialBar(id == 7 and "pet" or "stance", value) end
        return Runtime.SetCustomBar(id, value)
    end)
    local useGlobal = Checkbox(inherited, "Use Global Settings", "useGlobalLayout", function()
        local layout = GetLayout(); return layout and layout.useGlobalLayout == true
    end, function(value)
        if type(view.selected) ~= "number" then return false, "Choose an action bar." end
        return Runtime.SetUseGlobalLayout(view.selected, value)
    end)
    local reset = UI.CreateButton(canvas, nil, "Reset local layout", 136, 24); UI.StyleActionButton(reset)
    reset:SetScript("OnClick", function()
        if type(view.selected) ~= "number" then return Complete(false, "Choose an action bar.") end
        return Complete(Runtime.ResetBarLayout(view.selected))
    end)
    UI.AttachTooltip(reset, "Reset local layout", "Reset position and individual layout. Global choice, actions and keys are retained.")
    local section
    local function AddSection(value)
        value.items = {mosMaxColumns = 3, mosMeasureItem = Bars.Modules.AppearanceSettings.MeasureRow,
            mosLayoutItem = Bars.Modules.AppearanceSettings.LayoutRow}
        table.insert(view.sections, value); table.insert(view.rows, value.heading)
        for _, row in ipairs(value.rows) do table.insert(view.rows, row) end
    end
    local function Section(caption)
        local row = UI.CreateContainer(nil, settings); row:SetHeight(24)
        row.control = UI.CreateHeading(row, caption, 3, "gold")
        row.control:SetPoint("TOPLEFT", row, "TOPLEFT", 0, -3); row.control:SetHeight(16)
        row.kind = "heading"; section = {caption = caption, heading = row, rows = {}}
        AddSection(section)
    end
    for _, definition in ipairs(sliders) do
        local key, caption, minimum, maximum = definition[1], definition[2], definition[3], definition[4]
        if key == "scalePct" then Section("Geometry") elseif key == "buttonSize" then Section("Appearance") end
        local row = UI.CreateContainer(nil, settings); row:SetHeight(44)
        local slider = UI.Settings.CreateSlider(row, "BootyActionBarsLayout" .. key, 0, -15, caption, key, minimum, maximum, nil,
            {ensure = function() end, get = function() local layout = GetLayout(); return layout and layout[key] or minimum end,
                set = function(_, value) Complete(SetPreference(key, value)) end})
        row.control, row.key, row.kind, row.babBaseHeight = slider, key, "slider", 44
        table.insert(section.rows, row); table.insert(view.rows, row); view.sliders[key] = slider
    end
    local appearance = Bars.Modules.AppearanceSettings.Create(settings, {
        GetLayout = GetLayout, GetSelection = function() return view.selected end,
        SetPreference = SetPreference, Complete = Complete, IsAvailable = Runtime.IsAvailable,
        SetColor = function(id, group, rgba)
            if id == "global" then return Runtime.SetGlobalColor(group, rgba) end
            return Runtime.SetBarColor(id, group, rgba)
        end,
    })
    AddSection(appearance.sections[1])
    Section("Labels and slots")
    for _, definition in ipairs(checks) do
        local key, caption = definition[1], definition[2]
        local row = UI.CreateContainer(nil, settings); row:SetHeight(32)
        local check = Checkbox(row, caption, key, function() local layout = GetLayout(); return layout and layout[key] == true end,
            function(value) return SetPreference(key, value) end)
        row.control, row.key, row.kind, row.babBaseHeight = check, key, "check", 32
        table.insert(section.rows, row); table.insert(view.rows, row); view.checks[key] = check
    end
    for index = 2, table.getn(appearance.sections) do AddSection(appearance.sections[index]) end
    view.appearance = appearance
    local behaviors = Bars.Modules.BehaviorSettings.Create(canvas, {
        GetSelection = function() return view.selected end, Complete = Complete,
        Prepare = function() return appearance:Close() end,
    })
    view.behaviors = behaviors
    local utility = Utility and Bars.Modules.UtilitySettings.Create(canvas, {GetSelection = function() return view.selected end, Complete = Complete})
    view.utility, owner.utilitySettings = utility, utility
    for _, id in ipairs(identities) do
        local button = UI.CreateSelectionButton(list, nil, Name(id), 124, 26); UI.SetButtonLabelInsets(button, 8, 4)
        button.barSettingsView, button.barSelectionId = view, id
        button:SetScript("OnClick", SelectListedBar); view.buttons[id] = button
    end
    local function MeasureList(width)
        local columns = view.compact and 2 or 1
        local columnWidth = math.max(1, (width - (columns - 1) * 4) / columns)
        for index, id in ipairs(identities) do
            local button = view.buttons[id]; button:SetWidth(math.max(1, columnWidth - 4))
            button.label:SetText(Name(id))
            button:ClearAllPoints(); button:SetPoint("TOPLEFT", list, "TOPLEFT", math.mod(index - 1, columns) * (columnWidth + 4), -math.floor((index - 1) / columns) * 30)
        end
        return math.ceil(table.getn(identities) / columns) * 30
    end
    local function Place(region, width, top)
        region:ClearAllPoints(); region:SetPoint("TOPLEFT", canvas, "TOPLEFT", 12, -top); region:SetWidth(width)
        return top + region:GetHeight()
    end
    local function MeasureCheckbox(control, width)
        local labelWidth = math.max(1, width - control:GetWidth() - 7)
        control.label:SetWidth(labelWidth)
        local labelHeight = UI.MeasureTextHeight(control.label, labelWidth)
        control.label:SetHeight(labelHeight); control.label:ClearAllPoints()
        if labelHeight > control:GetHeight() then control.label:SetPoint("TOPLEFT", control, "TOPRIGHT", 6, 0)
        else control.label:SetPoint("LEFT", control, "RIGHT", 6, 0) end
        if control.labelHit then
            control.labelHit:SetWidth(labelWidth + 5); control.labelHit:SetHeight(math.max(control:GetHeight(), labelHeight))
            control.labelHit:ClearAllPoints()
            if labelHeight > control:GetHeight() then control.labelHit:SetPoint("TOPLEFT", control, "TOPRIGHT", 1, 0)
            else control.labelHit:SetPoint("LEFT", control, "RIGHT", 1, 0) end
        end
        return math.max(32, labelHeight + 4)
    end
    local function Measure(width)
        local usable = math.max(1, width - 24)
        title:SetHeight(24); Place(title, usable, 8)
        description:SetHeight(UI.MeasureTextHeight(description, usable)); local top = Place(description, usable, 40) + 16
        if view.selected == "layout" then
            local height = 0
            for _, check in ipairs(toolChecks) do
                check:ClearAllPoints(); check:SetPoint("TOPLEFT", tools, "TOPLEFT", 0, -height)
                height = height + MeasureCheckbox(check, usable)
            end
            tools:SetHeight(height); return Place(tools, usable, top) + 12
        end
        if IsUtility(view.selected) then
            if utility.frame:IsShown() then utility:Layout(usable); top = Place(utility.frame, usable, top) + 8 end
            return top + 12
        end
        if view.selected ~= "global" then
            visibility:SetHeight(MeasureCheckbox(show, usable)); inherited:SetHeight(MeasureCheckbox(useGlobal, usable))
            top = Place(visibility, usable, top) + 6; top = Place(inherited, usable, top) + 8
        end
        if behaviors.frame:IsShown() then behaviors:Measure(usable); top = Place(behaviors.frame, usable, top) + 8 end
        if settings:IsShown() then
            local content = 0
            for _, group in ipairs(view.sections) do
                local items = group.items
                while table.getn(items) > 0 do table.remove(items) end
                for _, row in ipairs(group.rows) do if row:IsShown() then table.insert(items, row) end end
                if table.getn(items) > 0 then
                    local heading = group.heading
                    heading:ClearAllPoints(); heading:SetPoint("TOPLEFT", settings, "TOPLEFT", 0, -content); heading:SetWidth(usable)
                    heading.control:SetWidth(usable)
                    content = content + heading:GetHeight()
                    content = content + UI.Settings.LayoutGrid(settings, items, 0, -content, usable, 0)
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
        local listWidth = view.compact and math.max(1, width - 16) or width < 440 and 120 or 152
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
        closed, failure = behaviors:Close(); if not closed then return false, failure end
        self.selected = id; if type(id) == "number" then owner.selectedBar = id end
        self:Refresh(); return true
    end
    function view:Refresh()
        if not frame:IsVisible() then return end
        local id, store = self.selected, Bars.Database.Ensure()
        local isLayout, isGlobal, isUtility = id == "layout", id == "global", IsUtility(id)
        for key, button in pairs(self.buttons) do UI.StyleWarmListRow(button, key == id) end
        title:SetText(Name(id))
        description:SetText(isLayout and "Unlock to position bars. Show anchors also reveals hidden bars."
            or isGlobal and "Shared appearance for bars using Global Settings. Each bar keeps its own position."
            or isUtility and "Position and scale these native controls separately. Their original actions keep working."
            or id == 1 and "Actions follow the page or form. Hiding this bar keeps other bars active."
            or type(id) == "number" and id >= 7 and "Shown when a pet or form is available. Use Layout and Show anchors to position it while absent."
            or "Actions use fixed slots. Hiding preserves layout, actions and keys.")
        if isLayout then tools:Show() else tools:Hide() end
        behaviors:Refresh()
        if not isLayout and not isGlobal and not isUtility then visibility:Show(); inherited:Show(); reset:Show()
        else visibility:Hide(); inherited:Hide(); reset:Hide() end
        if utility then if isUtility then utility:Refresh() else utility:Hide() end end
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
            show.label:SetText("Show " .. Name(id))
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
        local ok, failure = appearance:Close()
        local closed, reason = behaviors:Close()
        if not closed then ok, failure = false, failure and failure .. "; " .. tostring(reason) or reason end
        frame:Hide(); return ok, failure
    end
    frame:SetScript("OnHide", function()
        local ok, failure = appearance:Close()
        local closed, reason = behaviors:Close()
        if not closed then ok, failure = false, failure and failure .. "; " .. tostring(reason) or reason end
        if not ok then error(failure) end
    end)
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
