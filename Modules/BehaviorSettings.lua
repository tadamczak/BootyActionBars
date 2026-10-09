local Bars = BootyActionBars
local UI, Runtime = Bars.UI.Components, Bars.Core.Runtime
local Config = Bars.Services.BarConfig
local BehaviorSettings = {}
Bars.Modules.BehaviorSettings = BehaviorSettings
local MAX_RULES, MAX_CHOICES = 16, 12

local function Ordinary(id) return Config.ValidOrdinaryID(id) end
local function SameForm(left, right)
    return left.classToken == right.classToken and left.locale == right.locale and left.formName == right.formName
end
local function Condition(rule, catalog)
    if rule.condition == "stealth" then return "Stealth" end
    for _, form in ipairs(catalog) do if SameForm(rule, form) then return rule.formName end end
    return rule.formName .. " (unavailable: " .. rule.classToken .. "/" .. rule.locale .. ")"
end
local function Used(rules, except, condition, form)
    for index, rule in ipairs(rules) do
        if index ~= except and rule.condition == condition and (condition == "stealth" or SameForm(rule, form)) then return true end
    end
    return false
end
local function Conditions(rules, catalog, edited)
    local options, selected = {}, nil
    local rule = edited and rules[edited]
    if not Used(rules, edited, "stealth") then
        table.insert(options, {value = 1, text = "Stealth", condition = "stealth"})
        if rule and rule.condition == "stealth" then selected = 1 end
    end
    for index, form in ipairs(catalog) do
        if not Used(rules, edited, "form", form) then
            local option = {value = index + 1, text = form.formName, condition = "form",
                classToken = form.classToken, locale = form.locale, formName = form.formName}
            table.insert(options, option)
            if rule and rule.condition == "form" and SameForm(rule, form) then selected = option.value end
        end
    end
    if rule and rule.condition == "form" and not selected then
        local option = {value = table.getn(catalog) + 2, text = Condition(rule, catalog), condition = "form",
            classToken = rule.classToken, locale = rule.locale, formName = rule.formName}
        table.insert(options, option); selected = option.value
    end
    return options, selected or options[1] and options[1].value
end
local function Invoke(callback)
    local oldThis, oldEvent, oldArg = this, event, arg1
    local ok, failure = pcall(callback)
    this, event, arg1 = oldThis, oldEvent, oldArg
    return ok, failure
end

