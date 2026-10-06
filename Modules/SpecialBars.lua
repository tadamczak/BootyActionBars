local Bars = BootyActionBars
local UI = Bars.UI.Components
local Special = {}
Bars.Modules.SpecialBars = Special
local state = {active = false, editing = false, configured = {}, views = {}, visibleCount = 0}
local owners = {pet = {id = 7, kind = "pet", subscriptions = {}}, stance = {id = 8, kind = "stance", subscriptions = {}}}
local kinds = {"pet", "stance"}
local availability = {
    pet = {"PLAYER_ENTERING_WORLD", "UNIT_PET", "PET_BAR_UPDATE", "PLAYER_CONTROL_LOST", "PLAYER_CONTROL_GAINED",
        "PLAYER_FARSIGHT_FOCUS_CHANGED"},
    stance = {"PLAYER_ENTERING_WORLD", "UPDATE_SHAPESHIFT_FORMS"},
}
local transient = {
    pet = {"PET_BAR_UPDATE_COOLDOWN", "UNIT_FLAGS", "UNIT_AURA", "UPDATE_BINDINGS"},
    stance = {"SPELL_UPDATE_COOLDOWN", "SPELL_UPDATE_USABLE", "PLAYER_AURAS_CHANGED", "UPDATE_INVENTORY_ALERTS", "UPDATE_BINDINGS"},
}
local Sync, Refresh, StopKind, Remove
local function Run(callback, first, second, third, fourth)
    local previousThis, previousEvent, previousArg = this, event, arg1
    local ran, result, failure = pcall(callback, first, second, third, fourth)
    this, event, arg1 = previousThis, previousEvent, previousArg
    if not ran then return false, tostring(result) end
    if result == false then return false, failure or "A special action bar operation was declined." end
    return true, result, failure
end
local function Report(message)
    message = tostring(message)
    if state.failure ~= message then BootyLib.Print("BootyActionBars: " .. message) end
    state.failure = message
end
local function Press(button)
    if button.mousePressed then button.pressFeedback:Show() else button.pressFeedback:Hide() end
end
local function ClearTooltip(button)
    if GameTooltip and GameTooltip.IsOwned and GameTooltip:IsOwned(button) then GameTooltip:Hide() end
end
local function Cancel(button)
    if button.mouseHeld then button.skipClick = true end
    button.mousePressed, button.mouseHeld = false, false
    button.pressFeedback:Hide(); button.hoverFeedback:Hide(); ClearTooltip(button)
    return true
end
local function VisibleSlot(button)
    local owner = owners[button.bar.kind]
    return state.active and state.configured[owner.kind] and owner.visible
        and button.index <= button.bar.count and button.bar.frame:IsVisible()
end
local function InputAvailable(button) return VisibleSlot(button) and button.hasAction end
local function Use(button, mouseButton)
    if not InputAvailable(button) then return false end
    this = button
    local ok, failure = button.bar.service.Use(button.index, mouseButton)
    if not ok then return false, failure end
    return Refresh(owners[button.bar.kind], "ReadState")
end
local function Click()
    local button, mouseButton = this, arg1
    button:SetChecked(button.rendered.current and 1 or 0)
    button.mousePressed, button.mouseHeld = false, false; Press(button)
    local skipped = button.skipClick; button.skipClick = nil
    if skipped then return end
    local ok, failure = Run(Use, button, mouseButton)
    if not ok then Report(failure) end
end
local function MouseDown()
    if not VisibleSlot(this) then return end
    if arg1 == "LeftButton" or arg1 == "RightButton" then
        this.skipClick = nil; this.mouseHeld, this.mousePressed = true, true; Press(this)
    end
end
local function MouseUp() this.mouseHeld, this.mousePressed = false, false; Press(this) end
local function Tooltip(button)
    if not InputAvailable(button) then return true end
    this = button
    return button.bar.service.Tooltip(button.index, button)
end
local function Enter()
    local button = this
    if not VisibleSlot(button) then return end
    button.hoverFeedback:Show()
    local ok, failure = Run(Tooltip, button)
    if not ok then Report(failure) end
