-- TacoRot / engine_warlock.lua  (stable + DoT clip + AoE toggle)
local TacoRot = _G.TacoRot
if not TacoRot then return end
local IDS = _G.TacoRot_IDS

-- ---------- Tunables ----------
local CLIP = 0.30          -- refresh DoTs when remaining <= cast_time * CLIP
local GCD_CUTOFF = 1.6     -- seconds; treat short CDs as available for prediction

-- ---------- Helpers ----------
local function Known(id) return id and IsSpellKnown and IsSpellKnown(id) end

local function ReadySoon(id)
  if not Known(id) then return false end
  local start, dur, enabled = GetSpellCooldown(id)
  if enabled == 0 then return false end
  if not start or start == 0 or dur == 0 then return true end
  local remain = (start + dur) - GetTime()
  if dur <= GCD_CUTOFF then return true end
  return remain <= 0.2
end

local function DebuffInfo(unit, spellId)
  unit = unit or "target"
  for i = 1, 40 do
    local name, _, _, _, _, dur, exp, _, _, _, id = UnitDebuff(unit, i)
    if not name then break end
    if id == spellId then
      local remain = (exp and (exp - GetTime())) or 0
      return true, remain, dur
    end
  end
  return false, 0, 0
end

local function PlayerHP()
  local m = UnitHealthMax("player") or 1
  local c = UnitHealth("player") or m
  return c / m
end

local function TargetCasting()
  return UnitCastingInfo("target") or UnitChannelInfo("target")
end

local function TargetHasBuff()
  for i = 1, 40 do
    if not UnitBuff("target", i) then break end
    return true
  end
  return false
end

local function IsPlayerCastingName(nameWanted)
  if not nameWanted then return false end
  local n = UnitCastingInfo("player") or UnitChannelInfo("player")
  return n and n == nameWanted
end

local function GetCastTimeSec(spellId)
  local _, _, _, castMS = GetSpellInfo(spellId)
  return (castMS or 1500) / 1000
end

-- ---------- Snapshot & Ranks ----------
local Snap = {}
local function Stats()
  Snap.playerHp = PlayerHP()
end

local function UpdateRanks()
  if IDS and IDS.UpdateRanks then IDS:UpdateRanks() end
end

-- ---------- Priority bits ----------
local function enabled(db, sid) return sid and (db.profile.spells[sid] ~= false) and Known(sid) end

local function ShouldRefreshUp(isUp, remainSec, castSec)
  if not isUp then return true end
  return remainSec <= (castSec * CLIP)
end

-- ---------- Single-Target queue (predictive + DoT clip) ----------
local function BuildSingleTarget(db)
  UpdateRanks(); Stats()
  local A = IDS.Ability
  local q, pushed = {}, {}
  local function push(sid) if sid and not pushed[sid] and Known(sid) then q[#q+1]=sid; pushed[sid]=true end end

  -- DoT states + mid-cast smoothing
  local immUp, immRemain = DebuffInfo("target", A.Immolate)
  local corUp, corRemain = DebuffInfo("target", A.Corruption)
  local immName = GetSpellInfo(A.Immolate)
  local corName = GetSpellInfo(A.Corruption)
  if IsPlayerCastingName(immName) then immUp = true; immRemain = 999 end
  if IsPlayerCastingName(corName) then corUp = true; corRemain = 999 end

  local immCast = GetCastTimeSec(A.Immolate)
  local corCast = GetCastTimeSec(A.Corruption)

  -- 1) DoTs (with clip)
  if enabled(db, A.Immolate) and ReadySoon(A.Immolate) and ShouldRefreshUp(immUp, immRemain, immCast) then
    push(A.Immolate); immUp = true; immRemain = 999
  end
  if #q < 3 and enabled(db, A.Corruption) and ReadySoon(A.Corruption) and ShouldRefreshUp(corUp, corRemain, corCast) then
    push(A.Corruption); corUp = true; corRemain = 999
  end

  -- 2) Fillers
  local fillers = { A.ShadowBolt, A.SearingPain }
  for _, sid in ipairs(fillers) do
    if #q >= 3 then break end
    if enabled(db, sid) and ReadySoon(sid) then push(sid) end
  end

  if #q == 0 then push(A.ShadowBolt) end
  return q
end

