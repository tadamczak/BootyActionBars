local Bars = BootyActionBars
local NativeBar = {}
Bars.Modules.NativeBar = NativeBar
local state = {active = false, restorationBlocked = false, partial = false,
    replacedTargets = 0, restoredTargets = 0, restoreFailures = 0}
local records = {}
local updateButton, updateHotkeys

local function Shown(value) return value ~= nil and value ~= false and value ~= 0 end
local function Field(frame, name) return frame[name] end
local function Assign(frame, name, value) frame[name] = value end
local function Global(name)
    if type(getglobal) == "function" then return getglobal(name) end
    return _G[name]
end
local function Record(index)
    local record = records[index]
    if record then return record end
    record = {}
    records[index] = record
    -- Fixed arity delegates do no work while leased. Retained guards become
    -- inert passthroughs before any restoration is attempted.
    record.showGuard = function(frame)
        if not record.enabled then return record.originalShow(frame) end
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
local function Cleanup()
    state.active = false
    state.failure, state.partial = nil, false
    state.replacedTargets, state.restoredTargets, state.restoreFailures = 0, 0, 0
    -- A failing setter must never leave a live suppressing callback behind.
    for index = 1, 12 do if records[index] then records[index].enabled = false end end
    for index = 1, 12 do
        local record = records[index]
        if record and record.frame then
            if record.touched then
                local show = RestoreField(record, "Show", record.originalShow, record.showGuard, false, record.showAttempted)
                local onEvent = RestoreField(record, "OnEvent", record.originalEvent, record.eventGuard, true, record.eventAttempted)
                local onUpdate = RestoreField(record, "OnUpdate", record.originalUpdate, record.updateGuard, true, record.updateAttempted)
                if record.replaced then state.replacedTargets = state.replacedTargets + 1 end
                if show and onEvent and onUpdate then
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
            record.touched, record.showAttempted, record.eventAttempted, record.updateAttempted = nil, nil, nil, nil
        end
    end
    updateButton, updateHotkeys = nil, nil
    state.partial = state.replacedTargets > 0 or state.restoreFailures > 0
    if state.partial then
        state.restorationBlocked = true
        if not state.failure then state.failure = "Native action-button ownership changed; reload before another replacement." end
        return false, state.failure
    end
    return true
end
local function Supported()
    local ok, failure = Bars.Services.NativeBarPolicy.Check()
    if not ok then return false, failure end
    local bonus = Global("BonusActionBarFrame")
    if not bonus or type(bonus.IsShown) ~= "function" then return false, "The native bonus action-bar frame is unavailable." end
    if Shown(bonus:IsShown()) then return false, "Wait until the native bonus action bar finishes hiding." end
    return true
end
function NativeBar.Check()
    local previousThis, previousEvent, previousArg = this, event, arg1
    local ran, ok, failure = pcall(Supported)
    this, event, arg1 = previousThis, previousEvent, previousArg
    if not ran then return false, tostring(ok) end
    return ok, failure
end
local function Snapshot()
    local ok, failure = NativeBar.Check()
    if not ok then return false, failure end
    if type(ActionButton_Update) ~= "function" or type(ActionButton_UpdateHotkeys) ~= "function" then
        return false, "The native action-button refresh API is unavailable."
    end
    for index = 1, 12 do
        local frame = Global("ActionButton" .. index)
        if not frame or type(frame.Show) ~= "function" or type(frame.Hide) ~= "function"
            or type(frame.GetScript) ~= "function" or type(frame.SetScript) ~= "function"
            or type(frame.IsShown) ~= "function" or type(frame.SetButtonState) ~= "function" then
            return false, "Native ActionButton" .. index .. " is unavailable or invalid."
        end
        local onEvent, onUpdate = frame:GetScript("OnEvent"), frame:GetScript("OnUpdate")
        if onEvent ~= nil and type(onEvent) ~= "function" or onUpdate ~= nil and type(onUpdate) ~= "function" then
            return false, "Native ActionButton" .. index .. " has invalid callbacks."
        end
        local record = Record(index)
        if frame.Show == record.showGuard or onEvent == record.eventGuard or onUpdate == record.updateGuard then
            state.restorationBlocked = true
            return false, "A retired native action-button guard is still installed; reload before replacement."
        end
        record.frame, record.originalShow, record.hide = frame, frame.Show, frame.Hide
        record.getScript, record.setScript, record.isShown = frame.GetScript, frame.SetScript, frame.IsShown
        record.originalEvent, record.originalUpdate = onEvent, onUpdate
        record.shown, record.normal, record.buttonType = Shown(frame:IsShown()), frame.SetButtonState, frame.buttonType
        record.replaced, record.enabled = false, false
    end
    updateButton, updateHotkeys = ActionButton_Update, ActionButton_UpdateHotkeys
    return true
end
local function Begin()
    local ok, failure = Snapshot()
    if not ok then return false, failure end
    for index = 1, 12 do
        local record, frame = records[index], records[index].frame
        record.touched, record.enabled, record.showAttempted = true, true, true
        frame.Show = record.showGuard
        record.eventAttempted = true; record.setScript(frame, "OnEvent", record.eventGuard)
        record.updateAttempted = true; record.setScript(frame, "OnUpdate", record.updateGuard)
        if frame.Show ~= record.showGuard or record.getScript(frame, "OnEvent") ~= record.eventGuard
            or record.getScript(frame, "OnUpdate") ~= record.updateGuard then
            return false, "Native ActionButton" .. index .. " rejected replacement callbacks."
        end
        record.normal(frame, "NORMAL")
        record.hide(frame)
        if Shown(record.isShown(frame)) then return false, "Native ActionButton" .. index .. " could not be hidden." end
    end
    state.active, state.failure = true, nil
    state.partial, state.replacedTargets, state.restoredTargets, state.restoreFailures = false, 0, 0, 0
    return true
end
function NativeBar.Acquire()
    if state.active then return true end
    if state.restorationBlocked then return false, state.failure end
    local previousThis, previousEvent, previousArg = this, event, arg1
    local ran, ok, failure = pcall(Begin)
    if not ran then failure, ok = ok, false end
    if not ok then
        local originalFailure = tostring(failure)
        local restored, cleanupFailure = Cleanup()
        state.failure = originalFailure
        if not restored then state.failure = originalFailure .. " Restoration: " .. tostring(cleanupFailure) end
    end
    this, event, arg1 = previousThis, previousEvent, previousArg
    return ok, state.failure
end
function NativeBar.Release()
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
