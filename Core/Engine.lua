local Bars = BootyActionBars
local Engine = {}
Bars.Core.Engine = Engine
local state = {active = false, requested = false, subscribed = false, views = {}, customBars = {},
    customActive = {}, customRevision = 0, customConfiguredCount = 0, customActiveCount = 0, macroDirty = {},
    mainShown = true, mainActive = false, mappingOffsets = {}, mappingPages = {}, mappingMatches = {},
    mappingChanged = {}, mappingCaptions = {}, behaviorLive = {}, mergeOwners = {}, mergeCounts = {},
    mergeOrdinals = {}, mergeViewLists = {}, mergeMemberIDs = {}, mergePlans = {}}
local events = {"PLAYER_ENTERING_WORLD", "ACTIONBAR_SLOT_CHANGED", "ACTIONBAR_UPDATE_COOLDOWN",
    "ACTIONBAR_UPDATE_USABLE", "ACTIONBAR_UPDATE_STATE", "PLAYER_TARGET_CHANGED", "PLAYER_AURAS_CHANGED",
    "UNIT_INVENTORY_CHANGED", "UPDATE_INVENTORY_ALERTS", "BAG_UPDATE", "UPDATE_BINDINGS", "PLAYER_ENTER_COMBAT", "PLAYER_LEAVE_COMBAT",
    "START_AUTOREPEAT_SPELL", "STOP_AUTOREPEAT_SPELL", "CRAFT_SHOW", "CRAFT_CLOSE", "TRADE_SKILL_SHOW", "TRADE_SKILL_CLOSE",
    "ACTIONBAR_PAGE_CHANGED", "UPDATE_BONUS_ACTIONBAR", "UPDATE_SHAPESHIFT_FORMS", "ADDON_LOADED",
    "ACTIONBAR_SHOWGRID", "ACTIONBAR_HIDEGRID"}
local pageEvents = {ACTIONBAR_PAGE_CHANGED = true, UPDATE_BONUS_ACTIONBAR = true, UPDATE_SHAPESHIFT_FORMS = true}
local behaviorEvents = {PLAYER_ENTERING_WORLD = true, PLAYER_AURAS_CHANGED = true,
    ACTIONBAR_PAGE_CHANGED = true, UPDATE_BONUS_ACTIONBAR = true, UPDATE_SHAPESHIFT_FORMS = true,
    BOOTY_ACTIONBARS_BEHAVIOR_CONFIG = true}
local stateEvents = {ACTIONBAR_UPDATE_STATE = true, PLAYER_ENTER_COMBAT = true, PLAYER_LEAVE_COMBAT = true,
    START_AUTOREPEAT_SPELL = true, STOP_AUTOREPEAT_SPELL = true, CRAFT_SHOW = true, CRAFT_CLOSE = true,
    TRADE_SKILL_SHOW = true, TRADE_SKILL_CLOSE = true}
local SyncRange, SyncWorker, FlushMacroChanges, SyncMain, SyncContext, UpdateMappings, PublishVisibility
local visibilityObserver, visibilityDepth, notifyingVisibility = nil, 0, false
local liveMain, observedMain, observedCustom = false, false, 0
local liveCustom = {[2] = false, [3] = false, [4] = false, [5] = false, [6] = false}

local function Valid(index)
    return type(index) == "number" and index >= 1 and index <= 12 and index == math.floor(index)
end
local function ValidBar(barId)
    return type(barId) == "number" and barId >= 1 and barId <= 6 and barId == math.floor(barId)
end
local function MergeOwner(id) return state.mergeOwners[id] or id end
local function RequestedBar(id)
    local owner = MergeOwner(id)
    return owner == 1 and state.mainShown or owner ~= 1 and state.customBars[owner] == true
end
function Engine.GetMergeOwner(id)
    if not ValidBar(id) then return nil, "Only ordinary action bars can be merged." end
    return MergeOwner(id)
end
function Engine.GetMergeCount(id)
    if not ValidBar(id) then return nil, "Only ordinary action bars can be merged." end
    return state.mergeCounts[id] or 12
end
function Engine.GetMergeMembers(id, target)
    if not ValidBar(id) then return nil, "Only ordinary action bars can be merged." end
    local factory = Bars.Services.BarMerging
    if factory then return factory.Members(state.merges, MergeOwner(id), target) end
    target = target or {}; target[1] = id
    for index = 2, table.getn(target) do target[index] = nil end
    return target
end
function Engine.ConfigureMerges(groups)
    local factory = Bars.Services.BarMerging
    if not factory then
        if groups == nil or type(groups) == "table" and next(groups) == nil then return true end
        return false, "Merged action bar settings are unavailable."
    end
    local valid, failure = factory.Validate(groups)
    if not valid then return false, failure end
    if factory.Equal(state.merges, groups) then return true end
    local copy; copy, failure = factory.Copy(groups)
    if not copy then return false, failure end
    state.merges, state.hasMerges, state.mergeDirty = copy, next(copy) ~= nil, true
    for id = 1, 6 do
        local host, count, ordinal = factory.Read(copy, id)
        state.mergeOwners[id], state.mergeCounts[id], state.mergeOrdinals[id] = host, count, ordinal
    end
    state.customRevision = state.customRevision + 1
    return true
end
local function Report(message)
    message = tostring(message)
    if state.failure ~= message then BootyLib.Print("BootyActionBars: " .. message) end
    state.failure = message
end
local function ProtectedCall(callback, owner, second)
    local previousThis, previousEvent, previousArg = this, event, arg1
    local ran, ok, failure = pcall(callback, owner, second)
    this, event, arg1 = previousThis, previousEvent, previousArg
    if not ran then return false, tostring(ok) end
    if ok == false then return false, failure or "An action bar could not be suspended." end
    return true
end
local function Context(view, index, callback, first, second, third, fourth)
    local previousThis, previousEvent, previousArg = this, event, arg1
    this = view.buttons[index]
    local ok, result, reason = pcall(callback, first, second, third, fourth)
    this, event, arg1 = previousThis, previousEvent, previousArg
    if not ok then Report(result); return false, result end
    return result, reason
end
local function ReadAndRender(view, index, category, force)
    local button = view.buttons[index]
    local nativeEvent, nativeArg = event, arg1
    local result, reason
    if category == "ReadRange" then result, reason = state.rangeService.Read(button.action, button.read, true, true)
    else result, reason = state.service[category](button.action, button.read) end
    if not result then return false, reason end
    this, event, arg1 = button, nativeEvent, nativeArg
    if category == "Read" and state.rangeService then
        result, reason = state.rangeService.Read(button.action, button.read)
        if not result then return false, reason end
    end
    this, event, arg1 = button, nativeEvent, nativeArg
    view:Render(index, button.read, force, category == "ReadRange")
    return true
