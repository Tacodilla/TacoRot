-- Warlock IDs + ranks (3.3.5-ish) with icon fallbacks
local TR_IDS = {}

TR_IDS.Ability = {
  ShadowBolt = 686,
  Corruption = 172,
  Immolate   = 348,
  SearingPain= 5676,
  RainofFire = 5740,
  LifeTap    = 1454,
  ShadowWard = 6229,
  Incinerate = 29722,
  Conflagrate= 17962,
  Seed       = 27243,
}

TR_IDS.Rank = {
  ShadowBolt = {686,695,705,1088,1106,7641,11659,11660,11661,25307},
  Corruption = {172,6222,6223,7648,11671,11672,25311},
  Immolate   = {348,707,1094,2941,11665,11667,11668,25309},
  SearingPain= {5676,17919,17920,17921,17922,17923},
  RainofFire = {5740,6219,11677,11678},
  LifeTap    = {1454,1455,1456,11687,11688,11689},
  ShadowWard = {6229,11739,11740,28610},
  Incinerate = {29722,32231,47837,47838},
  Conflagrate= {17962,18930,18931,18932,27266,30912,47843,47827},
  Seed       = {27243,47833,47836},
}

local function HighestKnown(list)
  if not list then return nil end
  for i = #list, 1, -1 do
    if IsSpellKnown and IsSpellKnown(list[i]) then return list[i] end
  end
end

function TR_IDS:UpdateRanks()
  for name, list in pairs(TR_IDS.Rank) do
    local best = HighestKnown(list)
    if best then TR_IDS.Ability[name] = best end
  end
end

_G.TacoRot_IDS = TR_IDS

-- ===== Icon fallbacks so Warlock never shows ??? =====
_G.TacoRotIconFallbacks = _G.TacoRotIconFallbacks or {}
local fb = _G.TacoRotIconFallbacks
local function setOnce(id, tex) if id and not fb[id] then fb[id] = tex end end

setOnce(686,   "Interface\\Icons\\Spell_Shadow_ShadowBolt")
setOnce(172,   "Interface\\Icons\\Spell_Shadow_AbominationExplosion") -- Corruption
setOnce(348,   "Interface\\Icons\\Spell_Fire_Immolation")
setOnce(5676,  "Interface\\Icons\\Spell_Fire_SoulBurn")               -- Searing Pain
setOnce(5740,  "Interface\\Icons\\Spell_Shadow_RainOfFire")
setOnce(1454,  "Interface\\Icons\\Spell_Shadow_BurningSpirit")        -- Life Tap
setOnce(6229,  "Interface\\Icons\\Spell_Shadow_AntiShadow")           -- Shadow Ward
setOnce(29722, "Interface\\Icons\\Spell_Fire_FlameShock")             -- Incinerate (approx)
setOnce(17962, "Interface\\Icons\\Spell_Fire_Fireball02")             -- Conflagrate (approx)
setOnce(27243, "Interface\\Icons\\Spell_Shadow_SeedOfDestruction")    -- Seed of Corruption

return TR_IDS
