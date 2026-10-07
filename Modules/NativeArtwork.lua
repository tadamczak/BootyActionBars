local Bars = BootyActionBars
local Artwork = {}
Bars.Modules.NativeArtwork = Artwork
local names = {"MainMenuBarTexture0", "MainMenuBarTexture1", "MainMenuBarTexture2", "MainMenuBarTexture3",
    "MainMenuBarLeftEndCap", "MainMenuBarRightEndCap", "BonusActionBarTexture0", "BonusActionBarTexture1"}
local records = {}
local state = {active = false, restorationBlocked = false, partial = false,
    restoredTargets = 0, replacedTargets = 0, restoreFailures = 0}
local function Global(name) if type(getglobal) == "function" then return getglobal(name) end; return _G[name] end
local function Field(region, key) return region[key] end
local function Assign(region, value) region.SetAlpha = value end
local function Alpha(value) return type(value) == "number" and value == value and value >= 0 and value <= 1 end
local function Read(callback, value)
    local oldThis, oldEvent, oldArg = this, event, arg1
    local ok, result, detail = pcall(callback, value)
    this, event, arg1 = oldThis, oldEvent, oldArg
    return ok, result, detail
end
local function Write(callback, first, second)
    local oldThis, oldEvent, oldArg = this, event, arg1
    local ok, result = pcall(callback, first, second)
    this, event, arg1 = oldThis, oldEvent, oldArg
    return ok, result
end
local function Record(index)
    local record = records[index]
    if record then return record end
    record = {}; records[index] = record
    record.guard = function(region, value)
        if record.enabled and region == record.region then
            if not Alpha(value) then error("SetAlpha requires a number from 0 to 1.", 0) end
            -- Suppressed writes retain native/foreign intent without calling
            -- hooks again or doing work on each rendered frame.
            record.desired = value
            return
        end
        return record.originalSetter(region, value)
    end
    return record
end
local function Fail(reason)
    state.restoreFailures = state.restoreFailures + 1
    state.failure = state.failure and state.failure .. "; " .. tostring(reason) or tostring(reason)
end
local function Foreign(record, detail)
    if not record.replaced then state.replacedTargets = state.replacedTargets + 1; record.replaced = true end
    Fail(record.name .. " ownership changed: " .. detail)
end
local function OwnedGlobal(record)
    local ok, current = Read(Global, record.name)
    if not ok then Fail(current); return false end
    if current ~= record.region then Foreign(record, "global region"); return false end
    return true
end
local function OwnedGetter(record)
    local ok, current = Write(Field, record.region, "GetAlpha")
    if not ok then Fail(current); return false end
    if current ~= record.getter then Foreign(record, "GetAlpha method"); return false end
    return true
end
local function Cleanup()
    state.active = false
    state.failure, state.partial = nil, false
    state.restoredTargets, state.replacedTargets, state.restoreFailures = 0, 0, 0
    -- No subsequent failing setter can leave another live suppressing guard.
    for index = 1, 8 do if records[index] then records[index].enabled = false end end
    for index = 1, 8 do
        local record = records[index]
        if record and record.region and record.touched then
            local globalOwned = OwnedGlobal(record)
            local ok, setter = Write(Field, record.region, "SetAlpha")
            local methodOwned = false
            if not ok then Fail(setter)
            elseif setter == record.guard then
                local restored, failure = Write(Assign, record.region, record.originalSetter)
                if not restored then Fail(failure) end
                local checked, current = Write(Field, record.region, "SetAlpha")
                if not checked then Fail(current)
                elseif current ~= record.originalSetter then Fail(record.name .. " refused SetAlpha restoration.")
                else methodOwned = true end
            elseif setter == record.originalSetter and not record.installed then methodOwned = true
            else Foreign(record, "SetAlpha method") end
            local valueOwned = true
            if record.alphaTouched then
                valueOwned = false
                if globalOwned and methodOwned and OwnedGetter(record) then
                    local read, current = Read(record.getter, record.region)
                    if not read then Fail(current)
                    elseif not Alpha(current) then Fail(record.name .. " returned invalid alpha during restoration.")
                    elseif current ~= 0 then
                        if not record.masked and current == record.initial then valueOwned = true
                        else Foreign(record, "direct alpha") end
                    else
                        local owned = OwnedGlobal(record) and OwnedGetter(record)
                        local checked, setterNow = Write(Field, record.region, "SetAlpha")
                        if not checked then Fail(setterNow); owned = false
                        elseif setterNow ~= record.originalSetter then Foreign(record, "SetAlpha method"); owned = false end
                        local restored = false
                        if owned then
                            local reason
                            restored, reason = Write(record.originalSetter, record.region, record.desired)
                            if not restored then Fail(reason) end
                            owned = OwnedGlobal(record) and OwnedGetter(record)
                            checked, setterNow = Write(Field, record.region, "SetAlpha")
                            if not checked then Fail(setterNow); owned = false
                            elseif setterNow ~= record.originalSetter then Foreign(record, "SetAlpha method"); owned = false end
                        end
                        if owned then
                            local verified, actual = Read(record.getter, record.region)
                            if not verified then Fail(actual)
                            -- Native alpha may be packed into an 8-bit value.
                            elseif not Alpha(actual) or math.abs(actual - record.desired) > 1 / 255 + 1e-8 then
                                Fail(record.name .. " refused alpha restoration.")
                            elseif restored then valueOwned = true end
                        end
                    end
                end
            end
            if globalOwned and methodOwned and valueOwned then state.restoredTargets = state.restoredTargets + 1 end
        end
        if record then
            record.region, record.getter, record.desired, record.initial = nil, nil, nil, nil
            record.touched, record.installed, record.alphaTouched, record.masked = nil, nil, nil, nil
        end
    end
    state.partial = state.replacedTargets > 0 or state.restoreFailures > 0
    if state.partial then
        state.restorationBlocked = true
        state.failure = state.failure .. " Reload before another native artwork lease."
        return false, state.failure
    end
    return true
