local Style = {}
BootyActionBars.Services.TextStyle = Style
Style.Paths = {friz = "Fonts\\FRIZQT__.TTF", arial = "Fonts\\ARIALN.TTF", morpheus = "Fonts\\MORPHEUS.TTF", skurri = "Fonts\\SKURRI.TTF"}
-- Exact stock 1.12 FontXML roles, independent of another addon changing shared FontObjects.
Style.Native = {
    hotkey = {face = Style.Paths.arial, size = 12, flags = "THICKOUTLINE,MONOCHROME"},
    count = {face = Style.Paths.arial, size = 17, flags = "OUTLINE"},
    macro = {face = Style.Paths.friz, size = 10, flags = "OUTLINE"},
    cooldown = {face = Style.Paths.friz, size = 24, flags = "OUTLINE"},
}
Style.Choices = {native = true, default = true, friz = true, arial = true, morpheus = true, skurri = true}
Style.Options = {{value = "native", text = "Game default"}, {value = "default", text = "Original font"}, {value = "friz", text = "Friz Quadrata"},
    {value = "arial", text = "Arial"}, {value = "morpheus", text = "Morpheus"}, {value = "skurri", text = "Skurri"}}
function Style.Font(key, original, role)
    key = key or "default"
    if not Style.Choices[key] then return nil, "Choose a supported font." end
    if key == "native" and Style.Native[role] then return Style.Native[role].face end
    return (key == "default" or key == "native") and original or Style.Paths[key]
end
