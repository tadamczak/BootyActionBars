local Bars = BootyActionBars
local Layout = {}
Bars.Services.BarLayout = Layout

function Layout.Finite(value)
    return type(value) == "number" and value == value and math.abs(value) <= 1000000
end
function Layout.ValidID(id)
    return type(id) == "number" and id >= 1 and id <= 8 and id == math.floor(id)
end
function Layout.SlotCount(id) return (id == 7 or id == 8) and 10 or 12 end
function Layout.ValidScale(value)
    return Layout.Finite(value) and value >= 50 and value <= 200 and value == math.floor(value)
end
function Layout.ValidColumns(value)
    return Layout.Finite(value) and value >= 1 and value <= 12 and value == math.floor(value)
end
function Layout.ValidSpacing(value)
    return Layout.Finite(value) and value >= 0 and value <= 20 and value == math.floor(value)
end
function Layout.ValidDisplayKey(key)
    return key == "showTitle" or key == "showHotkeys" or key == "showCounts"
        or key == "showMacroNames" or key == "showEmptyButtons"
end
local appearance = {buttonSize = {24, 64, 40}, iconInset = {0, 8, 4}, opacityPct = {20, 100, 100}, labelFontSize = {8, 16, 10}}
function Layout.ValidAppearance(key, value)
    local limit = appearance[key]
    return limit ~= nil and Layout.Finite(value) and value == math.floor(value) and value >= limit[1] and value <= limit[2]
end
function Layout.Validate(record)
    if type(record) ~= "table" or not Layout.ValidScale(record.scalePct)
        or not Layout.Finite(record.x) or not Layout.Finite(record.y)
        or record.columns ~= nil and not Layout.ValidColumns(record.columns)
        or record.spacing ~= nil and not Layout.ValidSpacing(record.spacing)
        or record.showTitle ~= nil and type(record.showTitle) ~= "boolean"
        or record.showHotkeys ~= nil and type(record.showHotkeys) ~= "boolean"
        or record.showCounts ~= nil and type(record.showCounts) ~= "boolean"
        or record.showMacroNames ~= nil and type(record.showMacroNames) ~= "boolean"
        or record.showEmptyButtons ~= nil and type(record.showEmptyButtons) ~= "boolean" then
        return false, "Invalid action bar layout. Preserve the saved file before repairing it."
    end
    for key in pairs(appearance) do
        if record[key] ~= nil and not Layout.ValidAppearance(key, record[key]) then
            return false, "Invalid action bar appearance. Preserve the saved file before repairing it."
        end
    end
    return true
end
function Layout.ValidateLayouts(layouts)
    if layouts == nil then return true end
    if type(layouts) ~= "table" then return false, "Invalid saved action bar layouts." end
    for id, record in pairs(layouts) do
        if not Layout.ValidID(id) then return false, "Saved layouts support bars 1-6, pet and forms." end
        local ok, failure = Layout.Validate(record)
        if not ok then return false, failure end
    end
    return true
end
function Layout.Read(layouts, id)
    if not Layout.ValidID(id) then return nil, "Choose an action bar from 1 to 8." end
    local ok, failure = Layout.ValidateLayouts(layouts)
    if not ok then return nil, failure end
    local record = layouts and layouts[id]
    if not record then return {scalePct = 100, x = 0, y = id == 7 and -250 or id == 8 and -320 or -180 + (id - 1) * 68, columns = Layout.SlotCount(id), spacing = 4,
        showTitle = true, showHotkeys = true, showCounts = true, showMacroNames = true, showEmptyButtons = true,
        buttonSize = 40, iconInset = 4, opacityPct = 100, labelFontSize = 10} end
    return {scalePct = record.scalePct, x = record.x, y = record.y,
        columns = record.columns or Layout.SlotCount(id), spacing = record.spacing or 4,
        showTitle = record.showTitle ~= false, showHotkeys = record.showHotkeys ~= false, showCounts = record.showCounts ~= false,
        showMacroNames = record.showMacroNames ~= false, showEmptyButtons = record.showEmptyButtons ~= false,
        buttonSize = record.buttonSize or 40, iconInset = record.iconInset or 4,
        opacityPct = record.opacityPct or 100, labelFontSize = record.labelFontSize or 10}
end
local function Clamp(value, minimum, maximum)
    -- An oversized bar cannot fit this axis; keep its center accessible.
    if minimum > maximum then return 0 end
    return math.max(minimum, math.min(maximum, value))
end
function Layout.Resolve(id, record, width, height)
    if not Layout.ValidID(id) then return nil, "Choose an action bar from 1 to 8." end
    if record == nil then record = Layout.Read(nil, id) end
    local ok, failure = Layout.Validate(record)
    if not ok then return nil, failure end
    if not Layout.Finite(width) or width <= 0 or not Layout.Finite(height) or height <= 0 then
        return nil, "Action bar screen dimensions are unavailable."
    end
    local scale = record.scalePct / 100
    local slots = Layout.SlotCount(id)
    local columns, spacing = math.min(record.columns or slots, slots), record.spacing or 4
    local rows = math.ceil(slots / columns)
    local size = record.buttonSize or 40
    local barWidth, barHeight = size * columns + (columns - 1) * spacing, size * rows + (rows - 1) * spacing
    local halfWidth, halfHeight = barWidth / 2 * scale, barHeight / 2 * scale
    local showTitle, showHotkeys, showCounts = record.showTitle ~= false, record.showHotkeys ~= false, record.showCounts ~= false
    local titleHeight = (showTitle and 28 or 0) * scale
    local x = Clamp(record.x, -width / 2 + 8 + halfWidth, width / 2 - 8 - halfWidth)
    local y = Clamp(record.y, -height / 2 + 8 + halfHeight, height / 2 - 8 - halfHeight - titleHeight)
    return {scale = scale, x = x, y = y, anchorX = x / scale, anchorY = y / scale,
        width = width, height = height, columns = columns, spacing = spacing,
        barWidth = barWidth, barHeight = barHeight, showTitle = showTitle, showHotkeys = showHotkeys, showCounts = showCounts,
        showMacroNames = record.showMacroNames ~= false, showEmptyButtons = record.showEmptyButtons ~= false,
        buttonSize = size, iconInset = record.iconInset or 4, opacityPct = record.opacityPct or 100,
        labelFontSize = record.labelFontSize or 10}
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
