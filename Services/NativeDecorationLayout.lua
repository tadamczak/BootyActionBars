local Layout = {}
BootyActionBars.Services.NativeDecorationLayout = Layout

Layout.Texture = "Interface\\MainMenuBar\\UI-MainMenuBar-Dwarf"
Layout.GryphonTexture = "Interface\\MainMenuBar\\UI-MainMenuBar-EndCap-Dwarf"
-- Verified installed patch.MPQ atlas: a complete four-sided socket, and
-- clean stone that excludes the round pager at x38..47 (MOS331 evidence).
Layout.SlotUV = {47 / 256, 90 / 256, 213 / 256, 1}
Layout.BackingUV = {56 / 256, 248 / 256, 94 / 256, 126 / 256}
Layout.BackingPixels = {192, 32}
Layout.MaxBackingPieces = 693 -- Worst legal 72-slot partial row at 50% body / 200% socket scale; lazy only.
local keys = {"count", "columns", "buttonSize", "spacing", "nativeTexture", "nativeBackground", "nativeBorder", "slotArtwork", "gryphons",
    "textureScale", "buttonScale", "gryphonScale", "width", "height", "tileSize", "socketSize", "step", "left", "top", "right", "bottom",
    "innerLeft", "innerTop", "innerRight", "innerBottom", "padLeft", "padRight", "padTop", "padBottom",
    "gryphonSize", "gryphonOverlap", "gryphonBottom", "level", "strata", "backingLeft", "backingTop",
    "backingWidth", "backingHeight", "backingColumns", "backingRows", "backingCount", "backingRotated",
    "backingStepX", "backingStepY"}
local function Number(value, fallback, minimum, maximum)
    if type(value) ~= "number" or value - value ~= 0 then return fallback end
    return math.max(minimum, math.min(maximum, value))
end
function Layout.ResolveBacking(left, top, width, height, scalePct, target)
    target = target or {}
    local scale = Number(scalePct, 100, 50, 200) / 100
    local tileWidth, tileHeight = Layout.BackingPixels[1] * scale, Layout.BackingPixels[2] * scale
    local columns, rows = math.ceil(width / tileWidth), math.ceil(height / tileHeight)
    local rotatedColumns, rotatedRows = math.ceil(width / tileHeight), math.ceil(height / tileWidth)
    local rotated = rotatedColumns * rotatedRows < columns * rows
    if rotated then tileWidth, tileHeight, columns, rows = tileHeight, tileWidth, rotatedColumns, rotatedRows end
    target.backingLeft, target.backingTop, target.backingWidth, target.backingHeight = left, top, width, height
    target.backingColumns, target.backingRows, target.backingCount = columns, rows, columns * rows
    target.backingRotated, target.backingStepX, target.backingStepY = rotated, tileWidth, tileHeight
    return target
end
function Layout.Backing(scene, index)
    if index < 1 or index > scene.backingCount then return end
    local row = math.floor((index - 1) / scene.backingColumns)
    local column = index - 1 - row * scene.backingColumns
    local offsetX, offsetY = column * scene.backingStepX, row * scene.backingStepY
    local width, height = math.min(scene.backingStepX, scene.backingWidth - offsetX), math.min(scene.backingStepY, scene.backingHeight - offsetY)
    local uv = Layout.BackingUV
    local left, right, top, bottom = uv[1], uv[2], uv[3], uv[4]
    if scene.backingRotated then
        top = bottom - (bottom - top) * width / scene.backingStepX
        right = left + (right - left) * height / scene.backingStepY
    else
        right = left + (right - left) * width / scene.backingStepX
        bottom = top + (bottom - top) * height / scene.backingStepY
    end
    return scene.backingLeft + offsetX, scene.backingTop + offsetY, width, height, left, right, top, bottom, scene.backingRotated
