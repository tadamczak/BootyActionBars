local Bars = BootyActionBars
local Behavior = Bars.Services.BehaviorService
local Editor = {}
Bars.Modules.BehaviorEditor = Editor
local state = {}
local captures = setmetatable({}, {__mode="k"})
local function Run(callback, first, second, third, fourth)
    local oldThis, oldEvent, oldArg = this, event, arg1
    local ran, result, detail = pcall(callback, first, second, third, fourth)
    this, event, arg1 = oldThis, oldEvent, oldArg
    if not ran then return false, tostring(result) end
    if result == false or result == nil then return false, detail or "Action bar rule editing was declined." end
    return true, result, detail
end
local function Snapshot(store)
    local copy, failure = Behavior.Copy(store.barBehaviors)
    if not copy then return nil, failure end
    local result = {owner=store, root=store.barBehaviors, values=copy, lists={}, records={}}
    for id, list in pairs(store.barBehaviors or {}) do
        result.lists[id], result.records[id] = list, {}
        for index, rule in ipairs(list) do result.records[id][index] = rule end
    end
    return result
end
local function Owned(value)
    local store = BootyActionBarsDB
    if store ~= value.owner or store.barBehaviors ~= value.root then return false, "Action bar rule ownership changed while editing." end
    local valid, failure = Behavior.Validate(store.barBehaviors)
    if not valid then return false, failure end
    if not Behavior.Equal(store.barBehaviors, value.values) then return false, "Action bar rules changed while editing." end
    for id = 1, 6 do
        local list = store.barBehaviors and store.barBehaviors[id]
        if list ~= value.lists[id] then return false, "Action bar rule ownership changed while editing." end
        for index = 1, Behavior.LIMIT do
            if (list and list[index]) ~= (value.records[id] and value.records[id][index]) then
                return false, "Action bar rule ownership changed while editing."
            end
        end
    end
    return true
end
function Editor.Configure(store)
    if type(store) ~= "table" then return false, "Action bar rule settings are unavailable." end
    local ok, failure = Behavior.Validate(store.barBehaviors)
    if not ok then return false, failure end
    state.store = store
    return true
end
function Editor.ValidateCapture(token, id)
    local value = captures[token]
    if not value or value.id ~= id or value.owner ~= state.store then return false, "This action bar rule editor is no longer current." end
    return Owned(value)
end
local function Owner(id, token)
    if not Behavior.ValidID(id) then return nil, "Choose an ordinary action bar from 1 to 6." end
    -- Reject a stale modal before the defaults pipeline can write a new owner.
    if token ~= nil then
        local ok, failure = Editor.ValidateCapture(token, id)
        if not ok then return nil, failure end
    end
    if not state.store or BootyActionBarsDB ~= state.store then return nil, "Action bar rule ownership changed while editing." end
    local valid, failure = Behavior.Validate(state.store.barBehaviors)
    if not valid then return nil, failure end
    local ran, store, detail = Run(Bars.Database.Ensure)
    if not ran then return nil, store end
    if store ~= state.store or BootyActionBarsDB ~= store then return nil, "Action bar rule ownership changed while editing." end
    valid, failure = Behavior.Validate(store.barBehaviors)
    if not valid then return nil, failure end
    if token ~= nil then
        valid, failure = Editor.ValidateCapture(token, id)
        if not valid then return nil, failure end
    end
    return store, detail
end
function Editor.GetRules(id)
    local store, failure = Owner(id)
    if not store then return nil, failure end
    local copy, reason = Behavior.Copy({[id]=store.barBehaviors and store.barBehaviors[id]})
    if not copy then return nil, reason end
    return copy[id] or {}
end
function Editor.Capture(id)
    local store, failure = Owner(id)
    if not store then return nil, failure end
    local value, reason = Snapshot(store)
    if not value then return nil, reason end
    local token = {}
    value.id, captures[token] = id, value
    return token
end
function Editor.ReadCatalog()
    if not state.catalog then state.catalog = Behavior.Create() end
    return state.catalog.ReadCatalog()
end
local function Failure(first, label, detail)
    return tostring(first) .. " " .. label .. ": " .. tostring(detail)
