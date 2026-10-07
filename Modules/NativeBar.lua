local Bars = BootyActionBars
local NativeBar = {}
Bars.Modules.NativeBar = NativeBar
local state = {active = false, mainActive = false, customActive = {}, activeTargets = 0,
    restorationBlocked = false, partial = false,
    replacedTargets = 0, restoredTargets = 0, restoreFailures = 0}
local records = {}
local updateButton, updateHotkeys
local failureObserver, notifyingFailure
local targetCount = 72
local groups = {
    {id = 1, first = 1, last = 24, bit = 1},
    {id = 3, first = 25, last = 36, bit = 2, name = "MultiBarRight"},
    {id = 4, first = 37, last = 48, bit = 4, name = "MultiBarLeft"},
    {id = 5, first = 49, last = 60, bit = 8, name = "MultiBarBottomRight"},
    {id = 6, first = 61, last = 72, bit = 16, name = "MultiBarBottomLeft"},
}
local floor = math.floor
local Cleanup

local function Shown(value) return value ~= nil and value ~= false and value ~= 0 end
local function Field(frame, name) return frame[name] end
local function Assign(frame, name, value) frame[name] = value end
local function Global(name)
    if type(getglobal) == "function" then return getglobal(name) end
    return _G[name]
end
local function TargetName(index)
    if records[index] then return records[index].name end
    if index <= 12 then return "ActionButton" .. index end
    if index <= 24 then return "BonusActionButton" .. (index - 12) end
    for _, group in ipairs(groups) do
        if index >= group.first and index <= group.last then return group.name .. "Button" .. (index - group.first + 1) end
    end
end
local function Wanted(mask, group)
    return floor(mask / group.bit) - floor(mask / (group.bit * 2)) * 2 == 1
end
local function UpdateState()
    state.activeTargets, state.mainActive = 0, false
    for _, group in ipairs(groups) do
        local count = 0
        for index = group.first, group.last do
            if records[index] and records[index].enabled then count = count + 1 end
        end
        state.activeTargets = state.activeTargets + count
        if group.id == 1 then state.mainActive = count == 24
        else state.customActive[group.id] = count == 12 and true or nil end
    end
    state.active = state.activeTargets > 0
end
local function NotifyFailure(failure)
    if not failureObserver or notifyingFailure or state.syncing or state.cleaning then return failure end
    local previousThis, previousEvent, previousArg = this, event, arg1
    notifyingFailure = true
    local ran, ok, reason = pcall(failureObserver, failure)
    notifyingFailure = nil
    this, event, arg1 = previousThis, previousEvent, previousArg
    if not ran then reason = ok end
    if not ran or ok == false then
        return failure .. " Failure observer: " .. tostring(reason or "Native failure notification was rejected.")
    end
    if type(reason) == "string" and reason ~= failure then
        if string.sub(reason, 1, string.len(failure)) == failure then return reason end
        return failure .. " Failure observer: " .. reason
    end
    return failure
end
local function Record(index)
    local record = records[index]
    if record then return record end
    record = {name = TargetName(index)}
    for _, group in ipairs(groups) do
        if index >= group.first and index <= group.last then record.group = group; break end
    end
    records[index] = record
    -- Fixed arity delegates do no work while leased. Retained guards become
    -- inert passthroughs before any restoration is attempted.
    record.showGuard = function(frame)
        if not record.enabled then return record.originalShow(frame) end
    end
    -- A native or retained method may bypass frame.Show. The visibility
    -- callback keeps that path hidden without changing either parent bar.
    record.onShowGuard = function()
        if not record.enabled then
            if record.originalOnShow then return record.originalOnShow() end
            return
        end
        -- A hooked Hide can re-enter a retained native Show. Only the outer
        -- callback hides; it verifies the final result after that hook returns.
        if record.hiding then return end
        local previousThis, previousEvent, previousArg = this, event, arg1
        record.hiding = true
        this = record.frame
        local ok, failure = pcall(record.hide, record.frame)
        record.hiding = nil
        if ok then
            this = record.frame
            local read, visible = pcall(record.isShown, record.frame)
            if not read then ok, failure = false, visible
            elseif Shown(visible) then ok, failure = false, "Native " .. TargetName(index) .. " rejected its visibility lease." end
        end
        if not ok and state.active then
            -- A visibility failure ends the whole lease before exposing an
            -- error. No other button may retain a live suppressing delegate.
            local originalFailure = tostring(failure)
            local restored, cleanupFailure = Cleanup()
            failure = originalFailure
            if not restored then failure = originalFailure .. " Restoration: " .. tostring(cleanupFailure) end
            state.failure = failure
            -- The Runtime must release the other native owners immediately;
            -- synchronous acquisition failures already return through it.
            failure = NotifyFailure(failure)
            state.failure = failure
        end
        this, event, arg1 = previousThis, previousEvent, previousArg
        if not ok then error(failure, 0) end
    end
    record.eventGuard = function()
        if not record.enabled and record.originalEvent then return record.originalEvent() end
    end
    record.updateGuard = function()
        if not record.enabled and record.originalUpdate then return record.originalUpdate() end
    end
    return record
