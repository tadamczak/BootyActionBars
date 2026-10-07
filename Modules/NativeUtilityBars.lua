local Bars = BootyActionBars
local Utility = {}
Bars.Modules.NativeUtilityBars = Utility
local UI, Layout = Bars.UI.Components, Bars.Services.UtilityLayout
local state = {active = false, nativeHidden = false, editing = false, showAnchors = false, groups = {}}
local parentLease, failureObserver, notifyingFailure
local ApplyGroup, EditGroup, ReleaseGroups, Notify, Commit
local DragStartScript, DragStopScript, DragHiddenScript

local function Enabled(value) return value ~= nil and value ~= false and value ~= 0 end
local function Global(name) return type(getglobal) == "function" and getglobal(name) or _G[name] end
local function Failure(message) if not state.failure then state.failure = tostring(message) end end
local function Call(callback, owner, first, second, third, fourth, fifth)
    local previousThis, previousEvent, previousArg = this, event, arg1
    local ok, failure = pcall(callback, owner, first, second, third, fourth, fifth)
    this, event, arg1 = previousThis, previousEvent, previousArg
    if not ok then Failure(failure) end
    return ok, failure
end
local function Field(frame, name) return frame[name] end
local function Assign(frame, name, value) frame[name] = value end
local function RestoreSlot(record, name, original, guard, script)
    local getter = script and record.getScript or Field
    local inspected, current = Call(getter, record.frame, name)
    if not inspected then return false end
    if current == original then return true end
    if current ~= guard then Failure("Native " .. record.name .. " " .. name .. " has another owner."); return false end
    local restored
    if script then restored = Call(record.setScript, record.frame, name, original)
    else restored = Call(Assign, record.frame, name, original) end
    local read, actual = Call(getter, record.frame, name)
    if read and actual ~= original then Failure("Native " .. record.name .. " " .. name .. " restoration was declined.") end
    return restored and read and actual == original
end
local function Points(frame)
    local points = {}
    for index = 1, frame:GetNumPoints() do
        local point, owner, relative, x, y = frame:GetPoint(index)
        points[index] = {point, owner, relative, x, y}
    end
    return points
end
local function Remember(record, point, owner, relative, x, y)
    local index = record.pointCount + 1
    for old = 1, record.pointCount do if record.points[old][1] == point then index = old; break end end
    local value = record.points[index]
    if not value then value = {}; record.points[index] = value end
    value[1], value[2], value[3], value[4], value[5] = point, owner, relative, x, y
    record.pointCount = math.max(record.pointCount, index)
end
local function Capture(frame, name, target, anchored)
    for _, method in ipairs({"GetParent", "SetParent", "GetNumPoints", "GetPoint", "SetPoint", "ClearAllPoints",
        "GetWidth", "GetHeight", "GetScale", "SetScale", "SetWidth", "SetHeight"}) do
        if type(frame[method]) ~= "function" then error("Native " .. name .. " lacks " .. method .. ".") end
    end
    local record = {frame = frame, name = name, parent = frame:GetParent(), target = target,
        points = Points(frame), width = frame:GetWidth(), height = frame:GetHeight(), scale = frame:GetScale(),
        setParent = frame.SetParent, setPoint = frame.SetPoint, clear = frame.ClearAllPoints,
        setWidth = frame.SetWidth, setHeight = frame.SetHeight, setScale = frame.SetScale, anchored = anchored}
    record.pointCount = table.getn(record.points)
    record.pointGuard = function(owner, point, relative, relativePoint, x, y)
        if not record.enabled or owner ~= record.frame then return record.setPoint(owner, point, relative, relativePoint, x, y) end
        Remember(record, point, relative, relativePoint, x, y)
    end
    record.clearGuard = function(owner)
        if not record.enabled or owner ~= record.frame then return record.clear(owner) end
        record.pointCount = 0
    end
    if name == "KeyRingButton" then
        for _, method in ipairs({"Show", "Hide", "IsShown", "GetScript", "SetScript"}) do
            if type(frame[method]) ~= "function" then error("Native keyring lacks " .. method .. ".") end
        end
        record.show, record.hide, record.isShown = frame.Show, frame.Hide, frame.IsShown
        record.getScript, record.setScript, record.onHide = frame.GetScript, frame.SetScript, frame:GetScript("OnHide")
        record.latestShown = Enabled(frame:IsShown())
        record.showGuard = function(owner)
            if owner ~= record.frame then return record.show(owner) end
            if record.visibilityEnabled then record.latestShown = true end
            return record.show(owner)
        end
        record.hideGuard = function(owner)
            if owner ~= record.frame or not record.visibilityEnabled then return record.hide(owner) end
            record.latestShown = false
        end
        record.onHideGuard = function()
            if not record.visibilityEnabled then if record.onHide then return record.onHide() end; return end
            if record.revealing then return end
            record.latestShown, record.revealing = false, true
            local previousThis, previousEvent, previousArg = this, event, arg1
            local ok, failure = pcall(record.show, record.frame)
            if ok then
                local read, shown = pcall(record.isShown, record.frame)
                if not read then ok, failure = false, shown
                elseif not Enabled(shown) then ok, failure = false, "Native keyring rejected its visibility lease." end
            end
            record.revealing = nil
            if not ok then
                local initial = tostring(failure)
                Utility.Release(); state.failure = initial
                Notify(initial)
            end
            this, event, arg1 = previousThis, previousEvent, previousArg
            if not ok then error(state.failure or failure, 0) end
        end
    end
    return record