end
local function Leave()
    this.hoverFeedback:Hide(); this.mousePressed = false; Press(this); ClearTooltip(this)
end
local function Drag(button, placing)
    if not VisibleSlot(button) or not placing and not button.hasAction or button.bar.kind ~= "pet" then return true end
    if not placing and type(IsShiftKeyDown) == "function" then
        local shift = IsShiftKeyDown()
        if not shift or shift == 0 then return true end
    end
    button.skipClick = true; Cancel(button)
    this = button
    local service = button.bar.service
    local ok, failure
    if placing then ok, failure = service.Place(button.index) else ok, failure = service.Pickup(button.index) end
    if not ok then return false, failure end
    return Refresh(owners.pet, "Read")
end
local function Pickup() local ok, failure = Run(Drag, this, false); if not ok then Report(failure) end end
local function Place() local ok, failure = Run(Drag, this, true); if not ok then Report(failure) end end
local function Hotkey(button, key)
    local previousEvent, previousArg = event, arg1
    local text = key and (type(GetBindingText) == "function" and GetBindingText(key, "KEY_", 1) or key) or ""
    this, event, arg1 = button, previousEvent, previousArg
    button.hotkey:SetText(text)
end
local function Binding(button)
    local previousEvent, previousArg = event, arg1
    this = button
    local key = button.bar.service.GetBindingKeys(button.index)
    this, event, arg1 = button, previousEvent, previousArg
    if button.bindingKey ~= key or not button.bar.displayReady then
        button.bindingKey = key
        if button.bar.showHotkeys then Hotkey(button, key) end
    end
    return true
end
local function Render(button, data, force)
    local old = button.rendered
    button.hasAction = data.hasAction
    if force or old.texture ~= data.texture then button.icon:SetTexture(data.texture); old.texture = data.texture end
    if force or old.usable ~= data.usable or old.noMana ~= data.noMana then
        if data.usable then button.icon:SetVertexColor(1, 1, 1)
        elseif data.noMana then button.icon:SetVertexColor(0.5, 0.5, 1)
        else button.icon:SetVertexColor(0.3, 0.3, 0.3) end
        old.usable, old.noMana = data.usable, data.noMana
    end
    if force or old.current ~= data.current then button:SetChecked(data.current and 1 or 0); old.current = data.current end
    if force or old.autocastEnabled ~= data.autocastEnabled then
        if data.autocastEnabled then button.autocast:Show() else button.autocast:Hide() end
        old.autocastEnabled = data.autocastEnabled
    end
    if force or old.start ~= data.cooldownStart or old.duration ~= data.cooldownDuration or old.enabled ~= data.cooldownEnabled then
        CooldownFrame_SetTimer(button.cooldown, data.cooldownStart, data.cooldownDuration, data.cooldownEnabled and 1 or 0)
        old.start, old.duration, old.enabled = data.cooldownStart, data.cooldownDuration, data.cooldownEnabled
    end
    if GameTooltip and GameTooltip.IsOwned and GameTooltip:IsOwned(button) then
        if data.hasAction then return Tooltip(button) else GameTooltip:Hide() end
    end
    return true
end
local function ReadButton(button, category, force)
    local previousEvent, previousArg = event, arg1
    this = button
    local data, failure = button.bar.service[category](button.index, button.read)
    if not data then return false, failure end
    this, event, arg1 = button, previousEvent, previousArg
    return Render(button, data, force)
end
local function Hidden()
    local view = this.bar
    local owner = owners[view.kind]
    if owner.visible then owner.visible = false; state.visibleCount = state.visibleCount - 1 end
    local ok, failure = view:Suspend()
    local removed, reason = Remove(owner, transient[owner.kind])
    if not removed and ok then ok, failure = false, reason end
    if Bars.Modules.Editor then
        local ended, reason = Run(Bars.Modules.Editor.OnBarHidden, view.id)
        if not ended and ok then ok, failure = false, reason end
    end
    if not ok then Report(failure) end
