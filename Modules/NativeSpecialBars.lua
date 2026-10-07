local Bars = BootyActionBars
local NativeSpecial = {}
Bars.Modules.NativeSpecialBars = NativeSpecial
local state = {active = false, pet = false, stance = false, restorationBlocked = false,
    partial = false, restoredTargets = 0, replacedTargets = 0, restoreFailures = 0}
local kinds = {"pet", "stance"}
local records = {
    pet = {name = "PetActionBarFrame", presence = "PetHasActionBar"},
    stance = {name = "ShapeshiftBarFrame", presence = "GetNumShapeshiftForms"},
}
local Cleanup, failureObserver
local changing = 0
local notifyingFailure = false
local releaseRequested = false
local cancellation = "Native special-bar lease was cancelled during synchronization."
local function GuardFailure(failure)
    local oldThis, oldEvent, oldArg = this, event, arg1
    local original = tostring(failure)
    -- Public Sync already returns failure to Runtime, which releases all
    -- owners. Retained native Show also runs outside that caller boundary.
    if changing == 0 then
        changing = changing + 1
        local ran, restored, reason = pcall(Cleanup, true, true)
        changing = changing - 1
        releaseRequested = false
        if not ran then original = original .. " Restoration: " .. tostring(restored)
        elseif not restored then original = original .. " Restoration: " .. tostring(reason) end
        this, event, arg1 = oldThis, oldEvent, oldArg
        state.failure = original
        if failureObserver then
            notifyingFailure = true
            local notified, result, detail = pcall(failureObserver, original)
            notifyingFailure = false
            this, event, arg1 = oldThis, oldEvent, oldArg
            if not notified then original = original .. " Failure observer: " .. tostring(result)
            elseif result == false then original = original .. " Failure observer: " .. tostring(detail or "Native cleanup was declined.")
            elseif type(detail) == "string" and detail ~= original then
                if string.sub(detail, 1, string.len(original)) == original then original = detail
                else original = original .. " Native cleanup: " .. detail end
            end
            state.failure = original
        end
    end
    this, event, arg1 = oldThis, oldEvent, oldArg
    error(original, 0)
end
local function Shown(value) return value ~= nil and value ~= false and value ~= 0 end
local function Global(name)
    if type(getglobal) == "function" then return getglobal(name) end
    return _G[name]
end
local function Field(frame, name) return frame[name] end
local function Assign(frame, name, value) frame[name] = value end
local function Fail(message)
    state.restoreFailures = state.restoreFailures + 1
    if not state.failure then state.failure = tostring(message) end
end
local function Invoke(record, callback)
    local previousThis, previousEvent, previousArg = this, event, arg1
    this = record.frame
    local ok, failure = pcall(callback, record.frame)
    this, event, arg1 = previousThis, previousEvent, previousArg
    return ok, failure
end
for _, kind in ipairs(kinds) do
    local record = records[kind]
    record.showGuard = function(frame)
        if not record.enabled then return record.originalShow(frame) end
        record.showRequested = true
    end
    record.onShowGuard = function()
        if not record.enabled then
            if record.originalOnShow then return record.originalOnShow() end
            return
        end
        -- Engine/native callers can retain the original Show method. Hide
        -- before those paths render, without replacing keyboard or event APIs.
        if record.hiding then return end
        record.showRequested = true
        record.hiding = true
        local ok, failure = Invoke(record, record.hide)
        record.hiding = nil
        if not ok then return GuardFailure(failure) end
        local read, visible = Invoke(record, record.isShown)
        if not read then return GuardFailure(visible) end
        if Shown(visible) then return GuardFailure(record.name .. " rejected its visibility lease.") end
    end
end
local function UpdateState()
    state.pet, state.stance = records.pet.enabled == true, records.stance.enabled == true
    state.active = state.pet or state.stance
end
local function RestoreField(record, name, original, guard, script, attempted)
    if not attempted then return true end
    local ok, value
    if script then ok, value = pcall(record.getScript, record.frame, name)
    else ok, value = pcall(Field, record.frame, name) end
    if not ok then Fail(value); return false end
    if value == original then return true end
    if value ~= guard then record.replaced = true; return false end
    if script then ok, value = pcall(record.setScript, record.frame, name, original)
    else ok, value = pcall(Assign, record.frame, name, original) end
    if not ok then Fail(value); return false end
    if script then ok, value = pcall(record.getScript, record.frame, name)
    else ok, value = pcall(Field, record.frame, name) end
    if not ok then Fail(value); return false end
    if value ~= original then Fail(record.name .. " rejected callback restoration."); return false end
    return true
