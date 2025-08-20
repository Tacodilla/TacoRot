local TR = _G.TacoRot
if not TR then return end

TR.Predict = TR.Predict or {}
local P = TR.Predict

-- ===== Timing helpers =====
function P.Known(id)
  return id and (IsPlayerSpell and IsPlayerSpell(id) or (IsSpellKnown and IsSpellKnown(id)))
end

function P.ReadyNow(id)
  if not P.Known(id) then return false end
  local s,d,en = GetSpellCooldown(id)
  if en==0 then return false end
  return (not s or s==0 or d==0)
end

function P.CurrentGCD()
  local haste = UnitSpellHaste("player") or 0
  local gcd = 1.5 / (1 + haste/100)
  if gcd < 1.0 then gcd = 1.0 end
  return gcd
end

function P.Latency()
  local _,_,home,world = GetNetStats()
  local l = home or 0
  if world and world>l then l=world end
  return (l or 0)/1000
end

local function PadCfg(token)
  local db = TR.db and TR.db.profile
  if not db then return {enabled=true,gcd=1.6,latency=true} end
  db.pad = db.pad or {}
  local pad = db.pad[token]
  if not pad then pad = {enabled=true,gcd=1.6,latency=true}; db.pad[token]=pad end
  if pad.enabled==nil then pad.enabled=true end
  pad.gcd = pad.gcd or 1.6
  if pad.latency==nil then pad.latency=true end
  return pad
end

function P.ReadySoon(id, token)
  local pad = PadCfg(token or select(2,UnitClass("player")))
  if not pad.enabled then return P.ReadyNow(id) end
  if not P.Known(id) then return false end
  local start,dur,en = GetSpellCooldown(id)
  if en==0 then return false end
  if (not start or start==0 or dur==0) then return true end
  local remaining = start + dur - GetTime()
  local gcd = P.CurrentGCD()
  local latency = pad.latency and P.Latency() or 0
  return remaining <= (pad.gcd + gcd - latency)
end

-- ===== Aura cache =====
local buffCache, debuffCache = {}, {}

local function BuildBuffCache(u)
  local c = {}
  for i=1,40 do
    local name,_,_,_,_,_,expires,_,_,_,id = UnitBuff(u,i)
    if not name then break end
    c[id] = expires or 0
  end
  buffCache[u]=c
end

local function BuildDebuffCache(u)
  local c = {}
  for i=1,40 do
    local name,_,_,_,_,_,expires,caster,_,_,id = UnitDebuff(u,i)
    if not name then break end
    c[id] = {exp=expires or 0, caster=caster}
  end
  debuffCache[u]=c
end

function P.ClearCache()
  wipe(buffCache)
  wipe(debuffCache)
end

function P.BuffUp(u,id)
  local c = buffCache[u]
  if not c then BuildBuffCache(u); c=buffCache[u] end
  local exp = c[id]
  return exp and exp>GetTime()
end

function P.BuffRemaining(u,id)
  local c = buffCache[u]
  if not c then BuildBuffCache(u); c=buffCache[u] end
  local exp = c[id]
  return (exp and exp>GetTime()) and (exp-GetTime()) or 0
end

function P.DebuffUp(u,id)
  local c = debuffCache[u]
  if not c then BuildDebuffCache(u); c=debuffCache[u] end
  local info = c[id]
  return info and info.caster=="player" and info.exp>GetTime()
end

function P.DebuffRemaining(u,id)
  local c = debuffCache[u]
  if not c then BuildDebuffCache(u); c=debuffCache[u] end
  local info = c[id]
  if info and info.caster=="player" and info.exp then
    local r = info.exp - GetTime()
    if r>0 then return r end
  end
  return 0
end

function P.ShouldRefreshDebuff(u,id,threshold)
  threshold = threshold or (TR.db and TR.db.profile.dotThreshold) or 0
  if not P.DebuffUp(u,id) then return true end
  return P.DebuffRemaining(u,id) <= threshold
end

-- ===== Movement & range =====
function P.PlayerMoving()
  return (GetUnitSpeed("player") or 0) > 0
end

function P.HaveTarget()
  return UnitExists("target") and not UnitIsDead("target")
end

function P.InMelee()
  return CheckInteractDistance and CheckInteractDistance("target",3)
end

function P.InRanged()
  return CheckInteractDistance and CheckInteractDistance("target",4)
end

-- ===== Enemy counting for auto-AoE =====
P._recentGUID = P._recentGUID or {}
local frame = CreateFrame("Frame")
frame:RegisterEvent("COMBAT_LOG_EVENT_UNFILTERED")
frame:SetScript("OnEvent", function()
  local _,_,_,srcGUID,_,_,_,destGUID = CombatLogGetCurrentEventInfo()
  if srcGUID == UnitGUID("player") or srcGUID == UnitGUID("pet") then
    P._recentGUID[destGUID] = GetTime()
  end
end)

function P.EnemyCount()
  local now = GetTime()
  local n = 0
  for k,t in pairs(P._recentGUID) do
    if now - t < 5 then
      n = n + 1
    else
      P._recentGUID[k] = nil
    end
  end
  return n
end

function P.AoEActive()
  if TR.db and TR.db.profile.autoAoE then
    return P.EnemyCount() >= 3
  else
    return TR.db and TR.db.profile.aoe
  end
end

return P
