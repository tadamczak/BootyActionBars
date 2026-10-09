local Bars = BootyActionBars
local UI = Bars.UI.Components
local Appearance = {}
Bars.Modules.ButtonAppearance = Appearance
local NativeLayout = Bars.Services.NativeDecorationLayout
local fields = {"hoverMode", "hoverSize", "hoverBackgroundShadow", "hoverBorderShadow", "hoverBorder", "hoverBorderSize", "hoverRadius",
    "showButtonBorder", "borderSize", "buttonBackground", "nativeTexture", "nativeBackground", "nativeBorder", "nativeSlotArtwork",
    "nativeTextureScalePct", "nativeBorderScalePct", "nativeButtonScalePct", "gryphons", "gryphonScalePct", "columns", "spacing"}
for _, prefix in ipairs({"rangeIn", "rangeOut", "hover", "border"}) do
    for _, channel in ipairs({"R", "G", "B", "A"}) do table.insert(fields, prefix .. channel) end
end
local defaultHover = "Interface\\Buttons\\ButtonHilight-Square"
local borderFields = {hoverMode = true, hoverBorder = true, hoverSize = true, hoverBorderSize = true, hoverRadius = true, showButtonBorder = true, borderSize = true,
    hoverR = true, hoverG = true, hoverB = true, hoverA = true, borderR = true, borderG = true, borderB = true, borderA = true}
local hoverFields = {hoverMode = true, hoverSize = true, hoverBackgroundShadow = true, hoverBorderShadow = true,
    hoverBorder = true, hoverBorderSize = true, hoverRadius = true, hoverR = true, hoverG = true, hoverB = true, hoverA = true}
local legacyHover = {}
for _, prefix in ipairs({"hoverBackground", "hoverShadow", "hoverOutline"}) do
    for _, suffix in ipairs({"Size", "Radius", "R", "G", "B", "A"}) do
        local key = prefix .. suffix
        table.insert(fields, key); hoverFields[key] = true
        if prefix == "hoverOutline" then borderFields[key] = true end
        legacyHover[key] = "hover" .. suffix
    end
end
local sides = {"left", "right"}
local function Style(view, drawing)
    local style = view.buttonAppearance
    if not style then
        style = {borderColor = {}, hoverColor = {}, hoverOutlineColor = {}, borderRevision = 0, hoverRevision = 0}
        view.buttonAppearance = style
    end
    local borderChanged, hoverChanged = false, false
    for _, key in ipairs(fields) do
        local value = drawing and drawing[key]
        if value == nil then
            if legacyHover[key] then
                value = drawing and drawing[legacyHover[key]]
                if value == nil then value = Bars.Services.BarLayout.DefaultValue(legacyHover[key]) end
            elseif key == "nativeSlotArtwork" then value = drawing and drawing.nativeTexture == true and drawing.nativeTextureBackground ~= false or false
            elseif key == "nativeBackground" or key == "nativeBorder" then value = drawing and drawing.nativeTexture == true or false
            elseif key == "nativeButtonScalePct" or key == "nativeBorderScalePct" then value = drawing and drawing.nativeTextureScalePct or Bars.Services.BarLayout.DefaultValue("nativeTextureScalePct")
            elseif key == "hoverBackgroundShadow" then value = drawing and drawing.hoverMode == "shadow" or false
            elseif key == "hoverBorderShadow" then value = not drawing or not drawing.hoverMode or drawing.hoverMode == "default"
            elseif key == "hoverBorder" then value = drawing and drawing.hoverMode == "border" or false
            else value = Bars.Services.BarLayout.DefaultValue(key) end
        end
        if style[key] ~= value then
            if borderFields[key] then borderChanged = true end
            if hoverFields[key] then hoverChanged = true end
        end
        style[key] = value
    end
    style.borderColor[1], style.borderColor[2], style.borderColor[3] = style.borderR, style.borderG, style.borderB
    style.hoverColor[1], style.hoverColor[2], style.hoverColor[3] = style.hoverR, style.hoverG, style.hoverB
    style.hoverOutlineColor[1], style.hoverOutlineColor[2], style.hoverOutlineColor[3] = style.hoverOutlineR, style.hoverOutlineG, style.hoverOutlineB
    local size, inset = drawing and drawing.buttonSize or 40, drawing and drawing.iconInset or 4
    if style.buttonSize ~= size or style.iconInset ~= inset then hoverChanged, borderChanged = true, true end
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
    local hover = button.appearanceHovered and style.hoverBorder
    local visible = style.showButtonBorder or hover
    local size = hover and style.hoverBorderSize or style.borderSize
    local color = hover and style.hoverOutlineColor or style.borderColor
    local alpha = hover and style.hoverOutlineA or style.borderA
    if not repair and button.appearanceBorderReady and button.appearanceBorderRevision == style.borderRevision
        and button.appearanceBorderHovered == hover then return end
    button.appearanceBorderReady = false
    if visible or button.bootyProjectOutline then
        local minimum = math.max(button:GetFrameLevel(), button.cooldown and button.cooldown:GetFrameLevel() or 0) + 1
        UI.SetProjectButtonOutline(button, visible, size, color, nil, minimum, hover and style.hoverOutlineRadius or nil)
        local outline = button.bootyProjectOutline
        if hover then
            local expansion = style.hoverOutlineSize - 1
            outline:ClearAllPoints(); outline:SetPoint("TOPLEFT", button, "TOPLEFT", -expansion, expansion)
            outline:SetPoint("BOTTOMRIGHT", button, "BOTTOMRIGHT", expansion, -expansion)
            outline:SetAlpha(alpha)
        else outline:SetBackdropBorderColor(color[1], color[2], color[3], alpha) end
    end
    button.appearanceBorderRevision, button.appearanceBorderHovered = style.borderRevision, hover
    button.appearanceBorderReady = true