end
local function RestoreVisibility(record)
    local shown = record.shown or record.showRequested
    -- Losing a pet/forms while leased must not resurrect an empty stock bar.
    -- Preserve initially hidden intent unless stock subsequently requests Show.
    if shown then
        local resolved, api = pcall(Global, record.presence)
        if not resolved then
            Fail(api)
            local hidden, failure = Invoke(record, record.hide)
            if not hidden then Fail(failure) end
            return false
        end
        if type(api) == "function" then
            local ok, available = pcall(api)
            if not ok then
                Fail(available)
                local hidden, failure = Invoke(record, record.hide)
                if not hidden then Fail(failure) end
                return false
            end
            if record.presence == "GetNumShapeshiftForms" then
                if type(available) ~= "number" or available ~= available or available < 0
                    or available >= 1e300 or available ~= math.floor(available) then
                    Fail("The native shapeshift count is invalid."); return false
                end
                shown = available > 0
            else
                if available ~= nil and available ~= false and available ~= 0 and available ~= true and available ~= 1 then
                    Fail("The native pet action-bar availability is invalid."); return false
                end
                shown = Shown(available)
            end
        end
    end
    local ok, failure = Invoke(record, shown and record.originalShow or record.hide)
    if not ok then Fail(failure); return false end
    local read, visible = pcall(record.isShown, record.frame)
    if not read then Fail(visible); return false end
    if Shown(visible) ~= shown then Fail(record.name .. " visibility could not be restored."); return false end
    return true
end
Cleanup = function(pet, stance)
    local touched = pet and records.pet.touched or stance and records.stance.touched
    if not touched then
        -- Snapshot preflight can retain an untouched first target when the
        -- second is missing. No restoration is needed for those references.
        for _, kind in ipairs(kinds) do
            local record = records[kind]
            if (kind == "pet" and pet or kind == "stance" and stance) and not record.enabled then
                record.frame, record.hide, record.isShown, record.getScript, record.setScript = nil, nil, nil, nil, nil
            end
        end
        if state.restorationBlocked then return false, state.failure end
        return true
    end
    if not state.restorationBlocked then
        state.failure, state.partial = nil, false
        state.restoredTargets, state.replacedTargets, state.restoreFailures = 0, 0, 0
    end
    if pet then records.pet.enabled = false end
    if stance then records.stance.enabled = false end
    UpdateState()
    for _, kind in ipairs(kinds) do
        local record = records[kind]
        if (kind == "pet" and pet or kind == "stance" and stance) and record.frame then
            if record.touched then
                local show = RestoreField(record, "Show", record.originalShow, record.showGuard, false, record.showAttempted)
                local onShow = RestoreField(record, "OnShow", record.originalOnShow, record.onShowGuard, true, record.onShowAttempted)
                if record.replaced then state.replacedTargets = state.replacedTargets + 1 end
                -- Foreign owners control visibility once either leased field
                -- changes. Restore only fields still owned by this controller.
                if show and onShow and RestoreVisibility(record) then
                    state.restoredTargets = state.restoredTargets + 1
                end
            end
            record.frame, record.hide, record.isShown, record.getScript, record.setScript = nil, nil, nil, nil, nil
            record.touched, record.showAttempted, record.onShowAttempted, record.hiding = nil, nil, nil, nil
        end
    end
    state.partial = state.restorationBlocked or state.replacedTargets > 0 or state.restoreFailures > 0
    if state.partial then
        state.restorationBlocked = true
        if not state.failure then state.failure = "Native special-bar ownership changed; reload before replacement." end
        return false, state.failure
    end
    return true
end
local function Snapshot(record)
    local frame = Global(record.name)
    if not frame or type(frame.Show) ~= "function" or type(frame.Hide) ~= "function"
        or type(frame.IsShown) ~= "function" or type(frame.GetScript) ~= "function" or type(frame.SetScript) ~= "function" then
        return false, record.name .. " is unavailable or invalid."
    end
    local onShow = frame:GetScript("OnShow")
    if onShow ~= nil and type(onShow) ~= "function" then return false, record.name .. " has an invalid OnShow callback." end
    if frame.Show == record.showGuard or onShow == record.onShowGuard then
        state.restorationBlocked = true
        state.failure = "A retired native special-bar guard is still installed; reload before replacement."
        return false, state.failure
    end
    record.frame, record.originalShow, record.originalOnShow = frame, frame.Show, onShow
    record.hide, record.isShown, record.getScript, record.setScript = frame.Hide, frame.IsShown, frame.GetScript, frame.SetScript
    record.shown, record.replaced, record.showRequested = Shown(frame:IsShown()), false, false
    return true
