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
  DemonSkin  = 687,
  FelArmor   = 28176,
  SummonImp  = 688,
  SummonVoidwalker = 697,
  SummonFelhunter = 691,
  SummonFelguard = 30146,
  CurseOfAgony = 980,
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
  DemonSkin  = {687,696},
  FelArmor   = {28176,47893},
  SummonImp  = {688},
  SummonVoidwalker = {697},
  SummonFelhunter = {691},
  SummonFelguard = {30146},
  CurseOfAgony = {980,1014,6217,11711,11712,11713},
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
setOnce(687,   "Interface\\Icons\\Spell_Shadow_RagingScream")         -- Demon Skin
setOnce(28176, "Interface\\Icons\\Spell_Shadow_FelArmour")            -- Fel Armor
setOnce(47893, "Interface\\Icons\\Spell_Shadow_FelArmour")            -- Fel Armor (higher rank)
setOnce(688,   "Interface\\Icons\\Spell_Shadow_SummonImp")            -- Summon Imp
setOnce(697,   "Interface\\Icons\\Spell_Shadow_SummonVoidWalker")     -- Summon Voidwalker
setOnce(691,   "Interface\\Icons\\Spell_Shadow_SummonFelHunter")      -- Summon Felhunter
setOnce(30146, "Interface\\Icons\\Spell_Shadow_SummonFelGuard")       -- Summon Felguard
setOnce(980,   "Interface\\Icons\\Spell_Shadow_CurseOfMannoroth")     -- Curse of Agony

return TR_IDS