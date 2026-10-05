local Bars = BootyActionBars
local UI = Bars.UI.Components
local Overview = {}
Bars.Modules.Overview = Overview
local message = "Action bar editing will be available in a later build. Open Settings to manage BootyActionBars preferences and named profiles."

function Overview.Create(parent, host)
    local page = UI.CreateContainer(nil, parent)
    page:SetAllPoints(parent)
    local title = UI.CreateHeading(page, "Action Bars", 2, "gold")
    title:SetPoint("TOPLEFT", page, "TOPLEFT", 16, -16)
    title:SetHeight(24)
    local body = UI.CreateComponentLabel(page, message, "white")
    body:SetJustifyH("LEFT"); body:SetJustifyV("TOP")
    body:SetPoint("TOPLEFT", title, "BOTTOMLEFT", 0, -12)
    local settings = UI.CreateButton(page, nil, "Settings", 100, 24)
    UI.StyleActionButton(settings)
    settings:SetPoint("TOPLEFT", body, "BOTTOMLEFT", 0, -16)
    settings:SetScript("OnClick", host.OpenSettings)
    local view = {frame = page, settingsButton = settings}
    function view:OnResize()
        local width = UI.GetFrameSpan(parent)
        width = math.max(1, width - 32)
        title:SetWidth(width); body:SetWidth(width)
        body:SetHeight(UI.MeasureTextHeight(body, width))
    end
    function view:Refresh()
        if page:IsVisible() then self:OnResize() end
    end
    function view:Show()
        if not Bars.Core.Runtime.IsAvailable() then return false end
        page:Show(); self:Refresh(); return true
    end
    function view:Hide() page:Hide() end
    page:Hide()
    return view
end
