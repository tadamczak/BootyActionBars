local Bars = BootyActionBars
local UI = Bars.UI.Components
local Overview = {}
Bars.Modules.Overview = Overview
local message = "The main bar follows pages and forms. Additional bars keep fixed action slots. Assign keys under BootyActionBars. Dragging changes shared client actions."

function Overview.Create(parent, host)
    local page = UI.CreateContainer(nil, parent)
    page:SetAllPoints(parent)
    local view = {frame = page, selectedBar = 2}
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
    local controls = UI.CreateContainer(nil, page)
    controls:SetPoint("TOPLEFT", native, "BOTTOMLEFT", 0, -16)
    controls:SetHeight(20)
    local choices = {}
    for id = 2, 6 do
        choices[table.getn(choices) + 1] = {value = id,
            text = "Bar " .. id .. " (slots " .. ((id - 1) * 12 + 1) .. "-" .. (id * 12) .. ")"}
    end
    local _, choice = UI.CreateChoiceField({parent = controls, x = 0, y = 0,
        label = "Extra bar", initialText = choices[1].text, width = 200, height = 126,
        firstY = -7, step = 20, buttonOffset = 70, labelValue = true, choices = choices,
        getValue = function() return view.selectedBar end,
        onSelect = function(value) view.selectedBar = value end,
        onChanged = function() view:Refresh() end})
    local add = UI.CreateButton(page, nil, "Add bar", 92, 24)
    UI.StyleActionButton(add); add:SetPoint("TOPLEFT", controls, "BOTTOMLEFT", 0, -12)
    local remove = UI.CreateButton(page, nil, "Remove bar", 110, 24)
    UI.StyleActionButton(remove); remove:SetPoint("LEFT", add, "RIGHT", 12, 0)
    local status = UI.CreateComponentLabel(page, "", "white")
    status:SetPoint("TOPLEFT", add, "BOTTOMLEFT", 0, -10)
    status:SetJustifyH("LEFT"); status:SetJustifyV("TOP")
    add:SetScript("OnClick", function()
        local ok, failure = Bars.Core.Runtime.SetCustomBar(view.selectedBar, true)
        if not ok and failure then host.Print(failure) end
    end)
    remove:SetScript("OnClick", function()
        local ok, failure = Bars.Core.Runtime.SetCustomBar(view.selectedBar, false)
        if not ok and failure then host.Print(failure) end
    end)
    view.settingsButton, view.trialButton, view.nativeButton = settings, trial, native
    view.barChoice, view.addBarButton, view.removeBarButton, view.barStatus = choice, add, remove, status
    function view:OnResize()
        local width = UI.GetFrameSpan(parent)
        width = math.max(1, width - 32)
        title:SetWidth(width); body:SetWidth(width); controls:SetWidth(width); status:SetWidth(width)
        body:SetHeight(UI.MeasureTextHeight(body, width))
        status:SetHeight(UI.MeasureTextHeight(status, width))
    end
    function view:Refresh()
        if page:IsVisible() then
            local store, failure = Bars.Database.Ensure()
            trial.label:SetText(store and store.trialBarEnabled and "Disable test bar" or "Enable test bar")
            native.label:SetText(store and store.nativeMainBarEnabled and "Restore native buttons" or "Replace native buttons")
            local configured = store and store.customBars[self.selectedBar] == true
            UI.SetButtonEnabled(add, store ~= nil and not configured)
            UI.SetButtonEnabled(remove, configured == true)
            status:SetText(not store and failure or configured and
                "Added. Removing this bar keeps its actions and assigned keys."
                or "Not added. Enable the test bars to show configured bars.")
            self:OnResize()
        end
    end
    function view:Show()
        if not Bars.Core.Runtime.IsAvailable() then return false end
        page:Show(); self:Refresh(); return true
    end
    function view:Hide() choice.panel:Hide(); page:Hide() end
    page:Hide()
    return view
end
