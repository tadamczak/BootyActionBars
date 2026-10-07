local Utility = {}
BootyActionBars.Services.UtilityLayout = Utility
Utility.Keys = {"experience", "keyring", "latency", "bags", "micro"}
local definitions = {
    experience = {label = "Experience / Reputation", names = {"MainMenuExpBar", "ReputationWatchBar", "ExhaustionTick"}, count = 1, width = 1024, height = 26, columns = 1},
    keyring = {label = "Keyring", names = {"KeyRingButton"}, count = 1, width = 18, height = 39, columns = 1},
    latency = {label = "Latency", names = {"MainMenuBarPerformanceBarFrame"}, count = 1, width = 20, height = 66, columns = 1},
    bags = {label = "Bags", names = {"MainMenuBarBackpackButton", "CharacterBag0Slot", "CharacterBag1Slot", "CharacterBag2Slot", "CharacterBag3Slot"}, count = 5, width = 37, height = 37, columns = 5},
    micro = {label = "Micro Menu", names = {"CharacterMicroButton", "SpellbookMicroButton", "TalentMicroButton", "QuestLogMicroButton", "SocialsMicroButton", "WorldMapMicroButton", "MainMenuMicroButton", "HelpMicroButton"}, count = 8, width = 29, height = 58, columns = 8},
}
local fields = {shown = true, x = true, y = true, scalePct = true, columns = true, spacing = true, nativeTexture = true}
local artworkIds = {keyring = true, latency = true, bags = true, micro = true}
-- Separate starting rows keep newly enabled groups usable before their first drag.
local positions = {experience = {0, -180}, keyring = {-290, -120}, latency = {-250, -120}, bags = {-110, -120}, micro = {150, -120}}
local function Finite(value) return type(value) == "number" and value == value and math.abs(value) <= 1000000 end
function Utility.Definition(id) return definitions[id] end
function Utility.Name(id) return definitions[id] and definitions[id].label end
function Utility.ValidID(id) return definitions[id] ~= nil end
function Utility.SupportsNativeTexture(id) return artworkIds[id] == true end
function Utility.ValidValue(id, key, value)
    local definition = definitions[id]
    if not definition or not fields[key] then return false end
    if key == "nativeTexture" then return Utility.SupportsNativeTexture(id) and type(value) == "boolean" end
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
    return record
end
function Utility.Patch(saved, id, key, value)
    if not Utility.ValidValue(id, key, value) then return nil, "Invalid utility-bar preference." end
    local record, failure = Utility.Read(saved, id)
    if not record then return nil, failure end
    record[key] = value
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
    "backingColumns", "backingRows", "backingCount", "backingRotated", "backingStepX", "backingStepY"}
function Utility.ResolveArtwork(id, record, width, height, shown, target)
    if not Utility.SupportsNativeTexture(id) or type(record) ~= "table" or type(shown) ~= "boolean"
        or not Utility.ValidValue(id, "columns", record.columns) or not Utility.ValidValue(id, "spacing", record.spacing)
        or not Finite(width) or width <= 0 or not Finite(height) or height <= 0 then
        return nil, "Native utility artwork geometry is unavailable."
    end
    target = target or {}
    local native = BootyActionBars.Services.NativeDecorationLayout
    target.id, target.shown, target.columns, target.spacing = id, shown, record.columns, record.spacing
    target.width, target.height, target.backingCount = width, height, 0
    if id == "bags" then
        target.socketSize = math.min(43, 37 + record.spacing)
        local crop = (43 - target.socketSize) / 2
        native.ResolveBacking(-3 + crop, -4 + crop, width + 6 - crop * 2, height + 6 - crop * 2, 100, target)
        target.count = target.backingCount + definitions.bags.count
    elseif id == "micro" then
        -- Preserve the clean stock section's +8,-17 offset and five-unit right
        -- overhang. Its centre grows with the grid; bevels remain six units.
        target.left, target.top, target.right, target.bottom = 8, 17, width + 5, height + 2
        target.padLeft, target.padRight, target.padTop, target.padBottom = 6, 6, 6, 6
        target.innerLeft, target.innerTop = target.left + 6, target.top + 6
        target.innerRight, target.innerBottom = target.right - 6, target.bottom - 6
        native.ResolveBacking(target.innerLeft, target.innerTop, target.innerRight - target.innerLeft,
            target.innerBottom - target.innerTop, 100, target)
        target.count = target.backingCount + 8
    else target.count = 1 end
    if target.backingCount > native.MaxBackingPieces then return nil, "Native utility artwork exceeds its supported grid." end
    return target
end
function Utility.ArtworkPiece(scene, index, target)
    if type(index) ~= "number" or index < 1 or index > scene.count or index ~= math.floor(index) then return end
    target = target or {}
    local native = BootyActionBars.Services.NativeDecorationLayout
    target.rotated = false
    if index <= scene.backingCount then
        target.path = native.Texture
        target.x, target.y, target.width, target.height, target.left, target.right, target.top, target.bottom, target.rotated = native.Backing(scene, index)
    elseif scene.id == "bags" then
        local slot = index - scene.backingCount - 1
        local row = math.floor(slot / scene.columns)
        local column = slot - row * scene.columns
        local crop = (43 - scene.socketSize) / 2
        target.path, target.x, target.y = Utility.NativeTexture, column * (37 + scene.spacing) - 3 + crop, row * (37 + scene.spacing) - 4 + crop
        target.width, target.height = scene.socketSize, scene.socketSize
        -- Keep the complete native socket: a centre crop would erase its
        -- bevel when the cell is narrower than the 43-pixel source sprite.
        target.left, target.right, target.top, target.bottom = 43 / 256, 86 / 256, 21 / 128, 64 / 128
    elseif scene.id == "micro" then
        target.path = native.Texture
        target.x, target.y, target.width, target.height, target.left, target.right, target.top, target.bottom = native.Edge(scene, index - scene.backingCount)
    elseif scene.id == "latency" then
        target.path, target.x, target.y, target.width, target.height = Utility.NativeTexture, 0, 11, 20, 43
        target.left, target.right, target.top, target.bottom = 1 / 256, 21 / 256, 21 / 128, 64 / 128
    else
        target.path, target.x, target.y, target.width, target.height = Utility.NativeTexture, -2, -3, 22, 43
        target.left, target.right, target.top, target.bottom = 20 / 256, 42 / 256, 21 / 128, 64 / 128
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
