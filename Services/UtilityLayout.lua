local Utility = {}
BootyActionBars.Services.UtilityLayout = Utility
Utility.Keys = {"experience", "keyring", "latency", "bags", "micro"}
local definitions = {
    experience = {label = "Experience / Reputation", names = {"MainMenuExpBar", "ReputationWatchBar", "ExhaustionTick"}, count = 1, width = 1024, height = 26, columns = 1},
    keyring = {label = "Keyring", names = {"KeyRingButton"}, count = 1, width = 18, height = 39, columns = 1},
    latency = {label = "Latency", names = {"MainMenuBarPerformanceBarFrame"}, count = 1, width = 7 * 20 / 16, height = 38 * 66 / 64, offsetX = -1, offsetY = 13 * 66 / 64, columns = 1},
    bags = {label = "Bags", names = {"MainMenuBarBackpackButton", "CharacterBag0Slot", "CharacterBag1Slot", "CharacterBag2Slot", "CharacterBag3Slot"}, count = 5, width = 37, height = 37, columns = 5},
    micro = {label = "Micro Menu", names = {"CharacterMicroButton", "SpellbookMicroButton", "TalentMicroButton", "QuestLogMicroButton", "SocialsMicroButton", "WorldMapMicroButton", "MainMenuMicroButton", "HelpMicroButton"}, count = 8, width = 29, height = 58, visualWidth = 26, visualHeight = 58 * 41 / 64 - 3, offsetX = -1.5, offsetY = 58 * 23 / 64 + 1.5, columns = 8},
}
local fields = {shown = true, x = true, y = true, scalePct = true, columns = true, spacing = true, nativeTexture = true}
Utility.StyleKeys = {"nativeBackground", "nativeBorder", "nativeSlotArtwork", "nativeTextureScalePct", "nativeBorderScalePct", "nativeButtonScalePct", "gryphons", "gryphonScalePct"}
for _, key in ipairs(Utility.StyleKeys) do fields[key] = true end
-- Separate starting rows keep newly enabled groups usable before their first drag.
local positions = {experience = {0, -180}, keyring = {-290, -120}, latency = {-250, -120}, bags = {-110, -120}, micro = {150, -120}}
local function Finite(value) return type(value) == "number" and value == value and math.abs(value) <= 1000000 end
function Utility.Definition(id) return definitions[id] end
function Utility.Name(id) return definitions[id] and definitions[id].label end
function Utility.ValidID(id) return definitions[id] ~= nil end
function Utility.SupportsNativeTexture(id) return definitions[id] ~= nil end
function Utility.ValidValue(id, key, value)
    local definition = definitions[id]
    if not definition or not fields[key] then return false end
    if key == "nativeTexture" then return Utility.SupportsNativeTexture(id) and type(value) == "boolean" end
    for _, styleKey in ipairs(Utility.StyleKeys) do
        if key == styleKey then return BootyActionBars.Services.BarLayout.ValidGlobalValue(key, value) end
    end
    if key == "shown" then return type(value) == "boolean" end
    if not Finite(value) then return false end
    if key == "x" or key == "y" then return true end
    if value ~= math.floor(value) then return false end
    if key == "scalePct" then return value >= 50 and value <= 200 end
    if key == "columns" then return value >= 1 and value <= definition.count end
    return value >= 0 and value <= 20
end
function Utility.Validate(saved)
    if saved == nil then return true end
    if type(saved) ~= "table" then return false, "Invalid saved utility-bar layouts." end
    for id, record in pairs(saved) do
        if not definitions[id] or type(record) ~= "table" then return false, "Invalid utility-bar identity or layout." end
        for key, value in pairs(record) do
            if not Utility.ValidValue(id, key, value) then return false, "Invalid utility-bar preference: " .. tostring(key) end
        end
    end
    return true
end
function Utility.Read(saved, id)
    local definition = definitions[id]
    if not definition then return nil, "Choose a listed utility bar." end
    local ok, failure = Utility.Validate(saved)
    if not ok then return nil, failure end
    local source = saved and saved[id] or {}
    local record = {shown = source.shown == true, x = source.x or positions[id][1], y = source.y or positions[id][2],
        scalePct = source.scalePct or 100, columns = source.columns or definition.columns, spacing = source.spacing or 2}
    if Utility.SupportsNativeTexture(id) then record.nativeTexture = source.nativeTexture == true end
    for _, key in ipairs(Utility.StyleKeys) do
        local value = source[key]
        if value == nil then
            if key == "nativeBackground" or key == "nativeBorder" or key == "nativeSlotArtwork" then value = source.nativeTexture == true
            else value = BootyActionBars.Services.BarLayout.DefaultValue(key) end
        end
        record[key] = value
    end
    return record