end
local function Begin(record)
    if releaseRequested then return false, cancellation end
    record.enabled, record.touched, record.showAttempted = true, true, true
    record.frame.Show = record.showGuard
    if releaseRequested then return false, cancellation end
    record.onShowAttempted = true
    record.setScript(record.frame, "OnShow", record.onShowGuard)
    if releaseRequested then return false, cancellation end
    if record.frame.Show ~= record.showGuard or record.getScript(record.frame, "OnShow") ~= record.onShowGuard then
        return false, record.name .. " rejected replacement callbacks."
    end
    if releaseRequested then return false, cancellation end
    local ok, failure = Invoke(record, record.hide)
    if not ok then return false, failure end
    if releaseRequested then return false, cancellation end
    if Shown(record.isShown(record.frame)) then return false, record.name .. " could not be hidden." end
    return true
end
local function SyncBody(requested, pet, stance)
    if not requested or not pet and not stance then return Cleanup(true, true) end
    if state.restorationBlocked then return false, state.failure end
    local policy = Bars.Services.NativeBarPolicy
    if not policy or type(policy.CheckCompeting) ~= "function" then return false, "The native special-bar policy is unavailable." end
    local ok, failure = policy.CheckCompeting()
    if not ok then return false, failure end
    if releaseRequested then return false, cancellation end
    ok, failure = Cleanup(not pet, not stance)
    if not ok then return false, failure end
    if releaseRequested then return false, cancellation end
    -- Both new targets are inspected before touching either frame.
    for _, kind in ipairs(kinds) do
        if releaseRequested then return false, cancellation end
        local record, desired = records[kind], kind == "pet" and pet or kind == "stance" and stance
        if desired then
            if record.enabled then
                if record.frame.Show ~= record.showGuard or record.getScript(record.frame, "OnShow") ~= record.onShowGuard then
                    return false, record.name .. " ownership changed while replaced."
                end
                if releaseRequested then return false, cancellation end
                if Shown(record.isShown(record.frame)) then
                    if releaseRequested then return false, cancellation end
                    ok, failure = Invoke(record, record.hide)
                    if not ok then return false, failure end
                    if releaseRequested then return false, cancellation end
                    if Shown(record.isShown(record.frame)) then return false, record.name .. " could not be hidden." end
                end
            else
                ok, failure = Snapshot(record)
                if not ok then return false, failure end
            end
        end
    end
    for _, kind in ipairs(kinds) do
        if releaseRequested then return false, cancellation end
        local record, desired = records[kind], kind == "pet" and pet or kind == "stance" and stance
        if desired and not record.enabled then
            ok, failure = Begin(record)
            if not ok then return false, failure end
        end
    end
    UpdateState()
    state.failure = nil
    return true
end
function NativeSpecial.Sync(requested, pet, stance)
    if notifyingFailure then return false, "Native special-bar ownership is reporting a failure." end
    if type(requested) ~= "boolean" or type(pet) ~= "boolean" or type(stance) ~= "boolean" then
        return false, "Expected explicit native replacement and live special-bar visibility flags."
    end
    if changing > 0 then
        if not requested then releaseRequested = true end
        return false, "Native special-bar ownership is already changing."
    end
    local previousThis, previousEvent, previousArg = this, event, arg1
    releaseRequested = false
    changing = changing + 1
    local ran, ok, failure = pcall(SyncBody, requested, pet, stance)
    if not ran then failure, ok = ok, false end
    if releaseRequested then ok, failure = false, failure or cancellation end
    if not ok then
        local originalFailure = tostring(failure)
        local restored, reason = Cleanup(true, true)
        state.failure = originalFailure
        if not restored and tostring(reason) ~= originalFailure then
            state.failure = originalFailure .. " Restoration: " .. tostring(reason)
        end
    end
    changing = changing - 1
    releaseRequested = false
    this, event, arg1 = previousThis, previousEvent, previousArg
    return ok, state.failure
end
function NativeSpecial.Release()
    -- A first target may be enabled before UpdateState publishes active. Queue
    -- OFF at every public mutation boundary rather than overlooking that lease.
    if changing > 0 then
        releaseRequested = true
        return false, "Native special-bar ownership is already changing."
    end
    if not state.active then
        if state.restorationBlocked then return false, state.failure end
        return true
    end
    local previousThis, previousEvent, previousArg = this, event, arg1
    changing = changing + 1
    local ok, failure = Cleanup(true, true)
    changing = changing - 1
    releaseRequested = false
    this, event, arg1 = previousThis, previousEvent, previousArg
    return ok, failure
end
function NativeSpecial.SetFailureObserver(callback)
    if callback ~= nil and type(callback) ~= "function" then return false, "Native special-bar failure observer must be a function or nil." end
    failureObserver = callback
    return true
end
function NativeSpecial.GetState() return state end