end
local function Restore(record)
    record.enabled = false
    local frame = record.frame
    local restored = true
    local anchorsOwned = not record.anchored or ((frame.SetPoint == record.pointGuard or frame.SetPoint == record.setPoint)
        and (frame.ClearAllPoints == record.clearGuard or frame.ClearAllPoints == record.clear))
    if not anchorsOwned then record.foreignAnchors = true end
    if record.visibilityTouched then
        record.visibilityEnabled = false
        if not RestoreSlot(record, "Show", record.show, record.showGuard) then restored = false end
        if not RestoreSlot(record, "Hide", record.hide, record.hideGuard) then restored = false end
        if not RestoreSlot(record, "OnHide", record.onHide, record.onHideGuard, true) then restored = false end
    end
    if record.anchored then
        if not RestoreSlot(record, "SetPoint", record.setPoint, record.pointGuard) then restored = false end
        if not RestoreSlot(record, "ClearAllPoints", record.clear, record.clearGuard) then restored = false end
    end
    local parent = frame:GetParent()
    if parent ~= record.target and parent ~= record.parent then
        Failure("Native " .. record.name .. " has another parent owner.")
        return false
    end
    if not Call(record.setParent, frame, record.parent) then restored = false end
    -- Only our parent and anchor writes are leased. Native size/scale updates
    -- continue to own their fields; a foreign anchor must keep its geometry.
    if record.anchored and not record.foreignAnchors then
        if not Call(record.clear, frame) then restored = false end
        for index = 1, record.pointCount do
            local point = record.points[index]
            if not Call(record.setPoint, frame, point[1], point[2], point[3], point[4], point[5]) then restored = false end
        end
    end
    if record.visibilityTouched then
        if not Call(record.latestShown and record.show or record.hide, frame) then restored = false end
        record.visibilityTouched = not restored
    end
    record.touched = not restored
    return restored
end
local artworkFields = Layout.ArtworkFields
local paintFields = {"path", "x", "y", "width", "height", "left", "right", "top", "bottom", "rotated"}
local function CopyFields(source, target, fields)
    for _, key in ipairs(fields) do target[key] = source[key] end
end
local function SameArtwork(first, second)
    for _, key in ipairs(artworkFields) do if first[key] ~= second[key] then return false end end
    return true
end
local function ArtworkVisibility(texture, shown, repair)
    if not repair and texture.utilityArtReady and texture.utilityArtShown == shown then return end
    texture.utilityArtReady = false
    if shown then texture:Show() else texture:Hide() end
    if Enabled(texture:IsShown()) ~= shown then error("Native utility artwork visibility was declined.") end
    texture.utilityArtShown, texture.utilityArtReady = shown, true