end
function Utility.ReadEffective(store, id, candidate)
    local result, failure = Utility.Read(store.utilityLayouts, id)
    if not result then return nil, failure end
    if candidate then for key, value in pairs(candidate) do result[key] = value end end
    local owner = BootyActionBars.Services.BarMerging.StyleOwner(store, id)
    if owner == id then return result end
    local donor
    if type(owner) == "number" then donor, failure = BootyActionBars.Services.BarLayout.Read(store.barLayouts, owner, store.globalLayout)
    else donor, failure = Utility.Read(store.utilityLayouts, owner) end
    if not donor then return nil, failure end
    for _, key in ipairs(Utility.StyleKeys) do result[key] = donor[key] end
    result.scalePct, result.spacing = donor.scalePct, donor.spacing
    result.columns = math.min(donor.columns, definitions[id].count)
    return result
end
function Utility.Patch(saved, id, key, value)
    if not Utility.ValidValue(id, key, value) then return nil, "Invalid utility-bar preference." end
    local record, failure = Utility.Read(saved, id)
    if not record then return nil, failure end
    record[key] = value
    if key == "nativeTexture" then record.nativeBackground, record.nativeBorder, record.nativeSlotArtwork = value, value, value end
    return record
end
function Utility.Copy(saved)
    local ok, failure = Utility.Validate(saved)
    if not ok then return nil, failure end
    local result = {}
    for _, id in ipairs(Utility.Keys) do
        local record = saved and saved[id]
        if record then
            local copy = {}; for key, value in pairs(record) do copy[key] = value end; result[id] = copy
        end
    end
    return result
end
function Utility.Equal(left, right)
    if type(left) ~= "table" or type(right) ~= "table" then return left == right end
    for id, record in pairs(left) do
        local other = right[id]
        if type(record) ~= "table" or type(other) ~= "table" then return false end
        for key, value in pairs(record) do if other[key] ~= value then return false end end
        for key, value in pairs(other) do if record[key] ~= value then return false end end
    end
    for id in pairs(right) do if left[id] == nil then return false end end
    return true
end
-- Installed KeyRing atlas and control offsets are indexed in MOS331 evidence.
Utility.NativeTexture = "Interface\\MainMenuBar\\UI-MainMenuBar-KeyRing"
Utility.ArtworkFields = {"id", "shown", "columns", "spacing", "width", "height", "count", "socketSize",
    "left", "top", "right", "bottom", "innerLeft", "innerTop", "innerRight", "innerBottom",
    "padLeft", "padRight", "padTop", "padBottom", "backingLeft", "backingTop", "backingWidth", "backingHeight",
    "backingColumns", "backingRows", "backingCount", "backingRotated", "backingStepX", "backingStepY",
    "edgeCount", "slotCount", "slotWidth", "slotHeight", "slotPadding", "cellWidth", "cellHeight", "gryphons", "gryphonSize", "gryphonOverlap", "frontCount", "regularCount"}
function Utility.ResolveArtwork(id, record, width, height, shown, target)
    if not Utility.SupportsNativeTexture(id) or type(record) ~= "table" or type(shown) ~= "boolean"
        or not Utility.ValidValue(id, "columns", record.columns) or not Utility.ValidValue(id, "spacing", record.spacing)
        or not Finite(width) or width <= 0 or not Finite(height) or height <= 0 then
        return nil, "Native utility artwork geometry is unavailable."
    end
    target = target or {}
    local native = BootyActionBars.Services.NativeDecorationLayout
    target.id, target.shown, target.columns, target.spacing = id, shown, record.columns, record.spacing
    target.width, target.height = width, height
    target.cellWidth, target.cellHeight = (definitions[id].visualWidth or definitions[id].width), definitions[id].visualHeight or definitions[id].height
    local border = record.nativeBorder
    if border == nil then border = record.nativeTexture == true end
    local background = record.nativeBackground
    if background == nil then background = record.nativeTexture == true end
    local slots = record.nativeSlotArtwork
    if slots == nil then slots = record.nativeTexture == true end
    local padding = border and 6 * (record.nativeBorderScalePct or 100) / 100 or 0
    target.innerLeft, target.innerTop, target.innerRight, target.innerBottom = 0, 0, width, height
    target.left, target.top, target.right, target.bottom = -padding, -padding, width + padding, height + padding
    target.padLeft, target.padRight, target.padTop, target.padBottom = padding, padding, padding, padding
    native.ResolveBacking(0, 0, width, height, record.nativeTextureScalePct or 100, target)
    if not background then target.backingCount = 0 end
    target.edgeCount, target.slotCount = border and 8 or 0, slots and definitions[id].count * 9 or 0
    local buttonScale = (record.nativeButtonScalePct or 100) / 100
    target.slotWidth = math.min(target.cellWidth * buttonScale, target.cellWidth + record.spacing)
    target.slotHeight = math.min(target.cellHeight * buttonScale, target.cellHeight + record.spacing)
    target.slotPadding = math.min(6 * buttonScale, target.slotWidth / 3, target.slotHeight / 3)
    target.gryphons = record.gryphons or "none"
    target.gryphonSize, target.gryphonOverlap = 128 * (record.gryphonScalePct or 100) / 100, 32 * (record.gryphonScalePct or 100) / 100
    target.frontCount = target.gryphons == "both" and 2 or target.gryphons ~= "none" and 1 or 0
    target.regularCount = target.backingCount + target.edgeCount + target.slotCount
    target.count = target.regularCount + target.frontCount
    if target.backingCount > native.MaxBackingPieces then return nil, "Native utility artwork exceeds its supported grid." end
    return target
