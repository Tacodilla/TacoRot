-- paladin_ids.lua — TacoRot Paladin IDs (3.3.5)
-- Structure mirrors existing Hunter/Rogue/Warlock/Druid tables.
-- Uses rank promotion at load, plus fallback icons so you never see ???

local IDS = {}
IDS.Ability = {
  SealOfVengeance    = 31801,
  SealOfCorruption   = 53736,
  SealOfDedication   = 20375, -- TODO: verify ID
  SealOfPenitence    = 31892,
  SealOfTheMountain  = 84510, -- TODO: verify ID
  JudgementOfWisdom   = 53408,
  JudgementOfLight    = 20271,
  CrusaderStrike     = 35395,
  Consecration       = 26573,
  Exorcism           = 879,
  HammerOfWrath      = 24275,
  AvengingWrath      = 31884,
  HolyWrath          = 2812,
}

IDS.Rank = {
  SealOfVengeance    = {31801},
  SealOfCorruption   = {53736},
  SealOfDedication   = {20375}, -- TODO: verify ranks
  SealOfPenitence    = {31892},
  SealOfTheMountain  = {84510}, -- TODO: verify ranks
  JudgementOfWisdom  = {53408},
  JudgementOfLight   = {20271},
  CrusaderStrike     = {35395},
  Consecration       = {26573, 20116, 20922, 20923, 20924, 27173, 48818, 48819},
  Exorcism           = {879, 5614, 5615, 10312, 10313, 10314, 27138, 48801, 48800},
  HammerOfWrath      = {24275, 24274, 24239, 27180, 48805, 48806},
  AvengingWrath      = {31884},
  HolyWrath          = {2812, 10318, 27139, 48816, 48817},
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

_G.TacoRot_IDS_Paladin = IDS

-- ===== Icon fallbacks by spellID =====
_G.TacoRotIconFallbacks = _G.TacoRotIconFallbacks or {}
local fb = _G.TacoRotIconFallbacks
local function setOnce(id, tex) if id and not fb[id] then fb[id] = tex end end

setOnce(31801, "Interface\Icons\Spell_Holy_SealOfVengeance")
setOnce(53736, "Interface\Icons\Spell_Holy_SealOfVengeance")
setOnce(53408, "Interface\Icons\Spell_Holy_RighteousFury")
setOnce(20271, "Interface\Icons\Spell_Holy_RighteousFury")
setOnce(35395, "Interface\Icons\Spell_Holy_CrusaderStrike")
setOnce(26573, "Interface\Icons\Spell_Holy_InnerFire")
setOnce(879, "Interface\Icons\Spell_Holy_Excorcism_02")
setOnce(24275, "Interface\Icons\Ability_Paladin_HammeroftheRighteous")
setOnce(31884, "Interface\Icons\Spell_Holy_AvengineWrath")
setOnce(2812, "Interface\Icons\Spell_Holy_Excorcism")
setOnce(20375, "Interface\\Icons\\Ability_Paladin_SealOfCommand")
setOnce(31892, "Interface\\Icons\\Ability_Paladin_SealOfBlood")
setOnce(84510, "Interface\\Icons\\Spell_Holy_SealOfRighteousness")
