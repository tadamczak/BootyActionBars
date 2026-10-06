local Bars = BootyActionBars
local Engine = {}
Bars.Core.Engine = Engine
local state = {active = false, requested = false, subscribed = false, views = {}, customBars = {},
    customActive = {}, customRevision = 0, customConfiguredCount = 0, customActiveCount = 0}
local events = {"PLAYER_ENTERING_WORLD", "ACTIONBAR_SLOT_CHANGED", "ACTIONBAR_UPDATE_COOLDOWN",
    "ACTIONBAR_UPDATE_USABLE", "ACTIONBAR_UPDATE_STATE", "PLAYER_TARGET_CHANGED", "PLAYER_AURAS_CHANGED",
    "UNIT_INVENTORY_CHANGED", "BAG_UPDATE", "UPDATE_BINDINGS", "PLAYER_ENTER_COMBAT", "PLAYER_LEAVE_COMBAT",
    "START_AUTOREPEAT_SPELL", "STOP_AUTOREPEAT_SPELL", "CRAFT_SHOW", "CRAFT_CLOSE", "TRADE_SKILL_SHOW", "TRADE_SKILL_CLOSE",
    "ACTIONBAR_PAGE_CHANGED", "UPDATE_BONUS_ACTIONBAR", "UPDATE_SHAPESHIFT_FORMS"}
local pageEvents = {ACTIONBAR_PAGE_CHANGED = true, UPDATE_BONUS_ACTIONBAR = true, UPDATE_SHAPESHIFT_FORMS = true}
local stateEvents = {ACTIONBAR_UPDATE_STATE = true, PLAYER_ENTER_COMBAT = true, PLAYER_LEAVE_COMBAT = true,
    START_AUTOREPEAT_SPELL = true, STOP_AUTOREPEAT_SPELL = true, CRAFT_SHOW = true, CRAFT_CLOSE = true,
    TRADE_SKILL_SHOW = true, TRADE_SKILL_CLOSE = true}

local function Valid(index)
    return type(index) == "number" and index >= 1 and index <= 12 and index == math.floor(index)
end
local function ValidBar(barId)
    return type(barId) == "number" and barId >= 1 and barId <= 6 and barId == math.floor(barId)
end
local function Report(message)
    message = tostring(message)
    if state.failure ~= message then BootyLib.Print("BootyActionBars: " .. message) end
    state.failure = message
end
local function Context(view, index, callback, first, second, third, fourth)
    local previousThis, previousEvent, previousArg = this, event, arg1
    this = view.buttons[index]
    local ok, result, reason = pcall(callback, first, second, third, fourth)
    this, event, arg1 = previousThis, previousEvent, previousArg
    if not ok then Report(result); return false, result end
    return result, reason
end
local function ReadAndRender(view, index, category, force)
    local button = view.buttons[index]
    local result, reason = state.service[category](button.action, button.read)
    if not result then return false, reason end
    view:Render(index, button.read, force)
    return true
end
local function Refresh(view, index, category, force)
    return Context(view, index, ReadAndRender, view, index, category, force)
end
local function RefreshView(view, category, force)
    for index = 1, 12 do
        local ok, failure = Refresh(view, index, category, force)
        if not ok then return false, failure end
    end
    return true
end
local function IsActive(barId)
    return state.active and (barId == 1 or state.customActive[barId] == true)
end
local function RefreshAll(category, force)
    for barId = 1, 6 do
        if IsActive(barId) then
            local ok, failure = RefreshView(state.views[barId], category, force)
            if not ok then return false, failure end
        end
    end
    return true
end
local function ApplyPage(offset, page)
    if state.actionOffset == offset then return false end
    -- A partial view failure invalidates the cache so the next enable repairs
    -- every action even if it returns to the previously cached page.
    state.actionOffset, state.page = nil, nil
    local suspended, failure = state.view:Suspend(true)
    if suspended == false then error(failure or "The old action page could not be suspended.") end
    for index = 1, 12 do state.view.buttons[index].action = offset + index end
    state.view:SetPage(page, offset)
    state.actionOffset, state.page = offset, page
    return true
end
local function ReadPage()
    local offset, page = Bars.Services.ActionPageService.Read()
    if offset == nil then return false, page end
    return true, ApplyPage(offset, page)