end
local function ArtworkGeometry(texture, frame, paint)
    texture.utilityArtReady = false
    texture.utilityArtPaintComplete = false
    if texture:SetTexture(paint.path) == false then error("Native utility artwork texture is unavailable.") end
    local coordinates
    if paint.rotated then
        coordinates = texture:SetTexCoord(paint.left, paint.bottom, paint.right, paint.bottom,
            paint.left, paint.top, paint.right, paint.top)
    else coordinates = texture:SetTexCoord(paint.left, paint.right, paint.top, paint.bottom) end
    if coordinates == false then error("Native utility artwork coordinates were declined.") end
    if texture:ClearAllPoints() == false or texture:SetPoint("TOPLEFT", frame, "TOPLEFT", paint.x, -paint.y) == false then
        error("Native utility artwork anchors were declined.")
    end
    if texture:SetWidth(paint.width) == false or texture:SetHeight(paint.height) == false then
        error("Native utility artwork dimensions were declined.")
    end
end
local function ArtworkPiece(group, scene, index, repair, cleanup)
    local art, shown = group.artwork, scene.shown and index <= scene.count
    local texture = art.pieces[index]
    if shown and not texture then
        texture = UI.CreateTexture(group.frame, nil, "BACKGROUND")
        texture.utilityArtPaint, texture.utilityArtCommittedPaint = {}, {}
        art.pieces[index] = texture
    end
    if not texture then return end
    local paint
    if shown then
        paint = texture.utilityArtPaint
        Layout.ArtworkPiece(scene, index, paint)
    elseif repair and texture.utilityArtHasPaint then paint = texture.utilityArtCommittedPaint end
    if cleanup then
        local ok, reason = true
        if paint then ok, reason = pcall(ArtworkGeometry, texture, group.frame, paint) end
        local visible, failure = pcall(ArtworkVisibility, texture, shown, true)
        if not ok then error(reason) elseif not visible then error(failure) end
    else
        if paint then ArtworkGeometry(texture, group.frame, paint) end
        ArtworkVisibility(texture, shown, repair)
    end
    if paint and paint ~= texture.utilityArtPaint then CopyFields(paint, texture.utilityArtPaint, paintFields) end
    if paint then texture.utilityArtPaintComplete = true end
end
local function DrawArtwork(group, scene, repair, cleanup)
    local failure
    for index = 1, math.max(scene.count or 0, table.getn(group.artwork.pieces)) do
        local ok, reason = pcall(ArtworkPiece, group, scene, index, repair, cleanup)
        if not ok then if not cleanup then error(reason) end; failure = failure or reason end
    end
    return failure == nil, failure
end
local function HideArtwork(group)
    local art = group.artwork
    if not art then return end
    local savedThis, savedEvent, a1, a2, a3, a4, a5, a6, a7, a8, a9 = this, event, arg1, arg2, arg3, arg4, arg5, arg6, arg7, arg8, arg9
    art.ready = false
    for _, texture in ipairs(art.pieces) do
        Call(ArtworkVisibility, texture, false, false)
    end
    this, event, arg1, arg2, arg3, arg4, arg5, arg6, arg7, arg8, arg9 = savedThis, savedEvent, a1, a2, a3, a4, a5, a6, a7, a8, a9
