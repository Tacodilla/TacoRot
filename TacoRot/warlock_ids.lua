-- TacoRot Warlock IDs (compact) - rank aware
local TR_IDS = {}

TR_IDS.Ability = {
  ShadowBolt = 686,
  Corruption = 172,
  Immolate   = 348,
  SearingPain= 5676,
  RainofFire = 5740,
  LifeTap    = 1454,
  DrainMana  = 5138,
  SiphonLife = 18265,
  ShadowWard = 6229,
}
TR_IDS.Rank = {
  ShadowBolt = {686,695,705,1088,1106,7641,11659,11660,11661,25307},
  Corruption = {172,6222,6223,7648,11671,11672,25311},
  Immolate   = {348,707,1094,2941,11665,11667,11668,25309},
  SearingPain= {5676,17919,17920,17921,17922,17923},
  RainofFire = {5740,6219,11677,11678},
  LifeTap    = {1454,1455,1456,11687,11688,11689},
  DrainMana  = {5138,6226,11703,11704},
  SiphonLife = {18265,18879,18880,18881},
  ShadowWard = {6229,11739,11740,28610},
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
