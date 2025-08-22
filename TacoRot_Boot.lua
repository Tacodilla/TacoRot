-- TacoRot_Boot.lua (Wrath 3.3.5a)
local addonName = ...
_G.TacoRot = _G.TacoRot or {}
local TR = _G.TacoRot

-- Namespace table for internal modules.
TR.ns = TR.ns or {}

-- Minimal settings so UI code that expects AceDB-like tables won't explode.
TR.DB = TR.DB or {
  profile = {
    displays = TR.DB and TR.DB.profile and TR.DB.profile.displays or {},
    specs    = TR.DB and TR.DB.profile and TR.DB.profile.specs or {},
    notifications = { enabled = true },
    toggles = {
      cooldowns  = { value = true },
      interrupts = { value = true },
      defensives = { value = true },
    },
  }
}
