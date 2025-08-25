-- engine_warrior.lua — TacoRot Warrior (3.3.5)
-- Adds out-of-combat buff "padding" (configurable) + existing low-level padding.
-- OOC buffs are suggested only if enabled in options and missing.

local TR = _G.TacoRot
if not TR then return end

local function ResolveIDS()
  local t
  t = _G.TacoRot_IDS_Warrior;       if type(t)=="table" and (t.Ability or t.Rank) then return t end
  t = _G.TacoRot_IDS_WARRIOR;       if type(t)=="table" and (t.Ability or t.Rank) then return t end
  if type(_G.TacoRot_IDS)=="table" then
    t = _G.TacoRot_IDS["WARRIOR"]; if type(t)=="table" and (t.Ability or t.Rank) then return t end
    t = _G.TacoRot_IDS["Warrior"]; if type(t)=="table" and (t.Ability or t.Rank) then return t end
    if _G.TacoRot_IDS.Ability then return _G.TacoRot_IDS end
  end
  return nil
end

local IDS = ResolveIDS() or {}; local A = IDS.Ability
-- SAFE fallback constant (should be at top of each engine file)
local SAFE = 6603  -- Attack spell ID - universally available

local function Fallback()
  return SAFE
end

-- talent/spec
local function PrimaryTab()
  local n = (GetNumTalentTabs and GetNumTalentTabs()) or 3
  local best, pts = 1, -1
  for i=1,n do local _,_,p = GetTalentTabInfo(i); p=p or 0; if p>pts then best,pts=i,p end end
  return best
end
local function SpecName()
  local tab = PrimaryTab()
  if tab==1 then return "Arms" elseif tab==2 then return "Fury" else return "Protection" end
end

-- padding + buff config
local TOKEN = "WARRIOR"
local function Pad() local p=TR and TR.db and TR.db.profile and TR.db.profile.pad; local v=p and p[TOKEN]; if not v then return {enabled=true,gcd=1.6} end; if v.enabled==nil then v.enabled=true end; v.gcd=v.gcd or 1.6; return v end
local function BuffCfg() local p=TR and TR.db and TR.db.profile and TR.db.profile.buff; return (p and p[TOKEN]) or {enabled=true} end

-- helpers
local function Known(id) return id and (IsPlayerSpell and IsPlayerSpell(id) or (IsSpellKnown and IsSpellKnown(id))) end
local function ReadyNow(id) if not Known(id) then return false end local s,d,en=GetSpellCooldown(id); if en==0 then return false end return (not s or s==0 or d==0) end
local function ReadySoon(id)
  local pad = Pad()
  if not pad.enabled then return ReadyNow(id) end
  if not Known(id) then return false end
  local start, duration, enabled = GetSpellCooldown(id)
  if enabled == 0 then return false end
  if (not start or start == 0 or duration == 0) then return true end
  local gcd = 1.5
  local remaining = (start + duration) - GetTime()
  return remaining <= (pad.gcd + gcd)