end
function Layout.Resolve(drawing, count, target)
    target = target or {}
    drawing = drawing or {}
    count = math.floor(Number(count, 12, 1, 72))
    local columns = math.floor(Number(drawing.columns, count, 1, count))
    local size = Number(drawing.buttonSize, 40, 24, 64)
    local spacing = Number(drawing.spacing, 4, 0, 20)
    local textureScale = Number(drawing.nativeTextureScalePct, 100, 50, 200) / 100
    local buttonScale = Number(drawing.nativeButtonScalePct, textureScale * 100, 50, 200) / 100
    local gryphonScale = Number(drawing.gryphonScalePct, 100, 50, 200) / 100
    local rows = math.ceil(count / columns)
    local width, height = columns * size + (columns - 1) * spacing, rows * size + (rows - 1) * spacing
    local tileSize = 43 * buttonScale
    -- Fit the complete square uniformly into its own cell. Cropping a larger
    -- sprite would remove the entire six-pixel bevel at common settings.
    local socketSize = math.min(tileSize, size + spacing)
    local slots = drawing.nativeSlotArtwork
    if slots == nil then slots = drawing.nativeTexture == true and drawing.nativeTextureBackground ~= false end
    local extent = slots and math.max(0, (socketSize - size) / 2) or 0
    target.count, target.columns, target.buttonSize, target.spacing = count, columns, size, spacing
    local background, border = drawing.nativeBackground, drawing.nativeBorder
    if background == nil then background = drawing.nativeTexture == true end
    if border == nil then border = drawing.nativeTexture == true end
    target.nativeBackground, target.nativeBorder = background == true, border == true
    target.nativeTexture, target.slotArtwork = background == true or border == true, slots == true
    target.gryphons, target.textureScale, target.gryphonScale = drawing.gryphons or "none", textureScale, gryphonScale
    target.width, target.height, target.tileSize, target.step = width, height, tileSize, size + spacing
    target.socketSize = socketSize
    target.buttonScale = buttonScale
    target.innerLeft, target.innerTop, target.innerRight, target.innerBottom = -extent, -extent, width + extent, height + extent
    local padding = border and 6 * textureScale or 0
    target.padLeft, target.padRight, target.padTop, target.padBottom = padding, padding, padding, padding
    target.left, target.top = target.innerLeft - target.padLeft, target.innerTop - target.padTop
    target.right, target.bottom = target.innerRight + target.padRight, target.innerBottom + target.padBottom
    target.gryphonSize, target.gryphonOverlap = 128 * gryphonScale, 32 * gryphonScale
    -- End caps meet the first row even when the grid contains several rows.
    target.gryphonBottom = size + extent + target.padBottom
    Layout.ResolveBacking(target.innerLeft, target.innerTop, target.innerRight - target.innerLeft,
        target.innerBottom - target.innerTop, textureScale * 100, target)
    if not target.nativeBackground then target.backingCount = 0 end
    return target
end
function Layout.Copy(source, target)
    target = target or {}
    for _, key in ipairs(keys) do target[key] = source[key] end
    return target
end
function Layout.Equal(left, right)
    if not left or not right then return false end
    for _, key in ipairs(keys) do if left[key] ~= right[key] then return false end end
    return true
end
function Layout.Tile(scene, index)
    if index < 1 or index > scene.count then return end
    local row = math.floor((index - 1) / scene.columns)
    local column = index - 1 - row * scene.columns
    local uv = Layout.SlotUV
    return column * scene.step + (scene.buttonSize - scene.socketSize) / 2,
        row * scene.step + (scene.buttonSize - scene.socketSize) / 2, scene.socketSize, scene.socketSize,
        uv[1], uv[2], uv[3], uv[4]
end
function Layout.Edge(scene, index)
    local left, top, right, bottom = scene.left, scene.top, scene.right, scene.bottom
    local innerLeft, innerTop, innerRight, innerBottom = scene.innerLeft, scene.innerTop, scene.innerRight, scene.innerBottom
    -- Coherent six-pixel bevel from the same complete native socket. No
    -- neighbouring socket connector, pager, or bag engraving enters the frame.
    if index == 1 then return left, top, scene.padLeft, scene.padTop, 47 / 256, 53 / 256, 213 / 256, 219 / 256
    elseif index == 2 then return innerLeft, top, innerRight - innerLeft, scene.padTop, 53 / 256, 84 / 256, 213 / 256, 219 / 256
    elseif index == 3 then return innerRight, top, scene.padRight, scene.padTop, 84 / 256, 90 / 256, 213 / 256, 219 / 256
    elseif index == 4 then return left, innerTop, scene.padLeft, innerBottom - innerTop, 47 / 256, 53 / 256, 219 / 256, 250 / 256
    elseif index == 5 then return innerRight, innerTop, scene.padRight, innerBottom - innerTop, 84 / 256, 90 / 256, 219 / 256, 250 / 256
    elseif index == 6 then return left, innerBottom, scene.padLeft, scene.padBottom, 47 / 256, 53 / 256, 250 / 256, 1
    elseif index == 7 then return innerLeft, innerBottom, innerRight - innerLeft, scene.padBottom, 53 / 256, 84 / 256, 250 / 256, 1
    elseif index == 8 then return innerRight, innerBottom, scene.padRight, scene.padBottom, 84 / 256, 90 / 256, 250 / 256, 1 end
end
