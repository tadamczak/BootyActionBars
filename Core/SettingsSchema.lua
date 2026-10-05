local Bars = BootyActionBars
local fields = {{
    key = "hideMinimapIcon", legacyKey = "actionbarsHideMinimapIcon",
    label = "Hide minimap icon", type = "checkbox", default = false,
    path = {"Action Bars", "General"},
    tooltip = "Hide the BootyActionBars minimap icon when running without Booty Suite. Use /bab to open Action Bars.",
    set = function(value, store) store.hideMinimapIcon = value == true end,
    onChange = Bars.Core.Runtime.SettingsChanged,
}}

function Bars.GetSettings()
    local store = Bars.Database.Ensure()
    if not store then return nil end
    return {db = store, fields = fields}
end
