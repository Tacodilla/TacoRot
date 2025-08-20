-- engine_hunter.lua — TacoRot Hunter (3.3.5)
-- Uses core prediction helpers for timing, movement and auras.

local TR = _G.TacoRot
if not TR then return end
local P = TR.Predict

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
local TOKEN = "HUNTER"

-- ===== config =====
local function PetCfg() local p=TR and TR.db and TR.db.profile and TR.db.profile.pet; return (p and p[TOKEN]) or {enabled=true} end

-- ===== helpers =====
local function pad3(q, fb) q[1]=q[1] or fb; q[2]=q[2] or q[1]; q[3]=q[3] or q[2]; return q end
local function Push(q,id) if id then q[#q+1]=id end end

local function AutoShotActive()
  local n = (A and A.AutoShot and GetSpellInfo(A.AutoShot)) or "Auto Shot"
  local ok = IsAutoRepeatSpell and IsAutoRepeatSpell(n)
  return ok == 1 or ok == true
end

-- ===== Pets (OOC) =====
local function HasPet() return UnitExists("pet") and not UnitIsDead("pet") end
local function CallPetID() if A and A.CallPet then return A.CallPet end local id=883; if P.Known(id) then return id end end
local function RevivePetID() if A and A.RevivePet then return A.RevivePet end local id=982; if P.Known(id) then return id end end
local function MendPetID() if A and A.MendPet then return A.MendPet end local id=136; if P.Known(id) then return id end end

local function BuildPetQueue()
  local cfg = PetCfg(); if not (cfg.enabled ~= false) then return end
  local q = {}
  if (not HasPet()) and (cfg.summon ~= false) then
    local call = CallPetID(); if call and P.ReadySoon(call, TOKEN) then Push(q, call); return q end
  end
  if UnitExists("pet") and UnitIsDead("pet") and (cfg.revive ~= false) then
    local revive = RevivePetID(); if revive and P.ReadySoon(revive, TOKEN) then Push(q, revive); return q end
  end
  if UnitExists("pet") and (cfg.mend ~= false) then
    local hp = UnitHealth("pet") or 0; local max = UnitHealthMax("pet") or 1
    if max > 0 and (hp/max) < 0.60 then local mend = MendPetID(); if mend and P.ReadySoon(mend, TOKEN) then Push(q, mend); return q end end
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
  P.ClearCache()

  local q = {}

  if not P.HaveTarget() then
    if not UnitAffectingCombat("player") then
      local pq = BuildPetQueue(); if pq and pq[1] then return pq end
    end
    return { Fallback(), Fallback(), Fallback() }
  end

  if not UnitAffectingCombat("player") then
    if A and P.ReadySoon(A.HuntersMark, TOKEN) and not P.DebuffUp("target", A.HuntersMark) then Push(q, A.HuntersMark) end
  end

  if A and A.KillShot and P.ReadySoon(A.KillShot, TOKEN) then Push(q, A.KillShot) end

  if P.InMelee() then
    if A and P.ReadySoon(A.RaptorStrike, TOKEN) then table.insert(q,1,A.RaptorStrike) end
    if #q < 3 and A and P.ReadySoon(A.WingClip, TOKEN) then Push(q, A.WingClip) end
  else
    if A and P.ReadySoon(A.AimedShot, TOKEN) then Push(q, A.AimedShot) end
    if P.AoEActive() and A and P.ReadySoon(A.MultiShot, TOKEN) then Push(q, A.MultiShot) end
    if A and P.ReadySoon(A.ArcaneShot, TOKEN) then Push(q, A.ArcaneShot) end
    if A and not P.PlayerMoving() and P.ReadySoon(A.SteadyShot, TOKEN) then Push(q, A.SteadyShot) end
    if #q < 3 and A and A.SerpentSting and P.ReadySoon(A.SerpentSting, TOKEN) and P.ShouldRefreshDebuff("target", A.SerpentSting) then
      Push(q, A.SerpentSting)
    end
  end

  if #q < 1 and A and A.AutoShot and not AutoShotActive() then Push(q, A.AutoShot) end

  if not UnitAffectingCombat("player") and #q == 0 then
    local pq = BuildPetQueue(); if pq and pq[1] then q = pq end
  end

  return pad3(q, Fallback())
end

-- ===== Engine tick / timer =====
function TR:EngineTick_Hunter()
  local q = BuildQueue()
  self._lastMainSpell = q[1]
  if self.UI and self.UI.Update then self.UI:Update(q[1], q[2], q[3]) end
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
  self:Print("TacoRot Hunter engine active: " .. "DPS")
end

function TR:StopEngine_Hunter()
  local t = self._engineTimer_HU
  if not t then return end
  local AceTimer = LibStub and LibStub("AceTimer-3.0", true)
  if AceTimer and type(t)=="number" then AceTimer:CancelTimer(t,true) elseif type(t)=="table" and t.SetScript then t:SetScript("OnUpdate",nil); t:Hide() end
  self._engineTimer_HU = nil
end

do local _,c=UnitClass("player"); if c=="HUNTER" then TR:StartEngine_Hunter() end end
