-- TacoRot_Profiler.lua
local TR = _G.TacoRot
local ns = TR.ns

local function t() return debugprofilestop() end

local prof = { events = {}, frames = {} }
ns.prof = prof

function ns.ProfileCPU(key, fn)
  return function(...)
    local s = t()
    local r = { fn(...) }
    local d = t() - s
    local e = prof.events[key] or { calls=0, total=0, max=0 }
    e.calls = e.calls + 1; e.total = e.total + d; if d > e.max then e.max = d end
    prof.events[key] = e
    return unpack(r)
  end
end

function ns.ProfileFrame(key, fn)
  return function(elapsed)
    local s = t(); fn(elapsed); local d = t() - s
    local f = prof.frames[key] or { calls=0, total=0, max=0 }
    f.calls = f.calls + 1; f.total = f.total + d; if d > f.max then f.max = d end
    prof.frames[key] = f
  end
end

-- Debug slash to print a quick summary
SLASH_TACOROTPROF1 = "/trprof"
SlashCmdList.TACOROTPROF = function()
  DEFAULT_CHAT_FRAME:AddMessage("|cff00ffffTacoRot profiler|r")
  for k,v in pairs(prof.events) do
    DEFAULT_CHAT_FRAME:AddMessage(("%s: calls=%d total=%.1fms max=%.2fms")
      :format(k, v.calls, v.total, v.max))
  end
end