end
local function Restore(before, requested, previousEnabled, firstFailure)
    local engine = Bars.Core.Engine
    local restored, latest = false, nil
    for pass = 1, 2 do
        latest = BootyActionBarsDB
        if type(latest) ~= "table" then
            firstFailure = Failure(firstFailure, "Restoration", "The current saved owner is unavailable.")
            break
        end
        local captured, reason = Snapshot(latest)
        if not captured then firstFailure = Failure(firstFailure, "Restoration", reason); break end
        local ok, failure = Run(engine.ConfigureBehaviors, captured.values)
        if not ok then firstFailure = Failure(firstFailure, "Restoration", failure); break end
        local owned, why = Owned(captured)
        if owned then restored = true; break end
        if pass == 2 then firstFailure = Failure(firstFailure, "Restoration", why) end
    end
    if not restored then
        local stopped, stopFailure = Run(engine.Disable)
        if not stopped then firstFailure = Failure(firstFailure, "Cleanup", stopFailure) end
        return false, firstFailure
    end
    local wanted = requested
    if latest ~= before.owner or latest.trialBarEnabled ~= previousEnabled then wanted = latest.trialBarEnabled == true end
    local currentOK, current = Run(engine.GetState)
    if not currentOK then return false, Failure(firstFailure, "Activity restoration", current) end
    if wanted and not current.requested then
        local active, activeFailure = Run(engine.Enable)
        if not active then firstFailure = Failure(firstFailure, "Activity restoration", activeFailure) end
    elseif not wanted and current.requested then
        local stopped, stopFailure = Run(engine.Disable)
        if not stopped then firstFailure = Failure(firstFailure, "Cleanup", stopFailure) end
    end
    return false, firstFailure
end
local function Commit(store, candidate)
    local before, failure = Snapshot(store)
    if not before then return false, failure end
    if Behavior.Equal(candidate, before.values) then return true end
    local engine = Bars.Core.Engine
    if not engine or type(engine.ConfigureBehaviors) ~= "function" or type(engine.GetState) ~= "function"
        or type(engine.Enable) ~= "function" or type(engine.Disable) ~= "function" then return false, "The action bar behavior engine is unavailable." end
    local requested, enabled = engine.GetState().requested == true, store.trialBarEnabled
    local staged = Behavior.Copy(candidate)
    local ok, reason = Run(engine.ConfigureBehaviors, candidate)
    if ok then ok, reason = Owned(before) end
    if ok and state.store ~= store then ok, reason = false, "Action bar rule ownership changed while editing." end
    if ok then
        ok, reason = Behavior.Validate(candidate)
        if ok and not Behavior.Equal(candidate, staged) then ok, reason = false, "Staged action bar rules changed while editing." end
    end
    if not ok then return Restore(before, requested, enabled, reason) end
    store.barBehaviors = candidate
    return true
end
local function Update(id, index, rule, token)
    local store, failure = Owner(id, token)
    if not store then return false, failure end
    local candidate, reason = Behavior.PrepareUpdate(store.barBehaviors, id, index, rule)
    if not candidate then return false, reason end
    return Commit(store, candidate)
end
local function Remove(id, index, token)
    local store, failure = Owner(id, token)
    if not store then return false, failure end
    local candidate, reason = Behavior.PrepareRemove(store.barBehaviors, id, index)
    if not candidate then return false, reason end
    return Commit(store, candidate)
end
local function Move(id, index, destination, token)
    local store, failure = Owner(id, token)
    if not store then return false, failure end
    local candidate, reason = Behavior.PrepareMove(store.barBehaviors, id, index, destination)
    if not candidate then return false, reason end
    return Commit(store, candidate)
end
local function Mutation(callback, first, second, third, fourth)
    if state.busy then return false, "Action bar rule editing is already in progress." end
    state.busy = true
    local ok, value = Run(callback, first, second, third, fourth)
    state.busy = nil
    if not ok then return false, value end
    return true
end
function Editor.Update(id, index, rule, token) return Mutation(Update, id, index, rule, token) end
function Editor.Remove(id, index, token) return Mutation(Remove, id, index, token) end
function Editor.Move(id, index, destination, token) return Mutation(Move, id, index, destination, token) end
