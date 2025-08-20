-- engine_warlock.lua — TacoRot Warlock (3.3.5)
-- Uses unified prediction helpers: dynamic GCD, latency and aura caching.

local TR = _G.TacoRot
if not TR then return end
local P = TR.Predict

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
local TOKEN = "WARLOCK"

-- Spec name
local function PrimaryTab() local n=(GetNumTalentTabs and GetNumTalentTabs()) or 3; local b,p=1,-1; for i=1,n do local _,_,pt=GetTalentTabInfo(i); pt=pt or 0; if pt>p then b,p=i,pt end end return b end
local function SpecName() local tab=PrimaryTab(); return (tab==1 and "Affliction") or (tab==2 and "Demonology") or "Destruction" end

-- Config
local function BuffCfg() local p=TR and TR.db and TR.db.profile and TR.db.profile.buff; return (p and p[TOKEN]) or {enabled=true} end
local function PetCfg() local p=TR and TR.db and TR.db.profile and TR.db.profile.pet; return (p and p[TOKEN]) or {enabled=true} end

-- Helpers
local function pad3(q, fb) q[1]=q[1] or fb; q[2]=q[2] or q[1]; q[3]=q[3] or q[2]; return q end
local function Push(q,id) if id then q[#q+1]=id end end
local function HaveTarget() return P.HaveTarget() end

-- OOC Buffs
local function FelArmorID() if A and A.FelArmor then return A.FelArmor end local r=47893; if P.Known(r) then return r end end
local function DemonSkinID() if A and A.DemonSkin then return A.DemonSkin end local r=687; if P.Known(r) then return r end end

local function BuildBuffQueue()
  local cfg = BuffCfg(); if not (cfg.enabled ~= false) then return end
  local q = {}
  local fa = FelArmorID()
  local ds = DemonSkinID()
  local hasArmorBuff = (fa and P.BuffUp("player", fa)) or (ds and P.BuffUp("player", ds))
  if not hasArmorBuff then
    if fa and P.ReadySoon(fa, TOKEN) and (cfg.felArmor ~= false) then Push(q, fa)
    elseif ds and P.ReadySoon(ds, TOKEN) and (cfg.demonSkin ~= false) then Push(q, ds) end
  end
  return q
end

-- Pets
local function KnownFirst(...) for i=1, select("#", ...) do local id = select(i, ...); if id and P.Known(id) then return id end end end
local function BestDemon()
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
    if demon and P.ReadySoon(demon, TOKEN) then Push(q, demon) end
  end
  return q
end

-- DPS Priorities
local function BuildQueue()
  P.ClearCache()
  local q = {}
  local tree = PrimaryTab()
  local thresh = TR.db and TR.db.profile.dotThreshold or 3

  if P.AoEActive() and A.SeedOfCorruption and P.ReadySoon(A.SeedOfCorruption, TOKEN) then Push(q, A.SeedOfCorruption) end

  if A.Corruption and P.ReadySoon(A.Corruption, TOKEN) and P.ShouldRefreshDebuff("target", A.Corruption, thresh) then Push(q, A.Corruption) end
  if A.CurseOfAgony and P.ReadySoon(A.CurseOfAgony, TOKEN) and P.ShouldRefreshDebuff("target", A.CurseOfAgony, thresh) then Push(q, A.CurseOfAgony) end
  if A.UnstableAffliction and not P.PlayerMoving() and P.ReadySoon(A.UnstableAffliction, TOKEN) and P.ShouldRefreshDebuff("target", A.UnstableAffliction, thresh) then Push(q, A.UnstableAffliction) end

  if tree == 3 then
    if A.Immolate and not P.PlayerMoving() and P.ReadySoon(A.Immolate, TOKEN) and P.ShouldRefreshDebuff("target", A.Immolate, thresh) then Push(q, A.Immolate) end
    if A.Conflagrate and P.ReadySoon(A.Conflagrate, TOKEN) and P.DebuffUp("target", A.Immolate) then Push(q, A.Conflagrate) end
  end

  if not P.PlayerMoving() and A.ShadowBolt and P.ReadySoon(A.ShadowBolt, TOKEN) then Push(q, A.ShadowBolt) end

  if UnitPower("player", 0) / UnitPowerMax("player", 0) < 0.2 and A.LifeTap and P.ReadySoon(A.LifeTap, TOKEN) then
    Push(q, A.LifeTap)
  end

  return q
end

function TR:EngineTick_Warlock()
  IDS = ResolveIDS() or IDS
  A = (IDS and IDS.Ability) or A
  if IDS and IDS.UpdateRanks then pcall(IDS.UpdateRanks, IDS) end

  local q
  if not A or not next(A) then
    q = {SAFE,SAFE,SAFE}
  elseif not UnitAffectingCombat("player") then
    local petQ = BuildPetQueue()
    local buffQ = BuildBuffQueue()
    if petQ and petQ[1] then
      q = petQ
    elseif buffQ and buffQ[1] then
      q = buffQ
    elseif HaveTarget() then
      q = BuildQueue()
    else
      q = {SAFE,SAFE,SAFE}
    end
  else
    q = BuildQueue()
  end

  q = pad3(q or {}, SAFE)
  self._lastMainSpell = q[1]

  if TR.UI_Update then
    TR.UI_Update(q[1], q[2], q[3])
  elseif self.UI and self.UI.Update then
    self.UI:Update(q[1], q[2], q[3])
  end
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
