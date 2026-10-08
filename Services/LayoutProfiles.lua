local Bars = BootyActionBars
local Profiles = {}
Bars.Services.LayoutProfiles = Profiles
local Behavior = Bars.Services.BehaviorService
local Config = Bars.Services.BarConfig
Profiles.VERSION, Profiles.LIMIT = 2, 20
local fields = {"x", "y"}
for _, key in ipairs(Bars.Services.BarLayout.GlobalKeys) do table.insert(fields, key) end
local function LocalField(key) return Bars.Services.BarLayout.ProfileField(key, 2) end
local function GlobalCopy(value, existing)
    local copy = {}
    for key, item in pairs(existing or {}) do if not Bars.Services.BarLayout.ValidGlobalValue(key, item) then copy[key] = item end end
    for _, key in ipairs(Bars.Services.BarLayout.GlobalKeys) do copy[key] = value and value[key] end
    return copy
end

function Profiles.Name(value)
    if type(value) ~= "string" then return nil, "Enter a layout name." end
    local name = string.gsub(string.gsub(value, "^%s+", ""), "%s+$", "")
    if name == "" or string.len(name) > 64 or string.find(name, "[%c]") then return nil, "Use a layout name of 1-64 characters." end
    return name
end
function Profiles.ValidateStore(profiles)
    if profiles == nil then return true end
    if type(profiles) ~= "table" then return false, "Invalid saved layout profiles. Preserve the saved file before repairing it." end
    local count = 0
    for name, record in pairs(profiles) do
        local normalized = Profiles.Name(name)
        if normalized ~= name or type(record) ~= "table" then return false, "Invalid saved layout profile name or record." end
        count = count + 1
        if count > Profiles.LIMIT then return false, "At most 20 layout profiles are supported." end
    end
    return true
end
function Profiles.Validate(profile)
    if type(profile) ~= "table" or (profile.version ~= 1 and profile.version ~= Profiles.VERSION) then return false, "Unsupported action bar layout profile." end
    for key in pairs(profile) do
        if key ~= "version" and key ~= "barLayouts" and key ~= "customBars" and key ~= "specialBars"
            and not (profile.version == 2 and (key == "globalLayout" or key == "mainBarShown" or key == "mainBarFollowClient"
                or key == "barBehaviors" or key == "utilityLayouts" or key == "barMerges" or key == "mergeStyleOverrides")) then return false, "Unexpected layout profile data." end
    end
    local ok, failure = Bars.Services.BarConfig.Validate(profile.customBars)
    if not ok then return false, failure end
    ok, failure = Bars.Services.BarConfig.ValidateSpecial(profile.specialBars)
    if not ok then return false, failure end
    if type(profile.customBars) ~= "table" or type(profile.specialBars) ~= "table" then return false, "Layout profile bar visibility is missing." end
    if profile.version == 2 then
        if profile.mainBarFollowClient ~= nil and type(profile.mainBarFollowClient) ~= "boolean" then
            return false, "Invalid main bar page following in the layout profile."
        end
        if profile.barMerges ~= nil then
            if not Bars.Services.BarMerging then return false, "Merged layouts are unavailable." end
            ok, failure = Bars.Services.BarMerging.Validate(profile.barMerges)
            if not ok then return false, failure end
        end
        if profile.mergeStyleOverrides ~= nil then
            ok, failure = Bars.Services.BarMerging.ValidateOverrides(profile.mergeStyleOverrides)
            if not ok then return false, failure end
        end
        ok, failure = Behavior.Validate(profile.barBehaviors)
        if not ok then return false, failure end
        if profile.utilityLayouts ~= nil then
            if not Bars.Services.UtilityLayout then return false, "Utility-bar layouts are unavailable." end
            ok, failure = Bars.Services.UtilityLayout.Validate(profile.utilityLayouts)
            if not ok then return false, failure end
        end
    end
    ok, failure = Bars.Services.BarLayout.ValidateLayouts(profile.barLayouts)
    if not ok then return false, failure end
    if type(profile.barLayouts) ~= "table" then return false, "Layout profile geometry is missing." end
    if profile.version == 2 then
        if type(profile.globalLayout) ~= "table" or type(profile.mainBarShown) ~= "boolean" then return false, "Global layout or main bar visibility is missing." end
        ok, failure = Bars.Services.BarLayout.ValidateGlobal(profile.globalLayout)
        if not ok then return false, failure end
        for key, value in pairs(profile.globalLayout) do
            if not Bars.Services.BarLayout.ValidGlobalValue(key, value) then return false, "Unexpected global layout data." end
        end
    end
    for _, id in ipairs(Config.LayoutIDs) do
        local record = profile.barLayouts[id]
        if id <= 8 and type(record) ~= "table" then return false, "Layout profiles must contain all eight original bar layouts." end
        if record then
            for key in pairs(record) do
                if not Bars.Services.BarLayout.ProfileField(key, profile.version) then return false, "Unexpected layout appearance data." end
            end
            if profile.version == 2 and (type(record.useGlobalLayout) ~= "boolean" or type(record.localLayoutSaved) ~= "boolean") then
                return false, "Layout inheritance flags are missing."
            end
        end
    end
    return true
