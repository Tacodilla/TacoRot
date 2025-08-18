-- engine_warlock.lua — TacoRot Warlock (3.3.5)
-- Adds Buff padding (OOC) and Pets maintenance (where applicable) for new-player accessibility.

local TR = _G.TacoRot
if not TR then return end

-- Resolve IDS table
local function ResolveIDS()
  local t
  t = _G.TacoRot_IDS_Warlock;       if type(t)=="table" and (t.Ability or t.Rank) then return t end
  t = _G.TacoRot_IDS_WARLOCK;       if type(t)=="table" and (t.Ability or t.Rank) then return t end
  if type(_G.TacoRot_IDS)=="table" then
    t = _G.TacoRot_IDS["WARLOCK"]; if type(t)=="table" and (t.Ability or t.Rank) then return t end
    t = _G.TacoRot_IDS["Warlock"]; if type(t)=="table" and (t.Ability or t.Rank) then return t end
    if _G.TacoRot_IDS.Ability then return _G.TacoRot_IDS end
  end
  return nil
end

local IDS = ResolveIDS() or {}; local A = IDS.Ability
local SAFE = 686

-- Spec name
local function PrimaryTab() local n=(GetNumTalentTabs and GetNumTalentTabs()) or 3; local b,p=1,-1; for i=1,n do local _,_,pt=GetTalentTabInfo(i); pt=pt or 0; if pt>p then b,p=i,pt end end return b end
local function SpecName() local tab=PrimaryTab(); return (tab==1 and "Affliction") or (tab==2 and "Demonology") or "Destruction" end

-- Config
local TOKEN = "WARLOCK"
local function Pad() local p=TR and TR.db and TR.db.profile and TR.db.profile.pad; local v=p and p[TOKEN]; if not v then return {enabled=true,gcd=1.6} end; if v.enabled==nil then v.enabled=true end; v.gcd=v.gcd or 1.6; return v end
local function BuffCfg() local p=TR and TR.db and TR.db.profile and TR.db.profile.buff; return (p and p[TOKEN]) or {enabled=true} end
local function PetCfg() local p=TR and TR.db and TR.db.profile and TR.db.profile.pet; return (p and p[TOKEN]) or {enabled=true} end

-- Helpers
local function Known(id) return id and (IsPlayerSpell and IsPlayerSpell(id) or (IsSpellKnown and IsSpellKnown(id))) end
local function ReadyNow(id) if not Known(id) then return false end local s,d,en = GetSpellCooldown(id); if en==0 then return false end return (not s or s==0 or d==0) end
local function ReadySoon(id) local pad=Pad(); if not pad.enabled then return ReadyNow(id) end if not Known(id) then return false end local s,d,en=GetSpellCooldown(id); if en==0 then return false end if (not s or s==0 or d==0) then return true end return (s+d-GetTime()) <= (pad.gcd or 1.6) end
local function DebuffUpID(u, id) if not id then return false end local wanted=GetSpellInfo(id) for i=1,40 do local name,_,_,_,_,_,_,caster,_,_,sid=UnitDebuff(u,i); if not name then break end if sid==id or (name==wanted and caster=="player") then return true end end return false end
local function BuffUpID(u, id) if not id then return false end local wanted=GetSpellInfo(id) for i=1,40 do local name=UnitBuff(u,i); if not name then break end if name==wanted then return true end end return false end
local function HaveTarget() return UnitExists("target") and not UnitIsDead("target") end
local function pad3(q, fb) q[1]=q[1] or fb; q[2]=q[2] or q[1]; q[3]=q[3] or q[2]; return q end
local function Push(q,id) if id then q[#q+1]=id end end

-- OOC Buffs

local function FelArmorID()
  if A and A.FelArmor then return A.FelArmor end
  local r = 47893; if Known(r) then return r end -- Fel Armor
  return nil
end
local function BuildBuffQueue()
  local cfg = BuffCfg(); if not (cfg.enabled ~= false and (cfg.felArmor ~= false)) then return end
  local q = {}
  local fa = FelArmorID()
  if fa and not BuffUpID("player", fa) and ReadySoon(fa) then Push(q, fa) end
  return q
end


-- Pets

local function KnownFirst(...)
  for i=1, select("#", ...) do local id = select(i, ...); if id and Known(id) then return id end end
end
local function BestDemon()
  -- Prefer Felguard > Felhunter > Voidwalker > Imp, unless IDs table says otherwise
  local felguard = (A and A.SummonFelguard) or 30146
  local felhunter = (A and A.SummonFelhunter) or 691
  local voidwalker = (A and A.SummonVoidwalker) or 697
  local imp = (A and A.SummonImp) or 688
  return KnownFirst(felguard, felhunter, voidwalker, imp)
end
local function HasPet() return UnitExists("pet") and not UnitIsDead("pet") end
local function BuildPetQueue()
  local cfg = PetCfg(); if not (cfg.enabled ~= false and (cfg.summon ~= false)) then return end
  local q = {}
  if not HasPet() then
    local demon = BestDemon()
    if demon and ReadySoon(demon) then Push(q, demon) end
  end
  return q
end


-- DPS Priorities (existing style, trimmed)

local function BuildQueue()
  local q = {}
  -- Generic: Corruption -> Curse/CoA -> Shadow Bolt filler (simple for leveling/new players)
  if A and A.Corruption and not DebuffUpID("target", A.Corruption) and ReadySoon(A.Corruption) then Push(q, A.Corruption) end
  if A and A.CurseOfAgony and not DebuffUpID("target", A.CurseOfAgony) and ReadySoon(A.CurseOfAgony) then Push(q, A.CurseOfAgony) end
  if A and ReadySoon(A.ShadowBolt) then Push(q, A.ShadowBolt) end
  return q
end


function TR:EngineTick_Warlock()
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
  if self.UI and self.UI.Update then self.UI:Update(q[1], q[2], q[3]) end
end

function TR:StartEngine_Warlock()
  self:StopEngine_Warlock()
  self:EngineTick_Warlock()
  local AceTimer = LibStub and LibStub("AceTimer-3.0", true)
  if AceTimer and AceTimer.ScheduleRepeatingTimer then
    self._engineTimer_WA = AceTimer:ScheduleRepeatingTimer(function() _G.TacoRot:EngineTick_Warlock() end, 0.20)
  else
    local acc, f = 0, CreateFrame("Frame")
    f:SetScript("OnUpdate", function(_, e) acc=acc+(e or 0); if acc>=0.20 then acc=acc-0.20; _G.TacoRot:EngineTick_Warlock() end end)
    self._engineTimer_WA = f
  end
  self:Print("TacoRot Warlock engine active: " .. SpecName())
end

function TR:StopEngine_Warlock()
  local t = self._engineTimer_WA
  if not t then return end
  local AceTimer = LibStub and LibStub("AceTimer-3.0", true)
  if AceTimer and type(t)=="number" then AceTimer:CancelTimer(t,true) elseif type(t)=="table" and t.SetScript then t:SetScript("OnUpdate",nil); t:Hide() end
  self._engineTimer_WA = nil
end

do local _,c=UnitClass("player"); if c=="WARLOCK" then TR:StartEngine_Warlock() end end
