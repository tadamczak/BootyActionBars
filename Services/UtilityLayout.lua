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
local fields = {shown = true, x = true, y = true, scalePct = true, columns = true, spacing = true}
-- Separate starting rows keep newly enabled groups usable before their first drag.
local positions = {experience = {0, -180}, keyring = {-290, -120}, latency = {-250, -120}, bags = {-110, -120}, micro = {150, -120}}
local function Finite(value) return type(value) == "number" and value == value and math.abs(value) <= 1000000 end
function Utility.Definition(id) return definitions[id] end
function Utility.Name(id) return definitions[id] and definitions[id].label end
function Utility.ValidID(id) return definitions[id] ~= nil end
function Utility.ValidValue(id, key, value)
    local definition = definitions[id]
    if not definition or not fields[key] then return false end
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
