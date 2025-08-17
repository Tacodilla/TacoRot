local TacoRot = _G.TacoRot
if not TacoRot then return end
local IDS = _G.TacoRot_IDS

-- ---------- Helpers ----------
local iconCache = TacoRot.iconCache or {}
local function IconFor(id)
  if not id then return nil end
  if not iconCache[id] then
    local _,_,ic = GetSpellInfo(id); iconCache[id] = ic
  end
  return iconCache[id]
end

local function Known(id) return id and IsSpellKnown and IsSpellKnown(id) end

local GCD_CUTOFF = 1.6
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
  for i=1,40 do
    local name, _, _, count, _, dur, exp, _, _, _, id = UnitDebuff(unit, i)
    if not name then break end
    if id == spellId then
      local remain = exp and (exp - GetTime()) or 0
      return true, remain, dur, count
    end
  end
  return false, 0, 0, 0
end

local function DebuffUp(spellId, unit) local up = DebuffInfo(unit or "target", spellId); return up end

local function PlayerHP()
  local m = UnitHealthMax("player") or 1
  local c = UnitHealth("player") or m
  return c/m
end

local function PlayerManaPct()
  local m = UnitPowerMax("player", 0) or 1
  local c = UnitPower("player", 0) or 0
  return c/m
end

local function TargetCasting() return UnitCastingInfo("target") or UnitChannelInfo("target") end

local function TargetHasBuff()
  for i=1,40 do if not UnitBuff("target", i) then break end; return true end
  return false
end

local function TargetAttackable()
  return UnitExists("target") and UnitCanAttack("player", "target") and not UnitIsDeadOrGhost("target")
end

local function InRangeByName(spellId)
  local name = GetSpellInfo(spellId)
  if not name then return nil end
  local r = IsSpellInRange(name, "target")
  return r == 1
end

-- ---------- Snapshot & Ranks ----------
local Snap = {}
local function Stats()
  Snap.playerHp = PlayerHP()
  Snap.manaPct = PlayerManaPct()
  Snap.attackable = TargetAttackable()
end
local function UpdateRanks() if IDS and IDS.UpdateRanks then IDS:UpdateRanks() end end

-- ---------- Priority helpers ----------
local function enabled(db, sid) return sid and (db.profile.spells[sid] ~= false) and Known(sid) end

local function IsPlayerCastingName(nameWanted)
  if not nameWanted then return false end
  local n = UnitCastingInfo("player") or UnitChannelInfo("player")
  return n and n == nameWanted
end

-- Only refresh DoTs when remaining < cast_time * clip (ConROC-like clipping)
local CLIP = 0.3
local function ShouldRefresh(spellId, castTime)
  local up, remain = DebuffInfo("target", spellId)
  if not up then return true end
  return remain <= (castTime or 1.5) * CLIP
end

