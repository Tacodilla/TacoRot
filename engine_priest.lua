-- engine_priest.lua — TacoRot Priest (3.3.5)
-- Adds out-of-combat buff "padding" (configurable) + existing low-level padding.
-- OOC buffs are suggested only if enabled in options and missing.

local TR = _G.TacoRot
if not TR then return end

local function ResolveIDS()
  local t
  t = _G.TacoRot_IDS_Priest;       if type(t)=="table" and (t.Ability or t.Rank) then return t end
  t = _G.TacoRot_IDS_PRIEST;       if type(t)=="table" and (t.Ability or t.Rank) then return t end
  if type(_G.TacoRot_IDS)=="table" then
    t = _G.TacoRot_IDS["PRIEST"]; if type(t)=="table" and (t.Ability or t.Rank) then return t end
    t = _G.TacoRot_IDS["Priest"]; if type(t)=="table" and (t.Ability or t.Rank) then return t end
    if _G.TacoRot_IDS.Ability then return _G.TacoRot_IDS end
  end
  return nil
end

local IDS = ResolveIDS() or {}; local A = IDS.Ability
local SAFE = 585

-- talent/spec
local function PrimaryTab()
  local n = (GetNumTalentTabs and GetNumTalentTabs()) or 3
  local best, pts = 1, -1
  for i=1,n do local _,_,p = GetTalentTabInfo(i); p=p or 0; if p>pts then best,pts=i,p end end
  return best
end
local function SpecName()
  local tab = PrimaryTab()
  return "Shadow"
end

-- padding + buff config
local TOKEN = "PRIEST"
local function Pad() local p=TR and TR.db and TR.db.profile and TR.db.profile.pad; local v=p and p[TOKEN]; if not v then return {enabled=true,gcd=1.6} end; if v.enabled==nil then v.enabled=true end; v.gcd=v.gcd or 1.6; return v end
local function BuffCfg() local p=TR and TR.db and TR.db.profile and TR.db.profile.buff; return (p and p[TOKEN]) or {enabled=true} end

-- helpers
local function Known(id) return id and (IsPlayerSpell and IsPlayerSpell(id) or (IsSpellKnown and IsSpellKnown(id))) end
local function ReadyNow(id) if not Known(id) then return false end local s,d,en=GetSpellCooldown(id); if en==0 then return false end return (not s or s==0 or d==0) end
local function ReadySoon(id) local pad=Pad(); if not pad.enabled then return ReadyNow(id) end if not Known(id) then return false end local s,d,en=GetSpellCooldown(id); if en==0 then return false end if (not s or s==0 or d==0) then return true end return (s+d-GetTime())<= (pad.gcd or 1.6) end
local function DebuffUpID(u, id) if not id then return false end local wanted=GetSpellInfo(id) for i=1,40 do local name,_,_,_,_,_,_,caster,_,_,sid=UnitDebuff(u,i); if not name then break end if sid==id or (name==wanted and caster=="player") then return true end end return false end
local function BuffUpID(u, id) if not id then return false end local wanted=GetSpellInfo(id) for i=1,40 do local name=UnitBuff(u,i); if not name then break end if name==wanted then return true end end return false end
local function HaveTarget() return UnitExists("target") and not UnitIsDead("target") end
local function pad3(q, fb) q[1]=q[1] or fb; q[2]=q[2] or q[1]; q[3]=q[3] or q[2]; return q end
local function Push(q,id) if id then q[#q+1]=id end end

-- Fallback safe
local function Fallback()
  return SAFE
end

-- OOC Buff maintenance (per class)

local function IFID()
  if A and A.InnerFire then return A.InnerFire end
  local r = 48168; if Known(r) then return r end
  return 588
end
local function BuildBuffQueue()
  local cfg = BuffCfg(); if not (cfg.enabled ~= false and (cfg.innerFire ~= false)) then return end
  local q = {}
  local ifi = IFID()
  if ifi and not BuffUpID("player", ifi) and ReadySoon(ifi) then Push(q, ifi) end
  return q
end


-- core priorities

local function BuildQueue()
  local q = {}
  if A.VampiricTouch and not DebuffUpID("target", A.VampiricTouch) and ReadySoon(A.VampiricTouch) then Push(q, A.VampiricTouch) end
  if A.DevouringPlague and not DebuffUpID("target", A.DevouringPlague) and ReadySoon(A.DevouringPlague) then Push(q, A.DevouringPlague) end
  if A.ShadowWordPain and not DebuffUpID("target", A.ShadowWordPain) and ReadySoon(A.ShadowWordPain) then Push(q, A.ShadowWordPain) end
  if ReadySoon(A.MindBlast) then Push(q, A.MindBlast) end
  if ReadySoon(A.MindFlay) then Push(q, A.MindFlay) end
  if ReadySoon(A.ShadowWordDeath) then Push(q, A.ShadowWordDeath) end
  return q
end


-- tick
function TR:EngineTick_Priest()
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
  if self.UI and self.UI.Update then self.UI:Update(q[1], q[2], q[3]) end
end

-- start/stop
function TR:StartEngine_Priest()
  self:StopEngine_Priest()
  self:EngineTick_Priest()
  local AceTimer = LibStub and LibStub("AceTimer-3.0", true)
  if AceTimer and AceTimer.ScheduleRepeatingTimer then
    self._engineTimer_PR = AceTimer:ScheduleRepeatingTimer(function() _G.TacoRot:EngineTick_Priest() end, 0.20)
  else
    local acc, f = 0, CreateFrame("Frame")
    f:SetScript("OnUpdate", function(_, e) acc=acc+(e or 0); if acc>=0.20 then acc=acc-0.20; _G.TacoRot:EngineTick_Priest() end end)
    self._engineTimer_PR = f
  end
  self:Print("TacoRot Priest engine active: " .. SpecName())
end
function TR:StopEngine_Priest()
  local t = self._engineTimer_PR
  if not t then return end
  local AceTimer = LibStub and LibStub("AceTimer-3.0", true)
  if AceTimer and type(t)=="number" then AceTimer:CancelTimer(t,true) elseif type(t)=="table" and t.SetScript then t:SetScript("OnUpdate",nil); t:Hide() end
  self._engineTimer_PR = nil
end

do local _,c=UnitClass("player"); if c=="PRIEST" then TR:StartEngine_Priest() end end
