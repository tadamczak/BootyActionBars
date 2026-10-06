local Bars = BootyActionBars
local Layout = {}
Bars.Services.BarLayout = Layout

function Layout.Finite(value)
    return type(value) == "number" and value == value and math.abs(value) <= 1000000
end
function Layout.ValidID(id)
    return type(id) == "number" and id >= 1 and id <= 6 and id == math.floor(id)
end
function Layout.ValidScale(value)
    return Layout.Finite(value) and value >= 50 and value <= 200 and value == math.floor(value)
end
function Layout.Validate(record)
    if type(record) ~= "table" or not Layout.ValidScale(record.scalePct)
        or not Layout.Finite(record.x) or not Layout.Finite(record.y) then
        return false, "Invalid action bar layout. Preserve the saved file before repairing it."
    end
    return true
end
function Layout.ValidateLayouts(layouts)
    if layouts == nil then return true end
    if type(layouts) ~= "table" then return false, "Invalid saved action bar layouts." end
    for id, record in pairs(layouts) do
        if not Layout.ValidID(id) then return false, "Saved layouts support only bars 1 through 6." end
        local ok, failure = Layout.Validate(record)
        if not ok then return false, failure end
    end
    return true
end
function Layout.Read(layouts, id)
    if not Layout.ValidID(id) then return nil, "Choose an action bar from 1 to 6." end
    local ok, failure = Layout.ValidateLayouts(layouts)
    if not ok then return nil, failure end
    local record = layouts and layouts[id]
    if not record then return {scalePct = 100, x = 0, y = -180 + (id - 1) * 68} end
    return {scalePct = record.scalePct, x = record.x, y = record.y}
end
local function Clamp(value, minimum, maximum)
    -- An oversized bar cannot fit this axis; keep its center accessible.
    if minimum > maximum then return 0 end
    return math.max(minimum, math.min(maximum, value))
end
function Layout.Resolve(id, record, width, height)
    if not Layout.ValidID(id) then return nil, "Choose an action bar from 1 to 6." end
    if record == nil then record = Layout.Read(nil, id) end
    local ok, failure = Layout.Validate(record)
    if not ok then return nil, failure end
    if not Layout.Finite(width) or width <= 0 or not Layout.Finite(height) or height <= 0 then
        return nil, "Action bar screen dimensions are unavailable."
    end
    local scale = record.scalePct / 100
    local halfWidth, halfHeight = 262 * scale, 20 * scale
    local x = Clamp(record.x, -width / 2 + 8 + halfWidth, width / 2 - 8 - halfWidth)
    local y = Clamp(record.y, -height / 2 + 8 + halfHeight, height / 2 - 8 - halfHeight - 28 * scale)
    return {scale = scale, x = x, y = y, anchorX = x / scale, anchorY = y / scale,
        width = width, height = height}
end
function Layout.Capture(centerX, centerY, barScale, parentScale, parentX, parentY)
    if not Layout.Finite(centerX) or not Layout.Finite(centerY) or not Layout.Finite(parentX)
        or not Layout.Finite(parentY) or not Layout.Finite(barScale) or barScale <= 0
        or not Layout.Finite(parentScale) or parentScale <= 0 then
        return nil, "Action bar coordinates are unavailable."
    end
    local ratio = barScale / parentScale
    local x, y = centerX * ratio - parentX, centerY * ratio - parentY
    if not Layout.Finite(x) or not Layout.Finite(y) then return nil, "Action bar coordinates exceed supported limits." end
    return x, y
end