end
local function Refresh(view, index, category, force)
    state.readingDepth = (state.readingDepth or 0) + 1
    local ok, failure = Context(view, index, ReadAndRender, view, index, category, force)
    state.readingDepth = state.readingDepth - 1
    return ok, failure
end
local function RefreshView(view, category, force)
    for index = 1, 12 do
        local ok, failure = Refresh(view, index, category, force)
        if not ok then return false, failure end
    end
    return true
end
local function IsActive(barId)
    return state.active and (barId == 1 and state.mainActive == true or barId ~= 1 and state.customActive[barId] == true)
end
local function RefreshAll(category, force)
    for barId = 1, 6 do
        if IsActive(barId) then
            local ok, failure = RefreshView(state.views[barId], category, force)
            if not ok then return false, failure end
        end
    end
    return true
end
local function ClearWorkerScript()
    if state.workerFrame then state.workerFrame:SetScript("OnUpdate", nil) end
end
local function StopWorker()
    local ok, failure = ProtectedCall(ClearWorkerScript)
    if ok then state.workerFrame = nil end
    state.workerTracking, state.rangeFrame = false, nil
    return ok, failure
end
local function StopRange()
    state.rangeTracking, state.rangeElapsed = false, 0
    return SyncWorker()
end
local function RangeUpdate(elapsed)
    if not state.rangeTracking then return end
    state.rangeElapsed = state.rangeElapsed + (elapsed or 0)
    if state.rangeElapsed < 0.2 then return end
    -- A slow frame never triggers a catch-up burst.
    state.rangeElapsed = 0
    local previousThis, previousEvent, previousArg = this, event, arg1
    local ran, hasTarget = pcall(state.rangeService.HasTarget)
    this, event, arg1 = previousThis, previousEvent, previousArg
    if not ran then Engine.Disable(); Report(hasTarget); return end
    if not state.active or not hasTarget then
        local ok, failure = StopRange()
        if not ok then Engine.Disable(); Report(failure) end
        return
    end
    for barId = 1, 6 do
        if IsActive(barId) then
            local view = state.views[barId]
            for index = 1, 12 do
                if view.buttons[index].read.hasRange then
                    local ok, failure = Refresh(view, index, "ReadRange")
                    if not ok then Engine.Disable(); Report(failure); return end
                end
            end
        end
    end
    if state.macroPending then
        local ok, failure = FlushMacroChanges()
        if ok then ok, failure = SyncRange() end
        if not ok then Engine.Disable(); Report(failure) end
    end
end
local function WorkerTick()
    -- Use the existing observed entry point; scoped profiling includes this
    -- conditional worker without replacing a frame script during capture.
    Engine.HandleEvent("BOOTY_ACTIONBARS_SHARED_UPDATE", arg1)
end
local function InstallWorkerScript() state.workerFrame:SetScript("OnUpdate", WorkerTick) end
SyncWorker = function()
    local cooldown = Bars.Modules.CooldownText
    state.cooldownTracking = state.active and cooldown ~= nil and cooldown.GetDemand() or false
    if not state.active or not state.rangeTracking and not state.cooldownTracking then
        state.cooldownElapsed = 0
        return StopWorker()
    end
    local frame = state.mainActive and state.view.frame or state.driver
    if not frame then return false, "The action bar update driver is unavailable." end
    if not state.workerTracking or state.workerFrame ~= frame then
        local ok, failure = StopWorker()
        if not ok then return false, failure end
        state.workerFrame, state.workerTracking = frame, true
        ok, failure = ProtectedCall(InstallWorkerScript)
        if not ok then return false, failure end
    end
    state.rangeFrame = state.rangeTracking and frame or nil
    return true
end
local function CooldownUpdate(elapsed)
    local cooldown = Bars.Modules.CooldownText
    if not cooldown or not cooldown.GetDemand() then state.cooldownElapsed = 0; return true end
    state.cooldownElapsed = (state.cooldownElapsed or 0) + (elapsed or 0)
    if state.cooldownElapsed < 0.1 then return true end
    state.cooldownElapsed = 0
    local oldThis, oldEvent, oldArg = this, event, arg1
    local ran, now = pcall(GetTime)
    this, event, arg1 = oldThis, oldEvent, oldArg
    if not ran then return false, tostring(now) end
    return cooldown.Tick(now)
end
local function SharedUpdate(elapsed)
    state.workerUpdating = true
    RangeUpdate(elapsed)
    local ok, failure = true, nil
    if state.active then ok, failure = CooldownUpdate(elapsed) end
    state.workerUpdating = nil
    if ok then ok, failure = SyncWorker() end
    if not ok then Engine.Disable(); Report(failure) end
end
function Engine.CooldownChanged()
    if state.enabling or state.cleaning or state.mappingUpdating or state.workerUpdating or (state.readingDepth or 0) > 0 then return true end
    local ok, failure = SyncWorker()
    if not ok then Engine.Disable(); Report(failure) end
    return ok, failure
end
SyncRange = function()
    if not state.active or not state.rangeService then return StopRange() end
    local candidates = false
    for barId = 1, 6 do
        if IsActive(barId) then
            for index = 1, 12 do
                if state.views[barId].buttons[index].read.hasRange then candidates = true; break end
            end
        end
        if candidates then break end
    end
    if not candidates then return StopRange() end
    local previousThis, previousEvent, previousArg = this, event, arg1
    local ran, target = pcall(state.rangeService.HasTarget)
    this, event, arg1 = previousThis, previousEvent, previousArg
    if not ran then return false, target end
    local wanted = target == true
    if wanted ~= (state.rangeTracking == true) then state.rangeElapsed = 0 end
    state.rangeTracking = wanted
    return SyncWorker()
end
local function SyncBehaviorDemand(force, prospectiveBar)
    local service = state.behaviorService
    if not service then return true, false end
    local changed = state.behaviorMaskConfigured ~= true
    local demand = false
    for barId = 1, 6 do
        local live
        if state.enabling then live = state.active and RequestedBar(barId)
        else live = IsActive(barId) or barId == prospectiveBar and state.active and RequestedBar(barId) end
        live = live == true
        if state.behaviorLive[barId] ~= live then state.behaviorLive[barId], changed = live, true end
        local list = state.behaviorRules and state.behaviorRules[barId]
        if live and list and table.getn(list) > 0 then demand = true end
    end
    if changed or force then
        local ok, failure = ProtectedCall(service.Configure, state.behaviorRules, state.behaviorLive)
        state.behaviorMaskConfigured = ok == true
        if not ok then return false, failure end
        state.behaviorPendingConfig = true
    end
    state.behaviorDemand = demand
    return true, changed
