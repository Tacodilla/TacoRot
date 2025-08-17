-- Warlock IDs + ranks (3.3.5-ish)
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
  Seed       = 27243, -- Seed of Corruption base
}

TR_IDS.Rank = {
  ShadowBolt = {686,695,705,1088,1106,7641,11659,11660,11661,25307},
  Corruption = {172,6222,6223,7648,11671,11672,25311},
  Immolate   = {348,707,1094,2941,11665,11667,11668,25309},
  SearingPain= {5676,17919,17920,17921,17922,17923},
  RainofFire = {5740,6219,11677,11678},
  LifeTap    = {1454,1455,1456,11687,11688,11689},
  ShadowWard = {6229,11739,11740,28610},
  Incinerate = {29722,32231,47837,47838}, -- higher ranks for WotLK clients
  Conflagrate= {17962,18930,18931,18932,27266,30912,47843,47827},
  Seed       = {27243,47833,47836},
}

local function HighestKnown(rankList)
  if not rankList then return nil end
  for i = #rankList, 1, -1 do
    local id = rankList[i]
    if IsSpellKnown and IsSpellKnown(id) then return id end
  end
  return nil
end

function TR_IDS:UpdateRanks()
  for name, list in pairs(TR_IDS.Rank) do
    local best = HighestKnown(list)
    if best then TR_IDS.Ability[name] = best end
  end
end

_G.TacoRot_IDS = TR_IDS
return TR_IDS
