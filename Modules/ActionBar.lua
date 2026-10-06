local Bars = BootyActionBars
local UI = Bars.UI.Components
local ActionBar = {}
Bars.Modules.ActionBar = ActionBar
local pooled

local function UpdatePressed(button)
    local pressed = button.pressed or button.mousePressed
    button:SetButtonState(pressed and "PUSHED" or "NORMAL")
    if pressed then button.pressFeedback:Show() else button.pressFeedback:Hide() end
end
local function CancelPressed(button)
    button.pressed, button.mousePressed = false, false
    UpdatePressed(button)
end
local function Click()
    -- Native CheckButton clicks toggle checked before invoking this script.
    this:SetChecked(this.rendered.checked and 1 or 0)
    this.mousePressed = false; UpdatePressed(this)
    this.bar.callbacks.Click(this.index, arg1, this.skipClick); this.skipClick = nil
end
local function MouseDown()
    this.skipClick = nil
    if arg1 == "LeftButton" or arg1 == "RightButton" then
        this.mousePressed = true; UpdatePressed(this)
    end
end
local function MouseUp()
    this.mousePressed = false; UpdatePressed(this)
end
local function Pickup()
    if type(IsShiftKeyDown) == "function" then
        local shift = IsShiftKeyDown()
        if shift and shift ~= 0 then
            this.skipClick = true; CancelPressed(this); this.bar.callbacks.Pickup(this.index)
        end
    end
end
local function Place()
    this.skipClick = true; CancelPressed(this); this.bar.callbacks.Place(this.index)
end
local function Leave()
    this.hoverFeedback:Hide()
    this.mousePressed = false; UpdatePressed(this)
    if GameTooltip and GameTooltip.IsOwned and GameTooltip:IsOwned(this) then GameTooltip:Hide() end
end
local function Enter()
    this.hoverFeedback:Show()
    if this.hasAction and GameTooltip and GameTooltip.SetAction then
        GameTooltip:SetOwner(this, "ANCHOR_RIGHT"); GameTooltip:SetAction(this.action)
    end
end
local function Hide() this.bar.callbacks.OnHide() end
local function Show() this.bar.callbacks.OnShow() end

function ActionBar.Create(callbacks)
    if pooled then return pooled end
    local frame = UI.CreateContainer("BootyActionBarsTrialBar", UIParent)
    local view = {frame = frame, buttons = {}, callbacks = callbacks}
    frame.bar = view
    frame:SetWidth(524); frame:SetHeight(40)
    frame:SetPoint("CENTER", UIParent, "CENTER", 0, -180)
    local title = UI.CreateComponentLabel(frame, "BootyActionBars (slots 1-12)", "white")
    title:SetPoint("BOTTOM", frame, "TOP", 0, 8)
    frame:Hide()
    for index = 1, 12 do
        local name = "BootyActionBarsActionButton" .. index
        local button = UI.CreateCheckButton(name, frame)
        view.buttons[index] = button
        button.index, button.action, button.bar = index, index, view
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
        button.nameLabel:SetPoint("BOTTOM", button, "BOTTOM", 0, 4); button.nameLabel:Hide()
        button.rendered, button.read, button.pressed, button.mousePressed = {}, {}, false, false
        button:RegisterForClicks("LeftButtonUp", "RightButtonUp")
        button:RegisterForDrag("LeftButton")
        button:SetScript("OnClick", Click); button:SetScript("OnMouseDown", MouseDown)
        button:SetScript("OnMouseUp", MouseUp)
        button:SetScript("OnDragStart", Pickup); button:SetScript("OnReceiveDrag", Place)
        button:SetScript("OnEnter", Enter); button:SetScript("OnLeave", Leave)
    end
    frame:SetScript("OnHide", Hide); frame:SetScript("OnShow", Show)
    function view:Show() self.frame:Show() end
    function view:SetPage(page, offset)
        title:SetText("BootyActionBars (page " .. page .. ", slots " .. (offset + 1) .. "-" .. (offset + 12) .. ")")
    end
    function view:Hide() self:Suspend(); self.frame:Hide() end
    function view:Suspend(preserveHover)
        for _, button in ipairs(self.buttons) do
            CancelPressed(button); button.skipClick = nil
            button.cooldown:Hide()
            -- A page change keeps the button under the pointer visible.
            if not preserveHover then button.hoverFeedback:Hide() end
            if GameTooltip and GameTooltip.IsOwned and GameTooltip:IsOwned(button) then GameTooltip:Hide() end
        end
    end
    function view:SetPressed(index, pressed)
        local button = self.buttons[index]
        button.pressed = pressed
        UpdatePressed(button)
    end
    function view:Binding(index, key)
        local button = self.buttons[index]
        if button.bindingKey == key then return end
        button.bindingKey = key
        local text = key and (type(GetBindingText) == "function" and GetBindingText(key, "KEY_", 1) or key) or ""
        button.hotkey:SetText(text)
    end
    function view:Render(index, data, force)
        local button, old = self.buttons[index], self.buttons[index].rendered
        button.hasAction = data.hasAction
        if force or old.texture ~= data.texture then button.icon:SetTexture(data.texture); old.texture = data.texture end
        if force or old.count ~= data.count then button.count:SetText(data.count > 1 and data.count or ""); old.count = data.count end
        if force or old.usable ~= data.usable or old.noMana ~= data.noMana then
            if data.usable then button.icon:SetVertexColor(1, 1, 1)
            elseif data.noMana then button.icon:SetVertexColor(0.5, 0.5, 1)
            else button.icon:SetVertexColor(0.3, 0.3, 0.3) end
            old.usable, old.noMana = data.usable, data.noMana
        end
        local checked = data.current or data.autoRepeat
        if force or old.checked ~= checked then button:SetChecked(checked and 1 or 0); old.checked = checked end
        if force or old.start ~= data.cooldownStart or old.duration ~= data.cooldownDuration or old.enabled ~= data.cooldownEnabled then
            CooldownFrame_SetTimer(button.cooldown, data.cooldownStart, data.cooldownDuration, data.cooldownEnabled and 1 or 0)
            old.start, old.duration, old.enabled = data.cooldownStart, data.cooldownDuration, data.cooldownEnabled
        end
        if GameTooltip and GameTooltip.IsOwned and GameTooltip:IsOwned(button) then
            if data.hasAction then GameTooltip:SetAction(button.action) else GameTooltip:Hide() end
        end
    end
    pooled = view
    return view
end
