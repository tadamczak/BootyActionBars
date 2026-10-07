local Service = {}
BootyActionBars.Services.CooldownTextService = Service
local floor, ceil = math.floor, math.ceil
-- Match the installed cooldown-number behavior: omit the global cooldown
-- while preserving the independent native Model animation for every timer.
Service.MIN_DURATION = 2

function Service.Finite(value)
    return type(value) == "number" and value == value and math.abs(value) < 1e300
end
function Service.ValidCooldown(start, duration)
    return Service.Finite(start) and Service.Finite(duration) and start >= 0 and duration >= 0
        and Service.Finite(start + duration)
end
function Service.ValidColor(value) return Service.Finite(value) and value >= 0 and value <= 1 end
function Service.ValidFontSize(value)
    return Service.Finite(value) and value == floor(value) and value >= 8 and value <= 32
end
function Service.Bucket(remaining)
    if not Service.Finite(remaining) then return nil, "Invalid cooldown time." end
    if remaining <= 0 then return 0, 0 end
    if remaining >= 86400 then return 5, ceil(remaining / 86400) end
    if remaining >= 3600 then return 4, ceil(remaining / 3600) end
    if remaining >= 60 then return 3, ceil(remaining / 60) end
    if remaining >= 3 then return 2, ceil(remaining) end
    -- Never print zero while the native timer still has positive time left.
    return 1, math.max(1, ceil(remaining * 10))
end
function Service.Format(kind, value)
    if kind == 0 then return "" end
    if kind == 1 then return string.format("%.1f", value / 10) end
    if kind == 2 then return tostring(value) end
    if kind == 3 then return tostring(value) .. "m" end
    if kind == 4 then return tostring(value) .. "h" end
    if kind == 5 then return tostring(value) .. "d" end
    return nil, "Invalid cooldown display bucket."
end