end
local function Flags(value)
    local copy = {}
    for key, enabled in pairs(value or {}) do copy[key] = enabled end
    return copy
end
function Profiles.Capture(store)
    if type(store) ~= "table" then return nil, "Action bar settings are unavailable." end
    local ok, failure = Bars.Services.BarConfig.Validate(store.customBars)
    if not ok then return nil, failure end
    ok, failure = Bars.Services.BarConfig.ValidateSpecial(store.specialBars)
    if not ok then return nil, failure end
    ok, failure = Behavior.Validate(store.barBehaviors)
    if not ok then return nil, failure end
    ok, failure = Bars.Services.BarLayout.ValidateGlobal(store.globalLayout)
    if not ok then return nil, failure end
    if store.mainBarShown ~= nil and type(store.mainBarShown) ~= "boolean" then return nil, "Invalid main bar visibility." end
    if store.mainBarFollowClient ~= nil and type(store.mainBarFollowClient) ~= "boolean" then return nil, "Invalid main bar page following." end
    local result = {version = Profiles.VERSION, barLayouts = {}, customBars = Flags(store.customBars), specialBars = Flags(store.specialBars),
        globalLayout = GlobalCopy(store.globalLayout), mainBarShown = store.mainBarShown ~= false, mainBarFollowClient = store.mainBarFollowClient ~= false,
        barBehaviors = Behavior.Copy(store.barBehaviors)}
    if Bars.Services.BarMerging then
        result.barMerges, failure = Bars.Services.BarMerging.Copy(store.barMerges)
        if not result.barMerges then return nil, failure end
        local valid; valid, failure = Bars.Services.BarMerging.ValidateOverrides(store.mergeStyleOverrides)
        if not valid then return nil, failure end
        result.mergeStyleOverrides = Flags(store.mergeStyleOverrides)
    end
    if Bars.Services.UtilityLayout then
        result.utilityLayouts, failure = Bars.Services.UtilityLayout.Copy(store.utilityLayouts)
        if not result.utilityLayouts then return nil, failure end
    end
    for _, id in ipairs(Config.LayoutIDs) do
        local record, reason = Bars.Services.BarLayout.ReadLocal(store.barLayouts, id)
        if not record then return nil, reason end
        result.barLayouts[id] = record
    end
    return result