end
local function ResolveMapping(barId)
    local offset, page = (barId - 1) * 12, barId
    if barId == 1 then
        offset, page = Bars.Services.ActionPageService.Read()
        if offset == nil then return nil, page end
    end
    if state.behaviorService then return state.behaviorService.Resolve(barId, offset, page) end
    return offset, page
end
local function SetMapping(view, offset, page, matched)
    for index = 1, 12 do view.buttons[index].action = offset + index end
    local ok, failure = view:SetPage(page, offset, matched)
    if ok == false then return false, failure or "The action bar source could not be displayed." end
    view.offset, view.page, view.behaviorMatched = offset, page, matched
    if view.id == 1 or view == state.view then state.actionOffset, state.page = offset, page end
    return true
end
local function ReadMappings(name, refreshAll)
    local ok, changed = SyncBehaviorDemand()
    if not ok then return false, changed end
    if state.behaviorService and (behaviorEvents[name] or state.behaviorPendingConfig) then
        local snapshotEvent = state.behaviorPendingConfig and "BOOTY_ACTIONBARS_BEHAVIOR_CONFIG" or name
        ok, changed = state.behaviorService.Refresh(snapshotEvent)
        if not ok then return false, changed end
        state.behaviorPendingConfig = nil
    end
    local anyChanged = false
    for barId = 1, 6 do
        state.mappingChanged[barId], state.mappingCaptions[barId] = nil, nil
        if IsActive(barId) then
            local view = state.views[barId]
            local offset, page, matched = ResolveMapping(barId)
            if offset == nil then return false, page end
            state.mappingOffsets[barId], state.mappingPages[barId], state.mappingMatches[barId] = offset, page, matched
            state.mappingChanged[barId] = view.offset ~= offset
            state.mappingCaptions[barId] = view.page ~= page or view.behaviorMatched ~= matched
            if state.mappingChanged[barId] then anyChanged = true end
        end
    end
    -- Every affected old input is cancelled before any bar takes its new source.
    for barId = 1, 6 do
        if state.mappingChanged[barId] then
            local view = state.views[barId]
            view.offset, view.page, view.behaviorMatched = nil, nil, nil
            if barId == 1 then state.actionOffset, state.page = nil, nil end
            ok, changed = view:Suspend(true)
            if ok == false then return false, changed or "The old action source could not be suspended." end
        end
    end
    for barId = 1, 6 do
        if state.mappingChanged[barId] or state.mappingCaptions[barId] then
            ok, changed = SetMapping(state.views[barId], state.mappingOffsets[barId], state.mappingPages[barId], state.mappingMatches[barId])
            if not ok then return false, changed end
        end
    end
    for barId = 1, 6 do
        if IsActive(barId) and (state.mappingChanged[barId] or refreshAll) then
            ok, changed = RefreshView(state.views[barId], "Read", state.mappingChanged[barId] or name == "PLAYER_ENTERING_WORLD")
            if not ok then return false, changed end
        end
    end
    return true, anyChanged
end
UpdateMappings = function(name, refreshAll)
    local previousThis, previousEvent, previousArg = this, event, arg1
    state.mappingUpdating = true
    local ran, ok, result
    for pass = 1, 2 do
        state.mappingPending, state.mappingPendingRefresh = nil, nil
        ran, ok, result = pcall(ReadMappings, name, refreshAll)
        if not ran or not ok or not state.mappingPending then break end
        name = "BOOTY_ACTIONBARS_BEHAVIOR_CONFIG"
        refreshAll = refreshAll or state.mappingPendingRefresh
    end
    if ran and ok and state.mappingPending then ok, result = false, "Action bar source changes did not settle after two updates." end
    if not ran or not ok then
        for barId = 1, 6 do
            if state.mappingChanged[barId] or state.mappingCaptions[barId] then
                local view = state.views[barId]
                if view then view.offset, view.page, view.behaviorMatched = nil, nil, nil end
                if barId == 1 then state.actionOffset, state.page = nil, nil end
            end
        end
    end
    state.mappingUpdating = nil
    state.mappingPending, state.mappingPendingRefresh = nil, nil
    this, event, arg1 = previousThis, previousEvent, previousArg
    if not ran then return false, ok end
    return ok, result
end
local function Binding(view, index, barId)
    local previousEvent, previousArg = event, arg1
    local key
    if barId == 1 then key = state.service.GetBindingKeys(index)
    else key = state.service.GetBindingKeys(index, barId) end
    -- A client hook may change legacy globals before formatting the label.
    this, event, arg1 = view.buttons[index], previousEvent, previousArg
    view:Binding(index, key)
    return true
end
local function ViewBindings(view, barId)
    for index = 1, 12 do
        local ok, failure = Context(view, index, Binding, view, index, barId)
        if not ok then return false, failure end
    end
    return true
end
local function RefreshBindings()
    for barId = 1, 6 do
        if IsActive(barId) then
            local ok, failure = ViewBindings(state.views[barId], barId)
            if not ok then return false, failure end
        end
    end
    return true
end
local function Unsubscribe()
    if not state.subscribed then return end
    for _, name in ipairs(events) do BootyLib.Unsubscribe(name, Engine) end
    state.subscribed = false
    state.cursorGridDepth = 0
end
local function ActivityChanged()
    -- Runtime may synchronize native leases here before the outer visibility
    -- observer drains. Publish the completed activation's actual identities.
    PublishVisibility()
    if state.activityObserver then return state.activityObserver(state.active) end
    return true
end
local function PrepareDisplay(view)
    -- Apply saved visibility before page text, forced action reads and binding
    -- formatting, including reactivation of an already pooled hidden view.
    local editor = Bars.Modules.Editor
    if editor then
        local layout, failure = editor.GetLayout(view.id)
        if not layout then return false, failure end
        local ok, reason = view:SetDisplay(layout)
        if ok == false then return false, reason end
    end
    if view.SetCursorGrid then return view:SetCursorGrid((state.cursorGridDepth or 0) > 0) end
    return true
end
local function HideView(view)
    local firstFailure
    if Bars.Modules.Editor and not (view == state.view and state.hidingMain) then
        local id = view.id or (view == state.view and 1)
        local ok, failure = ProtectedCall(Bars.Modules.Editor.OnBarHidden, id)
        if not ok then firstFailure = failure end
    end
    local ok, failure = ProtectedCall(view.Hide, view)
    if not ok and view.frame and type(view.frame.Hide) == "function" then
        -- Even a broken suspension must not leave native child animations
        -- visible. Preserve the first failure after attempting the parent.
        ProtectedCall(view.frame.Hide, view.frame)
    end
    return firstFailure == nil and ok, firstFailure or failure
