-- engine_hunter.lua — TacoRot Hunter (3.3.5) - FIXED SYNTAX ERROR
-- Restore early-game padding: **Auto Shot → Raptor Strike** takes precedence OOC,
-- while still keeping pet maintenance. Hunter's Mark remains an OOC nicety.

local TR = _G.TacoRot
if not TR then return end

-- ===== IDS resolve =====
local function ResolveIDS()
  local t
  t = _G.TacoRot_IDS_Hunter;       if type(t)=="table" and (t.Ability or t.Rank) then return t end
  t = _G.TacoRot_IDS_HUNTER;       if type(t)=="table" and (t.Ability or t.Rank) then return t end
  if type(_G.TacoRot_IDS)=="table" then
    t = _G.TacoRot_IDS["HUNTER"]; if type(t)=="table" and (t.Ability or t.Rank) then return t end
    t = _G.TacoRot_IDS["Hunter"]; if type(t)=="table" and (t.Ability or t.Rank) then return t end
    if _G.TacoRot_IDS.Ability then return _G.TacoRot_IDS end
  end
  return nil
end

local IDS = ResolveIDS() or {}; local A = IDS.Ability
local SAFE = 3044 -- Arcane Shot icon as last-resort

-- ===== config =====
local TOKEN = "HUNTER"
local function Pad() local p=TR and TR.db and TR.db.profile and TR.db.profile.pad; local v=p and p[TOKEN]; if not v then return {enabled=true,gcd=1.6} end; if v.enabled==nil then v.enabled=true end; v.gcd=v.gcd or 1.6; return v end
local function PetCfg() local p=TR and TR.db and TR.db.profile and TR.db.profile.pet; return (p and p[TOKEN]) or {enabled=true} end

