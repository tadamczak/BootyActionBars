local Bars = BootyActionBars
local UI = Bars.UI.Components
local Overview = {}
Bars.Modules.Overview = Overview
local message = "Try a fixed bar for action slots 1-12. Its actions share client storage: dragging an action also changes that slot on other bars. Assign BootyActionBars keys in the game's Key Bindings menu. Paging, shapeshifts, pets and layout editing are planned for later builds."

function Overview.Create(parent, host)
    local page = UI.CreateContainer(nil, parent)
    page:SetAllPoints(parent)
    local title = UI.CreateHeading(page, "Action Bars", 2, "gold")
    title:SetPoint("TOPLEFT", page, "TOPLEFT", 16, -16)
    title:SetHeight(24)
    local body = UI.CreateComponentLabel(page, message, "white")
    body:SetJustifyH("LEFT"); body:SetJustifyV("TOP")
    body:SetPoint("TOPLEFT", title, "BOTTOMLEFT", 0, -12)
    local trial = UI.CreateButton(page, nil, "Enable test bar", 140, 24)
    UI.StyleActionButton(trial)
    trial:SetPoint("TOPLEFT", body, "BOTTOMLEFT", 0, -16)
    trial:SetScript("OnClick", function()
        local store = Bars.Database.Ensure()
        if store then Bars.Core.Runtime.SetTrialEnabled(not store.trialBarEnabled) end
    end)
    local settings = UI.CreateButton(page, nil, "Settings", 100, 24)
    UI.StyleActionButton(settings)
    settings:SetPoint("LEFT", trial, "RIGHT", 12, 0)
    settings:SetScript("OnClick", host.OpenSettings)
    local view = {frame = page, settingsButton = settings, trialButton = trial}
    function view:OnResize()
        local width = UI.GetFrameSpan(parent)
        width = math.max(1, width - 32)
        title:SetWidth(width); body:SetWidth(width)
        body:SetHeight(UI.MeasureTextHeight(body, width))
    end
    function view:Refresh()
        if page:IsVisible() then
            self:OnResize()
            local store = Bars.Database.Ensure()
            trial.label:SetText(store and store.trialBarEnabled and "Disable test bar" or "Enable test bar")
        end
    end
    function view:Show()
        if not Bars.Core.Runtime.IsAvailable() then return false end
        page:Show(); self:Refresh(); return true
    end
    function view:Hide() page:Hide() end
    page:Hide()
    return view
end