end
local function DebuffUpID(u, id) if not id then return false end local wanted=GetSpellInfo(id) for i=1,40 do local name,_,_,_,_,_,_,caster,_,_,sid=UnitDebuff(u,i); if not name then break end if sid==id or (name==wanted and caster=="player") then return true end end return false end
local function BuffUpID(u, id) if not id then return false end local wanted=GetSpellInfo(id); if not wanted then return false end for i=1,40 do local name,_,_,_,_,_,_,_,_,_,sid=UnitBuff(u,i); if not name then break end if sid==id or name==wanted then return true end end return false end
local function HaveTarget() return UnitExists("target") and not UnitIsDead("target") end
local function InMelee() return CheckInteractDistance and CheckInteractDistance("target", 3) end
local function pad3(q, fb) q[1]=q[1] or fb; q[2]=q[2] or q[1]; q[3]=q[3] or q[2]; return q end
local function Push(q,id) if id then q[#q+1]=id end end

-- Auto Attack helper
local function AutoAttackActive()
  return IsAutoRepeatSpell and (IsAutoRepeatSpell("Attack") == 1 or IsAutoRepeatSpell("Attack") == true)
end

-- OOC Buff maintenance (per class)

local function BuildBuffQueue()
  local cfg = BuffCfg(); if not (cfg.enabled ~= false and (cfg.battleShout ~= false)) then return end
  local q = {}
  if A and A.BattleShout and not BuffUpID("player", A.BattleShout) and ReadySoon(A.BattleShout) then Push(q, A.BattleShout) end
  return q
end

-- core priorities

local function Rage() return UnitPower("player",1) or 0 end

-- Helper to detect if we're in an AoE situation
local function ShouldUseAoE()
  if not (TR and TR.db and TR.db.profile and TR.db.profile.aoe) then
    return false
  end
  return true
end

local function BuildSingleTargetQueue(level)
  local q = {}
  local tree = PrimaryTab() -- 1 Arms, 2 Fury
  local rage = Rage()

  -- Auto attack always first if in melee
  if InMelee() and not AutoAttackActive() then
    table.insert(q, 1, 6603)
  end

  if level < 16 then
    if rage > 15 and A and ReadySoon(A.HeroicStrike) then Push(q, A.HeroicStrike) end

  elseif level < 31 then
    if A and A.Rend and not DebuffUpID("target", A.Rend) and ReadySoon(A.Rend) then Push(q, A.Rend) end
    if A and ReadySoon(A.Overpower) then Push(q, A.Overpower) end
    if rage > 30 and A and ReadySoon(A.HeroicStrike) then Push(q, A.HeroicStrike) end

  elseif level < 46 then
    if tree == 1 and A and ReadySoon(A.MortalStrike) then Push(q, A.MortalStrike) end
    if tree == 2 and A and ReadySoon(A.Bloodthirst) then Push(q, A.Bloodthirst) end
    if A and A.Rend and not DebuffUpID("target", A.Rend) and ReadySoon(A.Rend) then Push(q, A.Rend) end
    if A and ReadySoon(A.Overpower) then Push(q, A.Overpower) end
    if rage > 40 and A and ReadySoon(A.HeroicStrike) then Push(q, A.HeroicStrike) end

  else
    local targetHealthPct = UnitHealth("target") / UnitHealthMax("target")
    if UnitHealth("target") > 1 and targetHealthPct <= 0.2 and A and ReadySoon(A.Execute) then Push(q, A.Execute) end
    if tree == 1 then
      if A and ReadySoon(A.MortalStrike) then Push(q, A.MortalStrike) end
      if A and A.Rend and not DebuffUpID("target", A.Rend) and ReadySoon(A.Rend) then Push(q, A.Rend) end
      if A and ReadySoon(A.Overpower) then Push(q, A.Overpower) end
      if A and ReadySoon(A.Slam) then Push(q, A.Slam) end
    else
      if A and ReadySoon(A.Bloodthirst) then Push(q, A.Bloodthirst) end
      if A and ReadySoon(A.Whirlwind) then Push(q, A.Whirlwind) end
      if A and ReadySoon(A.Slam) then Push(q, A.Slam) end
    end
    if rage > 50 and A and ReadySoon(A.HeroicStrike) then Push(q, A.HeroicStrike) end
  end

  return q
end

local function BuildAoEQueue(level)
  local q = {}
  local rage = Rage()

  if InMelee() and not AutoAttackActive() then
    table.insert(q, 1, 6603)
  end

  if level < 36 then
    if rage > 20 and A and ReadySoon(A.HeroicStrike) then Push(q, A.HeroicStrike) end
  else
    if A and ReadySoon(A.Whirlwind) then Push(q, A.Whirlwind) end
    if level >= 46 then
      local tree = PrimaryTab()
      if tree == 1 and A and ReadySoon(A.SweepingStrikes) then Push(q, A.SweepingStrikes) end
    end
    if rage > 30 and A and ReadySoon(A.HeroicStrike) then Push(q, A.HeroicStrike) end
    if A and ReadySoon(A.Slam) then Push(q, A.Slam) end
  end

  return q
end

local function BuildQueue()
  local level = UnitLevel("player")
  if ShouldUseAoE() then
    return BuildAoEQueue(level)
  else
    return BuildSingleTargetQueue(level)
  end
end

-- tick
function TR:EngineTick_Warrior()
  IDS = ResolveIDS() or IDS
  A = (IDS and IDS.Ability) or A
  if IDS and IDS.UpdateRanks then pcall(IDS.UpdateRanks, IDS) end

  local q
  if not A or not next(A) then
    local fb = Fallback()
    q = {fb,fb,fb}
  elseif not UnitAffectingCombat("player") then
    q = BuildBuffQueue() or {}
    if not q[1] then
      q = BuildQueue() -- Always show rotation, regardless of target
    end
  else
    q = BuildQueue()
  end

  q = pad3(q or {}, Fallback())
  -- DEBUG: Add this TEMPORARILY to troubleshoot (remove after fixing)
  if not q or not q[1] then
    DEFAULT_CHAT_FRAME:AddMessage("|cff55ff55[TacoRot DEBUG]|r Empty queue for " .. (UnitClass("player") or "Unknown"))
    DEFAULT_CHAT_FRAME:AddMessage("|cff55ff55[TacoRot DEBUG]|r A table: " .. tostring(A and next(A) and "has spells" or "empty/nil"))
  end
  self._lastMainSpell = q[1]

  -- Standardized UI update call
  if TR.UI_Update then
    TR.UI_Update(q[1], q[2], q[3])
  elseif self.UI and self.UI.Update then
    self.UI:Update(q[1], q[2], q[3])
  end
end

-- start/stop
function TR:StartEngine_Warrior()
  self:StopEngine_Warrior()
  self:EngineTick_Warrior()
  local AceTimer = LibStub and LibStub("AceTimer-3.0", true)
  if AceTimer and AceTimer.ScheduleRepeatingTimer then
    self._engineTimer_WA = AceTimer:ScheduleRepeatingTimer(function() _G.TacoRot:EngineTick_Warrior() end, 0.20)
  else
    local acc, f = 0, CreateFrame("Frame")
    f:SetScript("OnUpdate", function(_, e) acc=acc+(e or 0); if acc>=0.20 then acc=acc-0.20; _G.TacoRot:EngineTick_Warrior() end end)
    self._engineTimer_WA = f
  end
  self:Print("TacoRot Warrior engine active: " .. SpecName())
end
function TR:StopEngine_Warrior()
  local t = self._engineTimer_WA
  if not t then return end
  local AceTimer = LibStub and LibStub("AceTimer-3.0", true)
  if AceTimer and type(t)=="number" then AceTimer:CancelTimer(t,true) elseif type(t)=="table" and t.SetScript then t:SetScript("OnUpdate",nil); t:Hide() end
  self._engineTimer_WA = nil
end

do local _,c=UnitClass("player"); if c=="WARRIOR" then TR:StartEngine_Warrior() end end