-- ===== helpers =====
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
local function BuffUpID(u, id) if not id then return false end local wanted=GetSpellInfo(id) for i=1,40 do local name=UnitBuff(u,i); if not name then break end if name==wanted then return true end end return false end
local function HaveTarget() return UnitExists("target") and not UnitIsDead("target") end
local function InMelee()  return CheckInteractDistance and CheckInteractDistance("target", 3) end
local function InRanged() return CheckInteractDistance and CheckInteractDistance("target", 4) end
local function pad3(q, fb) q[1]=q[1] or fb; q[2]=q[2] or q[1]; q[3]=q[3] or q[2]; return q end
local function Push(q,id) if id then q[#q+1]=id end end

local function AutoShotActive()
  local n = (A and A.AutoShot and GetSpellInfo(A.AutoShot)) or "Auto Shot"
  local ok = IsAutoRepeatSpell and IsAutoRepeatSpell(n)
  return ok == 1 or ok == true
end

-- ===== Pets (OOC) =====
local function HasPet() return UnitExists("pet") and not UnitIsDead("pet") end
local function CallPetID()
  if A and A.CallPet then return A.CallPet end
  local id = 883; if Known(id) then return id end
end
local function RevivePetID()
  if A and A.RevivePet then return A.RevivePet end
  local id = 982; if Known(id) then return id end
end
local function MendPetID()
  if A and A.MendPet then return A.MendPet end
  local id = 136; if Known(id) then return id end
end

local function BuildPetQueue()
  local cfg = PetCfg(); if not (cfg.enabled ~= false) then return end
  local q = {}
  if (not HasPet()) and (cfg.summon ~= false) then
    local call = CallPetID(); if call and ReadySoon(call) then Push(q, call); return q end
  end
  if UnitExists("pet") and UnitIsDead("pet") and (cfg.revive ~= false) then
    local revive = RevivePetID(); if revive and ReadySoon(revive) then Push(q, revive); return q end
  end
  if UnitExists("pet") and (cfg.mend ~= false) then
    local hp = UnitHealth("pet") or 0; local max = UnitHealthMax("pet") or 1
    if max > 0 and (hp/max) < 0.60 then local mend = MendPetID(); if mend and ReadySoon(mend) then Push(q, mend); return q end end
  end
  return q
end

-- ===== Priorities =====
local function Fallback()
  return (A and A.AutoShot) or (A and A.RaptorStrike) or SAFE
end

local function BuildQueue()
  IDS = ResolveIDS() or IDS
  A = (IDS and IDS.Ability) or A

  local q = {}

  if not HaveTarget() then
    -- No target: favor pet upkeep out of combat, otherwise fall back
    if not UnitAffectingCombat("player") then
      local pq = BuildPetQueue(); if pq and pq[1] then return pq end
    end
    return { Fallback(), Fallback(), Fallback() }
  end
  
  if HaveTarget() then
    -- Out of combat buffs/setup
    if not UnitAffectingCombat("player") then
      if A and ReadySoon(A.HuntersMark) and not DebuffUpID("target", A.HuntersMark) then 
        Push(q, A.HuntersMark) 
      end
    end

    -- High priority abilities
    if A and A.KillShot and ReadySoon(A.KillShot) then 
      Push(q, A.KillShot) 
    end

    if InMelee() then
      -- Melee range abilities
      if A and ReadySoon(A.RaptorStrike) then 
        table.insert(q, 1, A.RaptorStrike) 
      end
      if #q < 3 and A and ReadySoon(A.WingClip) then 
        Push(q, A.WingClip) 
      end
    else
      -- Ranged abilities
      if A and ReadySoon(A.AimedShot) then 
        Push(q, A.AimedShot) 
      end
      if A and ReadySoon(A.MultiShot) then 
        Push(q, A.MultiShot) 
      end
      if A and ReadySoon(A.ArcaneShot) then 
        Push(q, A.ArcaneShot) 
      end
      if A and ReadySoon(A.SteadyShot) then 
        Push(q, A.SteadyShot) 
      end

      -- Serpent Sting if not already on target
      if #q < 3 and A and A.SerpentSting and not DebuffUpID("target", A.SerpentSting) and ReadySoon(A.SerpentSting) then
        Push(q, A.SerpentSting)
      end
    end -- end else (ranged)

    -- Auto Shot if nothing else and not active
    if #q < 1 and A and A.AutoShot and not AutoShotActive() then 
      Push(q, A.AutoShot) 
    end
  end -- end if HaveTarget()

  -- Only after prioritizing Auto Shot / Raptor logic, insert pet suggestions if nothing critical was queued
  if not UnitAffectingCombat("player") and (#q == 0) then
    local pq = BuildPetQueue()
    if pq and pq[1] then
      q = pq
    end
  end

  return pad3(q, Fallback())
end

-- ===== Engine tick / timer =====
function TR:EngineTick_Hunter()
  IDS = ResolveIDS() or IDS; A = (IDS and IDS.Ability) or A
  if IDS and IDS.UpdateRanks then pcall(IDS.UpdateRanks, IDS) end

  local q
  if not A or not next(A) then
    q = {SAFE,SAFE,SAFE}
  elseif not UnitAffectingCombat("player") then
    q = BuildPetQueue() or BuildQueue()
    if not (q and q[1]) then q = BuildQueue() end
  else
    q = BuildQueue()
  end

  self._lastMainSpell = q[1]
  
  -- Use the correct UI update method
  if TR.UI_Update then
    TR.UI_Update(q[1], q[2], q[3])
  elseif self.UI and self.UI.Update then 
    self.UI:Update(q[1], q[2], q[3]) 
  end
end

function TR:StartEngine_Hunter()
  self:StopEngine_Hunter()
  self:EngineTick_Hunter()
  local AceTimer = LibStub and LibStub("AceTimer-3.0", true)
  if AceTimer and AceTimer.ScheduleRepeatingTimer then
    self._engineTimer_HU = AceTimer:ScheduleRepeatingTimer(function() _G.TacoRot:EngineTick_Hunter() end, 0.20)
  else
    local acc, f = 0, CreateFrame("Frame")
    f:SetScript("OnUpdate", function(_, e) acc=acc+(e or 0); if acc>=0.20 then acc=acc-0.20; _G.TacoRot:EngineTick_Hunter() end end)
    self._engineTimer_HU = f
  end
  self:Print("TacoRot Hunter engine active: DPS")
end

function TR:StopEngine_Hunter()
  local t = self._engineTimer_HU
  if not t then return end
  local AceTimer = LibStub and LibStub("AceTimer-3.0", true)
  if AceTimer and type(t)=="number" then 
    AceTimer:CancelTimer(t,true) 
  elseif type(t)=="table" and t.SetScript then 
    t:SetScript("OnUpdate",nil); t:Hide() 
  end
  self._engineTimer_HU = nil
end

do local _,c=UnitClass("player"); if c=="HUNTER" then TR:StartEngine_Hunter() end end