end
local function Shown()
    local view = this.bar
    local owner = owners[view.kind]
    if owner.syncing then return end
    if not state.active or not state.configured[owner.kind] then view:Hide(); return end
    local ok, failure = Run(Sync, owner)
    if not ok then StopKind(owner, true); Report(failure) end
end
local function Create(owner)
    if state.views[owner.id] then return state.views[owner.id] end
    local name = owner.kind == "pet" and "BootyActionBarsPetBar" or "BootyActionBarsStanceBar"
    local frame = UI.CreateContainer(name, UIParent)
    local view = {id = owner.id, kind = owner.kind, frame = frame, buttons = {}, count = 0,
        showTitle = true, showHotkeys = true, showCounts = true, displayReady = true, service = owner.service}
    state.views[owner.id] = view; frame.bar = view
    frame:SetMovable(true)
    if frame.SetDontSavePosition then frame:SetDontSavePosition(true) end
    if frame.SetUserPlaced then frame:SetUserPlaced(false) end
    if frame.SetClampedToScreen then frame:SetClampedToScreen(true) end
    frame:SetWidth(436); frame:SetHeight(40)
    frame:SetPoint("CENTER", UIParent, "CENTER", 0, owner.kind == "pet" and -260 or -320)
    frame:Hide()
    view.title = UI.CreateComponentLabel(frame, owner.kind == "pet" and "Pet actions" or "Stances and forms", "white")
    view.title:SetPoint("BOTTOM", frame, "TOP", 0, 8); view.title:SetWidth(436); view.title:SetHeight(20)
    for index = 1, 10 do
        local buttonName = name .. "Button" .. index
        local button = UI.CreateCheckButton(buttonName, frame)
        view.buttons[index] = button; button.bar, button.index = view, index
        button:SetID(index); button:SetWidth(40); button:SetHeight(40)
        button:SetPoint("LEFT", frame, "LEFT", (index - 1) * 44, 0)
        UI.StyleButton(button, ""); button.label:Hide(); UI.SetProjectButtonOutline(button, true)
        button:SetCheckedTexture("Interface\\Buttons\\CheckButtonHilight")
        button.icon = UI.CreateTexture(button, buttonName .. "Icon", "ARTWORK")
        button.icon:SetPoint("TOPLEFT", button, "TOPLEFT", 4, -4)
        button.icon:SetPoint("BOTTOMRIGHT", button, "BOTTOMRIGHT", -4, 4)
        button.hoverFeedback = UI.CreateTexture(button, nil, "OVERLAY")
        button.hoverFeedback:SetAllPoints(button.icon)
        button.hoverFeedback:SetTexture("Interface\\Buttons\\ButtonHilight-Square")
        button.hoverFeedback:SetBlendMode("ADD"); button.hoverFeedback:SetAlpha(0.6); button.hoverFeedback:Hide()
        button.pressFeedback = UI.CreateTexture(button, nil, "OVERLAY")
        button.pressFeedback:SetAllPoints(button.icon)
        button.pressFeedback:SetTexture("Interface\\Buttons\\UI-Quickslot-Depress"); button.pressFeedback:Hide()
        button.autocast = UI.CreateTexture(button, nil, "OVERLAY")
        button.autocast:SetAllPoints(button.icon)
        button.autocast:SetTexture("Interface\\Buttons\\UI-AutoCastableOverlay")
        button.autocast:SetBlendMode("ADD"); button.autocast:Hide()
        button.cooldown = UI.CreateModel(buttonName .. "Cooldown", button, "CooldownFrameTemplate")
        button.cooldown:SetAllPoints(button.icon); button.cooldown:Hide()
        button.hotkey = UI.CreateLabel(button, nil, "OVERLAY", "NumberFontNormalSmall")
        button.hotkey:SetPoint("TOPRIGHT", button, "TOPRIGHT", -4, -4)
        button.hotkey:SetWidth(32); button.hotkey:SetJustifyH("RIGHT")
        button.read, button.rendered = {}, {}; button.mouseHeld, button.mousePressed = false, false
        button:RegisterForClicks("LeftButtonUp", "RightButtonUp")
        button:SetScript("OnClick", Click); button:SetScript("OnMouseDown", MouseDown); button:SetScript("OnMouseUp", MouseUp)
        button:SetScript("OnEnter", Enter); button:SetScript("OnLeave", Leave)
        if owner.kind == "pet" then
            button:RegisterForDrag("LeftButton")
            button:SetScript("OnDragStart", Pickup); button:SetScript("OnReceiveDrag", Place)
        end
    end
    frame:SetScript("OnHide", Hidden); frame:SetScript("OnShow", Shown)
    function view:Suspend()
        local firstFailure
        for _, button in ipairs(self.buttons) do
            local ok, failure = Run(Cancel, button)
            if not ok and not firstFailure then firstFailure = failure end
            ok, failure = Run(button.cooldown.Hide, button.cooldown)
            if not ok and not firstFailure then firstFailure = failure end
        end
        return firstFailure == nil, firstFailure
    end
    function view:CancelInput()
        local firstFailure
        for _, button in ipairs(self.buttons) do
            local ok, failure = Run(Cancel, button)
            if not ok and not firstFailure then firstFailure = failure end
        end
        return firstFailure == nil, firstFailure
    end
    function view:Hide()
        local ok, failure = self:Suspend()
        local hidden, reason = Run(self.frame.Hide, self.frame)
        return ok and hidden, failure or reason
    end
    function view:Show()
        if Bars.Modules.Editor then
            local ok, failure = Bars.Modules.Editor.ApplyView(self, true)
            if not ok then return false, failure end
        end
        self.frame:Show(); return true
    end
    function view:SetGrid(value)
        self.frame:SetWidth(value.barWidth); self.frame:SetHeight(value.barHeight)
        local step, columns = 40 + value.spacing, value.columns
        for index = 1, 10 do
            local row = math.floor((index - 1) / columns)
            local column = index - 1 - row * columns
            local button = self.buttons[index]
            button:ClearAllPoints(); button:SetPoint("TOPLEFT", self.frame, "TOPLEFT", column * step, -row * step)
        end
        self.title:SetWidth(value.barWidth); return true
    end
    function view:SetDisplay(value, repair)
        local rebuild = repair == true or not self.displayReady
        local titleChanged, keysChanged = rebuild or self.showTitle ~= value.showTitle, rebuild or self.showHotkeys ~= value.showHotkeys
        self.displayReady = false
        self.showTitle, self.showHotkeys, self.showCounts = value.showTitle, value.showHotkeys, value.showCounts
        if titleChanged then if self.showTitle then self.title:Show() else self.title:Hide() end end
        if keysChanged then
            for _, button in ipairs(self.buttons) do
                if self.showHotkeys then
                    local ok, failure = Run(Hotkey, button, button.bindingKey)
                    if not ok then return false, failure end
                    button.hotkey:Show()
                else button.hotkey:Hide() end
            end
        end
        self.displayReady = true; return true
    end
    return view
