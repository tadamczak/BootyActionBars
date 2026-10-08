local Bars = BootyActionBars
local Runtime = {}
Bars.Core.Runtime = Runtime
local state = {initialized = false, stopped = false, batchDepth = 0}
local nativeEvents = {"ACTIONBAR_PAGE_CHANGED", "UPDATE_BONUS_ACTIONBAR", "UPDATE_SHAPESHIFT_FORMS", "ADDON_LOADED"}
local hiddenNativeBars = {[3] = true, [4] = true, [5] = true, [6] = true}
local function RefreshView()
    if state.view then state.view:Refresh() end
end
local function NativeFailure(failure)
    failure = tostring(failure or "Native action buttons could not be restored. Reload before continuing.")
    if state.nativeFailure ~= failure then BootyLib.Print("BootyActionBars: " .. failure) end
    state.nativeFailure = failure
    return false, failure
end
local function UnsubscribeNative()
    if not state.nativeSubscribed then return end
    for _, name in ipairs(nativeEvents) do BootyLib.Unsubscribe(name, Runtime) end
    state.nativeSubscribed = false
end
local function CallLifecycle(callback, first, second, third, fourth)
    local previousThis, previousEvent, previousArg = this, event, arg1
    local ran, ok, failure = pcall(callback, first, second, third, fourth)
    this, event, arg1 = previousThis, previousEvent, previousArg
    if not ran then return false, tostring(ok) end
    if ok == false then return false, failure or "Action bar layout could not be updated." end
    return true
end
local function ReleaseNative()
    -- Every owner must release even if another restoration fails.
    local ok, failure = CallLifecycle(Bars.Modules.NativeBar.Release)
    local artwork = Bars.Modules.NativeArtwork
    if artwork then
        local restored, reason = CallLifecycle(artwork.Release)
        if not restored then
            if ok then failure = reason else failure = tostring(failure) .. " Artwork: " .. tostring(reason) end
            ok = false
        end
    end
    local special = Bars.Modules.NativeSpecialBars
    if special then
        local restored, reason = CallLifecycle(special.Release)
        if not restored then
            if ok then failure = reason else failure = tostring(failure) .. " Special bars: " .. tostring(reason) end
            ok = false
        end
    end
    return ok, failure
end
local function AbortNative(failure)
    if state.store then state.store.nativeMainBarEnabled = false end
    UnsubscribeNative()
    local restored, reason = ReleaseNative()
    local utilities = Bars.Modules.NativeUtilityBars
    if utilities then
        local released, detail = CallLifecycle(utilities.Release)
        if not released then restored, reason = false, tostring(reason or "") .. " Utilities: " .. tostring(detail) end
    end
    if not restored and tostring(reason) ~= tostring(failure) then
        failure = tostring(failure) .. " Restoration: " .. tostring(reason)
    end
    return NativeFailure(failure)
end
local function NativeLeaseFailure(failure)
    -- Retained native Show can fail outside this product's event dispatcher.
    -- End every lease immediately rather than waiting for another client event.
    local _, diagnostic = AbortNative(failure)
    RefreshView()
    return true, diagnostic
end
local function NativeRequested()
    local store = state.store
    return store ~= nil and not state.stopped and store.nativeMainBarEnabled == true
end
local function SyncNativeSpecial(pet, stance)
    local controller = Bars.Modules.NativeSpecialBars
    if not controller then return true end
    local requested = NativeRequested()
    local ok, failure = CallLifecycle(controller.Sync, requested, requested, requested)
    if not ok then return AbortNative(failure) end
    return true
end
local function SpecialVisibilityChanged(pet, stance)
    -- A delivered visibility notification is independent of an optional native
    -- lease. Its refusal is reported and restored without disabling healthy BAB bars.
    local ok = SyncNativeSpecial(pet, stance)
    if not ok then RefreshView() end
    return true
end
local SyncNative
local function NativeEvent()
    -- Stock events may show native frames again; the independent master switch
    -- retains their visibility lease without reading BAB action mappings.
    SyncNative(); RefreshView()
end
SyncNative = function()
    state.utilityFailure = nil
    local controller = Bars.Modules.NativeBar
    local utilities = Bars.Modules.NativeUtilityBars
    if utilities then
        local configured, failure = CallLifecycle(utilities.Configure, state.store)
        if not configured then state.utilityFailure = failure; return AbortNative(failure) end
        local active = not state.stopped and state.store and state.store.trialBarEnabled == true
            and Bars.Core.Engine.GetState().active == true
        local ok, reason = CallLifecycle(utilities.Sync, active == true, NativeRequested())
        if not ok then state.utilityFailure = reason; return AbortNative(reason) end
    end
    if not NativeRequested() then
        UnsubscribeNative()
        local ok, failure = ReleaseNative()
        if not ok then return AbortNative(failure) end
        return true
    end
    local safe, reason = CallLifecycle(Bars.Services.NativeBarPolicy.CheckCompeting)
    if not safe then return AbortNative(reason) end
    -- The two master switches are independent, including both sets hidden.
    -- Hiding a BAB identity never releases a requested native visibility lease.
    local acquired, acquireFailure = CallLifecycle(controller.Sync, true, hiddenNativeBars)
    if not acquired then return AbortNative(acquireFailure) end
    local artwork = Bars.Modules.NativeArtwork
    if artwork then
        acquired, acquireFailure = CallLifecycle(artwork.Sync, true)
        if not acquired then return AbortNative(acquireFailure) end
    end
    local specialOK, specialFailure = SyncNativeSpecial(true, true)
    if not specialOK then return false, specialFailure end
    if not NativeRequested() then
        return AbortNative("Native replacement was cancelled while changing visibility.")
    end
    if not state.nativeSubscribed then
        for _, name in ipairs(nativeEvents) do BootyLib.Subscribe(name, Runtime, NativeEvent) end
        state.nativeSubscribed = true
    end
    state.nativeFailure = nil
    return true
