BootyActionBars = BootyActionBars or {}
local Bars = BootyActionBars
local version = type(GetAddOnMetadata) == "function" and GetAddOnMetadata("BootyActionBars", "Version")
Bars.version = type(version) == "string" and version ~= "" and version or "0.1.0-dev.1"
Bars.API_VERSION = 1
Bars.Core = Bars.Core or {}
Bars.Modules = Bars.Modules or {}
Bars.Services = Bars.Services or {}
Bars.UI = BootyLib.UI
