-- engine_warrior.lua — TacoRot Warrior (3.3.5)
-- IDS resolver + padding-safe fallback (A may be nil on first tick) + contract timer.

local TR = _G.TacoRot
if not TR then return end

-- ===== IDS resolve (handles several naming schemes) =====
local function ResolveIDS()
  local t
  t = _G.TacoRot_IDS_Warrior;       if type(t)=="table" and (t.Ability or t.Rank) then return t end
  t = _G.TacoRot_IDS_WARRIOR;    if type(t)=="table" and (t.Ability or t.Rank) then return t end
  if type(_G.TacoRot_IDS)=="table" then
    t = _G.TacoRot_IDS["WARRIOR"]; if type(t)=="table" and (t.Ability or t.Rank) then return t end
    t = _G.TacoRot_IDS["Warrior"];    if type(t)=="table" and (t.Ability or t.Rank) then return t end
    if _G.TacoRot_IDS.Ability then return _G.TacoRot_IDS end
  end
  return nil
end

local IDS = ResolveIDS() or {}; local A = IDS.Ability -- may be nil at load
local SAFE = 78

-- ===== spec name =====
local function PrimaryTab()
  local num = (GetNumTalentTabs and GetNumTalentTabs()) or 3
  local bestIdx, bestPts = 1, -1
  for i=1, num do
    local _, _, points = GetTalentTabInfo(i)
    points = points or 0
    if points > bestPts then bestIdx, bestPts = i, points end
  end
  return bestIdx
end
local function SpecName()
  local tab = PrimaryTab()
  if tab == 1 then return "Arms" elseif tab == 2 then return "Fury" else return "Protection" end
end

-- ===== padding config =====
local TOKEN = "WARRIOR"
local function Pad()
  local p = TR and TR.db and TR.db.profile and TR.db.profile.pad
  local pad = p and p[TOKEN]
  if not pad then return {enabled=true, gcd=1.6} end
  if pad.enabled == nil then pad.enabled = true end
  pad.gcd = pad.gcd or 1.6
  return pad
end

-- ===== helpers =====
local function Known(id) return id and (IsPlayerSpell and IsPlayerSpell(id) or (IsSpellKnown and IsSpellKnown(id))) end
local function ReadyNow(id)
  if not Known(id) then return false end
  local s,d,en = GetSpellCooldown(id); if en == 0 then return false end
  return (not s or s == 0 or d == 0)
end
local function ReadySoon(id)
  local pad = Pad()
  if not pad.enabled then return ReadyNow(id) end
  if not Known(id) then return false end
  local s,d,en = GetSpellCooldown(id); if en == 0 then return false end
  if (not s or s == 0 or d == 0) then return true end
  return (s + d - GetTime()) <= (pad.gcd or 1.6)
end
local function DebuffUpID(unit, spellID)
  if not spellID then return false end
  local wanted = GetSpellInfo(spellID)
  for i=1,40 do
    local name, _, _, _, _, _, _, caster, _, _, id = UnitDebuff(unit, i)
    if not name then break end
    if id == spellID or (name == wanted and caster == "player") then return true end
  end
  return false
end
local function BuffUpID(unit, spellID)
  if not spellID then return false end
  local wanted = GetSpellInfo(spellID)
  for i=1,40 do
    local name = UnitBuff(unit, i)
    if not name then break end
    if name == wanted then return true end
  end
  return false
