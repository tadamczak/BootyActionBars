local ActionPageService = {}
BootyActionBars.Services.ActionPageService = ActionPageService

local floor = math.floor

local function Integer(value, minimum, maximum)
    return type(value) == "number" and value == value and value >= minimum
        and value <= maximum and value == floor(value)
end

-- Stock 1.12 has six ordinary pages. On page one the client bonus offset
-- selects pages seven through ten; higher offsets exceed the 120-slot store.
-- Class names and form indices do not determine the slot mapping here.
function ActionPageService.Resolve(page, bonusOffset)
    if not Integer(page, 1, 6) then return nil, "The native action-bar page is unavailable or invalid." end
    if not Integer(bonusOffset, 0, 4) then return nil, "The native bonus-bar state is unavailable or invalid." end
    local effectivePage = page
    if page == 1 and bonusOffset > 0 then effectivePage = 6 + bonusOffset end
    return (effectivePage - 1) * 12, effectivePage
end

local function ReadState(api)
    local page = api.CURRENT_ACTIONBAR_PAGE
    if not Integer(page, 1, 6) then return nil, "The native action-bar page is unavailable or invalid." end
    local getBonus = api.GetBonusBarOffset
    if type(getBonus) ~= "function" then return nil, "The native bonus-bar API is unavailable." end
    return ActionPageService.Resolve(page, getBonus())
end

-- Keep lookup and invocation inside the protected read: injected adapters or
-- late API replacements may throw. No global page fallback masks a bad state.
function ActionPageService.Read(api)
    if api == nil then api = _G end
    if type(api) ~= "table" then return nil, "The native action-bar API is unavailable." end
    local previousThis, previousEvent, previousArg = this, event, arg1
    local ok, offset, effectivePage = pcall(ReadState, api)
    this, event, arg1 = previousThis, previousEvent, previousArg
    if not ok then return nil, "The native action-bar state could not be read: " .. tostring(offset) end
    return offset, effectivePage
end
