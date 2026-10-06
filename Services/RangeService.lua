local RangeService = {}
BootyActionBars.Services.RangeService = RangeService
local floor = math.floor
local function Enabled(value) return value ~= nil and value ~= false and value ~= 0 end

-- Vanilla has no movement/range-change event. Hooks are resolved at read time
-- so macro providers retain their own target and conditional spell policy.
function RangeService.Create(api)
    api = api or _G
    local service = {}
    function service.HasTarget()
        return type(api.UnitExists) == "function" and Enabled(api.UnitExists("target")) or false
    end
    function service.Read(slot, target, targetPresent, cachedCapability)
        if type(slot) ~= "number" or slot < 1 or slot > 120 or slot ~= floor(slot) then return nil, "invalid-slot" end
        if type(target) ~= "table" then return nil, "invalid-target" end
        local knownRange = cachedCapability and target.hasRange
        target.hasRange, target.inRange = false, nil
        if not Enabled(target.hasAction) or type(api.IsActionInRange) ~= "function" then return target end
        local nativeThis, nativeEvent, nativeArg = this, event, arg1
        target.hasRange = knownRange == true
        if not cachedCapability and type(api.ActionHasRange) == "function" then target.hasRange = Enabled(api.ActionHasRange(slot)) end
        this, event, arg1 = nativeThis, nativeEvent, nativeArg
        if type(api.ActionHasRange) == "function" and not target.hasRange then return target end
        if targetPresent == nil then targetPresent = service.HasTarget() end
        this, event, arg1 = nativeThis, nativeEvent, nativeArg
        if not targetPresent then return target end
        local result = api.IsActionInRange(slot)
        this, event, arg1 = nativeThis, nativeEvent, nativeArg
        if result ~= nil and result ~= 0 and result ~= 1 then error("Invalid action range result.") end
        target.inRange = result
        -- A client without ActionHasRange can still expose a definitive range.
        if type(api.ActionHasRange) ~= "function" then target.hasRange = result ~= nil end
        return target
    end
    return service
end