-- ---------- Build queues ----------
local function BuildSingleTarget(db)
  UpdateRanks(); Stats()
  local A = IDS.Ability
  local q = {}
  local pushed = {}

  local immName = GetSpellInfo(A.Immolate)
  local corName = GetSpellInfo(A.Corruption)

  local immUp, immRemain = DebuffInfo("target", A.Immolate)
  local corUp, corRemain = DebuffInfo("target", A.Corruption)

  -- Virtually apply if currently casting
  if IsPlayerCastingName(immName) then immUp = true; immRemain = 999 end
  if IsPlayerCastingName(corName) then corUp = true; corRemain = 999 end

  local function push(sid)
    if sid and not pushed[sid] and Known(sid) then q[#q+1]=sid; pushed[sid]=true end
  end

  -- Life Tap rule
  if Snap.manaPct <= (db.profile.tapMana or 0.15) and Snap.playerHp >= (db.profile.tapMinHP or 0.35) and enabled(db, A.LifeTap) and ReadySoon(A.LifeTap) then
    push(A.LifeTap)
  end

  -- Spec-sensitive burst/DoTs
  local spec = db.profile.spec or "Destro"
  if spec == "Destro" then
    -- Keep Immolate up, then Conflagrate if it's known & ready and Immo up
    if enabled(db, A.Immolate) and ReadySoon(A.Immolate) and (not immUp or ShouldRefresh(A.Immolate, 2.0)) then push(A.Immolate); immUp=true end
    if enabled(db, A.Conflagrate) and ReadySoon(A.Conflagrate) and immUp then push(A.Conflagrate) end
    if #q < 3 and enabled(db, A.Corruption) and ReadySoon(A.Corruption) and (not corUp or ShouldRefresh(A.Corruption, 2.0)) then push(A.Corruption); corUp=true end
    -- Fillers: Incinerate if known, else Shadow Bolt
    if #q < 3 then
      if enabled(db, A.Incinerate) and ReadySoon(A.Incinerate) then push(A.Incinerate) end
      if #q < 3 and enabled(db, A.ShadowBolt) and ReadySoon(A.ShadowBolt) then push(A.ShadowBolt) end
    end
  elseif spec == "Aff" then
    if enabled(db, A.Corruption) and ReadySoon(A.Corruption) and (not corUp or ShouldRefresh(A.Corruption, 2.0)) then push(A.Corruption); corUp=true end
    if #q < 3 and enabled(db, A.Immolate) and ReadySoon(A.Immolate) and (not immUp or ShouldRefresh(A.Immolate, 2.0)) then push(A.Immolate); immUp=true end
    if #q < 3 and enabled(db, A.SearingPain) and ReadySoon(A.SearingPain) then push(A.SearingPain) end
    if #q < 3 and enabled(db, A.ShadowBolt) and ReadySoon(A.ShadowBolt) then push(A.ShadowBolt) end
  else -- Demo default
    if enabled(db, A.Immolate) and ReadySoon(A.Immolate) and (not immUp or ShouldRefresh(A.Immolate, 2.0)) then push(A.Immolate); immUp=true end
    if #q < 3 and enabled(db, A.Corruption) and ReadySoon(A.Corruption) and (not corUp or ShouldRefresh(A.Corruption, 2.0)) then push(A.Corruption); corUp=true end
    if #q < 3 and enabled(db, A.ShadowBolt) and ReadySoon(A.ShadowBolt) then push(A.ShadowBolt) end
  end

  -- Range/LOS gate: if first spell not in range or target not attackable, replace icon with question mark (but keep logic)
  if not Snap.attackable or (q[1] and not InRangeByName(q[1])) then
    -- swap icon to question mark by setting texture, but keep q list; do this in presenter
  end

  if #q == 0 then push(A.ShadowBolt) end
  return q
end

local function BuildAoE(db)
  UpdateRanks(); Stats()
  local A = IDS.Ability
  local q = {}
  local pushed = {}
  local function push(sid) if sid and not pushed[sid] and Known(sid) then q[#q+1]=sid; pushed[sid]=true end end

  -- Channel Rain of Fire / or Seed if known
  if enabled(db, A.Seed) and ReadySoon(A.Seed) then push(A.Seed) end
  if #q < 3 and enabled(db, A.RainofFire) and ReadySoon(A.RainofFire) then push(A.RainofFire) end
  -- Fill with Immolate/Corruption for spread pressure
  if #q < 3 and enabled(db, A.Immolate) and ReadySoon(A.Immolate) then push(A.Immolate) end
  if #q < 3 and enabled(db, A.Corruption) and ReadySoon(A.Corruption) then push(A.Corruption) end
  return q
end

-- ---------- Detectors ----------
local PET_SPELL_LOCK = 19647 -- Felhunter
local PET_DEVOUR    = 19801 -- Felhunter

local function PetIsFelhunter()
  if not UnitExists("pet") then return false end
  local fam = UnitCreatureFamily("pet")
  if fam and fam == "Felhunter" then return true end
  -- fallback: if pet exists and has Spell Lock known, assume Felhunter
  return Known(PET_SPELL_LOCK)
end

local function UpdateDetectors(db)
  -- Defense
  if db.profile.enableDefense and PlayerHP() <= (db.profile.defHealth or 0.45) then
    if Known(IDS.Ability.ShadowWard) then
      local ic = IconFor(IDS.Ability.ShadowWard)
      if TacoRotDefWindow and ic then TacoRotDefWindow.tex:SetTexture(ic); TacoRotDefWindow:Show() end
    else
      if TacoRotDefWindow then TacoRotDefWindow:Show() end
    end
  else
    if TacoRotDefWindow then TacoRotDefWindow:Hide() end
  end

  -- Interrupt
  if db.profile.enableInterrupt and PetIsFelhunter() and TargetCasting() and Known(PET_SPELL_LOCK) then
    local ic = IconFor(PET_SPELL_LOCK)
    if TacoRotIntFlash and ic then TacoRotIntFlash.tex:SetTexture(ic); TacoRotIntFlash:Show() end
  else
    if TacoRotIntFlash then TacoRotIntFlash:Hide() end
  end

  -- Purge
  if db.profile.enablePurge and PetIsFelhunter() and TargetHasBuff() and Known(PET_DEVOUR) then
    local ic = IconFor(PET_DEVOUR)
    if TacoRotPurgeFlash and ic then TacoRotPurgeFlash.tex:SetTexture(ic); TacoRotPurgeFlash:Show() end
  else
    if TacoRotPurgeFlash then TacoRotPurgeFlash:Hide() end
  end
end

-- ---------- Engine loop & presenter ----------
local function setIcon(frame, sid, neutralWhenOutOfRange)
  if not frame then return end
  if sid and (not neutralWhenOutOfRange or InRangeByName(sid)) and IconFor(sid) then
    frame.tex:SetTexture(IconFor(sid)); frame:Show()
  else
    frame.tex:SetTexture("Interface\\Icons\\INV_Misc_QuestionMark"); frame:Show()
  end
end

function TacoRot:EngineTick()
  local db = self.db
  local q = (db.profile.aoe and BuildAoE or BuildSingleTarget)(db)

  if db.profile.debug then
    DEFAULT_CHAT_FRAME:AddMessage("|cffffcc00[TacoRot]|r queue: "..table.concat({tostring(q[1]),tostring(q[2]),tostring(q[3])}, ", "))
  end

  setIcon(TacoRotWindow,  q[1], true)
  setIcon(TacoRotWindow2, q[2], false)
  setIcon(TacoRotWindow3, q[3], false)
  UpdateDetectors(db)
end

function TacoRot:AdjustTick(inCombat)
  local interval = inCombat and 0.10 or 0.25
  if self._engineTimer then self:CancelTimer(self._engineTimer); self._engineTimer=nil end
  self._engineTimer = self:ScheduleRepeatingTimer("EngineTick", interval)
end

function TacoRot:StartEngine_Warlock()
  if self._engineTimer then return end
  self:AdjustTick(UnitAffectingCombat("player"))
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
