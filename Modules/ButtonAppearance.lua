local Bars = BootyActionBars
local UI = Bars.UI.Components
local Appearance = {}
Bars.Modules.ButtonAppearance = Appearance
local fields = {"hoverMode", "hoverSize", "showButtonBorder", "borderSize", "buttonBackground", "nativeTexture", "nativeTextureBackground", "nativeTextureScalePct", "gryphons"}
for _, prefix in ipairs({"rangeIn", "rangeOut", "hover", "border"}) do
    for _, channel in ipairs({"R", "G", "B", "A"}) do table.insert(fields, prefix .. channel) end
end
-- Stock 1.12 uses a 256x256 atlas for a 1024x43 menu. Keep the
-- 512x43 action section and close its right edge with the stock end cap.
-- Entries are x,y,width,height,left,right,top,bottom in native pixels/UV.
local slices = {{0, 0, 256, 43, 0, 1, 213 / 256, 1},
    {256, 0, 247, 43, 0, 247 / 256, 149 / 256, 192 / 256},
    {503, 0, 9, 43, 246 / 256, 255 / 256, 21 / 256, 64 / 256}}
local edges = {}
for _, slice in ipairs(slices) do
    table.insert(edges, {slice[1], 40, slice[3], 3, slice[5], slice[6], slice[7], slice[7] + 3 / 256})
    table.insert(edges, {slice[1], 0, slice[3], 4, slice[5], slice[6], slice[8] - 4 / 256, slice[8]})
end
-- Buttons occupy x8..506,y4..40. Exclude their complete recessed squares.
table.insert(edges, {0, 4, 8, 36, 0, 8 / 256, 216 / 256, 252 / 256})
table.insert(edges, {506, 4, 6, 36, 249 / 256, 255 / 256, 24 / 256, 60 / 256})
local defaultHover = "Interface\\Buttons\\ButtonHilight-Square"
local shadowHover = "Interface\\Buttons\\UI-ActionButton-Border"
local borderFields = {hoverMode = true, hoverSize = true, showButtonBorder = true, borderSize = true,
    hoverR = true, hoverG = true, hoverB = true, hoverA = true, borderR = true, borderG = true, borderB = true, borderA = true}
local hoverFields = {hoverMode = true, hoverSize = true, hoverR = true, hoverG = true, hoverB = true, hoverA = true}
local sides = {"left", "right"}
local function Style(view, drawing)
    local style = view.buttonAppearance
    if not style then
        style = {borderColor = {}, hoverColor = {}, borderRevision = 0, hoverRevision = 0}
        view.buttonAppearance = style
    end
    local borderChanged, hoverChanged = false, false
    for _, key in ipairs(fields) do
        local value = drawing and drawing[key]
        if value == nil then value = Bars.Services.BarLayout.DefaultValue(key) end
        if style[key] ~= value then
            if borderFields[key] then borderChanged = true end
            if hoverFields[key] then hoverChanged = true end
        end
        style[key] = value
    end
    style.borderColor[1], style.borderColor[2], style.borderColor[3] = style.borderR, style.borderG, style.borderB
    style.hoverColor[1], style.hoverColor[2], style.hoverColor[3] = style.hoverR, style.hoverG, style.hoverB
    local size, inset = drawing and drawing.buttonSize or 40, drawing and drawing.iconInset or 4
    if style.buttonSize ~= size or style.iconInset ~= inset then hoverChanged = true end
    if drawing then
        style.width, style.height = drawing.barWidth or style.width, drawing.barHeight or style.height
    end
    style.buttonSize, style.iconInset = size, inset
    if borderChanged then style.borderRevision = style.borderRevision + 1 end
    if hoverChanged then style.hoverRevision = style.hoverRevision + 1 end
    return style