end
local function PaintArtwork(group, wanted)
    local art = group.artwork
    local shown = wanted and group.preferences.nativeTexture == true
    if not art and not shown then return end
    if not art then
        art = {pieces = {}, current = {}, committed = {}, off = {id = group.id, shown = false, count = 0}}
        group.artwork = art
    end
    local scene, failure = Layout.ResolveArtwork(group.id, group.preferences, group.width, group.height, shown, art.current)
    if not scene then error(failure) end
    if art.ready and SameArtwork(scene, art.committed) then return end
    local previous = art.hasCommitted and art.committed or art.off
    local savedThis, savedEvent, a1, a2, a3, a4, a5, a6, a7, a8, a9 = this, event, arg1, arg2, arg3, arg4, arg5, arg6, arg7, arg8, arg9
    art.ready = false
    local ok, reason = pcall(DrawArtwork, group, scene, false, false)
    if not ok then
        local restored, failure = DrawArtwork(group, previous, true, true)
        art.ready = restored and art.hasCommitted == true
        this, event, arg1, arg2, arg3, arg4, arg5, arg6, arg7, arg8, arg9 = savedThis, savedEvent, a1, a2, a3, a4, a5, a6, a7, a8, a9
        if not restored then reason = tostring(reason) .. "; utility artwork restoration failed: " .. tostring(failure) end
        error(reason)
    end
    this, event, arg1, arg2, arg3, arg4, arg5, arg6, arg7, arg8, arg9 = savedThis, savedEvent, a1, a2, a3, a4, a5, a6, a7, a8, a9
    for _, texture in ipairs(art.pieces) do
        if texture.utilityArtPaintComplete and texture.utilityArtPaint.path then
            CopyFields(texture.utilityArtPaint, texture.utilityArtCommittedPaint, paintFields); texture.utilityArtHasPaint = true
        end
    end
    CopyFields(scene, art.committed, artworkFields); art.ready, art.hasCommitted = true, true
end
local function ReleaseGroup(group)
    if group.drag then Call(group.frame.StopMovingOrSizing, group.frame); group.drag = nil end
    if group.handle then Call(group.handle.Hide, group.handle) end
    HideArtwork(group)
    if group.records then
        for _, record in ipairs(group.records) do
            if record.touched then
                local ok, failure = pcall(Restore, record)
                if not ok then Failure(failure) end
            end
        end
    end
    group.leased = false
    Call(group.frame.Hide, group.frame)
end
ReleaseGroups = function()
    for _, id in ipairs(Layout.Keys) do
        local group = state.groups[id]
        if group then
            local ok, failure = pcall(ReleaseGroup, group)
            if not ok then Failure(failure) end
        end
    end
end
Notify = function(failure)
    if not failureObserver or notifyingFailure then return end
    notifyingFailure = true
    local previousThis, previousEvent, previousArg = this, event, arg1
    local ran, ok, reason = pcall(failureObserver, failure)
    this, event, arg1 = previousThis, previousEvent, previousArg
    notifyingFailure = nil
    if not ran then reason = ok end
    if not ran or ok == false then state.failure = tostring(failure) .. " Failure observer: " .. tostring(reason) end
