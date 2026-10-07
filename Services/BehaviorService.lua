local Bars = BootyActionBars
local Behavior = {}
Bars.Services.BehaviorService = Behavior
Behavior.LIMIT = 16
local floor = math.floor
local classes = {WARRIOR=true, PALADIN=true, HUNTER=true, ROGUE=true, PRIEST=true,
    SHAMAN=true, MAGE=true, WARLOCK=true, DRUID=true}
local fields = {"condition", "sourceBar", "classToken", "locale", "formName"}
local snapshotFields = {"classToken", "locale", "formName", "stealthed", "prowl", "shadowmeld", "auraReady"}
local function Integer(value, minimum, maximum)
    return type(value) == "number" and value == value and value >= minimum and value <= maximum and value == floor(value)
end
local function Text(value)
    return type(value) == "string" and string.len(value) > 0 and string.len(value) <= 128 and not string.find(value, "[%c]")
end
local function Locale(value)
    return type(value) == "string" and string.find(value, "^[a-z][a-z][A-Z][A-Z]$") ~= nil
end
local function Plain(value) return type(value) == "table" and getmetatable(value) == nil end
function Behavior.ValidID(id) return Integer(id, 1, 6) end
function Behavior.ValidateRule(rule)
    if not Plain(rule) or not Integer(rule.sourceBar, 1, 6) then return false, "Choose a source action bar from 1 to 6." end
    if rule.condition ~= "stealth" and rule.condition ~= "form" then return false, "Choose Stealth or a form." end
    for key in pairs(rule) do
        if key ~= "condition" and key ~= "sourceBar" and not (rule.condition == "form"
            and (key == "classToken" or key == "locale" or key == "formName")) then return false, "Unexpected action bar rule data." end
    end
    if rule.condition == "form" and (not classes[rule.classToken] or not Locale(rule.locale) or not Text(rule.formName)) then
        return false, "A form rule needs its class, client language and exact form name."
    end
    return true
end
function Behavior.Validate(value)
    if value == nil then return true end
    if not Plain(value) then return false, "Invalid saved action bar rules. Preserve the saved file before repairing it." end
    for id, list in pairs(value) do
        if not Behavior.ValidID(id) or not Plain(list) then return false, "Rules belong only to ordinary action bars 1 to 6." end
        local count = 0
        for index, rule in pairs(list) do
            if not Integer(index, 1, Behavior.LIMIT) then return false, "At most 16 ordered rules are supported per bar." end
            local ok, failure = Behavior.ValidateRule(rule)
            if not ok then return false, failure end
            count = count + 1
        end
        for index = 1, count do if list[index] == nil then return false, "Action bar rules must have a continuous order." end end
        for index = 1, count do
            for earlier = 1, index - 1 do
                local first, second = list[earlier], list[index]
                if first.condition == second.condition and (first.condition == "stealth"
                    or first.classToken == second.classToken and first.locale == second.locale and first.formName == second.formName) then
                    return false, "A condition can appear only once in a bar's ordered rules."
                end
            end
        end
    end
    return true
end
local function RuleCopy(rule)
    local result = {}
    for _, key in ipairs(fields) do result[key] = rule[key] end
    return result
end
function Behavior.Copy(value)
    local ok, failure = Behavior.Validate(value)
    if not ok then return nil, failure end
    local result = {}
    for id, list in pairs(value or {}) do
        result[id] = {}
        for index, rule in ipairs(list) do result[id][index] = RuleCopy(rule) end
    end
    return result
end
function Behavior.Equal(first, second)
    -- Ownership checks also see values written by callbacks after validation.
    if not Behavior.Validate(first) or not Behavior.Validate(second) then return false end
    for id = 1, 6 do
        local a, b = first and first[id], second and second[id]
        for index = 1, Behavior.LIMIT do
            local x, y = a and a[index], b and b[index]
            if (x == nil) ~= (y == nil) then return false end
            if x then for _, key in ipairs(fields) do if x[key] ~= y[key] then return false end end end
        end
    end
    return true
end
local function Candidate(value, id)
    if not Behavior.ValidID(id) then return nil, "Choose an ordinary action bar from 1 to 6." end
    local result, failure = Behavior.Copy(value)
    if not result then return nil, failure end
    result[id] = result[id] or {}
    return result, table.getn(result[id])
