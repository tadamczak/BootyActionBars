local Layout = {}
BootyActionBars.Services.NativeDecorationLayout = Layout

Layout.Texture = "Interface\\MainMenuBar\\UI-MainMenuBar-Dwarf"
Layout.GryphonTexture = "Interface\\MainMenuBar\\UI-MainMenuBar-EndCap-Dwarf"
-- The first stock button is 36px at x8,y4; its 42px recess is centred
-- at x26,y22. Atlas menu row 0 occupies y213..256 (stock 1.12 XML).
Layout.SlotUV = {5 / 256, 47 / 256, 213 / 256, 255 / 256}
Layout.BackingUV = {46 / 256, 48 / 256, 218 / 256, 248 / 256}
local keys = {"count", "columns", "buttonSize", "spacing", "nativeTexture", "background", "gryphons",
    "textureScale", "gryphonScale", "width", "height", "tileSize", "step", "left", "top", "right", "bottom",
    "innerLeft", "innerTop", "innerRight", "innerBottom", "padLeft", "padRight", "padTop", "padBottom",
    "gryphonSize", "gryphonOverlap", "gryphonBottom", "level", "strata"}
local function Number(value, fallback, minimum, maximum)
    if type(value) ~= "number" or value - value ~= 0 then return fallback end
    return math.max(minimum, math.min(maximum, value))
end
function Layout.Resolve(drawing, count, target)
    target = target or {}
    drawing = drawing or {}
    count = math.floor(Number(count, 12, 1, 12))
    local columns = math.floor(Number(drawing.columns, count, 1, count))
    local size = Number(drawing.buttonSize, 40, 1, 128)
    local spacing = Number(drawing.spacing, 4, 0, 64)
    local textureScale = Number(drawing.nativeTextureScalePct, 100, 50, 200) / 100
    local gryphonScale = Number(drawing.gryphonScalePct, 100, 50, 200) / 100
    local rows = math.ceil(count / columns)
    local width, height = columns * size + (columns - 1) * spacing, rows * size + (rows - 1) * spacing
    local tileSize = 42 * textureScale
    local extent = drawing.nativeTexture and math.max(0, (tileSize - size) / 2) or 0
    target.count, target.columns, target.buttonSize, target.spacing = count, columns, size, spacing
    target.nativeTexture, target.background = drawing.nativeTexture == true, drawing.nativeTextureBackground ~= false
    target.gryphons, target.textureScale, target.gryphonScale = drawing.gryphons or "none", textureScale, gryphonScale
    target.width, target.height, target.tileSize, target.step = width, height, tileSize, size + spacing
    target.innerLeft, target.innerTop, target.innerRight, target.innerBottom = -extent, -extent, width + extent, height + extent
    target.padLeft, target.padRight = drawing.nativeTexture and 5 * textureScale or 0, drawing.nativeTexture and 9 * textureScale or 0
    target.padTop, target.padBottom = drawing.nativeTexture and 3 * textureScale or 0, drawing.nativeTexture and 4 * textureScale or 0
    target.left, target.top = target.innerLeft - target.padLeft, target.innerTop - target.padTop
    target.right, target.bottom = target.innerRight + target.padRight, target.innerBottom + target.padBottom
    target.gryphonSize, target.gryphonOverlap = 128 * gryphonScale, 32 * gryphonScale
    -- End caps meet the first row even when the grid contains several rows.
    target.gryphonBottom = size + extent + target.padBottom
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
    return column * scene.step + (scene.buttonSize - scene.tileSize) / 2,
        row * scene.step + (scene.buttonSize - scene.tileSize) / 2, scene.tileSize, scene.tileSize
end
function Layout.Edge(scene, index)
    local left, top, right, bottom = scene.left, scene.top, scene.right, scene.bottom
    local innerLeft, innerTop, innerRight, innerBottom = scene.innerLeft, scene.innerTop, scene.innerRight, scene.innerBottom
    -- Native corners, horizontal rails, and end-cap vertical rails. The centre
    -- remains independent so disabling the background leaves only this frame.
    if index == 1 then return left, top, scene.padLeft, scene.padTop, 0, 5 / 256, 213 / 256, 216 / 256
    elseif index == 2 then return innerLeft, top, innerRight - innerLeft, scene.padTop, 5 / 256, 47 / 256, 213 / 256, 216 / 256
    elseif index == 3 then return innerRight, top, scene.padRight, scene.padTop, 246 / 256, 255 / 256, 21 / 256, 24 / 256
    elseif index == 4 then return left, innerTop, scene.padLeft, innerBottom - innerTop, 0, 5 / 256, 216 / 256, 252 / 256
    elseif index == 5 then return innerRight, innerTop, scene.padRight, innerBottom - innerTop, 246 / 256, 255 / 256, 24 / 256, 60 / 256
    elseif index == 6 then return left, innerBottom, scene.padLeft, scene.padBottom, 0, 5 / 256, 252 / 256, 1
    elseif index == 7 then return innerLeft, innerBottom, innerRight - innerLeft, scene.padBottom, 5 / 256, 47 / 256, 252 / 256, 1
    elseif index == 8 then return innerRight, innerBottom, scene.padRight, scene.padBottom, 246 / 256, 255 / 256, 60 / 256, 64 / 256 end
end
