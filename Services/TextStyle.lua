local Style = {}
BootyActionBars.Services.TextStyle = Style
Style.Paths = {friz = "Fonts\\FRIZQT__.TTF", arial = "Fonts\\ARIALN.TTF", morpheus = "Fonts\\MORPHEUS.TTF", skurri = "Fonts\\SKURRI.TTF"}
Style.Choices = {default = true, friz = true, arial = true, morpheus = true, skurri = true}
Style.Options = {{value = "default", text = "Default"}, {value = "friz", text = "Friz Quadrata"},
    {value = "arial", text = "Arial"}, {value = "morpheus", text = "Morpheus"}, {value = "skurri", text = "Skurri"}}
function Style.Font(key, original)
    key = key or "default"
    if not Style.Choices[key] then return nil, "Choose a supported font." end
    return key == "default" and original or Style.Paths[key]
end
