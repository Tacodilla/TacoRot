-- ui.lua — 3.3.5 safe.
-- Fixes cooldown :Clear() usage and keeps original frame names (TacoRotWindow, 2, 3).
-- Supports both ApplyIcon(...) and UI.Update(s1,s2,s3).

local TacoRot = _G.TacoRot or {}
_G.TacoRot = TacoRot
TacoRot.UI = TacoRot.UI or {}
local UI = TacoRot.UI

-- -----------------------
-- helpers
-- -----------------------
local function Q() return "Interface\\Icons\\INV_Misc_QuestionMark" end
local function SpellIcon(id) local _,_,tex = GetSpellInfo(id or 0); return tex or Q() end

-- 3.3.5-safe "clear cooldown"
local function ClearCooldown(cd)
  if not cd then return end
  if CooldownFrame_SetTimer then
    CooldownFrame_SetTimer(cd, 0, 0, 0)
  else
    cd:SetCooldown(0, 0)
  end
end

local function SetCooldown(cd, start, dur, enable)
  if not cd then return end
  if start and dur and dur > 0 and (enable == 1 or enable == true) then
    if CooldownFrame_SetTimer then
      CooldownFrame_SetTimer(cd, start, dur, 1)
    else
      cd:SetCooldown(start, dur)
    end
  else
    ClearCooldown(cd)
  end
end

-- -----------------------
-- frame factory
-- -----------------------
local function CreateIconFrame(name, parent, size, tex)
  local f = CreateFrame("Frame", name, parent)
  f:SetSize(size, size)
  f:SetFrameStrata("MEDIUM")
  f:SetFrameLevel(73)
  f:SetClampedToScreen(true)

  f.tex = f:CreateTexture(nil, "ARTWORK")
  f.tex:SetAllPoints(true)
  f.tex:SetTexture(tex or Q())

  f.cd = CreateFrame("Cooldown", name.."CD", f, "CooldownFrameTemplate")
  f.cd:SetAllPoints(true)

  -- pulsing border while casting (toggled by TacoRot:SetMainCastFlash)
  f.border = f:CreateTexture(nil, "OVERLAY")
  f.border:SetTexture("Interface\\Buttons\\UI-ActionButton-Border")
  f.border:SetBlendMode("ADD")
  f.border:SetAllPoints(true)
  f.border:Hide()

  f._pulseT, f._flashing = 0, false
  f:SetScript("OnUpdate", function(self, e)
    if not self._flashing then return end
    self._pulseT = (self._pulseT + e * 2.8) % 2
    local a = self._pulseT; if a > 1 then a = 2 - a end
    self.border:SetAlpha(0.35 + 0.65 * a)
  end)

  return f
end

-- -----------------------
-- build / init
-- -----------------------
function TacoRot:CreateWindows()
  if _G.TacoRotWindow then return end

  local p = (self.db and self.db.profile) or {}
  local s = p.iconSize or 52
  local n = p.nextScale or 0.82

  local anc = p.anchor or {"CENTER", UIParent, "CENTER", -200, 120}
  local root = CreateFrame("Frame", "TacoRotAnchor", UIParent)
  root:SetSize(1,1)
  root:SetPoint(anc[1], anc[2] or UIParent, anc[3], anc[4], anc[5])

  TacoRotWindow  = CreateIconFrame("TacoRotWindow",  root, s, Q())
  TacoRotWindow2 = CreateIconFrame("TacoRotWindow2", root, math.floor(s*n), Q())
  TacoRotWindow3 = CreateIconFrame("TacoRotWindow3", root, math.floor(s*n), Q())

  TacoRotWindow:ClearAllPoints()
  TacoRotWindow:SetPoint("CENTER", root, "CENTER", 0, 0)
  TacoRotWindow2:SetPoint("LEFT", TacoRotWindow, "RIGHT", 3, 0)
  TacoRotWindow3:SetPoint("LEFT", TacoRotWindow2, "RIGHT", 3, 0)

  -- dragging (honors profile.unlock)
  local function makeDrag(f)
    f:RegisterForDrag("LeftButton")
    f:SetMovable(true)
    f:EnableMouse(true)
    f:SetScript("OnDragStart", function(self)
      local unlocked = TacoRot.db and TacoRot.db.profile and TacoRot.db.profile.unlock
      if unlocked then self:StartMoving() end
    end)
    f:SetScript("OnDragStop", function(self)
      self:StopMovingOrSizing()
      local point, rel, relPoint, x, y = TacoRotWindow:GetPoint()
      if TacoRot.db and TacoRot.db.profile then
        TacoRot.db.profile.anchor = {point, rel or UIParent, relPoint, x, y}
      end
    end)
  end
  makeDrag(TacoRotWindow); makeDrag(TacoRotWindow2); makeDrag(TacoRotWindow3)

  -- show/hide next windows from saved setting
  if p.nextWindows == false then
    TacoRotWindow2:Hide(); TacoRotWindow3:Hide()
  else
    TacoRotWindow2:Show(); TacoRotWindow3:Show()
  end
end

-- create on login so engines can immediately paint
do
  local f = CreateFrame("Frame")
  f:RegisterEvent("PLAYER_LOGIN")
  f:SetScript("OnEvent", function() if TacoRot and TacoRot.CreateWindows then TacoRot:CreateWindows() end end)
end

-- -----------------------
-- public APIs
-- -----------------------
-- Legacy: engines call this directly (Warlock/older)
function TacoRot:ApplyIcon(frame, spellId)
  if not frame or not frame.tex then
    if not _G.TacoRotWindow then self:CreateWindows() end
    frame = frame or _G.TacoRotWindow
    if not frame or not frame.tex then return end
  end

  if not spellId then
    frame.tex:SetTexture(Q())
    ClearCooldown(frame.cd)
    return
  end

  frame.tex:SetTexture(SpellIcon(spellId))
  local start, dur, en = GetSpellCooldown(spellId)
  SetCooldown(frame.cd, start, dur, en)
end

-- Queue-style: UI.Update(s1,s2,s3)
function UI.Update(s1, s2, s3)
  if not _G.TacoRotWindow then TacoRot:CreateWindows() end
  if not s2 then s2 = s1 end
  if not s3 then s3 = s2 end
  TacoRot:ApplyIcon(_G.TacoRotWindow,  s1)
  TacoRot:ApplyIcon(_G.TacoRotWindow2, s2)
  TacoRot:ApplyIcon(_G.TacoRotWindow3, s3)
end

-- Cast flash control used by core (optional)
function TacoRot:SetMainCastFlash(on)
  if not _G.TacoRotWindow then return end
  if on then
    TacoRotWindow._flashing = true
    TacoRotWindow.border:Show()
  else
    TacoRotWindow._flashing = false
    TacoRotWindow.border:Hide()
  end
end