end
local function Parent(wanted)
    if not wanted then
        local record = parentLease
        if not record or not record.touched then return true end
        record.enabled = false
        local frame = record.frame
        local restored = true
        if not RestoreSlot(record, "Show", record.show, record.guard) then restored = false end
        if not RestoreSlot(record, "Hide", record.hide, record.hideGuard) then restored = false end
        if not RestoreSlot(record, "OnShow", record.originalOnShow, record.onShow, true) then restored = false end
        if not Call(record.shown and record.show or record.hide, frame) then restored = false end
        local read, visible = Call(record.isShown, frame)
        if not read then restored = false
        elseif Enabled(visible) ~= record.shown then Failure("Native menu visibility restoration was declined."); restored = false end
        record.touched = not restored
        return restored, state.failure
    end
    if parentLease and parentLease.touched and not parentLease.enabled then
        local restored, failure = Parent(false)
        if not restored then return false, failure end
    end
    if parentLease and parentLease.enabled then
        if parentLease.frame.Show ~= parentLease.guard or parentLease.frame.Hide ~= parentLease.hideGuard or
            parentLease.getScript(parentLease.frame, "OnShow") ~= parentLease.onShow then
            return false, "Native menu visibility has another owner."
        end
        return not Enabled(parentLease.isShown(parentLease.frame)), "The native menu visibility lease was declined."
    end
    local frame = Global("MainMenuBar")
    if not frame then return false, "Native MainMenuBar is unavailable." end
    for _, method in ipairs({"Show", "Hide", "IsShown", "GetScript", "SetScript"}) do
        if type(frame[method]) ~= "function" then return false, "Native MainMenuBar lacks " .. method .. "." end
    end
    local record = {frame = frame, name = "MainMenuBar", show = frame.Show, hide = frame.Hide, isShown = frame.IsShown,
        getScript = frame.GetScript, setScript = frame.SetScript, originalOnShow = frame:GetScript("OnShow"), shown = Enabled(frame:IsShown())}
    record.guard = function(owner)
        if owner ~= record.frame or not record.enabled then return record.show(owner) end
        record.shown = true
    end
    record.hideGuard = function(owner)
        if owner == record.frame and record.enabled then record.shown = false end
        return record.hide(owner)
    end
    record.onShow = function()
        if not record.enabled then if record.originalOnShow then return record.originalOnShow() end; return end
        if record.hiding then return end
        record.shown = true
        record.hiding = true
        local previousThis, previousEvent, previousArg = this, event, arg1
        local ok, failure = pcall(record.hide, record.frame)
        if ok then
            local read, shown = pcall(record.isShown, record.frame)
            if not read then ok, failure = false, shown
            elseif Enabled(shown) then ok, failure = false, "The native menu rejected its visibility lease." end
        end
        record.hiding = nil
        if not ok then
            local initial = tostring(failure)
            Utility.Release(); state.failure = initial
            Notify(initial)
        end
        this, event, arg1 = previousThis, previousEvent, previousArg
        if not ok then error(state.failure or failure, 0) end
    end
    parentLease, record.enabled, record.touched = record, true, true
    frame.Show, frame.Hide = record.guard, record.hideGuard; record.setScript(frame, "OnShow", record.onShow)
    record.hide(frame)
    if frame.Show ~= record.guard or frame.Hide ~= record.hideGuard or record.getScript(frame, "OnShow") ~= record.onShow or Enabled(record.isShown(frame)) then
        return false, "The native menu rejected its visibility lease."
    end
    return true
end
local function Ensure(id)
    local group = state.groups[id]
    if group then return group end
    local frame = UI.CreateContainer("BootyActionBarsUtility_" .. id, UIParent)
    group = {id = id, frame = frame}; state.groups[id] = group
    frame:Hide(); frame:SetMovable(true)
    if frame.SetDontSavePosition then frame:SetDontSavePosition(true) end
    if frame.SetUserPlaced then frame:SetUserPlaced(false) end
    if frame.SetClampedToScreen then frame:SetClampedToScreen(false) end
    frame:SetFrameStrata("LOW")
    return group
end
local function Geometry(group, preferences)
    local definition = Layout.Definition(group.id)
    local columns = math.min(preferences.columns, definition.count)
    local rows = math.ceil(definition.count / columns)
    local width = columns * definition.width + math.max(0, columns - 1) * preferences.spacing
    local height = rows * definition.height + math.max(0, rows - 1) * preferences.spacing
    local screenWidth, screenHeight = UI.GetFrameSpan(UIParent)
    local drawing, failure = Layout.Resolve(preferences, width, height, screenWidth, screenHeight)
    if not drawing then error(failure) end
    group.width, group.height = width, height
    group.frame:SetWidth(width); group.frame:SetHeight(height); group.frame:SetScale(drawing.scale)
    group.frame:ClearAllPoints(); group.frame:SetPoint("CENTER", UIParent, "CENTER", drawing.anchorX, drawing.anchorY)
    group.preferences = preferences
