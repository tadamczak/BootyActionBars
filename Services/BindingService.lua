local BindingService = {}
BootyActionBars.Services.BindingService = BindingService
local floor = math.floor
local Config = BootyActionBars.Services.BarConfig
local function Integer(value, limit)
    return type(value) == "number" and value >= 1 and value <= limit and value == floor(value)
end
function BindingService.Command(barId, index)
    if not Config.ValidLayoutID(barId) or not Integer(index, Config.ValidOrdinaryID(barId) and Config.SLOT_COUNT or 10) then return nil end
    return Config.BindingPrefix(barId) .. index
end
local function OwnCommand(command)
    if type(command) ~= "string" then return false end
    for _, barId in ipairs(Config.LayoutIDs) do
        for index = 1, Config.ValidOrdinaryID(barId) and Config.SLOT_COUNT or 10 do
            if command == BindingService.Command(barId, index) then return true end
        end
    end
    return false
end
local function Key(value)
    return type(value) == "string" and value ~= "" and string.len(value) <= 64
        and not string.find(value, "[%c%s]") and value ~= "UNKNOWN" and value ~= "ESCAPE"
        and value ~= "SHIFT" and value ~= "CTRL" and value ~= "ALT"
end
local function Action(value)
    if value == nil then return "" end
    if type(value) ~= "string" then error("The client returned an invalid binding action.") end
    return value
end
local function BindingKey(value)
    if value == nil or value == "" then return nil end
    if type(value) ~= "string" then error("The client returned an invalid binding key.") end
    return value
end
local function Enabled(value) return value ~= nil and value ~= false and value ~= 0 end
local function Protected(callback, first, second)
    local previousThis, previousEvent, previousArg = this, event, arg1
    local ran, result, reason, extra = pcall(callback, first, second)
    this, event, arg1 = previousThis, previousEvent, previousArg
    if not ran then return false, tostring(result) end
    return result, reason, extra
end