end
function Profiles.Prepare(profile, existingLayouts, existingGlobal, existingBehaviors)
    local ok, failure = Profiles.Validate(profile)
    if not ok then return nil, failure end
    ok, failure = Bars.Services.BarLayout.ValidateLayouts(existingLayouts)
    if not ok then return nil, failure end
    ok, failure = Bars.Services.BarLayout.ValidateGlobal(existingGlobal)
    if not ok then return nil, failure end
    ok, failure = Behavior.Validate(existingBehaviors)
    if not ok then return nil, failure end
    local result = {barLayouts = {}, customBars = Flags(profile.customBars), specialBars = Flags(profile.specialBars),
        replaceGlobal = profile.version == 2, replaceBehaviors = profile.version == 2 and profile.barBehaviors ~= nil}
    if profile.version == 2 and profile.barMerges ~= nil then
        result.barMerges, failure = Bars.Services.BarMerging.Copy(profile.barMerges)
        if not result.barMerges then return nil, failure end
        result.replaceMerges = true
    end
    if profile.version == 2 and profile.mergeStyleOverrides ~= nil then
        result.mergeStyleOverrides = Flags(profile.mergeStyleOverrides)
        result.replaceMergeStyles = true
    end
    if profile.version == 2 and profile.utilityLayouts ~= nil then
        result.utilityLayouts, failure = Bars.Services.UtilityLayout.Copy(profile.utilityLayouts)
        if not result.utilityLayouts then return nil, failure end
        result.replaceUtilities = true
    end
    if result.replaceBehaviors then result.barBehaviors = Behavior.Copy(profile.barBehaviors) end
    if profile.version == 2 then
        result.globalLayout = GlobalCopy(profile.globalLayout, existingGlobal)
        result.mainBarShown = profile.mainBarShown
        result.mainBarFollowClient = profile.mainBarFollowClient
    end
    for _, id in ipairs(Config.LayoutIDs) do
        local record = {}
        -- Preserve extension fields already owned by the current saved record;
        -- a named layout replaces only this product's declared preferences.
        for key, value in pairs(existingLayouts and existingLayouts[id] or {}) do if not LocalField(key) then record[key] = value end end
        local saved = profile.barLayouts[id]
        if saved then
            for _, key in ipairs(fields) do record[key] = saved[key] end
            record.useGlobalLayout = profile.version == 2 and saved.useGlobalLayout or false
            record.localLayoutSaved = profile.version ~= 2 or saved.localLayoutSaved
            result.barLayouts[id] = record
        elseif existingLayouts and existingLayouts[id] then
            -- Older profiles have no opinion about later ordinary bar layouts.
            for key, value in pairs(existingLayouts[id]) do record[key] = value end
            result.barLayouts[id] = record
        end
    end
    return result
end
function Profiles.Names(profiles)
    local ok, failure = Profiles.ValidateStore(profiles)
    if not ok then return nil, failure end
    local names = {}
    for name in pairs(profiles or {}) do table.insert(names, name) end
    table.sort(names)
    return names
end
function Profiles.Save(store, name, replace)
    if type(store) ~= "table" then return false, "Action bar settings are unavailable." end
    local normalized, reason = Profiles.Name(name)
    if not normalized then return false, reason end
    local names, failure = Profiles.Names(store.layoutProfiles)
    if not names then return false, failure end
    if store.layoutProfiles and store.layoutProfiles[normalized] and replace ~= true then return false, "Confirm replacing this layout profile." end
    if not (store.layoutProfiles and store.layoutProfiles[normalized]) and table.getn(names) >= Profiles.LIMIT then return false, "At most 20 layout profiles are supported." end
    local snapshot, why = Profiles.Capture(store)
    if not snapshot then return false, why end
    if not store.layoutProfiles then store.layoutProfiles = {} end
    store.layoutProfiles[normalized] = snapshot
    return true, normalized
end
function Profiles.Delete(store, name)
    if type(store) ~= "table" then return false, "Action bar settings are unavailable." end
    local normalized, reason = Profiles.Name(name)
    if not normalized then return false, reason end
    if not store.layoutProfiles or not store.layoutProfiles[normalized] then return false, "Choose an existing layout profile." end
    store.layoutProfiles[normalized] = nil
    return true
end
