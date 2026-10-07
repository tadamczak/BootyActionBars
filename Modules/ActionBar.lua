local Bars = BootyActionBars
local UI = Bars.UI.Components
local ActionBar = {}
Bars.Modules.ActionBar = ActionBar
local pooled = {}
local Appearance = Bars.Modules.ButtonAppearance
local function Countdown(method, first, second, third, fourth)
    local owner = Bars.Modules.CooldownText
    if owner then
        local ok, failure = owner[method](first, second, third, fourth)
        if ok == false then error(failure or "Cooldown text update failed.") end
    end
    return true
end
local function BindingMode()
    local editor = Bars.Modules.BindingEditor
    return editor and editor.IsEditing and editor.IsEditing() or false
end
local function LayoutMode()
    local editor = Bars.Modules.Editor
    return editor and editor.IsEditing and editor.IsEditing() or false
end
local UpdateEmpty
local function CaptureFrame(frame, snapshot)
    snapshot.parent, snapshot.scale, snapshot.alpha = frame:GetParent(), frame:GetScale(), frame:GetAlpha()
    snapshot.points = snapshot.points or {}
    local count = frame:GetNumPoints()
    for index = 1, count do
        local point = snapshot.points[index] or {}; snapshot.points[index] = point
        point[1], point[2], point[3], point[4], point[5] = frame:GetPoint(index)
    end
    for index = count + 1, table.getn(snapshot.points) do snapshot.points[index] = nil end
end
local function ParentFrame(frame, parent)
    if frame:SetParent(parent) == false or frame:GetParent() ~= parent then error("The client declined the merged action bar parent.") end
end
local function ScaleFrame(frame, scale)
    local result = frame:SetScale(scale)
    local actual = frame:GetScale()
    if result == false or type(actual) ~= "number" or actual ~= actual or math.abs(actual - scale) > 0.0001 then error("The client declined the merged action bar scale.") end
end
local function ClearFrame(frame)
    if frame:ClearAllPoints() == false then error("The client declined merged action bar anchors.") end
end
local function AlphaFrame(frame, alpha)
    local result = frame:SetAlpha(alpha)
    local actual = frame:GetAlpha()
    if result == false or type(actual) ~= "number" or actual ~= actual or math.abs(actual - alpha) > 0.0001 then error("The client declined the merged action bar opacity.") end
end
local function PointFrame(frame, point)
    if frame:SetPoint(point[1], point[2], point[3], point[4], point[5]) == false then error("The client declined a restored action bar anchor.") end
end
local function RestoreFrame(frame, snapshot)
    local firstFailure
    local ok, reason = pcall(ParentFrame, frame, snapshot.parent)
    if not ok then firstFailure = tostring(reason) end
    ok, reason = pcall(ScaleFrame, frame, snapshot.scale)
    if not ok and not firstFailure then firstFailure = tostring(reason) end
    ok, reason = pcall(AlphaFrame, frame, snapshot.alpha)
    if not ok and not firstFailure then firstFailure = tostring(reason) end
    ok, reason = pcall(ClearFrame, frame)
    if not ok and not firstFailure then firstFailure = tostring(reason) end
    for _, point in ipairs(snapshot.points) do
        ok, reason = pcall(PointFrame, frame, point)
        if not ok and not firstFailure then firstFailure = tostring(reason) end
    end
    return firstFailure == nil, firstFailure
end
local function MergeTitle(view, shown)
    local result
    if shown then result = view.title:Show() else result = view.title:Hide() end
    local actual = view.title:IsShown()
    actual = actual ~= nil and actual ~= false and actual ~= 0
    if result == false or actual ~= shown then error("The client declined the merged action bar title visibility.") end
end
local function ComposeFrame(view, host)
    if host ~= view then
        if not view.mergeOriginal then view.mergeOriginal = {}; CaptureFrame(view.frame, view.mergeOriginal) end
        ParentFrame(view.frame, host.frame); ScaleFrame(view.frame, 1); AlphaFrame(view.frame, 1); ClearFrame(view.frame)
        if view.frame:SetAllPoints(host.frame) == false then error("The client declined the merged action bar bounds.") end
        MergeTitle(view, false)
    elseif view.mergeOriginal then
        local ok, failure = RestoreFrame(view.frame, view.mergeOriginal)
        if not ok then error(failure) end
    end