end
local function Snapshot()
    for index = 1, 8 do
        local name, record = names[index], Record(index)
        local region = Global(name)
        if not region or type(region.SetAlpha) ~= "function" or type(region.GetAlpha) ~= "function" then
            return false, "Native " .. name .. " is unavailable or has no alpha API."
        end
        if region.SetAlpha == record.guard then
            state.restorationBlocked = true
            return false, "A retired " .. name .. " alpha guard is still installed; reload before replacement."
        end
        local ok, alpha = Read(region.GetAlpha, region)
        if not ok then return false, tostring(alpha) end
        if not Alpha(alpha) then return false, "Native " .. name .. " has invalid alpha." end
        record.name, record.region, record.getter = name, region, region.GetAlpha
        record.originalSetter, record.desired, record.initial = region.SetAlpha, alpha, alpha
        record.enabled, record.replaced = false, false
    end
    return true
end
local function Begin()
    local ok, failure = Snapshot(); if not ok then return false, failure end
    if state.releaseRequested then return false, "Native artwork lease was cancelled during synchronization." end
    for index = 1, 8 do
        local record, region = records[index], records[index].region
        if Global(record.name) ~= region or region.SetAlpha ~= record.originalSetter or region.GetAlpha ~= record.getter then
            return false, record.name .. " ownership changed before native artwork replacement."
        end
        local current, alphaBefore = Read(record.getter, region)
        if not current then return false, tostring(alphaBefore) end
        if state.releaseRequested then return false, "Native artwork lease was cancelled during synchronization." end
        if alphaBefore ~= record.initial then return false, record.name .. " alpha changed before native artwork replacement." end
        if Global(record.name) ~= region or region.SetAlpha ~= record.originalSetter or region.GetAlpha ~= record.getter then
            return false, record.name .. " ownership changed before native artwork replacement."
        end
        if state.releaseRequested then return false, "Native artwork lease was cancelled during synchronization." end
        record.touched, record.enabled = true, true
        Assign(region, record.guard)
        if region.SetAlpha ~= record.guard then return false, record.name .. " refused its alpha guard." end
        record.installed = true
        if state.releaseRequested then return false, "Native artwork lease was cancelled during synchronization." end
        record.alphaTouched = true
        local written, reason = Write(record.originalSetter, region, 0)
        if not written then return false, tostring(reason) end
        if state.releaseRequested then return false, "Native artwork lease was cancelled during synchronization." end
        if Global(record.name) ~= region or region.SetAlpha ~= record.guard or region.GetAlpha ~= record.getter then
            return false, record.name .. " ownership changed while hiding native artwork."
        end
        local read, alpha = Read(record.getter, region)
        if not read then return false, tostring(alpha) end
        if alpha ~= 0 then return false, record.name .. " refused hidden alpha." end
        record.masked = true
    end
    state.active, state.failure = true, nil
    state.partial, state.restoredTargets, state.replacedTargets, state.restoreFailures = false, 0, 0, 0
    return true
end
local function CheckActive()
    for index = 1, 8 do
        local record = records[index]
        if Global(record.name) ~= record.region or record.region.SetAlpha ~= record.guard or record.region.GetAlpha ~= record.getter then
            return false, record.name .. " artwork ownership changed while leased."
        end
        local ok, alpha = Read(record.getter, record.region)
        if not ok then return false, tostring(alpha) end
        if alpha ~= 0 then return false, record.name .. " artwork alpha changed while leased." end
    end
    return true
end
function Artwork.Sync(requested)
    if type(requested) ~= "boolean" then return false, "Native artwork requires an explicit visibility lease." end
    if not requested then return Artwork.Release() end
    if state.restorationBlocked then return false, state.failure end
    if state.busy then return false, "Native artwork ownership is already changing." end
    state.busy, state.syncing, state.releaseRequested = true, true, nil
    local ok, success, failure = Read(state.active and CheckActive or Begin)
    if not ok then failure, success = success, false end
    if state.releaseRequested then success, failure = false, failure or "Native artwork lease was cancelled during synchronization." end
    if not success then
        local original = tostring(failure)
        local restored, reason = Cleanup()
        state.failure = restored and original or original .. " Restoration: " .. tostring(reason)
    end
    state.busy, state.syncing, state.releaseRequested = nil, nil, nil
    return success, state.failure
end
function Artwork.Release()
    if state.busy then
        if state.syncing then state.releaseRequested = true end
        return false, "Native artwork ownership is already changing."
    end
    if not state.active then
        if state.restorationBlocked then return false, state.failure end
        return true
    end
    state.busy = true
    local ok, failure = Cleanup()
    state.busy = nil
    return ok, failure
end
function Artwork.GetState() return state end