end
local function Lease(group)
    if group.leased then
        for _, record in ipairs(group.records) do
            if record.frame:GetParent() ~= record.target or record.anchored and
                (record.frame.SetPoint ~= record.pointGuard or record.frame.ClearAllPoints ~= record.clearGuard) then
                error("Native " .. record.name .. " has another layout owner.")
            end
            if record.visibilityTouched and (record.frame.Show ~= record.showGuard or record.frame.Hide ~= record.hideGuard or
                record.getScript(record.frame, "OnHide") ~= record.onHideGuard) then
                error("Native " .. record.name .. " has another visibility owner.")
            end
        end
        return
    end
    if group.records then
        for _, record in ipairs(group.records) do
            if record.touched then
                ReleaseGroup(group)
                break
            end
        end
        for _, record in ipairs(group.records) do
            if record.touched then error("Native utility restoration is still incomplete.") end
        end
    end
    local definition, records = Layout.Definition(group.id), {}
    -- Validate every target before moving the first native control.
    for _, name in ipairs(definition.names) do
        local frame = Global(name)
        if not frame then
            group.available, group.failure = false, "Native " .. name .. " is unavailable."
            error(group.failure)
        end
        records[table.getn(records) + 1] = Capture(frame, name, group.frame, name ~= "ExhaustionTick")
    end
    group.records = records
    for _, record in ipairs(records) do
        if record.name == "ExhaustionTick" then record.target = records[1].frame end
        record.touched = true
        record.setParent(record.frame, record.target)
        if record.anchored then
            record.enabled = true
            record.frame.SetPoint, record.frame.ClearAllPoints = record.pointGuard, record.clearGuard
        end
        if record.name == "KeyRingButton" then
            record.visibilityTouched, record.visibilityEnabled = true, true
            record.frame.Show, record.frame.Hide = record.showGuard, record.hideGuard
            record.setScript(record.frame, "OnHide", record.onHideGuard)
            record.show(record.frame)
            if not Enabled(record.isShown(record.frame)) then error("Native keyring rejected its visibility lease.") end
        end
    end
    group.leased, group.available, group.failure = true, true, nil
end
local function Position(group)
    local definition, preferences = Layout.Definition(group.id), group.preferences
    for index, record in ipairs(group.records) do
        if record.anchored then
            local x, y = 0, 0
            if group.id == "experience" then y = index == 2 and -13 or 0
            elseif group.id == "latency" then x = 4
            else
                local row = math.floor((index - 1) / preferences.columns)
                local column = index - 1 - row * preferences.columns
                x, y = column * (definition.width + preferences.spacing), -row * (definition.height + preferences.spacing)
            end
            record.clear(record.frame); record.setPoint(record.frame, "TOPLEFT", group.frame, "TOPLEFT", x, y)
        end
    end
end
local function CancelDrag(group)
    if not group.drag then return end
    group.drag = nil; group.frame:StopMovingOrSizing()
    local preferences, failure = Layout.Read(state.store and state.store.utilityLayouts, group.id)
    if not preferences then error(failure) end
    Geometry(group, preferences)
end
local function DragStart()
    local group = this.utilityGroup
    if not group or not state.editing or group.drag then return end
    local screenWidth, screenHeight = UI.GetFrameSpan(UIParent)
    group.drag = {store = state.store, saved = state.store.utilityLayouts,
        original = state.store.utilityLayouts and state.store.utilityLayouts[group.id],
        snapshot = state.store.utilityLayouts and assert(Layout.Copy(state.store.utilityLayouts)),
        width = screenWidth, height = screenHeight, scale = UIParent:GetEffectiveScale()}
    group.frame:StartMoving()
end
local function DragStop()
    local group = this.utilityGroup
    if not group or not group.drag then return end
    group.frame:StopMovingOrSizing()
    local drag = group.drag
    local width, height = UI.GetFrameSpan(UIParent)
    if not state.editing or drag.store ~= state.store or drag.saved ~= state.store.utilityLayouts or
        drag.original ~= (state.store.utilityLayouts and state.store.utilityLayouts[group.id]) or
        not Layout.Equal(drag.saved, drag.snapshot) or
        width ~= drag.width or height ~= drag.height or UIParent:GetEffectiveScale() ~= drag.scale then CancelDrag(group); return end
    local x, y = group.frame:GetCenter()
    local parentX, parentY = UIParent:GetCenter()
    local positionX, positionY = Bars.Services.BarLayout.Capture(x, y, group.frame:GetEffectiveScale(), drag.scale, parentX, parentY)
    if not positionX then CancelDrag(group); error(positionY) end
    group.drag = nil
    local preferences, failure = Layout.Patch(state.store.utilityLayouts, group.id, "x", positionX)
    if not preferences then error(failure) end
    preferences.y = positionY
    local drawing = assert(Layout.Resolve(preferences, group.width, group.height, width, height))
    preferences.x, preferences.y = drawing.x, drawing.y
    local ok, reason = Commit(group.id, preferences)
    if not ok then error(reason, 0) end
