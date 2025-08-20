-- engine_druid.lua — TacoRot Druid (3.3.5)
-- Adds Buff padding (OOC) and Pets maintenance (where applicable) for new-player accessibility.

local TR = _G.TacoRot
if not TR then return end

-- Resolve IDS table
local function ResolveIDS()
  local t
  t = _G.TacoRot_IDS_Druid;       if type(t)=="table" and (t.Ability or t.Rank) then return t end
  t = _G.TacoRot_IDS_DRUID;       if type(t)=="table" and (t.Ability or t.Rank) then return t end
  if type(_G.TacoRot_IDS)=="table" then
    t = _G.TacoRot_IDS["DRUID"]; if type(t)=="table" and (t.Ability or t.Rank) then return t end
    t = _G.TacoRot_IDS["Druid"]; if type(t)=="table" and (t.Ability or t.Rank) then return t end
    if _G.TacoRot_IDS.Ability then return _G.TacoRot_IDS end
  end
  return nil
end

local IDS = ResolveIDS() or {}; local A = IDS.Ability
local SAFE = 5176

-- Spec name
local function PrimaryTab() local n=(GetNumTalentTabs and GetNumTalentTabs()) or 3; local b,p=1,-1; for i=1,n do local _,_,pt=GetTalentTabInfo(i); pt=pt or 0; if pt>p then b,p=i,pt end end return b end
local function SpecName() local tab=PrimaryTab(); return (tab==1 and "Balance") or (tab==2 and "Feral") or "Restoration" end

-- Config
local TOKEN = "DRUID"
local function Pad() local p=TR and TR.db and TR.db.profile and TR.db.profile.pad; local v=p and p[TOKEN]; if not v then return {enabled=true,gcd=1.6} end; if v.enabled==nil then v.enabled=true end; v.gcd=v.gcd or 1.6; return v end
local function BuffCfg() local p=TR and TR.db and TR.db.profile and TR.db.profile.buff; return (p and p[TOKEN]) or {enabled=true} end
local function PetCfg() local p=TR and TR.db and TR.db.profile and TR.db.profile.pet; return (p and p[TOKEN]) or {enabled=true} end

-- Helpers
local function Known(id)
  return id and IsSpellKnown and IsSpellKnown(id)
end
local function ReadyNow(id) if not Known(id) then return false end local s,d,en = GetSpellCooldown(id); if en==0 then return false end return (not s or s==0 or d==0) end
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

-- Form detection
local function InCatForm() return GetShapeshiftForm() == 3 end
local function InBearForm() return GetShapeshiftForm() == 1 end
local function InMoonkinForm() return GetShapeshiftForm() == 5 end

-- Auto Attack helper
local function AutoAttackActive()
  return IsAutoRepeatSpell and (IsAutoRepeatSpell("Attack") == 1 or IsAutoRepeatSpell("Attack") == true)
end

-- OOC Buffs

local function MarkID()
  if A and A.MarkOfTheWild then return A.MarkOfTheWild end
  local r = 48469; if Known(r) then return r end -- MotW (Wrath rank)
  return 1126
end
local function ThornsID()
  if A and A.Thorns then return A.Thorns end
  local r = 53307; if Known(r) then return r end -- Thorns (Wrath rank)
  return 467
end
local function BuildBuffQueue()
  local cfg = BuffCfg(); if not (cfg.enabled ~= false) then return end
  local q = {}
  if (cfg.mark ~= false) then local m=MarkID(); if m and not BuffUpID("player", m) and ReadySoon(m) then Push(q, m) end end
  if (cfg.thorns ~= false) then local t=ThornsID(); if t and not BuffUpID("player", t) and ReadySoon(t) then Push(q, t) end end
  return q
end

-- Pets

local function BuildPetQueue() return nil end

-- DPS Priorities (existing style, trimmed)

