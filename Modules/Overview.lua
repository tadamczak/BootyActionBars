local Bars = BootyActionBars
local UI = Bars.UI.Components
local Overview = {}
Bars.Modules.Overview = Overview
local tabs = {{"general", "General"}, {"bars", "Action Bars"}, {"keybindings", "Keybindings"}}
function Overview.Create(parent, host)
    local frame = UI.CreateContainer(nil, parent); frame:SetAllPoints(parent); frame.bootyTextSizeDelta = -2
    local body = UI.CreateContainer(nil, frame)
    local view = {frame = frame, panels = {}, tabs = {}, tabRow = {}, activeTab = "general", selectedBar = 2, bindingIndex = 1}
    function view.Complete(ok, failure, skipRefresh)
        if not ok and failure then host.Print(failure) end
        if not skipRefresh then view:Refresh() end
        return ok, failure, skipRefresh
    end
    local function EndEditors()
        local ok, failure = Bars.Modules.Editor.CancelPending()
        local utilities = Bars.Modules.NativeUtilityBars
        if utilities then
            local cancelled, reason = utilities.CancelPending()
            if not cancelled then ok, failure = false, reason end
        end
        if Bars.Modules.BindingEditor then
            local cancelled, reason = Bars.Modules.BindingEditor.Cancel()
            if not cancelled then ok, failure = false, failure and tostring(failure) .. " Binding cleanup: " .. tostring(reason) or reason end
        end
        if not ok and failure then host.Print(failure) end
        return ok, failure
    end
    local function Panel(id)
        if not view.panels[id] then
            local factory = id == "general" and Bars.Modules.GeneralSettings or id == "bars" and Bars.Modules.BarSettings or Bars.Modules.KeybindingSettings
            view.panels[id] = factory.Create(body, host, view)
        end
        return view.panels[id]
    end
    function view:SelectTab(id)
        if not self.tabs[id] then return false, "Choose General, Action Bars or Keybindings." end
        if id ~= self.activeTab then
            local ok, failure = EndEditors(); if not ok then return false, failure end
            local previous = self.panels[self.activeTab]; if previous then previous:Hide() end
            self.activeTab = id
        end
        for key, tab in pairs(self.tabs) do UI.SetOpenButtonBorder(tab, key == id, "bottom") end
        if frame:IsVisible() then Panel(id):Show(); self:OnResize() end
        return true
    end
    for _, item in ipairs(tabs) do
        local id, label = item[1], item[2]
        local button = UI.CreateSelectionButton(frame, nil, label, id == "general" and 82 or 104, 26)
        button:SetScript("OnClick", function() view:SelectTab(id) end); view.tabs[id] = button
        table.insert(view.tabRow, button)
    end
    function view:OnResize()
        if not frame:IsVisible() then return end
        local width, height = UI.GetFrameSpan(parent); width, height = math.max(1, width), math.max(1, height)
        frame:SetWidth(width); frame:SetHeight(height)
        for _, item in ipairs(tabs) do
            local tab = self.tabs[item[1]]
            tab:SetWidth(math.min(item[1] == "general" and 82 or 104, math.max(1, width - 16)))
        end
        local top = UI.LayoutFlow(frame, self.tabRow, 8, 8, math.max(1, width - 16), 6) + 10
        body:ClearAllPoints(); body:SetPoint("TOPLEFT", frame, "TOPLEFT", 0, -top)
        body:SetWidth(width); body:SetHeight(math.max(1, height - top))
        local panel = self.panels[self.activeTab]; if panel then panel:Layout(width, math.max(1, height - top)) end
    end
    function view:RefreshBindings()
        local panel = self.panels.keybindings; if panel and panel.frame:IsVisible() then panel:RefreshBindings() end
    end
    function view:Refresh()
        if not frame:IsVisible() then return end
        Panel(self.activeTab):Refresh(true); self:OnResize()
    end
    function view:Show()
        if not Bars.Core.Runtime.IsAvailable() then return false end
        frame:Show(); self:SelectTab(self.activeTab); return true
    end
    function view:Hide()
        local ok, failure = EndEditors()
        for _, panel in pairs(self.panels) do panel:Hide() end
        frame:Hide(); return ok, failure
    end
    frame:SetScript("OnHide", function()
        EndEditors(); for _, panel in pairs(view.panels) do panel:Hide() end
    end)
    frame:SetScript("OnShow", function() view:SelectTab(view.activeTab) end)
    if Bars.Modules.BindingEditor then Bars.Modules.BindingEditor.SetObserver(function()
        local ok, failure = Bars.Core.Runtime.RestoreLayoutUnlock()
        if not ok and failure then host.Print(failure) end
        view:RefreshBindings()
    end) end
    frame:Hide(); return view
end