end
function Behavior.PrepareUpdate(value, id, index, rule)
    local ok, failure = Behavior.ValidateRule(rule)
    if not ok then return nil, failure end
    local result, count = Candidate(value, id)
    if not result then return nil, count end
    if index == nil then
        if count >= Behavior.LIMIT then return nil, "At most 16 ordered rules are supported per bar." end
        index = count + 1
    elseif not Integer(index, 1, count) then return nil, "Choose an existing action bar rule." end
    result[id][index] = RuleCopy(rule)
    ok, failure = Behavior.Validate(result)
    if not ok then return nil, failure end
    return result
end
function Behavior.PrepareRemove(value, id, index)
    local result, count = Candidate(value, id)
    if not result then return nil, count end
    if not Integer(index, 1, count) then return nil, "Choose an existing action bar rule." end
    table.remove(result[id], index)
    if count == 1 then result[id] = nil end
    return result
end
function Behavior.PrepareMove(value, id, index, destination)
    local result, count = Candidate(value, id)
    if not result then return nil, count end
    if not Integer(index, 1, count) or not Integer(destination, 1, count) then return nil, "Choose an existing rule and priority." end
    local rule = table.remove(result[id], index)
    table.insert(result[id], destination, rule)
    return result
end
local function Run(callback, first, second)
    local oldThis, oldEvent, oldArg = this, event, arg1
    local ran, result, detail, extra = pcall(callback, first, second)
    this, event, arg1 = oldThis, oldEvent, oldArg
    if not ran then return nil, "Action bar behavior state could not be read: " .. tostring(result) end
    return result, detail, extra
end
local function Identity(api)
    if type(api.UnitClass) ~= "function" or type(api.GetLocale) ~= "function" then error("The native class or language API is unavailable.") end
    local _, class = api.UnitClass("player")
    local locale = api.GetLocale()
    if not classes[class] or not Locale(locale) then error("The player's class or client language is unavailable.") end
    return class, locale
end
local function Enabled(value)
    if value ~= nil and value ~= false and value ~= true and value ~= 0 and value ~= 1 then error("Invalid native form or stealth state.") end
    return value ~= nil and value ~= false and value ~= 0
end
local function Forms(api, target, catalog, class, locale)
    if type(api.GetNumShapeshiftForms) ~= "function" or type(api.GetShapeshiftFormInfo) ~= "function" then error("The native form API is unavailable.") end
    local count = api.GetNumShapeshiftForms()
    if not Integer(count, 0, 10) then error("Invalid native form count.") end
    target.formName = nil
    for index = 1, count do
        local texture, name, active = api.GetShapeshiftFormInfo(index)
        if not Text(name) then error("A native form name is unavailable.") end
        if catalog then
            for earlier = 1, index - 1 do if catalog[earlier].formName == name then error("Native form names are ambiguous.") end end
            catalog[index] = {classToken=class, locale=locale, formName=name, index=index, texture=texture}
        end
        if Enabled(active) then
            if target.formName then error("Several native forms are active.") end
            target.formName = name
        end
    end
    return target
end
local function Catalog(api)
    local class, locale = Identity(api)
    local result = {}
    Forms(api, {}, result, class, locale)
    return result, class, locale
end
local auraEvents = {PLAYER_ENTERING_WORLD=true, PLAYER_AURAS_CHANGED=true, BOOTY_ACTIONBARS_BEHAVIOR_CONFIG=true}
local stateEvents = {PLAYER_ENTERING_WORLD=true, PLAYER_AURAS_CHANGED=true, UPDATE_BONUS_ACTIONBAR=true,
    UPDATE_SHAPESHIFT_FORMS=true, BOOTY_ACTIONBARS_BEHAVIOR_CONFIG=true}
local function Auras(api, target)
    if type(api.UnitBuff) ~= "function" then error("The native helpful-aura API is unavailable.") end
    target.prowl, target.shadowmeld, target.auraReady = false, false, false
    for index = 1, 32 do
        local texture = api.UnitBuff("player", index)
        if texture == nil then break end
        if type(texture) ~= "string" then error("Invalid native helpful-aura texture.") end
        -- Stock texture paths and spelling, verified against the installed
        -- client's macro provider. No hidden tooltip or spellbook scan.
        if target.classToken == "DRUID" and texture == "Interface\\Icons\\Spell_Nature_Invisibilty" then target.prowl = true
        elseif texture == "Interface\\Icons\\Spell_Nature_WispSplode" then target.shadowmeld = true end
    end
    target.auraReady = true
