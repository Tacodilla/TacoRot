-- ui.lua — TacoRot lightweight UI for 3.3.5 (Wrath-safe)
-- Adds Blizzard-style GCD spiral via Cooldown frames, cast flash pulse, and 3.3.5-safe APIs.

local TR = _G.TacoRot or {}
_G.TacoRot = TR

-- ===================== Compat helpers =====================
local function SetSizeCompat(obj, w, h)
    if obj.SetSize then obj:SetSize(w, h)
    else
        if obj.SetWidth  then obj:SetWidth(w)  end
        if obj.SetHeight then obj:SetHeight(h) end
    end
end

local function MaybeClampToScreen(f, on)
    if f.SetClampedToScreen then f:SetClampedToScreen(on) end
end

-- ===================== DB Helpers =====================
local function EnsureUIData()
    _G.TacoRotDB = _G.TacoRotDB or {}
    local DB = _G.TacoRotDB
    DB.UI = DB.UI or {}
    if DB.UI.locked == nil then DB.UI.locked = false end
    if DB.UI.scale  == nil then DB.UI.scale  = 1.0  end
    return DB
end
EnsureUIData()

-- ===================== Icon Helpers =====================
_G.TacoRotIconFallbacks = _G.TacoRotIconFallbacks or {}
local fb = _G.TacoRotIconFallbacks

local function SafeSpellTexture(id)
    if type(id) == "number" and id > 0 then
        local _, _, icon = GetSpellInfo(id) -- 3.3.5-safe
        if icon then return icon end
    end
    return fb[id] or "Interface\\Icons\\INV_Misc_QuestionMark"
end

local function EnableDrag(frame, enable)
    if not frame then return end
    frame:SetMovable(true)
    MaybeClampToScreen(frame, true)
    if enable then
        frame:EnableMouse(true)
        frame:RegisterForDrag("LeftButton")
        frame:SetScript("OnDragStart", function(f) if not IsShiftKeyDown() then f:StartMoving() end end)
        frame:SetScript("OnDragStop",  function(f)
            f:StopMovingOrSizing()
            local DB = EnsureUIData()
            local p, _, rP, x, y = f:GetPoint()
            DB.UI.point, DB.UI.relPoint, DB.UI.x, DB.UI.y = p, rP, x, y
        end)
    else
        frame:EnableMouse(false)
        frame:RegisterForDrag()
        frame:SetScript("OnDragStart", nil)
        frame:SetScript("OnDragStop",  nil)
    end
end

-- ===================== Cooldown helpers (Blizzard spiral) =====================
local function EnsureCooldown(f)
    if f.cooldown then return f.cooldown end
    local cd = CreateFrame("Cooldown", nil, f)          -- 3.3.5 has Cooldown frames
    cd:SetAllPoints(f)
    if cd.SetReverse then cd:SetReverse(true) end       -- make it sweep clockwise, like action buttons
    cd:Hide()
    -- Make sure the spiral sits above the icon but below our glow
    cd:SetFrameLevel(f:GetFrameLevel() + 5)
    f.cooldown = cd
    return cd
end

local function SetCooldownOn(f, start, duration, enable)
    if not f then return end
    local cd = EnsureCooldown(f)
    if enable == 1 and duration and duration > 0 and start and start > 0 then
        if cd.SetCooldown then
            cd:SetCooldown(start, duration)
        elseif CooldownFrame_SetTimer then               -- fallback for older builds
            CooldownFrame_SetTimer(cd, start, duration, 1)
        end
        cd:Show()
    else
        if cd.SetCooldown then
            cd:Hide()                                    -- simplest clear on 3.3.5
        elseif CooldownFrame_SetTimer then
            CooldownFrame_SetTimer(cd, 0, 0, 0)
            cd:Hide()
        end
    end
end

-- ===================== Frames =====================
local function CreateIconFrame(name, parent, size, ox, oy)
    local f = _G[name]
    if f then return f end

    f = CreateFrame("Frame", name, parent)
    SetSizeCompat(f, size, size)
    f:SetPoint("CENTER", parent, "CENTER", ox, oy)

    local bg = f:CreateTexture(nil, "BACKGROUND")
    bg:SetAllPoints(f)
    bg:SetTexture(0, 0, 0, 0.5) -- 3.3.5: solid color via SetTexture(r,g,b,a)
    f.bg = bg

    local t = f:CreateTexture(nil, "ARTWORK")
    t:SetAllPoints(f)
    t:SetTexture("Interface\\Icons\\INV_Misc_QuestionMark")
    f.icon = t

    EnsureCooldown(f) -- add Blizzard spiral overlay

    f:Show()
    return f