end
local function OrdinaryVisibilityChanged()
    local ok = SyncNative()
    if not ok then RefreshView() end
    -- Native replacement is optional: refusal preserves healthy BAB gameplay.
    return true
end
local function SyncSpecial(active)
    local controller = Bars.Modules.SpecialBars
    if not controller then return true end
    if active then return controller.Enable() end
    return controller.Disable()
end
local function EngineActivity(active)
    -- Native ownership and layout cleanup must both run even if one fails.
    local specialOK, specialFailure = CallLifecycle(SyncSpecial, active)
    local nativeOK, nativeFailure = CallLifecycle(SyncNative)
    local editorOK, editorFailure = CallLifecycle(Bars.Modules.Editor.OnActivity, active)
    local utilities = Bars.Modules.NativeUtilityBars
    if utilities and not active then
        local ended, reason = CallLifecycle(utilities.SetEditing, false, false)
        if not ended and editorOK then editorOK, editorFailure = false, reason end
    end
    if not specialOK then return false, specialFailure end
    if not editorOK then return false, editorFailure end
    -- A rejected native lease is already reported and leaves valid trial bars
    -- usable. Restoration errors still fail inactive cleanup.
    if not nativeOK and (not active or state.utilityFailure) then return false, nativeFailure end
    return true
end
local function SyncEngine()
    local store, failure = Bars.Database.Ensure()
    if not store then return false, failure end
    state.store = store
    if Bars.Core.Engine.ConfigureMainFollowing then
        local configured, reason = Bars.Core.Engine.ConfigureMainFollowing(store.mainBarFollowClient ~= false)
        if not configured then return false, reason end
    elseif store.mainBarFollowClient == false then
        return false, "Main action bar following is unavailable in the current engine."
    end
    if Bars.Modules.BehaviorEditor then
        local configured, reason = Bars.Modules.BehaviorEditor.Configure(store)
        if not configured then return false, reason end
        configured, reason = Bars.Core.Engine.ConfigureBehaviors(store.barBehaviors)
        if not configured then return false, reason end
    end
    local layoutOK, layoutFailure = Bars.Modules.Editor.Configure(store)
    if not layoutOK then return false, layoutFailure end
    if Bars.Core.Engine.ConfigureMerges then
        local configured, reason = Bars.Core.Engine.ConfigureMerges(store.barMerges)
        if not configured then return false, reason end
    end
    local options = store.editorOptions or {}
    if Bars.Modules.Editor.SetShowGrid then
        layoutOK, layoutFailure = Bars.Modules.Editor.SetShowGrid(options.showGrid == true)
        if not layoutOK then return false, layoutFailure end
        layoutOK, layoutFailure = Bars.Modules.Editor.SetShowAnchors(options.showAnchors == true)
        if not layoutOK then return false, layoutFailure end
    end
    local configured, reason
    if Bars.Core.Engine.ConfigureMainVisibility then
        configured, reason = Bars.Core.Engine.ConfigureMainVisibility(store.mainBarShown ~= false)
        if not configured then return false, reason end
    end
    configured, reason = Bars.Core.Engine.ConfigureCustomBars(store.customBars)
    if not configured then return false, reason end
    if Bars.Modules.SpecialBars then
        configured, reason = Bars.Modules.SpecialBars.Configure(store.specialBars)
        if not configured then
            store.trialBarEnabled = false
            local stopped, cleanupFailure = CallLifecycle(Bars.Core.Engine.Disable)
            if not stopped then reason = tostring(reason) .. " Cleanup: " .. tostring(cleanupFailure) end
            return false, reason
        end
    end
    if state.stopped or not store.trialBarEnabled then
        local ok, reason = Bars.Core.Engine.Disable()
        if not ok then return false, reason end
        return SyncNative()
    end
    local ok, failure = Bars.Core.Engine.Enable(store.customBars)
    if not ok then
        store.trialBarEnabled = false
        Bars.Core.Engine.Disable()
        BootyLib.Print("BootyActionBars: " .. tostring(failure))
    else
        local specialOK, specialFailure = CallLifecycle(SyncSpecial, Bars.Core.Engine.GetState().active)
        if not specialOK then
            store.trialBarEnabled = false
            Bars.Core.Engine.Disable()
            return false, specialFailure
        end
        local nativeOK, nativeFailure = SyncNative()
        if not nativeOK and state.utilityFailure then return false, nativeFailure end
        local applied, reason = CallLifecycle(Bars.Modules.Editor.OnActivity, Bars.Core.Engine.GetState().active)
        if not applied then
            store.trialBarEnabled = false
            Bars.Core.Engine.Disable()
            BootyLib.Print("BootyActionBars: " .. tostring(reason))
            return false, reason
        end
    end
    return ok, failure
end

function Runtime.Initialize()
    if state.initialized then return true end
    local store, failure = Bars.Database.Ensure()
    if not store then state.failure = failure; return false, failure end
    state.initialized, state.failure = true, nil
    state.store = store
    if Bars.Modules.NativeBar.SetFailureObserver then
        Bars.Modules.NativeBar.SetFailureObserver(NativeLeaseFailure)
    end
    if Bars.Modules.NativeSpecialBars and Bars.Modules.NativeSpecialBars.SetFailureObserver then
        Bars.Modules.NativeSpecialBars.SetFailureObserver(NativeLeaseFailure)
    end
    if Bars.Modules.NativeUtilityBars and Bars.Modules.NativeUtilityBars.SetFailureObserver then
        Bars.Modules.NativeUtilityBars.SetFailureObserver(NativeLeaseFailure)
    end
    if Bars.Modules.SpecialBars and Bars.Modules.SpecialBars.SetVisibilityObserver then
        Bars.Modules.SpecialBars.SetVisibilityObserver(SpecialVisibilityChanged)
    end
    if Bars.Core.Engine.SetVisibilityObserver then
        Bars.Core.Engine.SetVisibilityObserver(OrdinaryVisibilityChanged)
    end
    Bars.Core.Engine.SetActivityObserver(EngineActivity)
    SyncEngine()
    return true