end
function Utility.ArtworkPiece(scene, index, target)
    if type(index) ~= "number" or index < 1 or index > scene.count or index ~= math.floor(index) then return end
    target = target or {}
    local native = BootyActionBars.Services.NativeDecorationLayout
    target.rotated, target.foreground = false, false
    if index <= scene.backingCount then
        target.path = native.Texture
        target.x, target.y, target.width, target.height, target.left, target.right, target.top, target.bottom, target.rotated = native.Backing(scene, index)
    elseif index <= scene.backingCount + scene.edgeCount then
        target.path = native.Texture
        target.x, target.y, target.width, target.height, target.left, target.right, target.top, target.bottom = native.Edge(scene, index - scene.backingCount)
    elseif index <= scene.backingCount + scene.edgeCount + scene.slotCount then
        local part = index - scene.backingCount - scene.edgeCount - 1
        local slot, piece = math.floor(part / 9), math.mod(part, 9)
        local row = math.floor(slot / scene.columns)
        local column = slot - row * scene.columns
        local x = column * (scene.cellWidth + scene.spacing) + (scene.cellWidth - scene.slotWidth) / 2
        local y = row * (scene.cellHeight + scene.spacing) + (scene.cellHeight - scene.slotHeight) / 2
        local cell = scene.slotScene or {}; scene.slotScene = cell
        local padding = scene.slotPadding
        cell.left, cell.top, cell.right, cell.bottom = x, y, x + scene.slotWidth, y + scene.slotHeight
        cell.innerLeft, cell.innerTop, cell.innerRight, cell.innerBottom = x + padding, y + padding, cell.right - padding, cell.bottom - padding
        cell.padLeft, cell.padRight, cell.padTop, cell.padBottom = padding, padding, padding, padding
        target.path = native.Texture
        if piece == 0 then
            target.x, target.y, target.width, target.height = cell.innerLeft, cell.innerTop, cell.innerRight - cell.innerLeft, cell.innerBottom - cell.innerTop
            target.left, target.right, target.top, target.bottom = 53 / 256, 84 / 256, 219 / 256, 250 / 256
        else target.x, target.y, target.width, target.height, target.left, target.right, target.top, target.bottom = native.Edge(cell, piece) end
    else
        local side = scene.gryphons == "right" and "right" or index == scene.count and scene.gryphons == "both" and "right" or "left"
        target.path, target.foreground = native.GryphonTexture, true
        target.width, target.height = scene.gryphonSize, scene.gryphonSize
        target.x = side == "left" and scene.left - scene.gryphonSize + scene.gryphonOverlap or scene.right - scene.gryphonOverlap
        target.y = scene.cellHeight + scene.padBottom - scene.gryphonSize
        target.left, target.right, target.top, target.bottom = side == "right" and 1 or 0, side == "right" and 0 or 1, 0, 1
    end
    return target
end
function Utility.Resolve(record, width, height, screenWidth, screenHeight)
    if type(record) ~= "table" or not Finite(width) or width <= 0 or not Finite(height) or height <= 0
        or not Finite(screenWidth) or screenWidth <= 0 or not Finite(screenHeight) or screenHeight <= 0
        or not Finite(record.x) or not Finite(record.y) or not Finite(record.scalePct) or record.scalePct <= 0 then
        return nil, "Utility-bar screen geometry is unavailable."
    end
    local scale = math.min(record.scalePct / 100, screenWidth / width, screenHeight / height)
    local halfWidth, halfHeight = width * scale / 2, height * scale / 2
    local x = math.max(-screenWidth / 2 + halfWidth, math.min(screenWidth / 2 - halfWidth, record.x))
    local y = math.max(-screenHeight / 2 + halfHeight, math.min(screenHeight / 2 - halfHeight, record.y))
    return {scale = scale, x = x, y = y, anchorX = x / scale, anchorY = y / scale}
end
