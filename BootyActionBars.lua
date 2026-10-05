local Bars = BootyActionBars
local Runtime = Bars.Core.Runtime

function Bars.GetQuickMenu(host)
    return {{text = "Action Bars", icon = "list", enabled = Runtime.IsAvailable(),
        action = function() return host.OpenView("actionbars") end}}
end

Bars.Product = {
    id = "actionbars", name = "BootyActionBars", title = "BootyActionBars",
    version = Bars.version, apiVersion = Bars.API_VERSION, namespace = Bars,
    Initialize = Runtime.Initialize, OnHostReady = Runtime.OnHostReady,
    GetDatabase = Bars.Database.Ensure,
    views = {{id = "actionbars", label = "Action Bars", icon = "list",
        create = Runtime.CreateView, IsAvailable = Runtime.IsAvailable,
        width = 560, height = 340, minWidth = 350, minHeight = 260}},
    GetQuickMenu = Bars.GetQuickMenu, GetSettings = Bars.GetSettings,
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
