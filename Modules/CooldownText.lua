local Bars = BootyActionBars
local Service, UI = Bars.Services.CooldownTextService, Bars.UI.Components
local Module = {}
Bars.Modules.CooldownText = Module
local records, views, active = {}, {}, {}
local state = {activeCount = 0, attachedCount = 0}
local observer, notifying = nil, false

local function Call(record, method, first, second, third, fourth, fifth)
    local oldThis, oldEvent, oldArg = this, event, arg1
    this = record.button
    local ok, result = pcall(record.label[method], record.label, first, second, third, fourth, fifth)
    this, event, arg1 = oldThis, oldEvent, oldArg
    if not ok then error(result, 0) end
    if result == false then error("Cooldown text rejected " .. method .. ".", 0) end
end
local function Notify(previous)
    if (previous > 0) == (state.activeCount > 0) or not observer or notifying then return true end
    local oldThis, oldEvent, oldArg = this, event, arg1
    notifying = true
    local ran, ok, failure = pcall(observer, state.activeCount > 0)
    notifying = false
    this, event, arg1 = oldThis, oldEvent, oldArg
    if not ran then return false, tostring(ok) end
    if ok == false then return false, failure or "The cooldown worker could not be updated." end
    return true
end
local function Remove(record)
    if record.activeIndex then
        local index, last = record.activeIndex, active[state.activeCount]
        active[index] = last; last.activeIndex = index
        active[state.activeCount] = nil; state.activeCount = state.activeCount - 1
        record.activeIndex = nil
    end
    if record.shown then Call(record, "Hide"); record.shown = false end
end
local function Eligible(record)
    local view = record.owner
    local count = view.view.count or (view.view.id <= 6 and 12 or 0)
    return view.visible and view.enabled and view.a > 0 and not record.suspended and not record.expired
        and record.button.index <= count and record.button.emptyHidden ~= true
        and record.enabled and record.start > 0 and record.duration >= Service.MIN_DURATION
end
local function Sync(record)
    if Eligible(record) then
        if not record.activeIndex then
            state.activeCount = state.activeCount + 1
            active[state.activeCount] = record; record.activeIndex = state.activeCount
        end
    else Remove(record) end
end
local function Owner(view)
    local owner = views[view]
    if not owner then
        owner = {view = view, visible = false, enabled = true, size = 14, r = 1, g = 1, b = 1, a = 1, records = {}}
        views[view] = owner
    end
    return owner
end
local function Style(record)
    local owner = record.owner
    if record.fontSize ~= owner.size then
        Call(record, "SetFont", record.face, owner.size, "OUTLINE"); record.fontSize = owner.size
    end
    if record.r ~= owner.r or record.g ~= owner.g or record.b ~= owner.b or record.a ~= owner.a then
        Call(record, "SetTextColor", owner.r, owner.g, owner.b, owner.a)
        record.r, record.g, record.b, record.a = owner.r, owner.g, owner.b, owner.a
    end
end
local function Attach(button)
    local view, index = button and button.bar, button and button.index
    if type(view) ~= "table" or type(view.id) ~= "number" or view.id < 1 or view.id > 8 or view.id ~= math.floor(view.id)
        or type(index) ~= "number" or index < 1 or index ~= math.floor(index)
        or index > (view.id <= 6 and 12 or 10) or not button.cooldown then
        return false, "Invalid cooldown button."
    end
    local id = view.id <= 6 and (view.id - 1) * 12 + index or 72 + (view.id - 7) * 10 + index
    local record = records[id]
    if record then
        if record.button ~= button then return false, "A cooldown button identity is already owned." end
        if record.creationFailure then return false, record.creationFailure end
        return true
    end
    record = {button = button, owner = Owner(view), start = 0, duration = 0, enabled = false, shown = false}
    records[id], record.owner.records[index] = record, record
    state.attachedCount = state.attachedCount + 1
    -- These Models belong to BAB for their pooled lifetime. Installed number
    -- addons honor this flag before allocating their per-button text workers.
    button.cooldown.noCooldownCount = true
    record.creationFailure = "Cooldown text construction did not finish."
    record.label = UI.CreateLabel(button, nil, "OVERLAY", "NumberFontNormal")
    if not record.label then return false, "The cooldown label is unavailable." end
    record.shown = true
    button.cooldownLabel = record.label
    local oldThis, oldEvent, oldArg = this, event, arg1
    this = button
    record.face = record.label:GetFont()
    this, event, arg1 = oldThis, oldEvent, oldArg
    if not record.face then return false, "The cooldown font is unavailable." end
    Call(record, "SetPoint", "CENTER", button, "CENTER", 0, 0)
    Call(record, "Hide"); record.shown = false; Style(record)
    record.creationFailure = nil
    return true
end
local function ConfigureView(view, drawing)
    if type(view) ~= "table" or type(drawing) ~= "table" then return false, "Invalid cooldown appearance." end
    local enabled = drawing.showCooldownText ~= false
    local size, r, g, b, a = drawing.cooldownFontSize or 14, drawing.cooldownR or 1,
        drawing.cooldownG or 1, drawing.cooldownB or 1, drawing.cooldownA or 1
    if drawing.showCooldownText ~= nil and type(drawing.showCooldownText) ~= "boolean"
        or not Service.ValidFontSize(size) or not Service.ValidColor(r) or not Service.ValidColor(g)
        or not Service.ValidColor(b) or not Service.ValidColor(a) then return false, "Invalid cooldown appearance." end
    local owner = Owner(view)
    owner.enabled, owner.size, owner.r, owner.g, owner.b, owner.a = enabled, size, r, g, b, a
    for _, record in pairs(owner.records) do
        Style(record)
        if owner.visible then record.suspended = false end
        Sync(record)
    end
    return true