end

function Runtime.OnHostReady(host)
    local ok, failure = Runtime.Initialize()
    if not ok then return false, failure end
    state.host = host
    return true
end

function Runtime.IsAvailable()
    return state.initialized and not state.stopped
end

function Runtime.SettingsChanged()
    if state.batchDepth > 0 then state.batchDirty = true; return end
    if state.stopped then return end
    SyncEngine()
    if state.host and state.host.ApplySettings then state.host.ApplySettings() end
    if state.view then state.view:Refresh() end
end

function Runtime.BeginSettingsBatch()
    state.batchDepth = state.batchDepth + 1
end

function Runtime.EndSettingsBatch(success)
    state.batchDepth = math.max(0, state.batchDepth - 1)
    if state.batchDepth == 0 then
        local dirty = state.batchDirty
        state.batchDirty = nil
        if success ~= false and dirty then Runtime.SettingsChanged() end
    end
end

function Runtime.OnSettingsProfileApplied()
    Runtime.SettingsChanged()
end

function Runtime.CreateView(parent, host)
    -- Hosts pool this factory result. No runtime frames exist before opening.
    if not state.view then state.view = Bars.Modules.Overview.Create(parent, host) end
    return state.view
end

function Runtime.Stop()
    state.stopped = true
    local ok, failure = Bars.Core.Engine.Disable()
    local restored, reason = CallLifecycle(SyncNative)
    if not restored then ok, failure = false, failure and tostring(failure) .. "; " .. tostring(reason) or reason end
    if state.view then state.view:Hide() end
    return ok, failure
end

function Runtime.Start()
    local ok, failure = Runtime.Initialize()
    if not ok then return false, failure end
    state.stopped = false
    return SyncEngine()
end

function Runtime.IsBusy() return false end
function Runtime.GetState() return state end

function Runtime.SetTrialEnabled(value)
    if not Runtime.IsAvailable() then return false, "BootyActionBars is stopped or waiting for login." end
    local store = Bars.Database.Ensure()
    if not store then return false, "BootyActionBars settings are unavailable." end
    store.trialBarEnabled = value == true
    local ok, failure = SyncEngine()
    if state.view then state.view:Refresh() end
    return ok, failure
end

function Runtime.SetNativeEnabled(value)
    if not Runtime.IsAvailable() then return false, "BootyActionBars is stopped or waiting for login." end
    local store = Bars.Database.Ensure()
    if not store then return false, "BootyActionBars settings are unavailable." end
    state.store = store
    store.nativeMainBarEnabled = value == true
    local ok, failure = SyncNative()
    if ok and value ~= true then state.nativeFailure = nil end
    RefreshView()
    return ok, failure
end

function Runtime.SetCustomBar(id, enabled)
    if not Runtime.IsAvailable() then return false, "BootyActionBars is stopped or waiting for login." end
    if not Bars.Services.BarConfig.ValidID(id) or type(enabled) ~= "boolean" then
        return false, "Choose an additional bar from 2 to 10 and show or hide it."
    end
    local store, failure = Bars.Database.Ensure()
    if not store then return false, failure end
    if (store.customBars[id] == true) == enabled then return true end
    -- The user's choice is durable; activation errors still stop the engine
    -- and retain that choice for repair/reload rather than reporting success.
    store.customBars[id] = enabled and true or nil
    local ok, reason = SyncEngine()
    RefreshView()
    return ok, reason
end

function Runtime.SetMainBarShown(value)
    if not Runtime.IsAvailable() or type(value) ~= "boolean" then
        return false, "Choose whether to show Action Bar 1."
    end
    local store, failure = Bars.Database.Ensure()
    if not store then return false, failure end
    if store.mainBarShown == value then return true end
    store.mainBarShown = value
    local ok, reason = SyncEngine()
    RefreshView()
    return ok, reason
end

function Runtime.GetMainBarFollowClient()
    local store, failure = Bars.Database.Ensure()
    if not store then return nil, failure end
    return store.mainBarFollowClient ~= false
end
local function SetMainBarFollowClient(value)
    if not Runtime.IsAvailable() or type(value) ~= "boolean" then
        return false, "Choose whether Main Action Bar follows client pages and forms."
    end
    local store, failure = Bars.Database.Ensure()
    if not store then return false, failure end
    if Runtime.GetMergeOwner(1) ~= 1 then return false, "Main Action Bar uses its merge owner's settings." end
    if (store.mainBarFollowClient ~= false) == value then return true end
    if type(Bars.Core.Engine.ConfigureMainFollowing) ~= "function" then return false, "Main action bar following is unavailable." end
    local previous, enabled = store.mainBarFollowClient, store.trialBarEnabled
    local ended, reason = CallLifecycle(Bars.Modules.Editor.End)
    if not ended then return false, reason end
    if Bars.Modules.BindingEditor then
        ended, reason = CallLifecycle(Bars.Modules.BindingEditor.Cancel)
        if not ended then return false, reason end
    end
    if BootyActionBarsDB ~= store or store.mainBarFollowClient ~= previous or store.trialBarEnabled ~= enabled then
        return false, "Main action bar following changed while cancelling input."
    end
    store.mainBarFollowClient = value
    local ok, message = CallLifecycle(SyncEngine)
    local owned = BootyActionBarsDB == store and store.mainBarFollowClient == value
    if not ok or not owned then
        message = message or "Main action bar following changed while applying."
        if owned then store.mainBarFollowClient, store.trialBarEnabled = previous, enabled end
        local restored, restoration = CallLifecycle(SyncEngine)
        if not restored then message = tostring(message) .. " Restoration: " .. tostring(restoration) end
        RefreshView(); return false, message
    end
    RefreshView(); return true
end
function Runtime.SetMainBarFollowClient(value)
    if state.mainFollowingBusy then return false, "Main action bar following is already being changed." end
    state.mainFollowingBusy = true
    local ok, failure = CallLifecycle(SetMainBarFollowClient, value)
    state.mainFollowingBusy = nil
    return ok, failure