end
function Engine.SetActivityObserver(callback)
    state.activityObserver = callback
end
local function SetCustomActive(barId, value, revise)
    if (state.customActive[barId] == true) == value then return end
    state.customActive[barId] = value and true or nil
    state.customActiveCount = state.customActiveCount + (value and 1 or -1)
    if revise then state.customRevision = state.customRevision + 1 end
end
local function HideCustoms()
    local firstFailure
    state.hidingCustoms = true
    for barId = 2, 6 do
        SetCustomActive(barId, false, false)
        if state.views[barId] then
            local ok, failure = HideView(state.views[barId])
            if not ok and not firstFailure then firstFailure = failure end
        end
    end
    state.hidingCustoms = nil
    return firstFailure == nil, firstFailure
end
local function Configure(customBars)
    if customBars == nil then return true end
    if type(customBars) ~= "table" then return false, "Invalid custom action bar configuration." end
    for barId, enabled in pairs(customBars) do
        if not ValidBar(barId) or barId < 2 or enabled ~= true then
            return false, "Custom action bars must be enabled identities 2 through 6."
        end
    end
    for barId = 2, 6 do
        local enabled = customBars[barId] == true
        if (state.customBars[barId] == true) ~= enabled then
            state.customBars[barId] = enabled and true or nil
            state.customConfiguredCount = state.customConfiguredCount + (enabled and 1 or -1)
            state.customRevision = state.customRevision + 1
        end
    end
    return true
end
function Engine.ConfigureCustomBars(customBars)
    return Configure(customBars)
end
function Engine.ConfigureBehaviors(rules)
    local factory = Bars.Services.BehaviorService
    if not factory then
        if rules == nil or type(rules) == "table" and next(rules) == nil then return true end
        return false, "Action bar behaviors are unavailable."
    end
    local previousThis, previousEvent, previousArg = this, event, arg1
    local ran, valid, failure = pcall(factory.Validate, rules)
    this, event, arg1 = previousThis, previousEvent, previousArg
    if not ran then return false, tostring(valid) end
    if not valid then return false, failure end
    local equal = factory.Equal(rules, state.behaviorConfiguredValues)
    if not state.behaviorService and equal then state.behaviorRules = rules; return true end
    local candidate
    if not equal then
        candidate, failure = factory.Copy(rules)
        if not candidate then return false, failure end
    end
    if not state.behaviorService then
        local created, service = pcall(factory.Create)
        this, event, arg1 = previousThis, previousEvent, previousArg
        if not created then return false, tostring(service) end
        state.behaviorService = service
    end
    local previous = state.behaviorRules
    state.behaviorRules = rules
    local ok, reason = SyncBehaviorDemand(not equal)
    if not ok then state.behaviorRules = previous; return false, reason end
    if not equal then
        state.behaviorConfiguredValues = candidate
        state.customRevision = state.customRevision + 1
    end
    if state.mappingUpdating then state.mappingPending = true; return true end
    if not state.active or not state.behaviorPendingConfig then return true end
    ok, reason = UpdateMappings("BOOTY_ACTIONBARS_BEHAVIOR_CONFIG")
    if ok then ok, reason = FlushMacroChanges() end
    if ok then ok, reason = SyncRange() end
    if not ok then
        local cleaned, cleanupFailure = Engine.Disable()
        if not cleaned then reason = tostring(reason) .. " Cleanup: " .. tostring(cleanupFailure) end
        Report(reason); return false, reason
    end
    return true
end
function Engine.ConfigureMainVisibility(shown)
    if type(shown) ~= "boolean" then return false, "Choose whether to show the main action bar." end
    if state.mainShown ~= shown then
        state.mainShown = shown
        state.customRevision = state.customRevision + 1
    end
    return true
end
local function CreateView(barId)
    if state.views[barId] then return state.views[barId] end
    local ok, view = pcall(Bars.Modules.ActionBar.Create, {Click = Engine.MouseClick, Pickup = Engine.Pickup,
        Place = Engine.Place, OnHide = Engine.OnHide, OnShow = Engine.OnShow,
        Tooltip = Engine.Tooltip, LeaveTooltip = Engine.LeaveTooltip}, barId)
    if not ok then
        state.creationFailure = tostring(view)
        return nil, state.creationFailure
    end
    state.views[barId] = view
    if barId == 1 then state.view = view end
    return view
end
local function SetMergeView(view, plan) return view:SetMergeGroup(plan.host, plan.ordinal, plan.members) end
local function ComposeMerges()
    local factory = Bars.Services.BarMerging
    if not factory then return true end
    if state.mergeDirty then
        state.mainActive = false
        for id = 2, 6 do SetCustomActive(id, false, false) end
    end
    for host = 1, 6 do
        if MergeOwner(host) == host then
            local ids = state.mergeMemberIDs[host] or {}; state.mergeMemberIDs[host] = ids
            local members, failure = factory.Members(state.merges, host, ids)
            if not members then return false, failure end
            local needed = state.active and RequestedBar(host)
            for _, id in ipairs(ids) do if state.views[id] then needed = true end end
            if needed then
                local views = state.mergeViewLists[host] or {}; state.mergeViewLists[host] = views
                for index, id in ipairs(ids) do
                    local view; view, failure = CreateView(id)
                    if not view then return false, failure end
                    views[index] = view
                end
                for index = table.getn(ids) + 1, table.getn(views) do views[index] = nil end
            end
        end
    end
    for id = 1, 6 do
        local view = state.views[id]
        if view then
            local owner = MergeOwner(id)
            local plan = state.mergePlans[id] or {}; state.mergePlans[id] = plan
            plan.host, plan.ordinal, plan.members = state.views[owner], state.mergeOrdinals[id] or 0, state.mergeViewLists[owner]
            local ok, failure = ProtectedCall(SetMergeView, view, plan)
            if not ok then return false, failure end
        end
    end
    state.mergeDirty = nil
    return true
end
local function ParentVisible()
    if not UIParent or type(UIParent.IsVisible) ~= "function" then return true end
    local value = UIParent:IsVisible()
    return value ~= nil and value ~= false and value ~= 0
end
local function ContextHidden() return Engine.OnContextHide() end
local function ContextShown() return Engine.OnContextShow() end
local function CreateDriver()
    if state.driverFailure then return false, state.driverFailure end
    if not state.driver then
        state.driver = Bars.UI.Components.CreateContainer("BootyActionBarsContextDriver", UIParent)
    end
    local frame = state.driver
    if not state.driverReady then
        frame:Hide(); frame:SetWidth(1); frame:SetHeight(1); frame:SetAlpha(0)
        frame:EnableMouse(false); frame:SetPoint("CENTER", UIParent, "CENTER", 0, 0)
        frame:SetScript("OnHide", ContextHidden); frame:SetScript("OnShow", ContextShown)
        state.driverReady = true
    end
    return true
