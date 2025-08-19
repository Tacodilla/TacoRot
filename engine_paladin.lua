-- engine_paladin.lua — TacoRot Paladin (3.3.5)
-- Adds out-of-combat buff "padding" (configurable) + existing low-level padding.
-- OOC buffs are suggested only if enabled in options and missing.

local TR = _G.TacoRot
if not TR then return end

local function ResolveIDS()
  local t
  t = _G.TacoRot_IDS_Paladin;       if type(t)=="table" and (t.Ability or t.Rank) then return t end
  t = _G.TacoRot_IDS_PALADIN;       if type(t)=="table" and (t.Ability or t.Rank) then return t end
  if type(_G.TacoRot_IDS)=="table" then
    t = _G.TacoRot_IDS["PALADIN"]; if type(t)=="table" and (t.Ability or t.Rank) then return t end
    t = _G.TacoRot_IDS["Paladin"]; if type(t)=="table" and (t.Ability or t.Rank) then return t end
    if _G.TacoRot_IDS.Ability then return _G.TacoRot_IDS end
  end
  return nil
end

local IDS = ResolveIDS() or {}; local A = IDS.Ability
local SAFE = 20271

-- talent/spec
local function PrimaryTab()
  local n = (GetNumTalentTabs and GetNumTalentTabs()) or 3
  local best, pts = 1, -1
  for i=1,n do local _,_,p = GetTalentTabInfo(i); p=p or 0; if p>pts then best,pts=i,p end end
  return best
end
local function SpecName()
  local tab = PrimaryTab()
  return "Retribution"
end

-- padding + buff config
local TOKEN = "PALADIN"
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

-- Fallback safe
local function Fallback()
  return SAFE
end

-- OOC Buff maintenance (per class)

local SOR = (A and A.SealOfRighteousness) or 84508 -- server custom
local function HaveSeal()
  return BuffUpID("player", (A and A.SealOfRighteousness) or SOR)
      or BuffUpID("player", A and A.SealOfVengeance)
      or BuffUpID("player", A and A.SealOfCorruption)
end
local function BuildBuffQueue()
  local cfg = BuffCfg(); if not (cfg.enabled ~= false and (cfg.seal ~= false)) then return end
  local q = {}
  if not HaveSeal() then
    if ReadySoon((A and A.SealOfRighteousness) or SOR) then Push(q, (A and A.SealOfRighteousness) or SOR) end
  end
  return q
end

-- core priorities

local function BuildQueue()
  local q = {}
  
  -- Auto attack first if not active and in range (crucial for low-level paladins)
  if InMelee() and not AutoAttackActive() then
    table.insert(q, 1, 6603) -- Attack spell ID
  end
  
  -- standard Ret single-target
  if A and (ReadySoon(A.JudgementOfWisdom) or ReadySoon(A.JudgementOfLight)) then Push(q, A.JudgementOfWisdom or A.JudgementOfLight) end
  if A and ReadySoon(A.DivineStorm) then Push(q, A.DivineStorm) end
  if A and ReadySoon(A.CrusaderStrike) then Push(q, A.CrusaderStrike) end
  if A and ReadySoon(A.Exorcism) then Push(q, A.Exorcism) end
  if A and ReadySoon(A.Consecration) then Push(q, A.Consecration) end
  if A and UnitHealth("target")>1 and (UnitHealth("target")/UnitHealthMax("target"))<=0.2 and ReadySoon(A.HammerOfWrath) then Push(q, A.HammerOfWrath) end
  return q
end

-- tick
function TR:EngineTick_Paladin()
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
      if HaveTarget() then q = BuildQueue() else local fb = Fallback(); q = {fb,fb,fb} end
    end
  else
    q = BuildQueue()
  end

  q = pad3(q or {}, Fallback())
  self._lastMainSpell = q[1]
  
  -- Fix UI update call
  if TR.UI_Update then
    TR.UI_Update(q[1], q[2], q[3])
  elseif self.UI and self.UI.Update then 
    self.UI:Update(q[1], q[2], q[3]) 
  end
end

-- start/stop
function TR:StartEngine_Paladin()
  self:StopEngine_Paladin()
  self:EngineTick_Paladin()
  local AceTimer = LibStub and LibStub("AceTimer-3.0", true)
  if AceTimer and AceTimer.ScheduleRepeatingTimer then
    self._engineTimer_PA = AceTimer:ScheduleRepeatingTimer(function() _G.TacoRot:EngineTick_Paladin() end, 0.20)
  else
    local acc, f = 0, CreateFrame("Frame")
    f:SetScript("OnUpdate", function(_, e) acc=acc+(e or 0); if acc>=0.20 then acc=acc-0.20; _G.TacoRot:EngineTick_Paladin() end end)
    self._engineTimer_PA = f
  end
  self:Print("TacoRot Paladin engine active: " .. SpecName())
end
function TR:StopEngine_Paladin()
  local t = self._engineTimer_PA
  if not t then return end
  local AceTimer = LibStub and LibStub("AceTimer-3.0", true)
  if AceTimer and type(t)=="number" then AceTimer:CancelTimer(t,true) elseif type(t)=="table" and t.SetScript then t:SetScript("OnUpdate",nil); t:Hide() end
  self._engineTimer_PA = nil
end

do local _,c=UnitClass("player"); if c=="PALADIN" then TR:StartEngine_Paladin() end end