end

-- Defaults in case Ace DB isn’t ready yet; will be resized by ApplySettings
local _DEFAULT_MAIN = 52
local _DEFAULT_NEXT = 40
local _DEFAULT_NEXT2 = 32

TacoRotWindow  = TacoRotWindow  or CreateIconFrame("TacoRotWindow",  UIParent, _DEFAULT_MAIN, -90, 0)
TacoRotWindow2 = TacoRotWindow2 or CreateIconFrame("TacoRotWindow2", UIParent, _DEFAULT_NEXT,  -40, 0)
TacoRotWindow3 = TacoRotWindow3 or CreateIconFrame("TacoRotWindow3", UIParent, _DEFAULT_NEXT2,   0, 0)

local function AnchorSecondaries()
    TacoRotWindow2:ClearAllPoints()
    TacoRotWindow3:ClearAllPoints()
    TacoRotWindow2:SetPoint("LEFT", TacoRotWindow,  "RIGHT", 12, 0)
    TacoRotWindow3:SetPoint("LEFT", TacoRotWindow2, "RIGHT", 10, 0)
end

-- ===================== Wrath-safe GLOW (kept; optional flair) =====================
local function EnsureGlow(f)
    if f._glow then return f._glow end
    local g = f:CreateTexture(nil, "OVERLAY")
    g:SetTexture("Interface\\Cooldown\\ping4") -- present in 3.3.5
    g:SetBlendMode("ADD")
    g:SetPoint("CENTER")
    g:SetAlpha(0)
    local w, h = f:GetWidth() or 52, f:GetHeight() or 52
    SetSizeCompat(g, (w * 1.7), (h * 1.7))
    g:Hide()
    f._glow = g
    return g
end

local function EnsureFlashDriver(f)
    if f._flashDriver then return f._flashDriver end
    local drv = CreateFrame("Frame", nil, f); drv:Hide()
    drv._active = false
    drv._dur    = 0.25
    drv._tEnd   = 0
    drv._baseW  = (f:GetWidth() or 52) * 1.7
    drv._baseH  = (f:GetHeight() or 52) * 1.7

    drv:SetScript("OnUpdate", function(self, elapsed)
        if not self._active then self:Hide() return end
        local g = f._glow
        if not g then self._active = false; self:Hide(); return end
        local remain = self._tEnd - GetTime()
        if remain <= 0 then
            g:SetAlpha(0); g:Hide()
            self._active = false
            self:Hide()
            return
        end
        local pct = remain / self._dur
        g:SetAlpha(pct)
        local s = 1.0 + (1 - pct) * 0.35
        SetSizeCompat(g, self._baseW * s, self._baseH * s)
    end)

    f._flashDriver = drv
    return drv
end

local function TriggerFlash(f)
    if not f then return end
    local g   = EnsureGlow(f)
    local drv = EnsureFlashDriver(f)
    drv._baseW = (f:GetWidth() or 52) * 1.7
    drv._baseH = (f:GetHeight() or 52) * 1.7
    g:SetAlpha(1.0)
    g:Show()
    drv._active = true
    drv._tEnd   = GetTime() + drv._dur
    drv:Show()
end

-- ===================== UI restore/update =====================
local function RestoreUI()
    local DB = EnsureUIData()
    local ui = DB.UI

    local scale = tonumber(ui.scale) or 1.0
    TacoRotWindow:SetScale(scale)
    TacoRotWindow2:SetScale(scale)
    TacoRotWindow3:SetScale(scale)

    if ui.point and ui.relPoint and ui.x and ui.y then
        TacoRotWindow:ClearAllPoints()
        TacoRotWindow:SetPoint(ui.point, UIParent, ui.relPoint, ui.x, ui.y)
    end
    AnchorSecondaries()
    EnableDrag(TacoRotWindow, not ui.locked)
end

-- Public API expected by core
TR.UI = TR.UI or {}

