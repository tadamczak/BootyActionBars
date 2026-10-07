local Bars = BootyActionBars
local Database = {}
Bars.Database = Database
Database.SCHEMA_VERSION = 1

local function EditorOptions(value)
    if value == nil then return true end
    if type(value) ~= "table" or value.showGrid ~= nil and type(value.showGrid) ~= "boolean"
        or value.showAnchors ~= nil and type(value.showAnchors) ~= "boolean" then
        return false, "Invalid saved layout tools. Preserve the saved file before repairing it."
    end
    return true
end

local function Defaults(store)
    -- Fail before writing defaults when a newer build owns this saved format.
    if store.schemaVersion ~= nil and store.schemaVersion ~= Database.SCHEMA_VERSION then
        error("Unsupported BootyActionBars saved data. Update the addon before opening it.")
    end
    local valid, failure = Bars.Services.BarConfig.Validate(store.customBars)
    if not valid then error(failure) end
    valid, failure = Bars.Services.BarConfig.ValidateSpecial(store.specialBars)
    if not valid then error(failure) end
    valid, failure = Bars.Services.BarLayout.ValidateLayouts(store.barLayouts)
    if not valid then error(failure) end
    if Bars.Services.LayoutProfiles then
        valid, failure = Bars.Services.LayoutProfiles.ValidateStore(store.layoutProfiles)
        if not valid then error(failure) end
    end
    valid, failure = EditorOptions(store.editorOptions)
    if not valid then error(failure) end
    store.schemaVersion = Database.SCHEMA_VERSION
    if type(store.hideMinimapIcon) ~= "boolean" then store.hideMinimapIcon = false end
    if type(store.trialBarEnabled) ~= "boolean" then store.trialBarEnabled = false end
    if type(store.nativeMainBarEnabled) ~= "boolean" then store.nativeMainBarEnabled = false end
    if store.customBars == nil then store.customBars = {} end
    if store.specialBars == nil then store.specialBars = {} end
    if store.barLayouts == nil then store.barLayouts = {} end
    if store.layoutProfiles == nil then store.layoutProfiles = {} end
    if store.editorOptions == nil then store.editorOptions = {} end
    if type(store.presentation) ~= "table" then store.presentation = {} end
    if type(store.presentation.windows) ~= "table" then store.presentation.windows = {} end
    if type(store.presentation.minimap) ~= "table" then store.presentation.minimap = {angle = 270} end
    store.addonVersion = Bars.version
end

-- This new product has no MOS data to import. DAB import has a separate,
-- explicitly validated workflow; never borrow a legacy shell preference.
BootyLib.Data.RegisterOwner("actionbars", "BootyActionBarsDB", function() return false end, Defaults)

function Database.Ensure()
    -- Guard before the shared migration/default pipeline can touch this store.
    local store = BootyActionBarsDB
    if store ~= nil and type(store) ~= "table" then
        return nil, "Invalid BootyActionBars saved data. Preserve it before repairing the saved file."
    end
    if store and store.schemaVersion ~= nil and store.schemaVersion ~= Database.SCHEMA_VERSION then
        return nil, "Unsupported BootyActionBars saved data. Update the addon before opening it."
    end
    if store then
        local valid, failure = Bars.Services.BarConfig.Validate(store.customBars)
        if not valid then return nil, failure end
        valid, failure = Bars.Services.BarConfig.ValidateSpecial(store.specialBars)
        if not valid then return nil, failure end
        valid, failure = Bars.Services.BarLayout.ValidateLayouts(store.barLayouts)
        if not valid then return nil, failure end
        if Bars.Services.LayoutProfiles then
            valid, failure = Bars.Services.LayoutProfiles.ValidateStore(store.layoutProfiles)
            if not valid then return nil, failure end
        end
        valid, failure = EditorOptions(store.editorOptions)
        if not valid then return nil, failure end
    end
    return BootyLib.Data.Ensure("actionbars")
end
