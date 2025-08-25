-- Compat-335.lua — tiny helpers for 3.3.5
-- Was: t...t+1] (syntax error) which can abort TOC processing on some clients.

local function _to(...)
  local t = {}
  for i = 1, select("#", ...) do
    t[#t + 1] = tostring(select(i, ...))
  end
  return table.concat(t, " ")
end

_G.TacoRot_ToStringAll = _to