end
SyncContext = function()
    local wanted = state.requested and (not RequestedBar(1) or MergeOwner(1) ~= 1)
    if wanted then
        local ok, failure = ProtectedCall(CreateDriver)
        if not ok then state.driverFailure = failure; return false, failure end
        return ProtectedCall(state.driver.Show, state.driver)
    end
    if state.driver then
        local rangeOK, rangeFailure = true, nil
        if state.workerFrame == state.driver then rangeOK, rangeFailure = StopWorker() end
        state.hidingDriver = true
        local ok, failure = ProtectedCall(state.driver.Hide, state.driver)
        state.hidingDriver = nil
        return rangeOK and ok, rangeFailure or failure
    end
    return true
end
SyncMain = function()
    if not RequestedBar(1) then
        state.mainActive = false
        if state.view then
            state.hidingMain = true
            local ok, failure = HideView(state.view)
            state.hidingMain = nil
            if not ok then return false, failure end
        end
        return true
    end
    local view, failure = CreateView(1)
    if not view then return false, failure end
    if state.mainActive and view.frame:IsVisible() then return true end
    local ok, reason = ProtectedCall(view.Suspend, view)
    if ok then ok, reason = ProtectedCall(PrepareDisplay, view) end
    if not ok then return false, reason end
    state.showingMain = true
    ok, reason = ProtectedCall(view.Show, view)
    state.showingMain = nil
    if not ok then return false, reason end
    if not view.frame:IsVisible() then state.mainActive = false; return true end
    state.mainActive = true
    ok, reason = UpdateMappings()
    if ok and not reason then ok, reason = RefreshView(view, "Read", true) end
    if ok then ok, reason = ViewBindings(view, 1) end
    return ok, reason
end
local function ActivateCustom(barId, revise)
    local view, failure = CreateView(barId)
    if not view then return false, failure end
    if state.customActive[barId] then return true end
    local demand, demandFailure = SyncBehaviorDemand(false, barId)
    if not demand then return false, demandFailure end
    if state.behaviorService and state.behaviorPendingConfig then
        demand, demandFailure = ProtectedCall(state.behaviorService.Refresh, "BOOTY_ACTIONBARS_BEHAVIOR_CONFIG")
        if not demand then return false, demandFailure end
        state.behaviorPendingConfig = nil
    end
    local offset, page, matched = ResolveMapping(barId)
    if offset == nil then return false, page end
    local suspended, suspendFailure = ProtectedCall(view.Suspend, view)
    if not suspended then return false, suspendFailure end
    local prepared, prepareFailure = ProtectedCall(PrepareDisplay, view)
    if not prepared then return false, prepareFailure end
    local previousThis, previousEvent, previousArg = this, event, arg1
    view.offset, view.page, view.behaviorMatched = nil, nil, nil
    local ran, ok, reason = pcall(SetMapping, view, offset, page, matched)
    this, event, arg1 = previousThis, previousEvent, previousArg
    if not ran or not ok then view.offset, view.page, view.behaviorMatched = nil, nil, nil end
    if not ran then return false, ok end
    if not ok then return false, reason end
    ok, reason = RefreshView(view, "Read", true)
    if not ok then return false, reason end
    ok, reason = ViewBindings(view, barId)
    if not ok then return false, reason end
    SetCustomActive(barId, true, revise)
    ok, reason = ProtectedCall(view.Show, view)
    if not ok then return false, reason end
    if not view.frame:IsVisible() then
        SetCustomActive(barId, false, revise)
        local suspended, failure = ProtectedCall(view.Suspend, view)
        if not suspended then return false, failure end
    end
    return true
end
local function SyncCustoms(revise)
    for barId = 2, 6 do
        if RequestedBar(barId) and state.active then
            local ok, failure = ActivateCustom(barId, revise)
            if not ok then return false, failure end
        elseif state.views[barId] then
            SetCustomActive(barId, false, false)
            state.hidingCustoms = true
            local ok, failure = HideView(state.views[barId])
            state.hidingCustoms = nil
            if not ok then return false, failure end
        end
    end
    return true
end
local function RefreshSlot(slot)
    if type(slot) ~= "number" or slot < 1 or slot > 120 or slot ~= math.floor(slot) then return true end
    for barId = 1, 6 do
        if IsActive(barId) then
            local view = state.views[barId]
            local index = view.offset and slot - view.offset
            if Valid(index) then
                local ok, failure = Refresh(view, index, "Read")
                if not ok then return false, failure end
            end
        end
    end
    return true
end
FlushMacroChanges = function()
    -- Provider cache fills can notify after an earlier field was already read.
    -- Coalesce every affected slot, including the current partial/full read.
    for pass = 1, 2 do
        if not state.macroPending then return true end
        state.macroPending = nil
        for slot = 1, 120 do
            if state.macroDirty[slot] then
                state.macroDirty[slot] = nil
                local ok, failure = RefreshSlot(slot)
                if not ok then return false, failure end
            end
        end
    end
    for slot = 1, 120 do
        if state.macroDirty[slot] then return false, "Macro updates did not settle after refreshing actions." end
    end
    return true
end
function Engine.MacroEvent(slot)
    Engine.HandleEvent("BOOTY_ACTIONBARS_MACRO_UPDATE", slot)
