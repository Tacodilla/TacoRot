local TR = _G.TacoRot
if not TR then return end

TR.State = TR.State or {}
local State = TR.State

-- Enhanced state tracking
function State:Update()
  -- Preserve existing engine logic but add enhanced tracking
  self.time = GetTime()
  self.combatTime = self.inCombat and (self.time - (self.combatStart or self.time)) or 0
  self.gcd = self:GetGCD()
  self.castTime = self:GetCastTime()

  -- Resource tracking
  self.power = {
    current = UnitPower("player"),
    max = UnitPowerMax("player"),
    regen = self:GetPowerRegen(),
    timeToMax = self:GetTimeToMaxPower()
  }

  -- Enhanced buff/debuff tracking
  self.auras = self:UpdateAuras()
end

function State:GetGCD()
  local start, duration = GetSpellCooldown(61304) -- Global Cooldown
  if start == 0 then return 0 end
  return math.max(0, start + duration - GetTime())
end

function State:UpdateAuras()
  local auras = { buffs = {}, debuffs = {} }

  -- Player buffs
  for i = 1, 40 do
    local name, _, _, count, _, duration, expires = UnitBuff("player", i)
    if not name then break end
    auras.buffs[name] = {
      count = count or 1,
      duration = duration or 0,
      expires = expires or 0,
      remains = expires and math.max(0, expires - GetTime()) or 0
    }
  end

  -- Target debuffs
  for i = 1, 40 do
    local name, _, _, count, _, duration, expires = UnitDebuff("target", i, "PLAYER")
    if not name then break end
    auras.debuffs[name] = {
      count = count or 1,
      duration = duration or 0,
      expires = expires or 0,
      remains = expires and math.max(0, expires - GetTime()) or 0
    }
  end

  return auras
end
