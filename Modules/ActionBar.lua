local Bars = BootyActionBars
local UI = Bars.UI.Components
local ActionBar = {}
Bars.Modules.ActionBar = ActionBar
local pooled = {}
local function BindingMode()
    local editor = Bars.Modules.BindingEditor
    return editor and editor.IsEditing and editor.IsEditing() or false
end
local UpdateEmpty
local function LabelFont(label, size)
    local face, oldSize, flags = label:GetFont()
    if face and oldSize ~= size then label:SetFont(face, size, flags) end
end

local function UpdateCaption(view)
    if not view.showTitle then return end
    if view.gridWidth < 320 then view.title:SetText("Bar " .. view.id); return end
    if not view.page then view.title:SetText("BootyActionBars (slots 1-12)"); return end
    local label = view.id == 1 and "BootyActionBars (page " .. view.page or "BootyActionBars custom " .. view.id .. " (fixed"
    view.title:SetText(label .. ", slots " .. (view.offset + 1) .. "-" .. (view.offset + 12) .. ")")
end
local function FormatHotkey(button, key, nativeEvent, nativeArg)
    local text = key and (type(GetBindingText) == "function" and GetBindingText(key, "KEY_", 1) or key) or ""
    -- A formatter hook may alter legacy globals before the native text write.
    this, event, arg1 = button, nativeEvent, nativeArg
    button.hotkey:SetText(text)
end
local function UpdateHotkey(button, key)
    local previousThis, previousEvent, previousArg = this, event, arg1
    this = button
    local ok, failure = pcall(FormatHotkey, button, key, previousEvent, previousArg)
    this, event, arg1 = previousThis, previousEvent, previousArg
    if not ok then error(failure) end
end
local function UpdateCount(button)
    local count = button.rendered.count or 0
    button.count:SetText(count > 1 and count or "")
end

local function UpdatePressed(button)
    local pressed = button.pressed or button.mousePressed
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
    if BindingMode() then return end
    -- Native CheckButton clicks toggle checked before invoking this script.
    this:SetChecked(this.rendered.checked and 1 or 0)
    this.mousePressed, this.mouseHeld = false, false; UpdatePressed(this)
    if this.bar.id == 1 then this.bar.callbacks.Click(this.index, arg1, this.skipClick)
    else this.bar.callbacks.Click(this.index, arg1, this.skipClick, this.bar.id) end
    this.skipClick = nil
end
local function MouseDown()
    if BindingMode() then return end
    if arg1 == "LeftButton" or arg1 == "RightButton" then
        this.skipClick = nil
        this.mousePressed, this.mouseHeld = true, true; UpdatePressed(this)
    end
end
local function MouseUp()
    this.mousePressed, this.mouseHeld = false, false; UpdatePressed(this)
end
local function Pickup()
    if BindingMode() then return end
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
    if BindingMode() then return end
    this.skipClick = true; CancelPressed(this)
    if this.bar.id == 1 then this.bar.callbacks.Place(this.index)
    else this.bar.callbacks.Place(this.index, this.bar.id) end
end
local function Tooltip(button)
    if BindingMode() then return true end
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
    this.hoverFeedback:Hide()
    this.mousePressed = false; UpdatePressed(this)
    LeaveTooltip(this)
end
local function Enter()
    this.hoverFeedback:Show()
    if BindingMode() then
        Bars.Modules.BindingEditor.SelectButton(this, this.bar.id, this.index)
        return
    end
    if this.hasAction and GameTooltip and GameTooltip.SetAction then
        Tooltip(this)
    end
end
local function Hide()
    if this.bar.id == 1 then this.bar.callbacks.OnHide()
    else this.bar.callbacks.OnHide(this.bar.id) end
end
local function Show()
    if this.bar.id == 1 then this.bar.callbacks.OnShow()
    else this.bar.callbacks.OnShow(this.bar.id) end
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
        ok, failure = pcall(button.hoverFeedback.Hide, button.hoverFeedback)
        if not ok and not firstFailure then firstFailure = tostring(failure) end
    end
    ok, failure = pcall(ClearTooltip, button)
    if not ok and not firstFailure then firstFailure = tostring(failure) end
    return firstFailure == nil, firstFailure