-- ---------- AoE queue ----------
local function BuildAoE(db)
  UpdateRanks(); Stats()
  local A = IDS.Ability or {}
  local q, pushed = {}, {}
  local function push(sid) if sid and not pushed[sid] and Known(sid) then q[#q+1]=sid; pushed[sid]=true end end

  -- Consider current channel/cast as "busy" to avoid flicker
  local seedName       = A.Seed       and GetSpellInfo(A.Seed)
  local rofName        = A.RainofFire and GetSpellInfo(A.RainofFire)
  local castingSeed    = seedName and IsPlayerCastingName(seedName)
  local castingRoF     = rofName and IsPlayerCastingName(rofName)

  -- 1) Big AoE spells first (if not already channeling one)
  if not castingRoF and not castingSeed then
    if enabled(db, A.Seed) and ReadySoon(A.Seed) then push(A.Seed) end
    if #q < 3 and enabled(db, A.RainofFire) and ReadySoon(A.RainofFire) then push(A.RainofFire) end
  else
    -- Maintain the one you're channeling to keep main icon stable
    if castingSeed and A.Seed then push(A.Seed) end
    if castingRoF and A.RainofFire then push(A.RainofFire) end
  end

  -- 2) Spread some pressure (simple, safe)
  if #q < 3 and enabled(db, A.Immolate) and ReadySoon(A.Immolate) then push(A.Immolate) end
  if #q < 3 and enabled(db, A.Corruption) and ReadySoon(A.Corruption) then push(A.Corruption) end

  -- 3) Fillers if needed
  if #q < 3 and enabled(db, A.ShadowBolt) and ReadySoon(A.ShadowBolt) then push(A.ShadowBolt) end
  if #q == 0 then push(A.ShadowBolt) end
  return q
end

-- ---------- AoE switch ----------
local function AoEEnabled()
  -- ALT forces AoE; persistent toggle lives in db.profile.aoe when you /tr aoe
  return IsAltKeyDown() or (TacoRot.db and TacoRot.db.profile and TacoRot.db.profile.aoe)
end

-- ---------- Detectors (pet-aware, unchanged) ----------
local PET_SPELL_LOCK = 19647 -- Felhunter
local PET_DEVOUR    = 19801 -- Felhunter

local function PetIsFelhunter()
  if not UnitExists("pet") then return false end
  local fam = UnitCreatureFamily("pet")
  if fam and fam == "Felhunter" then return true end
  return Known(PET_SPELL_LOCK)
end

local function UpdateDetectors(db)
  -- Defense
  if db.profile.enableDefense and PlayerHP() <= (db.profile.defHealth or 0.45) then
    if Known(IDS.Ability.ShadowWard) then
      local _,_,icon = GetSpellInfo(IDS.Ability.ShadowWard)
      if TacoRotDefWindow and icon then TacoRotDefWindow.tex:SetTexture(icon); TacoRotDefWindow:Show() end
    else
      if TacoRotDefWindow then TacoRotDefWindow:Show() end
    end
  else
    if TacoRotDefWindow then TacoRotDefWindow:Hide() end
  end

  -- Interrupt
  if db.profile.enableInterrupt and PetIsFelhunter() and TargetCasting() and Known(PET_SPELL_LOCK) then
    local _,_,icon = GetSpellInfo(PET_SPELL_LOCK)
    if TacoRotIntFlash and icon then TacoRotIntFlash.tex:SetTexture(icon); TacoRotIntFlash:Show() end
  else
    if TacoRotIntFlash then TacoRotIntFlash:Hide() end
  end

  -- Purge
  if db.profile.enablePurge and PetIsFelhunter() and TargetHasBuff() and Known(PET_DEVOUR) then
    local _,_,icon = GetSpellInfo(PET_DEVOUR)
    if TacoRotPurgeFlash and icon then TacoRotPurgeFlash.tex:SetTexture(icon); TacoRotPurgeFlash:Show() end
  else
    if TacoRotPurgeFlash then TacoRotPurgeFlash:Hide() end
  end
end

-- ---------- Engine loop ----------
local function setIcon(frame, sid)
  if not frame or not sid then return end
  local _,_,icon = GetSpellInfo(sid)
  if icon then frame.tex:SetTexture(icon) end
end

function TacoRot:EngineTick()
  local db = self.db
  local q = AoEEnabled() and BuildAoE(db) or BuildSingleTarget(db)
  setIcon(TacoRotWindow,  q[1])
  setIcon(TacoRotWindow2, q[2])
  setIcon(TacoRotWindow3, q[3])
  UpdateDetectors(db)
end

function TacoRot:StartEngine_Warlock()
  if self._engineTimer then return end
  UpdateRanks()
  self._engineTimer = self:ScheduleRepeatingTimer("EngineTick", 0.2)
end

function TacoRot:StopEngine_Warlock()
  if self._engineTimer then self:CancelTimer(self._engineTimer); self._engineTimer=nil end
end

TacoRot:RegisterMessage("TACOROT_ENABLE_CLASS_MODULE", function()
  TacoRot:RegisterEvent("SPELLS_CHANGED", UpdateRanks)
  TacoRot:RegisterEvent("CHARACTER_POINTS_CHANGED", UpdateRanks)
  TacoRot:RegisterEvent("PLAYER_TALENT_UPDATE", UpdateRanks)
  TacoRot:StartEngine_Warlock()
end)

-- ---------- Add /tr aoe toggle without touching core ----------
if type(TacoRot.Slash) == "function" then
  local _oldSlash = TacoRot.Slash
  function TacoRot:Slash(input)
    input = (input or ""):lower()
    if input == "aoe" then
      self.db.profile.aoe = not self.db.profile.aoe
      DEFAULT_CHAT_FRAME:AddMessage("|cffffcc00[TacoRot]|r AoE mode: "..(self.db.profile.aoe and "ON" or "OFF").." (hold ALT for temporary AoE)")
      return
    end
    return _oldSlash(self, input)
  end
end
