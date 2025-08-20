-- engine_warlock.lua — TacoRot Warlock (3.3.5) - ENHANCED WITH PREDICTION

local TR = _G.TacoRot
if not TR then return end

local function ResolveIDS()
  local t
  t = _G.TacoRot_IDS_Warlock; if type(t)=="table" and (t.Ability or t.Rank) then return t end
  t = _G.TacoRot_IDS_WARLOCK; if type(t)=="table" and (t.Ability or t.Rank) then return t end
  t = _G.TacoRot_IDS; if type(t)=="table" and (t.Ability or t.Rank) then return t end
  return nil
end
local IDS = ResolveIDS() or {}; local A = IDS.Ability
local SAFE = 686 -- Shadow Bolt

local function PrimaryTab() local n=(GetNumTalentTabs and GetNumTalentTabs()) or 3; local b,p=1,-1; for i=1,n do local _,_,pt=GetTalentTabInfo(i); pt=pt or 0; if pt>p then b,p=i,pt end end return b end
local function SpecName() local tab=PrimaryTab(); if tab==1 then return "Affliction" elseif tab==2 then return "Demonology" else return "Destruction" end end

local TOKEN = "WARLOCK"
local function Pad() local p=TR and TR.db and TR.db.profile and TR.db.profile.pad; local v=p and p[TOKEN]; if not v then return {enabled=true,gcd=1.6} end; if v.enabled==nil then v.enabled=true end; v.gcd=v.gcd or 1.6; return v end
local function BuffCfg() local p=TR and TR.db and TR.db.profile and TR.db.profile.buff; return (p and p[TOKEN]) or {enabled=true} end
local function PetCfg() local p=TR and TR.db and TR.db.profile and TR.db.profile.pet; return (p and p[TOKEN]) or {enabled=true} end

-- ================= Enhanced Helper Functions =================

local function Known(id) return id and (IsPlayerSpell and IsPlayerSpell(id) or (IsSpellKnown and IsSpellKnown(id))) end

-- ORIGINAL ReadyNow/ReadySoon for fallback
local function ReadyNow(id)
  if not Known(id) then return false end
  local s,d,en = GetSpellCooldown(id)
  if en == 0 then return false end
  return (not s or s==0 or d==0)
end

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

-- ENHANCED prediction functions
local function GetCurrentGameState()
    return TR.CaptureGameState and TR:CaptureGameState() or {}
end

local function PredictiveReadySoon(id, futureState, timeOffset)
    if TR.PredictiveReadySoon then
        return TR.PredictiveReadySoon(id, futureState, timeOffset)
    else
        return ReadySoon(id) -- Fallback
    end
end

local function StateHasDebuffID(state, debuffId)
    if TR.StateHasDebuffID then
        return TR:StateHasDebuffID(state, debuffId)
    else
        -- Fallback to current checking
        return DebuffUpID("target", debuffId)
    end
end

