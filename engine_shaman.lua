-- engine_shaman.lua — TacoRot Shaman (3.3.5)
-- Adds out-of-combat buff "padding" (configurable) + existing low-level padding.
-- OOC buffs are suggested only if enabled in options and missing.

local TR = _G.TacoRot
if not TR then return end

local function ResolveIDS()
  local t
  t = _G.TacoRot_IDS_Shaman;       if type(t)=="table" and (t.Ability or t.Rank) then return t end
  t = _G.TacoRot_IDS_SHAMAN;       if type(t)=="table" and (t.Ability or t.Rank) then return t end
  if type(_G.TacoRot_IDS)=="table" then
    t = _G.TacoRot_IDS["SHAMAN"]; if type(t)=="table" and (t.Ability or t.Rank) then return t end
    t = _G.TacoRot_IDS["Shaman"]; if type(t)=="table" and (t.Ability or t.Rank) then return t end
    if _G.TacoRot_IDS.Ability then return _G.TacoRot_IDS end
  end
  return nil
end

local IDS = ResolveIDS() or {}; local A = IDS.Ability
local SAFE = 403

-- talent/spec
local function PrimaryTab()
  local n = (GetNumTalentTabs and GetNumTalentTabs()) or 3
  local best, pts = 1, -1
  for i=1,n do local _,_,p = GetTalentTabInfo(i); p=p or 0; if p>pts then best,pts=i,p end end
  return best
end
local function SpecName()
  local tab = PrimaryTab()
  if tab==1 then return "Elemental" else return "Enhancement" end
end

-- padding + buff config
local TOKEN = "SHAMAN"
local function Pad() local p=TR and TR.db and TR.db.profile and TR.db.profile.pad; local v=p and p[TOKEN]; if not v then return {enabled=true,gcd=1.6} end; if v.enabled==nil then v.enabled=true end; v.gcd=v.gcd or 1.6; return v end
local function BuffCfg() local p=TR and TR.db and TR.db.profile and TR.db.profile.buff; return (p and p[TOKEN]) or {enabled=true} end

-- helpers
local function Known(id) return id and (IsPlayerSpell and IsPlayerSpell(id) or (IsSpellKnown and IsSpellKnown(id))) end
local function ReadyNow(id) if not Known(id) then return false end local s,d,en=GetSpellCooldown(id); if en==0 then return false end return (not s or s==0 or d==0) end
local function ReadySoon(id)
  if not Known(id) then return false end
  local pad = Pad()
  if not pad.enabled then
    return TR:IsAbilityReadySoon(id, 0)
  end
  return TR:IsAbilityReadySoon(id, pad.gcd)
end

local function SafeCheck(func, ...)
  if type(func) ~= "function" then return false end
  local ok, res = pcall(func, ...)
  return ok and res
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

local function LSID()
  if A and A.LightningShield then return A.LightningShield end
  -- common ranks
  local r = 49281; if Known(r) then return r end
  r = 25469; if Known(r) then return r end
  return 324 -- rank 1
end
local function BuildBuffQueue()
  local cfg = BuffCfg(); if not (cfg.enabled ~= false and (cfg.lightningShield ~= false)) then return end
  local q = {}
  local ls = LSID()
  if ls and not BuffUpID("player", ls) and SafeCheck(ReadySoon, ls) then Push(q, ls) end
  return q
end

-- core priorities

local function BuildQueue()
  local q = {}
  local tree = PrimaryTab()
  
  if tree == 1 then
    -- Elemental - ranged caster
    if A and A.FlameShock and not DebuffUpID("target", A.FlameShock) and SafeCheck(ReadySoon, A.FlameShock) then Push(q, A.FlameShock) end
    if A and SafeCheck(ReadySoon, A.MoltenBlast) then Push(q, A.MoltenBlast) end
    if A and SafeCheck(ReadySoon, A.LightningBolt) then Push(q, A.LightningBolt) end
    if A and SafeCheck(ReadySoon, A.ChainLightning) then Push(q, A.ChainLightning) end
  else
    -- Enhancement - melee
    -- Auto attack first if not active and in range (crucial for Enhancement)
    if InMelee() and not AutoAttackActive() then
      table.insert(q, 1, 6603) -- Attack spell ID
    end
    
    if A and SafeCheck(ReadySoon, A.Stormstrike) then Push(q, A.Stormstrike) end
    if A and SafeCheck(ReadySoon, A.LavaLash) then Push(q, A.LavaLash) end
    if A and SafeCheck(ReadySoon, A.EarthShock) then Push(q, A.EarthShock) end
  end
  return q
end

-- tick
function TR:EngineTick_Shaman()
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
  if TR:ShouldUpdateSuggestions(q) then
    if TR.UI_Update then
      TR.UI_Update(q[1], q[2], q[3])
    elseif self.UI and self.UI.Update then
      self.UI:Update(q[1], q[2], q[3])
    end
  end
end

-- start/stop
function TR:StartEngine_Shaman()
  self:StopEngine_Shaman()
  self:EngineTick_Shaman()
  local AceTimer = LibStub and LibStub("AceTimer-3.0", true)
  if AceTimer and AceTimer.ScheduleRepeatingTimer then
    self._engineTimer_SH = AceTimer:ScheduleRepeatingTimer(function() _G.TacoRot:EngineTick_Shaman() end, 0.20)
  else
    local acc, f = 0, CreateFrame("Frame")
    f:SetScript("OnUpdate", function(_, e) acc=acc+(e or 0); if acc>=0.20 then acc=acc-0.20; _G.TacoRot:EngineTick_Shaman() end end)
    self._engineTimer_SH = f
  end
  self:Print("TacoRot Shaman engine active: " .. SpecName())
end
function TR:StopEngine_Shaman()
  local t = self._engineTimer_SH
  if not t then return end
  local AceTimer = LibStub and LibStub("AceTimer-3.0", true)
  if AceTimer and type(t)=="number" then AceTimer:CancelTimer(t,true) elseif type(t)=="table" and t.SetScript then t:SetScript("OnUpdate",nil); t:Hide() end
  self._engineTimer_SH = nil
end

do local _,c=UnitClass("player"); if c=="SHAMAN" then TR:StartEngine_Shaman() end end