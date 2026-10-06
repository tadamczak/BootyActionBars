local Bars = BootyActionBars
local Layout, UI = Bars.Services.BarLayout, Bars.UI.Components
local Editor = {}
Bars.Modules.Editor = Editor
local state = {active = false, editing = false, subscribed = false, handles = {}, drags = {}, handleFailures = {}}
local CancelDrag, EnsureHandle, ContextEvent

local function Run(callback, first, second, third, fourth)
    local oldThis, oldEvent, oldArg = this, event, arg1
    local ran, result, detail, extra = pcall(callback, first, second, third, fourth)
    this, event, arg1 = oldThis, oldEvent, oldArg
    if not ran then return false, tostring(result) end
    return true, result, detail, extra
end
local function Try(callback, first, second, third, fourth)
    local ran, result, detail = Run(callback, first, second, third, fourth)
    if not ran then return false, result end
    if result == false then return false, detail or "Action bar editing could not be completed." end
    return true, result, detail
end
local function Report(failure)
    failure = tostring(failure)
    if state.failure ~= failure then BootyLib.Print("BootyActionBars: " .. failure) end
    state.failure = failure
end
local function View(id)
    local engine = Bars.Core.Engine.GetState()
    return engine.views and engine.views[id] or id == 1 and engine.view or nil
end
local function Screen(withCenter)
    local width, height = UI.GetFrameSpan(UIParent)
    local scale = UIParent:GetEffectiveScale()
    if not Layout.Finite(width) or width <= 0 or not Layout.Finite(height) or height <= 0
        or not Layout.Finite(scale) or scale <= 0 then error("Action bar screen context is unavailable.") end
    local context = {width = width, height = height, scale = scale}
    if withCenter then
        context.x, context.y = UIParent:GetCenter()
        if not Layout.Finite(context.x) or not Layout.Finite(context.y) then error("The screen center is unavailable.") end
    end
    return context
end
local function SameContext(first, second)
    return first and second and first.width == second.width and first.height == second.height
        and first.scale == second.scale and first.x == second.x and first.y == second.y
end
local function Drawing(view, value)
    local frame = view.frame
    frame:SetScale(value.scale)
    local actual = frame:GetScale()
    if not Layout.Finite(actual) or math.abs(actual - value.scale) > 0.0001 then error("The client declined the action bar scale.") end
    frame:ClearAllPoints(); frame:SetPoint("CENTER", UIParent, "CENTER", value.anchorX, value.anchorY)
    if frame.SetUserPlaced then frame:SetUserPlaced(false) end
    return true
end
local function ApplyRecord(view, record, force)
    local context = Screen(false)
    local value, failure = Layout.Resolve(view.id, record, context.width, context.height)
    if not value then return false, failure end
    value.parentScale = context.scale
    local previous = view.layoutDrawing
    if not force and previous and previous.scale == value.scale and previous.anchorX == value.anchorX
        and previous.anchorY == value.anchorY and previous.width == value.width and previous.height == value.height
        and previous.parentScale == value.parentScale then return true end
    local ok, reason = Try(Drawing, view, value)
    if not ok then
        if previous then
            local restored, restoreFailure = Try(Drawing, view, previous)
            if not restored then reason = reason .. " Restoration: " .. tostring(restoreFailure) end
        end
        return false, reason
    end
    view.layoutDrawing = value
    return true
end
function Editor.Configure(store)
    if type(store) ~= "table" then return false, "Action bar layout settings are unavailable." end
    local ok, failure = Layout.ValidateLayouts(store.barLayouts)
    if not ok then return false, failure end
    state.store = store
    return true
end
function Editor.GetLayout(id)
    return Layout.Read(state.store and state.store.barLayouts, id)
end
function Editor.ApplyView(view, force)
    if not view or not Layout.ValidID(view.id) then return false, "Action bar view identity is unavailable." end
    local record, failure = Editor.GetLayout(view.id)
    if not record then return false, failure end
    local ran, ok, reason = Run(ApplyRecord, view, record, force)
    if not ran then return false, ok end
    return ok, reason
