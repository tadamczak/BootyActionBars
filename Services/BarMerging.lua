local Merging = {}
BootyActionBars.Services.BarMerging = Merging
Merging.LIMIT, Merging.SLOTS_PER_BAR = 6, 12

function Merging.ValidID(id)
    return type(id) == "number" and id >= 1 and id <= Merging.LIMIT and id == math.floor(id)
end
local function Children(list, allowEmpty)
    if type(list) ~= "table" then return nil, "Merged action bars need an ordered child list." end
    local count, seen = 0, {}
    for index, id in pairs(list) do
        if type(index) ~= "number" or index < 1 or index > 5 or index ~= math.floor(index)
            or not Merging.ValidID(id) or seen[id] then return nil, "Merged action bars contain an invalid or duplicate child." end
        seen[id], count = true, count + 1
    end
    if count == 0 and not allowEmpty then return nil, "An empty merge group must be removed." end
    for index = 1, count do if rawget(list, index) == nil then return nil, "Merged action bar child lists must be dense." end end
    return count
end
function Merging.Validate(groups)
    if groups == nil then return true end
    if type(groups) ~= "table" then return false, "Invalid saved merged action bars." end
    local owners = {}
    for host, list in pairs(groups) do
        if not Merging.ValidID(host) then return false, "Only ordinary action bars 1-6 can own merged groups." end
        local count, failure = Children(list, false)
        if not count then return false, failure end
        for index = 1, count do
            local id = rawget(list, index)
            if id == host or rawget(groups, id) ~= nil or owners[id] then
                return false, "Merged groups must be flat and disjoint; a bar cannot belong to two groups."
            end
            owners[id] = host
        end
    end
    return true
end
function Merging.Copy(groups)
    local valid, failure = Merging.Validate(groups)
    if not valid then return nil, failure end
    local copy = {}
    for host, list in pairs(groups or {}) do
        local children = {}
        for index = 1, table.getn(list) do children[index] = rawget(list, index) end
        copy[host] = children
    end
    return copy
end
function Merging.Equal(first, second)
    if not Merging.Validate(first) or not Merging.Validate(second) then return false end
    for host = 1, Merging.LIMIT do
        local left, right = first and rawget(first, host), second and rawget(second, host)
        if (left == nil) ~= (right == nil) then return false end
        if left then
            if table.getn(left) ~= table.getn(right) then return false end
            for index = 1, table.getn(left) do if rawget(left, index) ~= rawget(right, index) then return false end end
        end
    end
    return true
end
function Merging.Read(groups, id)
    if not Merging.ValidID(id) then return nil, "Only ordinary action bars can be merged." end
    local valid, failure = Merging.Validate(groups)
    if not valid then return nil, failure end
    for host = 1, Merging.LIMIT do
        local children = groups and rawget(groups, host)
        if children then
            local count = (table.getn(children) + 1) * Merging.SLOTS_PER_BAR
            if id == host then return host, count, 0 end
            for index = 1, table.getn(children) do if rawget(children, index) == id then return host, count, index end end
        end
    end
    return id, Merging.SLOTS_PER_BAR, 0
end
function Merging.Members(groups, host, target)
    local owner, count = Merging.Read(groups, host)
    if not owner then return nil, count end
    if owner ~= host then return nil, "Choose the primary bar of the merged group." end
    target = target or {}
    local children = groups and rawget(groups, host)
    target[1] = host
    local length = children and table.getn(children) or 0
    for index = 1, length do target[index + 1] = rawget(children, index) end
    for index = length + 2, table.getn(target) do target[index] = nil end
    return target
end
function Merging.Patch(groups, host, children)
    if not Merging.ValidID(host) then return nil, "Only ordinary action bars can own a merged group." end
    local copy, failure = Merging.Copy(groups)
    if not copy then return nil, failure end
    local count = 0
    if children ~= nil then
        count, failure = Children(children, true)
        if not count then return nil, failure end
    end
    copy[host] = nil
    if count > 0 then
        local list = {}
        for index = 1, count do list[index] = rawget(children, index) end
        copy[host] = list
    end
    local valid; valid, failure = Merging.Validate(copy)
    if not valid then return nil, failure end
    return copy
end
local function Detach(groups, owner, source)
    local list = groups[owner]
    for index = 1, table.getn(list) do
        if list[index] == source then
            for following = index, table.getn(list) - 1 do list[following] = list[following + 1] end
            list[table.getn(list)] = nil
            if table.getn(list) == 0 then groups[owner] = nil end
            return
        end
    end
end
function Merging.SetDestination(groups, source, destination)
    if not Merging.ValidID(source) or destination ~= nil and not Merging.ValidID(destination) then
        return nil, "Only ordinary action bars 1-6 can be merged."
    end
    if source == destination then return nil, "An action bar cannot be merged into itself." end
    local copy, failure = Merging.Copy(groups)
    if not copy then return nil, failure end
    local sourceOwner = Merging.Read(groups, source)
    if destination == nil then
        if sourceOwner ~= source then Detach(copy, sourceOwner, source) end
        return copy
    end
    local destinationOwner = Merging.Read(groups, destination)
    if sourceOwner == destinationOwner then
        if sourceOwner == source then return nil, "A primary action bar cannot be merged into its own group." end
        return copy
    end
    local moving
    if sourceOwner == source then
        moving = Merging.Members(groups, source)
        copy[source] = nil
    else
        moving = {source}
        Detach(copy, sourceOwner, source)
    end
    local children = copy[destinationOwner] or {}
    copy[destinationOwner] = children
    local count = table.getn(children)
    for index = 1, table.getn(moving) do children[count + index] = moving[index] end
    local valid; valid, failure = Merging.Validate(copy)
    if not valid then return nil, failure end
    return copy
end
