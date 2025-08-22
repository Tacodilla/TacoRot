-- TacoRot_EventCore.lua
local TR = _G.TacoRot
local ns = TR.ns

local evtFrame = CreateFrame("Frame")
local handlers = {}        -- event -> {fn, ...}
local frameHandlers = {}   -- ordered list of functions for "FRAME_UPDATE"

function ns.RegisterEvent(event, fn)
  handlers[event] = handlers[event] or {}
  table.insert(handlers[event], fn)
  if event ~= "FRAME_UPDATE" then evtFrame:RegisterEvent(event) end
end

function ns.UnregisterEvent(event, fn)
  local list = handlers[event]; if not list then return end
  for i=#list,1,-1 do if list[i] == fn then table.remove(list, i) end end
  if event ~= "FRAME_UPDATE" and (#(handlers[event] or {}) == 0) then
    evtFrame:UnregisterEvent(event)
  end
end

function ns.OnFrame(fn)
  table.insert(frameHandlers, fn)
end

evtFrame:SetScript("OnEvent", function(_, event, ...)
  local list = handlers[event]; if not list then return end
  for i=1,#list do list[i](event, ...) end
end)

evtFrame:SetScript("OnUpdate", function(_, elapsed)
  for i=1,#frameHandlers do frameHandlers[i](elapsed) end
end)

-- Useful defaults
ns.RegisterEvent("PLAYER_REGEN_DISABLED", function() TR.inCombat = true end)
ns.RegisterEvent("PLAYER_REGEN_ENABLED",  function() TR.inCombat = false end)