end
local function Border(button, repair)
    local style = button.bar.buttonAppearance
    local hover = button.appearanceHovered and style.hoverMode == "border"
    local visible = style.showButtonBorder or hover
    local size = hover and style.hoverSize or style.borderSize
    local color = hover and style.hoverColor or style.borderColor
    local alpha = hover and style.hoverA or style.borderA
    if not repair and button.appearanceBorderReady and button.appearanceBorderRevision == style.borderRevision
        and button.appearanceBorderHovered == hover then return end
    button.appearanceBorderReady = false
    if visible or button.mosProjectOutline then
        UI.SetProjectButtonOutline(button, visible, size, color)
        button.mosProjectOutline:SetBackdropBorderColor(color[1], color[2], color[3], alpha)
    end
    button.appearanceBorderRevision, button.appearanceBorderHovered = style.borderRevision, hover
    button.appearanceBorderReady = true
end
local function Feedback(button, repair)
    local style, feedback = button.bar.buttonAppearance, button.hoverFeedback
    local shown = button.appearanceHovered and style.hoverMode ~= "border"
    if not repair and button.appearanceHoverReady and button.appearanceHoverRevision == style.hoverRevision
        and button.appearanceHoverShown == shown then return end
    button.appearanceHoverReady = false
    local shadow = style.hoverMode == "shadow"
    feedback:SetTexture(shadow and shadowHover or defaultHover)
    feedback:SetBlendMode(shadow and "BLEND" or "ADD")
    local shade = shadow and 0.2 or 1
    feedback:SetVertexColor(style.hoverR * shade, style.hoverG * shade, style.hoverB * shade, 1)
    feedback:SetAlpha(style.hoverA)
    feedback:ClearAllPoints()
    if shadow then
        local extent = style.buttonSize + style.hoverSize * 4
        feedback:SetPoint("CENTER", button, "CENTER", 0, 0)
        feedback:SetWidth(extent); feedback:SetHeight(extent)
    elseif style.hoverSize == 2 then feedback:SetAllPoints(button.icon)
    else
        local expansion = style.hoverSize - 2
        feedback:SetPoint("TOPLEFT", button.icon, "TOPLEFT", -expansion, expansion)
        feedback:SetPoint("BOTTOMRIGHT", button.icon, "BOTTOMRIGHT", expansion, -expansion)
    end
    if shown then feedback:Show() else feedback:Hide() end
    button.appearanceHoverRevision, button.appearanceHoverShown = style.hoverRevision, shown
    button.appearanceHoverReady = true
end
function Appearance.ApplyColor(button, data, repair)
    local style = button.bar.buttonAppearance
    local state = data.usable and (data.inRange == 0 and 2 or 1) or data.noMana and 3 or 4
    local red, green, blue, alpha
    if state == 1 then red, green, blue, alpha = style.rangeInR, style.rangeInG, style.rangeInB, style.rangeInA
    elseif state == 2 then red, green, blue, alpha = style.rangeOutR, style.rangeOutG, style.rangeOutB, style.rangeOutA
    elseif state == 3 then red, green, blue, alpha = 0.5, 0.5, 1, 1
    else red, green, blue, alpha = 0.3, 0.3, 0.3, 1 end
    if repair or not button.appearanceTintReady or button.appearanceR ~= red or button.appearanceG ~= green
        or button.appearanceB ~= blue or button.appearanceA ~= alpha then
        -- A setter can mutate the widget before throwing. A failed write must
        -- leave this cache dirty so restoring the previous style repaints it.
        button.appearanceTintReady = false
        button.icon:SetVertexColor(red, green, blue, alpha)
        button.appearanceR, button.appearanceG, button.appearanceB, button.appearanceA = red, green, blue, alpha
        button.appearanceTintReady = true
    end
    button.appearanceHasState = true
    button.rendered.color = state
end
function Appearance.Hover(button, enabled)
    button.appearanceHovered = enabled == true
    Border(button); Feedback(button)
end
function Appearance.InitializeButton(button)
    if not button.bar.buttonAppearance then Style(button.bar) end
    UI.ApplyDropdownChoiceSurface(button)
    button:SetBackdropBorderColor(0, 0, 0, 0)
    button.hoverFeedback = UI.CreateTexture(button, nil, "OVERLAY")
    button.appearanceHovered = false
    Border(button, true); Feedback(button, true)
    button.appearanceBackground = true
    return true
end
local function ShowArt(texture, shown, repair)
    if repair or texture.appearanceShown ~= shown then
        if shown then texture:Show() else texture:Hide() end
        texture.appearanceShown = shown
    end