end
local function LabelFont(label, size)
    local face, oldSize, flags = label:GetFont()
    if face and oldSize ~= size then label:SetFont(face, size, flags) end
end

local function UpdateCaption(view)
    if not view.showTitle then return end
    if view.mergeViews then
        view.title:SetText("Bar " .. view.id .. " (" .. table.getn(view.layoutButtons) .. " slots)")
        return
    end
    if view.gridWidth < 320 then
        local label = "Bar " .. view.id
        if view.behaviorMatched then label = view.gridWidth < 80 and view.id .. ">" .. view.page or label .. " >" .. view.page end
        view.title:SetText(label); return
    end
    if not view.page then view.title:SetText("BootyActionBars (slots 1-12)"); return end
    local label
    if view.behaviorMatched then label = "BootyActionBars " .. view.id .. " (source " .. view.page
    else label = view.id == 1 and "BootyActionBars (page " .. view.page or "BootyActionBars custom " .. view.id .. " (fixed" end
    view.title:SetText(label .. ", slots " .. (view.offset + 1) .. "-" .. (view.offset + 12) .. ")")
end
local function FormatHotkey(button, key, second, nativeEvent, nativeArg)
    local text = key and (type(GetBindingText) == "function" and GetBindingText(key, "KEY_", 1) or key) or ""
    this, event, arg1 = button, nativeEvent, nativeArg
    if second then
        local secondary = type(GetBindingText) == "function" and GetBindingText(second, "KEY_", 1) or second
        text = text .. " / " .. secondary
    end
    -- A formatter hook may alter legacy globals before the native text write.
    this, event, arg1 = button, nativeEvent, nativeArg
    button.hotkey:SetText(text)
end
local function UpdateHotkey(button, key, second)
    local previousThis, previousEvent, previousArg = this, event, arg1
    this = button
    local ok, failure = pcall(FormatHotkey, button, key, second, previousEvent, previousArg)
    this, event, arg1 = previousThis, previousEvent, previousArg
    if not ok then error(failure) end
end
local function BindingLabel(button, force, saved)
    if saved and button.draftActive then button.bindingKey = button.draftPrimary end
    local editing = BindingMode()
    local first, second, known = button.bindingKey, nil, false
    if editing and Bars.Modules.BindingEditor.GetDraftKey then first, second, known = Bars.Modules.BindingEditor.GetDraftKey(button.bindingCommand, first) end
    local shown = editing or button.bar.showHotkeys
    if not shown and not button.bindingLabelAssign then
        if force or button.bindingLabelShown ~= false then button.hotkey:Hide(); button.bindingLabelShown = false end
        button.draftActive, button.draftPrimary = false, nil
        return
    end
    if force or not button.bindingLabelReady or button.labelPrimary ~= first or button.labelSecondary ~= second then
        button.bindingLabelReady = false
        UpdateHotkey(button, first, second)
        button.labelPrimary, button.labelSecondary, button.bindingLabelReady = first, second, true
    end
    if force or button.bindingLabelShown ~= shown then
        if shown then button.hotkey:Show() else button.hotkey:Hide() end
        button.bindingLabelShown = shown
    end
    button.draftActive, button.draftPrimary = editing and known or false, editing and first or nil
    button.bindingLabelAssign = editing
end
local function UpdateCount(button)
    local count = button.rendered.count or 0
    button.count:SetText(count > 1 and count or "")
end

local function UpdatePressed(button)
    local pressed = button.bindingSelected or button.pressed or button.mousePressed
    -- MouseUp runs before the client's pressed-state check for OnClick. The
    -- client owns that state; our overlay also supplies keyboard feedback.
    if pressed then button.pressFeedback:Show() else button.pressFeedback:Hide() end
