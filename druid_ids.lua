-- druid_ids.lua — TacoRot Druid IDs (3.3.5)
local DR = {}

-- ==== Abilities (use base IDs; engine checks by name/IsSpellKnown) ====
DR.Ability = {
  -- Balance
  Wrath         = 5176,
  Moonfire      = 8921,
  Starfire      = 2912,
  InsectSwarm   = 5570,
  Starfall      = 48505,
  ForceOfNature = 33831,

  -- Feral (Cat)
  MangleCat     = 33876,   -- Mangle (Cat)
  Shred         = 5221,
  Rake          = 1822,
  Rip           = 1079,
  SavageRoar    = 52610,
  FerociousBite = 22568,
  TigersFury    = 5217,

  -- Forms (useful for detection)
  CatForm       = 768,
  BearForm      = 5487,
}

DR.Rank = {
  -- Balance
  Wrath         = {5176, 5177, 5178, 5179, 5180, 6780, 8905, 9912, 9913, 26984, 26985, 48459, 48461},
  Moonfire      = {8921, 8924, 8925, 8926, 8927, 8928, 8929, 9833, 9834, 9835, 26987, 26988, 48462, 48463},
  Starfire      = {2912, 8949, 8950, 8951, 9875, 9876, 25298, 26986, 48464, 48465},
  InsectSwarm   = {5570, 24974, 24975, 24976, 24977, 27013, 48468, 48469},
  Starfall      = {48505, 53199, 53200, 53201},
  ForceOfNature = {33831},

  -- Feral (Cat)
  MangleCat     = {33876, 33982, 33983, 48565, 48566},
  Shred         = {5221, 6800, 8992, 9829, 9830, 27001, 27002, 48571, 48572},
  Rake          = {1822, 1823, 1824, 9904, 27003, 48573, 48574},
  Rip           = {1079, 9492, 9493, 9752, 9894, 9896, 27008, 49799, 49800},
  SavageRoar    = {52610},
  FerociousBite = {22568, 22827, 22828, 22829, 31018, 24248, 48576, 48577},
  TigersFury    = {5217, 6793, 9845, 9846, 50212, 50213},

  -- Forms
  CatForm       = {768},
  BearForm      = {5487},
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

  -- Final fallback: return the lowest rank
  return list[1]
end

function DR.UpdateRanks(self)
  for key, list in pairs(self.Rank) do
    local id = bestRank(list)
    if id then self.Ability[key] = id end
  end
end

-- Export
_G.TacoRot_IDS_Druid = DR

-- ===== Icon fallbacks (kept; set only if not already defined) =====
_G.TacoRotIconFallbacks = _G.TacoRotIconFallbacks or {}
local fb = _G.TacoRotIconFallbacks
local function setOnce(id, tex) if id and not fb[id] then fb[id] = tex end end

-- Balance
setOnce(5176,  "Interface\\Icons\\Spell_Nature_AbolishMagic")      -- Wrath
setOnce(8921,  "Interface\\Icons\\Spell_Nature_StarFall")          -- Moonfire
setOnce(2912,  "Interface\\Icons\\Spell_Arcane_StarFire")          -- Starfire
setOnce(5570,  "Interface\\Icons\\Spell_Nature_InsectSwarm")       -- Insect Swarm
setOnce(48505, "Interface\\Icons\\Ability_Druid_Starfall")         -- Starfall
setOnce(33831, "Interface\\Icons\\Ability_Druid_ForceofNature")    -- Treants

-- Feral
setOnce(33876, "Interface\\Icons\\Ability_Druid_Mangle2")          -- Mangle (Cat)
setOnce(5221,  "Interface\\Icons\\Ability_Druid_Shred")            -- Shred
setOnce(1822,  "Interface\\Icons\\Ability_Druid_Disembowel")       -- Rake
setOnce(1079,  "Interface\\Icons\\Ability_GhoulFrenzy")            -- Rip
setOnce(52610, "Interface\\Icons\\Ability_Druid_SkinTeeth")        -- Savage Roar
setOnce(22568, "Interface\\Icons\\Ability_Druid_FerociousBite")    -- Ferocious Bite
setOnce(5217,  "Interface\\Icons\\Ability_Mount_JungleTiger")      -- Tiger’s Fury

-- Forms
setOnce(768,   "Interface\\Icons\\Ability_Druid_CatForm")          -- Cat Form
setOnce(5487,  "Interface\\Icons\\Ability_Racial_BearForm")        -- Bear Form

return DR