end

function Runtime.SetSpecialBar(kind, enabled)
    if not Runtime.IsAvailable() then return false, "BootyActionBars is stopped or waiting for login." end
    if (kind ~= "pet" and kind ~= "stance") or type(enabled) ~= "boolean" then return false, "Choose pet or stance and on or off." end
    local store, failure = Bars.Database.Ensure()
    if not store then return false, failure end
    if (store.specialBars[kind] == true) == enabled then return true end
    store.specialBars[kind] = enabled and true or nil
    Bars.Core.Engine.MarkLayoutChanged()
    local ok, reason = SyncEngine()
    RefreshView()
    return ok, reason
end

function Runtime.IsEditing() return Bars.Modules.Editor.IsEditing() end

function Runtime.SetEditEnabled(enabled)
    if type(enabled) ~= "boolean" then return false, "Choose whether to edit the bar layout." end
    local ok, failure
    if enabled then
        if Bars.Modules.BindingEditor then
            ok, failure = Bars.Modules.BindingEditor.Cancel()
            if not ok then RefreshView(); return false, failure end
        end
        if not Runtime.IsAvailable() or not state.view or not state.view.frame:IsVisible() then
            return false, "Open Action Bars and enable the test bars before editing their layout."
        end
        ok, failure = Bars.Modules.Editor.Begin()
    else ok, failure = Bars.Modules.Editor.End() end
    local utilities = Bars.Modules.NativeUtilityBars
    if utilities then
        local editing = ok and enabled == true
        local anchors = state.store and state.store.editorOptions and state.store.editorOptions.showAnchors == true
        local applied, reason = CallLifecycle(utilities.SetEditing, editing, anchors == true)
        if not applied then
            local ended, detail = CallLifecycle(Bars.Modules.Editor.End)
            ok, failure = false, reason
            if not ended then failure = tostring(failure) .. " Editor cleanup: " .. tostring(detail) end
        end
    end
    RefreshView()
    return ok, failure
end

function Runtime.GetUtilityLayout(id)
    local store, failure = Bars.Database.Ensure()
    if not store then return nil, failure end
    return Bars.Services.UtilityLayout.Read(store.utilityLayouts, id)
end
function Runtime.SetUtilityPreference(id, key, value)
    if not Runtime.IsAvailable() then return false, "BootyActionBars is stopped or waiting for login." end
    local utilities = Bars.Modules.NativeUtilityBars
    if not utilities then return false, "Utility bars are unavailable." end
    local ok, failure = CallLifecycle(utilities.SetPreference, id, key, value)
    RefreshView()
    return ok, failure
end
function Runtime.ResetUtilityLayout(id)
    if not Runtime.IsAvailable() then return false, "BootyActionBars is stopped or waiting for login." end
    local utilities = Bars.Modules.NativeUtilityBars
    if not utilities then return false, "Utility bars are unavailable." end
    local ok, failure = CallLifecycle(utilities.Reset, id)
    RefreshView()
    return ok, failure
end

function Runtime.GetBarLayout(id)
    return Bars.Modules.Editor.GetLayout(id)
end

function Runtime.GetGlobalLayout() return Bars.Modules.Editor.GetGlobalLayout() end
function Runtime.SetGlobalLayout(key, value)
    if not Runtime.IsAvailable() then return false, "BootyActionBars is stopped or waiting for login." end
    local owner, failure = Bars.Database.Ensure()
    if not owner then return false, failure end
    local ok, reason = Bars.Modules.Editor.SetGlobalLayout(key, value)
    if not ok and BootyActionBarsDB ~= owner then
        local restored, restoreFailure = CallLifecycle(SyncEngine)
        if not restored then reason = tostring(reason) .. " Resynchronization: " .. tostring(restoreFailure) end
    end
    RefreshView()
    return ok, reason
end
function Runtime.SetUseGlobalLayout(id, value)
    if not Runtime.IsAvailable() then return false, "BootyActionBars is stopped or waiting for login." end
    local owner, failure = Bars.Database.Ensure()
    if not owner then return false, failure end
    local ok, failure = Bars.Modules.Editor.SetUseGlobalLayout(id, value)
    if not ok and BootyActionBarsDB ~= owner then
        local restored, restoreFailure = CallLifecycle(SyncEngine)
        if not restored then failure = tostring(failure) .. " Resynchronization: " .. tostring(restoreFailure) end
    end
    RefreshView()
    return ok, failure
end

function Runtime.SetGlobalColor(group, rgba)
    if not Runtime.IsAvailable() then return false, "BootyActionBars is stopped or waiting for login." end
    local owner, failure = Bars.Database.Ensure()
    if not owner then return false, failure end
    local ok, reason = CallLifecycle(Bars.Modules.Editor.SetGlobalColor, group, rgba)
    if not ok and BootyActionBarsDB ~= owner then
        local restored, restoreFailure = CallLifecycle(SyncEngine)
        if not restored then reason = tostring(reason) .. " Resynchronization: " .. tostring(restoreFailure) end
    end
    RefreshView()
    return ok, reason
end

