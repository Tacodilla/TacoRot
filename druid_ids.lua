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

-- (Optional) stub if the core calls UpdateRanks; safe no-op
function DR.UpdateRanks(self)
  -- If you ever want rank promotion like Hunter’s ids.UpdateSpellID(),
  -- do it here. The engine currently gates by spell name (HasSpell)
  -- so base IDs are sufficient.
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
