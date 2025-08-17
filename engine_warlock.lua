-- engine_warlock.lua
local TacoRot = _G.TacoRot
if not TacoRot then return end
local IDS = _G.TacoRot_IDS

local CLIP = 0.30
local GCD_CUTOFF = 1.6

local function Known(id) return id and IsSpellKnown and IsSpellKnown(id) end
local function ReadySoon(id)
  if not Known(id) then return false end
  local s,d,en = GetSpellCooldown(id)
  if en == 0 then return false end
  if not s or s == 0 or d == 0 then return true end
  if d <= GCD_CUTOFF then return true end
  return (s + d - GetTime()) <= 0.2
end

local function DebuffInfo(unit, spellId)
  unit = unit or "target"
  for i=1,40 do
    local name, _, _, _, _, dur, exp, _, _, _, id = UnitDebuff(unit, i)
    if not name then break end
    if id == spellId then
      local remain = (exp and (exp - GetTime())) or 0
      return true, remain, dur
    end
  end
  return false, 0, 0
end

local function PlayerHP() local m=UnitHealthMax("player") or 1; local c=UnitHealth("player") or m; return c/m end
local function TargetCasting() return UnitCastingInfo("target") or UnitChannelInfo("target") end
local function TargetHasBuff() for i=1,40 do if not UnitBuff("target", i) then break end; return true end return false end
local function IsPlayerCastingName(n) local a=UnitCastingInfo("player") or UnitChannelInfo("player"); return a and n and a==n end
local function CastTimeSec(id) local _,_,_,ms=GetSpellInfo(id); return (ms or 1500)/1000 end
local function enabled(db,sid) return sid and (db.profile.spells[sid] ~= false) and Known(sid) end
local function ShouldRefresh(up, remain, cast) if not up then return true end; return remain <= (cast * CLIP) end

local function BuildQueue(db)
  if IDS and IDS.UpdateRanks then IDS:UpdateRanks() end
  local A = IDS.Ability
  local q, pushed = {}, {}
  local function push(s) if s and not pushed[s] and Known(s) then q[#q+1]=s; pushed[s]=true end end

  local immUp, immRem = DebuffInfo("target", A.Immolate)
  local corUp, corRem = DebuffInfo("target", A.Corruption)
  local immName = GetSpellInfo(A.Immolate)
  local corName = GetSpellInfo(A.Corruption)
  if IsPlayerCastingName(immName) then immUp = true; immRem = 999 end
  if IsPlayerCastingName(corName) then corUp = true; corRem = 999 end

  local immCast = CastTimeSec(A.Immolate)
  local corCast = CastTimeSec(A.Corruption)

  if enabled(db, A.Immolate) and ReadySoon(A.Immolate) and ShouldRefresh(immUp, immRem, immCast) then
    push(A.Immolate); immUp = true; immRem = 999
  end
  if #q<3 and enabled(db, A.Corruption) and ReadySoon(A.Corruption) and ShouldRefresh(corUp, corRem, corCast) then
    push(A.Corruption); corUp = true; corRem = 999
  end

  local fillers = { A.ShadowBolt, A.SearingPain }
  for _, sid in ipairs(fillers) do
    if #q >= 3 then break end
    if enabled(db, sid) and ReadySoon(sid) then q[#q+1]=sid end
  end

  -- pad to 3
  while #q < 3 do q[#q+1] = A.ShadowBolt end
  return q
end

local PET_SPELL_LOCK = 19647
local PET_DEVOUR    = 19801
local function PetIsFelhunter()
  if not UnitExists("pet") then return false end
  local fam = UnitCreatureFamily("pet")
  if fam and fam == "Felhunter" then return true end
  return IsSpellKnown(PET_SPELL_LOCK)
end

local function UpdateDetectors(db)
  if db.profile.enableDefense and PlayerHP() <= (db.profile.defHealth or 0.45) then
    if IsSpellKnown(IDS.Ability.ShadowWard) then
      local _,_,icon = GetSpellInfo(IDS.Ability.ShadowWard)
      if TacoRotDefWindow and icon then TacoRotDefWindow.tex:SetTexture(icon); TacoRotDefWindow:Show() end
    else
      if TacoRotDefWindow then TacoRotDefWindow:Show() end
    end
  else
    if TacoRotDefWindow then TacoRotDefWindow:Hide() end
  end

  if db.profile.enableInterrupt and PetIsFelhunter() and TargetCasting() and IsSpellKnown(PET_SPELL_LOCK) then
    local _,_,icon = GetSpellInfo(PET_SPELL_LOCK)
    if TacoRotIntFlash and icon then TacoRotIntFlash.tex:SetTexture(icon); TacoRotIntFlash:Show() end
  else
    if TacoRotIntFlash then TacoRotIntFlash:Hide() end
  end

  if db.profile.enablePurge and PetIsFelhunter() and TargetHasBuff() and IsSpellKnown(PET_DEVOUR) then
    local _,_,icon = GetSpellInfo(PET_DEVOUR)
    if TacoRotPurgeFlash and icon then TacoRotPurgeFlash.tex:SetTexture(icon); TacoRotPurgeFlash:Show() end
  else
    if TacoRotPurgeFlash then TacoRotPurgeFlash:Hide() end
  end
end

function TacoRot:EngineTick_Warlock()
  local q = BuildQueue(self.db)

  -- store for cast flash
  self._lastMainSpell = q[1]

  -- optional: hide duplicate next windows
  if q[2] == q[1] then q[2] = nil end
  if q[3] == q[1] or q[3] == q[2] then q[3] = nil end

  if TacoRot.ApplyIcon then
    TacoRot:ApplyIcon(TacoRotWindow,  q[1])
    TacoRot:ApplyIcon(TacoRotWindow2, q[2])
    TacoRot:ApplyIcon(TacoRotWindow3, q[3])
  end

  if TacoRotWindow2 then (q[2] and TacoRotWindow2.Show or TacoRotWindow2.Hide)(TacoRotWindow2) end
  if TacoRotWindow3 then (q[3] and TacoRotWindow3.Show or TacoRotWindow3.Hide)(TacoRotWindow3) end

  UpdateDetectors(self.db)
end

function TacoRot:StartEngine_Warlock()
  if self._engineTimerWL then return end
  self._engineTimerWL = self:ScheduleRepeatingTimer("EngineTick_Warlock", 0.2)
end
function TacoRot:StopEngine_Warlock()
  if self._engineTimerWL then self:CancelTimer(self._engineTimerWL); self._engineTimerWL=nil end
end

TacoRot:RegisterMessage("TACOROT_ENABLE_CLASS_MODULE", function()
  local _, class = UnitClass("player")
  if class == "WARLOCK" then
    TacoRot:RegisterEvent("SPELLS_CHANGED", function() if IDS and IDS.UpdateRanks then IDS:UpdateRanks() end end)
    TacoRot:StartEngine_Warlock()
  end
end)