end
local function CancelPressed(button)
    -- A remap or suspension cancels the action even if the client later
    -- delivers OnClick for the mouse press which started before that change.
    if button.mouseHeld then button.skipClick = true end
    button.pressed, button.mousePressed = false, false
    UpdatePressed(button)
end
local function Click()
    if BindingMode() then
        this:SetChecked(this.rendered.checked and 1 or 0)
        this.mousePressed, this.mouseHeld = false, false
        Bars.Modules.BindingEditor.SelectButton(this, this.bar.id, this.index)
        return
    end
    if LayoutMode() then this:SetChecked(this.rendered.checked and 1 or 0); CancelPressed(this); return end
    -- Native CheckButton clicks toggle checked before invoking this script.
    this:SetChecked(this.rendered.checked and 1 or 0)
    this.mousePressed, this.mouseHeld = false, false; UpdatePressed(this)
    if this.bar.id == 1 then this.bar.callbacks.Click(this.index, arg1, this.skipClick)
    else this.bar.callbacks.Click(this.index, arg1, this.skipClick, this.bar.id) end
    this.skipClick = nil
end
local function MouseDown()
    if BindingMode() or LayoutMode() then return end
    if arg1 == "LeftButton" or arg1 == "RightButton" then
        this.skipClick = nil
        this.mousePressed, this.mouseHeld = true, true; UpdatePressed(this)
    end
end
local function MouseUp()
    this.mousePressed, this.mouseHeld = false, false; UpdatePressed(this)
end
local function Pickup()
    if BindingMode() or LayoutMode() then return end
    if type(IsShiftKeyDown) == "function" then
        local shift = IsShiftKeyDown()
        if shift and shift ~= 0 then
            this.skipClick = true; CancelPressed(this)
            if this.bar.id == 1 then this.bar.callbacks.Pickup(this.index)
            else this.bar.callbacks.Pickup(this.index, this.bar.id) end
        end
    end
end
local function Place()
    if BindingMode() or LayoutMode() then return end
    this.skipClick = true; CancelPressed(this)
    if this.bar.id == 1 then this.bar.callbacks.Place(this.index)
    else this.bar.callbacks.Place(this.index, this.bar.id) end
end
local function Tooltip(button)
    if BindingMode() or LayoutMode() then return true end
    if button.bar.callbacks.Tooltip then
        local ok, failure = button.bar.callbacks.Tooltip(button.index, button.bar.id)
        if ok == false and failure then error(failure) end
        return ok
    end
    GameTooltip:SetOwner(button, "ANCHOR_RIGHT"); GameTooltip:SetAction(button.action)
end
local function LeaveTooltip(button)
    if button.bar.callbacks.LeaveTooltip then
        local ok, failure = button.bar.callbacks.LeaveTooltip(button.index, button.bar.id)
        if ok == false and failure then error(failure) end
        return ok
    end
    if GameTooltip and GameTooltip.IsOwned and GameTooltip:IsOwned(button) then GameTooltip:Hide() end
end
local function Leave()
    Appearance.Hover(this, false)
    this.mousePressed = false; UpdatePressed(this)
    LeaveTooltip(this)
end
local function Enter()
    Appearance.Hover(this, true)
    if BindingMode() or LayoutMode() then return end
    if this.hasAction and GameTooltip and GameTooltip.SetAction then
        Tooltip(this)
    end
end
local function Hide()
    local view = this.bar
    local previousThis, previousEvent, previousArg = this, event, arg1
    local ok, failure = pcall(view.SetCursorGrid, view, false)
    local firstFailure = not ok and tostring(failure) or nil
    ok, failure = pcall(Countdown, "SetViewVisible", view, false)
    if not ok and not firstFailure then firstFailure = tostring(failure) end
    this, event, arg1 = previousThis, previousEvent, previousArg
    if view.id == 1 then ok, failure = pcall(view.callbacks.OnHide)
    else ok, failure = pcall(view.callbacks.OnHide, view.id) end
    if not ok and not firstFailure then firstFailure = tostring(failure) end
    this, event, arg1 = previousThis, previousEvent, previousArg
    if firstFailure then error(firstFailure, 0) end