end
UpdateEmpty = function(button)
    local view = button.bar
    local shown = view.showEmptyButtons or view.editing or BindingMode() or button.hasAction
    local wasHidden = button.emptyHidden
    button.emptyHidden = not shown
    if shown then button:Show()
    else
        -- Cancel the old gesture before a later action can occupy this slot.
        if not wasHidden then
            local ok, failure = SuspendButton(button, false)
            if not ok then error(failure, 0) end
        end
        button:Hide()
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
        button:SetID(index); button:SetWidth(40); button:SetHeight(40)
        button:SetPoint("LEFT", frame, "LEFT", (index - 1) * 44, 0)
        UI.StyleButton(button, ""); button.label:Hide()
        UI.SetProjectButtonOutline(button, true)
        button:SetCheckedTexture("Interface\\Buttons\\CheckButtonHilight")
        button.icon = UI.CreateTexture(button, name .. "Icon", "ARTWORK")
        button.icon:SetPoint("TOPLEFT", button, "TOPLEFT", 4, -4)
        button.icon:SetPoint("BOTTOMRIGHT", button, "BOTTOMRIGHT", -4, 4)
        -- Stock action-button feedback is independent of cast success and the
        -- generic skin's native textures. Keep the project outline unchanged.
        button.hoverFeedback = UI.CreateTexture(button, nil, "OVERLAY")
        button.hoverFeedback:SetAllPoints(button.icon)
        button.hoverFeedback:SetTexture("Interface\\Buttons\\ButtonHilight-Square")
        button.hoverFeedback:SetBlendMode("ADD"); button.hoverFeedback:SetAlpha(0.6)
        button.hoverFeedback:Hide()
        button.pressFeedback = UI.CreateTexture(button, nil, "OVERLAY")
        button.pressFeedback:SetAllPoints(button.icon)
        button.pressFeedback:SetTexture("Interface\\Buttons\\UI-Quickslot-Depress")
        button.pressFeedback:Hide()
        button.cooldown = UI.CreateModel(name .. "Cooldown", button, "CooldownFrameTemplate")
        button.cooldown:SetAllPoints(button.icon); button.cooldown:Hide()
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
        return true
    end
    function view:SetPage(page, offset)
        self.page, self.offset = page, offset
        UpdateCaption(self)
    end
    function view:SetGrid(value)
        self.frame:SetWidth(value.barWidth); self.frame:SetHeight(value.barHeight)
        local size, inset, fontSize = value.buttonSize or 40, value.iconInset or 4, value.labelFontSize or 10
        local step, columns = size + value.spacing, value.columns
        self.frame:SetAlpha((value.opacityPct or 100) / 100)
        for index = 1, 12 do
            local row = math.floor((index - 1) / columns)
            local column = index - 1 - row * columns
            local button = self.buttons[index]
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
    function view:SetDisplay(value, repair)
        local rebuild = repair == true or not self.displayReady
        local titleChanged = rebuild or self.showTitle ~= value.showTitle
        local hotkeysChanged = rebuild or self.showHotkeys ~= value.showHotkeys
        local countsChanged = rebuild or self.showCounts ~= value.showCounts
        local names = value.showMacroNames ~= false
        local empties = value.showEmptyButtons ~= false
        local namesChanged, emptiesChanged = rebuild or self.showMacroNames ~= names, rebuild or self.showEmptyButtons ~= empties
        if not titleChanged and not hotkeysChanged and not countsChanged and not namesChanged and not emptiesChanged then return true end
        self.displayReady = false
        self.showTitle, self.showHotkeys, self.showCounts = value.showTitle, value.showHotkeys, value.showCounts
        self.showMacroNames, self.showEmptyButtons = names, empties
        if titleChanged then
            if self.showTitle then UpdateCaption(self); title:Show() else title:Hide() end
        end
        for index = 1, 12 do
            local button = self.buttons[index]
            if hotkeysChanged then
                if self.showHotkeys then UpdateHotkey(button, button.bindingKey); button.hotkey:Show()
                else button.hotkey:Hide() end
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
    function view:SetEditing(value)
        self.editing = value == true
        for _, button in ipairs(self.buttons) do UpdateEmpty(button) end
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
        this, event, arg1 = previousThis, previousEvent, previousArg
        return firstFailure == nil, firstFailure
    end
    function view:Suspend(preserveHover)
        local previousThis, previousEvent, previousArg = this, event, arg1
        local firstFailure
        for _, button in ipairs(self.buttons) do
            -- A page change keeps the button under the pointer visible;
            -- one failing widget must not keep later animations running.
            local ran, ok, failure = pcall(SuspendButton, button, preserveHover)
            if not ran and not firstFailure then firstFailure = tostring(ok)
            elseif ok == false and not firstFailure then firstFailure = failure end
        end
        this, event, arg1 = previousThis, previousEvent, previousArg
        return firstFailure == nil, firstFailure
    end
    function view:CancelInput()
        local previousThis, previousEvent, previousArg = this, event, arg1
        local firstFailure
        for _, button in ipairs(self.buttons) do
            local ok, failure = pcall(CancelPressed, button)
            if not ok and not firstFailure then firstFailure = tostring(failure) end
            ok, failure = pcall(button.pressFeedback.Hide, button.pressFeedback)
            if not ok and not firstFailure then firstFailure = tostring(failure) end
            ok, failure = pcall(button.hoverFeedback.Hide, button.hoverFeedback)
            if not ok and not firstFailure then firstFailure = tostring(failure) end
            ok, failure = pcall(ClearTooltip, button)
            if not ok and not firstFailure then firstFailure = tostring(failure) end
        end
        this, event, arg1 = previousThis, previousEvent, previousArg
        return firstFailure == nil, firstFailure
    end
    function view:SetPressed(index, pressed)
        local button = self.buttons[index]
        button.pressed = pressed
        UpdatePressed(button)
    end
    function view:Binding(index, key)
        local button = self.buttons[index]
        if button.bindingKey == key and self.displayReady then return end
        button.bindingKey = key
        if not self.showHotkeys then return end
        local ready = self.displayReady
        self.displayReady = false
        UpdateHotkey(button, key)
        self.displayReady = ready
    end
    function view:Render(index, data, force, rangeOnly)
        local button, old = self.buttons[index], self.buttons[index].rendered
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
        local color = data.usable and (data.inRange == 0 and 2 or 1) or data.noMana and 3 or 4
        if force or old.color ~= color then
            if color == 1 then button.icon:SetVertexColor(1, 1, 1)
            elseif color == 2 then button.icon:SetVertexColor(1, 0.2, 0.2)
            elseif color == 3 then button.icon:SetVertexColor(0.5, 0.5, 1)
            else button.icon:SetVertexColor(0.3, 0.3, 0.3) end
            old.color = color
        end
        old.usable, old.noMana, old.inRange = data.usable, data.noMana, data.inRange
        local checked = data.current or data.autoRepeat
        if force or old.checked ~= checked then button:SetChecked(checked and 1 or 0); old.checked = checked end
        if force or old.start ~= data.cooldownStart or old.duration ~= data.cooldownDuration or old.enabled ~= data.cooldownEnabled then
            CooldownFrame_SetTimer(button.cooldown, data.cooldownStart, data.cooldownDuration, data.cooldownEnabled and 1 or 0)
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
