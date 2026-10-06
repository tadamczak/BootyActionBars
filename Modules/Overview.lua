local Bars = BootyActionBars
local UI = Bars.UI.Components
local Overview = {}
Bars.Modules.Overview = Overview
local message = "Follow client pages and form actions. Assign keys under BootyActionBars. Native replacement requires page 1 outside forms: disable competing bar addons and reload first. Pets and layout editing are planned."

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
    local native = UI.CreateButton(page, nil, "Replace native buttons", 180, 24)
    UI.StyleActionButton(native)
    native:SetPoint("TOPLEFT", trial, "BOTTOMLEFT", 0, -12)
    native:SetScript("OnClick", function()
        local store = Bars.Database.Ensure()
        if store then Bars.Core.Runtime.SetNativeEnabled(not store.nativeMainBarEnabled) end
    end)
    local view = {frame = page, settingsButton = settings, trialButton = trial, nativeButton = native}
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
            native.label:SetText(store and store.nativeMainBarEnabled and "Restore native buttons" or "Replace native buttons")
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
