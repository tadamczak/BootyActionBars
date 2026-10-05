local Bars = BootyActionBars
local fields = {{
    key = "hideMinimapIcon", legacyKey = "actionbarsHideMinimapIcon",
    label = "Hide minimap icon", type = "checkbox", default = false,
    path = {"Action Bars", "General"},
    tooltip = "Hide the BootyActionBars minimap icon when running without Booty Suite. Use /bab to open Action Bars.",
    set = function(value, store) store.hideMinimapIcon = value == true end,
    onChange = Bars.Core.Runtime.SettingsChanged,
}, {
    key = "trialBarEnabled", label = "Enable test bar (slots 1-12)", type = "checkbox", default = false,
    profile = false, path = {"Action Bars", "General"},
    tooltip = "Show the optional fixed slots 1-12 test bar. Dragging actions changes these shared client slots, including other bars. Set its own keys in the game's Key Bindings menu. Paging, forms and pets are not supported yet.",
    set = function(value) return Bars.Core.Runtime.SetTrialEnabled(value) end,
    onChange = Bars.Core.Runtime.SettingsChanged,
}}

function Bars.GetSettings()
    local store = Bars.Database.Ensure()
    if not store then return nil end
    return {db = store, fields = fields}
end
