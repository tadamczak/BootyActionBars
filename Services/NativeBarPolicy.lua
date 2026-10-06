local NativeBarPolicy = {}
BootyActionBars.Services.NativeBarPolicy = NativeBarPolicy

local competingAddons = {"DiscordActionBars", "DiscordActionBarsOptions", "Bongos", "Bongos_ActionBar", "pfUI"}
local floor = math.floor

local function Integer(value, minimum)
    return type(value) == "number" and value == value and value >= minimum
        and value < 1e300 and value == floor(value)
end

-- Stock 1.12 action buttons derive their slots from this global. The bonus
-- offset redirects page-one input to a different bar, which this phase does
-- not own. The controller separately checks the bonus frame's slide-out state.
function NativeBarPolicy.Check(api)
    if api == nil then api = _G end
    if type(api) ~= "table" then return false, "The native action-bar API is unavailable." end
    local page = api.CURRENT_ACTIONBAR_PAGE
    if not Integer(page, 1) then return false, "The native action-bar page is unavailable or invalid." end
    if page ~= 1 then return false, "Native replacement currently supports action-bar page 1 only." end

    if type(api.GetBonusBarOffset) ~= "function" then return false, "The native bonus-bar API is unavailable." end
    local ok, offset = pcall(api.GetBonusBarOffset)
    if not ok then return false, "The native bonus-bar state could not be read: " .. tostring(offset) end
    if not Integer(offset, 0) then return false, "The native bonus-bar state is invalid." end
    if offset ~= 0 then return false, "Native replacement is unavailable while a bonus action bar is active." end

    if type(api.IsAddOnLoaded) ~= "function" then return false, "The loaded-addon API is unavailable." end
    for _, name in ipairs(competingAddons) do
        local loaded
        ok, loaded = pcall(api.IsAddOnLoaded, name)
        if not ok then return false, "The loaded-addon state could not be read for " .. name .. ": " .. tostring(loaded) end
        if loaded ~= nil and loaded ~= false and loaded ~= 0 and loaded ~= true and loaded ~= 1 then
            return false, "The loaded-addon state is invalid for " .. name .. "."
        end
        if loaded == true or loaded == 1 then return false, "Disable " .. name .. " before replacing native action buttons." end
    end
    if api.DAB_INITIALIZED == true then return false, "Disable DiscordActionBars before replacing native action buttons." end
    if type(api.pfUI) == "table" and type(api.pfUI.bars) == "table" then
        return false, "Disable pfUI action bars before replacing native action buttons."
    end
    return true
end