-- Size + layout driven by Ace profile when available
function TR.UI:ApplySettings()
    local main = (TR.db and TR.db.profile and TR.db.profile.iconSize) or _DEFAULT_MAIN
    local nsc  = (TR.db and TR.db.profile and TR.db.profile.nextScale) or 0.82
    local n1   = math.floor(main * nsc)
    local n2   = math.max(24, math.floor(n1 * 0.8))

    SetSizeCompat(TacoRotWindow,  main, main)
    SetSizeCompat(TacoRotWindow2, n1,   n1)
    SetSizeCompat(TacoRotWindow3, n2,   n2)

    -- keep cooldowns fitted
    if TacoRotWindow.cooldown  then TacoRotWindow.cooldown:SetAllPoints(TacoRotWindow) end
    if TacoRotWindow2.cooldown then TacoRotWindow2.cooldown:SetAllPoints(TacoRotWindow2) end
    if TacoRotWindow3.cooldown then TacoRotWindow3.cooldown:SetAllPoints(TacoRotWindow3) end

    AnchorSecondaries()
end

function TR.UI:Init()
    RestoreUI()
    self:UpdateGCD() -- clear/initialize spiral state
end

-- Engines call this to set icons; also remember main for flash matching
function TR.UI_Update(mainID, next1, next2)
    if TacoRotWindow and TacoRotWindow.icon then
        TacoRotWindow.icon:SetTexture(SafeSpellTexture(mainID))
    end
    if TacoRotWindow2 and TacoRotWindow2.icon then
        TacoRotWindow2.icon:SetTexture(SafeSpellTexture(next1))
    end
    if TacoRotWindow3 and TacoRotWindow3.icon then
        TacoRotWindow3.icon:SetTexture(SafeSpellTexture(next2))
    end
    TR._lastMainSpell = mainID
end

function TR.UI:Update(a,b,c) TR.UI_Update(a,b,c) end

-- === GCD spiral update ===
local GCD_ID = 61304 -- the universal GCD spell in Wrath
function TR.UI:UpdateGCD()
    local start, duration, enable = GetSpellCooldown(GCD_ID)
    SetCooldownOn(TacoRotWindow,  start, duration, enable)
    SetCooldownOn(TacoRotWindow2, start, duration, enable)
    SetCooldownOn(TacoRotWindow3, start, duration, enable)
end

-- === FLASH HOOK (called by core during cast start/succeed) ===
function TR:SetMainCastFlash(on)
    if not TacoRotWindow then return end
    if on then
        TriggerFlash(TacoRotWindow)
    else
        if TacoRotWindow._glow then
            TacoRotWindow._glow:Hide()
            TacoRotWindow._glow:SetAlpha(0)
        end
        if TacoRotWindow._flashDriver then
            TacoRotWindow._flashDriver._active = false
            TacoRotWindow._flashDriver:Hide()
        end
    end
end

-- ===================== Slash (/trui) =====================
SLASH_TACOROTUI1 = "/trui"
SlashCmdList["TACOROTUI"] = function(msg)
    msg = (msg or ""):lower()
    local DB = EnsureUIData()
    if msg == "unlock" then
        DB.UI.locked = false; EnableDrag(TacoRotWindow, true)
        DEFAULT_CHAT_FRAME:AddMessage("|cffffcc00[TacoRot]|r UI unlocked. Drag the main icon.")
    elseif msg == "lock" then
        DB.UI.locked = true; EnableDrag(TacoRotWindow, false)
        DEFAULT_CHAT_FRAME:AddMessage("|cffffcc00[TacoRot]|r UI locked.")
    elseif msg:find("^scale") then
        local v = tonumber(msg:match("scale%s+([%d%.]+)"))
        if v and v >= 0.5 and v <= 2.0 then
            DB.UI.scale = v; RestoreUI()
            DEFAULT_CHAT_FRAME:AddMessage("|cffffcc00[TacoRot]|r UI scale set to "..v)
        else
            DEFAULT_CHAT_FRAME:AddMessage("|cffffcc00[TacoRot]|r Usage: /trui scale 0.5 - 2.0")
        end
    elseif msg == "reset" then
        DB.UI.point, DB.UI.relPoint, DB.UI.x, DB.UI.y = nil, nil, nil, nil
        DB.UI.scale = 1.0
        RestoreUI()
        DEFAULT_CHAT_FRAME:AddMessage("|cffffcc00[TacoRot]|r UI position/scale reset.")
    else
        DEFAULT_CHAT_FRAME:AddMessage("|cffffcc00[TacoRot]|r Commands: unlock, lock, scale <num>, reset")
    end
end

-- Initialize now (also called from core if available)
TR.UI:Init()
