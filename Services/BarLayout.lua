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
-- One declaration owns saved values, validation, inheritance and profile keys.
-- Colors stay scalar so picker inputs and saved snapshots never share tables.
local fields, colorKeys = {}, {}
Layout.Fields, Layout.GlobalKeys = fields, {}
Layout.ColorGroups = {"rangeIn", "rangeOut", "hover", "border", "cooldown"}
local function Define(key, kind, value, minimum, maximum, version, geometry, choices)
    fields[key] = {kind = kind, default = value, minimum = minimum, maximum = maximum,
        version = version, geometry = geometry, choices = choices}
    table.insert(Layout.GlobalKeys, key)
end
Define("scalePct", "integer", 100, 50, 200, 1, true)
Define("columns", "integer", 12, 1, 12, 1, true)
Define("spacing", "integer", 4, 0, 20, 1, true)
Define("showTitle", "boolean", true, nil, nil, 1)
Define("showHotkeys", "boolean", true, nil, nil, 1)
Define("showCounts", "boolean", true, nil, nil, 1)
Define("showMacroNames", "boolean", true, nil, nil, 1)
Define("showEmptyButtons", "boolean", true, nil, nil, 1)
Define("buttonSize", "integer", 40, 24, 64, 1, true)
Define("iconInset", "integer", 4, 0, 8, 1, true)
Define("opacityPct", "integer", 100, 20, 100, 1, true)
Define("labelFontSize", "integer", 10, 8, 16, 1, true)
Define("hoverMode", "enum", "default", nil, nil, 2, nil, {default = true, border = true, shadow = true})
Define("hoverSize", "integer", 2, 1, 6, 2)
Define("showButtonBorder", "boolean", true, nil, nil, 2)
Define("borderSize", "integer", 2, 1, 6, 2)
Define("buttonBackground", "boolean", true, nil, nil, 2)
Define("cooldownFontSize", "integer", 14, 8, 32, 2)
Define("showCooldownText", "boolean", true, nil, nil, 2)
Define("nativeTexture", "boolean", false, nil, nil, 2)
Define("gryphons", "enum", "none", nil, nil, 2, nil, {none = true, left = true, right = true, both = true})
local colors = {rangeIn = {1,1,1,1}, rangeOut = {1,0.2,0.2,1}, hover = {1,1,1,0.6},
    border = {1,0.78,0.2,1}, cooldown = {1,1,1,1}}
local channels = {"R", "G", "B", "A"}
for _, group in ipairs(Layout.ColorGroups) do
    colorKeys[group] = {}
    for index, channel in ipairs(channels) do
        local key = group .. channel
        Define(key, "number", colors[group][index], 0, 1, 2)
        colorKeys[group][index] = key
    end
end
function Layout.ValidGlobalValue(key, value)
    local field = fields[key]
    if not field then return false end
    if field.kind == "boolean" then return type(value) == "boolean" end
    if field.kind == "enum" then return type(value) == "string" and field.choices[value] == true end
    return Layout.Finite(value) and value >= field.minimum and value <= field.maximum
        and (field.kind ~= "integer" or value == math.floor(value))
end
function Layout.ValidScale(value) return Layout.ValidGlobalValue("scalePct", value) end
function Layout.ValidColumns(value) return Layout.ValidGlobalValue("columns", value) end
function Layout.ValidSpacing(value) return Layout.ValidGlobalValue("spacing", value) end
function Layout.ValidDisplayKey(key) return fields[key] ~= nil and fields[key].kind == "boolean" end
function Layout.ValidAppearance(key, value)
    return fields[key] ~= nil and key ~= "scalePct" and key ~= "columns" and key ~= "spacing"
        and fields[key].kind ~= "boolean" and Layout.ValidGlobalValue(key, value)
end
function Layout.ColorKeys(group) return colorKeys[group] end
function Layout.ColorPatch(group, rgba)
    local keys = colorKeys[group]
    if not keys or type(rgba) ~= "table" then return nil, "Choose a known color and four RGBA channels." end
    local patch = {}
    for index = 1, 4 do
        local value = rawget(rgba, index)
        if not Layout.ValidGlobalValue(keys[index], value) then return nil, "RGBA channels must be finite values from 0 to 1." end
        patch[keys[index]] = value
    end
    for index in pairs(rgba) do
        if type(index) ~= "number" or index < 1 or index > 4 or index ~= math.floor(index) then return nil, "RGBA colors contain exactly four channels." end
    end
    return patch
end
function Layout.ProfileField(key, version)
    if key == "x" or key == "y" then return true end
    if key == "useGlobalLayout" or key == "localLayoutSaved" then return version == 2 end
    local field = fields[key]
    return field ~= nil and field.version <= version
end
function Layout.EqualShared(first, second)
    if not first or not second then return false end
    for _, key in ipairs(Layout.GlobalKeys) do if first[key] ~= second[key] then return false end end
    return true
end
function Layout.EqualGeometry(first, second)
    if not first or not second then return false end
    for _, key in ipairs(Layout.GlobalKeys) do
        if fields[key].geometry and first[key] ~= second[key] then return false end
    end
    return first.scale == second.scale and first.anchorX == second.anchorX and first.anchorY == second.anchorY
        and first.width == second.width and first.height == second.height and first.parentScale == second.parentScale
        and first.barWidth == second.barWidth and first.barHeight == second.barHeight
end
function Layout.EqualDrawing(first, second)
    return Layout.EqualShared(first, second) and Layout.EqualGeometry(first, second)
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
        if value == nil then value = fields[key].default end
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
    return fields[key] and fields[key].default
end
function Layout.Validate(record)
    if type(record) ~= "table" or not Layout.ValidScale(record.scalePct)
        or not Layout.Finite(record.x) or not Layout.Finite(record.y)
        or record.useGlobalLayout ~= nil and type(record.useGlobalLayout) ~= "boolean"
        or record.localLayoutSaved ~= nil and type(record.localLayoutSaved) ~= "boolean" then
        return false, "Invalid action bar layout. Preserve the saved file before repairing it."
    end
    for _, key in ipairs(Layout.GlobalKeys) do
        if record[key] ~= nil and not Layout.ValidGlobalValue(key, record[key]) then
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
    local result = {scale = scale, x = x, y = y, anchorX = x / scale, anchorY = y / scale,
        width = width, height = height, columns = columns, spacing = spacing,
        barWidth = barWidth, barHeight = barHeight, showTitle = showTitle, showHotkeys = showHotkeys, showCounts = showCounts,
        showMacroNames = record.showMacroNames ~= false, showEmptyButtons = record.showEmptyButtons ~= false,
        buttonSize = size, iconInset = record.iconInset or 4, opacityPct = record.opacityPct or 100,
        labelFontSize = record.labelFontSize or 10}
    for _, key in ipairs(Layout.GlobalKeys) do
        local value = record[key]
        if value == nil then value = Layout.DefaultValue(key, id) end
        result[key] = value
    end
    result.columns = columns
    return result
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
