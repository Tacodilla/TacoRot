-- Compat-335.lua
local function _to(...) local t={} for i=1,select('#', ...) do t[#t+1]=tostring(select(i, ...)) end return table.concat(t,' ') end
_G.TacoRot_ToStringAll = _to