end
function Engine.HandleEvent(name, unit)
    if not state.active then return end
    if state.composing then state.mergePendingRefresh = true; return end
    if name == "ACTIONBAR_SHOWGRID" or name == "ACTIONBAR_HIDEGRID" then
        -- Vanilla sends a balanced grid request for action, spell, item and
        -- macro cursor gestures. Reveal the existing drop targets without a
        -- cursor timer or rebuilding actions on every mouse movement.
        local before = state.cursorGridDepth or 0
        local depth = math.max(0, before + (name == "ACTIONBAR_SHOWGRID" and 1 or -1))
        state.cursorGridDepth = depth
        if (before > 0) ~= (depth > 0) then
            for barId = 1, 6 do
                local view = state.views[barId]
                if IsActive(barId) and view.SetCursorGrid then
                    local ok, failure = ProtectedCall(view.SetCursorGrid, view, depth > 0)
                    if not ok then Engine.Disable(); Report(failure); return end
                end
            end
        end
        return
    end
    if name == "BOOTY_ACTIONBARS_MACRO_UPDATE" and ((state.readingDepth or 0) > 0 or state.mappingUpdating) then
        if type(unit) == "number" and unit >= 1 and unit <= 120 and unit == math.floor(unit) then
            state.macroDirty[unit] = true
            state.macroPending = true
        end
        return
    end
    if state.mappingUpdating then
        if behaviorEvents[name] then state.mappingPending = true end
        if name ~= "BOOTY_ACTIONBARS_SHARED_UPDATE" and name ~= "BOOTY_ACTIONBARS_RANGE_UPDATE" then
            state.mappingPending, state.mappingPendingRefresh = true, true
        end
        return
    end
    if name == "BOOTY_ACTIONBARS_SHARED_UPDATE" then SharedUpdate(unit); return end
    if name == "BOOTY_ACTIONBARS_RANGE_UPDATE" then RangeUpdate(unit); return end
    local ok, failure = true, nil
    if name == "BOOTY_ACTIONBARS_MACRO_UPDATE" then ok, failure = RefreshSlot(unit)
    elseif name == "ADDON_LOADED" then
        if state.service.RefreshMacroProvider then ok, failure = state.service.RefreshMacroProvider() end
        if ok then ok, failure = RefreshAll("Read") end
    elseif pageEvents[name] or name == "BOOTY_ACTIONBARS_BEHAVIOR_CONFIG" then
        ok, failure = UpdateMappings(name)
    elseif name == "PLAYER_ENTERING_WORLD" then
        ok, failure = UpdateMappings(name, true)
    elseif name == "UPDATE_BINDINGS" then ok, failure = RefreshBindings()
    elseif name == "ACTIONBAR_SLOT_CHANGED" then
        if unit == nil or type(unit) == "number" and unit <= 0 then
            ok, failure = RefreshAll("Read")
        elseif type(unit) == "number" then
            for barId = 1, 6 do
                if IsActive(barId) then
                    local view = state.views[barId]
                    local index = view.offset and unit - view.offset
                    if Valid(index) then
                        ok, failure = Refresh(state.views[barId], index, "Read")
                        if not ok then break end
                    end
                end
            end
        end
    elseif name == "ACTIONBAR_UPDATE_COOLDOWN" or name == "UPDATE_INVENTORY_ALERTS" then
        ok, failure = RefreshAll("ReadAvailability")
    elseif name == "PLAYER_TARGET_CHANGED" or name == "PLAYER_AURAS_CHANGED" then
        -- Hooked macro icons/cooldowns may change without a native slot event.
        if name == "PLAYER_AURAS_CHANGED" and state.behaviorDemand then ok, failure = UpdateMappings(name, true)
        else ok, failure = RefreshAll("Read") end
    elseif name == "ACTIONBAR_UPDATE_USABLE" then
        ok, failure = RefreshAll("ReadUsability")
    elseif stateEvents[name] then ok, failure = RefreshAll("ReadState")
    elseif name == "BAG_UPDATE" or name == "UNIT_INVENTORY_CHANGED" and unit == "player" then
        ok, failure = RefreshAll("Read")
    end
    if ok then ok, failure = FlushMacroChanges() end
    if ok then ok, failure = SyncRange() end
    if not ok then Engine.Disable(); Report(failure or "An action could not be refreshed.") end
end
local function Event() Engine.HandleEvent(event, arg1) end
local function Subscribe()
    if state.subscribed then return end
    if state.service.ReadCursorGrid then state.cursorGridDepth = state.service.ReadCursorGrid() end
    for _, name in ipairs(events) do BootyLib.Subscribe(name, Engine, Event) end
    state.subscribed = true
    if (state.cursorGridDepth or 0) > 0 then
        for barId = 1, 6 do
            local view = state.views[barId]
            if IsActive(barId) and view.SetCursorGrid then
                local ok, failure = ProtectedCall(view.SetCursorGrid, view, true)
                if not ok then return false, failure end
            end
        end
    end
    return true
end
local function SyncSubscriptions()
    local configured, reason = SyncBehaviorDemand()
    if not configured then return false, reason end
    local wanted = state.active and (state.mainActive or state.customActiveCount > 0)
    if wanted then
        local subscribed, failure = Subscribe()
        if subscribed == false then return false, failure end
        if not state.macroEnabled and state.service.EnableMacroEvents then
            local ok, failure = ProtectedCall(state.service.EnableMacroEvents, Engine.MacroEvent)
            if not ok then return false, failure end
            state.macroEnabled = true
        end
    else
        Unsubscribe()
        if state.macroEnabled and state.service and state.service.DisableMacroEvents then
            local ok, failure = ProtectedCall(state.service.DisableMacroEvents)
            if not ok then return false, failure end
        end
        state.macroEnabled = false
    end
    return true
end
function Engine.OnHide(barId)
    barId = barId or 1
    if state.composing then return true end
    local firstFailure
    local intentional = barId == 1 and state.hidingMain
    local binding = Bars.Modules.BindingEditor
    if binding and binding.IsEditing() then
        local ok, failure = ProtectedCall(binding.Cancel)
        if not ok then firstFailure = failure end
    end
    if Bars.Modules.Editor and not intentional then
        local ok, failure = ProtectedCall(Bars.Modules.Editor.OnBarHidden, barId)
        if not ok and not firstFailure then firstFailure = failure end
    end
    if barId ~= 1 or MergeOwner(barId) ~= barId and not state.contextHiding then
        if ValidBar(barId) and state.views[barId] then
            if state.requested and state.active and not ParentVisible() then
                local ok, failure = Engine.OnContextHide()
                return firstFailure == nil and ok, firstFailure or failure
            end
            if barId == 1 then state.mainActive = false else SetCustomActive(barId, false, not state.hidingCustoms) end
            local ok, failure = ProtectedCall(state.views[barId].Suspend, state.views[barId])
            if ok then ok, failure = SyncSubscriptions() end
            if ok then ok, failure = SyncRange() end
            return firstFailure == nil and ok, firstFailure or failure
        end
        return firstFailure == nil, firstFailure
    end
    state.mainActive = false
    if intentional then
        local ok, failure = true, nil
        if state.view then ok, failure = ProtectedCall(state.view.Suspend, state.view) end
        if ok then ok, failure = SyncSubscriptions() end
        if ok then ok, failure = SyncRange() end
        if ok and Bars.Modules.Editor then ok, failure = ProtectedCall(Bars.Modules.Editor.Sync) end
        return firstFailure == nil and ok, firstFailure or failure
    end
    state.active = false
    local stopped, stopFailure = StopRange()
    if not stopped and not firstFailure then firstFailure = stopFailure end
    Unsubscribe()
    if state.service and state.service.DisableMacroEvents then state.service.DisableMacroEvents() end
    state.macroEnabled = false
    if state.cleaning then return firstFailure == nil, firstFailure end
    local ok, failure = ProtectedCall(ActivityChanged)
    if not ok and not firstFailure then firstFailure = failure end
    if state.view then
        local suspended, failure = ProtectedCall(state.view.Suspend, state.view)
        if not suspended and not firstFailure then firstFailure = failure end
    end
    local hidden, failure = HideCustoms()
    if not hidden and not firstFailure then firstFailure = failure end
    if firstFailure then Report(firstFailure) end
    return firstFailure == nil, firstFailure