function Runtime.SetEditorOption(key, value)
    if (key ~= "showGrid" and key ~= "showAnchors") or type(value) ~= "boolean" then
        return false, "Choose a grid or anchor setting."
    end
    local store, failure = Bars.Database.Ensure()
    if not store then return false, failure end
    local options, previous = store.editorOptions, store.editorOptions and store.editorOptions[key]
    local setter = key == "showGrid" and Bars.Modules.Editor.SetShowGrid or Bars.Modules.Editor.SetShowAnchors
    if not setter then return false, "The layout tools are unavailable." end
    local ok, reason = CallLifecycle(setter, value)
    if ok and (BootyActionBarsDB ~= store or store.editorOptions ~= options
        or options and options[key] ~= previous) then
        ok, reason = false, "Layout tool settings ownership changed during editing."
        local restored, restoreFailure = CallLifecycle(setter, previous == true)
        if not restored then reason = reason .. " Restoration: " .. tostring(restoreFailure) end
    end
    if ok then
        if not store.editorOptions then store.editorOptions = {} end
        store.editorOptions[key] = value and true or nil
    end
    if ok and key == "showAnchors" and Bars.Modules.NativeUtilityBars then
        ok, reason = CallLifecycle(Bars.Modules.NativeUtilityBars.SetEditing, Runtime.IsEditing(), value)
        if not ok then
            store.editorOptions[key] = previous
            local restored, detail = CallLifecycle(setter, previous == true)
            if not restored then reason = tostring(reason) .. " Restoration: " .. tostring(detail) end
            restored, detail = CallLifecycle(Bars.Modules.NativeUtilityBars.SetEditing, Runtime.IsEditing(), previous == true)
            if not restored then reason = tostring(reason) .. " Utility restoration: " .. tostring(detail) end
        end
    end
    RefreshView()
    return ok, reason
end

local function LayoutAvailable(id)
    if not Runtime.IsAvailable() then return false, "BootyActionBars is stopped or waiting for login." end
    if not Bars.Services.BarLayout.ValidID(id) then
        return false, "Choose an action bar, pet bar or form bar."
    end
    local store, failure = Bars.Database.Ensure()
    if not store then return false, failure end
    if Bars.Services.BarConfig.ValidOrdinaryID(id) and Runtime.GetMergeOwner(id) ~= id then
        return false, "This bar uses its merge owner's settings. Choose None to restore its individual settings."
    end
    return true
end
function Runtime.GetMergeOwner(id)
    local service = Bars.Services.BarMerging
    if not service or not Bars.Services.BarConfig.ValidOrdinaryID(id) then return id end
    return service.Read(state.store and state.store.barMerges, id)
end
function Runtime.GetMergeCount(id)
    if id == 7 or id == 8 then return 10 end
    if not Bars.Services.BarConfig.ValidOrdinaryID(id) then return 12 end
    local _, count = Runtime.GetMergeOwner(id)
    return count or 12
end
function Runtime.SetBarMerge(id, destination)
    if not Runtime.IsAvailable() then return false, "BootyActionBars is stopped or waiting for login." end
    local store, failure = Bars.Database.Ensure()
    if not store then return false, failure end
    local service = Bars.Services.BarMerging
    local candidate, reason = service.SetDestination(store.barMerges, id, destination)
    if not candidate then return false, reason end
    if service.Equal(candidate, store.barMerges) then return true end
    local previous, before = store.barMerges, service.Copy(store.barMerges)
    local enabled = store.trialBarEnabled
    local ended, detail = CallLifecycle(Bars.Modules.Editor.End)
    if not ended then return false, detail end
    if Bars.Modules.BindingEditor then
        ended, detail = CallLifecycle(Bars.Modules.BindingEditor.Cancel)
        if not ended then return false, detail end
    end
    if BootyActionBarsDB ~= store or store.barMerges ~= previous or not service.Equal(previous, before)
        or store.trialBarEnabled ~= enabled then
        return false, "Action bar merge settings changed while cancelling input."
    end
    store.barMerges = candidate
    local expected = service.Copy(candidate)
    Bars.Core.Engine.MarkLayoutChanged()
    local ok, message = CallLifecycle(SyncEngine)
    local owned = BootyActionBarsDB == store and store.barMerges == candidate and service.Equal(candidate, expected)
    if not ok or not owned then
        message = message or "Action bar merge settings ownership changed while applying."
        if BootyActionBarsDB == store and store.barMerges == candidate and service.Equal(candidate, expected) then
            store.barMerges, store.trialBarEnabled = previous, enabled
        end
        local restored, restoration = CallLifecycle(SyncEngine)
        if not restored then message = tostring(message) .. " Restoration: " .. tostring(restoration) end
        RefreshView(); return false, message
    end
    RefreshView(); return true
end

function Runtime.SetBarScale(id, percent)
    local valid, reason = LayoutAvailable(id)
    if not valid then return false, reason end
    local ok, failure = Bars.Modules.Editor.SetScale(id, percent)
    RefreshView()
    return ok, failure
end

local function SetGridPreference(id, key, value, validator, maximum)
    if not validator(value) then return false, "Choose an integer " .. key .. " value from " .. (key == "columns" and 1 or 0) .. " to " .. maximum .. "." end
    local valid, reason = LayoutAvailable(id)
    if not valid then return false, reason end
    local layout, failure = Bars.Modules.Editor.GetLayout(id)
    if not layout then return false, failure end
    layout[key] = value
    local ok, message = Bars.Modules.Editor.SetGrid(id, layout.columns, layout.spacing)
    RefreshView()
    return ok, message
end

function Runtime.SetBarColumns(id, columns)
    if (id == 7 or id == 8) and type(columns) == "number" and columns > 10 then return false, "Pet and form bars support at most 10 columns." end
    local maximum = Runtime.GetMergeCount(id)
    if type(columns) == "number" and columns > maximum then return false, "The column count exceeds this bar's slots." end
    return SetGridPreference(id, "columns", columns, Bars.Services.BarLayout.ValidColumns, maximum)
end

function Runtime.SetBarSpacing(id, spacing)
    return SetGridPreference(id, "spacing", spacing, Bars.Services.BarLayout.ValidSpacing, 20)
end

function Runtime.SetBarDisplay(id, key, enabled)
    if not Bars.Services.BarLayout.ValidDisplayKey(key) or type(enabled) ~= "boolean" then
        return false, "Choose a known visibility or appearance toggle."
    end
    local valid, reason = LayoutAvailable(id)
    if not valid then return false, reason end
    local ok, failure = Bars.Modules.Editor.SetDisplay(id, key, enabled)
    RefreshView()
    return ok, failure
end

