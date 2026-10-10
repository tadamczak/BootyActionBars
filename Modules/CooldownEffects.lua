local Bars = BootyActionBars
local Service, UI = Bars.Services.CooldownTextService, Bars.UI.Components
local Effects = {}
Bars.Modules.CooldownEffects = Effects
local circle = "Interface\\AddOns\\BootyLib\\Assets\\CooldownCircle"
local function Call(record, region, method, first, second, third, fourth, fifth)
    local oldThis, oldEvent, a1, a2, a3, a4, a5, a6, a7, a8, a9 = this, event, arg1, arg2, arg3, arg4, arg5, arg6, arg7, arg8, arg9
    this = record.button
    -- These native calls take zero, one, four or five operands. Even nil
    -- counts as an extra operand in the client, notably for SetTexCoord.
    local ran, result
    if fifth ~= nil then ran, result = pcall(region[method], region, first, second, third, fourth, fifth)
    elseif fourth ~= nil then ran, result = pcall(region[method], region, first, second, third, fourth)
    elseif first ~= nil then ran, result = pcall(region[method], region, first)
    else ran, result = pcall(region[method], region) end
    this, event, arg1, arg2, arg3, arg4, arg5, arg6, arg7, arg8, arg9 = oldThis, oldEvent, a1, a2, a3, a4, a5, a6, a7, a8, a9
    if not ran then error(result, 0) end
    if result == false and method ~= "IsShown" then error("Cooldown effect rejected " .. method .. ".", 0) end
    return result
end
local function Default(value, fallback) if value == nil then return fallback end; return value end
function Effects.Configure(owner, drawing)
    local mode = Default(drawing.cooldownEffectMode, "circle")
    local r, g, b, a = Default(drawing.cooldownEffectR, 0), Default(drawing.cooldownEffectG, 0),
        Default(drawing.cooldownEffectB, 0), Default(drawing.cooldownEffectA, 0.6)
    local flash = Default(drawing.cooldownFlash, false)
    local fr, fg, fb, fa = Default(drawing.cooldownFlashR, 1), Default(drawing.cooldownFlashG, 0.2),
        Default(drawing.cooldownFlashB, 0.2), Default(drawing.cooldownFlashA, 0.65)
    local size, inset = Default(drawing.buttonSize, 40), Default(drawing.iconInset, 4)
    if not Service.ValidEffectMode(mode) or type(flash) ~= "boolean" or not Service.ValidColor(r)
        or not Service.ValidColor(g) or not Service.ValidColor(b) or not Service.ValidColor(a)
        or not Service.ValidColor(fr) or not Service.ValidColor(fg) or not Service.ValidColor(fb) or not Service.ValidColor(fa)
        or not Service.Finite(size) or size < 24 or size > 64 or not Service.Finite(inset) or inset < 0 or inset > 8 then
        return false, "Invalid cooldown effect appearance."
    end
    local changed = owner.effectMode ~= mode or owner.effectR ~= r or owner.effectG ~= g or owner.effectB ~= b or owner.effectA ~= a
        or owner.flash ~= flash or owner.flashR ~= fr or owner.flashG ~= fg or owner.flashB ~= fb or owner.flashA ~= fa
        or owner.effectSize ~= size - inset * 2
    owner.effectMode, owner.effectR, owner.effectG, owner.effectB, owner.effectA = mode, r, g, b, a
    owner.flash, owner.flashR, owner.flashG, owner.flashB, owner.flashA = flash, fr, fg, fb, fa
    owner.effectSize, owner.nativeSize = size - inset * 2, size
    owner.radius=math.max(0,(drawing.buttonRadius or 0)-inset)
    owner.iconInset=inset
    owner.paintMode=mode == "native" and (r~=0 or g~=0 or b~=0 or owner.radius>0) and "circle" or mode
    return true, changed
end
function Effects.UsesNative(owner) return owner.paintMode == "native" end
function Effects.Demand(record)
    local owner = record.owner
    return not Effects.UsesNative(owner) and owner.effectA > 0 or owner.flash and owner.flashA > 0 and record.duration >= Service.MIN_DURATION
end
function Effects.HideNative(record)
    record.nativeActive = false
    Call(record, record.button.cooldown, "Hide")
