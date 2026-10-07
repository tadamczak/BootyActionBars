local Bars = BootyActionBars
local MacroActionService = {}
Bars.Services.MacroActionService = MacroActionService
local floor = math.floor

local function ValidSlot(slot)
    return type(slot) == "number" and slot >= 1 and slot <= 120 and slot == floor(slot)
end
local function Function(api, name)
    local value = api[name]
    return type(value) == "function" and value or nil
end
local function Text(value) return type(value) == "string" and value ~= "" and value or nil end
local function Enabled(value) return value ~= nil and value ~= false and value ~= 0 end
local function Count(value)
    if type(value) ~= "number" or value ~= value or value < 0 or value >= 1e300 then return 0 end
    return floor(value)
end
local function Nonnegative(value)
    if type(value) ~= "number" or value ~= value or value < 0 or value >= 1e300 then return 0 end
    return value
end
local function CleveOwns(api, slot)
    local provider = api.CleveRoids
    -- The hooked getters already resolve CleveRoids' action. Calling its
    -- GetAction again could parse and emit a nested slot event on a cache miss.
    if type(provider) ~= "table" or not Enabled(provider.ready) or type(provider.Actions) ~= "table" then return false end
    local actions = provider.Actions[slot]
    return type(actions) == "table" and (type(actions.active) == "table" or type(actions.tooltip) == "table")
end
local function SuperAction(api, slot, resolvedName)
    if CleveOwns(api, slot) then return end
    local options, resolve = api.SM_VARS, Function(api, "SM_GetActionSpell")
    if type(options) ~= "table" or options.checkCooldown ~= 1 or not resolve then return end
    local name
    -- A complete read has already obtained the native macro label. False
    -- means that read found no name; nil requests a fresh partial read.
    if resolvedName ~= nil then name = Text(resolvedName)
    else
        local getText = Function(api, "GetActionText")
        name = getText and Text(getText(slot))
    end
    if not name then return end
    local super = type(api.SM_ACTION) == "table" and api.SM_ACTION[slot] or nil
    local getSuper, getMacro, getIndex = Function(api, "GetSuperMacroInfo"), Function(api, "GetMacroInfo"), Function(api, "GetMacroIndexByName")
    if super and getSuper then
        if not Text(getSuper(super)) then return end
    elseif getMacro and getIndex then
        if not Text(getMacro(getIndex(name))) then return end
    end
    local kind, action, texture = resolve(name, super)
    if (kind == "spell" or kind == "item") and Text(action) then
        return kind, action, texture, options.replaceIcon == 1
    end
end
local function SuperVisual(target, texture, replace)
    target.macroProvider = "supermacro"
    if replace and Text(texture) then target.texture = texture end
end
local function Context(callback, first, second, third)
    local previousThis, previousEvent, previousArg = this, event, arg1
    local ran, result, failure = pcall(callback, first, second, third)
    this, event, arg1 = previousThis, previousEvent, previousArg
    if not ran then return false, tostring(result) end
    if result == false then return false, failure end
    return true, result
end