local function BuildQueue()
  local q = {}
  local spec = PrimaryTab()
  
  if InCatForm() then
    -- Cat form - melee DPS
    if InMelee() and not AutoAttackActive() then
      table.insert(q, 1, 6603) -- Attack spell ID
    end
    if A and ReadySoon(A.MangleCat) then Push(q, A.MangleCat) end
    if A and ReadySoon(A.Shred) then Push(q, A.Shred) end
    if A and A.Rake and not DebuffUpID("target", A.Rake) and ReadySoon(A.Rake) then Push(q, A.Rake) end
    if A and ReadySoon(A.FerociousBite) then Push(q, A.FerociousBite) end
    
  elseif InBearForm() then
    -- Bear form - tank/melee
    if InMelee() and not AutoAttackActive() then
      table.insert(q, 1, 6603) -- Attack spell ID
    end
    if A and ReadySoon(A.MangleBear) then Push(q, A.MangleBear) end
    if A and ReadySoon(A.Maul) then Push(q, A.Maul) end
    
  else
    -- Caster form - Balance spells
    if A and A.InsectSwarm and not DebuffUpID("target", A.InsectSwarm) and ReadySoon(A.InsectSwarm) then Push(q, A.InsectSwarm) end
    if A and A.Moonfire and not DebuffUpID("target", A.Moonfire) and ReadySoon(A.Moonfire) then Push(q, A.Moonfire) end
    if A and ReadySoon(A.Wrath) then Push(q, A.Wrath) end
    
    -- If no target and low level, suggest cat form for melee
    if not HaveTarget() and UnitLevel("player") < 10 and A and A.CatForm and ReadySoon(A.CatForm) then
      Push(q, A.CatForm)
    end
  end
  
  return q
end

function TR:EngineTick_Druid()
  IDS = ResolveIDS() or IDS
  A = (IDS and IDS.Ability) or A
  if IDS and IDS.UpdateRanks then pcall(IDS.UpdateRanks, IDS) end

  local q = {}
  if not A or not next(A) then
    q = {SAFE,SAFE,SAFE}
  elseif not UnitAffectingCombat("player") then
    q = BuildPetQueue() or BuildBuffQueue() or {} -- prefer getting a pet up first
    if not q[1] then
      if HaveTarget() then q = BuildQueue() else q = {SAFE,SAFE,SAFE} end
    end
  else
    q = BuildQueue()
  end

  q = pad3(q or {}, SAFE)
  self._lastMainSpell = q[1]
  
  -- Fix UI update call
  if TR.UI_Update then
    TR.UI_Update(q[1], q[2], q[3])
  elseif self.UI and self.UI.Update then 
    self.UI:Update(q[1], q[2], q[3]) 
  end
end

function TR:StartEngine_Druid()
  self:StopEngine_Druid()
  self:EngineTick_Druid()
  local AceTimer = LibStub and LibStub("AceTimer-3.0", true)
  if AceTimer and AceTimer.ScheduleRepeatingTimer then
    self._engineTimer_DR = AceTimer:ScheduleRepeatingTimer(function() _G.TacoRot:EngineTick_Druid() end, 0.20)
  else
    local acc, f = 0, CreateFrame("Frame")
    f:SetScript("OnUpdate", function(_, e) acc=acc+(e or 0); if acc>=0.20 then acc=acc-0.20; _G.TacoRot:EngineTick_Druid() end end)
    self._engineTimer_DR = f
  end
  self:Print("TacoRot Druid engine active: " .. SpecName())
end

function TR:StopEngine_Druid()
  local t = self._engineTimer_DR
  if not t then return end
  local AceTimer = LibStub and LibStub("AceTimer-3.0", true)
  if AceTimer and type(t)=="number" then AceTimer:CancelTimer(t,true) elseif type(t)=="table" and t.SetScript then t:SetScript("OnUpdate",nil); t:Hide() end
  self._engineTimer_DR = nil
end

do local _,c=UnitClass("player"); if c=="DRUID" then TR:StartEngine_Druid() end end