end
local function HaveTarget() return UnitExists("target") and not UnitIsDead("target") end
local function pad3(q, fb) q[1]=q[1] or fb; q[2]=q[2] or q[1]; q[3]=q[3] or q[2]; return q end
local function Push(q,id) if id then q[#q+1]=id end end

-- ===== padding-safe Fallbacks (guard A==nil) =====

local function Fallback(forceSafe)
  if forceSafe or not A then
    return SAFE -- 78 Heroic Strike is a safe texture; if unknown, client still has it
  end
  return (Known(A.HeroicStrike) and A.HeroicStrike)
      or (Known(A.Rend) and A.Rend)
      or (Known(A.BattleShout) and A.BattleShout)
      or SAFE
end


-- ===== priorities (may reference A; BuildQueue called only when A available) =====

local function Rage() return UnitPower("player",1) or 0 end
local function BuildQueue()
  local q = {}
  local tree = PrimaryTab()
  if A and A.BattleShout and not UnitAffectingCombat("player") and ReadySoon(A.BattleShout) and not BuffUpID("player", A.BattleShout) then Push(q, A.BattleShout) end
  if tree == 1 then
    if A and A.Rend and not DebuffUpID("target", A.Rend) and ReadySoon(A.Rend) then Push(q, A.Rend) end
    if A and ReadySoon(A.Overpower) then Push(q, A.Overpower) end
    if A and ReadySoon(A.MortalStrike) then Push(q, A.MortalStrike) end
    if A and UnitHealth("target") > 1 and (UnitHealth("target")/UnitHealthMax("target")) <= 0.2 and ReadySoon(A.Execute) then Push(q, A.Execute) end
    if A and ReadySoon(A.Slam) then Push(q, A.Slam) end
    if A and Rage() > 50 and ReadySoon(A.HeroicStrike) then Push(q, A.HeroicStrike) end
  else
    if A and ReadySoon(A.Bloodthirst) then Push(q, A.Bloodthirst) end
    if A and ReadySoon(A.Whirlwind) then Push(q, A.Whirlwind) end
    if A and ReadySoon(A.Slam) then Push(q, A.Slam) end
    if A and UnitHealth("target") > 1 and (UnitHealth("target")/UnitHealthMax("target")) <= 0.2 and ReadySoon(A.Execute) then Push(q, A.Execute) end
    if A and Rage() > 50 and ReadySoon(A.HeroicStrike) then Push(q, A.HeroicStrike) end
  end
  return q
end


-- ===== TICK =====
function TR:EngineTick_Warrior()
  -- Late-bind A every tick; if still nil, show safe fallback w/o touching A
  IDS = ResolveIDS() or IDS
  A = (IDS and IDS.Ability) or A
  if IDS and IDS.UpdateRanks then pcall(IDS.UpdateRanks, IDS) end

  local q
  if not A or not next(A) then
    local fb = Fallback(true) -- "true" -> force safe path (no A access)
    q = {fb, fb, fb}
  elseif HaveTarget() then
    q = BuildQueue()
  else
    local fb = Fallback(false)
    q = {fb, fb, fb}
  end

  q = pad3(q or {{}}, Fallback(true) or SAFE)
  self._lastMainSpell = q[1]
  if self.UI and self.UI.Update then self.UI:Update(q[1], q[2], q[3]) end
end

-- ===== START/STOP with 0.20s timer =====
function TR:StartEngine_Warrior()
  self:StopEngine_Warrior()
  self:EngineTick_Warrior()

  local AceTimer = LibStub and LibStub("AceTimer-3.0", true)
  if AceTimer and AceTimer.ScheduleRepeatingTimer then
    self._engineTimer_WA = AceTimer:ScheduleRepeatingTimer(function()
      _G.TacoRot:EngineTick_Warrior()
    end, 0.20)
  else
    local acc, f = 0, CreateFrame("Frame")
    f:SetScript("OnUpdate", function(_, elapsed)
      acc = acc + (elapsed or 0)
      if acc >= 0.20 then
        acc = acc - 0.20
        _G.TacoRot:EngineTick_Warrior()
      end
    end)
    self._engineTimer_WA = f
  end

  self:Print("TacoRot Warrior engine active: " .. SpecName())
end

function TR:StopEngine_Warrior()
  local t = self._engineTimer_WA
  if not t then return end
  local AceTimer = LibStub and LibStub("AceTimer-3.0", true)
  if AceTimer and type(t) == "number" then
    AceTimer:CancelTimer(t, true)
  elseif type(t) == "table" and t.SetScript then
    t:SetScript("OnUpdate", nil); t:Hide()
  end
  self._engineTimer_WA = nil
end

do
  local _, class = UnitClass("player")
  if class == "WARRIOR" then TR:StartEngine_Warrior() end
end