function Runtime.SetBarAppearance(id, key, value)
    local valid, reason = LayoutAvailable(id)
    if not valid then return false, reason end
    local ok, failure = Bars.Modules.Editor.SetAppearance(id, key, value)
    RefreshView()
    return ok, failure
end

function Runtime.SetBarColor(id, group, rgba)
    local valid, reason = LayoutAvailable(id)
    if not valid then return false, reason end
    local owner, failure = Bars.Database.Ensure()
    if not owner then return false, failure end
    local ok, message = CallLifecycle(Bars.Modules.Editor.SetColor, id, group, rgba)
    if not ok and BootyActionBarsDB ~= owner then
        local restored, restoreFailure = CallLifecycle(SyncEngine)
        if not restored then message = tostring(message) .. " Resynchronization: " .. tostring(restoreFailure) end
    end
    RefreshView()
    return ok, message
end

function Runtime.SetBarPosition(id, x, y)
    local valid, reason = LayoutAvailable(id)
    if not valid then return false, reason end
    local ok, failure = Bars.Modules.Editor.SetPosition(id, x, y)
    RefreshView()
    return ok, failure
end

function Runtime.SetBindingEditing(enabled)
    local module = Bars.Modules.BindingEditor
    if not module then return false, "The binding editor is unavailable." end
    if not enabled then return module.Cancel() end
    if not Runtime.IsAvailable() or not state.view or not state.view.frame:IsVisible() then return false, "Open Action Bars before assigning keys." end
    if module.IsEditing() then return true end
    local ok, failure = Bars.Modules.Editor.End()
    if not ok then return false, failure end
    ok, failure = module.Begin(state.host.window)
    if not ok then return false, failure end
    return true
end

function Runtime.SaveLayoutProfile(name, replace)
    local store, failure = Bars.Database.Ensure()
    if not store then return false, failure end
    local ok, result = Bars.Services.LayoutProfiles.Save(store, name, replace)
    if ok then state.profileRevision = (state.profileRevision or 0) + 1 end
    RefreshView()
    return ok, result
end

function Runtime.DeleteLayoutProfile(name)
    local store, failure = Bars.Database.Ensure()
    if not store then return false, failure end
    local ok, result = Bars.Services.LayoutProfiles.Delete(store, name)
    if ok then state.profileRevision = (state.profileRevision or 0) + 1 end
    RefreshView()
    return ok, result
end

function Runtime.GetBarBehaviors(id)
    if not Runtime.IsAvailable() then return nil, "BootyActionBars is stopped or waiting for login." end
    return Bars.Modules.BehaviorEditor.GetRules(id)
end
function Runtime.GetBehaviorCatalog()
    if not Runtime.IsAvailable() then return nil, "BootyActionBars is stopped or waiting for login." end
    return Bars.Modules.BehaviorEditor.ReadCatalog()
end
function Runtime.CaptureBarBehaviors(id)
    if not Runtime.IsAvailable() then return nil, "BootyActionBars is stopped or waiting for login." end
    return Bars.Modules.BehaviorEditor.Capture(id)
end
function Runtime.ValidateBarBehaviorCapture(id, token)
    if not Runtime.IsAvailable() then return false, "BootyActionBars is stopped or waiting for login." end
    return CallLifecycle(Bars.Modules.BehaviorEditor.ValidateCapture, token, id)
end
local function CompleteBehavior(callback, id, index, value, token)
    if not Runtime.IsAvailable() then return false, "BootyActionBars is stopped or waiting for login." end
    local capture = token
    if callback == Bars.Modules.BehaviorEditor.Remove then capture = value end
    if capture ~= nil then
        local current, reason = Runtime.ValidateBarBehaviorCapture(id, capture)
        -- A stale modal cannot run the defaults pipeline indirectly through a
        -- UI refresh. The third result tells the caller to report only.
        if not current then return false, reason, true end
    end
    local owner = BootyActionBarsDB
    local ok, failure = CallLifecycle(callback, id, index, value, token)
    if not ok and capture ~= nil then
        local current = Runtime.ValidateBarBehaviorCapture(id, capture)
        if not current then return false, failure, true end
    end
    if not ok and BootyActionBarsDB ~= owner then
        local restored, reason = CallLifecycle(SyncEngine)
        if not restored then failure = tostring(failure) .. " Resynchronization: " .. tostring(reason) end
    end
    RefreshView()
    return ok, failure
end
function Runtime.SetBarBehavior(id, index, rule, token)
    return CompleteBehavior(Bars.Modules.BehaviorEditor.Update, id, index, rule, token)
end
function Runtime.RemoveBarBehavior(id, index, token)
    return CompleteBehavior(Bars.Modules.BehaviorEditor.Remove, id, index, token)
end
function Runtime.MoveBarBehavior(id, index, destination, token)
    return CompleteBehavior(Bars.Modules.BehaviorEditor.Move, id, index, destination, token)
end

local function OwnsBehaviors(store, reference, snapshot)
    local current = store.barBehaviors
    if current ~= reference then return false end
    local valid = Bars.Services.BehaviorService.Validate(current)
    return valid and Bars.Services.BehaviorService.Equal(current, snapshot)
end
local function OwnsUtilities(store, reference, snapshot)
    if store.utilityLayouts ~= reference then return false end
    local service = Bars.Services.UtilityLayout
    return not service or service.Validate(reference) and service.Equal(reference, snapshot)
end
local function OwnsMerges(store, reference, snapshot)
    if store.barMerges ~= reference then return false end
    local service = Bars.Services.BarMerging
    return not service or service.Equal(reference, snapshot)