end
local function Owner()
    local store, failure = Bars.Database.Ensure()
    if not store then return nil, failure or "Action bar layout settings are unavailable." end
    if store ~= state.store then return nil, "Action bar saved layout ownership changed." end
    local ok, reason = Layout.ValidateLayouts(store.barLayouts)
    if not ok then return nil, reason end
    return store
end
local function Equal(first, second)
    return first and second and first.scalePct == second.scalePct and first.x == second.x and first.y == second.y
end
local function Commit(id, candidate, reset, expected)
    local store, failure = Owner()
    if not store then return false, failure end
    local layouts, original = store.barLayouts, store.barLayouts and store.barLayouts[id]
    local previous, reason = Layout.Read(layouts, id)
    if not previous then return false, reason end
    if expected and (store ~= expected.store or layouts ~= expected.layouts or original ~= expected.record
        or not Equal(previous, expected.original)) then return false, "Action bar layout changed while dragging." end
    local changed = reset and original ~= nil or not reset and not Equal(previous, candidate)
    if not changed and not expected then return true end
    local view = View(id)
    -- Profiling must also see attempted geometry changes which are rolled
    -- back after a native setter failure.
    Bars.Core.Engine.MarkLayoutChanged()
    if view and view.frame:IsVisible() then
        local ok, message = ApplyRecord(view, candidate, true)
        if not ok then return false, message end
    end
    local current, message = Owner()
    local after = Layout.Read(store.barLayouts, id)
    if current ~= store or store.barLayouts ~= layouts or (layouts and layouts[id]) ~= original or not Equal(after, previous) then
        -- The later saved value wins. Refresh it without writing our candidate.
        if view then Editor.ApplyView(view, true) end
        return false, message or "Action bar saved layout ownership changed during editing."
    end
    if not changed then return true end
    if not layouts then layouts = {}; store.barLayouts = layouts end
    if reset then layouts[id] = nil
    else
        local record = {}
        if original then for key, value in pairs(original) do record[key] = value end end
        record.scalePct, record.x, record.y = candidate.scalePct, candidate.x, candidate.y
        layouts[id] = record
    end
    state.failure = nil
    return true
end
local function Capture(view, context)
    local x, y = view.frame:GetCenter()
    return Layout.Capture(x, y, view.frame:GetEffectiveScale(), context.scale, context.x, context.y)
end
local function SetScale(id, percent)
    if not Layout.ValidID(id) or not Layout.ValidScale(percent) then return false, "Choose bar 1-6 and an integer scale from 50 to 200." end
    local cancelled, failure = CancelDrag(id)
    if not cancelled then return false, failure end
    local record, reason = Editor.GetLayout(id)
    if not record then return false, reason end
    if record.scalePct == percent then return true end
    local view = View(id)
    if view and view.frame:IsVisible() then
        local context = Screen(true)
        local x, y = Capture(view, context)
        if x == nil then return false, y end
        record.x, record.y = x, y
    end
    record.scalePct = percent
    return Commit(id, record, false)
end
function Editor.SetScale(id, percent)
    local ran, ok, failure = Run(SetScale, id, percent)
    if not ran then return false, ok end
    return ok, failure
end
local function Reset(id)
    if not Layout.ValidID(id) then return false, "Choose an action bar from 1 to 6." end
    local ok, failure = CancelDrag(id)
    if not ok then return false, failure end
    return Commit(id, Layout.Read(nil, id), true)
end
function Editor.Reset(id)
    local ran, ok, failure = Run(Reset, id)
    if not ran then return false, ok end
    return ok, failure
end
CancelDrag = function(id)
    local drag = state.drags[id]
    if not drag then return true end
    state.drags[id] = nil
    local frame, firstFailure = drag.view.frame, nil
    local ok, reason = Try(frame.StopMovingOrSizing, frame)
    if not ok then firstFailure = reason end
    if frame.SetUserPlaced then
        ok, reason = Try(frame.SetUserPlaced, frame, false)
        if not ok and not firstFailure then firstFailure = reason end
    end
    ok, reason = Editor.ApplyView(drag.view, true)
    if not ok and not firstFailure then firstFailure = reason end
    return firstFailure == nil, firstFailure