end
-- Stock FrameXML owns the model animation. Normalize its 36px/.75 geometry
-- to the retained icon rectangle instead of scaling the button or bar.
function Effects.SyncNative(record)
    local owner, button = record.owner, record.button
    local count = owner.view.count or table.getn(owner.view.buttons)
    local shown = Effects.UsesNative(owner) and owner.visible and not record.suspended and not record.expired
        and owner.effectA>0 and button.index <= count and not button.emptyHidden and record.enabled and record.start > 0 and record.duration > 0
    if not shown then Effects.HideNative(record); return end
    local model = button.cooldown
    if record.nativeAlpha ~= owner.effectA then
        record.nativeAlpha=nil;Call(record,model,"SetAlpha",owner.effectA);record.nativeAlpha=owner.effectA
    end
    if record.nativeSize ~= owner.effectSize then
        record.nativeSize = nil
        Call(record, model, "ClearAllPoints")
        Call(record, model, "SetPoint", "CENTER", button.icon, "CENTER", 0, 0)
        Call(record, model, "SetWidth", 36); Call(record, model, "SetHeight", 36)
        Call(record, model, "SetScale", owner.effectSize/36)
        record.nativeSize = owner.effectSize
    end
    if not record.nativeActive or record.nativeStart ~= record.start or record.nativeDuration ~= record.duration then
        record.nativeActive = false
        local savedThis, savedEvent, a1,a2,a3,a4,a5,a6,a7,a8,a9 = this,event,arg1,arg2,arg3,arg4,arg5,arg6,arg7,arg8,arg9
        this = button
        local ok, reason = pcall(CooldownFrame_SetTimer, model, record.start, record.duration, 1)
        this,event,arg1,arg2,arg3,arg4,arg5,arg6,arg7,arg8,arg9 = savedThis,savedEvent,a1,a2,a3,a4,a5,a6,a7,a8,a9
        if not ok then error(reason, 0) end
        if reason == false then error("Native cooldown timer was declined.", 0) end
        record.nativeActive, record.nativeStart, record.nativeDuration = true, record.start, record.duration
    end
end
local function SetVisibility(record,region,shown)
    if region.babCooldownShape then
        region.babCooldownShape.visible=shown;UI.SetRoundedTexture(region,region.babCooldownShape)
    else Call(record,region,shown and "Show" or "Hide") end
end
local function Visibility(record, region, shown, flash)
    local key = flash and "flashShown" or "effectShown"
    if record[key] == shown then return end
    -- Mark before calling the native setter: a hook may cancel its timer and
    -- Remove must see the in-progress Show so that the later cancellation wins.
    record[key] = shown
    local ran, failure = pcall(SetVisibility, record, region, shown)
    if not ran then record[key] = nil; error(failure, 0) end
    local actual = region.babCooldownShape and UI.IsRoundedTextureShown(region) or Call(record, region, "IsShown")
    if (actual ~= nil and actual ~= false and actual ~= 0) ~= record[key] then
        record[key] = nil
        error("Cooldown effect visibility was declined.", 0)
    end
end
function Effects.Hide(record)
    local failure
    for index = 1, 3 do
        local region
        if index == 1 then region = record.effect elseif index == 2 then region = record.flashEffect
        elseif record.blend then region = record.blend.effect end
        if region then
            local ran, reason = pcall(Visibility, index == 3 and record.blend or record, region, false, index == 2)
            if not ran then failure = failure and failure .. " " .. tostring(reason) or tostring(reason) end
        end
    end
    if failure then error(failure, 0) end
end
local function Ensure(record, flash)
    local region
    if flash then region = record.flashEffect else region = record.effect end
    if region then return region end
    if not record.button.icon then error("The cooldown icon is unavailable.", 0) end
    local parent = record.button
    if flash then
        local holder = record.flashHolder or UI.CreateContainer(nil, record.button)
        record.flashHolder = holder
        holder:SetAllPoints(record.button.icon); holder:SetFrameLevel(record.button:GetFrameLevel() + 3)
        holder:EnableMouse(false)
        parent = holder
    end
    region = UI.CreateTexture(parent, nil, flash and "OVERLAY" or "ARTWORK")
    if not region then error("The cooldown effect texture is unavailable.", 0) end
    if flash then record.flashEffect, record.button.cooldownFlashEffect, record.flashShown = region, region, true
    else record.effect, record.button.cooldownEffect, record.effectShown = region, region, true end
    Visibility(record, region, false, flash)
    return region
end
local function Color(record, region, r, g, b, a, flash)
    local key = flash and "flashPaint" or "effectPaint"
    local paint = record[key]
    if not paint then paint = {}; record[key] = paint end
    if paint.r ~= r or paint.g ~= g or paint.b ~= b or paint.a ~= a then
        paint.r, paint.g, paint.b, paint.a = nil, nil, nil, nil
        Call(record, region, "SetVertexColor", r, g, b, a)
        if region.babCooldownShape then
            local options=region.babCooldownShape;options.r,options.g,options.b,options.a=r,g,b,a
            UI.SetRoundedTextureColor(region,r,g,b,a)
        end
        paint.r, paint.g, paint.b, paint.a = r, g, b, a
    end
