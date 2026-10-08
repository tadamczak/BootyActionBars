local Bars = BootyActionBars
local BarConfig = {}
Bars.Services.BarConfig = BarConfig
-- Pet/form identities are already durable. New fixed bonus-source bars use
-- separate IDs so old layouts, merge groups and bindings keep their meaning.
BarConfig.SLOT_COUNT = 12
BarConfig.SPECIAL_SLOT_COUNT = 10
BarConfig.OrdinaryIDs = {1, 2, 3, 4, 5, 6, 9, 10, 11, 12}
BarConfig.CustomIDs = {2, 3, 4, 5, 6, 9, 10, 11, 12}
BarConfig.LayoutIDs = {1, 2, 3, 4, 5, 6, 7, 8, 9, 10, 11, 12}
BarConfig.MAX_SLOTS = table.getn(BarConfig.OrdinaryIDs) * BarConfig.SLOT_COUNT
local pages, identities = {}, {}
for page, id in ipairs(BarConfig.OrdinaryIDs) do pages[id], identities[page] = page, id end
local recordOffsets, recordCount = {}, 0
for _, id in ipairs(BarConfig.LayoutIDs) do
    recordOffsets[id] = recordCount
    recordCount = recordCount + ((id == 7 or id == 8) and BarConfig.SPECIAL_SLOT_COUNT or BarConfig.SLOT_COUNT)
end
function BarConfig.ValidOrdinaryID(id)
    return type(id) == "number" and pages[id] ~= nil
end
function BarConfig.ValidLayoutID(id)
    return BarConfig.ValidOrdinaryID(id) or id == 7 or id == 8
end
function BarConfig.SlotCount(id)
    if BarConfig.ValidOrdinaryID(id) then return BarConfig.SLOT_COUNT end
    if id == 7 or id == 8 then return BarConfig.SPECIAL_SLOT_COUNT end
end
function BarConfig.RecordOffset(id) return recordOffsets[id] end
function BarConfig.Page(id) return pages[id] end
function BarConfig.Offset(id)
    local page = pages[id]
    return page and (page - 1) * BarConfig.SLOT_COUNT or nil
end
function BarConfig.IDForPage(page) return identities[page] end
function BarConfig.Name(id)
    if id == 1 then return "Main Action Bar" end
    if id == 7 then return "Pet Bar" end
    if id == 8 then return "Forms / stances" end
    local page = pages[id]
    return page and "Action Bar " .. page or nil
end
function BarConfig.BindingPrefix(id)
    if id == 1 then return "BOOTYACTIONBARS_BUTTON" end
    if id == 7 then return "BOOTYACTIONBARS_PET_BUTTON" end
    if id == 8 then return "BOOTYACTIONBARS_STANCE_BUTTON" end
    local page = pages[id]
    return page and "BOOTYACTIONBARS_BAR" .. page .. "_BUTTON" or nil
end

function BarConfig.ValidID(value)
    return value ~= 1 and BarConfig.ValidOrdinaryID(value)
end

function BarConfig.Validate(config)
    if config == nil then return true end
    if type(config) ~= "table" then
        return false, "Invalid saved additional bars. Preserve the saved file before repairing it."
    end
    for id, enabled in pairs(config) do
        if not BarConfig.ValidID(id) or enabled ~= true then
            return false, "Invalid saved additional bars. Choose enabled ordinary action bars."
        end
    end
    return true
end

function BarConfig.ValidateSpecial(config)
    if config == nil then return true end
    if type(config) ~= "table" then return false, "Invalid saved pet/form bars." end
    for kind, enabled in pairs(config) do
        if (kind ~= "pet" and kind ~= "stance") or enabled ~= true then
            return false, "Saved pet/form bars support only enabled pet and stance entries."
        end
    end
    return true
end