end
function Engine.OnContextHide()
    if state.hidingDriver or state.cleaning or not state.requested or not state.active then return true end
    -- Keep a shown lifecycle frame available for the parent's eventual OnShow.
    -- Native cooldown animations and all action subscriptions stop meanwhile.
    state.contextHiding = true
    local ok, failure = Engine.OnHide(1)
    state.contextHiding = nil
    return ok, failure
end
function Engine.OnContextShow()
    if state.hidingDriver or state.enabling or not state.requested or state.active then return true end
    local ok, failure = Engine.Enable()
    if not ok then Report(failure) end
    return ok, failure
end
function Engine.OnShow(barId)
    barId = barId or 1
    if state.enabling or state.showingMain or state.composing then return end
    if barId == 1 and MergeOwner(1) ~= 1 then
        if not state.active and state.requested and ParentVisible() then return Engine.OnContextShow() end
        if not state.active or not RequestedBar(1) or state.mainActive then return end
        local ok, failure = SyncMain()
        if ok and Bars.Modules.Editor then ok, failure = ProtectedCall(Bars.Modules.Editor.Sync) end
        if ok then ok, failure = SyncSubscriptions() end
        if ok then ok, failure = SyncRange() end
        if not ok then Engine.Disable(); Report(failure) end
        return ok, failure
    end
    if barId ~= 1 then
        if not state.active and state.requested and ParentVisible() then return Engine.OnContextShow() end
        if not ValidBar(barId) or not state.active or not RequestedBar(barId) or state.customActive[barId] then return end
        local ok, failure = ActivateCustom(barId, true)
        if ok and Bars.Modules.Editor then ok, failure = ProtectedCall(Bars.Modules.Editor.Sync) end
        if ok then ok, failure = SyncSubscriptions() end
        if ok then ok, failure = SyncRange() end
        if not ok then Engine.Disable(); Report(failure) end
        return
    end
    if not RequestedBar(1) or not state.requested or state.active then return end
    local ok, failure = Engine.Enable()
    if not ok then Report(failure) end
end
local function Activate(wasActive)
    state.active = ParentVisible()
    local ok, failure = true, nil
    if state.hasMerges or state.mergeDirty then
        state.composing = true
        ok, failure = ComposeMerges()
        state.composing = nil
    end
    if ok then ok, failure = SyncBehaviorDemand() end
    if ok and state.active and state.behaviorService and state.behaviorPendingConfig then
        ok, failure = ProtectedCall(state.behaviorService.Refresh, "BOOTY_ACTIONBARS_BEHAVIOR_CONFIG")
        if ok then state.behaviorPendingConfig = nil; state.behaviorActivationPending = true end
    end
    if ok then ok, failure = SyncContext() end
    if ok and state.hasMerges and state.active then
        -- A custom primary must be visible before its main-source child is
        -- activated. Every source still uses its original twelve-slot pipeline.
        for id = 2, 6 do
            if MergeOwner(id) == id and RequestedBar(id) then
                ok, failure = ActivateCustom(id, wasActive)
                if not ok then break end
            end
        end
    end
    if ok then ok, failure = SyncMain() end
    if ok and RequestedBar(1) and not state.mainActive then state.active = false end
    if ok then ok, failure = SyncCustoms(wasActive) end
    if ok and state.behaviorActivationPending then
        ok, failure = UpdateMappings()
        state.behaviorActivationPending = nil
    end
    if ok then ok, failure = SyncSubscriptions() end
    if ok and state.mergePendingRefresh then
        state.mergePendingRefresh = nil
        ok, failure = UpdateMappings("PLAYER_ENTERING_WORLD", true)
    end
    if ok then ok, failure = FlushMacroChanges() end
    return ok, failure
end
function Engine.Enable(customBars)
    if state.creationFailure then return false, state.creationFailure end
    local ok, failure = Configure(customBars)
    if not ok then return false, failure end
    local UI = Bars.UI.Components
    if type(UI.CreateModel) ~= "function" or type(HasAction) ~= "function" or type(UseAction) ~= "function"
        or type(GetActionTexture) ~= "function" or type(GetActionCooldown) ~= "function" or type(CooldownFrame_SetTimer) ~= "function" then
        return false, "The test bar needs the current BootyLib and native action/cooldown APIs."
    end
    state.requested = true
    if not state.service then state.service = Bars.Services.ActionService.Create() end
    if not state.rangeService and Bars.Services.RangeService then state.rangeService = Bars.Services.RangeService.Create() end
    local wasActive = state.active
    state.enabling = true
    ok, failure = ProtectedCall(Activate, wasActive)
    state.enabling = nil
    if not ok then Engine.Disable(); return false, failure end
    ok, failure = SyncRange()
    if not ok then Engine.Disable(); return false, failure end
    state.failure = nil
    if wasActive ~= state.active then ok, failure = ProtectedCall(ActivityChanged) end
    if not ok then Engine.Disable(); return false, failure end
    return true
end
function Engine.SetMainVisible(shown)
    local ok, failure = Engine.ConfigureMainVisibility(shown)
    if not ok or not state.requested then return ok, failure end
    return Engine.Enable()
end
function Engine.Disable()
    state.requested, state.active, state.mainActive = false, false, false
    local stopped, firstFailure = StopRange()
    if state.service and state.service.DisableMacroEvents then state.service.DisableMacroEvents() end
    state.macroEnabled = false
    for slot = 1, 120 do state.macroDirty[slot] = nil end
    state.macroPending = nil
    Unsubscribe()
    local ok, activityFailure = ProtectedCall(ActivityChanged)
    if not ok and not firstFailure then firstFailure = activityFailure end
    local binding = Bars.Modules.BindingEditor
    if binding and binding.IsEditing() then
        local ended, failure = ProtectedCall(binding.Cancel)
        if not ended and not firstFailure then firstFailure = failure end
    end
    state.cleaning = true
    if state.view then
        local hidden, failure = HideView(state.view)
        if not hidden and not firstFailure then firstFailure = failure end
    end
    local hidden, failure = HideCustoms()
    if not hidden and not firstFailure then firstFailure = failure end
    state.cleaning = nil
    local driverHidden, driverFailure = SyncContext()
    if not driverHidden and not firstFailure then firstFailure = driverFailure end
    if firstFailure then Report(firstFailure) end
    return firstFailure == nil, firstFailure
