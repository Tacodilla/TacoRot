-- TacoRot / ui.lua  — adds proper drag handlers + persists anchor
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

local function makeDraggable(frame, persistAnchor)
  frame:RegisterForDrag("LeftButton")
  frame:SetMovable(true)
  frame:EnableMouse(true)
  frame:SetScript("OnDragStart", function(self)
    local unlocked = TacoRot and TacoRot.db and TacoRot.db.profile.unlock
    if unlocked then self:StartMoving() end
  end)
  frame:SetScript("OnDragStop", function(self)
    self:StopMovingOrSizing()
    if persistAnchor and TacoRot and TacoRot.db then
      local point, rel, relPoint, x, y = self:GetPoint()
      -- normalize rel to a frame name if possible
      local relName = rel and rel.GetName and rel:GetName() or rel or "UIParent"
      TacoRot.db.profile.anchor = {point, _G[relName] or UIParent, relPoint, x, y}
    end
  end)
end

function TacoRot:CreateWindows()
  if TacoRotWindow then return end
  local s = self.db.profile.iconSize

  -- Main suggestion
  TacoRotWindow  = createWindow("TacoRotWindow", s, "Interface\\Icons\\Spell_Shadow_ShadowBolt")
  -- Use saved anchor if present
  local anc = self.db.profile.anchor or {"CENTER", UIParent, "CENTER", -200, 120}
  TacoRotWindow:ClearAllPoints()
  TacoRotWindow:SetPoint(anc[1], anc[2] or UIParent, anc[3], anc[4], anc[5])
  makeDraggable(TacoRotWindow, true)  -- persist anchor on drop

  -- Next 2 (follow the main window)
  TacoRotWindow2 = createWindow("TacoRotWindow2", s*self.db.profile.nextScale, "Interface\\Icons\\INV_Misc_QuestionMark")
  TacoRotWindow2:SetPoint("BOTTOMLEFT", TacoRotWindow, "BOTTOMRIGHT", 3, 0)
  makeDraggable(TacoRotWindow2, false) -- anchored to main; no need to persist

  TacoRotWindow3 = createWindow("TacoRotWindow3", s*self.db.profile.nextScale, "Interface\\Icons\\INV_Misc_QuestionMark")
  TacoRotWindow3:SetPoint("BOTTOMLEFT", TacoRotWindow2, "BOTTOMRIGHT", 3, 0)
  makeDraggable(TacoRotWindow3, false)

  -- Defense (left of main)
  TacoRotDefWindow = createWindow("TacoRotDefWindow", math.floor(s*0.75), "Interface\\Icons\\Spell_Shadow_AntiShadow")
  TacoRotDefWindow:SetPoint("RIGHT", TacoRotWindow, "LEFT", -6, 0)
  makeDraggable(TacoRotDefWindow, false)

  -- Interrupt / Purge flashes (to the right of main)
  TacoRotIntFlash = createWindow("TacoRotIntFlash", self.db.profile.flashSize*0.25, "Interface\\Icons\\Ability_Kick")
  TacoRotIntFlash:SetPoint("TOPLEFT", TacoRotWindow, "TOPRIGHT", 5, 0)
  makeDraggable(TacoRotIntFlash, false)

  TacoRotPurgeFlash = createWindow("TacoRotPurgeFlash", self.db.profile.flashSize*0.25, "Interface\\Icons\\Spell_Nature_Purge")
  TacoRotPurgeFlash:SetPoint("BOTTOMLEFT", TacoRotWindow, "BOTTOMRIGHT", 5, 0)
  makeDraggable(TacoRotPurgeFlash, false)
end