end
local function Feedback(button, repair)
    local style, feedback = button.bar.buttonAppearance, button.hoverFeedback
    local shown = button.appearanceHovered and style.hoverBorderShadow
    local backgroundShown = button.appearanceHovered and style.hoverBackgroundShadow
    if not repair and button.appearanceHoverReady and button.appearanceHoverRevision == style.hoverRevision
        and button.appearanceHoverShown == shown and button.appearanceBackgroundHoverShown == backgroundShown then return end
    button.appearanceHoverReady = false
    local savedThis, savedEvent, a1, a2, a3, a4, a5, a6, a7, a8, a9 = this, event, arg1, arg2, arg3, arg4, arg5, arg6, arg7, arg8, arg9
    local background = button.backgroundHoverFeedback
    if backgroundShown and not background then
        background = UI.CreateTexture(button, nil, "ARTWORK"); button.backgroundHoverFeedback = background
    end
    local failure
    if background then
        if repair and background.bootyRoundedHover then background.bootyRoundedHover.ready = false end
        local ok, reason = pcall(UI.SetRoundedHoverSurface, button, background, backgroundShown, "background",
            style.buttonSize * style.hoverBackgroundSize / 5, style.hoverBackgroundRadius,
            style.hoverBackgroundR, style.hoverBackgroundG, style.hoverBackgroundB, style.hoverBackgroundA)
        if not ok then failure = tostring(reason) end
    end
    this, event, arg1, arg2, arg3, arg4, arg5, arg6, arg7, arg8, arg9 = savedThis, savedEvent, a1, a2, a3, a4, a5, a6, a7, a8, a9
    if repair and feedback.bootyRoundedHover then feedback.bootyRoundedHover.ready = false end
    local ok, reason = pcall(UI.SetRoundedHoverSurface, button, feedback, shown, "shadow",
        style.buttonSize + 2 * (style.hoverShadowSize - 1), style.hoverShadowRadius,
        style.hoverShadowR, style.hoverShadowG, style.hoverShadowB, style.hoverShadowA)
    if not ok then failure = failure or tostring(reason) end
    this, event, arg1, arg2, arg3, arg4, arg5, arg6, arg7, arg8, arg9 = savedThis, savedEvent, a1, a2, a3, a4, a5, a6, a7, a8, a9
    if failure then error(failure) end
    button.appearanceHoverRevision, button.appearanceHoverShown = style.hoverRevision, shown
    button.appearanceBackgroundHoverShown = backgroundShown
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
    local savedThis, savedEvent, a1, a2, a3, a4, a5, a6, a7, a8, a9 = this, event, arg1, arg2, arg3, arg4, arg5, arg6, arg7, arg8, arg9
    local ok, reason = pcall(Border, button)
    local painted, failure = pcall(Feedback, button)
    this, event, arg1, arg2, arg3, arg4, arg5, arg6, arg7, arg8, arg9 = savedThis, savedEvent, a1, a2, a3, a4, a5, a6, a7, a8, a9
    if not ok then error(reason) elseif not painted then error(failure) end
