-- TacoRot_Keybinds.lua
local TR = _G.TacoRot
local ns = TR.ns
local pending = false

local function getBindingFor(action)
  -- e.g. "ACTIONBUTTON1" or "MULTIACTIONBAR1BUTTON1"
  local k1, k2 = GetBindingKey(action)
  return k1 or k2
end
ns.GetBindingFor = getBindingFor

local function refreshBindings()
  pending = false
  if TR.RefreshHotkeys then TR.RefreshHotkeys(getBindingFor) end
end

local function queueRefresh()
  if pending then return end
  pending = true
  ns.OnFrame(function(elapsed)
    if not pending then return end
    pending = false
    refreshBindings()
  end)
end

ns.RegisterEvent("UPDATE_BINDINGS", queueRefresh)
ns.RegisterEvent("PLAYER_LOGIN",   queueRefresh)
