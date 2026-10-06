local Bars = BootyActionBars
local SpecialActionService = {}
Bars.Services.SpecialActionService = SpecialActionService

local floor = math.floor
local questionMark = "Interface\\Icons\\INV_Misc_QuestionMark"
-- These are the stock 1.12 pet command textures, used when another addon
-- removes a token constant. Unknown commands keep a visible placeholder.
local petTextures = {
    PET_DEFENSIVE_TEXTURE = "Interface\\Icons\\Ability_Defend",
    PET_AGGRESSIVE_TEXTURE = "Interface\\Icons\\Ability_Racial_BloodRage",
    PET_PASSIVE_TEXTURE = "Interface\\Icons\\Ability_Seal",
    PET_ATTACK_TEXTURE = "Interface\\Icons\\Ability_GhoulFrenzy",
    PET_FOLLOW_TEXTURE = "Interface\\Icons\\Ability_Tracking",
    PET_WAIT_TEXTURE = "Interface\\Icons\\Spell_Nature_TimeStop",
    PET_DISMISS_TEXTURE = "Interface\\Icons\\Spell_Shadow_Teleport",
}

local function Enabled(value)
    return value ~= nil and value ~= false and value ~= 0
end
local function ValidIndex(value)
    return type(value) == "number" and value >= 1 and value <= 10 and value == floor(value)
end
local function Nonnegative(value)
    if type(value) ~= "number" or value ~= value or value < 0 or value >= 1e300 then return 0 end
    return value
end
local function Text(value)
    return type(value) == "string" and value ~= "" and value or nil
end
local function Function(api, name)
    local value = api[name]
    if type(value) == "function" then return value end
end
local function ResolveName(api, name, token)
    if token and type(name) == "string" then return Text(api[name]) or Text(name) end
    return Text(name)
end
local function ResolveTexture(api, texture, token)
    if token then
        if type(texture) == "string" then return Text(api[texture]) or petTextures[texture] or questionMark end
        return questionMark
    end
    return Text(texture) or questionMark
end
local function Clear(target)
    target.hasAction, target.texture, target.name, target.subtext, target.isToken = false, nil, nil, nil, false
    target.count, target.usable, target.noMana, target.current, target.autoRepeat = 0, false, false, false, false
    target.autocastAllowed, target.autocastEnabled = false, false
    target.cooldownStart, target.cooldownDuration, target.cooldownEnabled = 0, 0, false
end
local function ValidatePartial(index, target)
    if not ValidIndex(index) then return false, "invalid-slot" end
    if type(target) ~= "table" then return false, "invalid-target" end
    return true
end