end
local function Show()
    if this.bar.id == 1 then this.bar.callbacks.OnShow()
    else this.bar.callbacks.OnShow(this.bar.id) end
    Countdown("SetViewVisible", this.bar, true)
end
local function ClearTooltip(button)
    LeaveTooltip(button)
end
local function SuspendButton(button, preserveHover)
    local firstFailure
    local ok, failure = pcall(CancelPressed, button)
    if not ok then firstFailure = tostring(failure) end
    ok, failure = pcall(button.pressFeedback.Hide, button.pressFeedback)
    if not ok and not firstFailure then firstFailure = tostring(failure) end
    ok, failure = pcall(button.cooldown.Hide, button.cooldown)
    if not ok and not firstFailure then firstFailure = tostring(failure) end
    if not preserveHover then
        ok, failure = pcall(Appearance.Hover, button, false)
        if not ok and not firstFailure then firstFailure = tostring(failure) end
    end
    ok, failure = pcall(ClearTooltip, button)
    if not ok and not firstFailure then firstFailure = tostring(failure) end
    return firstFailure == nil, firstFailure
end
UpdateEmpty = function(button)
    local view = button.bar
    local shown = view.showEmptyButtons or view.cursorGrid or view.editing or BindingMode() or button.hasAction
    local wasHidden = button.emptyHidden
    button.emptyHidden = not shown
    if shown then button:Show()
    else
        -- Cancel the old gesture before a later action can occupy this slot.
        local firstFailure
        if not wasHidden then
            local ok, failure = SuspendButton(button, false)
            if not ok then firstFailure = failure end
        end
        button:Hide()
        if firstFailure then error(firstFailure, 0) end
    end
end

