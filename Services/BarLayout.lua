local Bars = BootyActionBars
local Layout = {}
Bars.Services.BarLayout = Layout
local Config = Bars.Services.BarConfig

function Layout.Finite(value)
    return type(value) == "number" and value == value and math.abs(value) <= 1000000
end
function Layout.ValidID(id)
    return Config.ValidLayoutID(id)
end
function Layout.SlotCount(id) return (id == 7 or id == 8) and 10 or Config.SLOT_COUNT end
-- One declaration owns saved values, validation, inheritance and profile keys.
-- Colors stay scalar so picker inputs and saved snapshots never share tables.
local fields, colorKeys = {}, {}
Layout.Fields, Layout.GlobalKeys = fields, {}
Layout.ColorGroups = {"rangeIn", "rangeOut", "hover", "hoverBackground", "hoverShadow", "hoverOutline", "border", "cooldown", "cooldownUnder10", "cooldownUnder5", "cooldownEffect", "cooldownFlash"}
-- These values have legacy fallbacks; explicit false/default values must not
-- disappear from sparse saves and reactivate an older preference.
Layout.ExplicitKeys = {nativeSlotArtwork = true, nativeBackground = true, nativeBorder = true,
    nativeButtonScalePct = true, nativeBorderScalePct = true, hoverBackgroundShadow = true, hoverBorderShadow = true, hoverBorder = true}
for _, prefix in ipairs({"hoverBackground", "hoverShadow", "hoverOutline"}) do
    for _, suffix in ipairs({"Size", "Radius", "R", "G", "B", "A"}) do Layout.ExplicitKeys[prefix .. suffix] = true end
end
local function Define(key, kind, value, minimum, maximum, version, geometry, choices)
    fields[key] = {kind = kind, default = value, minimum = minimum, maximum = maximum,
        version = version, geometry = geometry, choices = choices}
    table.insert(Layout.GlobalKeys, key)
end
Define("scalePct", "integer", 100, 50, 200, 1, true)
Define("columns", "integer", Config.SLOT_COUNT, 1, Config.MAX_SLOTS, 1, true)
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
Define("hoverSize", "integer", 1, 1, 10, 2)
Define("hoverBackgroundShadow", "boolean", false, nil, nil, 2)
Define("hoverBorderShadow", "boolean", true, nil, nil, 2)
Define("hoverBorder", "boolean", false, nil, nil, 2)
Define("hoverBorderSize", "integer", 2, 1, 10, 2)
Define("hoverRadius", "integer", 0, 0, 10, 2)
for _, prefix in ipairs({"hoverBackground", "hoverShadow", "hoverOutline"}) do
    Define(prefix .. "Size", "integer", 1, 1, 10, 2)
    Define(prefix .. "Radius", "integer", 0, 0, 10, 2)
end
local fontChoices = {native = true, default = true, friz = true, arial = true, morpheus = true, skurri = true}
for _, prefix in ipairs({"title", "hotkey", "count", "macro", "cooldown"}) do
    Define(prefix .. "Font", "enum", prefix == "title" and "default" or "native", nil, nil, 2, true, fontChoices)
end
Define("showButtonBorder", "boolean", false, nil, nil, 2)
Define("borderSize", "integer", 2, 1, 6, 2)
Define("buttonBackground", "boolean", false, nil, nil, 2)
Define("cooldownFontSize", "integer", 14, 8, 32, 2)
Define("showCooldownText", "boolean", false, nil, nil, 2)
Define("cooldownFullSeconds", "boolean", true, nil, nil, 2)
Define("cooldownEffectMode", "enum", "native", nil, nil, 2, nil, {native = true, circle = true, vertical = true})
Define("cooldownFlash", "boolean", false, nil, nil, 2)
Define("nativeTexture", "boolean", false, nil, nil, 2)
Define("nativeTextureBackground", "boolean", true, nil, nil, 2)
Define("nativeSlotArtwork", "boolean", false, nil, nil, 2)
Define("nativeBackground", "boolean", false, nil, nil, 2)
Define("nativeBorder", "boolean", false, nil, nil, 2)
Define("nativeTextureScalePct", "integer", 100, 50, 200, 2)
Define("nativeBorderScalePct", "integer", 100, 50, 200, 2)
Define("nativeButtonScalePct", "integer", 100, 50, 200, 2)
Define("gryphons", "enum", "none", nil, nil, 2, nil, {none = true, left = true, right = true, both = true})
Define("gryphonScalePct", "integer", 100, 50, 200, 2)
local colors = {rangeIn = {1,1,1,1}, rangeOut = {1,1,1,1}, hover = {1,1,1,1},
    hoverBackground = {1,1,1,1}, hoverShadow = {1,1,1,1}, hoverOutline = {1,1,1,1},
    border = {1,0.78,0.2,1}, cooldown = {1,1,1,1}, cooldownUnder10 = {1,0.8,0.2,1}, cooldownUnder5 = {1,0.2,0.2,1},
    cooldownEffect = {0,0,0,0.6}, cooldownFlash = {1,0.2,0.2,0.65}}
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
    return first.count == second.count and first.scale == second.scale and first.anchorX == second.anchorX and first.anchorY == second.anchorY
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
-- Older v2 records gated recessed slots by both legacy flags. New records keep
-- body and slots independent; an explicit false must survive sparse saves.
local function NativeSlots(record)
    if record and record.nativeSlotArtwork ~= nil then return record.nativeSlotArtwork end
    return record ~= nil and record.nativeTexture == true and record.nativeTextureBackground ~= false