end
local function UpdatePage()
    local previousThis, previousEvent, previousArg = this, event, arg1
    local ran, ok, result = pcall(ReadPage)
    this, event, arg1 = previousThis, previousEvent, previousArg
    if not ran then return false, ok end
    return ok, result
end
local function Binding(view, index, barId)
    local previousEvent, previousArg = event, arg1
    local key
    if barId == 1 then key = state.service.GetBindingKeys(index)
    else key = state.service.GetBindingKeys(index, barId) end
    -- A client hook may change legacy globals before formatting the label.
    this, event, arg1 = view.buttons[index], previousEvent, previousArg
    view:Binding(index, key)
    return true
end
local function ViewBindings(view, barId)
    for index = 1, 12 do
        local ok, failure = Context(view, index, Binding, view, index, barId)
        if not ok then return false, failure end
    end
    return true
end
local function RefreshBindings()
    for barId = 1, 6 do
        if IsActive(barId) then
            local ok, failure = ViewBindings(state.views[barId], barId)
            if not ok then return false, failure end
        end
    end
    return true
end
local function Unsubscribe()
    if not state.subscribed then return end
    for _, name in ipairs(events) do BootyLib.Unsubscribe(name, Engine) end
    state.subscribed = false
end
local function ActivityChanged()
    if state.activityObserver then return state.activityObserver(state.active) end
    return true
end
local function ProtectedCall(callback, owner)
    local previousThis, previousEvent, previousArg = this, event, arg1
    local ran, ok, failure = pcall(callback, owner)
    this, event, arg1 = previousThis, previousEvent, previousArg
    if not ran then return false, tostring(ok) end
    if ok == false then return false, failure or "An action bar could not be suspended." end
    return true
end
local function HideView(view)
    local ok, failure = ProtectedCall(view.Hide, view)
    if not ok and view.frame and type(view.frame.Hide) == "function" then
        -- Even a broken suspension must not leave native child animations
        -- visible. Preserve the first failure after attempting the parent.
        ProtectedCall(view.frame.Hide, view.frame)
    end
    return ok, failure
end
function Engine.SetActivityObserver(callback)
    state.activityObserver = callback
end
local function SetCustomActive(barId, value, revise)
    if (state.customActive[barId] == true) == value then return end
    state.customActive[barId] = value and true or nil
    state.customActiveCount = state.customActiveCount + (value and 1 or -1)
    if revise then state.customRevision = state.customRevision + 1 end
end
local function HideCustoms()
    local firstFailure
    state.hidingCustoms = true
    for barId = 2, 6 do
        SetCustomActive(barId, false, false)
        if state.views[barId] then
            local ok, failure = HideView(state.views[barId])
            if not ok and not firstFailure then firstFailure = failure end
        end
    end
    state.hidingCustoms = nil
    return firstFailure == nil, firstFailure
end
local function Configure(customBars)
    if customBars == nil then return true end
    if type(customBars) ~= "table" then return false, "Invalid custom action bar configuration." end
    for barId, enabled in pairs(customBars) do
        if not ValidBar(barId) or barId < 2 or enabled ~= true then
            return false, "Custom action bars must be enabled identities 2 through 6."
        end
    end
    for barId = 2, 6 do
        local enabled = customBars[barId] == true
        if (state.customBars[barId] == true) ~= enabled then
            state.customBars[barId] = enabled and true or nil
            state.customConfiguredCount = state.customConfiguredCount + (enabled and 1 or -1)
            state.customRevision = state.customRevision + 1
        end
    end
    return true
end
function Engine.ConfigureCustomBars(customBars)
    return Configure(customBars)
end
local function CreateView(barId)
    if state.views[barId] then return state.views[barId] end
    local ok, view = pcall(Bars.Modules.ActionBar.Create, {Click = Engine.MouseClick, Pickup = Engine.Pickup,
        Place = Engine.Place, OnHide = Engine.OnHide, OnShow = Engine.OnShow}, barId)
    if not ok then
        state.creationFailure = tostring(view)
        return nil, state.creationFailure
    end
    state.views[barId] = view
    if barId == 1 then state.view = view end
    return view