end
function Appearance.InitializeButton(button)
    if not button.bar.buttonAppearance then Style(button.bar) end
    UI.ApplyDropdownChoiceSurface(button)
    button:SetBackdropBorderColor(0, 0, 0, 0)
    button.hoverFeedback = UI.CreateTexture(button, nil, "OVERLAY")
    button.hoverFeedback:SetTexture(defaultHover); button.hoverFeedback:SetBlendMode("ADD")
    button.hoverFeedback:SetAllPoints(button.icon)
    button.appearanceHovered = false
    Border(button, true); Feedback(button, true)
    button.appearanceBackground = true
    return true
end
local function ShowArt(texture, shown, repair)
    if repair or not texture.appearanceReady or texture.appearanceShown ~= shown then
        texture.appearanceReady = false
        if shown then texture:Show() else texture:Hide() end
        local actual = texture:IsShown()
        if (actual == true or actual == 1) ~= shown then error("Native action-bar decoration visibility was rejected.") end
        texture.appearanceShown, texture.appearanceReady = shown, true
    end
end
local function Foreground(view, scene, repair)
    local art = view.buttonDecorations
    local shown = scene.gryphons ~= "none"
    if shown and not art.foreground then
        art.foreground = UI.CreateContainer(nil, view.frame)
        art.foreground.appearanceInitialLevel = art.foreground:GetFrameLevel()
        art.foreground.appearanceInitialStrata = art.foreground:GetFrameStrata()
    end
    local host = art.foreground
    if not host then return end
    if shown then
        host.appearanceReady = false
        if not host.appearanceMouseConfigured then host:EnableMouse(false); host.appearanceMouseConfigured = true end
        host:SetFrameStrata(scene.strata); host:SetFrameLevel(scene.level)
        host:SetAllPoints(view.frame)
    elseif repair then
        host:SetFrameStrata(host.appearanceCommittedStrata or host.appearanceInitialStrata)
        host:SetFrameLevel(host.appearanceCommittedLevel or host.appearanceInitialLevel)
        if host.appearanceCommittedLevel then host:SetAllPoints(view.frame) else host:ClearAllPoints() end
    end
end
local paintKeys = {"path", "x", "y", "width", "height", "left", "right", "top", "bottom", "anchor", "rotated"}
local function CopyPaint(source, target)
    for _, key in ipairs(paintKeys) do target[key] = source[key] end
end
local function Geometry(texture, frame, paint)
    texture.appearanceReady = false
    if texture:SetTexture(paint.path) == false then error("Native action-bar decoration texture was rejected.") end
    if paint.rotated then
        -- Stock 1.12 TaxiFrame.DrawRouteLine uses the eight-coordinate form
        -- in TL,BL,TR,BR order. Rotate stone uniformly; never stretch its grain.
        texture:SetTexCoord(paint.left, paint.bottom, paint.right, paint.bottom,
            paint.left, paint.top, paint.right, paint.top)
    else texture:SetTexCoord(paint.left, paint.right, paint.top, paint.bottom) end
    texture:ClearAllPoints(); texture:SetPoint(paint.anchor, frame, "TOPLEFT", paint.x, paint.y)
    texture:SetWidth(paint.width); texture:SetHeight(paint.height)