end
Remove = function(owner, list)
    local firstFailure
    for _, name in ipairs(list) do
        if owner.subscriptions[name] then
            local ok, failure = Run(BootyLib.Unsubscribe, name, owner)
            if ok then owner.subscriptions[name] = nil elseif not firstFailure then firstFailure = failure end
        end
    end
    return firstFailure == nil, firstFailure
end
local function EventPet() Special.HandleEvent(event, arg1, "pet") end
local function EventStance() Special.HandleEvent(event, arg1, "stance") end
local function Subscribe(owner, list)
    for _, name in ipairs(list) do
        if not owner.subscriptions[name] then
            local ok, failure = Run(BootyLib.Subscribe, name, owner, owner.kind == "pet" and EventPet or EventStance)
            if not ok then return false, failure end
            owner.subscriptions[name] = true
        end
    end
    return true
end
StopKind = function(owner, all)
    local ok, firstFailure = Remove(owner, transient[owner.kind])
    if all then
        local removed, failure = Remove(owner, availability[owner.kind])
        if not removed and not firstFailure then firstFailure = failure end
    end
    if owner.visible then owner.visible = false; state.visibleCount = state.visibleCount - 1 end
    local view = state.views[owner.id]
    if view then
        local hidden, failure = Run(view.Hide, view)
        if hidden then view.editPreview = false end
        if not hidden and not firstFailure then firstFailure = failure end
        if Bars.Modules.Editor then
            local ended, reason = Run(Bars.Modules.Editor.OnBarHidden, owner.id)
            if not ended and not firstFailure then firstFailure = reason end
        end
    end
    return firstFailure == nil, firstFailure
