local Bars = BootyActionBars
local ActionService = {}
Bars.Services.ActionService = ActionService

local floor = math.floor

local function Enabled(value)
    return value ~= nil and value ~= false and value ~= 0
end

local function ValidIndex(value, limit)
    return type(value) == "number" and value >= 1 and value <= limit and value == floor(value)
end

local function Nonnegative(value)
    if type(value) ~= "number" or value ~= value or value < 0 or value >= 1e300 then return 0 end
    return value
end

local function Function(api, name)
    local value = api[name]
    if type(value) == "function" then return value end
end

local function ReadCooldown(api, slot, target)
    target.cooldownStart, target.cooldownDuration, target.cooldownEnabled = 0, 0, false
    if not Enabled(target.hasAction) then return target end
    local getCooldown = Function(api, "GetActionCooldown")
    if getCooldown then
        local start, duration, enabled = getCooldown(slot)
        target.cooldownStart, target.cooldownDuration = Nonnegative(start), Nonnegative(duration)
        target.cooldownEnabled = Enabled(enabled)
    end
    return target
end

local function ReadUsability(api, slot, target)
    target.count, target.usable, target.noMana = 0, false, false
    if not Enabled(target.hasAction) then return target end
    local getCount = Function(api, "GetActionCount")
    local isUsable = Function(api, "IsUsableAction")
    if getCount then target.count = floor(Nonnegative(getCount(slot))) end
    if isUsable then
        local usable, noMana = isUsable(slot)
        target.usable, target.noMana = Enabled(usable), Enabled(noMana)
    end
    return target
end

local function ReadState(api, slot, target)
    target.current, target.autoRepeat = false, false
    if not Enabled(target.hasAction) then return target end
    local isCurrent = Function(api, "IsCurrentAction")
    local isAutoRepeat = Function(api, "IsAutoRepeatAction")
    if isCurrent then target.current = Enabled(isCurrent(slot)) end
    if isAutoRepeat then target.autoRepeat = Enabled(isAutoRepeat(slot)) end
    return target
end

local function ValidatePartial(slot, target)
    if not ValidIndex(slot, 120) then return false, "invalid-slot" end
    if type(target) ~= "table" then return false, "invalid-target" end
    return true
end

-- Keep the adapter table, not original function pointers: macro addons may
-- replace client APIs after this service is created. The controller supplies
-- and restores the current button's global `this` around hooked API calls.
-- Injected adapters remain isolated from globals.
function ActionService.Create(api)
    api = api or _G
    local service = {}

    function service.Read(slot, target)
        if not ValidIndex(slot, 120) then return nil, "invalid-slot" end
        if target ~= nil and type(target) ~= "table" then return nil, "invalid-target" end
        target = target or {}
        local hasAction = Function(api, "HasAction")
        local present = hasAction and Enabled(hasAction(slot)) or false
        target.hasAction = present
        target.texture = nil
        if present then
            local getTexture = Function(api, "GetActionTexture")
            if getTexture then target.texture = getTexture(slot) end
        end
        ReadUsability(api, slot, target)
        ReadState(api, slot, target)
        ReadCooldown(api, slot, target)
        return target
    end

    function service.ReadCooldown(slot, target)
        local valid, reason = ValidatePartial(slot, target)
        if not valid then return nil, reason end
        return ReadCooldown(api, slot, target)
    end

    function service.ReadUsability(slot, target)
        local valid, reason = ValidatePartial(slot, target)
        if not valid then return nil, reason end
        return ReadUsability(api, slot, target)
    end

    function service.ReadState(slot, target)
        local valid, reason = ValidatePartial(slot, target)
        if not valid then return nil, reason end
        return ReadState(api, slot, target)
    end

    function service.Use(slot, checkCursor, selfCast)
        if not ValidIndex(slot, 120) then return false, "invalid-slot" end
        local useAction = Function(api, "UseAction")
        if not useAction then return false, "unavailable-api" end
        local saveMacro = Function(api, "MacroFrame_SaveMacro")
        if saveMacro then saveMacro() end
        useAction(slot, Enabled(checkCursor) and 1 or 0, Enabled(selfCast) and 1 or nil)
        return true
    end

    function service.Pickup(slot)
        if not ValidIndex(slot, 120) then return false, "invalid-slot" end
        local pickupAction = Function(api, "PickupAction")
        if not pickupAction then return false, "unavailable-api" end
        pickupAction(slot)
        return true
    end

    function service.Place(slot)
        if not ValidIndex(slot, 120) then return false, "invalid-slot" end
        local placeAction = Function(api, "PlaceAction")
        if not placeAction then return false, "unavailable-api" end
        placeAction(slot)
        return true
    end

    function service.GetBindingKeys(index)
        if not ValidIndex(index, 12) then return nil, nil, "invalid-button" end
        local getBindingKey = Function(api, "GetBindingKey")
        if not getBindingKey then return nil, nil, "unavailable-api" end
        return getBindingKey("BOOTYACTIONBARS_BUTTON" .. index)
    end

    function service.InCombat()
        local inCombat = Function(api, "UnitAffectingCombat")
        return inCombat and Enabled(inCombat("player")) or false
    end

    service.IsBusy = service.InCombat
    return service
end
