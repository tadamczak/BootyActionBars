local Bars = BootyActionBars
local Runtime = Bars.Core.Runtime

function Bars.GetQuickMenu(host)
    return {{text = "Action Bars", icon = "list", enabled = Runtime.IsAvailable(),
        action = function() return host.OpenView("actionbars") end}}
end

-- Explicit inspection only. The optional observer owns wrapping and timing;
-- asking for targets never creates gameplay frames or activates the engine.
function Bars.GetProfilingTargets()
    local Engine = Bars.Core.Engine
    local state = Engine.GetState()
    local targets = {{kind = "function", owner = Engine, key = "HandleEvent",
        name = "Action bar events", parameters = 2, results = 0}}
    local initialized = false
    local configured, specialConfigured = state.customConfiguredCount or 0, 0
    local store = BootyActionBarsDB
    if type(store) == "table" then
        configured = 0
        for _, id in ipairs(Bars.Services.BarConfig.CustomIDs) do if Bars.Services.BarMerging.Shown(store, id) then configured = configured + 1 end end
        for _, id in ipairs({7, 8}) do if Bars.Services.BarMerging.Shown(store, id) then specialConfigured = specialConfigured + 1 end end
    end
    for _, barId in ipairs(Bars.Services.BarConfig.OrdinaryIDs) do
        local view = state.views and state.views[barId]
        if barId == 1 and not view then view = state.view end
        if view then
            initialized = true
            for index = 1, 12 do
                local button = view.buttons[index]
                if button and button.cooldown then
                    local name = barId == 1 and "Cooldown " .. index or "Bar " .. Bars.Services.BarConfig.Page(barId) .. " cooldown " .. index
                    targets[table.getn(targets) + 1] = {kind = "script", frame = button.cooldown,
                        script = "OnUpdateModel", name = name, parameters = 0, results = 0}
                end
            end
        end
    end
    return {contractVersion = 1, productVersion = Bars.version,
        active = state.active == true, requested = state.requested == true,
        subscribed = state.subscribed == true, framesInitialized = initialized,
        customRevision = state.customRevision or 0,
        customConfiguredCount = configured,
        customActiveCount = state.customActiveCount or 0,
        specialConfiguredCount = specialConfigured,
        runtimeStopped = Runtime.GetState().stopped == true,
        settingsEnabled = type(BootyActionBarsDB) == "table" and BootyActionBarsDB.trialBarEnabled == true,
        targets = targets}
end

Bars.Product = {
    id = "actionbars", name = "BootyActionBars", title = "BootyActionBars",
    version = Bars.version, apiVersion = Bars.API_VERSION, namespace = Bars,
    Initialize = Runtime.Initialize, OnHostReady = Runtime.OnHostReady,
    GetDatabase = Bars.Database.Ensure,
    views = {{id = "actionbars", label = "Action Bars", icon = "list",
        create = Runtime.CreateView, IsAvailable = Runtime.IsAvailable,
        width = 560, height = 520, minWidth = 350, minHeight = 480}},
    GetQuickMenu = Bars.GetQuickMenu, GetSettings = Bars.GetSettings,
    GetProfilingTargets = Bars.GetProfilingTargets,
    BeginSettingsBatch = Runtime.BeginSettingsBatch, EndSettingsBatch = Runtime.EndSettingsBatch,
    OnSettingsProfileApplied = Runtime.OnSettingsProfileApplied,
    Stop = Runtime.Stop, Start = Runtime.Start, IsBusy = Runtime.IsBusy,
}
local registered, failure = BootyLib.RegisterProduct(Bars.Product)
if not registered then BootyLib.Print(failure) end
SlashCmdList = SlashCmdList or {}
SLASH_BOOTYACTIONBARS1, SLASH_BOOTYACTIONBARS2 = "/bab", "/bootyactionbars"
SlashCmdList.BOOTYACTIONBARS = function(command)
    command = string.lower(string.gsub(string.gsub(command or "", "^%s+", ""), "%s+$", ""))
    return Runtime.Open(command)
end
