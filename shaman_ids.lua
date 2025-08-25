-- shaman_ids.lua — TacoRot Shaman IDs (3.3.5)
-- Structure mirrors existing Hunter/Rogue/Warlock/Druid tables.
-- Uses rank promotion at load, plus fallback icons so you never see ???

local IDS = {}
IDS.Ability = {
  FlameShock       = 8050,
  EarthShock       = 8042,
  MoltenBlast      = 84508, -- TODO: verify ID
  LightningBolt    = 403,
  ChainLightning   = 421,
  Stormstrike      = 17364,
  LavaLash         = 60103,
  ShamanisticRage  = 30823,
}

IDS.Rank = {
  FlameShock       = {8050, 8052, 8053, 10447, 10448, 29228, 25457, 49232, 49233},
  EarthShock       = {8042, 8044, 8045, 8046, 10412, 10413, 10414, 25454, 49230, 49231},
  MoltenBlast      = {84508}, -- TODO: verify ranks
  LightningBolt    = {403, 529, 548, 915, 943, 6041, 10391, 10392, 15207, 15208, 25448, 25449, 49237, 49238},
  ChainLightning   = {421, 930, 2860, 10605, 25439, 25442, 49270, 49271},
  Stormstrike      = {17364},
  LavaLash         = {60103},
  ShamanisticRage  = {30823},
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

_G.TacoRot_IDS_Shaman = IDS

-- ===== Icon fallbacks by spellID =====
_G.TacoRotIconFallbacks = _G.TacoRotIconFallbacks or {}
local fb = _G.TacoRotIconFallbacks
local function setOnce(id, tex) if id and not fb[id] then fb[id] = tex end end

setOnce(8050, "Interface\Icons\Spell_Fire_FlameShock")
setOnce(8042, "Interface\Icons\Spell_Nature_EarthShock")
setOnce(84508, "Interface\Icons\Spell_Shaman_LavaBurst")
setOnce(403, "Interface\Icons\Spell_Nature_Lightning")
setOnce(421, "Interface\Icons\Spell_Nature_ChainLightning")
setOnce(17364, "Interface\Icons\Spell_Holy_SealOfMight")
setOnce(60103, "Interface\Icons\Ability_Shaman_LavaLash")
setOnce(30823, "Interface\Icons\Spell_Nature_ShamanRage")