end
local function ApplyLayoutSnapshot(snapshot)
    if not Runtime.IsAvailable() then return false, "BootyActionBars is stopped or waiting for login." end
    local store, failure = Bars.Database.Ensure()
    if not store then return false, failure end
    local prepared, reason = Bars.Services.LayoutProfiles.Prepare(snapshot, store.barLayouts, store.globalLayout, store.barBehaviors)
    if not prepared then return false, reason end
    local ended, endFailure = Bars.Modules.Editor.End()
    if not ended then return false, endFailure end
    if Bars.Modules.NativeUtilityBars then
        ended, endFailure = CallLifecycle(Bars.Modules.NativeUtilityBars.SetEditing, false, false)
        if not ended then return false, endFailure end
    end
    if Bars.Modules.BindingEditor then
        ended, endFailure = Bars.Modules.BindingEditor.Cancel()
        if not ended then return false, endFailure end
    end
    local oldLayouts, oldCustom, oldSpecial = store.barLayouts, store.customBars, store.specialBars
    local oldGlobal, oldMain, oldFollowing = store.globalLayout, store.mainBarShown, store.mainBarFollowClient
    local expectedFollowing = prepared.mainBarFollowClient
    if expectedFollowing == nil then expectedFollowing = oldFollowing end
    local oldBehaviors, oldUtilities = store.barBehaviors, store.utilityLayouts
    local oldMerges = store.barMerges
    local mergeValues = Bars.Services.BarMerging and Bars.Services.BarMerging.Copy(oldMerges)
    local preparedMerges = prepared.replaceMerges and Bars.Services.BarMerging.Copy(prepared.barMerges) or nil
    local utilityValues = Bars.Services.UtilityLayout and Bars.Services.UtilityLayout.Copy(oldUtilities)
    local preparedUtilities = prepared.replaceUtilities and Bars.Services.UtilityLayout.Copy(prepared.utilityLayouts) or nil
    local oldBehaviorValues = Bars.Services.BehaviorService.Copy(oldBehaviors)
    local preparedBehaviors = prepared.replaceBehaviors and Bars.Services.BehaviorService.Copy(prepared.barBehaviors) or nil
    local enabled = store.trialBarEnabled
    local stopped, stopFailure = CallLifecycle(Bars.Core.Engine.Disable)
    if not stopped then return false, stopFailure end
    if BootyActionBarsDB ~= store or store.mainBarFollowClient ~= oldFollowing or not OwnsBehaviors(store, oldBehaviors, oldBehaviorValues)
        or not OwnsUtilities(store, oldUtilities, utilityValues) or not OwnsMerges(store, oldMerges, mergeValues) then
        local restored, restoration = CallLifecycle(SyncEngine)
        local ownershipFailure = "Layout settings ownership changed before loading."
        if not restored then ownershipFailure = ownershipFailure .. " Resynchronization: " .. tostring(restoration) end
        return false, ownershipFailure
    end
    store.barLayouts, store.customBars, store.specialBars = prepared.barLayouts, prepared.customBars, prepared.specialBars
    if prepared.replaceGlobal then store.globalLayout = prepared.globalLayout end
    if prepared.mainBarShown ~= nil then store.mainBarShown = prepared.mainBarShown end
    if prepared.mainBarFollowClient ~= nil then store.mainBarFollowClient = prepared.mainBarFollowClient end
    if prepared.replaceBehaviors then store.barBehaviors = prepared.barBehaviors end
    if prepared.replaceUtilities then store.utilityLayouts = prepared.utilityLayouts end
    if prepared.replaceMerges then store.barMerges = prepared.barMerges end
    Bars.Core.Engine.MarkLayoutChanged()
    local ok, message = CallLifecycle(SyncEngine)
    local owned = BootyActionBarsDB == store and store.barLayouts == prepared.barLayouts
        and store.customBars == prepared.customBars and store.specialBars == prepared.specialBars
        and (not prepared.replaceGlobal or store.globalLayout == prepared.globalLayout)
        and (prepared.mainBarShown == nil or store.mainBarShown == prepared.mainBarShown)
        and store.mainBarFollowClient == expectedFollowing
        and (not prepared.replaceBehaviors or OwnsBehaviors(store, prepared.barBehaviors, preparedBehaviors))
        and (not prepared.replaceUtilities or OwnsUtilities(store, prepared.utilityLayouts, preparedUtilities))
        and (not prepared.replaceMerges or OwnsMerges(store, prepared.barMerges, preparedMerges))
    if ok and owned then return true end
    local firstFailure = message or "Layout settings ownership changed while loading."
    local cleaned, cleanupFailure = CallLifecycle(Bars.Core.Engine.Disable)
    if not cleaned then firstFailure = tostring(firstFailure) .. " Cleanup: " .. tostring(cleanupFailure) end
    if BootyActionBarsDB == store then
        if store.barLayouts == prepared.barLayouts then store.barLayouts = oldLayouts end
        if store.customBars == prepared.customBars then store.customBars = oldCustom end
        if store.specialBars == prepared.specialBars then store.specialBars = oldSpecial end
        if prepared.replaceGlobal and store.globalLayout == prepared.globalLayout then store.globalLayout = oldGlobal end
        if prepared.mainBarShown ~= nil and store.mainBarShown == prepared.mainBarShown then store.mainBarShown = oldMain end
        if prepared.mainBarFollowClient ~= nil and store.mainBarFollowClient == prepared.mainBarFollowClient then store.mainBarFollowClient = oldFollowing end
        if prepared.replaceBehaviors and OwnsBehaviors(store, prepared.barBehaviors, preparedBehaviors) then store.barBehaviors = oldBehaviors end
        if prepared.replaceUtilities and OwnsUtilities(store, prepared.utilityLayouts, preparedUtilities) then store.utilityLayouts = oldUtilities end
        if prepared.replaceMerges and OwnsMerges(store, prepared.barMerges, preparedMerges) then store.barMerges = oldMerges end
        -- Keep native ownership refusals; a profile must not undo conflict policy.
        store.trialBarEnabled = enabled
        local restored, restoreFailure = CallLifecycle(SyncEngine)
        if not restored then firstFailure = tostring(firstFailure) .. " Restoration: " .. tostring(restoreFailure) end
    end
    return false, firstFailure
end