end
local function ActivateCustom(barId, revise)
    local view, failure = CreateView(barId)
    if not view then return false, failure end
    if state.customActive[barId] then return true end
    local offset = (barId - 1) * 12
    local suspended, suspendFailure = ProtectedCall(view.Suspend, view)
    if not suspended then return false, suspendFailure end
    for index = 1, 12 do view.buttons[index].action = offset + index end
    local previousThis, previousEvent, previousArg = this, event, arg1
    local ok, reason = pcall(view.SetPage, view, barId, offset)
    this, event, arg1 = previousThis, previousEvent, previousArg
    if not ok then return false, reason end
    ok, reason = RefreshView(view, "Read", true)
    if not ok then return false, reason end
    ok, reason = ViewBindings(view, barId)
    if not ok then return false, reason end
    SetCustomActive(barId, true, revise)
    view:Show()
    if not view.frame:IsVisible() then
        SetCustomActive(barId, false, revise)
        local suspended, failure = ProtectedCall(view.Suspend, view)
        if not suspended then return false, failure end
    end
    return true
end
local function SyncCustoms(revise)
    for barId = 2, 6 do
        if state.customBars[barId] and state.active then
            local ok, failure = ActivateCustom(barId, revise)
            if not ok then return false, failure end
        elseif state.views[barId] then
            SetCustomActive(barId, false, false)
            state.hidingCustoms = true
            local ok, failure = HideView(state.views[barId])
            state.hidingCustoms = nil
            if not ok then return false, failure end
        end
    end
    return true
end
function Engine.HandleEvent(name, unit)
    if not state.active then return end
    local ok, failure = true, nil
    if pageEvents[name] then
        local changed
        ok, changed = UpdatePage()
        if not ok then failure = changed
        elseif changed then ok, failure = RefreshView(state.view, "Read", true) end
    elseif name == "PLAYER_ENTERING_WORLD" then
        ok, failure = UpdatePage()
        if ok then ok, failure = RefreshAll("Read", true) end
    elseif name == "UPDATE_BINDINGS" then ok, failure = RefreshBindings()
    elseif name == "ACTIONBAR_SLOT_CHANGED" then
        if unit == nil or type(unit) == "number" and unit <= 0 then
            ok, failure = RefreshAll("Read")
        elseif type(unit) == "number" then
            for barId = 1, 6 do
                if IsActive(barId) then
                    local offset = barId == 1 and state.actionOffset or (barId - 1) * 12
                    local index = unit - offset
                    if Valid(index) then
                        ok, failure = Refresh(state.views[barId], index, "Read")
                        if not ok then break end
                    end
                end
            end
        end
    elseif name == "ACTIONBAR_UPDATE_COOLDOWN" then
        ok, failure = RefreshAll("ReadCooldown")
        if ok then ok, failure = RefreshAll("ReadUsability") end
    elseif name == "PLAYER_TARGET_CHANGED" or name == "PLAYER_AURAS_CHANGED" then
        -- Hooked macro icons/cooldowns may change without a native slot event.
        ok, failure = RefreshAll("Read")
    elseif name == "ACTIONBAR_UPDATE_USABLE" then
        ok, failure = RefreshAll("ReadUsability")
    elseif stateEvents[name] then ok, failure = RefreshAll("ReadState")
    elseif name == "BAG_UPDATE" or name == "UNIT_INVENTORY_CHANGED" and unit == "player" then
        ok, failure = RefreshAll("Read")
    end
    if not ok then Engine.Disable(); Report(failure or "An action could not be refreshed.") end
end
local function Event() Engine.HandleEvent(event, arg1) end
local function Subscribe()
    if state.subscribed then return end
    for _, name in ipairs(events) do BootyLib.Subscribe(name, Engine, Event) end
    state.subscribed = true
end
function Engine.OnHide(barId)
    barId = barId or 1
    if barId ~= 1 then
        if ValidBar(barId) and state.views[barId] then
            SetCustomActive(barId, false, not state.hidingCustoms)
            return ProtectedCall(state.views[barId].Suspend, state.views[barId])
        end
        return true
    end
    state.active = false; Unsubscribe()
    if state.cleaning then return true end
    local ok, firstFailure = ProtectedCall(ActivityChanged)
    if state.view then
        local suspended, failure = ProtectedCall(state.view.Suspend, state.view)
        if not suspended and not firstFailure then firstFailure = failure end
    end
    local hidden, failure = HideCustoms()
    if not hidden and not firstFailure then firstFailure = failure end
    if firstFailure then Report(firstFailure) end
    return firstFailure == nil, firstFailure
