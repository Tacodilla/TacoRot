-- TacoRot_CastTracker.lua
local TR, ns = _G.TacoRot, _G.TacoRot.ns
TR.cast = TR.cast or { active = nil, last = nil }

local function start(_, unit, lineID, spellID)
  if unit ~= "player" then return end
  TR.cast.active = { id = spellID, lineID = lineID, started = GetTime() }
  if TR.OnCastStart then TR.OnCastStart(TR.cast.active) end
end

local function stop(_, unit, lineID, spellID)
  if unit ~= "player" then return end
  TR.cast.last = TR.cast.active
  TR.cast.active = nil
  if TR.OnCastStop then TR.OnCastStop(lineID, spellID) end
end

ns.RegisterEvent("UNIT_SPELLCAST_START", start)
ns.RegisterEvent("UNIT_SPELLCAST_CHANNEL_START", start)
ns.RegisterEvent("UNIT_SPELLCAST_STOP", stop)
ns.RegisterEvent("UNIT_SPELLCAST_CHANNEL_STOP", stop)
ns.RegisterEvent("UNIT_SPELLCAST_SUCCEEDED", function(_, unit, lineID, spellID)
  if unit ~= "player" then return end
  if TR.OnCastSucceeded then TR.OnCastSucceeded(lineID, spellID) end
end)