function ActionBar.Create(callbacks, barId)
    barId = barId or 1
    if type(barId) ~= "number" or barId < 1 or barId > 6 or barId ~= math.floor(barId) then
        error("Invalid action bar identity.")
    end
    if pooled[barId] then return pooled[barId] end
    local frameName = barId == 1 and "BootyActionBarsTrialBar" or "BootyActionBarsBar" .. barId
    local frame = UI.CreateContainer(frameName, UIParent)
    local view = {id = barId, frame = frame, buttons = {}, callbacks = callbacks, gridWidth = 524,
        showTitle = true, showHotkeys = true, showCounts = true, showMacroNames = true,
        showEmptyButtons = true, editing = false, displayReady = true}
    view.mergeHost, view.mergeOrdinal, view.mergeLayoutButtons = view, 0, {}
    view.layoutButtons = view.buttons
    frame.bar = view
    -- Native position APIs require a movable/resizable frame even while the
    -- editor is locked. Only the editor handle owns drag scripts.
    frame:SetMovable(true)
    if frame.SetDontSavePosition then frame:SetDontSavePosition(true) end
    if frame.SetUserPlaced then frame:SetUserPlaced(false) end
    if frame.SetClampedToScreen then frame:SetClampedToScreen(true) end
    frame:SetWidth(524); frame:SetHeight(40)
    frame:SetPoint("CENTER", UIParent, "CENTER", 0, -180 + (barId - 1) * 68)
    local title = UI.CreateComponentLabel(frame, "BootyActionBars (slots 1-12)", "white")
    view.title = title
    title:SetPoint("BOTTOM", frame, "TOP", 0, 8)
    title:SetWidth(524); title:SetHeight(20)
    frame:Hide()
    for index = 1, 12 do
        local prefix = barId == 1 and "BootyActionBarsActionButton" or "BootyActionBarsBar" .. barId .. "ActionButton"
        local name = prefix .. index
        local button = UI.CreateCheckButton(name, frame)
        view.buttons[index] = button
        button.index, button.action, button.bar = index, (barId - 1) * 12 + index, view
        button.bindingCommand = Bars.Services and Bars.Services.BindingService and Bars.Services.BindingService.Command(barId, index)
        button:SetID(index); button:SetWidth(40); button:SetHeight(40)
        button:SetPoint("LEFT", frame, "LEFT", (index - 1) * 44, 0)
        button:SetCheckedTexture("Interface\\Buttons\\CheckButtonHilight")
        button.icon = UI.CreateTexture(button, name .. "Icon", "ARTWORK")
        button.icon:SetPoint("TOPLEFT", button, "TOPLEFT", 4, -4)
        button.icon:SetPoint("BOTTOMRIGHT", button, "BOTTOMRIGHT", -4, 4)
        Appearance.InitializeButton(button)
        button.pressFeedback = UI.CreateTexture(button, nil, "OVERLAY")
        button.pressFeedback:SetAllPoints(button.icon)
        button.pressFeedback:SetTexture("Interface\\Buttons\\UI-Quickslot-Depress")
        button.pressFeedback:Hide()
        button.cooldown = UI.CreateModel(name .. "Cooldown", button, "CooldownFrameTemplate")
        button.cooldown:SetAllPoints(button.icon); button.cooldown:Hide()
        Countdown("Attach", button)
        button.count = UI.CreateLabel(button, name .. "Count", "OVERLAY", "NumberFontNormalSmall")
        button.count:SetPoint("BOTTOMRIGHT", button, "BOTTOMRIGHT", -5, 5)
        button.hotkey = UI.CreateLabel(button, nil, "OVERLAY", "NumberFontNormalSmall")
        button.hotkey:SetPoint("TOPRIGHT", button, "TOPRIGHT", -4, -4)
        button.hotkey:SetWidth(32); button.hotkey:SetJustifyH("RIGHT")
        -- SuperMacro uses these conventional globals during wrapped reads.
        button.nameLabel = UI.CreateLabel(button, name .. "Name", "OVERLAY", "GameFontNormalSmall")
        button.nameLabel:SetPoint("BOTTOM", button, "BOTTOM", 0, 4)
        button.nameLabel:SetWidth(32); button.nameLabel:SetHeight(12); button.nameLabel:Hide()
        button.rendered, button.read, button.pressed, button.mousePressed = {}, {}, false, false
        button.mouseHeld = false
        button:RegisterForClicks("LeftButtonUp", "RightButtonUp")
        button:RegisterForDrag("LeftButton")
        button:SetScript("OnClick", Click); button:SetScript("OnMouseDown", MouseDown)
        button:SetScript("OnMouseUp", MouseUp)
        button:SetScript("OnDragStart", Pickup); button:SetScript("OnReceiveDrag", Place)
        button:SetScript("OnEnter", Enter); button:SetScript("OnLeave", Leave)
    end
    frame:SetScript("OnHide", Hide); frame:SetScript("OnShow", Show)
    function view:Show()
        local editor = Bars.Modules.Editor
        if editor then
            local ok, failure = editor.ApplyView(self, true)
            if not ok then return false, failure end
        end
        self.frame:Show()
        Countdown("SetViewVisible", self, true)
        return true
    end
    function view:SetPage(page, offset, matched)
        self.page, self.offset, self.behaviorMatched = page, offset, matched
        UpdateCaption(self)
    end
    function view:SetMergeGroup(host, ordinal, members)
        host, ordinal = host or self, ordinal or 0
        if type(host) ~= "table" or not host.frame or not host.buttons or type(ordinal) ~= "number"
            or ordinal < 0 or ordinal > 5 or ordinal ~= math.floor(ordinal) then return false, "Invalid merged action bar composition." end
        local signature = 0
        if host == self then
            members = members or {self}
            if table.getn(members) < 1 or table.getn(members) > 6 or members[1] ~= self then return false, "Invalid merged source order." end
            for _, source in ipairs(members) do
                if type(source) ~= "table" or not source.buttons or table.getn(source.buttons) ~= 12 then return false, "Merged sources must retain twelve buttons." end
                signature = signature * 7 + source.id
            end
        end
        local expectedParent = host ~= self and host.frame or self.mergeOriginal and self.mergeOriginal.parent or self.frame:GetParent()
        if self.mergeHost == host and self.mergeOrdinal == ordinal and self.mergeSignature == signature
            and self.frame:GetParent() == expectedParent and not self.mergeRepairPending then return true end
        self.mergeRollback = self.mergeRollback or {}
        CaptureFrame(self.frame, self.mergeRollback)
        local shown = self.title:IsShown()
        self.mergeRollback.titleShown = shown ~= nil and shown ~= false and shown ~= 0
        local oldThis, oldEvent, oldArg = this, event, arg1
        local ok, failure = pcall(ComposeFrame, self, host)
        if not ok then
            local restored, reason = RestoreFrame(self.frame, self.mergeRollback)
            local titleOK, titleReason = pcall(MergeTitle, self, self.mergeRollback.titleShown)
            if not titleOK and restored then restored, reason = false, tostring(titleReason) end
            self.mergeRepairPending, self.layoutDrawing, self.displayReady = not restored, nil, false
            this, event, arg1 = oldThis, oldEvent, oldArg
            return false, tostring(failure) .. (not restored and " Restoration: " .. tostring(reason) or "")
        end
        this, event, arg1 = oldThis, oldEvent, oldArg
        self.mergeHost, self.mergeOrdinal, self.mergeSignature = host, ordinal, signature
        self.mergeRepairPending, self.layoutDrawing, self.displayReady = nil, nil, false
        if host == self then
            self.mergeOriginal = nil
            self.mergeViews = table.getn(members) > 1 and members or nil
            if self.mergeViews then
                local count = 0
                for _, source in ipairs(members) do for _, button in ipairs(source.buttons) do count = count + 1; self.mergeLayoutButtons[count] = button end end
                for index = count + 1, table.getn(self.mergeLayoutButtons) do self.mergeLayoutButtons[index] = nil end
                self.layoutButtons = self.mergeLayoutButtons
            else self.layoutButtons = self.buttons end
        else self.mergeViews, self.layoutButtons = nil, self.buttons end
        return true
    end
    function view:SetGrid(value)
        if self.mergeHost ~= self then return self.mergeHost:SetGrid(value) end
        self.frame:SetWidth(value.barWidth); self.frame:SetHeight(value.barHeight)
        local size, inset, fontSize = value.buttonSize or 40, value.iconInset or 4, value.labelFontSize or 10
        local step, columns = size + value.spacing, value.columns
        self.frame:SetAlpha((value.opacityPct or 100) / 100)
        for index, button in ipairs(self.layoutButtons) do
            local row = math.floor((index - 1) / columns)
            local column = index - 1 - row * columns
            button.layoutIndex = index
            button:SetWidth(size); button:SetHeight(size)
            button:ClearAllPoints()
            button:SetPoint("TOPLEFT", self.frame, "TOPLEFT", column * step, -row * step)
            button.icon:ClearAllPoints()
            button.icon:SetPoint("TOPLEFT", button, "TOPLEFT", inset, -inset)
            button.icon:SetPoint("BOTTOMRIGHT", button, "BOTTOMRIGHT", -inset, inset)
            button.hotkey:SetWidth(math.max(1, size - 8))
            button.nameLabel:SetWidth(math.max(1, size - 8)); button.nameLabel:SetHeight(fontSize + 2)
            LabelFont(button.hotkey, fontSize); LabelFont(button.count, fontSize); LabelFont(button.nameLabel, fontSize)
        end
        self.gridWidth = value.barWidth
        title:SetWidth(value.barWidth); title:SetHeight(20)
        UpdateCaption(self)
        return true
    end
    function view:SetOwnDisplay(value, repair)
        Appearance.ApplyView(self, value, repair)
        Countdown("ConfigureView", self, value)
        local rebuild = repair == true or not self.displayReady
        local caption = value.showTitle and self.mergeHost == self
        local titleChanged = rebuild or self.showTitle ~= caption
        local hotkeysChanged = rebuild or self.showHotkeys ~= value.showHotkeys
        local countsChanged = rebuild or self.showCounts ~= value.showCounts
        local names = value.showMacroNames ~= false
        local empties = value.showEmptyButtons ~= false
        local namesChanged, emptiesChanged = rebuild or self.showMacroNames ~= names, rebuild or self.showEmptyButtons ~= empties
        if not titleChanged and not hotkeysChanged and not countsChanged and not namesChanged and not emptiesChanged then return true end
        self.displayReady = false
        self.showTitle, self.showHotkeys, self.showCounts = caption, value.showHotkeys, value.showCounts
        self.showMacroNames, self.showEmptyButtons = names, empties
        if titleChanged then
            if self.showTitle then UpdateCaption(self); title:Show() else title:Hide() end
        end
        for index = 1, 12 do
            local button = self.buttons[index]
            if hotkeysChanged then
                BindingLabel(button, true)
            end
            if countsChanged then
                if self.showCounts then UpdateCount(button); button.count:Show() else button.count:Hide() end
            end
            if namesChanged then
                if self.showMacroNames then
                    button.nameLabel:SetText(button.rendered.macroName or "")
                    button.nameLabel:Show()
                else button.nameLabel:Hide() end
            end
            if emptiesChanged then UpdateEmpty(button) end
        end
        self.displayReady = true
        return true
    end
    function view:SetDisplay(value, repair)
        if self.mergeHost == self and self.mergeViews then
            for index = 2, table.getn(self.mergeViews) do
                local ok, failure = self.mergeViews[index]:SetOwnDisplay(value, repair)
                if ok == false then return false, failure end
            end
        end
        return self:SetOwnDisplay(value, repair)
    end
    function view:SetEditing(value)
        self.editing = value == true
        if self.mergeHost == self and self.mergeViews then
            for index = 2, table.getn(self.mergeViews) do self.mergeViews[index]:SetEditing(value) end
        end
        for _, button in ipairs(self.buttons) do UpdateEmpty(button) end
        return true
    end
    function view:SetCursorGrid(value)
        value = value == true
        if (self.cursorGrid == true) == value then return true end
        self.cursorGrid = value
        local previousThis, previousEvent, previousArg = this, event, arg1
        local firstFailure
        if not self.showEmptyButtons then
            for _, button in ipairs(self.buttons) do
                local ok, failure = pcall(UpdateEmpty, button)
                if not ok and not firstFailure then firstFailure = tostring(failure) end
            end
        end
        this, event, arg1 = previousThis, previousEvent, previousArg
        if firstFailure then error(firstFailure, 0) end
        return true
    end
    function view:Hide()
        local previousThis, previousEvent, previousArg = this, event, arg1
        local ran, ok, failure = pcall(self.Suspend, self)
        local firstFailure
        if not ran then firstFailure = tostring(ok)
        elseif ok == false then firstFailure = failure or "The action bar could not be suspended." end
        local hidden, reason = pcall(self.frame.Hide, self.frame)
        if not hidden and not firstFailure then firstFailure = tostring(reason) end
        local countdownHidden, countdownFailure = pcall(Countdown, "SetViewVisible", self, false)
        if not countdownHidden and not firstFailure then firstFailure = tostring(countdownFailure) end
        this, event, arg1 = previousThis, previousEvent, previousArg
        return firstFailure == nil, firstFailure
    end
    function view:Suspend(preserveHover)
        local previousThis, previousEvent, previousArg = this, event, arg1
        local firstFailure
        if not preserveHover then
            local ok, failure = pcall(self.SetCursorGrid, self, false)
            if not ok then firstFailure = tostring(failure) end
        end
        for _, button in ipairs(self.buttons) do
            -- A page change keeps the button under the pointer visible;
            -- one failing widget must not keep later animations running.
            local ran, ok, failure = pcall(SuspendButton, button, preserveHover)
            if not ran and not firstFailure then firstFailure = tostring(ok)
            elseif ok == false and not firstFailure then firstFailure = failure end
        end
        local ended, failure = pcall(Countdown, "SuspendView", self)
        if not ended and not firstFailure then firstFailure = tostring(failure) end
        this, event, arg1 = previousThis, previousEvent, previousArg
        return firstFailure == nil, firstFailure
    end
    function view:CancelInput(onlyHeld, preserveHover)
        local previousThis, previousEvent, previousArg = this, event, arg1
        local firstFailure
        for _, button in ipairs(self.mergeHost == self and self.layoutButtons or self.buttons) do
            local ok, failure = pcall(CancelPressed, button)
            if not ok and not firstFailure then firstFailure = tostring(failure) end
            ok, failure = pcall(button.pressFeedback.Hide, button.pressFeedback)
            if not ok and not firstFailure then firstFailure = tostring(failure) end
            if not preserveHover then
                ok, failure = pcall(Appearance.Hover, button, false)
                if not ok and not firstFailure then firstFailure = tostring(failure) end
                ok, failure = pcall(ClearTooltip, button)
                if not ok and not firstFailure then firstFailure = tostring(failure) end
            end
        end
        this, event, arg1 = previousThis, previousEvent, previousArg
        return firstFailure == nil, firstFailure
    end
    function view:SetPressed(index, pressed)
        local button = self.buttons[index]
        button.pressed = pressed
        UpdatePressed(button)
    end
    function view:SetBindingSelected(index, selected)
        local button = self.buttons[index]
        button.bindingSelected = selected == true
        UpdatePressed(button)
        return true
    end
    function view:RefreshBindingDraft(saved)
        local previousThis, previousEvent, previousArg = this, event, arg1
        local firstFailure
        for _, button in ipairs(self.buttons) do
            this = button
            local ok, reason = pcall(BindingLabel, button, false, saved)
            this, event, arg1 = previousThis, previousEvent, previousArg
            if not ok and not firstFailure then firstFailure = tostring(reason) end
        end
        return firstFailure == nil, firstFailure
    end
    function view:Binding(index, key)
        local button = self.buttons[index]
        if button.bindingKey == key and self.displayReady and not BindingMode() then return end
        button.bindingKey = key
        if not self.showHotkeys and not BindingMode() then return end
        local ready = self.displayReady
        self.displayReady = false
        BindingLabel(button, not ready)
        self.displayReady = ready
    end
    function view:Render(index, data, force, rangeOnly)
        local button, old = self.buttons[index], self.buttons[index].rendered
        if button.bindingSelected then UpdatePressed(button) end
        local availabilityChanged = button.hasAction ~= data.hasAction
        if button.hasAction and not data.hasAction then CancelPressed(button) end
        button.hasAction = data.hasAction
        if force or availabilityChanged then UpdateEmpty(button) end
        if force or old.macroName ~= data.macroName then
            if self.showMacroNames then
                button.nameLabel:SetText(data.macroName or "")
                button.nameLabel:Show()
            end
            old.macroName = data.macroName
        end
        if force or old.texture ~= data.texture then button.icon:SetTexture(data.texture); old.texture = data.texture end
        if force or old.count ~= data.count then
            if self.showCounts then button.count:SetText(data.count > 1 and data.count or "") end
            old.count = data.count
        end
        Appearance.ApplyColor(button, data)
        old.usable, old.noMana, old.inRange = data.usable, data.noMana, data.inRange
        local checked = data.current or data.autoRepeat
        if force or old.checked ~= checked then button:SetChecked(checked and 1 or 0); old.checked = checked end
        if force or old.start ~= data.cooldownStart or old.duration ~= data.cooldownDuration or old.enabled ~= data.cooldownEnabled then
            CooldownFrame_SetTimer(button.cooldown, data.cooldownStart, data.cooldownDuration, data.cooldownEnabled and 1 or 0)
            Countdown("Update", button, data.cooldownStart, data.cooldownDuration, data.cooldownEnabled)
            old.start, old.duration, old.enabled = data.cooldownStart, data.cooldownDuration, data.cooldownEnabled
        end
        if not rangeOnly and GameTooltip and GameTooltip.IsOwned and GameTooltip:IsOwned(button)
            and GameTooltip.IsShown and GameTooltip:IsShown() then
            if data.hasAction then Tooltip(button) else LeaveTooltip(button) end
        end
    end
    pooled[barId] = view
    return view
end
