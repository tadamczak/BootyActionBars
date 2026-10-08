local Bars = BootyActionBars
local fields = {{
    key = "hideMinimapIcon", legacyKey = "actionbarsHideMinimapIcon",
    label = "Hide minimap icon", type = "checkbox", default = false,
    path = {"Action Bars", "General"},
    tooltip = "Hide the BootyActionBars minimap icon when running without Booty Suite. Use /bab to open Action Bars.",
    set = function(value, store) store.hideMinimapIcon = value == true end,
    onChange = Bars.Core.Runtime.SettingsChanged,
}, {
    key = "trialBarEnabled", label = "Show BootyActionBars", type = "checkbox", default = false,
    profile = false, path = {"Action Bars", "General"},
    tooltip = "Enable the main bar and configured additional bars. Main follows client pages and forms by default; change this fallback under Main Action Bar > Behaviors. Custom rules take priority. Dragging changes shared client actions. Assign keys under BootyActionBars in the game's Key Bindings menu.",
    set = function(value) return Bars.Core.Runtime.SetTrialEnabled(value) end,
    onChange = Bars.Core.Runtime.SettingsChanged,
}}

function Bars.GetSettings()
    local store = Bars.Database.Ensure()
    if not store then return nil end
    return {db = store, fields = fields}
end