end
local function Record(button)
    local owner = button and views[button.bar]
    return owner and owner.records[button.index]
end
local function Update(button, start, duration, enabled)
    local record = Record(button)
    if not record or record.creationFailure then return false, record and record.creationFailure or "The cooldown text is not attached." end
    if not Service.ValidCooldown(start, duration) then return false, "Invalid cooldown timer." end
    local changed = record.start ~= start or record.duration ~= duration
    local activeTimer = enabled ~= nil and enabled ~= false and enabled ~= 0
    if changed or record.enabled ~= activeTimer or record.suspended then record.revision = (record.revision or 0) + 1 end
    record.start, record.duration, record.enabled = start, duration, activeTimer
    record.suspended = false
    if changed then record.expired, record.kind, record.value = nil, nil, nil end
    Sync(record)
    return true
end
local function SuspendView(view)
    local owner = views[view]
    if not owner then return true end
    local firstFailure
    for _, record in pairs(owner.records) do
        record.suspended = true
        local ok, failure = pcall(Remove, record)
        if not ok and not firstFailure then firstFailure = tostring(failure) end
    end
    return firstFailure == nil, firstFailure
end
local function SetViewVisible(view, visible)
    if type(visible) ~= "boolean" then return false, "Invalid cooldown view visibility." end
    local owner = views[view]
    if not owner then return true end
    owner.visible = visible
    for _, record in pairs(owner.records) do
        if visible then record.suspended = false end
        Sync(record)
    end
    return true
end
local function Tick(now)
    if not Service.Finite(now) then return false, "Invalid cooldown clock." end
    local index = 1
    while index <= state.activeCount do
        local record = active[index]
        if not Eligible(record) then Remove(record)
        else
            local kind, value = Service.Bucket(record.start + record.duration - now)
            if kind == nil then return false, value end
            if kind == 0 then record.expired = true; Remove(record)
            else
                local revision = record.revision
                if record.kind ~= kind or record.value ~= value then
                    local text, failure = Service.Format(kind, value)
                    if not text then return false, failure end
                    Call(record, "SetText", text)
                    if record.revision == revision then record.kind, record.value = kind, value end
                end
                -- A native text/visibility hook can cancel or replace a timer.
                -- Keep that new state; do not resurrect the outer snapshot.
                if record.revision == revision and record.activeIndex and Eligible(record) and not record.shown then
                    record.shown = true; Call(record, "Show")
                end
                if active[index] == record then index = index + 1 end
            end
        end
    end
    return true
end
local function Cleanup()
    local firstFailure
    for _, owner in pairs(views) do
        local ok, failure = SuspendView(owner.view)
        if not ok then
            if firstFailure then firstFailure = firstFailure .. " " .. tostring(failure)
            else firstFailure = tostring(failure) end
        end
    end
    return firstFailure
end
local function Run(callback, first, second, third, fourth)
    local oldThis, oldEvent, oldArg = this, event, arg1
    local previous = state.activeCount
    local ran, ok, failure = pcall(callback, first, second, third, fourth)
    this, event, arg1 = oldThis, oldEvent, oldArg
    if not ran then ok, failure = false, tostring(ok) end
    if ok == false then
        -- A drawing failure cannot retain an apparently healthy worker. Try
        -- every region independently and preserve the original diagnostic.
        local cleanupFailure = Cleanup()
        if cleanupFailure then failure = tostring(failure) .. " Cleanup: " .. cleanupFailure end
        state.failure = failure
    end
    local notified, reason = Notify(previous)
    if not notified then
        local cleanupFailure = Cleanup()
        if ok == false then failure = tostring(failure) .. " Worker: " .. tostring(reason) else failure = reason end
        if cleanupFailure then failure = tostring(failure) .. " Cleanup: " .. cleanupFailure end
        ok, state.failure = false, failure
    elseif ok ~= false then state.failure = nil end
    this, event, arg1 = oldThis, oldEvent, oldArg
    return ok ~= false, failure
end
function Module.Attach(button)
    local ok, failure = Run(Attach, button)
    if not ok and type(button) == "table" then
        local record = Record(button)
        if record and record.button == button and record.creationFailure then record.creationFailure = failure end
    end
    return ok, failure
end
function Module.ConfigureView(view, drawing) return Run(ConfigureView, view, drawing) end
function Module.Update(button, start, duration, enabled) return Run(Update, button, start, duration, enabled) end
function Module.SuspendView(view) return Run(SuspendView, view) end
function Module.SetViewVisible(view, visible) return Run(SetViewVisible, view, visible) end
function Module.Tick(now) return Run(Tick, now) end
function Module.GetDemand() return state.activeCount > 0 end
function Module.SetDemandObserver(callback)
    if callback ~= nil and type(callback) ~= "function" then return false, "Invalid cooldown observer." end
    observer = callback
    return true
end
function Module.GetState() return state end
