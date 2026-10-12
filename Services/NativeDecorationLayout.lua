local Layout = {}
BootyActionBars.Services.NativeDecorationLayout = Layout

Layout.Texture = "Interface\\MainMenuBar\\UI-MainMenuBar-Dwarf"
Layout.GryphonTexture = "Interface\\MainMenuBar\\UI-MainMenuBar-EndCap-Dwarf"
-- Verified installed patch.MPQ atlas: a complete four-sided socket, and
-- clean stone that excludes the round pager at x38..47 (MOS331 evidence).
Layout.SlotUV = {47 / 256, 90 / 256, 213 / 256, 1}
Layout.BackingUV = {56 / 256, 248 / 256, 94 / 256, 126 / 256}
Layout.BackingPixels = {192, 32}
Layout.MaxBackingPieces = 4608 -- Expanded range: measured worst is 4389 pieces for 120 slots; lazy pooled regions.
local keys = {"barBorderTexture", "count", "columns", "buttonSize", "spacing", "nativeTexture", "nativeBackground", "nativeBorder", "slotArtwork", "gryphons",
    "textureScale", "buttonScale", "gryphonScale", "width", "height", "tileSize", "socketSize", "step", "left", "top", "right", "bottom",
    "innerLeft", "innerTop", "innerRight", "innerBottom", "padLeft", "padRight", "padTop", "padBottom",
    "gryphonSize", "gryphonOverlap", "gryphonBottom", "level", "strata", "backingLeft", "backingTop",
    "backingWidth", "backingHeight", "backingColumns", "backingRows", "backingCount", "backingRotated",
    "backingStepX", "backingStepY", "gryphonLeftX", "gryphonLeftY", "gryphonRightX", "gryphonRightY"}
local function Number(value, fallback, minimum, maximum)
    if type(value) ~= "number" or value - value ~= 0 then return fallback end
    return math.max(minimum, math.min(maximum, value))
end
Layout.OrnamentKeys = {"sideOrnamentLeft","sideOrnamentRight","topOrnament", "topOrnamentScalePct", "topOrnamentX", "topOrnamentY",
    "bottomOrnament", "bottomOrnamentScalePct", "bottomOrnamentX", "bottomOrnamentY"}
for _, key in ipairs(Layout.OrnamentKeys) do table.insert(keys, key) end
local ornamentPrefixes = {"topOrnament", "bottomOrnament"}
function Layout.ResolveOrnaments(drawing, target)
    target.barBorderTexture=drawing.barBorderTexture or "native"
    target.sideOrnamentLeft,target.sideOrnamentRight=drawing.sideOrnamentLeft,drawing.sideOrnamentRight
    for _, prefix in ipairs(ornamentPrefixes) do
        target[prefix] = drawing[prefix] or "none"
        target[prefix .. "ScalePct"] = Number(drawing[prefix .. "ScalePct"],100,25,500)
        target[prefix .. "X"] = Number(drawing[prefix .. "X"],0,-1024,1024)
        target[prefix .. "Y"] = Number(drawing[prefix .. "Y"],0,-1024,1024)
    end
end
function Layout.OrnamentVisible(scene, index)
    if index == 3 then return scene.topOrnament ~= nil and scene.topOrnament ~= "none" end
    if index == 4 then return scene.bottomOrnament ~= nil and scene.bottomOrnament ~= "none" end
    local kind = scene.gryphons or "none"
    if kind == "none" then return false end
    if index==1 and scene.sideOrnamentLeft~=nil then return scene.sideOrnamentLeft end
    if index==2 and scene.sideOrnamentRight~=nil then return scene.sideOrnamentRight end
    if kind == "left" then return index == 1 end
    if kind == "right" then return index == 2 end
    return index == 1 or index == 2
end
function Layout.OrnamentCount(scene)
    local count=0
    for index=1,4 do if Layout.OrnamentVisible(scene,index) then count=count+1 end end
    return count
end
function Layout.OrnamentIndex(scene, ordinal)
    for index=1,4 do
        if Layout.OrnamentVisible(scene,index) then ordinal=ordinal-1;if ordinal==0 then return index end end
    end
end
function Layout.HasOrnaments(scene) return Layout.OrnamentCount(scene)>0 end
function Layout.Ornament(scene, index)
    if not Layout.OrnamentVisible(scene,index) then return end
    local side=index==1 and "left" or "right"
    local native=scene.gryphons=="both" or scene.gryphons=="left" or scene.gryphons=="right"
    local width,height,x,y,left,right,top,bottom,path
    if index<=2 and native then
        width,height=scene.gryphonSize,scene.gryphonSize
        x=index==1 and scene.left-width+scene.gryphonOverlap or scene.right-scene.gryphonOverlap
        y=scene.gryphonBottom-height
        left,right,top,bottom=index==1 and 0 or 1,index==1 and 1 or 0,0,1
        path=Layout.GryphonTexture
    else
        local catalog=BootyActionBars.Services.BarConfig.Ornaments
        local definition,sprite,scale
        if index<=2 then
            definition=catalog.side[scene.gryphons]
            sprite=catalog.sprites[definition[side]]
            scale=scene.gryphonSize/128
            height=definition.height*scale;width=height*sprite.width/sprite.height
            x=index==1 and scene.left-width*.8 or scene.right-width*.2
            y=scene.gryphonBottom-height
        else
            local prefix=index==3 and "topOrnament" or "bottomOrnament"
            definition=catalog.centre[scene[prefix]];sprite=catalog.sprites[definition.sprite]
            scale=scene[prefix .. "ScalePct"]/100
            width=definition.width*scale;height=width*sprite.height/sprite.width
            x=(scene.left+scene.right-width)/2+scene[prefix .. "X"]
            y=(index==3 and scene.top-height+8*scale or scene.bottom-8*scale)-scene[prefix .. "Y"]
        end
        path,left,right,top,bottom=sprite.path,0,sprite.right,0,sprite.bottom
        if index==1 and definition.mirrorLeft or index==2 and definition.mirrorRight then left,right=right,left end
    end
    if index<=2 then
        x=x+(index==1 and scene.gryphonLeftX or scene.gryphonRightX)
        y=y-(index==1 and scene.gryphonLeftY or scene.gryphonRightY)
    end
    return path,x,y,width,height,left,right,top,bottom
