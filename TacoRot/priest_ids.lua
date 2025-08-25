-- priest_ids.lua — TacoRot Priest IDs (3.3.5)
-- Structure mirrors existing Hunter/Rogue/Warlock/Druid tables.
-- Uses rank promotion at load, plus fallback icons so you never see ???

local IDS = {}
IDS.Ability = {
  VampiricTouch    = 34914,
  DevouringPlague  = 2944,
  ShadowWordPain   = 589,
  MindBlast        = 8092,
  MindFlay         = 15407,
  ShadowWordDeath  = 32379,
  Shadowfiend      = 34433,
}

IDS.Rank = {
  VampiricTouch    = {34914, 48159, 48160},
  DevouringPlague  = {2944, 19276, 19277, 19278, 19279, 19280, 25467, 48299, 48300},
  ShadowWordPain   = {589, 594, 970, 992, 2767, 10892, 10893, 10894, 25367, 25368, 48124, 48125},
  MindBlast        = {8092, 8102, 8103, 8104, 8105, 8106, 10945, 10946, 10947, 25372, 25375, 48126, 48127},
  MindFlay         = {15407, 17311, 17312, 17313, 17314, 18807, 25387, 48155, 48156},
  ShadowWordDeath  = {32379, 32996, 48157, 48158},
  Shadowfiend      = {34433},
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

_G.TacoRot_IDS_Priest = IDS

-- ===== Icon fallbacks by spellID =====
_G.TacoRotIconFallbacks = _G.TacoRotIconFallbacks or {}
local fb = _G.TacoRotIconFallbacks
local function setOnce(id, tex) if id and not fb[id] then fb[id] = tex end end

setOnce(34914, "Interface\Icons\Spell_Holy_Stoicism")
setOnce(2944, "Interface\Icons\Spell_Shadow_DevouringPlague")
setOnce(589, "Interface\Icons\Spell_Shadow_ShadowWordPain")
setOnce(8092, "Interface\Icons\Spell_Shadow_UnholyFrenzy")
setOnce(15407, "Interface\Icons\Spell_Shadow_SiphonMana")
setOnce(32379, "Interface\Icons\Spell_Shadow_DemonicFortitude")
setOnce(34433, "Interface\Icons\Spell_Shadow_Shadowfiend")