end
local function CancelAll()
    local firstFailure
    for id = 1, 6 do
        local ok, failure = CancelDrag(id)
        if not ok and not firstFailure then firstFailure = failure end
    end
    return firstFailure == nil, firstFailure
end
local function DragStart(id)
    local view = View(id)
    if not state.editing or not state.active or not view or not view.frame:IsVisible() then return false, "Action bar editing is inactive." end
    local store, failure = Owner()
    if not store then return false, failure end
    local ok, reason = CancelAll()
    if not ok then return false, reason end
    local context, original = Screen(true), Layout.Read(store.barLayouts, id)
    ok, reason = Try(view.CancelInput, view)
    if not ok then return false, reason end
    state.drags[id] = {view = view, store = store, layouts = store.barLayouts,
        record = store.barLayouts and store.barLayouts[id], original = original, context = context}
    Bars.Core.Engine.MarkLayoutChanged()
    ok, reason = Try(view.frame.StartMoving, view.frame)
    if not ok then CancelDrag(id); return false, reason end
    return true
end
local function DragStop(id)
    local drag = state.drags[id]
    if not drag then return true end
    local ok, failure = Try(drag.view.frame.StopMovingOrSizing, drag.view.frame)
    if not ok then CancelDrag(id); return false, failure end
    if not state.editing or not state.active or not drag.view.frame:IsVisible() then return CancelDrag(id) end
    local context = Screen(true)
    if not SameContext(context, drag.context) then return CancelDrag(id) end
    local x, y = Capture(drag.view, context)
    if x == nil then CancelDrag(id); return false, y end
    local candidate = {scalePct = drag.original.scalePct, x = x, y = y}
    local committed, reason = Commit(id, candidate, false, drag)
    if not committed then CancelDrag(id); return false, reason end
    state.drags[id] = nil
    return true
end
local function Start()
    local ran, ok, failure = Run(DragStart, this.editBarId)
    if not ran then ok, failure = false, ok end
    if not ok then Report(failure); CancelAll() end
end
local function Stop()
    local ran, ok, failure = Run(DragStop, this.editBarId)
    if not ran then ok, failure = false, ok end
    if not ok then Report(failure); CancelAll() end
end
local function Hidden()
    local ok, failure = CancelDrag(this.editBarId)
    if not ok then Report(failure) end
end
local function CreateHandle(view)
    local name = "BootyActionBarsBar" .. view.id .. "MoveHandle"
    if _G[name] then error("An action bar editing handle already owns this name.") end
    local handle = UI.CreateButton(view.frame, name, "Move bar " .. view.id, 524, 40)
    state.handles[view.id], view.editHandle = handle, handle
    handle:Hide()
    handle.editBarId = view.id; handle:SetAllPoints(view.frame)
    handle:SetFrameLevel(view.frame:GetFrameLevel() + 10)
    UI.SetProjectButtonOutline(handle, true)
    handle:RegisterForDrag("LeftButton"); handle:Hide()
    return handle
end
EnsureHandle = function(view)
    local id = view.id
    if state.handleFailures[id] then return false, state.handleFailures[id] end
    local handle = state.handles[id]
    if not handle then
        local ran, created = Run(CreateHandle, view)
        if not ran then
            -- Native named frames survive a failed Lua styling factory. Keep
            -- only our own partial control so End can hide/detach it; do not
            -- allocate another handle on the next attempt.
            local partial = _G["BootyActionBarsBar" .. id .. "MoveHandle"]
            if partial and type(partial.GetParent) == "function" then
                local inspected, parent = Run(partial.GetParent, partial)
                if inspected and parent == view.frame then state.handles[id], view.editHandle = partial, partial end
            end
            state.handleFailures[id] = created
            return false, created
        end
        handle, state.handles[id], view.editHandle = created, created, created
    end
    view.frame:SetMovable(true)
    handle:SetScript("OnDragStart", Start); handle:SetScript("OnDragStop", Stop); handle:SetScript("OnHide", Hidden)
    handle:Show()
    return true
