-- shaman_ids.lua — TacoRot Shaman IDs (3.3.5)
-- Structure mirrors existing Hunter/Rogue/Warlock/Druid tables.
-- Uses rank promotion at load, plus fallback icons so you never see ???

local IDS = {}
IDS.Ability = {
  FlameShock       = 8050,
  EarthShock       = 8042,
  LavaBurst        = 51505,
  LightningBolt    = 403,
  ChainLightning   = 421,
  Thunderstorm     = 51490,
  Stormstrike      = 17364,
  LavaLash         = 60103,
  ShamanisticRage  = 30823,
  FeralSpirit      = 51533,
}

IDS.Rank = {
  FlameShock       = {8050, 8052, 8053, 10447, 10448, 29228, 25457, 49232, 49233},
  EarthShock       = {8042, 8044, 8045, 8046, 10412, 10413, 10414, 25454, 49230, 49231},
  LavaBurst        = {51505, 60043},
  LightningBolt    = {403, 529, 548, 915, 943, 6041, 10391, 10392, 15207, 15208, 25448, 25449, 49237, 49238},
  ChainLightning   = {421, 930, 2860, 10605, 25439, 25442, 49270, 49271},
  Thunderstorm     = {51490},
  Stormstrike      = {17364},
  LavaLash         = {60103},
  ShamanisticRage  = {30823},
  FeralSpirit      = {51533},
}

local function bestRank(list)
  if not list then return nil end
  local lastKnown
  for i = #list, 1, -1 do
    local id = list[i]
    if IsSpellKnown and IsSpellKnown(id) then
      return id
    end
    lastKnown = id
  end
  -- If nothing known yet (low level), keep highest for texture resolution.
  return lastKnown
end

function IDS:UpdateRanks()
  for key, list in pairs(self.Rank) do
    local id = bestRank(list)
    if id then self.Ability[key] = id end
  end
end

_G.TacoRot_IDS_Shaman = IDS

-- ===== Icon fallbacks by spellID =====
_G.TacoRotIconFallbacks = _G.TacoRotIconFallbacks or {}
local fb = _G.TacoRotIconFallbacks
local function setOnce(id, tex) if id and not fb[id] then fb[id] = tex end end

setOnce(8050, "Interface\Icons\Spell_Fire_FlameShock")
setOnce(8042, "Interface\Icons\Spell_Nature_EarthShock")
setOnce(51505, "Interface\Icons\Spell_Shaman_LavaBurst")
setOnce(403, "Interface\Icons\Spell_Nature_Lightning")
setOnce(421, "Interface\Icons\Spell_Nature_ChainLightning")
setOnce(51490, "Interface\Icons\Spell_Nature_CallStorm")
setOnce(17364, "Interface\Icons\Spell_Holy_SealOfMight")
setOnce(60103, "Interface\Icons\Ability_Shaman_LavaLash")
setOnce(30823, "Interface\Icons\Spell_Nature_ShamanRage")
setOnce(51533, "Interface\Icons\Spell_Shaman_FeralSpirit")