-- No parser, frame, timer or macro execution belongs in this adapter. It
-- consumes the installed addons' current API hooks and resolved macro cache.
function MacroActionService.Create(api)
    api = api or _G
    local service = {}
    local active, observer = false, nil
    local registrations = {}

    function service.Apply(slot, target, partial, resolvedName)
        if not ValidSlot(slot) then return nil, "invalid-slot" end
        if type(target) ~= "table" then return nil, "invalid-target" end
        target.macroProvider = nil
        if not Enabled(target.hasAction) then return target end
        if CleveOwns(api, slot) then
            target.macroProvider = "cleveroids"
            if partial then
                local getTexture, getCount = Function(api, "GetActionTexture"), Function(api, "GetActionCount")
                if getTexture then target.texture = getTexture(slot) end
                if partial == true and getCount then target.count = Count(getCount(slot)) end
            end
            return target
        end
        local kind, action, texture, replace = SuperAction(api, slot, resolvedName)
        if not kind then return target end
        SuperVisual(target, texture, replace)
        if kind == "item" then
            local find = Function(api, "FindItem")
            if find and Text(action) then
                local id, book, itemTexture, count = find(action)
                target.count = Count(count)
            end
        end
        return target
    end

    -- SuperMacro's GetActionCooldown writes directly into foreign Icon/Count
    -- regions. Resolve its known cached action once so our data/render owner
    -- keeps hidden labels inert and does not scan the same bags twice.
    function service.ReadCooldown(slot, target, resolvedName)
        if not ValidSlot(slot) then return nil, "invalid-slot" end
        if type(target) ~= "table" then return nil, "invalid-target" end
        if not Enabled(target.hasAction) then return nil end
        local kind, action, texture, replace = SuperAction(api, slot, resolvedName)
        if not kind then return nil end
        local start, duration, enabled
        if kind == "spell" then
            local find, cooldown = Function(api, "SM_FindSpell"), Function(api, "GetSpellCooldown")
            if not find or not cooldown then return nil end
            local id, book = find(action)
            if not id then return nil end
            start, duration, enabled = cooldown(id, book)
        else
            local find, bagCooldown, inventoryCooldown = Function(api, "FindItem"),
                Function(api, "GetContainerItemCooldown"), Function(api, "GetInventoryItemCooldown")
            if not find or not bagCooldown or not inventoryCooldown then return nil end
            local id, book, itemTexture, count = find(action)
            target.count = Count(count)
            if book then start, duration, enabled = bagCooldown(id, book)
            elseif id then start, duration, enabled = inventoryCooldown("player", id)
            else start, duration, enabled = 0, 0, 0 end
        end
        SuperVisual(target, texture, replace)
        target.cooldownStart, target.cooldownDuration = Nonnegative(start), Nonnegative(duration)
        target.cooldownEnabled = Enabled(enabled)
        return target
    end

    local function DrawTooltip(slot, button)
        local tooltip = api.GameTooltip
        if not tooltip or type(tooltip.SetOwner) ~= "function" or type(tooltip.SetAction) ~= "function" then
            return false, "unavailable-api"
        end
        local nativeEvent, nativeArg = event, arg1
        this = button
        tooltip:SetOwner(button, "ANCHOR_RIGHT")
        this, event, arg1 = button, nativeEvent, nativeArg
        tooltip:SetAction(slot)
        this, event, arg1 = button, nativeEvent, nativeArg
        -- CleveRoids already hooks SetAction, and its conditional selection
        -- takes precedence over SuperMacro's first-action tooltip heuristic.
        if not CleveOwns(api, slot) then
            local setTooltip, getText = Function(api, "SM_ActionButton_SetTooltip"), Function(api, "GetActionText")
            if setTooltip and getText and Text(getText(slot)) then
                this, event, arg1 = button, nativeEvent, nativeArg
                setTooltip(slot)
            end
        end
        this, event, arg1 = button, nativeEvent, nativeArg
        if type(tooltip.Show) == "function" then tooltip:Show() end
        return true
    end
    function service.Tooltip(slot, button)
        if not ValidSlot(slot) then return false, "invalid-slot" end
        if type(button) ~= "table" and type(button) ~= "userdata" then return false, "invalid-button" end
        return Context(DrawTooltip, slot, button)
    end
    local function HideTooltip(slot, button)
        local tooltip = api.GameTooltip
        if not tooltip or type(tooltip.IsOwned) ~= "function" or not tooltip:IsOwned(button) then return true end
        local nativeEvent, nativeArg = event, arg1
        this = button
        local leave = not CleveOwns(api, slot) and Function(api, "SM_ActionButton_OnLeave")
        if leave then leave()
        elseif type(tooltip.Hide) == "function" then tooltip:Hide() end
        this, event, arg1 = button, nativeEvent, nativeArg
        return true
    end
    function service.LeaveTooltip(slot, button)
        if not ValidSlot(slot) then return false, "invalid-slot" end
        if type(button) ~= "table" and type(button) ~= "userdata" then return false, "invalid-button" end
        return Context(HideTooltip, slot, button)
    end

    local function Register(provider)
        local register = provider.RegisterActionEventHandler
        if type(register) ~= "function" then return true end
        for _, record in ipairs(registrations) do if record.provider == provider then return true end end
        local record = {provider = provider}
        record.callback = function(slot, name)
            -- The installed API has no unregister operation. One retained
            -- callback becomes inert before hiding/stopping the owned bars.
            if not active or api.CleveRoids ~= provider or not observer or not ValidSlot(slot) then return end
            if name ~= "ACTIONBAR_SLOT_CHANGED" and name ~= "ACTIONBAR_UPDATE_COOLDOWN"
                and name ~= "ACTIONBAR_UPDATE_USABLE" and name ~= "ACTIONBAR_UPDATE_STATE" then return end
            local ok, failure = Context(observer, slot, name)
            if not ok then error(failure or "Macro action refresh was declined.", 0) end
        end
        -- Retain before registering: a late throwing hook may already have
        -- inserted the callback, so retry must not append a duplicate.
        table.insert(registrations, record)
        local ok, failure = Context(register, record.callback)
        if not ok then record.failure = failure or "Macro callback registration was declined."; return false, record.failure end
        return true
    end
    function service.RefreshProvider()
        if not active then return true end
        local provider = api.CleveRoids
        if type(provider) ~= "table" then return true end
        for _, record in ipairs(registrations) do
            if record.provider == provider and record.failure then return false, record.failure end
        end
        return Register(provider)
    end
    function service.Enable(callback)
        if type(callback) ~= "function" then return false, "invalid-callback" end
        observer, active = callback, true
        local ok, failure = service.RefreshProvider()
        if not ok then active, observer = false, nil end
        return ok, failure
    end
    function service.Disable()
        active, observer = false, nil
        return true
    end
    return service
end
