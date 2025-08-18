-- warrior_ids.lua — TacoRot Warrior IDs (3.3.5)
-- Structure mirrors existing Hunter/Rogue/Warlock/Druid tables.
-- Uses rank promotion at load, plus fallback icons so you never see ???

local IDS = {}
IDS.Ability = {
  BattleShout      = 6673,
  MortalStrike     = 12294,
  Rend             = 772,
  Overpower        = 7384,
  Slam             = 1464,
  Execute          = 5308,
  Bladestorm       = 46924,
  SweepingStrikes  = 12328,
  Bloodthirst      = 23881,
  Whirlwind        = 1680,
  HeroicStrike     = 78,
  BerserkerRage    = 18499,
  Intercept        = 20252,
}

IDS.Rank = {
  BattleShout      = {6673, 5242, 6192, 11549, 11550, 11551, 25289, 2048, 47436},
  MortalStrike     = {12294, 21551, 21552, 21553, 25248, 30330},
  Rend             = {772, 6546, 6547, 6548, 11572, 11573, 11574},
  Overpower        = {7384},
  Slam             = {1464, 8820, 11604, 11605},
  Execute          = {5308, 20658, 20660, 20661, 20662},
  Bladestorm       = {46924},
  SweepingStrikes  = {12328},
  Bloodthirst      = {23881, 23892, 23893, 23894},
  Whirlwind        = {1680},
  HeroicStrike     = {78, 284, 285, 1608, 11564, 11565, 11566, 11567, 25286, 29707},
  BerserkerRage    = {18499},
  Intercept        = {20252, 20616, 20617},
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

_G.TacoRot_IDS_Warrior = IDS

-- ===== Icon fallbacks by spellID =====
_G.TacoRotIconFallbacks = _G.TacoRotIconFallbacks or {}
local fb = _G.TacoRotIconFallbacks
local function setOnce(id, tex) if id and not fb[id] then fb[id] = tex end end

setOnce(6673, "Interface\Icons\Ability_Warrior_BattleShout")
setOnce(12294, "Interface\Icons\Ability_Warrior_SavageBlow")
setOnce(772, "Interface\Icons\Ability_Gouge")
setOnce(7384, "Interface\Icons\Ability_MeleeDamage")
setOnce(1464, "Interface\Icons\Ability_Warrior_DecisiveStrike")
setOnce(5308, "Interface\Icons\INV_Sword_48")
setOnce(46924, "Interface\Icons\Ability_Warrior_Bladestorm")
setOnce(12328, "Interface\Icons\Ability_Rogue_SliceDice")
setOnce(23881, "Interface\Icons\Spell_Nature_BloodLust")
setOnce(1680, "Interface\Icons\Ability_Whirlwind")
setOnce(78, "Interface\Icons\Ability_Rogue_Ambush")
setOnce(18499, "Interface\Icons\Spell_Nature_AncestralGuardian")
setOnce(20252, "Interface\Icons\Ability_Rogue_Sprint")
