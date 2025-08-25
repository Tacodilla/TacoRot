-- mage_ids.lua — TacoRot Mage IDs (3.3.5)
-- Structure mirrors existing Hunter/Rogue/Warlock/Druid tables.
-- Uses rank promotion at load, plus fallback icons so you never see ???

local IDS = {}
IDS.Ability = {
  ArcaneBlast      = 30451,
  ArcaneMissiles   = 5143,
  ArcaneBarrage    = 44425,
  Fireball         = 133,
  Scorch           = 2948,
  LivingBomb       = 44457,
  Pyroblast        = 11366,
  Frostbolt        = 116,
  IceLance         = 30455,
  FrostfireBolt    = 44614,
  ArcaneExplosion  = 1449,
  Flamestrike      = 2120,
  BlastWave        = 11113,
  ConeOfCold       = 120,
  Blizzard         = 10,
}

IDS.Rank = {
  ArcaneBlast      = {30451},
  ArcaneMissiles   = {5143, 5144, 5145, 8416, 8417, 10211, 10212, 25345, 27075, 38699, 38704},
  ArcaneBarrage    = {44425},
  Fireball         = {133, 143, 145, 3140, 8400, 8401, 8402, 10148, 10149, 10150, 10151, 25306, 27070, 38692, 42832, 42833},
  Scorch           = {2948, 8444, 8445, 8446, 10205, 10206, 10207, 27073, 27074, 42858, 42859},
  LivingBomb       = {44457},
  Pyroblast        = {11366, 12505, 12522, 12523, 12524, 12525, 12526, 18809, 27132, 33938, 42890, 42891},
  Frostbolt        = {116, 205, 837, 7322, 8406, 8407, 8408, 10179, 10180, 10181, 25304, 27071, 27072, 38697, 42841, 42842},
  IceLance         = {30455, 42913, 42914},
  FrostfireBolt    = {44614, 47610},
  ArcaneExplosion  = {1449, 8437, 8438, 8439, 10201, 10202, 27080, 27082, 42920, 42921},
  Flamestrike      = {2120, 2121, 8422, 8423, 10215, 10216, 27086, 27087, 42925, 42926},
  BlastWave        = {11113, 13018, 13019, 13020, 13021, 27133, 33933, 42944, 42945},
  ConeOfCold       = {120, 8492, 10159, 10160, 10161, 27087, 42930, 42931},
  Blizzard         = {10, 6141, 8427, 10185, 10186, 10187, 27085, 42939, 42940},
}

local function bestRank(list)
  if not list then return nil end

  -- First pass: find the highest rank that is currently known
  for i = #list, 1, -1 do
    local id = list[i]
    if IsSpellKnown and IsSpellKnown(id) then
      return id
    end
  end

  -- Second pass: if nothing is known, find the highest rank that exists in spellbook
  for i = #list, 1, -1 do
    local id = list[i]
    if GetSpellInfo and GetSpellInfo(id) then
      return id
    end
  end

  -- Final fallback: return the lowest rank (most likely to be available at low levels)
  return list[1]
end

function IDS:UpdateRanks()
  for key, list in pairs(self.Rank) do
    local id = bestRank(list)
    if id then self.Ability[key] = id end
  end
end

_G.TacoRot_IDS_Mage = IDS

-- ===== Icon fallbacks by spellID =====
_G.TacoRotIconFallbacks = _G.TacoRotIconFallbacks or {}
local fb = _G.TacoRotIconFallbacks
local function setOnce(id, tex) if id and not fb[id] then fb[id] = tex end end

setOnce(30451, "Interface\Icons\Spell_Arcane_Blast")
setOnce(5143, "Interface\Icons\Spell_Nature_StarFall")
setOnce(44425, "Interface\Icons\Ability_Mage_ArcaneBarrage")
setOnce(133, "Interface\Icons\Spell_Fire_FlameBolt")
setOnce(2948, "Interface\Icons\Spell_Fire_SoulBurn")
setOnce(44457, "Interface\Icons\Ability_Mage_LivingBomb")
setOnce(11366, "Interface\Icons\Spell_Fire_Fireball02")
setOnce(116, "Interface\Icons\Spell_Frost_FrostBolt02")
setOnce(30455, "Interface\Icons\Spell_Frost_FrostBolt")
setOnce(44614, "Interface\Icons\Ability_Mage_FrostFireBolt")
setOnce(1449, "Interface\Icons\Spell_Nature_WispSplode")
setOnce(2120, "Interface\Icons\Spell_Fire_SelfDestruct")
setOnce(11113, "Interface\Icons\Spell_Holy_Excorcism_02")
setOnce(120, "Interface\Icons\Spell_Frost_IceShock")
setOnce(10, "Interface\Icons\Spell_Frost_IceStorm")
