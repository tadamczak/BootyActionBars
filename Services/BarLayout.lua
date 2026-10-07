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
Layout.GlobalKeys = {"scalePct", "columns", "spacing", "showTitle", "showHotkeys", "showCounts",
    "showMacroNames", "showEmptyButtons", "buttonSize", "iconInset", "opacityPct", "labelFontSize"}
local defaults = {scalePct = 100, columns = 12, spacing = 4, showTitle = true, showHotkeys = true,
    showCounts = true, showMacroNames = true, showEmptyButtons = true, buttonSize = 40, iconInset = 4,
    opacityPct = 100, labelFontSize = 10}
function Layout.ValidAppearance(key, value)
    local limit = appearance[key]
    return limit ~= nil and Layout.Finite(value) and value == math.floor(value) and value >= limit[1] and value <= limit[2]
end
function Layout.ValidGlobalValue(key, value)
    if key == "scalePct" then return Layout.ValidScale(value) end
    if key == "columns" then return Layout.ValidColumns(value) end
    if key == "spacing" then return Layout.ValidSpacing(value) end
    if Layout.ValidDisplayKey(key) then return type(value) == "boolean" end
    return Layout.ValidAppearance(key, value)
end
function Layout.ValidateGlobal(record)
    if record == nil then return true end
    if type(record) ~= "table" then return false, "Invalid global action bar settings." end
    for _, key in ipairs(Layout.GlobalKeys) do
        if record[key] ~= nil and not Layout.ValidGlobalValue(key, record[key]) then
            return false, "Invalid global action bar setting: " .. key .. "."
        end
    end
    if record.x ~= nil or record.y ~= nil or record.useGlobalLayout ~= nil or record.localLayoutSaved ~= nil then
        return false, "Global settings do not contain bar positions or inheritance flags."
    end
    return true
end
function Layout.ReadGlobal(record)
    local ok, failure = Layout.ValidateGlobal(record)
    if not ok then return nil, failure end
    local result = {}
    for _, key in ipairs(Layout.GlobalKeys) do
        local value = record and record[key]
        if value == nil then value = defaults[key] end
        result[key] = value
    end
    return result
end
function Layout.UsesGlobal(layouts, id)
    local record = layouts and layouts[id]
    return record == nil or record.useGlobalLayout == true
end
function Layout.DefaultValue(key, id)
    if key == "columns" and id then return Layout.SlotCount(id) end
    return defaults[key]
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
        or record.showEmptyButtons ~= nil and type(record.showEmptyButtons) ~= "boolean"
        or record.useGlobalLayout ~= nil and type(record.useGlobalLayout) ~= "boolean"
        or record.localLayoutSaved ~= nil and type(record.localLayoutSaved) ~= "boolean" then
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
function Layout.ReadLocal(layouts, id)
    if not Layout.ValidID(id) then return nil, "Choose an action bar from 1 to 8." end
    local ok, failure = Layout.ValidateLayouts(layouts)
    if not ok then return nil, failure end
    local record = layouts and layouts[id]
    local result = {x = record and record.x or 0,
        y = record and record.y or (id == 7 and -250 or id == 8 and -320 or -180 + (id - 1) * 68),
        useGlobalLayout = Layout.UsesGlobal(layouts, id),
        localLayoutSaved = record ~= nil and (record.localLayoutSaved == true or record.useGlobalLayout ~= true)}
    for _, key in ipairs(Layout.GlobalKeys) do
        local value = record and record[key]
        if value == nil then value = Layout.DefaultValue(key, id) end
        result[key] = value
    end
    return result
end
function Layout.Read(layouts, id, global)
    local result, failure = Layout.ReadLocal(layouts, id)
    if not result then return nil, failure end
    local ok, reason = Layout.ValidateGlobal(global)
    if not ok then return nil, reason end
    if result.useGlobalLayout then
        for _, key in ipairs(Layout.GlobalKeys) do
            local value = global and global[key]
            if value == nil then value = Layout.DefaultValue(key, id) end
            result[key] = value
        end
        result.columns = math.min(result.columns, Layout.SlotCount(id))
    end
    return result
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
    -- The bar's own rectangle reaches the screen edge. A caption is a child
    -- outside that rectangle and must not push a user-selected center inward.
    local x = Clamp(record.x, -width / 2 + halfWidth, width / 2 - halfWidth)
    local y = Clamp(record.y, -height / 2 + halfHeight, height / 2 - halfHeight)
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