end
local function Fail(message)
    state.restoreFailures = state.restoreFailures + 1
    if not state.failure then state.failure = tostring(message) end
end
local function RestoreField(record, name, original, guard, script, attempted)
    if not attempted then return true end
    local ok, current
    if script then ok, current = pcall(record.getScript, record.frame, name)
    else ok, current = pcall(Field, record.frame, name) end
    if not ok then Fail(current); return false end
    if current == original then return true end
    if current ~= guard then record.replaced = true; return false end
    if script then ok, current = pcall(record.setScript, record.frame, name, original)
    else ok, current = pcall(Assign, record.frame, name, original) end
    if not ok then Fail(current); return false end
    if script then ok, current = pcall(record.getScript, record.frame, name)
    else ok, current = pcall(Field, record.frame, name) end
    if not ok then Fail(current); return false end
    if current ~= original then Fail("A native action-button callback could not be restored."); return false end
    return true
end
local function Invoke(frame, callback, first, second)
    local previousThis, previousEvent, previousArg = this, event, arg1
    this = frame
    local ok, failure
    if second ~= nil then ok, failure = pcall(callback, first, second)
    elseif first ~= nil then ok, failure = pcall(callback, first)
    else ok, failure = pcall(callback) end
    this, event, arg1 = previousThis, previousEvent, previousArg
    if not ok then Fail(failure) end
    return ok
end
Cleanup = function(keepMask)
    if state.cleaning then return false, "Native action-button restoration is already running." end
    state.cleaning = true
    local touched = false
    for index = 1, targetCount do
        local record = records[index]
        if record and record.touched and (keepMask == nil or not Wanted(keepMask, record.group)) then touched = true end
    end
    if touched and not state.restorationBlocked then
        state.failure, state.partial = nil, false
        state.replacedTargets, state.restoredTargets, state.restoreFailures = 0, 0, 0
    end
    -- A failing setter must never leave a live suppressing callback behind.
    for index = 1, targetCount do
        local record = records[index]
        if record and (keepMask == nil or not Wanted(keepMask, record.group)) then record.enabled = false end
    end
    UpdateState()
    for index = 1, targetCount do
        local record = records[index]
        if record and record.frame and (keepMask == nil or not Wanted(keepMask, record.group)) then
            if record.touched then
                local identity, frame = pcall(Global, record.name)
                if not identity then Fail(frame)
                elseif frame ~= record.frame then record.replaced = true; identity = false end
                local show = RestoreField(record, "Show", record.originalShow, record.showGuard, false, record.showAttempted)
                local onShow = RestoreField(record, "OnShow", record.originalOnShow, record.onShowGuard, true, record.onShowAttempted)
                local onEvent = RestoreField(record, "OnEvent", record.originalEvent, record.eventGuard, true, record.eventAttempted)
                local onUpdate = RestoreField(record, "OnUpdate", record.originalUpdate, record.updateGuard, true, record.updateAttempted)
                if record.replaced then state.replacedTargets = state.replacedTargets + 1 end
                if identity and show and onShow and onEvent and onUpdate then
                    local normal = Invoke(record.frame, record.normal, record.frame, "NORMAL")
                    local callback = record.shown and record.originalShow or record.hide
                    local visible = Invoke(record.frame, callback, record.frame)
                    local ok, shown = pcall(record.isShown, record.frame)
                    if not ok then Fail(shown)
                    elseif Shown(shown) ~= record.shown then Fail("A native action button's visibility could not be restored."); ok = false end
                    -- Restore the visibility lease before stock refresh: a
                    -- changed shared slot may legitimately make Update hide
                    -- or show the button again.
                    local refreshed = Invoke(record.frame, updateButton)
                    local hotkeys = Invoke(record.frame, updateHotkeys, record.buttonType)
                    if normal and refreshed and hotkeys and visible and ok then
                        state.restoredTargets = state.restoredTargets + 1
                    end
                end
            end
            record.frame, record.hide, record.getScript, record.setScript = nil, nil, nil, nil
            record.isShown, record.normal, record.buttonType = nil, nil, nil
            record.touched, record.showAttempted, record.onShowAttempted = nil, nil, nil
            record.eventAttempted, record.updateAttempted, record.hiding = nil, nil, nil
        end
    end
    if keepMask == nil or keepMask == 0 then updateButton, updateHotkeys = nil, nil end
    state.cleaning = nil
    state.partial = state.restorationBlocked or state.replacedTargets > 0 or state.restoreFailures > 0
    if state.partial then
        state.restorationBlocked = true
        if not state.failure then state.failure = "Native action-button ownership changed; reload before another replacement." end
        return false, state.failure
    end
    return true
