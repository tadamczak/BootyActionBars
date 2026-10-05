local Bars = BootyActionBars
local Engine = {}
Bars.Core.Engine = Engine
local state = {active = false, requested = false, subscribed = false}
local events = {"PLAYER_ENTERING_WORLD", "ACTIONBAR_SLOT_CHANGED", "ACTIONBAR_UPDATE_COOLDOWN",
    "ACTIONBAR_UPDATE_USABLE", "ACTIONBAR_UPDATE_STATE", "PLAYER_TARGET_CHANGED", "PLAYER_AURAS_CHANGED",
    "UNIT_INVENTORY_CHANGED", "BAG_UPDATE", "UPDATE_BINDINGS", "PLAYER_ENTER_COMBAT", "PLAYER_LEAVE_COMBAT",
    "START_AUTOREPEAT_SPELL", "STOP_AUTOREPEAT_SPELL", "CRAFT_SHOW", "CRAFT_CLOSE", "TRADE_SKILL_SHOW", "TRADE_SKILL_CLOSE"}
local stateEvents = {ACTIONBAR_UPDATE_STATE = true, PLAYER_ENTER_COMBAT = true, PLAYER_LEAVE_COMBAT = true,
    START_AUTOREPEAT_SPELL = true, STOP_AUTOREPEAT_SPELL = true, CRAFT_SHOW = true, CRAFT_CLOSE = true,
    TRADE_SKILL_SHOW = true, TRADE_SKILL_CLOSE = true}

local function Valid(index)
    return type(index) == "number" and index >= 1 and index <= 12 and index == math.floor(index)
end
local function Report(message)
    message = tostring(message)
    if state.failure ~= message then BootyLib.Print("BootyActionBars: " .. message) end
    state.failure = message
end
local function Context(index, callback, first, second, third)
    local previous = this
    this = state.view.buttons[index]
    local ok, result, reason = pcall(callback, first, second, third)
    this = previous
    if not ok then Report(result); return false, result end
    return result, reason
end
local function ReadAndRender(index, category, force)
    local button = state.view.buttons[index]
    local result, reason = state.service[category](index, button.read)
    if not result then return false, reason end
    state.view:Render(index, button.read, force)
    return true
end
local function Refresh(index, category, force)
    return Context(index, ReadAndRender, index, category, force)
end
local function RefreshAll(category, force)
    for index = 1, 12 do
        local ok, failure = Refresh(index, category, force)
        if not ok then return false, failure end
    end
    return true
end
local function Bindings()
    for index = 1, 12 do
        local key = state.service.GetBindingKeys(index)
        state.view:Binding(index, key)
    end
    return true
end
local function RefreshBindings()
    local ok, failure = pcall(Bindings)
    if not ok then return false, failure end
    return true
end
local function Unsubscribe()
    if not state.subscribed then return end
    for _, name in ipairs(events) do BootyLib.Unsubscribe(name, Engine) end
    state.subscribed = false
end
function Engine.HandleEvent(name, unit)
    if not state.active then return end
    local ok, failure = true, nil
    if name == "UPDATE_BINDINGS" then ok, failure = RefreshBindings()
    elseif name == "ACTIONBAR_SLOT_CHANGED" then
        if Valid(unit) then ok, failure = Refresh(unit, "Read")
        elseif unit == nil or type(unit) == "number" and unit <= 0 then ok, failure = RefreshAll("Read") end
    elseif name == "ACTIONBAR_UPDATE_COOLDOWN" then
        ok, failure = RefreshAll("ReadCooldown")
        if ok then ok, failure = RefreshAll("ReadUsability") end
    elseif name == "PLAYER_TARGET_CHANGED" or name == "PLAYER_AURAS_CHANGED" then
        -- Hooked macro icons/cooldowns may change without a native slot event.
        ok, failure = RefreshAll("Read")
    elseif name == "ACTIONBAR_UPDATE_USABLE" then
        ok, failure = RefreshAll("ReadUsability")
    elseif stateEvents[name] then ok, failure = RefreshAll("ReadState")
    elseif name == "BAG_UPDATE" or name == "PLAYER_ENTERING_WORLD" or name == "UNIT_INVENTORY_CHANGED" and unit == "player" then
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
function Engine.OnHide()
    state.active = false; Unsubscribe()
    if state.view then state.view:Suspend() end
end
function Engine.OnShow()
    if not state.requested or state.active then return end
    local ok, failure = Engine.Enable()
    if not ok then Report(failure) end
end
function Engine.Enable()
    if state.active then return true end
    if state.creationFailure then return false, state.creationFailure end
    local UI = Bars.UI.Components
    if type(UI.CreateModel) ~= "function" or type(HasAction) ~= "function" or type(UseAction) ~= "function"
        or type(GetActionTexture) ~= "function" or type(GetActionCooldown) ~= "function" or type(CooldownFrame_SetTimer) ~= "function" then
        return false, "The test bar needs the current BootyLib and native action/cooldown APIs."
    end
    state.requested = true
    if not state.service then state.service = Bars.Services.ActionService.Create() end
    if not state.view then
        local ok, view = pcall(Bars.Modules.ActionBar.Create, {Click = Engine.MouseClick, Pickup = Engine.Pickup,
            Place = Engine.Place, OnHide = Engine.OnHide, OnShow = Engine.OnShow})
        if not ok then
            state.requested, state.creationFailure = false, tostring(view)
            return false, state.creationFailure
        end
        state.view = view
    end
    local ok, failure = RefreshAll("Read", true)
    if not ok then Engine.Disable(); return false, failure end
    ok, failure = RefreshBindings()
    if not ok then Engine.Disable(); return false, failure end
    state.active, state.failure = true, nil
    Subscribe(); state.view:Show()
    if not state.view.frame:IsVisible() then Engine.OnHide() end
    return true
end
function Engine.Disable()
    state.requested, state.active = false, false
    Unsubscribe()
    if state.view then state.view:Hide() end
    return true
end
function Engine.UseButton(index, keyState)
    if not state.active or not Valid(index) then return false end
    local button = state.view.buttons[index]
    if keyState == "down" then state.view:SetPressed(index, true); return true end
    if keyState ~= "up" or not button.pressed then return false end
    state.view:SetPressed(index, false)
    return Context(index, state.service.Use, index, false, false)
end
function Engine.MouseClick(index, mouseButton, skip)
    if not state.active or not Valid(index) or skip then return false end
    return Context(index, state.service.Use, index, true, mouseButton == "RightButton")
end
function Engine.Pickup(index)
    if not state.active or not Valid(index) then return false end
    return Context(index, state.service.Pickup, index)
end
function Engine.Place(index)
    if not state.active or not Valid(index) then return false end
    local ok, failure = Context(index, state.service.Place, index)
    if ok then
        local refreshed, reason = Refresh(index, "Read")
        if not refreshed then Engine.Disable(); Report(reason); return false, reason end
    end
    return ok, failure
end
function Engine.GetState() return state end
