local Bars = BootyActionBars
local BarConfig = {}
Bars.Services.BarConfig = BarConfig

function BarConfig.ValidID(value)
    return type(value) == "number" and value >= 2 and value <= 6 and value == math.floor(value)
end

function BarConfig.Validate(config)
    if config == nil then return true end
    if type(config) ~= "table" then
        return false, "Invalid saved additional bars. Preserve the saved file before repairing it."
    end
    for id, enabled in pairs(config) do
        if not BarConfig.ValidID(id) or enabled ~= true then
            return false, "Invalid saved additional bars. Only bars 2-6 with enabled entries are supported."
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
