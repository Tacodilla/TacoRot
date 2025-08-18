-- Rogue IDs + ranks (subset, 3.3.5-ish) with icon fallbacks
local TR_RG = {}
TR_RG.Ability = {
  SinisterStrike = 1752,
  Backstab       = 53,
  Mutilate       = 1329,
  Hemorrhage     = 16511,
  Ambush         = 8676,
  Garrote        = 703,
  SliceandDice   = 5171,
  Rupture        = 1943,
  Eviscerate     = 2098,
  BladeFlurry    = 13877,
  FanOfKnives    = 51723,
}

TR_RG.Rank = {
  SinisterStrike = {1752,1757,1758,1759,1760,8621,11293,11294,26862},
  Backstab       = {53,2589,2590,2591,8721,11279,11280,11281,25300},
  Mutilate       = {1329,34411,34412,34413,48663,48666},
  Hemorrhage     = {16511,17347,17348,26864},
  Ambush         = {8676,8724,8725,11267,11268,11269,27441},
  Garrote        = {703,8631,8632,8633,11289,11290,26839},
  SliceandDice   = {5171,6774},
  Rupture        = {1943,8639,8640,11273,11274,11275,26867},
  Eviscerate     = {2098,6760,6761,6762,8623,8624,11299,11300,26865},
  BladeFlurry    = {13877},
  FanOfKnives    = {51723},
}

local function HighestKnown(list)
  if not list then return nil end
  for i = #list, 1, -1 do
    if IsSpellKnown and IsSpellKnown(list[i]) then return list[i] end
  end
end

function TR_RG:UpdateRanks()
  for name, list in pairs(TR_RG.Rank) do
    local best = HighestKnown(list)
    if best then TR_RG.Ability[name] = best end
  end
end

_G.TacoRot_IDS_Rogue = TR_RG

-- ===== Icon fallbacks so Rogue never shows ??? =====
_G.TacoRotIconFallbacks = _G.TacoRotIconFallbacks or {}
local fb = _G.TacoRotIconFallbacks
local function setOnce(id, tex) if id and not fb[id] then fb[id] = tex end end

setOnce(1752,  "Interface\\Icons\\Ability_Rogue_SinisterStrike")
setOnce(53,    "Interface\\Icons\\Ability_BackStab")
setOnce(1329,  "Interface\\Icons\\Ability_Rogue_ShadowStrikes")   -- Mutilate
setOnce(16511, "Interface\\Icons\\Spell_Shadow_LifeDrain")        -- Hemorrhage
setOnce(8676,  "Interface\\Icons\\Ability_Rogue_Ambush")
setOnce(703,   "Interface\\Icons\\Ability_Rogue_Garrote")
setOnce(5171,  "Interface\\Icons\\Ability_Rogue_SliceDice")
setOnce(1943,  "Interface\\Icons\\Ability_Rogue_Rupture")
setOnce(2098,  "Interface\\Icons\\Ability_Rogue_Eviscerate")
setOnce(13877, "Interface\\Icons\\Ability_Warrior_PunishingBlow") -- Blade Flurry
setOnce(51723, "Interface\\Icons\\Ability_Rogue_FanofKnives")

return TR_RG