-- Edits belong to one transient session. Native input and durable client
-- bindings are untouched until an explicitly reviewed commit.
function BindingService.Create(api)
    api = api or _G
    local service = {}
    local state = {active = false, revision = 0, changedCount = 0, conflictCount = 0}
    local keys, keyRecords, commands, commandRecords = {}, {}, {}, {}
    local function Reset()
        for key in pairs(keyRecords) do keyRecords[key] = nil end
        for command in pairs(commandRecords) do commandRecords[command] = nil end
        for index = table.getn(keys), 1, -1 do table.remove(keys, index) end
        for index = table.getn(commands), 1, -1 do table.remove(commands, index) end
        state.changedCount, state.conflictCount, state.failure = 0, 0, nil
        state.revision = state.revision + 1
    end
    local function CurrentSet()
        local value = api.GetCurrentBindingSet()
        if value ~= 1 and value ~= 2 then error("The current binding set is unavailable or invalid.") end
        return value
    end
    local function ReadAction(key) return Action(api.GetBindingAction(key)) end
    local function Touch(key)
        local record = keyRecords[key]
        if record then return record end
        record = {key = key, original = ReadAction(key)}
        record.desired = record.original
        keyRecords[key] = record; table.insert(keys, record)
        return record
    end
    local function Capture(command)
        local record = commandRecords[command]
        if record then return record end
        local first, second = api.GetBindingKey(command)
        first, second = BindingKey(first), BindingKey(second)
        record = {command = command, first = first, second = second}
        commandRecords[command] = record; table.insert(commands, record)
        if first then Touch(first) end
        if second then Touch(second) end
        return record
    end
    local function Recount()
        state.changedCount, state.conflictCount = 0, 0
        for _, record in ipairs(keys) do
            if record.original ~= record.desired then
                state.changedCount = state.changedCount + 1
                if record.original ~= "" and record.desired ~= "" and not OwnCommand(record.original) then
                    state.conflictCount = state.conflictCount + 1
                end
            end
        end
        state.revision = state.revision + 1
    end
    local function Planned(command)
        local record = Capture(command)
        local first, second
        if record.first and Touch(record.first).desired == command then first = record.first end
        if record.second and Touch(record.second).desired == command then
            if first then second = record.second else first = record.second end
        end
        for _, key in ipairs(keys) do
            if key.desired == command and key.key ~= first and key.key ~= second then
                if not first then first = key.key
                elseif not second then second = key.key
                else error("A command cannot have more than two staged keys.") end
            end
        end
        return first, second
    end
    local function Begin()
        if state.active then return true end
        if type(api) ~= "table" or type(api.GetBindingAction) ~= "function" or type(api.GetBindingKey) ~= "function"
            or type(api.GetCurrentBindingSet) ~= "function" or type(api.SetBinding) ~= "function"
            or type(api.SaveBindings) ~= "function" then return false, "Native keybinding APIs are unavailable." end
        Reset(); state.bindingSet = CurrentSet(); state.active = true
        return true
    end
    function service.Begin() return Protected(Begin) end
    function service.Cancel()
        if state.committing then state.cancelRequested = true; return true end
        state.active = false; Reset(); return true
    end
    local function GetKeys(command)
        if not state.active or not OwnCommand(command) then return false, "Choose a BootyActionBars button." end
        return true, Planned(command)
    end
    function service.GetKeys(command) return Protected(GetKeys, command) end
    function service.GetDraftKeys(command)
        if not state.active then return false end
        local record = commandRecords[command]
        if not record or record.first and not keyRecords[record.first]
            or record.second and not keyRecords[record.second] then return false end
        -- Only commands whose native snapshot already belongs to this session
        -- have a draft. Label refresh must never discover new native bindings.
        return true, Planned(command)
    end
    local function Stage(command, key)
        if not state.active or state.committing then return false, "Keybinding editing is inactive or saving." end
        if not OwnCommand(command) then return false, "Choose a BootyActionBars button." end
        if not Key(key) then return false, "Choose a valid key; Escape clears the selected button." end
        if string.find(key, "MOUSEWHEEL", 1, true) then return false, "WoW 1.12 cannot bind mousewheel to down/up action commands." end
        local first, second = Planned(command)
        if key == first or key == second then return true end
        if first and second then return false, "This button already has two keys. Clear it before assigning another key." end
        local record = Touch(key)
        if record.original ~= "" then Capture(record.original) end
        record.desired = command
        Recount(); return true
    end
    function service.StageKey(command, key) return Protected(Stage, command, key) end
    local function Clear(command)
        if not state.active or state.committing or not OwnCommand(command) then return false, "Choose a BootyActionBars button while editing." end
        Capture(command)
        for _, record in ipairs(keys) do
            if record.desired == command then
                -- Clearing a staged move cancels that move; it must not erase
                -- the native command which still owns the key before Save.
                record.desired = record.original == command and "" or record.original
            end
        end
        Recount(); return true
    end
    function service.Clear(command) return Protected(Clear, command) end
    local function Validate()
        if CurrentSet() ~= state.bindingSet then return false, "The active binding set changed. Cancel and reopen binding mode." end
        for _, record in ipairs(keys) do
            if ReadAction(record.key) ~= record.original then return false, "Bindings changed while editing. Cancel and reopen binding mode." end
        end
        for _, record in ipairs(commands) do
            local first, second = api.GetBindingKey(record.command)
            if BindingKey(first) ~= record.first or BindingKey(second) ~= record.second then
                return false, "Bindings changed while editing. Cancel and reopen binding mode."
            end
        end
        if CurrentSet() ~= state.bindingSet then return false, "The binding set changed during validation. Cancel and reopen binding mode." end
        return true
    end
    local function Put(key, command)
        if CurrentSet() ~= state.bindingSet then return false, "The binding set changed while saving." end
        local result = api.SetBinding(key, command ~= "" and command or nil)
        if CurrentSet() ~= state.bindingSet then return false, "The binding set changed while saving." end
        if not Enabled(result) then return false, "The client declined binding " .. key .. "." end
        local action = ReadAction(key)
        if CurrentSet() ~= state.bindingSet then return false, "The binding set changed while saving." end
        if action ~= command then return false, "Binding " .. key .. " did not match the requested action." end
        return true
    end
    local function Apply()
        for _, record in ipairs(keys) do
            if record.desired ~= record.original then
                record.attempted = true
                local ok, reason = Put(record.key, "")
                if not ok then return false, reason end
                if state.cancelRequested then return false, "Binding editing closed while saving." end
            end
        end
        for _, record in ipairs(keys) do
            if record.desired ~= record.original and record.desired ~= "" then
                local ok, reason = Put(record.key, record.desired)
                if not ok then return false, reason end
                if state.cancelRequested then return false, "Binding editing closed while saving." end
            end
        end
        if CurrentSet() ~= state.bindingSet then return false, "The binding set changed while saving." end
        state.saveAttempted = true
        local result = api.SaveBindings(state.bindingSet)
        if result == false or result == 0 then return false, "The client declined saving bindings." end
        if state.cancelRequested then return false, "Binding editing closed while saving." end
        if CurrentSet() ~= state.bindingSet then return false, "The binding set changed while saving." end
        for _, record in ipairs(keys) do
            if ReadAction(record.key) ~= record.desired then return false, "Bindings changed while saving." end
        end
        if CurrentSet() ~= state.bindingSet then return false, "The binding set changed while saving." end
        return true
    end
    local function Rollback()
        -- A synchronous native hook may switch sets. Editing that new set
        -- would overwrite keys which never belonged to this transaction.
        if CurrentSet() ~= state.bindingSet then return false, "The binding set changed; rollback cannot edit the new set." end
        local firstFailure
        -- Restore all keys for affected commands, including foreign second
        -- keys, so the native primary/secondary order is preserved.
        for _, record in ipairs(keys) do
            if CurrentSet() ~= state.bindingSet then return false, "The binding set changed; rollback cannot edit the new set." end
            local ok, current = pcall(ReadAction, record.key)
            if not ok then firstFailure = firstFailure or tostring(current)
            elseif current ~= record.original and current ~= record.desired and current ~= "" then
                firstFailure = firstFailure or "Binding ownership changed during rollback."
            else
                local restored, reason = Protected(Put, record.key, "")
                if not restored then firstFailure = firstFailure or reason end
            end
        end
        for _, record in ipairs(commands) do
            for _, key in ipairs({record.first, record.second}) do
                if key then
                    if CurrentSet() ~= state.bindingSet then return false, "The binding set changed; rollback cannot edit the new set." end
                    local current = ReadAction(key)
                    if current == "" then
                        local restored, reason = Protected(Put, key, record.command)
                        if not restored then firstFailure = firstFailure or reason end
                    elseif current ~= record.command then firstFailure = firstFailure or "Binding ownership changed during rollback." end
                end
            end
        end
        if CurrentSet() ~= state.bindingSet then return false, "The binding set changed; rollback cannot edit the new set." end
        if state.saveAttempted then
            local ran, result = pcall(api.SaveBindings, state.bindingSet)
            if not ran or result == false or result == 0 then firstFailure = firstFailure or "The original bindings could not be saved after rollback." end
        end
        if firstFailure then return false, firstFailure end
        return Validate()
    end
    function service.Commit(confirmConflicts)
        if not state.active or state.committing then return false, "Keybinding editing is inactive or saving." end
        if state.changedCount == 0 then return true end
        if state.conflictCount > 0 and confirmConflicts ~= true then return false, "Review displaced foreign bindings before saving." end
        local valid, reason = Protected(Validate)
        if not valid then state.failure = reason; return false, reason end
        state.committing, state.saveAttempted, state.cancelRequested = true, false, false
        local ok, failure = Protected(Apply)
        if not ok then
            local restored, cleanupFailure = Protected(Rollback)
            if not restored then failure = tostring(failure) .. " Rollback: " .. tostring(cleanupFailure) end
            state.failure = failure
        else Reset() end
        state.committing = false
        if state.cancelRequested then state.active = false; Reset() end
        state.cancelRequested = nil
        return ok, failure
    end
    local function Label(command)
        if command == "" then return "unbound" end
        local label = api["BINDING_NAME_" .. command]
        return type(label) == "string" and label ~= "" and label or command
    end
    local function Preview(conflictsOnly)
        local lines = {}
        for _, record in ipairs(keys) do
            if record.original ~= record.desired and (not conflictsOnly or record.original ~= ""
                and record.desired ~= "" and not OwnCommand(record.original)) then
                table.insert(lines, record.key .. ": " .. Label(record.original) .. " -> " .. Label(record.desired))
            end
        end
        return table.concat(lines, "\n")
    end
    function service.GetPreview() return Preview(false) end
    function service.GetConflictPreview() return Preview(true) end
    function service.GetState() return state end
    return service
end