end
local function DragHidden()
    local group = this.utilityGroup
    if group then CancelDrag(group) end
end
EditGroup = function(group)
    local wanted = state.editing and (state.active and group.preferences.shown or state.showAnchors)
    if not wanted then
        CancelDrag(group)
        if group.handle then group.handle:Hide() end
        if not group.leased then group.frame:Hide() end
        return
    end
    local handle = group.handle
    if not handle then
        handle = UI.CreateControl("BootyActionBarsUtility_" .. group.id .. "MoveHandle", group.frame)
        group.handle = handle; handle.utilityGroup = group
        handle:EnableMouse(true); handle:RegisterForDrag("LeftButton")
        handle:SetFrameStrata("DIALOG"); handle:SetFrameLevel(group.frame:GetFrameLevel() + 50)
        handle:SetScript("OnDragStart", DragStartScript); handle:SetScript("OnDragStop", DragStopScript); handle:SetScript("OnHide", DragHiddenScript)
        UI.SetProjectButtonOutline(handle, true)
        group.label = UI.CreateComponentLabel(handle, Layout.Name(group.id), "white")
        group.label:SetPoint("CENTER", handle, "CENTER", 0, 0)
    end
    handle:SetAllPoints(group.frame)
    if state.showAnchors or not group.leased then group.label:Show() else group.label:Hide() end
    group.frame:Show(); handle:Show()
end
ApplyGroup = function(id, preferences)
    local failure
    if not preferences then preferences, failure = Layout.Read(state.store and state.store.utilityLayouts, id) end
    if not preferences then error(failure) end
    local wanted = state.active and preferences.shown
    local group = state.groups[id]
    if not wanted and not (state.editing and state.showAnchors) and not group then return end
    group = group or Ensure(id)
    if not wanted and group.leased then ReleaseGroup(group) end
    Geometry(group, preferences)
    if wanted then Lease(group); Position(group); group.frame:Show() end
    PaintArtwork(group, wanted)
    EditGroup(group)
end
function Utility.Configure(store)
    if type(store) ~= "table" then return false, "Utility-bar settings are unavailable." end
    local valid, failure = Layout.Validate(store.utilityLayouts)
    if not valid then return false, failure end
    if state.store ~= store then
        for _, group in pairs(state.groups) do CancelDrag(group) end
    end
    state.store = store
    return true
end
function Utility.Sync(active, nativeHidden)
    if type(active) ~= "boolean" or type(nativeHidden) ~= "boolean" then return false, "Expected explicit utility and native visibility." end
    if not state.store then return false, "Utility-bar settings are unavailable." end
    state.failure = nil
    state.active, state.nativeHidden = active, nativeHidden
    if not active then
        state.editing, state.showAnchors = false, false
        ReleaseGroups()
    end
    for _, id in ipairs(Layout.Keys) do
        local ok, failure = pcall(ApplyGroup, id)
        if not ok then Failure(failure) end
    end
    local ran, ok, failure = pcall(Parent, nativeHidden)
    if not ran then failure, ok = ok, false end
    if ok == false then Failure(failure) end
    if state.failure then
        local initial = state.failure
        local restored, failure = Utility.Release()
        state.failure = restored and initial or initial .. " Restoration: " .. tostring(failure)
        return false, state.failure
    end
    return true
end
function Utility.SetEditing(editing, showAnchors)
    state.failure = nil
    state.editing, state.showAnchors = editing == true, showAnchors == true
    for _, id in ipairs(Layout.Keys) do
        local ok, failure = pcall(ApplyGroup, id)
        if not ok then Failure(failure) end
    end
    return state.failure == nil, state.failure
