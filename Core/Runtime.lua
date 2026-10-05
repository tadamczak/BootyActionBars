local Bars = BootyActionBars
local Runtime = {}
Bars.Core.Runtime = Runtime
local state = {initialized = false, stopped = false, batchDepth = 0}

function Runtime.Initialize()
    if state.initialized then return true end
    local store, failure = Bars.Database.Ensure()
    if not store then state.failure = failure; return false, failure end
    state.initialized, state.failure = true, nil
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
    if state.view then state.view:Hide() end
    return true
end

function Runtime.Start()
    local ok, failure = Runtime.Initialize()
    if not ok then return false, failure end
    state.stopped = false
    return true
end

function Runtime.IsBusy() return false end
function Runtime.GetState() return state end

function Runtime.Open(command)
    if not state.host then
        BootyLib.Print(state.failure or "BootyActionBars is waiting for login.")
        return false
    end
    if command == "settings" then return state.host.OpenSettings() end
    if command == "" then return state.host.OpenView("actionbars") end
    state.host.Print("Use /bab to open Action Bars or /bab settings to open Settings.")
    return false
end