end
local function Piece(view, scene, kind, index, repair, cleanup)
    local art, shown, texture = view.buttonDecorations
    local x, y, width, height, left, right, top, bottom, rotated
    local path = NativeLayout.Texture
    local parent, side = view.frame
    if kind == "tile" then
        shown = scene.slotArtwork and index <= scene.count
        texture = art.panels[index]
        parent = (view.layoutButtons or view.buttons)[index]
        x, y, width, height, left, right, top, bottom = NativeLayout.Tile(scene, index)
    elseif kind == "edge" then
        shown, texture = scene.nativeBorder, art.edges[index]
        x, y, width, height, left, right, top, bottom = NativeLayout.Edge(scene, index)
    elseif kind == "backing" then
        shown, texture = scene.nativeBackground and index <= scene.backingCount, art.backings[index]
        x, y, width, height, left, right, top, bottom, rotated = NativeLayout.Backing(scene, index)
    else
        side = sides[index]
        shown = scene.gryphons == "both" or scene.gryphons == side
        texture, parent, path = art[side], art.foreground, NativeLayout.GryphonTexture
        width, height = scene.gryphonSize, scene.gryphonSize
        left, right, top, bottom = side == "right" and 1 or 0, side == "right" and 0 or 1, 0, 1
    end
    if shown and not texture then
        texture = UI.CreateTexture(parent, nil, side and "OVERLAY" or kind == "tile" and "BORDER" or "BACKGROUND")
        texture.appearancePaint, texture.appearanceCommittedPaint = {}, {}
        if kind == "tile" then art.panels[index] = texture
        elseif kind == "edge" then art.edges[index] = texture
        elseif kind == "backing" then art.backings[index] = texture; if index == 1 then art.backing = texture end
        else art[side] = texture end
    end
    if not texture then return end
    local paint
    if shown then
        paint = texture.appearancePaint
        paint.path, paint.width, paint.height = path, width, height
        paint.left, paint.right, paint.top, paint.bottom = left, right, top, bottom
        paint.rotated = rotated == true
        if side then
            paint.anchor, paint.x, paint.y = side == "left" and "BOTTOMRIGHT" or "BOTTOMLEFT",
                side == "left" and scene.left + scene.gryphonOverlap or scene.right - scene.gryphonOverlap, -scene.gryphonBottom
        else paint.anchor, paint.x, paint.y = "TOPLEFT", x, -y end
    elseif repair and texture.appearanceHasPaint then
        -- Hidden regions can retain a previously painted geometry. Rollback
        -- restores that geometry as well as their visibility.
        paint = texture.appearanceCommittedPaint
    end
    if cleanup then
        local ok, reason = true
        if paint then ok, reason = pcall(Geometry, texture, view.frame, paint) end
        local visible, visibilityReason = pcall(ShowArt, texture, shown, repair)
        if not ok then error(reason) elseif not visible then error(visibilityReason) end
    else
        if paint then Geometry(texture, view.frame, paint) end
        ShowArt(texture, shown, repair)
    end
    if paint and paint ~= texture.appearancePaint then CopyPaint(paint, texture.appearancePaint) end
end
local function CommitPiece(texture)
    if texture and texture.appearancePaint.path then
        CopyPaint(texture.appearancePaint, texture.appearanceCommittedPaint); texture.appearanceHasPaint = true
    end
end
local function CommitPaint(view, scene)
    local art = view.buttonDecorations
    for _, texture in ipairs(art.backings) do CommitPiece(texture) end
    for _, texture in ipairs(art.panels) do CommitPiece(texture) end
    for _, texture in ipairs(art.edges) do CommitPiece(texture) end
    CommitPiece(art.left); CommitPiece(art.right)
    if art.foreground and scene.gryphons ~= "none" then
        art.foreground.appearanceCommittedLevel, art.foreground.appearanceCommittedStrata = scene.level, scene.strata
    end
end
local function DrawScene(view, scene, repair, cleanup)
    -- Cleanup attempts every pooled region even when an individual native
    -- setter fails, retaining the original error for the caller's transaction.
    local failure
    local ok, reason = pcall(Foreground, view, scene, repair)
    if not ok then if not cleanup then error(reason) end; failure = reason end
    if view.buttonDecorations.foreground then
        ok, reason = pcall(ShowArt, view.buttonDecorations.foreground, scene.gryphons ~= "none", repair)
        if not ok then if not cleanup then error(reason) end; failure = failure or reason end
    end
    local art = view.buttonDecorations
    for index = 1, math.max(scene.backingCount, table.getn(art.backings)) do
        ok, reason = pcall(Piece, view, scene, "backing", index, repair, cleanup)
        if not ok then if not cleanup then error(reason) end; failure = failure or reason end
    end
    for index = 1, math.max(scene.count, table.getn(art.panels)) do
        ok, reason = pcall(Piece, view, scene, "tile", index, repair, cleanup)
        if not ok then if not cleanup then error(reason) end; failure = failure or reason end
    end
    for index = 1, 8 do
        ok, reason = pcall(Piece, view, scene, "edge", index, repair, cleanup)
        if not ok then if not cleanup then error(reason) end; failure = failure or reason end
    end
    for index = 1, 2 do
        ok, reason = pcall(Piece, view, scene, "gryphon", index, repair, cleanup)
        if not ok then if not cleanup then error(reason) end; failure = failure or reason end
    end
    return failure == nil, failure
