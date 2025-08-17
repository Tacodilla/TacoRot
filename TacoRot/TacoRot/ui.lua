local TacoRot = _G.TacoRot
if not TacoRot then return end

local function createWindow(name, size, iconTexture)
  local f = CreateFrame("Frame", name, UIParent)
  f:SetClampedToScreen(true)
  f:SetSize(size,size)
  f:SetFrameStrata("MEDIUM")
  f:SetFrameLevel(73)
  local t = f:CreateTexture(nil, "ARTWORK")
  t:SetAllPoints(true)
  t:SetTexture(iconTexture or "Interface\\Icons\\INV_Misc_QuestionMark")
  f.tex = t
  return f
end

function TacoRot:CreateWindows()
  if TacoRotWindow then return end
  local s = self.db.profile.iconSize

  TacoRotWindow  = createWindow("TacoRotWindow", s, "Interface\\Icons\\Spell_Shadow_ShadowBolt")
  TacoRotWindow:SetPoint(unpack(self.db.profile.anchor or {"CENTER", UIParent, "CENTER", -200, 120}))

  TacoRotWindow2 = createWindow("TacoRotWindow2", s*self.db.profile.nextScale, "Interface\\Icons\\INV_Misc_QuestionMark")
  TacoRotWindow2:SetPoint("BOTTOMLEFT", TacoRotWindow, "BOTTOMRIGHT", 3, 0)

  TacoRotWindow3 = createWindow("TacoRotWindow3", s*self.db.profile.nextScale, "Interface\\Icons\\INV_Misc_QuestionMark")
  TacoRotWindow3:SetPoint("BOTTOMLEFT", TacoRotWindow2, "BOTTOMRIGHT", 3, 0)

  TacoRotDefWindow = createWindow("TacoRotDefWindow", math.floor(s*0.75), "Interface\\Icons\\Spell_Shadow_AntiShadow")
  TacoRotDefWindow:SetPoint("RIGHT", TacoRotWindow, "LEFT", -6, 0)

  TacoRotIntFlash = createWindow("TacoRotIntFlash", TacoRot.db.profile.flashSize*0.25, "Interface\\Icons\\Ability_Kick")
  TacoRotIntFlash:SetPoint("TOPLEFT", TacoRotWindow, "TOPRIGHT", 5, 0)

  TacoRotPurgeFlash = createWindow("TacoRotPurgeFlash", TacoRot.db.profile.flashSize*0.25, "Interface\\Icons\\Spell_Nature_Purge")
  TacoRotPurgeFlash:SetPoint("BOTTOMLEFT", TacoRotWindow, "BOTTOMRIGHT", 5, 0)
end
