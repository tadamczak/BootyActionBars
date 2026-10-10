local Service = {}
BootyActionBars.Services.CooldownTextService = Service
local floor, ceil = math.floor, math.ceil
-- Match the installed cooldown-number behavior: omit the global cooldown
-- while preserving the independent native Model animation for every timer.
Service.MIN_DURATION = 2
Service.EFFECT_STEPS = 63

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
function Service.ValidEffectMode(value) return value == "native" or value == "circle" or value == "vertical" end
function Service.Progress(start, duration, now)
    if not Service.ValidCooldown(start, duration) or not Service.Finite(now) then return nil, "Invalid cooldown progress." end
    if duration == 0 then return 0 end
    return math.max(0, math.min(1, (start + duration - now) / duration))
end
function Service.EffectBucket(progress)
    if not Service.ValidColor(progress) then return nil, "Invalid cooldown progress." end
    return ceil(progress * Service.EFFECT_STEPS)
end
function Service.EffectUV(bucket)
    if type(bucket) ~= "number" or bucket ~= floor(bucket) or bucket < 0 or bucket > Service.EFFECT_STEPS then
        return nil, "Invalid cooldown effect bucket."
    end
    local row, column = floor(bucket / 8), bucket - floor(bucket / 8) * 8
    -- Sample the centres of the boundary texels, keeping adjacent atlas cells
    -- out of bilinear filtering. The source contains a transparent guard.
    return (column * 32 + 0.5) / 256, (column * 32 + 31.5) / 256,
        (row * 32 + 0.5) / 256, (row * 32 + 31.5) / 256
end
function Service.FlashPhase(remaining, duration)
    if not Service.Finite(remaining) or not Service.Finite(duration) then return false end
    -- A complete on/off cycle lasts one second. Global cooldowns do not flash.
    return duration >= Service.MIN_DURATION and remaining > 0 and remaining <= 3
        and floor(remaining * 2) - floor(remaining) * 2 == 1
end
function Service.Bucket(remaining, fullSeconds)
    if not Service.Finite(remaining) then return nil, "Invalid cooldown time." end
    if remaining <= 0 then return 0, 0 end
    if remaining >= 86400 then return 5, ceil(remaining / 86400) end
    if remaining >= 3600 then return 4, ceil(remaining / 3600) end
    if remaining >= 60 then return 3, ceil(remaining / 60) end
    if fullSeconds == true then return 2, ceil(remaining) end
    if fullSeconds == false then return 1, math.max(1, ceil(remaining * 10)) end
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