end
local function Supported()
    return Bars.Services.NativeBarPolicy.Check()
end
function NativeBar.Check()
    local previousThis, previousEvent, previousArg = this, event, arg1
    local ran, ok, failure = pcall(Supported)
    this, event, arg1 = previousThis, previousEvent, previousArg
    if not ran then return false, tostring(ok) end
    return ok, failure
end
local function Snapshot(mask)
    local ok, failure
    if Wanted(mask, groups[1]) then ok, failure = NativeBar.Check()
    else ok, failure = Bars.Services.NativeBarPolicy.CheckCompeting() end
    if not ok then return false, failure end
    if type(ActionButton_Update) ~= "function" or type(ActionButton_UpdateHotkeys) ~= "function" then
        return false, "The native action-button refresh API is unavailable."
    end
    for _, group in ipairs(groups) do
        if Wanted(mask, group) then
            for index = group.first, group.last do
                local name = TargetName(index)
                local frame = Global(name)
                if not frame or type(frame.Show) ~= "function" or type(frame.Hide) ~= "function"
                    or type(frame.GetScript) ~= "function" or type(frame.SetScript) ~= "function"
                    or type(frame.IsShown) ~= "function" or type(frame.SetButtonState) ~= "function" then
                    return false, "Native " .. name .. " is unavailable or invalid."
                end
                if group.id ~= 1 then
                    if type(frame.GetParent) ~= "function" or type(frame.GetID) ~= "function" then
                        return false, "Native " .. name .. " has no fixed multi-bar identity."
                    end
                    local parent = frame:GetParent()
                    if not parent or type(parent.GetName) ~= "function" or parent:GetName() ~= group.name
                        or frame:GetID() ~= index - group.first + 1 then
                        return false, "Native " .. name .. " has a changed multi-bar identity."
                    end
                end
                local onEvent, onUpdate, onShow = frame:GetScript("OnEvent"), frame:GetScript("OnUpdate"), frame:GetScript("OnShow")
                if onEvent ~= nil and type(onEvent) ~= "function" or onUpdate ~= nil and type(onUpdate) ~= "function"
                    or onShow ~= nil and type(onShow) ~= "function" then
                    return false, "Native " .. name .. " has invalid callbacks."
                end
                local record = Record(index)
                if record.enabled then
                    if frame ~= record.frame or frame.Show ~= record.showGuard or onShow ~= record.onShowGuard
                        or onEvent ~= record.eventGuard or onUpdate ~= record.updateGuard then
                        return false, "Native " .. name .. " ownership changed while replaced."
                    end
                    if Shown(record.isShown(frame)) then return false, "Native " .. name .. " became visible while replaced." end
                else
                    if frame.Show == record.showGuard or onShow == record.onShowGuard
                        or onEvent == record.eventGuard or onUpdate == record.updateGuard then
                        state.restorationBlocked = true
                        return false, "A retired native action-button guard is still installed; reload before replacement."
                    end
                    record.frame, record.originalShow, record.hide = frame, frame.Show, frame.Hide
                    record.getScript, record.setScript, record.isShown = frame.GetScript, frame.SetScript, frame.IsShown
                    record.originalEvent, record.originalUpdate, record.originalOnShow = onEvent, onUpdate, onShow
                    record.shown, record.normal, record.buttonType = Shown(frame:IsShown()), frame.SetButtonState, frame.buttonType
                    record.replaced, record.enabled = false, false
                end
            end
        end
    end
    if not updateButton then updateButton, updateHotkeys = ActionButton_Update, ActionButton_UpdateHotkeys end
    return true