end
Refresh = function(owner, category, force)
    local view = state.views[owner.id]
    if not owner.visible or not view or not view.frame:IsVisible() then return true end
    for index = 1, view.count do
        local ok, failure
        if category == "Binding" then ok, failure = Run(Binding, view.buttons[index])
        else ok, failure = Run(ReadButton, view.buttons[index], category, force) end
        if not ok then return false, failure end
    end
    return true
end
local function SyncBody(owner)
    if not state.active or not state.configured[owner.kind] then return StopKind(owner, true) end
    -- A hidden parent already delivered OnHide. Keep the child's shown intent
    -- so its native OnShow can repair the pool when the parent returns.
    if type(UIParent.IsVisible) == "function" and not UIParent:IsVisible() then return true end
    if not owner.service then owner.service = Bars.Services.SpecialActionService.Create(owner.kind) end
    local count, reason = owner.service.GetCount()
    if count == nil then return false, reason end
    if count == 0 and not state.editing then return StopKind(owner, false) end
    if owner.creationFailure then return false, owner.creationFailure end
    local previousThis, previousEvent, previousArg = this, event, arg1
    local ran, view = pcall(Create, owner)
    this, event, arg1 = previousThis, previousEvent, previousArg
    if not ran then owner.creationFailure = tostring(view); return false, owner.creationFailure end
    local editor = Bars.Modules.Editor
    if editor then
        local layout, failure = editor.GetLayout(view.id)
        if not layout then return false, failure end
        local prepared, reason = view:SetDisplay(layout)
        if not prepared then return false, reason end
    end
    if count == 0 then
        if not view.editPreview then
            -- Changing availability cancels a move before showing the same
            -- retained frame as an inert layout surface.
            local stopped, failure = StopKind(owner, false)
            if not stopped then return false, failure end
            view.count = 0
            for _, button in ipairs(view.buttons) do button:Hide() end
            view.editPreview = true
            local shown, reason = Run(view.Show, view)
            if not shown then return false, reason end
        end
        if editor and type(editor.Sync) == "function" then
            local synced, failure = Run(editor.Sync)
            if not synced then return false, failure end
        end
        return true
    end
    if view.editPreview and editor then
        local cancelled, failure = Run(editor.OnBarHidden, view.id)
        if not cancelled then return false, failure end
    end
    view.editPreview = false
    local force = not owner.visible or view.count ~= count
    if view.count ~= count then
        local ok, failure = view:Suspend()
        if not ok then return false, failure end
    end
    view.count = count
    for index = 1, 10 do
        if index <= count then view.buttons[index]:Show() else view.buttons[index]:Hide() end
    end
    if not owner.visible then owner.visible = true; state.visibleCount = state.visibleCount + 1 end
    -- Initial reads precede display. The controlled flag lets the same pooled
    -- path repair a view after a dismissal without starting a polling worker.
    local ok, failure
    for index = 1, count do
        ok, failure = Run(ReadButton, view.buttons[index], "Read", force)
        if ok and force then ok, failure = Run(Binding, view.buttons[index]) end
        if not ok then return false, failure end
    end
    ok, failure = Run(view.Show, view)
    if not ok then return false, failure end
    if not view.frame:IsVisible() then return StopKind(owner, false) end
    ok, failure = Subscribe(owner, transient[owner.kind])
    if not ok then return false, failure end
    if state.editing and editor and type(editor.Sync) == "function" then
        ok, failure = Run(editor.Sync)
        if not ok then return false, failure end
    end
    return true