end
function Layout.ResolveBacking(left, top, width, height, scalePct, target)
    target = target or {}
    local scale = Number(scalePct, 100, 25, 500) / 100
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
    count = math.floor(Number(count, 12, 1, 120))
    local columns = math.floor(Number(drawing.columns, count, 1, count))
    local size = Number(drawing.buttonSize, 40, 24, 64)
    local spacing = Number(drawing.spacing, 4, 0, 20)
    local textureScale = Number(drawing.nativeTextureScalePct, 100, 25, 500) / 100
    local borderScale = Number(drawing.nativeBorderScalePct, textureScale * 100, 25, 500) / 100
    local buttonScale = Number(drawing.nativeButtonScalePct, textureScale * 100, 25, 500) / 100
    local gryphonScale = Number(drawing.gryphonScalePct, 100, 25, 500) / 100
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
    local padding = border and 6 * borderScale or 0
    target.padLeft, target.padRight, target.padTop, target.padBottom = padding, padding, padding, padding
    target.left, target.top = target.innerLeft - target.padLeft, target.innerTop - target.padTop
    target.right, target.bottom = target.innerRight + target.padRight, target.innerBottom + target.padBottom
    target.gryphonSize, target.gryphonOverlap = 128 * gryphonScale, 32 * gryphonScale
    target.gryphonLeftX, target.gryphonLeftY = drawing.gryphonLeftX or 0, drawing.gryphonLeftY or 0
    target.gryphonRightX, target.gryphonRightY = drawing.gryphonRightX or 0, drawing.gryphonRightY or 0
    -- End caps meet the first row even when the grid contains several rows.
    target.gryphonBottom = size + extent + target.padBottom
    Layout.ResolveOrnaments(drawing,target)
    Layout.ResolveBacking(target.innerLeft, target.innerTop, target.innerRight - target.innerLeft,
        target.innerBottom - target.innerTop, textureScale * 100, target)
    if not target.nativeBackground then target.backingCount = 0 end
    return target
end
-- Bounds describe the complete visible merge group in the primary's units.
-- Background/border/end caps have one owner; each member retains its sockets.
function Layout.ExtendGroup(scene, group, scalePct, background)
    if not group then return end
    scene.innerLeft,scene.innerTop=math.min(scene.innerLeft,group.left),math.min(scene.innerTop,group.top)
    scene.innerRight,scene.innerBottom=math.max(scene.innerRight,group.left+group.width),math.max(scene.innerBottom,group.top+group.height)
    scene.left,scene.top=scene.innerLeft-scene.padLeft,scene.innerTop-scene.padTop
    scene.right,scene.bottom=scene.innerRight+scene.padRight,scene.innerBottom+scene.padBottom
    scene.gryphonBottom=scene.innerTop+(scene.buttonSize or scene.cellHeight)+(scene.padBottom or 0)
    Layout.ResolveBacking(scene.innerLeft,scene.innerTop,scene.innerRight-scene.innerLeft,scene.innerBottom-scene.innerTop,scalePct,scene)
    if not background then scene.backingCount=0 end
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
    local custom = BootyLib.UI.Components.ExtractedTextures.actionBorders[scene.barBorderTexture]
    if custom and scene.padTop>0 then
        local part=custom.parts[index]
        local x,y,w,h
        if index==1 then x,y,w,h=left,top,scene.padLeft,scene.padTop
        elseif index==2 then x,y,w,h=innerLeft,top,innerRight-innerLeft,scene.padTop
        elseif index==3 then x,y,w,h=innerRight,top,scene.padRight,scene.padTop
        elseif index==4 then x,y,w,h=left,innerTop,scene.padLeft,innerBottom-innerTop
        elseif index==5 then x,y,w,h=innerRight,innerTop,scene.padRight,innerBottom-innerTop
        elseif index==6 then x,y,w,h=left,innerBottom,scene.padLeft,scene.padBottom
        elseif index==7 then x,y,w,h=innerLeft,innerBottom,innerRight-innerLeft,scene.padBottom
        elseif index==8 then x,y,w,h=innerRight,innerBottom,scene.padRight,scene.padBottom end
        local u,v=1,1
        if index==2 or index==7 then u=w/(part.width*h/part.height)
        elseif index==4 or index==5 then v=h/(part.height*w/part.width) end
        return x,y,w,h,0,u,0,v,part.path
    end
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