-- Original helper functions (preserved)
local function DebuffUpID(u, id) if not id then return false end local wanted=GetSpellInfo(id) for i=1,40 do local name,_,_,_,_,_,_,caster,_,_,sid=UnitDebuff(u,i); if not name then break end if sid==id or (name==wanted and caster=="player") then return true end end return false end
local function BuffUpID(u, id) if not id then return false end local wanted=GetSpellInfo(id); if not wanted then return false end for i=1,40 do local name,_,_,_,_,_,_,_,_,_,sid=UnitBuff(u,i); if not name then break end if sid==id or name==wanted then return true end end return false end
local function HaveTarget() return UnitExists("target") and not UnitIsDead("target") end
local function pad3(q, fb) q[1]=q[1] or fb; q[2]=q[2] or q[1]; q[3]=q[3] or q[2]; return q end
local function Push(q,id) if id then q[#q+1]=id end end

-- Fallback safe
local function Fallback()
  return SAFE
end

-- ================= Enhanced Spell Prediction =================

-- Warlock-specific spell prediction logic
function TR:PredictNextSpell_Warlock(state, queue)
    local A = (self.IDS and self.IDS.Ability) or {}
    if not A then return nil end
    
    local tree = PrimaryTab()
    
    -- Priority 1: Essential DoTs if missing or expiring soon
    if A.Corruption and not StateHasDebuffID(state, A.Corruption) and PredictiveReadySoon(A.Corruption, state) then
        return A.Corruption
    end
    
    if A.CurseOfAgony and not StateHasDebuffID(state, A.CurseOfAgony) and PredictiveReadySoon(A.CurseOfAgony, state) then
        return A.CurseOfAgony
    end
    
    -- Affliction-specific
    if tree == 1 then
        if A.UnstableAffliction and not StateHasDebuffID(state, A.UnstableAffliction) and PredictiveReadySoon(A.UnstableAffliction, state) then
            return A.UnstableAffliction
        end
        if A.Haunt and not StateHasDebuffID(state, A.Haunt) and PredictiveReadySoon(A.Haunt, state) then
            return A.Haunt
        end
    end
    
    -- Destruction-specific  
    if tree == 3 then
        if A.Immolate and not StateHasDebuffID(state, A.Immolate) and PredictiveReadySoon(A.Immolate, state) then
            return A.Immolate
        end
        if A.Conflagrate and StateHasDebuffID(state, A.Immolate) and PredictiveReadySoon(A.Conflagrate, state) then
            return A.Conflagrate
        end
        if A.ChaosBolt and PredictiveReadySoon(A.ChaosBolt, state) then
            return A.ChaosBolt
        end
    end
    
    -- Filler spells
    if A.ShadowBolt and PredictiveReadySoon(A.ShadowBolt, state) then
        return A.ShadowBolt
    end
    
    if A.Incinerate and PredictiveReadySoon(A.Incinerate, state) then
        return A.Incinerate
    end
    
    return nil
end

-- ================= OOC Buff Maintenance =================

local function ArmorID()
  if A and A.DemonArmor then return A.DemonArmor end
  local da = 47793; if Known(da) then return da end
  return 706
end

local function BuildBuffQueue()
  local cfg = BuffCfg(); if not (cfg.enabled ~= false) then return end
  local q = {}
  local state = GetCurrentGameState()
  
  if (cfg.armor ~= false) then
    local armorId = ArmorID()
    if armorId and not BuffUpID("player", armorId) and PredictiveReadySoon(armorId, state) then 
      Push(q, armorId) 
    end
  end
  
  -- Soul Link for Demonology
  local tree = PrimaryTab()
  if tree == 2 and A and A.SoulLink and (cfg.soulLink ~= false) then
    if not BuffUpID("player", A.SoulLink) and PredictiveReadySoon(A.SoulLink, state) then 
      Push(q, A.SoulLink) 
    end
  end
  
  -- Fel Armor for high-level warlocks
  if (cfg.felArmor ~= false) then
    local fa = A and A.FelArmor
    if fa and Known(fa) and not BuffUpID("player", fa) and PredictiveReadySoon(fa, state) then
      Push(q, fa)
    end
  end
  
  -- Demon Skin for low levels
  if (cfg.demonSkin ~= false) then
    local ds = A and A.DemonSkin
    if ds and not BuffUpID("player", ds) and PredictiveReadySoon(ds, state) then
      Push(q, ds)
    end
  end
  
  return q
end

-- ================= Pet Management =================

local function KnownFirst(...)
  for i=1, select("#", ...) do local id = select(i, ...); if id and Known(id) then return id end end
end

local function BestDemon()
  local felguard = (A and A.SummonFelguard) or 30146
  local felhunter = (A and A.SummonFelhunter) or 691  
  local succubus = (A and A.SummonSuccubus) or 712
  local voidwalker = (A and A.SummonVoidwalker) or 697
  local imp = (A and A.SummonImp) or 688
  
  -- Prefer based on spec
  local tree = PrimaryTab()
  if tree == 2 then -- Demonology
    return KnownFirst(felguard, felhunter, voidwalker, imp)
  elseif tree == 3 then -- Destruction
    return KnownFirst(imp, succubus, felhunter, voidwalker)
  else -- Affliction
    return KnownFirst(felhunter, voidwalker, imp, succubus)
  end
end

local function HasPet() return UnitExists("pet") and not UnitIsDead("pet") end

local function BuildPetQueue()
  local cfg = PetCfg(); if not (cfg.enabled ~= false and (cfg.summon ~= false)) then return end
  local q = {}
  local state = GetCurrentGameState()
  
  if not HasPet() then
    local demon = BestDemon()
    if demon and PredictiveReadySoon(demon, state) then 
      Push(q, demon) 
    end
  end
  return q
end

-- ================= Enhanced DPS Priorities =================

local function BuildPredictiveQueue_Warlock(originalQueue, state)
    if TR.BuildPredictiveQueue then
        return TR:BuildPredictiveQueue(originalQueue, 6) -- Look 6 spells ahead
    else
        return originalQueue -- Fallback to original
    end
end

local function BuildQueue()
  local q = {}
  local state = GetCurrentGameState()
  local tree = PrimaryTab()
  
  -- Use enhanced prediction functions
  local useEnhanced = TR.db and TR.db.profile and TR.db.profile.prediction and TR.db.profile.prediction.enabled
  local ReadyFunc = useEnhanced and PredictiveReadySoon or ReadySoon
  local HasDebuffFunc = useEnhanced and StateHasDebuffID or 
    function(state, id) return DebuffUpID("target", id) end

  -- Core DoT priority
  if A.Corruption and not HasDebuffFunc(state, A.Corruption) and ReadyFunc(A.Corruption, state) then 
    Push(q, A.Corruption) 
  end
  
  if A.CurseOfAgony and not HasDebuffFunc(state, A.CurseOfAgony) and ReadyFunc(A.CurseOfAgony, state) then 
    Push(q, A.CurseOfAgony) 
  end

  -- Spec-specific priorities
  if tree == 1 then -- Affliction
    if A.UnstableAffliction and not HasDebuffFunc(state, A.UnstableAffliction) and ReadyFunc(A.UnstableAffliction, state) then
      Push(q, A.UnstableAffliction)
    end
    if A.Haunt and not HasDebuffFunc(state, A.Haunt) and ReadyFunc(A.Haunt, state) then
      Push(q, A.Haunt)
    end
    if A.DrainSoul and ReadyFunc(A.DrainSoul, state) then
      -- Use drain soul at low target health
      if HaveTarget() and (UnitHealth("target") / UnitHealthMax("target")) <= 0.25 then
        Push(q, A.DrainSoul)
      end
    end
  elseif tree == 2 then -- Demonology  
    if A.Metamorphosis and ReadyFunc(A.Metamorphosis, state) then
      Push(q, A.Metamorphosis)
    end
    if A.SoulFire and ReadyFunc(A.SoulFire, state) then
      Push(q, A.SoulFire)
    end
  else -- Destruction
    if A.Immolate and not HasDebuffFunc(state, A.Immolate) and ReadyFunc(A.Immolate, state) then 
      Push(q, A.Immolate) 
    end
    if A.Conflagrate and HasDebuffFunc(state, A.Immolate) and ReadyFunc(A.Conflagrate, state) then 
      Push(q, A.Conflagrate) 
    end
    if A.ChaosBolt and ReadyFunc(A.ChaosBolt, state) then
      Push(q, A.ChaosBolt)
    end
    if A.Incinerate and ReadyFunc(A.Incinerate, state) then
      Push(q, A.Incinerate)
    end
  end

  -- Filler spells
  if A.ShadowBolt and ReadyFunc(A.ShadowBolt, state) then 
    Push(q, A.ShadowBolt) 
  end

  -- Life Tap for mana management
  if A.LifeTap and ReadyFunc(A.LifeTap, state) then
    local manaPercent = UnitPower("player", 0) / UnitPowerMax("player", 0)
    if manaPercent < 0.3 then -- Low mana
      Push(q, A.LifeTap)
    end
  end
  
  -- Use enhanced prediction if available
  if useEnhanced then
    return BuildPredictiveQueue_Warlock(q, state)
  else
    return pad3(q, Fallback())
  end
end

-- ================= Enhanced Engine Tick =================

function TR:EngineTick_Warlock()
  IDS = ResolveIDS() or IDS
  A = (IDS and IDS.Ability) or A
  if IDS and IDS.UpdateRanks then pcall(IDS.UpdateRanks, IDS) end

  local q
  if not A or not next(A) then
    q = {SAFE,SAFE,SAFE}
  elseif not UnitAffectingCombat("player") then
    q = BuildPetQueue() or BuildBuffQueue() or {}
    if not q[1] then
      if HaveTarget() then 
        q = BuildQueue() 
      else 
        q = {SAFE,SAFE,SAFE} 
      end
    end
  else
    q = BuildQueue()
  end

  q = pad3(q or {}, SAFE)
  self._lastMainSpell = q[1]
  
  -- Enhanced UI update with prediction info
  if self.UI and self.UI.Update then 
    self.UI:Update(q[1], q[2], q[3]) 
  end
  
  -- Debug output if enabled
  if self.db and self.db.profile.prediction and self.db.profile.prediction.debugMode then
    if q[1] ~= self._lastDebugSpell then
      local spellName = GetSpellInfo(q[1]) or "Unknown"
      self:DebugPrediction("Next: " .. spellName .. " (" .. (q[1] or "nil") .. ")")
      self._lastDebugSpell = q[1]
    end
  end
end

-- ================= Enhanced Start/Stop Functions =================

function TR:StartEngine_Warlock()
  self:StopEngine_Warlock()
  self:EngineTick_Warlock()
  
  local useEnhanced = self.db and self.db.profile and self.db.profile.prediction and self.db.profile.prediction.enabled
  local AceTimer = LibStub and LibStub("AceTimer-3.0", true)
  
  if AceTimer and AceTimer.ScheduleRepeatingTimer then
    if useEnhanced then
      -- Dynamic timer system
      local function DynamicTick()
        local interval = self:GetOptimalUpdateInterval and self:GetOptimalUpdateInterval() or 0.1
        self:EngineTick_Warlock()
        
        if self._engineTimer_WL then
          self._engineTimer_WL = AceTimer:ScheduleTimer(DynamicTick, interval)
        end
      end
      self._engineTimer_WL = AceTimer:ScheduleTimer(DynamicTick, 0.1)
    else
      -- Standard fixed timer
      self._engineTimer_WL = AceTimer:ScheduleRepeatingTimer(function() _G.TacoRot:EngineTick_Warlock() end, 0.20)
    end
  else
    -- Fallback frame-based timer
    local acc, f = 0, CreateFrame("Frame")
    f:SetScript("OnUpdate", function(_, elapsed)
      acc = acc + (elapsed or 0)
      local targetInterval = useEnhanced and (self:GetOptimalUpdateInterval and self:GetOptimalUpdateInterval() or 0.1) or 0.20
      
      if acc >= targetInterval then
        acc = acc - targetInterval
        _G.TacoRot:EngineTick_Warlock()
      end
    end)
    self._engineTimer_WL = f
  end
  
  local engineType = useEnhanced and " enhanced engine" or " engine"
  self:Print("TacoRot Warlock" .. engineType .. " active: " .. SpecName())
end

function TR:StopEngine_Warlock()
  local t = self._engineTimer_WL
  if not t then return end
  local AceTimer = LibStub and LibStub("AceTimer-3.0", true)
  if AceTimer and type(t)=="number" then 
    AceTimer:CancelTimer(t,true) 
  elseif type(t)=="table" and t.SetScript then 
    t:SetScript("OnUpdate",nil); t:Hide() 
  end
  self._engineTimer_WL = nil
end

-- Auto-start for Warlock class
do 
  local _, c = UnitClass("player")
  if c == "WARLOCK" then 
    TR:StartEngine_Warlock() 
  end 
end
