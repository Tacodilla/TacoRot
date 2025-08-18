-- paladin_ids.lua — TacoRot IDs for Paladin (3.3.5)
-- Added Seal of Righteousness (private server) so the engine can prefer it.

local t = _G.TacoRot_IDS_Paladin or {}
_G.TacoRot_IDS_Paladin = t

t.Ability = t.Ability or {
  -- Core DPS
  JudgementOfWisdom = 53408,
  JudgementOfLight  = 20271,
  DivineStorm       = 53385,
  CrusaderStrike    = 35395,
  Consecration      = 48819, -- rank up handled below if you want to expand
  Exorcism          = 48801,
  HammerOfWrath     = 48806,

  -- Seals
  SealOfVengeance     = 31801,
  SealOfCorruption    = 53736,
  -- Private-server first instant cast:
  SealOfRighteousness = 84508,
}

-- Optional: simple rank promotion hook
function t.UpdateRanks(self)
  -- no-op for now; place rank-resolution if you want to switch IDs per rank
  return self
end