end
local function InputView(barId, index)
    if state.mappingUpdating or state.enabling then return nil end
    local binding = Bars.Modules.BindingEditor
    if binding and binding.IsEditing() then return nil end
    local editor = Bars.Modules.Editor
    if editor and editor.IsEditing() then return nil end
    if not ValidBar(barId) or not Valid(index) or not IsActive(barId) then return nil end
    local view = state.views[barId]
    if view and view.buttons[index].emptyHidden == true then return nil end
    return view
end
function Engine.Tooltip(index, barId)
    local view = InputView(barId or 1, index)
    if not view then return false end
    if state.service.Tooltip then return Context(view, index, state.service.Tooltip, view.buttons[index].action, view.buttons[index]) end
    return false
end
function Engine.LeaveTooltip(index, barId)
    local view = state.views[barId or 1]
    if not view or not Valid(index) or not state.service then return false end
    if state.service.LeaveTooltip then return Context(view, index, state.service.LeaveTooltip, view.buttons[index].action, view.buttons[index]) end
    return false
end
local function UseButton(barId, index, keyState)
    local view = InputView(barId, index)
    if not view then return false end
    local button = view.buttons[index]
    if keyState == "down" then view:SetPressed(index, true); return true end
    if keyState ~= "up" or not button.pressed then return false end
    view:SetPressed(index, false)
    return Context(view, index, state.service.Use, button.action, false, false)
end
function Engine.UseButton(index, keyState)
    return UseButton(1, index, keyState)
end
function Engine.UseCustomButton(barId, index, keyState)
    if not ValidBar(barId) or barId == 1 then return false end
    return UseButton(barId, index, keyState)
end
function Engine.MouseClick(index, mouseButton, skip, barId)
    local view = InputView(barId or 1, index)
    if not view or skip then return false end
    return Context(view, index, state.service.Use, view.buttons[index].action, true, mouseButton == "RightButton")
end
function Engine.Pickup(index, barId)
    local view = InputView(barId or 1, index)
    if not view then return false end
    return Context(view, index, state.service.Pickup, view.buttons[index].action)
end
function Engine.Place(index, barId)
    local view = InputView(barId or 1, index)
    if not view then return false end
    local ok, failure = Context(view, index, state.service.Place, view.buttons[index].action)
    if ok then
        local refreshed, reason = Refresh(view, index, "Read")
        if refreshed then refreshed, reason = FlushMacroChanges() end
        if refreshed then refreshed, reason = SyncRange() end
        if not refreshed then Engine.Disable(); Report(reason); return false, reason end
    end
    return ok, failure
end
function Engine.MarkLayoutChanged()
    state.customRevision = state.customRevision + 1
    return state.customRevision
end
function Engine.GetState() return state end
PublishVisibility = function()
    liveMain = state.active == true and state.mainActive == true and state.view ~= nil
    local mask, bit = 0, 1
    for barId = 2, 6 do
        local live = state.active == true and state.customActive[barId] == true and state.views[barId] ~= nil
        liveCustom[barId] = live
        if live then mask = mask + bit end
        bit = bit * 2
    end
    return liveMain, mask
end
function Engine.GetLiveVisibility()
    -- A settled cached snapshot, not a frame inspection. The shared table is
    -- read-only to callers and its identities do not describe action sources.
    return liveMain, liveCustom
end
function Engine.SetVisibilityObserver(callback)
    if callback ~= nil and type(callback) ~= "function" then return false, "Expected a visibility observer or nil." end
    local main, mask = PublishVisibility()
    visibilityObserver, observedMain, observedCustom = callback, main, mask
    return true
end
local function NotifyVisibility()
    if visibilityDepth > 0 then return true end
    -- A nested completed lifecycle may publish its newest snapshot during a
    -- callback; only the outer notifier delivers the next transition.
    if notifyingVisibility then PublishVisibility(); return true end
    local firstFailure
    for pass = 1, 2 do
        local main, mask = PublishVisibility()
        if main == observedMain and mask == observedCustom then return firstFailure == nil, firstFailure end
        observedMain, observedCustom = main, mask
        if visibilityObserver then
            notifyingVisibility = true
            local ok, failure = ProtectedCall(visibilityObserver, main, liveCustom)
            notifyingVisibility = false
            if not ok and not firstFailure then firstFailure = failure end
        end
    end
    local main, mask = PublishVisibility()
    if main ~= observedMain or mask ~= observedCustom then
        -- Latch the latest state before reporting so error cleanup cannot
        -- replay a transition which already failed to settle.
        observedMain, observedCustom = main, mask
        local failure = "Ordinary action bar visibility did not settle after two updates."
        firstFailure = firstFailure and tostring(firstFailure) .. " Visibility: " .. failure or failure
    end
    return firstFailure == nil, firstFailure
end
local function SettledVisibility(callback, first, second)
    visibilityDepth = visibilityDepth + 1
    local previousThis, previousEvent, previousArg = this, event, arg1
    local ran, result, failure = pcall(callback, first, second)
    this, event, arg1 = previousThis, previousEvent, previousArg
    visibilityDepth = visibilityDepth - 1
    if not ran then result, failure = false, tostring(result) end
    local notified, reason = ProtectedCall(NotifyVisibility)
    if not notified then
        if result ~= false then result, failure = false, reason
        else failure = tostring(failure) .. " Visibility: " .. tostring(reason) end
        ProtectedCall(Report, failure)
    end
    return result, failure
end
local function VisibilityBoundary(callback)
    return function(first, second) return SettledVisibility(callback, first, second) end
end
-- Native frame callbacks nest inside these public operations. Publish once
-- after the outer lifecycle settles, including partial failure and cleanup.
Engine.Enable = VisibilityBoundary(Engine.Enable)
Engine.Disable = VisibilityBoundary(Engine.Disable)
Engine.OnHide = VisibilityBoundary(Engine.OnHide)
Engine.OnShow = VisibilityBoundary(Engine.OnShow)
Engine.OnContextHide = VisibilityBoundary(Engine.OnContextHide)
Engine.OnContextShow = VisibilityBoundary(Engine.OnContextShow)
Engine.SetMainVisible = VisibilityBoundary(Engine.SetMainVisible)
if Bars.Modules.CooldownText then Bars.Modules.CooldownText.SetDemandObserver(Engine.CooldownChanged) end
