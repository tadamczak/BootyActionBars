local Bars = BootyActionBars
local Groups = {}
Bars.Modules.BarGroups = Groups
local Merging, UI = Bars.Services.BarMerging, Bars.UI.Components
local state = {links = {}, extents = {}}

local function View(id)
    if type(id) == "string" then return Bars.Modules.NativeUtilityBars.GetView(id) end
    if id == 7 or id == 8 then return Bars.Modules.SpecialBars.GetView(id) end
    local engine = Bars.Core.Engine.GetState()
    local owner = engine.mergeOwners[id] or id
    return engine.views[owner]
end
local function Capture(frame)
    local result = {frame = frame, points = {}}
    for index = 1, frame:GetNumPoints() do
        local point, relative, anchor, x, y = frame:GetPoint(index)
        result.points[index] = {point, relative, anchor, x, y}
    end
    return result
end
local function Restore(record)
    local frame = record.frame
    if frame:ClearAllPoints() == false then error("Group anchor reset was declined.") end
    for _, point in ipairs(record.points) do if frame:SetPoint(point[1], point[2], point[3], point[4], point[5]) == false then error("Group anchor restoration was declined.") end end
    if record.width then
        if frame:SetWidth(record.width) == false or frame:SetHeight(record.height) == false then error("Group handle restoration was declined.") end
    end
end
local function Extent(id, view, width, height)
    if type(id) == "string" then
        if view.handle then
            if view.handle:ClearAllPoints() == false or view.handle:SetPoint("TOPLEFT", view.frame, "TOPLEFT", 0, 0) == false
                or view.handle:SetWidth(width) == false or view.handle:SetHeight(height) == false then error("Merged utility handle sizing was declined.") end
        end
    else
        local ok, failure = Bars.Modules.Editor.SetGroupExtent(id, width, height)
        if ok == false then error(failure) end
    end
end
function Groups.Configure(store)
    local ok, failure = Merging.Validate(store and store.barMerges)
    if not ok then return false, failure end
    ok, failure = Merging.ValidateOverrides(store and store.mergeStyleOverrides)
    if not ok then return false, failure end
    state.store = store; return true
end
function Groups.Release()
    local oldThis, oldEvent, a1, a2, a3, a4, a5, a6, a7, a8, a9 = this, event, arg1, arg2, arg3, arg4, arg5, arg6, arg7, arg8, arg9
    local failure
    for frame, record in pairs(state.links) do
        local ok, reason = pcall(Restore, record)
        if ok then state.links[frame] = nil else failure = failure or tostring(reason) end
    end
    for id, view in pairs(state.extents) do
        local ok, reason = pcall(Extent, id, view, view.frame:GetWidth(), view.frame:GetHeight())
        if ok then state.extents[id] = nil else failure = failure or tostring(reason) end
    end
    this, event, arg1, arg2, arg3, arg4, arg5, arg6, arg7, arg8, arg9 = oldThis, oldEvent, a1, a2, a3, a4, a5, a6, a7, a8, a9
    return failure == nil, failure