end
local function Decorations(view, style, repair)
    local art = view.buttonDecorations
    local mergedChild = view.mergeHost ~= nil and view.mergeHost ~= view
    if not art and (mergedChild or not style.nativeBackground and not style.nativeBorder and not style.nativeSlotArtwork and style.gryphons == "none") then return end
    local buttons = view.layoutButtons or view.buttons
    if not art then
        art = {panels = {}, edges = {}, backings = {}, current = {}, committed = {}, off = {}}
        view.buttonDecorations = art
        NativeLayout.Resolve({nativeTexture = false, nativeBackground = false, nativeBorder = false, nativeSlotArtwork = false, gryphons = "none"}, table.getn(buttons), art.off)
    end
    local scene
    if mergedChild then scene = NativeLayout.Copy(art.off, art.current)
    else scene = NativeLayout.Resolve(style, table.getn(buttons), art.current) end
    if scene.gryphons ~= "none" then
        scene.strata, scene.level = view.frame:GetFrameStrata(), view.frame:GetFrameLevel()
        for _, button in ipairs(buttons) do
            scene.level = math.max(scene.level, button:GetFrameLevel(), button.cooldown:GetFrameLevel())
        end
        scene.level = scene.level + 1
    else scene.strata, scene.level = nil, nil end
    if not repair and art.ready and NativeLayout.Equal(scene, art.committed) then return end
    -- A client setter can mutate both a region and legacy callback globals
    -- before raising. Restore the last complete decoration scene atomically.
    local savedThis, savedEvent, a1, a2, a3, a4, a5, a6, a7, a8, a9 = this, event, arg1, arg2, arg3, arg4, arg5, arg6, arg7, arg8, arg9
    local previous = art.hasCommitted and art.committed or art.off
    art.ready = false
    local ok, reason = pcall(DrawScene, view, scene, repair, false)
    if not ok then
        local restored, restoreReason = DrawScene(view, previous, true, true)
        art.ready = restored and art.hasCommitted == true
        this, event, arg1, arg2, arg3, arg4, arg5, arg6, arg7, arg8, arg9 = savedThis, savedEvent, a1, a2, a3, a4, a5, a6, a7, a8, a9
        if not restored then reason = tostring(reason) .. "; decoration restoration failed: " .. tostring(restoreReason) end
        error(reason)
    end
    this, event, arg1, arg2, arg3, arg4, arg5, arg6, arg7, arg8, arg9 = savedThis, savedEvent, a1, a2, a3, a4, a5, a6, a7, a8, a9
    CommitPaint(view, scene); NativeLayout.Copy(scene, art.committed); art.ready, art.hasCommitted = true, true
end
function Appearance.ApplyFont(label, choice, size)
    if not label then return end
    if not label.babOriginalFont then
        local face, originalSize, flags = label:GetFont()
        label.babOriginalFont, label.babOriginalSize, label.babOriginalFlags = face, originalSize, flags
        label.babAppliedFont, label.babAppliedSize = face, originalSize
    end
    local face, failure = Bars.Services.TextStyle.Font(choice, label.babOriginalFont)
    if not face then error(failure or "The button font is unavailable.") end
    size = size or label.babOriginalSize
    if label.babAppliedFont ~= face or label.babAppliedSize ~= size then
        label.babAppliedFont, label.babAppliedSize = nil, nil
        local ok = label:SetFont(face, size, label.babOriginalFlags)
        if ok == false then error("The button font was declined.") end
        label.babAppliedFont, label.babAppliedSize = face, size
    end
end
local function ApplyView(view, drawing, repair)
    local style = Style(view, drawing)
    Appearance.ApplyFont(view.title, drawing.titleFont)
    for _, button in ipairs(view.buttons) do
        Appearance.ApplyFont(button.hotkey, drawing.hotkeyFont, drawing.labelFontSize)
        Appearance.ApplyFont(button.count, drawing.countFont, drawing.labelFontSize)
        Appearance.ApplyFont(button.nameLabel, drawing.macroFont, drawing.labelFontSize)
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
function Appearance.ApplyView(view, drawing, repair)
    local savedThis, savedEvent, a1, a2, a3, a4, a5, a6, a7, a8, a9 = this, event, arg1, arg2, arg3, arg4, arg5, arg6, arg7, arg8, arg9
    local ok, reason = pcall(ApplyView, view, drawing, repair)
    this, event, arg1, arg2, arg3, arg4, arg5, arg6, arg7, arg8, arg9 = savedThis, savedEvent, a1, a2, a3, a4, a5, a6, a7, a8, a9
    if not ok then error(reason) end
    return true
end