end
local function Geometry(record, region, progress, selectedBucket)
    local owner, size = record.owner, record.owner.effectSize
    local mode, bucket = owner.paintMode, selectedBucket or Service.EffectBucket(progress)
    if record.effectMode ~= mode or record.effectSize ~= size then
        record.effectMode, record.effectSize, record.effectBucket = nil, nil, nil
        Call(record, region, "SetTexture", mode == "circle" and circle or "Interface\\Buttons\\WHITE8X8")
        Call(record, region, "ClearAllPoints")
        Call(record, region, "SetPoint", mode == "circle" and "TOPLEFT" or "BOTTOMLEFT", record.button.icon,
            mode == "circle" and "TOPLEFT" or "BOTTOMLEFT", 0, 0)
        Call(record, region, "SetWidth", size)
        if mode == "circle" then Call(record, region, "SetHeight", size) end
        record.effectMode, record.effectSize = mode, size
    end
    if mode == "circle" then
        if record.effectBucket ~= bucket then
            record.effectBucket = nil
            local left, right, top, bottom = Service.EffectUV(bucket)
            Call(record, region, "SetTexCoord", left, right, top, bottom)
            record.effectBucket = bucket
        end
    elseif record.effectProgress ~= progress or record.effectBucket == nil then
        record.effectProgress, record.effectBucket = nil, nil
        Call(record, region, "SetTexCoord", 0, 1, 0, 1)
        Call(record, region, "SetHeight", size * progress)
        record.effectProgress, record.effectBucket = progress, bucket
    end
    if mode=="vertical" and owner.radius>0 or region.babCooldownShape then
        local options=region.babCooldownShape or {};region.babCooldownShape=options
        options.owner,options.layer,options.path=record.button,"ARTWORK",mode=="circle" and circle or "Interface\\Buttons\\WHITE8X8"
        options.width,options.height=size,mode=="circle" and size or size*progress
        options.x,options.y,options.radius=owner.iconInset,-owner.iconInset-(mode=="vertical" and size*(1-progress) or 0),mode=="vertical" and owner.radius or 0
        if mode=="circle" then options.left,options.right,options.top,options.bottom=Service.EffectUV(record.effectBucket)
        else options.left,options.right,options.top,options.bottom=0,1,0,1 end
        options.visible=record.effectShown
        if options.height>0 then UI.SetRoundedTexture(region,options) end
    end
end
function Effects.Paint(record, now)
    local owner, revision = record.owner, record.revision
    local progress, failure = Service.Progress(record.start, record.duration, now)
    if progress == nil then error(failure, 0) end
    if not Effects.UsesNative(owner) and owner.effectA > 0 and progress > 0 then
        local region = Ensure(record, false)
        local alpha = owner.effectA
        if owner.paintMode == "circle" then
            local position = progress * Service.EFFECT_STEPS
            local lower, fraction = math.floor(position), position - math.floor(position)
            Geometry(record, region, progress, lower)
            if fraction > 0 then
                local blend = record.blend
                if not blend then blend = {owner = owner, button = record.button}; record.blend = blend end
                local upper = Ensure(blend, false)
                record.button.cooldownEffect = region
                -- Nested masks: compensate the lower opacity so their shared
                -- pixels retain the configured opacity instead of pulsing.
                local upperAlpha = alpha * fraction
                alpha = upperAlpha == 1 and 0 or (alpha - upperAlpha) / (1 - upperAlpha)
                Geometry(blend, upper, progress, lower + 1)
                Color(blend, upper, owner.effectR, owner.effectG, owner.effectB, upperAlpha, false)
                if record.revision == revision and record.activeIndex and not record.suspended then Visibility(blend, upper, true, false) end
            elseif record.blend then Visibility(record.blend, record.blend.effect, false, false) end
        else
            if record.blend then Visibility(record.blend, record.blend.effect, false, false) end
            Geometry(record, region, progress)
        end
        Color(record, region, owner.effectR, owner.effectG, owner.effectB, alpha, false)
        if record.revision == revision and record.activeIndex and not record.suspended then Visibility(record, region, true, false) end
    elseif record.effect then
        Visibility(record, record.effect, false, false)
        if record.blend then Visibility(record.blend, record.blend.effect, false, false) end
    end
    if record.revision ~= revision or not record.activeIndex or record.suspended then return end
    local remaining = record.start + record.duration - now
    if owner.flash and owner.flashA > 0 and Service.FlashPhase(remaining, record.duration) then
        local region = Ensure(record, true)
        if record.flashSize ~= owner.effectSize then
            record.flashSize = nil
            Call(record, region, "SetTexture", "Interface\\Buttons\\WHITE8X8")
            Call(record, region, "ClearAllPoints"); Call(record, region, "SetPoint", "TOPLEFT", record.button.icon, "TOPLEFT", 0, 0)
            Call(record, region, "SetWidth", owner.effectSize); Call(record, region, "SetHeight", owner.effectSize)
            record.flashSize = owner.effectSize
        end
        if owner.radius>0 or region.babCooldownShape then
            local options=region.babCooldownShape or {};region.babCooldownShape=options
            options.owner,options.layer,options.path=record.flashHolder,"OVERLAY","Interface\\Buttons\\WHITE8X8"
            options.width,options.height,options.radius=owner.effectSize,owner.effectSize,owner.radius
            options.visible=record.flashShown;UI.SetRoundedTexture(region,options)
        end
        Color(record, region, owner.flashR, owner.flashG, owner.flashB, owner.flashA, true)
        if record.revision == revision and record.activeIndex and not record.suspended then Visibility(record, region, true, true) end
    elseif record.flashEffect then Visibility(record, record.flashEffect, false, true) end
end
