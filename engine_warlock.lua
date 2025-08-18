-- engine_warlock.lua — TacoRot Warlock (3.3.5)
-- Standardized engine: single startup line, flash-safe, queue padded to 3.
-- Early game (lvl < 20): Immolate -> Corruption -> Shadowbolt

-- ==== IDs hookup ====
local IDS = _G.TacoRot_IDS_Warlock or _G.TacoRot_IDS or {}
local A   = IDS.Ability or {}

-- ==== helpers ====
local function Known(id) return id and IsSpellKnown and IsSpellKnown(id) or false end

local function ReadyNow(id)
  if not Known(id) then return false end
  local s, d, en = GetSpellCooldown(id)
  if (en or 0) == 0 then return false end
  return (s or 0) == 0 or (d or 0) == 0
end

local function DebuffUpID(unit, spellID)
  if not spellID then return false end
  for i = 1, 40 do
    local name, _, _, _, _, _, _, caster, _, _, id = UnitDebuff(unit, i)
    if not name then break end
    if id == spellID and (not caster or caster == "player") then return true end
  end
  return false
end

local function push(q, id) if id and Known(id) then q[#q+1] = id end end
local function pad3(q, fb) q[1]=q[1] or fb; q[2]=q[2] or q[1]; q[3]=q[3] or q[2]; return q end

-- ==== spec detection ====
local function LockSpec()
  local best, idx = -1, 1
  for i = 1, GetNumTalentTabs() do
    local _, _, pts = GetTalentTabInfo(i, "player")
    if (pts or 0) > best then best, idx = pts, i end
  end
  if best <= 0 then return "AFFLICTION" end
  return (idx==1 and "AFFLICTION") or (idx==2 and "DEMONOLOGY") or "DESTRUCTION"
end

-- ==== Early-game APL (lvl <20) ====
local function APL_Early()
  local q = {}
  if #q < 3 and Known(A.Immolate)   and not DebuffUpID("target", A.Immolate)   then push(q, A.Immolate) end
  if #q < 3 and Known(A.Corruption) and not DebuffUpID("target", A.Corruption) then push(q, A.Corruption) end
  if #q < 3 and Known(A.ShadowBolt) then push(q, A.ShadowBolt) end
  return pad3(q, (Known(A.ShadowBolt) and A.ShadowBolt) or A.Immolate or A.Corruption)
end

-- ==== Spec APLs (IDs limited to your warlock_ids.lua) ====
local function APL_Affliction()
  if UnitLevel("player") < 20 then return APL_Early() end
  local q = {}
  if #q < 3 and Known(A.Corruption) and not DebuffUpID("target", A.Corruption) then push(q, A.Corruption) end
  -- Optional AoE seed if you use AoE mode (ALT or option)
  if #q < 3 and Known(A.Seed) and (IsAltKeyDown() or (_G.TacoRot and _G.TacoRot.db and _G.TacoRot.db.profile.aoe)) then push(q, A.Seed) end
  if #q < 3 and Known(A.ShadowBolt) then push(q, A.ShadowBolt) end
  return pad3(q, (Known(A.ShadowBolt) and A.ShadowBolt) or A.Corruption)
end

local function APL_Demonology()
  if UnitLevel("player") < 20 then return APL_Early() end
  local q = {}
  if #q < 3 and Known(A.Immolate)   and not DebuffUpID("target", A.Immolate)   then push(q, A.Immolate) end
  if #q < 3 and Known(A.Corruption) and not DebuffUpID("target", A.Corruption) then push(q, A.Corruption) end
  if #q < 3 and Known(A.ShadowBolt) then push(q, A.ShadowBolt) end
  return pad3(q, (Known(A.ShadowBolt) and A.ShadowBolt) or A.Immolate or A.Corruption)
end

local function APL_Destruction()
  if UnitLevel("player") < 20 then return APL_Early() end
  local q = {}
  if #q < 3 and Known(A.Immolate)    and not DebuffUpID("target", A.Immolate)  then push(q, A.Immolate) end
  if #q < 3 and Known(A.Conflagrate) and DebuffUpID("target", A.Immolate) and ReadyNow(A.Conflagrate) then push(q, A.Conflagrate) end
  if #q < 3 and Known(A.Incinerate)  then push(q, A.Incinerate) end
  if #q < 3 and Known(A.ShadowBolt)  then push(q, A.ShadowBolt) end
  return pad3(q, (Known(A.ShadowBolt) and A.ShadowBolt) or A.Incinerate or A.Immolate)
end

local function BuildQueue()
  if not UnitExists("target") or UnitIsDead("target") then
    local fb = (Known(A.ShadowBolt) and A.ShadowBolt) or A.Immolate or A.Corruption
    return { fb, fb, fb }
  end
  local spec = LockSpec()
  if spec == "DEMONOLOGY" then
    return APL_Demonology()
  elseif spec == "DESTRUCTION" then
    return APL_Destruction()
  else
    return APL_Affliction()
  end
end

-- ==== attach to core (uniform contract) ====
local function AttachWarlock()
  local TR = _G.TacoRot
  if not TR or TR._warlock_bound then return end

  function TR:EngineTick_Warlock()
    if IDS and IDS.UpdateRanks then pcall(IDS.UpdateRanks, IDS) end
    local q = BuildQueue()
    self._lastMainSpell = q and q[1] or self._lastMainSpell
    if self.UI and self.UI.Update then
      self.UI:Update(q[1], q[2], q[3])
    end
  end

  local function _SpecName()  -- pretty casing for the startup line
    local s = LockSpec()
    return (s=="AFFLICTION" and "Affliction") or (s=="DEMONOLOGY" and "Demonology") or "Destruction"
  end

  function TR:StartEngine_Warlock()
    if self._engineTimerWL then return end
    if self.EngineTick_Warlock then self:EngineTick_Warlock() end
    if self.ScheduleRepeatingTimer then
      self._engineTimerWL = self:ScheduleRepeatingTimer("EngineTick_Warlock", 0.20)
    else
      local f = CreateFrame("Frame"); f._t = 0
      f:SetScript("OnUpdate", function(s,e)
        s._t = s._t + e
        if s._t >= 0.20 then s._t = 0; if _G.TacoRot and _G.TacoRot.EngineTick_Warlock then _G.TacoRot:EngineTick_Warlock() end end
      end)
      self._engineTimerWL = f
    end
    self:Print("TacoRot Warlock engine active: " .. _SpecName())
  end

  function TR:StopEngine_Warlock()
    if not self._engineTimerWL then return end
    local t = self._engineTimerWL
    if type(t)=="table" and t.Cancel then
      self:CancelTimer(t)
    elseif type(t)=="table" and t.SetScript then
      t:SetScript("OnUpdate", nil); t:Hide()
    end
    self._engineTimerWL = nil
  end

  local _, class = UnitClass("player")
  if class == "WARLOCK" then TR:StartEngine_Warlock() end
  TR._warlock_bound = true
end

if _G.TacoRot then
  AttachWarlock()
else
  local f = CreateFrame("Frame")
  f:RegisterEvent("ADDON_LOADED")
  f:SetScript("OnEvent", function(_, _, addon)
    if addon == "TacoRot" then
      AttachWarlock()
      f:UnregisterAllEvents()
      f:Hide()
    end
  end)
end
