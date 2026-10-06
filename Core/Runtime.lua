local Bars = BootyActionBars
local Runtime = {}
Bars.Core.Runtime = Runtime
local state = {initialized = false, stopped = false, batchDepth = 0}
local nativeEvents = {"ACTIONBAR_PAGE_CHANGED", "UPDATE_BONUS_ACTIONBAR", "UPDATE_SHAPESHIFT_FORMS", "ADDON_LOADED"}
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
local function CallLifecycle(callback, first, second, third)
    local previousThis, previousEvent, previousArg = this, event, arg1
    local ran, ok, failure = pcall(callback, first, second, third)
    this, event, arg1 = previousThis, previousEvent, previousArg
    if not ran then return false, tostring(ok) end
    if ok == false then return false, failure or "Action bar layout could not be updated." end
    return true
end
local function ReleaseNative()
    -- Both owners must be released even when one restoration fails.
    local ok, failure = CallLifecycle(Bars.Modules.NativeBar.Release)
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
    if not restored then failure = tostring(failure) .. " Restoration: " .. tostring(reason) end
    return NativeFailure(failure)
end
local function NativeRequested()
    local store = state.store
    return store ~= nil and not state.stopped and store.trialBarEnabled == true
        and store.nativeMainBarEnabled == true and Bars.Core.Engine.GetState().active == true
end
local function SyncNativeSpecial(pet, stance)
    local controller = Bars.Modules.NativeSpecialBars
    if not controller then return true end
    local ok, failure = CallLifecycle(controller.Sync, NativeRequested(), pet == true, stance == true)
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
    if event == "ACTIONBAR_PAGE_CHANGED" or event == "UPDATE_BONUS_ACTIONBAR" or event == "UPDATE_SHAPESHIFT_FORMS" then
        -- Shared subscribers have no ordering contract. Repair the actual BAB
        -- mapping before deciding whether its primary native buttons can hide.
        local ok, failure = CallLifecycle(Bars.Core.Engine.HandleEvent, event, arg1)
        if not ok then AbortNative(failure); RefreshView(); return end
    end
    SyncNative(); RefreshView()
end
SyncNative = function()
    local controller = Bars.Modules.NativeBar
    if not NativeRequested() then
        UnsubscribeNative()
        local ok, failure = ReleaseNative()
        if not ok then return AbortNative(failure) end
        return true
    end
    local safe, reason = CallLifecycle(Bars.Services.NativeBarPolicy.CheckCompeting)
    if not safe then return AbortNative(reason) end
    local ok, failure = CallLifecycle(controller.Check)
    if ok and Bars.Core.Engine.GetState().actionOffset ~= 0 then
        ok, failure = false, "The test bar must display page 1 before replacing native buttons."
    end
    if ok then
        local acquired, acquireFailure = CallLifecycle(controller.Acquire)
        if not acquired then return AbortNative(acquireFailure) end
    else
        -- Keep the user's hide request while native primary buttons support
        -- the current bonus/page. Special form controls remain independently owned.
        local restored, restoreFailure = CallLifecycle(controller.Release)
        if not restored then return AbortNative(tostring(failure) .. " Restoration: " .. tostring(restoreFailure)) end
    end
    local special = Bars.Modules.SpecialBars
    local pet, stance = false, false
    if special and special.GetLiveVisibility then
        local previousThis, previousEvent, previousArg = this, event, arg1
        local read
        read, pet, stance = pcall(special.GetLiveVisibility)
        this, event, arg1 = previousThis, previousEvent, previousArg
        if not read then return AbortNative(pet) end
    end
    local specialOK, specialFailure = SyncNativeSpecial(pet, stance)
    if not specialOK then return false, specialFailure end
    if not state.nativeSubscribed then
        for _, name in ipairs(nativeEvents) do BootyLib.Subscribe(name, Runtime, NativeEvent) end
        state.nativeSubscribed = true
    end
    if not ok then return NativeFailure(failure) end
    state.nativeFailure = nil
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
    if not specialOK then return false, specialFailure end
    if not editorOK then return false, editorFailure end
    -- A rejected native lease is already reported and leaves valid trial bars
    -- usable. Restoration errors still fail inactive cleanup.
    if not nativeOK and not active then return false, nativeFailure end
    return true
end
local function SyncEngine()
    local store = Bars.Database.Ensure()
    if not store then return false end
    state.store = store
    local layoutOK, layoutFailure = Bars.Modules.Editor.Configure(store)
    if not layoutOK then return false, layoutFailure end
    local configured, reason = Bars.Core.Engine.ConfigureCustomBars(store.customBars)
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
    if state.stopped or not store.trialBarEnabled then return Bars.Core.Engine.Disable() end
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
        SyncNative()
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
    if not store.trialBarEnabled then store.nativeMainBarEnabled = false end
    if Bars.Modules.SpecialBars and Bars.Modules.SpecialBars.SetVisibilityObserver then
        Bars.Modules.SpecialBars.SetVisibilityObserver(SpecialVisibilityChanged)
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
    if not store.trialBarEnabled then store.nativeMainBarEnabled = false end
    local ok, failure = SyncEngine()
    if state.view then state.view:Refresh() end
    return ok, failure
