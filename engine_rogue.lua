-- engine_rogue.lua — TacoRot Rogue (3.3.5)
-- Quiet: single startup line; keeps _lastMainSpell in sync for flash.

local IDS = _G.TacoRot_IDS_Rogue
if not IDS then return end

-- ===== helpers =====
local function Known(id) return id and IsSpellKnown and IsSpellKnown(id) end
local function Energy() return UnitPower("player", 3) or 0 end
local function CP() return (GetComboPoints and GetComboPoints("player","target")) or 0 end
local function AuraRemain(unit, spellId)
  unit = unit or "player"
  for i=1,40 do
    local _, _, _, _, _, dur, exp, _, _, _, id = UnitAura(unit, i)
    if not id then break end
    if id == spellId then return math.max(0,(exp or 0)-GetTime()), dur or 0 end
  end
  return 0,0
end
local function DebuffRemain(spellId)
  for i=1,40 do
    local _, _, _, _, _, dur, exp, _, _, _, id = UnitDebuff("target", i)
    if not id then break end
    if id == spellId then return math.max(0,(exp or 0)-GetTime()), dur or 0 end
  end
  return 0,0
end
local function ReadyNow(id)
  if not Known(id) then return false end
  local s,d,en = GetSpellCooldown(id)
  return (en ~= 0) and ((s or 0) == 0 or (d or 0) == 0)
end
local function push(q, id) if id and Known(id) then q[#q+1] = id end end
local function pad3(q, fb) q[1]=q[1] or fb; q[2]=q[2] or q[1]; q[3]=q[3] or q[2]; return q end

-- ===== spec detect =====
local function RogueSpec()
  local best, idx = -1, 1
  for i=1, GetNumTalentTabs() do
    local _, _, pts = GetTalentTabInfo(i, "player")
    if (pts or 0) > best then best, idx = pts, i end
  end
  if best <= 0 then return "COMBAT" end
  return (idx == 1 and "ASSASSINATION") or (idx == 2 and "COMBAT") or "SUBTLETY"
end

-- ===== APLs =====
local A = IDS.Ability or {}

local function APL_Assassination()
  local q = {}
  local cp, en = CP(), Energy()
  local sndUp = AuraRemain("player", A.SliceandDice) > 0

  if IsStealthed() and Known(A.Ambush) and en >= 60 then push(q, A.Ambush) end
  if #q<3 and Known(A.SliceandDice) and (not sndUp) and cp >= 2 then push(q, A.SliceandDice) end
  if #q<3 and Known(A.Envenom) and cp >= 4 then push(q, A.Envenom) end
  if #q<3 and Known(A.Mutilate) and en >= 55 then push(q, A.Mutilate) end
  if #q<3 and Known(A.SinisterStrike) and en >= 45 then push(q, A.SinisterStrike) end
  return pad3(q, (Known(A.SinisterStrike) and A.SinisterStrike) or A.Backstab or A.Mutilate)
end

local function APL_Combat()
  local q = {}
  local cp, en = CP(), Energy()
  local sndUp = AuraRemain("player", A.SliceandDice) > 0

  if #q<3 and Known(A.SliceandDice) and (not sndUp) and cp >= 2 then push(q, A.SliceandDice) end
  if #q<3 and Known(A.KillingSpree) and ReadyNow(A.KillingSpree) then push(q, A.KillingSpree) end
  if #q<3 and Known(A.AdrenalineRush) and ReadyNow(A.AdrenalineRush) then push(q, A.AdrenalineRush) end
  if #q<3 and Known(A.Eviscerate) and cp >= 4 then push(q, A.Eviscerate) end
  if #q<3 and Known(A.SinisterStrike) and en >= 45 then push(q, A.SinisterStrike) end
  return pad3(q, (Known(A.SinisterStrike) and A.SinisterStrike) or A.Backstab)
end

local function APL_Subtlety()
  local q = {}
  local cp, en = CP(), Energy()
  local rupUp = DebuffRemain(A.Rupture) > 0

  if IsStealthed() and Known(A.Ambush) and en >= 60 then push(q, A.Ambush) end
  if #q<3 and Known(A.Rupture) and (not rupUp) and cp >= 3 then push(q, A.Rupture) end
  if #q<3 and Known(A.Eviscerate) and cp >= 4 then push(q, A.Eviscerate) end
  if #q<3 and Known(A.Backstab) and en >= 60 then push(q, A.Backstab) end
  if #q<3 and Known(A.SinisterStrike) and en >= 45 then push(q, A.SinisterStrike) end
  return pad3(q, (Known(A.Backstab) and A.Backstab) or A.SinisterStrike)
end

local function BuildQueue(spec)
  if not UnitExists("target") or UnitIsDead("target") then
    local fb = (Known(A.SinisterStrike) and A.SinisterStrike) or A.Backstab or A.Mutilate
    return {fb, fb, fb}
  end
  if spec == "ASSASSINATION" then return APL_Assassination()
  elseif spec == "SUBTLETY"   then return APL_Subtlety()
  else return APL_Combat() end
end

-- ===== attach to core =====
local function AttachRogue()
  local TR = _G.TacoRot
  if not TR or TR._rogue_bound then return end

  function TR:EngineTick_Rogue()
    local spec = RogueSpec()
    local q = BuildQueue(spec)
    self._lastMainSpell = q[1]
    if self.UI and self.UI.Update then
      self.UI:Update(q[1], q[2], q[3])
    end
  end

  function TR:StartEngine_Rogue()
    if self._engineTimerRG then return end
    self:EngineTick_Rogue()
    if self.ScheduleRepeatingTimer then
      self._engineTimerRG = self:ScheduleRepeatingTimer("EngineTick_Rogue", 0.2)
    else
      local f = CreateFrame("Frame"); f._t=0
      f:SetScript("OnUpdate", function(s,e) s._t=s._t+e; if s._t>=0.2 then s._t=0; if TR.EngineTick_Rogue then TR:EngineTick_Rogue() end end end)
      self._engineTimerRG = f
    end
    self:Print("TacoRot Rogue engine active: "..RogueSpec())
  end

  function TR:StopEngine_Rogue()
    if not self._engineTimerRG then return end
    local t = self._engineTimerRG
    if type(t)=="table" and t.Cancel then self:CancelTimer(t)
    elseif type(t)=="table" and t.SetScript then t:SetScript("OnUpdate", nil); t:Hide() end
    self._engineTimerRG = nil
  end

  local _, class = UnitClass("player")
  if class == "ROGUE" then TR:StartEngine_Rogue() end
  TR._rogue_bound = true
end

if _G.TacoRot then
  AttachRogue()
else
  local f = CreateFrame("Frame"); f:RegisterEvent("ADDON_LOADED")
  f:SetScript("OnEvent", function(_,_,addon) if addon=="TacoRot" then AttachRogue(); f:UnregisterAllEvents(); f:Hide() end end)
end