end
Sync = function(owner)
    if owner.syncing then return true end
    owner.syncing = true
    local previousThis, previousEvent, previousArg = this, event, arg1
    local ran, ok, failure = pcall(SyncBody, owner)
    this, event, arg1 = previousThis, previousEvent, previousArg
    owner.syncing = nil
    if not ran then return false, tostring(ok) end
    return ok, failure
end
function Special.Configure(config)
    if config ~= nil and type(config) ~= "table" then return false, "Invalid pet and stance bar configuration." end
    for kind, enabled in pairs(config or {}) do
        if not owners[kind] or enabled ~= true then return false, "Special bars support enabled pet and stance entries only." end
    end
    for _, kind in ipairs(kinds) do state.configured[kind] = config and config[kind] == true or nil end
    if state.active then return Special.Enable() end
    return true
end
function Special.Enable(config)
    if config ~= nil then
        local active = state.active; state.active = false
        local ok, failure = Special.Configure(config)
        state.active = active
        if not ok then return false, failure end
    end
    state.active = true
    for _, kind in ipairs(kinds) do
        local owner = owners[kind]
        local ok, failure = true, nil
        if state.configured[kind] then ok, failure = Subscribe(owner, availability[kind]) end
        if ok then ok, failure = Run(Sync, owner) end
        if not ok then Special.Disable(); return false, failure end
    end
    state.failure = nil; return true
end
function Special.Disable()
    state.active, state.editing = false, false
    local firstFailure
    for _, kind in ipairs(kinds) do
        local ok, failure = StopKind(owners[kind], true)
        if not ok and not firstFailure then firstFailure = failure end
    end
    return firstFailure == nil, firstFailure
end
function Special.SetEditing(value)
    if type(value) ~= "boolean" then return false, "Expected edit mode on or off." end
    if value and not state.active then return false, "Enable the action bars before editing." end
    if state.editing == value then return true end
    state.editing = value
    local firstFailure
    for _, kind in ipairs(kinds) do
        local ok, failure = Run(Sync, owners[kind])
        if not ok and not firstFailure then firstFailure = failure end
    end
    if firstFailure then
        state.editing = false
        for _, kind in ipairs(kinds) do
            local view = state.views[owners[kind].id]
            if view and view.editPreview then
                local ok, failure = StopKind(owners[kind], false)
                if not ok then firstFailure = firstFailure .. " Cleanup: " .. tostring(failure) end
            end
        end
    end
    return firstFailure == nil, firstFailure
end
function Special.HandleEvent(name, unit, kind)
    local owner = owners[kind]
    if not owner or not state.active or not state.configured[kind] then return true end
    if name == "UNIT_PET" and unit ~= "player" then return true end
    if (name == "UNIT_FLAGS" or name == "UNIT_AURA") and unit ~= "pet" then return true end
    local ok, failure
    if name == "PLAYER_ENTERING_WORLD" or name == "UNIT_PET" or name == "PET_BAR_UPDATE"
        or name == "PLAYER_CONTROL_LOST" or name == "PLAYER_CONTROL_GAINED" or name == "PLAYER_FARSIGHT_FOCUS_CHANGED"
        or name == "UPDATE_SHAPESHIFT_FORMS" then ok, failure = Run(Sync, owner)
    elseif name == "UPDATE_BINDINGS" then ok, failure = Refresh(owner, "Binding")
    elseif name == "PET_BAR_UPDATE_COOLDOWN" or name == "SPELL_UPDATE_COOLDOWN" then ok, failure = Refresh(owner, "ReadCooldown")
    else
        ok, failure = Refresh(owner, "ReadState")
        if ok then ok, failure = Refresh(owner, "ReadCooldown") end
    end
    if not ok then StopKind(owner, true); Report(failure) end
    return ok, failure
end
function Special.GetView(id) return state.views[id] end
function Special.GetState() return state end
