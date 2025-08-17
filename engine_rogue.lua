-- engine_rogue.lua (pads to 3; duplicates allowed; updates UI every tick)

local TacoRot = _G.TacoRot
if not TacoRot then return end
local IDS = _G.TacoRot_IDS_Rogue
local GCD_CUTOFF = 1.6

local function Known(id) return id and IsSpellKnown and IsSpellKnown(id) end
local function ReadySoon(id)
  if not Known(id) then return false end
  local s,d,en = GetSpellCooldown(id)
  if en == 0 then return false end
  if not s or s == 0 or d == 0 then return true end
  if d <= GCD_CUTOFF then return true end
  return (s + d - GetTime()) <= 0.2
end

local function Energy() return UnitPower("player", 3) or 0 end
local function ComboPoints() return (GetComboPoints and GetComboPoints("player","target")) or 0 end

local function AuraRemain(unit, spellId)
  unit = unit or "player"
  for i=1,40 do
    local name, _, _, _, _, dur, exp, _, _, _, id = UnitAura(unit, i)
    if not name then break end
    if id == spellId then return math.max(0,(exp or 0)-GetTime()), dur or 0 end
  end
  return 0,0
end

local function DebuffRemain(spellId)
  for i=1,40 do
    local name, _, _, _, _, dur, exp, _, _, _, id = UnitDebuff("target", i)
    if not name then break end
    if id == spellId then return math.max(0,(exp or 0)-GetTime()), dur or 0 end
  end
  return 0,0
end

local function IsAoE() return IsAltKeyDown() or (TacoRot.db and TacoRot.db.profile and TacoRot.db.profile.aoe) end
local function push(q, sid) if sid and Known(sid) then q[#q+1]=sid end end

-- ----- APLs -----
local function APL_Assassination(A)
  local q = {}
  local cp, en = ComboPoints(), Energy()
  local sndUp, sndDur = AuraRemain("player", A.SliceandDice)
  local rupUp = (DebuffRemain(A.Rupture) or 0) > 0

  if IsStealthed() and Known(A.Ambush) and en >= 60 then push(q,A.Ambush) end
  if #q<3 and Known(A.SliceandDice) and (not sndUp or sndDur <= 3) and cp >= 2 then push(q,A.SliceandDice) end
  if #q<3 and Known(A.Rupture) and (not rupUp) and cp >= 4 then push(q,A.Rupture) end
  if #q<3 and Known(A.Eviscerate) and cp >= 4 then push(q,A.Eviscerate) end
  if #q<3 and Known(A.Mutilate) and en >= 40 then push(q,A.Mutilate) end
  if #q<3 and Known(A.Backstab) and en >= 60 then push(q,A.Backstab) end
  if #q<3 and Known(A.SinisterStrike) and en >= 45 then push(q,A.SinisterStrike) end
  if #q==0 then push(q,A.SinisterStrike) end
  return q
end

local function APL_Combat(A)
  local q = {}
  local cp, en = ComboPoints(), Energy()
  local sndUp, sndDur = AuraRemain("player", A.SliceandDice)

  if Known(A.SliceandDice) and (not sndUp or sndDur <= 3) and cp >= 2 then push(q,A.SliceandDice) end
  if IsAoE() then
    if #q<3 and Known(A.BladeFlurry) and ReadySoon(A.BladeFlurry) then push(q,A.BladeFlurry) end
    if #q<3 and Known(A.FanOfKnives) and en >= 35 then push(q,A.FanOfKnives) end
  end
  if #q<3 and Known(A.Eviscerate) and cp >= 4 then push(q,A.Eviscerate) end
  if #q<3 and Known(A.SinisterStrike) and en >= 45 then push(q,A.SinisterStrike) end
  if #q<3 and Known(A.Backstab) and en >= 60 then push(q,A.Backstab) end
  if #q==0 then push(q,A.SinisterStrike) end
  return q
end

local function APL_Subtlety(A)
  local q = {}
  local cp, en = ComboPoints(), Energy()
  local sndUp, sndDur = AuraRemain("player", A.SliceandDice)

  if IsStealthed() and Known(A.Ambush) and en >= 60 then push(q,A.Ambush) end
  if #q<3 and Known(A.SliceandDice) and (not sndUp or sndDur <= 3) and cp >= 2 then push(q,A.SliceandDice) end
  if #q<3 and Known(A.Hemorrhage) and en >= 35 then push(q,A.Hemorrhage) end
  if #q<3 and Known(A.Eviscerate) and cp >= 4 then push(q,A.Eviscerate) end
  if #q<3 and Known(A.Backstab) and en >= 60 then push(q,A.Backstab) end
  if #q==0 then push(q,A.SinisterStrike) end
  return q
end

local function BuildQueue()
  if IDS and IDS.UpdateRanks then IDS:UpdateRanks() end
  local A = IDS and IDS.Ability or {}
  local spec = TacoRot.GetSpec and TacoRot:GetSpec()
  local base = (spec == "ASSASSINATION" and APL_Assassination(A))
           or (spec == "SUBTLETY"      and APL_Subtlety(A))
           or APL_Combat(A)

  -- pad to 3 (duplicates allowed so next windows always show)
  while #base < 3 do
    if IsAoE() and Known(A.FanOfKnives) then
      push(base, A.FanOfKnives)
    else
      local cp = ComboPoints()
      if cp >= 4 and Known(A.Eviscerate) then
        push(base, A.Eviscerate)
      elseif Known(A.Mutilate) then
        push(base, A.Mutilate)
      elseif Known(A.Backstab) and IsUsableSpell(A.Backstab) then
        push(base, A.Backstab)
      else
        push(base, A.SinisterStrike)
      end
    end
  end
  return base
end

function TacoRot:EngineTick_Rogue()
  local q = BuildQueue()
  self._lastMainSpell = q[1] -- for core’s cast-flash

  if TacoRot.UI and TacoRot.UI.Update then
    TacoRot.UI.Update(q[1], q[2], q[3])
  elseif TacoRot.ApplyIcon then
    TacoRot:ApplyIcon(TacoRotWindow,  q[1])
    TacoRot:ApplyIcon(TacoRotWindow2, q[2] or q[1])
    TacoRot:ApplyIcon(TacoRotWindow3, q[3] or q[2] or q[1])
  end
end

function TacoRot:StartEngine_Rogue()
  if self._engineTimerRG then return end
  self._engineTimerRG = self:ScheduleRepeatingTimer("EngineTick_Rogue", 0.2)
end

function TacoRot:StopEngine_Rogue()
  if self._engineTimerRG then self:CancelTimer(self._engineTimerRG); self._engineTimerRG=nil end
end

TacoRot:RegisterMessage("TACOROT_ENABLE_CLASS_MODULE", function()
  local _, class = UnitClass("player")
  if class == "ROGUE" then
    if IDS and IDS.UpdateRanks then IDS:UpdateRanks() end
    TacoRot:StartEngine_Rogue()
  end
end)