end
local function LegacyValues(result, record)
    for _, prefix in ipairs({"hoverBackground", "hoverShadow", "hoverOutline"}) do
        for _, channel in ipairs({"R", "G", "B", "A"}) do
            if not record or record[prefix .. channel] == nil then result[prefix .. channel] = result["hover" .. channel] end
        end
        if not record or record[prefix .. "Size"] == nil then result[prefix .. "Size"] = result.hoverSize end
        if not record or record[prefix .. "Radius"] == nil then result[prefix .. "Radius"] = result.hoverRadius end
    end
    result.nativeSlotArtwork = NativeSlots(record)
    for _, key in ipairs({"nativeBackground", "nativeBorder"}) do
        if not record or record[key] == nil then result[key] = record ~= nil and record.nativeTexture == true end
    end
    if not record or record.nativeButtonScalePct == nil then result.nativeButtonScalePct = result.nativeTextureScalePct end
    if not record or record.nativeBorderScalePct == nil then result.nativeBorderScalePct = result.nativeTextureScalePct end
    local mode = record and record.hoverMode or "default"
    if not record or record.hoverBackgroundShadow == nil then result.hoverBackgroundShadow = mode == "shadow" end
    if not record or record.hoverBorderShadow == nil then result.hoverBorderShadow = mode == "default" end
    if not record or record.hoverBorder == nil then result.hoverBorder = mode == "border" end
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
    LegacyValues(result, record)
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
        if not Layout.ValidID(id) then return false, "Saved layouts support ordinary action bars, pet and forms." end
        local ok, failure = Layout.Validate(record)
        if not ok then return false, failure end
    end
    return true
end
function Layout.ReadLocal(layouts, id)
    if not Layout.ValidID(id) then return nil, "Choose an action bar." end
    local ok, failure = Layout.ValidateLayouts(layouts)
    if not ok then return nil, failure end
    local record = layouts and layouts[id]
    local result = {x = record and record.x or 0,
        y = record and record.y or (id == 7 and -250 or id == 8 and -320 or -180 + (Config.Page(id) - 1) * 68),
        useGlobalLayout = Layout.UsesGlobal(layouts, id),
        localLayoutSaved = record ~= nil and (record.localLayoutSaved == true or record.useGlobalLayout ~= true)}
    for _, key in ipairs(Layout.GlobalKeys) do
        local value = record and record[key]
        if value == nil then value = Layout.DefaultValue(key, id) end
        result[key] = value
    end
    LegacyValues(result, record)
    return result
end
function Layout.Read(layouts, id, global, slots)
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
        LegacyValues(result, global)
    end
    result.columns = math.min(result.columns, slots or Layout.SlotCount(id))
    return result
end
function Layout.ReadEffective(store, id, slots)
    local result, failure = Layout.Read(store.barLayouts, id, store.globalLayout, slots)
    if not result then return nil, failure end
    local owner = BootyActionBars.Services.BarMerging.StyleOwner(store, id)
    if owner == id then return result end
    local donor
    if type(owner) == "number" then donor, failure = Layout.Read(store.barLayouts, owner, store.globalLayout, slots)
    else
        donor, failure = Layout.ReadGlobal(store.globalLayout)
        if donor then
            local utility; utility, failure = BootyActionBars.Services.UtilityLayout.Read(store.utilityLayouts, owner)
            if not utility then return nil, failure end
            for key, value in pairs(utility) do if fields[key] then donor[key] = value end end
        end
    end
    if not donor then return nil, failure end
    for _, key in ipairs(Layout.GlobalKeys) do result[key] = donor[key] end
    result.columns = math.min(result.columns, slots or Layout.SlotCount(id))
    return result
end
local function Clamp(value, minimum, maximum)
    -- An oversized bar cannot fit this axis; keep its center accessible.
    if minimum > maximum then return 0 end
    return math.max(minimum, math.min(maximum, value))
end
function Layout.Resolve(id, record, width, height, slots)
    if not Layout.ValidID(id) then return nil, "Choose an action bar." end
    if record == nil then record = Layout.Read(nil, id) end
    local ok, failure = Layout.Validate(record)
    if not ok then return nil, failure end
    if not Layout.Finite(width) or width <= 0 or not Layout.Finite(height) or height <= 0 then
        return nil, "Action bar screen dimensions are unavailable."
    end
    local scale = record.scalePct / 100
    slots = slots or Layout.SlotCount(id)
    if not Layout.Finite(slots) or slots < 1 or slots > Config.MAX_SLOTS or slots ~= math.floor(slots) then return nil, "Invalid action bar slot count." end
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
        width = width, height = height, count = slots, columns = columns, spacing = spacing,
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
    LegacyValues(result, record)
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
