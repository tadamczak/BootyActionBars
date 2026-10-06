BootyActionBars = BootyActionBars or {}
local Bars = BootyActionBars
local version = type(GetAddOnMetadata) == "function" and GetAddOnMetadata("BootyActionBars", "Version")
Bars.version = type(version) == "string" and version ~= "" and version or "0.1.0-dev.5"
Bars.API_VERSION = 1
Bars.Core = Bars.Core or {}
Bars.Modules = Bars.Modules or {}
Bars.Services = Bars.Services or {}
Bars.UI = BootyLib.UI
BINDING_HEADER_BOOTYACTIONBARS = "BootyActionBars"
for index = 1, 12 do
    _G["BINDING_NAME_BOOTYACTIONBARS_BUTTON" .. index] = "Action button " .. index
end