end
local function DrawArtwork(view, textures, pieces, shown, ratio, startX, repair)
    for index, piece in ipairs(pieces) do
        local texture = textures[index]
        if shown and not texture then
            texture = UI.CreateTexture(view.frame, nil, "BACKGROUND"); textures[index] = texture
        end
        if texture then
            if shown then
                texture:SetTexture("Interface\\MainMenuBar\\UI-MainMenuBar-Dwarf")
                texture:SetTexCoord(piece[5], piece[6], piece[7], piece[8])
                texture:ClearAllPoints()
                texture:SetPoint("BOTTOMLEFT", view.frame, "BOTTOMLEFT", startX + piece[1] * ratio, piece[2] * ratio)
                texture:SetWidth(piece[3] * ratio); texture:SetHeight(piece[4] * ratio)
            end
            ShowArt(texture, shown, repair)
        end
    end
end
local function Decorations(view, style, repair)
    local art = view.buttonDecorations
    if not art and not style.nativeTexture and style.gryphons == "none" then return end
    if not art then art = {panels = {}}; view.buttonDecorations = art end
    -- PrepareDisplay can provide the saved record before the first resolved
    -- grid. Native dimensions are safe here; this is never an action read.
    if not style.width then style.width = view.frame:GetWidth() end
    if not style.height then style.height = view.frame:GetHeight() end
    local changed = repair or not art.ready or art.width ~= style.width or art.height ~= style.height
        or art.size ~= style.buttonSize or art.nativeTexture ~= style.nativeTexture or art.gryphons ~= style.gryphons
        or art.background ~= style.nativeTextureBackground or art.scalePct ~= style.nativeTextureScalePct
    if not changed then return end
    art.ready = false
    -- The decoration keeps its original aspect even for a multi-row grid.
    local ratio = style.width / 512 * style.nativeTextureScalePct / 100
    local startX = (style.width - 512 * ratio) / 2
    DrawArtwork(view, art.panels, slices, style.nativeTexture and style.nativeTextureBackground, ratio, startX, repair)
    local showEdges = style.nativeTexture and not style.nativeTextureBackground
    if showEdges and not art.edges then art.edges = {} end
    if art.edges then DrawArtwork(view, art.edges, edges, showEdges, ratio, startX, repair) end
    for _, side in ipairs(sides) do
        local shown = style.gryphons == "both" or style.gryphons == side
        local texture = art[side]
        if shown and not texture then texture = UI.CreateTexture(view.frame, nil, "BACKGROUND"); art[side] = texture end
        if texture then
            if shown then
                texture:SetTexture("Interface\\MainMenuBar\\UI-MainMenuBar-EndCap-Dwarf")
                if side == "right" then texture:SetTexCoord(1, 0, 0, 1) else texture:SetTexCoord(0, 1, 0, 1) end
                local ratio = style.buttonSize / 40
                texture:SetWidth(128 * ratio); texture:SetHeight(128 * ratio)
                texture:ClearAllPoints()
                texture:SetPoint(side == "left" and "BOTTOMRIGHT" or "BOTTOMLEFT", view.frame,
                    side == "left" and "BOTTOMLEFT" or "BOTTOMRIGHT", side == "left" and 32 * ratio or -32 * ratio, 0)
            end
            ShowArt(texture, shown, repair)
        end
    end
    art.width, art.height, art.size, art.nativeTexture, art.gryphons = style.width, style.height, style.buttonSize, style.nativeTexture, style.gryphons
    art.background, art.scalePct = style.nativeTextureBackground, style.nativeTextureScalePct
    art.ready = true
end
function Appearance.ApplyView(view, drawing, repair)
    local style = Style(view, drawing)
    for _, button in ipairs(view.buttons) do
        if repair or button.appearanceBackground ~= style.buttonBackground then
            button.appearanceBackground = nil
            button:SetBackdropColor(0.08, 0.08, 0.08, style.buttonBackground and 0.95 or 0)
            button.appearanceBackground = style.buttonBackground
        end
        Border(button, repair); Feedback(button, repair)
        if button.appearanceHasState then Appearance.ApplyColor(button, button.rendered, repair) end
    end
    Decorations(view, style, repair)
    return true
end