end
local function Detach(id)
    local firstFailure
    local view, handle = View(id), state.handles[id]
    if handle then
        for _, name in ipairs({"OnDragStart", "OnDragStop", "OnHide"}) do
            local ok, reason = Try(handle.SetScript, handle, name, nil)
            if not ok and not firstFailure then firstFailure = reason end
        end
        local ok, reason = Try(handle.Hide, handle)
        if not ok and not firstFailure then firstFailure = reason end
    end
    if view then
        local ok, reason = Try(view.frame.SetMovable, view.frame, false)
        if not ok and not firstFailure then firstFailure = reason end
        ok, reason = Try(view.CancelInput, view)
        if not ok and not firstFailure then firstFailure = reason end
    end
    return firstFailure == nil, firstFailure
end
function Editor.End()
    state.editing = false
    local ok, firstFailure = CancelAll()
    for id = 1, 6 do
        local detached, failure = Detach(id)
        if not detached and not firstFailure then firstFailure = failure end
    end
    return firstFailure == nil, firstFailure
end
function Editor.OnBarHidden(id)
    if id == 1 then return Editor.End() end
    local ok, firstFailure = CancelDrag(id)
    local detached, failure = Detach(id)
    if not detached and not firstFailure then firstFailure = failure end
    return firstFailure == nil, firstFailure
end
function Editor.Sync()
    local firstFailure
    for id = 1, 6 do
        local view = View(id)
        if view and view.frame:IsVisible() then
            local ok, failure = Editor.ApplyView(view)
            if ok and state.editing then ok, failure = Try(EnsureHandle, view) end
            if not ok and not firstFailure then firstFailure = failure end
        end
    end
    return firstFailure == nil, firstFailure
end
function Editor.Begin()
    if not state.active or not Bars.Core.Engine.GetState().active then return false, "Enable and show the action bars before editing." end
    if state.editing then return true end
    state.editing = true
    for id = 1, 6 do
        local view = View(id)
        if view and view.frame:IsVisible() then
            local ok, failure = Try(view.CancelInput, view)
            if not ok then Editor.End(); return false, failure end
        end
    end
    local ok, failure = Editor.Sync()
    if not ok then Editor.End(); return false, failure end
    return true
end
function Editor.IsEditing() return state.editing end
ContextEvent = function()
    local name = type(arg1) == "string" and string.lower(arg1) or nil
    if name and name ~= "uiscale" and name ~= "useuiscale" and name ~= "gxresolution" then return end
    local ran, context = Run(Screen, true)
    if not ran then Report(context); CancelAll(); return end
    if SameContext(context, state.context) then return end
    Bars.Core.Engine.MarkLayoutChanged()
    local ok, failure = CancelAll()
    state.context = context
    local synced, reason = Editor.Sync()
    if not ok then Report(failure) elseif not synced then Report(reason) end
end
function Editor.OnActivity(active)
    state.active = active == true
    if not state.active then
        local ok, firstFailure = Editor.End()
        if state.subscribed then
            local removed, failure = Try(BootyLib.Unsubscribe, "CVAR_UPDATE", Editor)
            if removed then state.subscribed = false elseif not firstFailure then firstFailure = failure end
        end
        state.context = nil
        return firstFailure == nil, firstFailure
    end
    if not state.subscribed then
        local ok, result, reason = Run(BootyLib.Subscribe, "CVAR_UPDATE", Editor, ContextEvent)
        if not ok or result ~= true then return false, ok and (reason or "Action bar screen subscription declined.") or result end
        state.subscribed = true
    end
    local ran, context = Run(Screen, true)
    if not ran then return false, context end
    state.context = context
    return Editor.Sync()
end
function Editor.GetState() return state end