end
local function Refresh()
    if not state.store or not Bars.Core.Engine.GetState().active then return Groups.Release() end
    if not state.store.barMerges or not next(state.store.barMerges) then return Groups.Release() end
    local plans, extents, seen = {}, {}, {}
    for _, id in ipairs(Merging.IDs) do
        if state.store.barMerges and state.store.barMerges[id] then
            local primary = View(id)
            if not primary and type(id) == "number" then
                local failure; primary, failure = Bars.Modules.Editor.GetGroupAnchor(id)
                if not primary then return false, failure end
            end
            if primary then
                if type(id) == "number" and not primary.frame:IsVisible() then
                    local applied, reason = Bars.Modules.Editor.ApplyView(primary, true)
                    if not applied then return false, reason end
                end
                local frame, members = primary.frame, Merging.Members(state.store.barMerges, id)
                local scale = frame:GetScale()
                local width, height = frame:GetWidth() * scale, frame:GetHeight() * scale
                local gap = (primary.layoutDrawing and primary.layoutDrawing.spacing or primary.preferences and primary.preferences.spacing or 4) * scale
                seen[frame] = true
                for index = 2, table.getn(members) do
                    local child = View(members[index])
                    if child and not seen[child.frame] and child.frame:IsVisible() then
                        seen[child.frame] = true
                        local childScale = child.frame:GetScale()
                        plans[table.getn(plans) + 1] = {frame = child.frame, primary = frame, top = height + gap, scale = childScale}
                        width = math.max(width, child.frame:GetWidth() * childScale)
                        height = height + gap + child.frame:GetHeight() * childScale
                    end
                end
                extents[id] = {view = primary, width = width / scale, height = height / scale}
            end
        end
    end
    local snapshots, linked = {}, {}
    for _, plan in ipairs(plans) do
        snapshots[plan.frame] = Capture(plan.frame)
        linked[plan.frame] = true
    end
    for frame, record in pairs(state.links) do if not linked[frame] then snapshots[frame] = Capture(frame) end end
    local function CaptureHandle(id, view)
        local handle = type(id) == "string" and view.handle or Bars.Modules.Editor.GetGroupHandle(id)
        if handle and not snapshots[handle] then
            local record = Capture(handle); record.width, record.height = handle:GetWidth(), handle:GetHeight()
            snapshots[handle] = record
        end
    end
    for id, previous in pairs(state.extents) do CaptureHandle(id, previous) end
    for id, value in pairs(extents) do CaptureHandle(id, value.view) end
    local ok, failure = pcall(function()
        for frame, record in pairs(state.links) do if not linked[frame] then Restore(record) end end
        for _, plan in ipairs(plans) do
            local frame = plan.frame
            if frame:ClearAllPoints() == false or frame:SetPoint("TOPLEFT", plan.primary, "TOPLEFT", 0, -plan.top / plan.scale) == false then error("Merged bar positioning was declined.") end
            local point, relative, anchor, x, y = frame:GetPoint(1)
            if point ~= "TOPLEFT" or relative ~= plan.primary or anchor ~= "TOPLEFT" or x ~= 0 or math.abs(y + plan.top / plan.scale) > 0.001 then error("Merged bar positioning did not apply.") end
        end
        for id, previous in pairs(state.extents) do
            if not extents[id] then Extent(id, previous, previous.frame:GetWidth(), previous.frame:GetHeight()) end
        end
        for id, value in pairs(extents) do Extent(id, value.view, value.width, value.height) end
    end)
    if not ok then
        local restoration
        for _, record in pairs(snapshots) do local restored, reason = pcall(Restore, record); if not restored then restoration = restoration or tostring(reason) end end
        return false, tostring(failure) .. (restoration and " Restoration: " .. restoration or "")
    end
    for frame in pairs(state.links) do if not linked[frame] then state.links[frame] = nil end end
    for _, plan in ipairs(plans) do if not state.links[plan.frame] then state.links[plan.frame] = snapshots[plan.frame] end end
    for id in pairs(state.extents) do state.extents[id] = nil end
    for id, value in pairs(extents) do state.extents[id] = value.view end
    return true
end
function Groups.Refresh()
    if state.busy then return true end
    state.busy = true
    local oldThis, oldEvent, a1, a2, a3, a4, a5, a6, a7, a8, a9 = this, event, arg1, arg2, arg3, arg4, arg5, arg6, arg7, arg8, arg9
    local ran, ok, failure = pcall(Refresh)
    this, event, arg1, arg2, arg3, arg4, arg5, arg6, arg7, arg8, arg9 = oldThis, oldEvent, a1, a2, a3, a4, a5, a6, a7, a8, a9
    state.busy = nil
    if not ran then return false, tostring(ok) end
    return ok, failure
end