function BehaviorSettings.Create(parent, context)
    local function Available() return Runtime.IsAvailable() and (not context.IsAvailable or context.IsAvailable()) end
    local frame = UI.CreateContainer(nil, parent); frame.bootyTextSizeDelta = -2
    local view = {frame = frame, rows = {}, rules = {}, catalog = {}}
    local heading = UI.Settings.CreateSectionAccordion(frame, "Behaviors", 0, 0, 3, "list")
    local content = UI.CreateContainer(nil, frame)
    view.heading, view.content = heading, content
    view.expanded, view.content = true, content
    heading:SetExpanded(true); heading.label:SetText("-  Behaviors")
    heading:SetScript("OnClick", function()
        local ok, failure = view:Close(); if not ok then return context.Complete(false, failure) end
        view.expanded = not view.expanded
        heading:SetExpanded(view.expanded); heading.label:SetText((view.expanded and "-  " or "+  ") .. "Behaviors")
        return context.Complete(true)
    end)
    local help = UI.CreateComponentLabel(content, "First matching rule wins. Rules choose the actions shown on this bar.", "white")
    help:SetJustifyH("LEFT"); help:SetJustifyV("TOP")
    local status = UI.CreateComponentLabel(content, "No rules. The bar uses its normal actions.", "white")
    status:SetJustifyH("LEFT"); status:SetJustifyV("TOP")
    local add = UI.CreateButton(content, nil, "Add", 72, 24); UI.StyleActionButton(add)
    view.add, view.help, view.status = add, help, status
    local function Complete(ok, failure, skipRefresh) return context.Complete(ok, failure, skipRefresh) end
    local followingRow = UI.CreateContainer(nil, content); followingRow.babBaseHeight = 32
    local following = UI.Settings.CreateCheckbox(followingRow, 0, 0, "Follow client pages and forms", "mainBarFollowClient", nil,
        {ensure = function() end, get = Runtime.GetMainBarFollowClient, set = function(_, value)
            if context.GetSelection() ~= 1 or not frame:IsVisible() or not Available() then
                return Complete(false, "Choose the independent Main Action Bar.", true)
            end
            local closed, failure = view:Close(); if not closed then return Complete(false, failure) end
            if context.Prepare then
                closed, failure = context.Prepare(); if not closed then return Complete(false, failure) end
            end
            if context.GetSelection() ~= 1 or not frame:IsVisible() or not Available() then
                return Complete(false, "The selected action bar changed.", true)
            end
            return Complete(Runtime.SetMainBarFollowClient(value))
        end})
    followingRow.kind, followingRow.control = "check", following
    local followingHelp = UI.CreateComponentLabel(content,
        "Fallback when no custom rule matches: follow the game's pages, Stealth and forms. Turn off to use Main Action Bar slots 1-12.", "white")
    followingHelp:SetJustifyH("LEFT"); followingHelp:SetJustifyV("TOP")
    view.followingRow, view.followingCheckbox, view.followingHelp = followingRow, following, followingHelp
    local function Current(session)
        local runtimeState = Runtime.GetState()
        return view.session == session and frame:IsVisible() and context.GetSelection() == session.id
            and Available() and (runtimeState.host and runtimeState.host.window) == session.owner
    end
    local function HideChoices()
        local first
        if view.modal then
            for _, choice in ipairs({view.when, view.source}) do
                local ok, failure = Invoke(function() choice.panel:Hide() end)
                if not ok then first = first and first .. "; " .. tostring(failure) or tostring(failure) end
            end
        end
        return first == nil, first
    end
    function view:Close()
        self.session = nil
        local ok, failure = HideChoices()
        if self.modal then
            self.modal.onYes, self.modal.onNo = nil, nil
            local closed, reason = Invoke(function() self.modal:Hide() end)
            if not closed then ok, failure = false, failure and failure .. "; " .. tostring(reason) or tostring(reason) end
        end
        return ok, failure
    end
    local function Choices(control, options, selected)
        control.choices = options
        for index, button in ipairs(control.panel.options) do
            local option = options[index]
            if option then
                button.choiceValue, button.choiceText = option.value, option.text
                button:SetText(option.text); button:Show()
                if option.value == selected then control.label:SetText(option.text) end
            else button:Hide() end
        end
        control.panel:SetHeight(table.getn(options) * 22 + 14)
        control.panel:Hide()
    end
    local function CreateModal()
        if view.modal then return end
        local modal = UI.Window.CreateProjectConfirmation("BootyActionBarsBehaviorConfirmation", "Bar behavior", "Save", "link")
        modal.bootyTextSizeDelta = -2
        view.modal = modal
        local placeholders = {}
        for index = 1, MAX_CHOICES do placeholders[index] = {value = index, text = ""} end
        local function Choice(y, options, key)
            local _, control = UI.CreateChoiceField({parent = modal, x = 16, y = y, label = "", initialText = "",
                width = 288, height = table.getn(options) * 22 + 14, firstY = -7, step = 22, buttonOffset = 0,
                labelValue = true, choices = options,
                getValue = function() return view.session and view.session[key] end,
                onSelect = function(value) if view.session then view.session[key] = value end end})
            return control
        end
        view.when = Choice(-86, placeholders, "choice")
        local sources = {}
        for _, id in ipairs(Config.OrdinaryIDs) do table.insert(sources, {value = id, text = Config.Name(id)}) end
        view.source = Choice(-154, sources, "sourceBar")
        local whenLabel = UI.CreateComponentLabel(modal, "When", "white")
        whenLabel:SetPoint("TOPLEFT", modal, "TOPLEFT", 16, -62); whenLabel:SetWidth(288); whenLabel:SetHeight(18)
        local actionLabel = UI.CreateComponentLabel(modal, "Change to Action Bar", "white")
        actionLabel:SetPoint("TOPLEFT", modal, "TOPLEFT", 16, -130); actionLabel:SetWidth(288); actionLabel:SetHeight(18)
        local hide = modal:GetScript("OnHide")
        modal:SetScript("OnHide", function()
            local session = view.session
            if not session or not session.accepting then view.session = nil end
            local ok, failure = HideChoices()
            if hide then hide() end
            if not ok then error(failure) end
        end)
        local yes = modal.yes:GetScript("OnClick")
        modal.yes:SetScript("OnClick", function()
            local session = view.session
            if session then session.accepting = true end
            -- Project confirmation hides before invoking Save. Only this intentional
            -- hide preserves the captured draft; all other closes invalidate it.
            local ok, failure = Invoke(yes)
            if view.session == session then view.session = nil end
            if not ok then
                local closed, reason = view:Close()
                if not closed then failure = tostring(failure) .. "; Close: " .. tostring(reason) end
                Complete(false, tostring(failure))
            end
        end)
    end
    function view:Open(index)
        local closed, failure = self:Close(); if not closed then return Complete(false, failure) end
        if context.Prepare then
            local ok, reason = context.Prepare(); if not ok then return Complete(false, reason) end
        end
        local id = context.GetSelection()
        if not Ordinary(id) or not frame:IsVisible() or not Available() then return false, "Choose an independent action bar." end
        local runtimeState = Runtime.GetState()
        local owner = runtimeState.host and runtimeState.host.window
        local token, tokenFailure = Runtime.CaptureBarBehaviors(id)
        if not token then return Complete(false, tokenFailure) end
        local rules, reason = Runtime.GetBarBehaviors(id)
        if not rules then return Complete(false, reason) end
        if index and not rules[index] then return Complete(false, "The rule changed. Open it again.") end
        if not index and table.getn(rules) >= MAX_RULES then return Complete(false, "A bar can have at most 16 rules.") end
        local catalog, catalogFailure = Runtime.GetBehaviorCatalog()
        if not catalog then return Complete(false, catalogFailure) end
        local rule = index and rules[index]
        local options, selected = Conditions(rules, catalog, index)
        if not selected then return Complete(false, "All available conditions are already configured.") end
        local session = {id = id, index = index, token = token, choice = selected, sourceBar = rule and rule.sourceBar or 1,
            owner = owner, options = options, byValue = {}}
        for _, option in ipairs(options) do session.byValue[option.value] = option end
        if table.getn(session.options) > MAX_CHOICES then return Complete(false, "The form catalog exceeds the client limit.") end
        runtimeState = Runtime.GetState()
        if not frame:IsVisible() or context.GetSelection() ~= id or (runtimeState.host and runtimeState.host.window) ~= owner then
            return Complete(false, "The selected bar changed. Open the rule again.", true)
        end
        CreateModal(); self.session = session
        if UI.WindowStack then UI.WindowStack.SetOwner(self.modal, session.owner) end
        Choices(self.when, session.options, session.choice); Choices(self.source, self.source.choices, session.sourceBar)
        self.modal:Open(Config.Name(id), function()
            if not Current(session) then
                if self.session == session then self.session = nil end
                return Complete(false, "The selected bar changed. Open the rule again.", true)
            end
            local option = session.byValue[session.choice]
            self.session = nil
            if not option then return Complete(false, "Choose a condition.") end
            local value = {condition = option.condition, sourceBar = session.sourceBar}
            if option.condition == "form" then
                value.classToken, value.locale, value.formName = option.classToken, option.locale, option.formName
            end
            return Complete(Runtime.SetBarBehavior(session.id, session.index, value, session.token))
        end)
        self.modal.label:ClearAllPoints(); self.modal.label:SetPoint("TOPLEFT", self.modal, "TOPLEFT", 16, -38)
        self.modal.label:SetWidth(288); self.modal.label:SetHeight(18); self.modal:SetHeight(222)
        return true
    end
    local function Change(index, destination)
        local id = context.GetSelection()
        if not Ordinary(id) or not frame:IsVisible() then return false, "Choose an action bar." end
        local closed, failure = view:Close(); if not closed then return Complete(false, failure) end
        local token = view.token
        if not token then return Complete(false, "The rules changed. Refresh the selected bar.") end
        if destination then return Complete(Runtime.MoveBarBehavior(id, index, destination, token)) end
        return Complete(Runtime.RemoveBarBehavior(id, index, token))
    end
    local tableHead = UI.CreateContainer(nil, content); tableHead:SetHeight(22)
    local headers = {
        UI.Table.CreateHeader(tableHead, {}, "Condition", 0, 0, 140, "condition", false),
        UI.Table.CreateHeader(tableHead, {}, "Change to", 140, 0, 140, "action", false),
        UI.Table.CreateHeader(tableHead, {}, "Actions", 280, 0, 160, "controls", false),
    }
    local function Row(index)
        local row = UI.CreateControl(nil, content)
        UI.ApplyDropdownChoiceSurface(row); UI.ApplyRowBackground(row, index, false)
        row.label = UI.CreateComponentLabel(row, "", "white"); row.label:SetJustifyH("LEFT"); row.label:SetJustifyV("TOP")
        row.sourceLabel = UI.CreateComponentLabel(row, "", "white"); row.sourceLabel:SetJustifyH("LEFT"); row.sourceLabel:SetJustifyV("TOP")
        row.actions = UI.CreateContainer(nil, row); row.buttons = {}
        for _, definition in ipairs({{"Edit", 44}, {"Remove", 58}, {"up", 20}, {"down", 20}}) do
            local arrow = definition[1] == "up" or definition[1] == "down"
            local button = arrow and UI.CreateArrowButton(row.actions, definition[1]) or UI.CreateButton(row.actions, nil, definition[1], definition[2], 24)
            if not arrow then UI.StyleActionButton(button) end
            button.bootyFlowWidth = definition[2]; table.insert(row.buttons, button)
        end
        row.edit, row.remove, row.up, row.down = row.buttons[1], row.buttons[2], row.buttons[3], row.buttons[4]
        row.edit:SetScript("OnClick", function() view:Open(index) end)
        row.remove:SetScript("OnClick", function() Change(index) end)
        row.up:SetScript("OnClick", function() Change(index, index - 1) end)
        row.down:SetScript("OnClick", function() Change(index, index + 1) end)
        view.rows[index] = row; return row
    end
    add:SetScript("OnClick", function() view:Open() end)
    function view:Refresh()
        local id = context.GetSelection()
        if not Ordinary(id) then self:Close(); frame:Hide(); return true end
        frame:Show()
        if id == 1 then
            followingRow:Show(); followingHelp:Show()
            following:SetChecked(Runtime.GetMainBarFollowClient() and 1 or nil)
            UI.Settings.SetCheckboxEnabled(following, Available())
            help:SetText("First matching custom rule wins. If none matches, the built-in fallback below chooses the actions.")
        else
            followingRow:Hide(); followingHelp:Hide()
            help:SetText("First matching rule wins. If none matches, this bar uses its fixed action slots.")
        end
        local token, tokenFailure = Runtime.CaptureBarBehaviors(id)
        local rules, failure = Runtime.GetBarBehaviors(id)
        local catalog, catalogFailure = Runtime.GetBehaviorCatalog()
        self.token = token
        self.failure = failure or not catalog and catalogFailure or not token and tokenFailure or nil
        self.rules, self.catalog = rules or {}, catalog or {}
        local count = table.getn(self.rules)
        local available = Conditions(self.rules, self.catalog)
        if self.failure or count == 0 or table.getn(available) == 0 then
            status:SetText(self.failure or (count == 0 and (id == 1 and "No custom rules." or "No rules. The bar uses its fixed action slots.")
                or "All available conditions are already configured.")); status:Show()
        else status:Hide() end
        for index = 1, math.min(MAX_RULES, count) do
            local row = self.rows[index] or Row(index)
            local source = self.rules[index].sourceBar
            row.label:SetText(index .. ". " .. Condition(self.rules[index], self.catalog))
            row.sourceLabel:SetText(Config.Name(source))
            row:Show()
            UI.SetButtonEnabled(row.edit, Available()); UI.SetButtonEnabled(row.remove, Available())
            UI.SetButtonEnabled(row.up, Available() and index > 1)
            UI.SetButtonEnabled(row.down, Available() and index < count)
        end
        for index = count + 1, table.getn(self.rows) do self.rows[index]:Hide() end
        UI.SetButtonEnabled(add, Available() and not self.failure and count < MAX_RULES and table.getn(available) > 0)
        return self.failure == nil, self.failure
    end
    function view:Measure(width)
        heading:ClearAllPoints(); heading:SetPoint("TOPLEFT", frame, "TOPLEFT", 0, 0); heading:SetWidth(width); heading:SetHeight(24)
        if not self.expanded then content:Hide(); frame:SetHeight(24); return 24 end
        content:Show(); content:ClearAllPoints(); content:SetPoint("TOPLEFT", frame, "TOPLEFT", 0, -24); content:SetWidth(width)
        help:ClearAllPoints(); help:SetPoint("TOPLEFT", content, "TOPLEFT", 0, 0)
        help:SetWidth(width); help:SetHeight(UI.MeasureTextHeight(help, width))
        local top = help:GetHeight() + 8
        if status:IsShown() then
            status:ClearAllPoints(); status:SetPoint("TOPLEFT", content, "TOPLEFT", 0, -top)
            status:SetWidth(width); status:SetHeight(UI.MeasureTextHeight(status, width)); top = top + status:GetHeight() + 8
        end
        if followingRow:IsShown() then
            top = top + Bars.Modules.AppearanceSettings.LayoutRow(followingRow, content, 0, -top, width) + 4
            followingHelp:ClearAllPoints(); followingHelp:SetPoint("TOPLEFT", content, "TOPLEFT", 0, -top)
            followingHelp:SetWidth(width); followingHelp:SetHeight(UI.MeasureTextHeight(followingHelp, width))
            top = top + followingHelp:GetHeight() + 8
        end
        add:ClearAllPoints(); add:SetPoint("TOPLEFT", content, "TOPLEFT", 0, -top); add:SetWidth(math.min(72, width))
        top = top + add:GetHeight() + 8
        local inline = width >= 380
        local actionWidth, textWidth = 158, inline and width - 166 or width
        local columnWidth = math.max(1, (textWidth - 8) / 2)
        tableHead:ClearAllPoints(); tableHead:SetPoint("TOPLEFT", content, "TOPLEFT", 0, -top); tableHead:SetWidth(width)
        for index, header in ipairs(headers) do
            header:ClearAllPoints(); header:SetPoint("TOPLEFT", tableHead, "TOPLEFT", index == 1 and 0 or index == 2 and columnWidth + 8 or textWidth + 8, 0)
            header:SetWidth(index == 3 and actionWidth or columnWidth)
            if index == 3 and not inline then header:Hide() else header:Show() end
        end
        top = top + 26
        for _, row in ipairs(self.rows) do
            if row:IsShown() then
                row:ClearAllPoints(); row:SetPoint("TOPLEFT", content, "TOPLEFT", 0, -top); row:SetWidth(width)
                local labelWidth = columnWidth
                row.label:SetWidth(labelWidth); row.label:SetHeight(UI.MeasureTextHeight(row.label, labelWidth))
                row.label:ClearAllPoints(); row.label:SetPoint("TOPLEFT", row, "TOPLEFT", 0, 0)
                row.sourceLabel:SetWidth(labelWidth); row.sourceLabel:SetHeight(UI.MeasureTextHeight(row.sourceLabel, labelWidth))
                row.sourceLabel:ClearAllPoints(); row.sourceLabel:SetPoint("TOPLEFT", row, "TOPLEFT", columnWidth + 8, 0)
                local actionHeight = UI.LayoutFlow(row.actions, row.buttons, 0, 0, actionWidth, 4)
                row.actions:SetWidth(actionWidth); row.actions:SetHeight(actionHeight); row.actions:ClearAllPoints()
                row.actions:SetPoint("TOPLEFT", row, "TOPLEFT", inline and width - actionWidth or 0, inline and 0 or -(math.max(row.label:GetHeight(), row.sourceLabel:GetHeight()) + 4))
                row:SetHeight((inline and math.max(row.label:GetHeight(), row.sourceLabel:GetHeight(), actionHeight)
                    or math.max(row.label:GetHeight(), row.sourceLabel:GetHeight()) + 4 + actionHeight) + 10)
                top = top + row:GetHeight()
            end
        end
        content:SetHeight(top + 10); frame:SetHeight(top + 34); return frame:GetHeight()
    end
    frame:SetScript("OnHide", function() local ok, failure = view:Close(); if not ok then error(failure) end end)
    frame:Hide(); return view
end