end
local function Begin(mask)
    local ok, failure = Snapshot(mask)
    if not ok then return false, failure end
    ok, failure = Cleanup(mask)
    if not ok then return false, failure end
    for index = 1, targetCount do
        if state.cancelled then return false, "Native action-button replacement was interrupted." end
        local record = records[index]
        if record and Wanted(mask, record.group) and not record.enabled then
            local frame = record.frame
            record.touched, record.enabled, record.showAttempted = true, true, true
            frame.Show = record.showGuard
            record.onShowAttempted = true; record.setScript(frame, "OnShow", record.onShowGuard)
            record.eventAttempted = true; record.setScript(frame, "OnEvent", record.eventGuard)
            record.updateAttempted = true; record.setScript(frame, "OnUpdate", record.updateGuard)
            if frame.Show ~= record.showGuard or record.getScript(frame, "OnShow") ~= record.onShowGuard
                or record.getScript(frame, "OnEvent") ~= record.eventGuard
                or record.getScript(frame, "OnUpdate") ~= record.updateGuard then
                return false, "Native " .. TargetName(index) .. " rejected replacement callbacks."
            end
            record.normal(frame, "NORMAL")
            record.hide(frame)
            if state.cancelled then return false, "Native action-button replacement was interrupted." end
            if Shown(record.isShown(frame)) then return false, "Native " .. TargetName(index) .. " could not be hidden." end
        end
    end
    UpdateState()
    state.failure = nil
    return true
end
local function SyncMask(mask)
    if state.syncing or state.cleaning or notifyingFailure then
        state.cancelled = true
        return false, "Native action-button replacement is already changing."
    end
    if state.restorationBlocked then return false, state.failure end
    local previousThis, previousEvent, previousArg = this, event, arg1
    state.syncing, state.cancelled = true, nil
    local ran, ok, failure
    if mask == 0 then ran, ok, failure = pcall(Cleanup)
    else ran, ok, failure = pcall(Begin, mask) end
    if not ran then failure, ok = ok, false end
    if not ok then
        local originalFailure = tostring(failure)
        local restored, cleanupFailure = Cleanup()
        state.failure = originalFailure
        if not restored and tostring(cleanupFailure) ~= originalFailure then
            state.failure = originalFailure .. " Restoration: " .. tostring(cleanupFailure)
        end
    end
    state.syncing, state.cancelled = nil, nil
    this, event, arg1 = previousThis, previousEvent, previousArg
    return ok, state.failure
end
local function ReadMask(mainLive, customLive)
    -- Engine's stable published table may change during a nested visibility
    -- callback. Snapshot every input before inspecting or touching frames.
    if type(mainLive) ~= "boolean" or customLive ~= nil and type(customLive) ~= "table" then
        error("Expected explicit native main and custom-bar visibility.", 0)
    end
    local desired = mainLive and 1 or 0
    for id = 2, 6 do
        local live = customLive and customLive[id]
        if live ~= nil and type(live) ~= "boolean" then error("Invalid native custom-bar visibility.", 0) end
        if id > 2 and live then desired = desired + 2 ^ (id - 2) end
    end
    return desired
end
function NativeBar.Sync(mainLive, customLive)
    local previousThis, previousEvent, previousArg = this, event, arg1
    local ran, mask = pcall(ReadMask, mainLive, customLive)
    this, event, arg1 = previousThis, previousEvent, previousArg
    if not ran then
        local originalFailure = tostring(mask)
        local restored, reason = NativeBar.Release()
        state.failure = originalFailure
        if not restored and tostring(reason) ~= originalFailure then state.failure = originalFailure .. " Restoration: " .. tostring(reason) end
        return false, state.failure
    end
    return SyncMask(mask)
end
function NativeBar.Acquire()
    if state.mainActive then return true end
    local mask = 1
    for _, group in ipairs(groups) do
        if group.id ~= 1 and state.customActive[group.id] then mask = mask + group.bit end
    end
    return SyncMask(mask)
end
function NativeBar.Release()
    if state.cleaning then
        state.cancelled = true
        return false, "Native action-button restoration is already running."
    end
    if state.syncing then state.cancelled = true end
    if not state.active then
        if state.restorationBlocked then return false, state.failure end
        return true
    end
    local previousThis, previousEvent, previousArg = this, event, arg1
    local ok, failure = Cleanup()
    this, event, arg1 = previousThis, previousEvent, previousArg
    return ok, failure
end
function NativeBar.GetState() return state end
function NativeBar.SetFailureObserver(callback)
    if callback ~= nil and type(callback) ~= "function" then return false, "Expected a native failure observer or nil." end
    failureObserver = callback
    return true
end