-- Hold the API adapter rather than function pointers so late client hooks
-- remain visible. The controller owns any legacy global-script context.
function SpecialActionService.Create(kind, api)
    if kind ~= "pet" and kind ~= "stance" then return nil, "invalid-kind" end
    api = api or _G
    local service = {}
    local infoName = kind == "pet" and "GetPetActionInfo" or "GetShapeshiftFormInfo"
    local cooldownName = kind == "pet" and "GetPetActionCooldown" or "GetShapeshiftFormCooldown"
    local bindingPrefix = kind == "pet" and "BOOTYACTIONBARS_PET_BUTTON" or "BOOTYACTIONBARS_STANCE_BUTTON"

    function service.GetCount()
        if kind == "pet" then
            local hasBar = Function(api, "PetHasActionBar")
            return hasBar and Enabled(hasBar()) and 10 or 0
        end
        local getCount = Function(api, "GetNumShapeshiftForms")
        local count = getCount and floor(Nonnegative(getCount())) or 0
        return count > 10 and 10 or count
    end

    function service.ReadCooldown(index, target)
        local valid, reason = ValidatePartial(index, target)
        if not valid then return nil, reason end
        target.cooldownStart, target.cooldownDuration, target.cooldownEnabled = 0, 0, false
        if Enabled(target.hasAction) then
            local getCooldown = Function(api, cooldownName)
            if getCooldown then
                local start, duration, enabled = getCooldown(index)
                target.cooldownStart, target.cooldownDuration = Nonnegative(start), Nonnegative(duration)
                target.cooldownEnabled = Enabled(enabled)
            end
        end
        return target
    end

    function service.ReadState(index, target)
        local valid, reason = ValidatePartial(index, target)
        if not valid then return nil, reason end
        target.usable, target.noMana, target.current, target.autoRepeat = false, false, false, false
        target.autocastAllowed, target.autocastEnabled = false, false
        if not Enabled(target.hasAction) then return target end
        local getInfo = Function(api, infoName)
        if not getInfo then return target end
        if kind == "pet" then
            local name, subtext, texture, token, current, allowed, enabled = getInfo(index)
            target.current, target.autocastAllowed, target.autocastEnabled = Enabled(current), Enabled(allowed), Enabled(enabled)
            local getUsable = Function(api, "GetPetActionsUsable")
            target.usable = getUsable and Enabled(getUsable()) or false
        else
            local texture, name, current, usable = getInfo(index)
            target.current, target.usable = Enabled(current), Enabled(usable)
        end
        return target
    end

    function service.Read(index, target)
        if not ValidIndex(index) then return nil, "invalid-slot" end
        if target ~= nil and type(target) ~= "table" then return nil, "invalid-target" end
        target = target or {}
        Clear(target)
        if index > service.GetCount() then return target end
        local getInfo = Function(api, infoName)
        if not getInfo then return target end
        if kind == "pet" then
            local name, subtext, texture, token, current, allowed, enabled = getInfo(index)
            if not Text(name) then return target end
            target.hasAction, target.isToken = true, Enabled(token)
            target.name, target.subtext = ResolveName(api, name, target.isToken), Text(subtext)
            target.texture = ResolveTexture(api, texture, target.isToken)
            target.current, target.autocastAllowed, target.autocastEnabled = Enabled(current), Enabled(allowed), Enabled(enabled)
            local getUsable = Function(api, "GetPetActionsUsable")
            target.usable = getUsable and Enabled(getUsable()) or false
        else
            local texture, name, current, usable = getInfo(index)
            if not Text(name) and not Text(texture) then return target end
            target.hasAction, target.name, target.texture = true, Text(name), ResolveTexture(api, texture, false)
            target.current, target.usable = Enabled(current), Enabled(usable)
        end
        return service.ReadCooldown(index, target)
    end

    function service.GetBindingKeys(index)
        if not ValidIndex(index) then return nil, nil, "invalid-button" end
        local getBinding = Function(api, "GetBindingKey")
        if not getBinding then return nil, nil, "unavailable-api" end
        return getBinding(bindingPrefix .. index)
    end

    function service.Use(index, mouseButton)
        if not ValidIndex(index) then return false, "invalid-slot" end
        if mouseButton ~= nil and mouseButton ~= "LeftButton" and mouseButton ~= "RightButton" then
            return false, "invalid-mouse-button"
        end
        if index > service.GetCount() then return false, "unavailable-slot" end
        local operation
        if kind == "stance" then
            operation = Function(api, "CastShapeshiftForm")
        elseif mouseButton == "RightButton" then
            operation = Function(api, "TogglePetAutocast")
        else
            -- Native mouse attack toggles stop, while the native binding
            -- always casts. A nil mouse button identifies the binding path.
            local attackActive = Function(api, "IsPetAttackActive")
            if mouseButton == "LeftButton" and attackActive and Enabled(attackActive(index)) then
                local stop = Function(api, "PetStopAttack")
                if not stop then return false, "unavailable-api" end
                stop()
                return true
            end
            operation = Function(api, "CastPetAction")
        end
        if not operation then return false, "unavailable-api" end
        operation(index)
        return true
    end

    function service.Pickup(index)
        if not ValidIndex(index) then return false, "invalid-slot" end
        if kind ~= "pet" then return false, "unsupported-kind" end
        if index > service.GetCount() then return false, "unavailable-slot" end
        local pickup = Function(api, "PickupPetAction")
        if not pickup then return false, "unavailable-api" end
        pickup(index)
        return true
    end
    -- Vanilla uses PickupPetAction both for starting and receiving a drag.
    service.Place = service.Pickup

    function service.Tooltip(index, button)
        if not ValidIndex(index) then return false, "invalid-slot" end
        if type(button) ~= "table" and type(button) ~= "userdata" then return false, "invalid-button" end
        if index > service.GetCount() then return false, "unavailable-slot" end
        local tooltip = api.GameTooltip
        if not tooltip or type(tooltip.SetOwner) ~= "function" then return false, "unavailable-api" end
        local getInfo = Function(api, infoName)
        if not getInfo then return false, "unavailable-api" end
        local method, name, subtext
        if kind == "pet" then
            local rawName, rawSubtext, texture, token = getInfo(index)
            if not Text(rawName) then return false, "unavailable-slot" end
            if Enabled(token) then
                name, subtext, method = ResolveName(api, rawName, true), Text(rawSubtext), tooltip.SetText
            else method = tooltip.SetPetAction end
        else
            local texture, rawName = getInfo(index)
            if not Text(rawName) and not Text(texture) then return false, "unavailable-slot" end
            method = tooltip.SetShapeshift
        end
        if type(method) ~= "function" then return false, "unavailable-api" end
        tooltip:SetOwner(button, "ANCHOR_RIGHT")
        if type(tooltip.ClearLines) == "function" then tooltip:ClearLines() end
        if name then
            method(tooltip, name, 1, 1, 1)
            if subtext and type(tooltip.AddLine) == "function" then tooltip:AddLine(subtext, 0.5, 0.5, 0.5) end
        else method(tooltip, index) end
        if type(tooltip.Show) == "function" then tooltip:Show() end
        return true
    end

    return service
end