end
function Behavior.Create(api)
    api = api or _G
    local service = {}
    local state = {rules={}, live={}, snapshot={}, scratch={}, generation=0, ready=false}
    local function Read(name)
        local value = state.scratch
        for _, key in ipairs(snapshotFields) do value[key] = state.snapshot[key] end
        if not state.classToken then state.classToken, state.locale = Identity(api) end
        value.classToken, value.locale = state.classToken, state.locale
        if state.needForms or state.needStealth and value.classToken == "ROGUE" then Forms(api, value) end
        if state.needStealth then
            local rogue = false
            if value.classToken == "ROGUE" then
                if type(api.GetBonusBarOffset) ~= "function" then error("The native bonus-bar API is unavailable.") end
                local bonus = api.GetBonusBarOffset()
                if not Integer(bonus, 0, 4) then error("Invalid native bonus-bar state.") end
                rogue = value.formName ~= nil or bonus > 0
            end
            -- Known release 1.15.15 uses the verified sneak bit. Older builds
            -- used an aura-level byte; presence alone is not a valid gate.
            local trusted = api.CLASSIC_API_VERSION == 11515 and type(api.IsStealthed) == "function"
            local fast = trusted and Enabled(api.IsStealthed())
            if fast then
                value.stealthed = true
                -- The fast result skips observing this aura change. An older
                -- positive aura must not survive a later false fast result.
                if not state.ready or auraEvents[name] then value.auraReady = false end
            else
                if not state.ready or not value.auraReady or auraEvents[name] then Auras(api, value) end
                value.stealthed = rogue or value.prowl == true or value.shadowmeld == true
            end
        else value.stealthed, value.prowl, value.shadowmeld, value.auraReady = false, false, false, false end
        return value
    end
    function service.Configure(rules, liveBars)
        local candidate, failure = Behavior.Copy(rules)
        if not candidate then return false, failure end
        if not Plain(liveBars) then return false, "Active action bar identities are unavailable." end
        for id, enabled in pairs(liveBars) do
            if not Behavior.ValidID(id) or type(enabled) ~= "boolean" then return false, "Invalid active action bar identities." end
        end
        local changed = not Behavior.Equal(candidate, state.rules)
        local forms, stealth = false, false
        for id = 1, 6 do
            if (state.live[id] == true) ~= (liveBars[id] == true) then changed = true end
            state.live[id] = liveBars[id] == true
            if state.live[id] then
                for _, rule in ipairs(candidate[id] or {}) do
                    if rule.condition == "form" then forms = true else stealth = true end
                end
            end
        end
        state.rules, state.needForms, state.needStealth = candidate, forms, stealth
        if changed then state.generation = state.generation + 1; state.ready = false end
        return true
    end
    function service.Refresh(name)
        if not state.needForms and not state.needStealth then return true, false end
        if not stateEvents[name] then return true, false end
        if state.reading then
            state.pending = name
            if auraEvents[name] then state.pendingAura = true end
            return true, false
        end
        state.reading = true
        local changed = false
        for pass = 1, 2 do
            local generation = state.generation
            state.pending, state.pendingAura = nil, nil
            local value, failure = Run(Read, name)
            if not value then state.reading, state.ready = nil, false; return false, failure end
            if generation == state.generation and not state.pending then
                for _, key in ipairs(snapshotFields) do
                    if state.snapshot[key] ~= value[key] then changed = true end
                    state.snapshot[key] = value[key]
                end
                state.ready, state.reading = true, nil
                return true, changed
            end
            if not state.needForms and not state.needStealth then state.reading = nil; return true, false end
            if state.pendingAura or auraEvents[name] then name = "PLAYER_AURAS_CHANGED"
            else name = state.pending or "BOOTY_ACTIONBARS_BEHAVIOR_CONFIG" end
        end
        state.reading, state.ready = nil, false
        return false, "Action bar behavior updates did not settle after two reads."
    end
    function service.Resolve(id, baseOffset, basePage)
        if not Behavior.ValidID(id) then return nil, "Choose an ordinary action bar from 1 to 6." end
        local list = state.live[id] and state.rules[id]
        if list and table.getn(list) > 0 then
            if not state.ready then return nil, "Action bar behavior state is not ready." end
            for index, rule in ipairs(list) do
                if rule.condition == "stealth" and state.snapshot.stealthed
                    or rule.condition == "form" and rule.classToken == state.snapshot.classToken
                    and rule.locale == state.snapshot.locale and rule.formName == state.snapshot.formName then
                    return (rule.sourceBar - 1) * 12, rule.sourceBar, index
                end
            end
        end
        if not Integer(baseOffset, 0, 108) or not Integer(basePage, 1, 10) or baseOffset ~= (basePage - 1) * 12 then
            return nil, "The fallback action bar page is unavailable or invalid."
        end
        return baseOffset, basePage
    end
    function service.ReadCatalog() return Run(Catalog, api) end
    return service
end