end

function Runtime.SetNativeEnabled(value)
    if not Runtime.IsAvailable() then return false, "BootyActionBars is stopped or waiting for login." end
    local store = Bars.Database.Ensure()
    if not store then return false, "BootyActionBars settings are unavailable." end
    state.store = store
    if value == true and (not store.trialBarEnabled or not Bars.Core.Engine.GetState().active) then
        store.nativeMainBarEnabled = false
        RefreshView()
        return NativeFailure("Enable and show the BootyActionBars test bar before hiding native buttons.")
    end
    store.nativeMainBarEnabled = value == true
    local ok, failure = SyncNative()
    if ok and value ~= true then state.nativeFailure = nil end
    RefreshView()
    return ok, failure
end

function Runtime.SetCustomBar(id, enabled)
    if not Runtime.IsAvailable() then return false, "BootyActionBars is stopped or waiting for login." end
    if not Bars.Services.BarConfig.ValidID(id) or type(enabled) ~= "boolean" then
        return false, "Choose an additional bar from 2 to 6 and show or hide it."
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
        if not Runtime.IsAvailable() or not state.view or not state.view.frame:IsVisible() then
            return false, "Open Action Bars and enable the test bars before editing their layout."
        end
        ok, failure = Bars.Modules.Editor.Begin()
    else ok, failure = Bars.Modules.Editor.End() end
    RefreshView()
    return ok, failure
end

function Runtime.GetBarLayout(id)
    return Bars.Modules.Editor.GetLayout(id)
end

local function LayoutAvailable(id)
    if not Runtime.IsAvailable() then return false, "BootyActionBars is stopped or waiting for login." end
    if not Bars.Services.BarLayout.ValidID(id) then
        return false, "Choose a bar from 1 to 8."
    end
    local store, failure = Bars.Database.Ensure()
    if not store then return false, failure end
    if id == 7 or id == 8 then
        if not store.specialBars[id == 7 and "pet" or "stance"] then return false, "Show this bar before changing its layout." end
    elseif id ~= 1 and not store.customBars[id] then return false, "Show this bar before changing its layout." end
    return true
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
    return SetGridPreference(id, "columns", columns, Bars.Services.BarLayout.ValidColumns, 12)
end

function Runtime.SetBarSpacing(id, spacing)
    return SetGridPreference(id, "spacing", spacing, Bars.Services.BarLayout.ValidSpacing, 20)
end

function Runtime.SetBarDisplay(id, key, enabled)
    if not Bars.Services.BarLayout.ValidDisplayKey(key) or type(enabled) ~= "boolean" then
        return false, "Choose a bar title, hotkey or count setting and enable or disable it."
    end
    local valid, reason = LayoutAvailable(id)
    if not valid then return false, reason end
    local ok, failure = Bars.Modules.Editor.SetDisplay(id, key, enabled)
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
    local _, _, special, specialChoice = string.find(command, "^(%a+) (%a+)$")
    if (special == "pet" or special == "stance") and (specialChoice == "on" or specialChoice == "off") then
        local ok, failure = Runtime.SetSpecialBar(special, specialChoice == "on")
        if not ok then state.host.Print(failure) end
        return ok, failure
    end
    if command == "unlock" then
        local opened = state.host.OpenView("actionbars")
        if opened == false then return false, "Action Bars could not be opened." end
        local ok, failure = Runtime.SetEditEnabled(true)
        if not ok then state.host.Print(failure) end
        return ok, failure
    end
    if command == "lock" then return Runtime.SetEditEnabled(false) end
    local _, _, display, displayBar, choice = string.find(command, "^(%a+) (%d+) (%a+)$")
    local displayKey = display == "title" and "showTitle" or display == "hotkeys" and "showHotkeys" or display == "counts" and "showCounts"
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
        local id = tonumber(number)
        local enabled = choice == "on" or choice == "" and not store.customBars[id]
        local ok, reason = Runtime.SetCustomBar(id, enabled)
        if not ok and reason then state.host.Print(reason) end
        return ok, reason
    end
    if command == "" then return state.host.OpenView("actionbars") end
    state.host.Print("Use /bab, /bab settings, /bab pet|stance on|off, /bab test on|off, /bab native on|off, /bab bar 2-6 on|off, /bab unlock|lock, /bab scale 1-8 50-200, /bab columns 1-8 1-12, /bab gap 1-8 0-20, /bab title|hotkeys|counts 1-8 on|off, or /bab reset 1-8.")
    return false
end
