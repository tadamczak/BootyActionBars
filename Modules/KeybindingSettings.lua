local Bars = BootyActionBars
local UI = Bars.UI.Components
local Keybindings = {}
Bars.Modules.KeybindingSettings = Keybindings

function Keybindings.Create(parent, host, ownerView)
    local frame = UI.CreateContainer(nil, parent)
    frame:SetAllPoints(parent); frame.bootyTextSizeDelta = -2
    local page = UI.CreateResponsiveCanvas(frame, "BootyActionBarsKeybindingsScroll")
    local view = {frame = frame, canvas = page}
    local function Complete(ok, failure)
        if ownerView.Complete then return ownerView.Complete(ok, failure) end
        if not ok and failure then host.Print(failure) end
        view:Refresh(); return ok, failure
    end
    local help = UI.CreateComponentLabel(page,
        "Click Assign keys, click a button on any visible bar, then press a key. Save keys applies your changes; Cancel discards them.", "white")
    help:SetJustifyH("LEFT"); help:SetJustifyV("TOP")
    local function Action(text, width)
        local button = UI.CreateButton(page, nil, text, width, 24)
        UI.StyleActionButton(button); button.bootyFlowWidth = width
        return button
    end
    local assign, cancel, clear = Action("Assign keys", 112), Action("Cancel", 72), Action("Clear keybinding", 144)
    assign:SetScript("OnClick", function()
        local editor = Bars.Modules.BindingEditor
        if editor and editor.IsEditing() then Complete(editor.Save())
        else Complete(Bars.Core.Runtime.SetBindingEditing(true)) end
    end)
    cancel:SetScript("OnClick", function()
        local editor = Bars.Modules.BindingEditor; if editor then Complete(editor.Cancel()) end
    end)
    clear:SetScript("OnClick", function()
        local editor = Bars.Modules.BindingEditor; local state = editor and editor.GetState()
        if state and state.editing and state.armed and not state.confirming then Complete(editor.ClearSelection()) end
    end)
    local status = UI.CreateComponentLabel(page, "", "white")
    status:SetJustifyH("LEFT"); status:SetJustifyV("TOP")
    ownerView.bindingButton, ownerView.bindingSaveButton, ownerView.bindingCancelButton = assign, assign, cancel
    ownerView.bindingClearButton, ownerView.bindingStatus = clear, status
    view.actions, view.help = {assign, cancel, clear}, help
    local function Text(label, top, width)
        label:ClearAllPoints(); label:SetPoint("TOPLEFT", page, "TOPLEFT", 16, -top)
        label:SetWidth(width); label:SetHeight(UI.MeasureTextHeight(label, width))
        return top + label:GetHeight()
    end
    local function Measure(available)
        local width = math.max(1, available - 32)
        local top = Text(help, 12, width) + 16
        top = UI.LayoutFlow(page, view.actions, 16, top, width, 8) + 16
        view.contentHeight = Text(status, top, width) + 16
        return view.contentHeight
    end
    function view:Layout(width, height)
        if not frame:IsVisible() then return end
        if not width or not height then width, height = UI.GetFrameSpan(parent) end
        width, height = math.max(1, width), math.max(1, height)
        self.width, self.height = width, height; frame:SetWidth(width); frame:SetHeight(height)
        UI.LayoutResponsiveCanvas(page, Measure, nil, width, height)
    end
    function view:Refresh()
        if not frame:IsVisible() then return end
        local editor = Bars.Modules.BindingEditor; local state = editor and editor.GetState()
        local active = editor and editor.IsEditing() or false
        local confirming = state and state.confirming == true
        assign:SetText(active and "Save keys" or "Assign keys")
        UI.SetButtonEnabled(assign, Bars.Core.Runtime.IsAvailable() and editor ~= nil and not confirming)
        UI.SetButtonEnabled(cancel, active)
        UI.SetButtonEnabled(clear, active and state and state.armed == true and not confirming)
        local text = "Click Assign keys to begin."
        if state and state.failure then text = tostring(state.failure)
        elseif active and state then
            text = tostring(state.pendingCount or 0) .. " pending changes"
            if (state.conflictCount or 0) > 0 then text = text .. "; " .. state.conflictCount .. " conflicts" end
            if state.armed then text = text .. "\nSelected: " .. Bars.Services.BarConfig.Name(state.barId) .. ", button " .. state.index .. ". Press a key."
            else text = text .. "\nClick an action button to select it."
                if state.firstKey then text=text .. "\nLast key: " .. state.firstKey end
            end
        elseif state and state.message then text = state.message end
        if self.lastText ~= text then self.lastText = text; status:SetText(text) end
        self:Layout(self.width, self.height)
    end
    view.RefreshBindings = view.Refresh
    local function Cleanup()
        local editor = Bars.Modules.BindingEditor
        if editor and editor.IsEditing() then
            local ok, failure = editor.Cancel(); if not ok and failure then host.Print(failure) end
            return ok, failure
        end
        return true
    end
    frame:SetScript("OnHide", Cleanup)
    function view:Show()
        if not Bars.Core.Runtime.IsAvailable() then return false end
        frame:Show(); self:Refresh(); return true
    end
    function view:Hide() local ok, failure = Cleanup(); frame:Hide(); return ok, failure end
    frame:Hide(); return view
end