function Runtime.LoadLayoutProfile(name)
    local normalized, reason = Bars.Services.LayoutProfiles.Name(name)
    if not normalized then return false, reason end
    local store, failure = Bars.Database.Ensure()
    if not store then return false, failure end
    local snapshot = store.layoutProfiles and store.layoutProfiles[normalized]
    if not snapshot then return false, "Choose an existing layout profile." end
    local previous, why = Bars.Services.LayoutProfiles.Capture(store)
    if not previous then return false, why end
    local ok, message = ApplyLayoutSnapshot(snapshot)
    if ok then state.layoutUndo, state.loadedLayoutProfile = previous, normalized end
    RefreshView()
    return ok, message
end

function Runtime.UndoLayoutProfile()
    if not state.layoutUndo then return false, "No loaded layout can be undone in this session." end
    local ok, failure = ApplyLayoutSnapshot(state.layoutUndo)
    if ok then state.layoutUndo, state.loadedLayoutProfile = nil, nil end
    RefreshView()
    return ok, failure
end

function Runtime.ResetBarLayout(id)
    local valid, reason = LayoutAvailable(id)
    if not valid then return false, reason end
    local ok, failure = Bars.Modules.Editor.Reset(id)
    RefreshView()
    return ok, failure
end

function Runtime.Open(command)
    if not state.host then
        BootyLib.Print(state.failure or "BootyActionBars is waiting for login.")
        return false
    end
    if command == "settings" then return state.host.OpenSettings() end
    if command == "bind" then
        local opened = state.host.OpenView("actionbars")
        if opened == false then return false, "Action Bars could not be opened." end
        if state.view.SelectTab then
            local selected, reason = state.view:SelectTab("keybindings")
            if not selected then return false, reason end
        end
        local ok, failure = Runtime.SetBindingEditing(true)
        if not ok then state.host.Print(failure) end
        return ok, failure
    end
    local _, _, special, specialChoice = string.find(command, "^(%a+) (%a+)$")
    if (special == "pet" or special == "stance") and (specialChoice == "on" or specialChoice == "off") then
        local ok, failure = Runtime.SetSpecialBar(special, specialChoice == "on")
        if not ok then state.host.Print(failure) end
        return ok, failure
    end
    if command == "unlock" then
        local opened = state.host.OpenView("actionbars")
        if opened == false then return false, "Action Bars could not be opened." end
        if state.view.SelectTab then
            local selected, reason = state.view:SelectTab("bars")
            if not selected then return false, reason end
            selected, reason = state.view.panels.bars:Select("layout")
            if not selected then return false, reason end
        end
        local ok, failure = Runtime.SetEditEnabled(true)
        if not ok then state.host.Print(failure) end
        return ok, failure
    end
    if command == "lock" then return Runtime.SetEditEnabled(false) end
    local _, _, display, displayBar, choice = string.find(command, "^(%a+) (%d+) (%a+)$")
    local displayKey = display == "title" and "showTitle" or display == "hotkeys" and "showHotkeys" or display == "counts" and "showCounts"
        or display == "macronames" and "showMacroNames" or display == "empty" and "showEmptyButtons"
    if displayKey and (choice == "on" or choice == "off") then
        local ok, failure = Runtime.SetBarDisplay(tonumber(displayBar), displayKey, choice == "on")
        if not ok then state.host.Print(failure) end
        return ok, failure
    end
    local _, _, gridBar, columns = string.find(command, "^columns (%d+) (%d+)$")
    if gridBar then
        local ok, failure = Runtime.SetBarColumns(tonumber(gridBar), tonumber(columns))
        if not ok then state.host.Print(failure) end
        return ok, failure
    end
    local _, _, gapBar, spacing = string.find(command, "^gap (%d+) (%d+)$")
    if gapBar then
        local ok, failure = Runtime.SetBarSpacing(tonumber(gapBar), tonumber(spacing))
        if not ok then state.host.Print(failure) end
        return ok, failure
    end
    local _, _, bar, percent = string.find(command, "^scale (%d+) (%d+)$")
    if bar then
        local ok, failure = Runtime.SetBarScale(tonumber(bar), tonumber(percent))
        if not ok then state.host.Print(failure) end
        return ok, failure
    end
    local _, _, reset = string.find(command, "^reset (%d+)$")
    if reset then
        local ok, failure = Runtime.ResetBarLayout(tonumber(reset))
        if not ok then state.host.Print(failure) end
        return ok, failure
    end
    if command == "test" or command == "test on" or command == "test off" then
        local store, failure = Bars.Database.Ensure()
        if not store then state.host.Print(failure); return false, failure end
        return Runtime.SetTrialEnabled(command == "test on" or command == "test" and not store.trialBarEnabled)
    end
    if command == "native" or command == "native on" or command == "native off" then
        local store, failure = Bars.Database.Ensure()
        if not store then state.host.Print(failure); return false, failure end
        return Runtime.SetNativeEnabled(command == "native on" or command == "native" and not store.nativeMainBarEnabled)
    end
    local _, _, number, choice = string.find(command, "^bar (%d+) ?(%a*)$")
    if number and (choice == "" or choice == "on" or choice == "off") then
        local store, failure = Bars.Database.Ensure()
        if not store then state.host.Print(failure); return false, failure end
        local id = Bars.Services.BarConfig.IDForPage(tonumber(number))
        local enabled = choice == "on" or choice == "" and not store.customBars[id]
        local ok, reason = Runtime.SetCustomBar(id, enabled)
        if not ok and reason then state.host.Print(reason) end
        return ok, reason
    end
    if command == "" then return state.host.OpenView("actionbars") end
    state.host.Print("Use /bab, /bab settings, /bab pet|stance on|off, /bab test on|off, /bab native on|off, /bab bar 2-10 on|off, /bab unlock|lock, /bab scale ID 50-200, /bab columns ID 1-120 (up to the bar's slots), /bab gap ID 0-20, /bab title|hotkeys|counts ID on|off, or /bab reset ID. Layout IDs: 1-6 action bars, 7 pet, 8 forms, 9-12 action bars 7-10.")
    return false
end