end
function Utility.GetLayout(id) return Layout.Read(state.store and state.store.utilityLayouts, id) end
Commit = function(id, preferences)
    local owner, saved = state.store, state.store.utilityLayouts
    local snapshot = saved and assert(Layout.Copy(saved))
    local group = state.groups[id]
    if group then CancelDrag(group) end
    state.failure = nil
    local unchanged = state.store == owner and owner.utilityLayouts == saved and Layout.Equal(saved, snapshot)
    local ok, reason = true, nil
    if unchanged then ok, reason = pcall(ApplyGroup, id, preferences) end
    unchanged = unchanged and state.store == owner and owner.utilityLayouts == saved and Layout.Equal(saved, snapshot)
    if not ok or state.failure or not unchanged then
        local initial = state.failure or (not unchanged and "Utility-bar settings ownership changed while applying the layout.") or tostring(reason)
        group = state.groups[id]
        state.failure = nil
        if group then
            local released, failure = pcall(ReleaseGroup, group)
            if not released then Failure(failure) end
        end
        local repaired, failure = pcall(ApplyGroup, id)
        if not repaired then Failure(failure) end
        state.failure = state.failure and initial .. " Restoration: " .. state.failure or initial
        return false, state.failure
    end
    if not saved then saved = {}; owner.utilityLayouts = saved end
    saved[id] = preferences
    return true
end
function Utility.SetPreference(id, key, value)
    if not state.store then return false, "Utility-bar settings are unavailable." end
    local preferences, failure = Layout.Patch(state.store.utilityLayouts, id, key, value)
    if not preferences then return false, failure end
    return Commit(id, preferences)
end
function Utility.Reset(id)
    if not Layout.ValidID(id) or not state.store then return false, "Choose a listed utility bar." end
    local preferences = assert(Layout.Read(nil, id))
    preferences.shown = assert(Utility.GetLayout(id)).shown
    return Commit(id, preferences)
end
function Utility.OnContextChanged()
    state.failure = nil
    for _, id in ipairs(Layout.Keys) do
        local group = state.groups[id]
        if group then
            local cancelled, failure = pcall(CancelDrag, group)
            if not cancelled then Failure(failure) end
            local refreshed, reason = pcall(ApplyGroup, id)
            if not refreshed then Failure(reason) end
        end
    end
    return state.failure == nil, state.failure
end
function Utility.Release()
    state.failure = nil
    state.active, state.nativeHidden, state.editing, state.showAnchors = false, false, false, false
    ReleaseGroups()
    local ran, ok, failure = pcall(Parent, false)
    if not ran then failure, ok = ok, false end
    if ok == false then Failure(failure) end
    return state.failure == nil, state.failure
end
function Utility.SetFailureObserver(callback)
    if callback ~= nil and type(callback) ~= "function" then return false, "Expected a utility failure observer or nil." end
    failureObserver = callback; return true
end
function Utility.GetState() return state end
local function Boundary(callback)
    return function(first, second, third)
        local previousThis, previousEvent, previousArg = this, event, arg1
        local ran, ok, failure = pcall(callback, first, second, third)
        this, event, arg1 = previousThis, previousEvent, previousArg
        if not ran then Failure(ok); return false, state.failure end
        return ok, failure
    end
end
Utility.Configure = Boundary(Utility.Configure)
Utility.Sync = Boundary(Utility.Sync)
Utility.SetEditing = Boundary(Utility.SetEditing)
Utility.SetPreference = Boundary(Utility.SetPreference)
Utility.Reset = Boundary(Utility.Reset)
Utility.Release = Boundary(Utility.Release)
Utility.OnContextChanged = Boundary(Utility.OnContextChanged)
local function InputBoundary(callback)
    return function()
        local previousThis, previousEvent, previousArg = this, event, arg1
        local group = this.utilityGroup
        local ok, failure = pcall(callback)
        if not ok and group and group.drag then
            local restored, reason = pcall(CancelDrag, group)
            if not restored then failure = tostring(failure) .. " Restoration: " .. tostring(reason) end
        end
        this, event, arg1 = previousThis, previousEvent, previousArg
        if not ok then state.failure = tostring(failure); error(failure, 0) end
    end
end
DragStartScript, DragStopScript, DragHiddenScript = InputBoundary(DragStart), InputBoundary(DragStop), InputBoundary(DragHidden)