end
function Engine.OnShow(barId)
    barId = barId or 1
    if barId ~= 1 then
        if not ValidBar(barId) or not state.active or not state.customBars[barId] or state.customActive[barId] then return end
        local ok, failure = ActivateCustom(barId, true)
        if not ok then Engine.Disable(); Report(failure) end
        return
    end
    if not state.requested or state.active then return end
    local ok, failure = Engine.Enable()
    if not ok then Report(failure) end
end
function Engine.Enable(customBars)
    if state.creationFailure then return false, state.creationFailure end
    local ok, failure = Configure(customBars)
    if not ok then return false, failure end
    if state.active then
        ok, failure = SyncCustoms(true)
        if not ok then Engine.Disable(); return false, failure end
        return true
    end
    local UI = Bars.UI.Components
    if type(UI.CreateModel) ~= "function" or type(HasAction) ~= "function" or type(UseAction) ~= "function"
        or type(GetActionTexture) ~= "function" or type(GetActionCooldown) ~= "function" or type(CooldownFrame_SetTimer) ~= "function" then
        return false, "The test bar needs the current BootyLib and native action/cooldown APIs."
    end
    local offset, page = Bars.Services.ActionPageService.Read()
    if offset == nil then return false, page end
    state.requested = true
    if not state.service then state.service = Bars.Services.ActionService.Create() end
    local view
    view, failure = CreateView(1)
    if not view then state.requested = false; Engine.Disable(); return false, failure end
    local previousThis, previousEvent, previousArg = this, event, arg1
    ok, failure = pcall(ApplyPage, offset, page)
    this, event, arg1 = previousThis, previousEvent, previousArg
    if not ok then Engine.Disable(); return false, failure end
    ok, failure = RefreshView(state.view, "Read", true)
    if not ok then Engine.Disable(); return false, failure end
    ok, failure = ViewBindings(state.view, 1)
    if not ok then Engine.Disable(); return false, failure end
    state.active, state.failure = true, nil
    Subscribe(); state.view:Show()
    if not state.view.frame:IsVisible() then Engine.OnHide() end
    ok, failure = SyncCustoms(false)
    if not ok then Engine.Disable(); return false, failure end
    ActivityChanged()
    return true
end
function Engine.Disable()
    state.requested, state.active = false, false
    Unsubscribe()
    local ok, firstFailure = ProtectedCall(ActivityChanged)
    state.cleaning = true
    if state.view then
        local hidden, failure = HideView(state.view)
        if not hidden and not firstFailure then firstFailure = failure end
    end
    local hidden, failure = HideCustoms()
    if not hidden and not firstFailure then firstFailure = failure end
    state.cleaning = nil
    if firstFailure then Report(firstFailure) end
    return firstFailure == nil, firstFailure
end
local function InputView(barId, index)
    if not ValidBar(barId) or not Valid(index) or not IsActive(barId) then return nil end
    return state.views[barId]
end
local function UseButton(barId, index, keyState)
    local view = InputView(barId, index)
    if not view then return false end
    local button = view.buttons[index]
    if keyState == "down" then view:SetPressed(index, true); return true end
    if keyState ~= "up" or not button.pressed then return false end
    view:SetPressed(index, false)
    return Context(view, index, state.service.Use, button.action, false, false)
end
function Engine.UseButton(index, keyState)
    return UseButton(1, index, keyState)
end
function Engine.UseCustomButton(barId, index, keyState)
    if not ValidBar(barId) or barId == 1 then return false end
    return UseButton(barId, index, keyState)
end
function Engine.MouseClick(index, mouseButton, skip, barId)
    local view = InputView(barId or 1, index)
    if not view or skip then return false end
    return Context(view, index, state.service.Use, view.buttons[index].action, true, mouseButton == "RightButton")
end
function Engine.Pickup(index, barId)
    local view = InputView(barId or 1, index)
    if not view then return false end
    return Context(view, index, state.service.Pickup, view.buttons[index].action)
end
function Engine.Place(index, barId)
    local view = InputView(barId or 1, index)
    if not view then return false end
    local ok, failure = Context(view, index, state.service.Place, view.buttons[index].action)
    if ok then
        local refreshed, reason = Refresh(view, index, "Read")
        if not refreshed then Engine.Disable(); Report(reason); return false, reason end
    end
    return ok, failure
end
function Engine.GetState() return state end
