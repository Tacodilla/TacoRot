-- engine_bootstrap.lua — safety net for class engines (3.3.5-safe)
-- Runs AFTER all engine_* files listed in the TOC.
-- If an engine didn't attach (nil StartEngine_*), we register a minimal fallback.

local TR = _G.TacoRot
if not TR then return end

local function Known(id) return id and IsSpellKnown and IsSpellKnown(id) end
local function ReadyNow(id)
  if not Known(id) then return false end
  local s,d,en = GetSpellCooldown(id); if en == 0 then return false end
  return (not s or s == 0 or d == 0)
end
local function ReadySoon(id)
  if not Known(id) then return false end
  local s,d,en = GetSpellCooldown(id); if en == 0 then return false end
  if not s or s == 0 or d == 0 then return true end
  return (s + d - GetTime()) <= 0.2
end
local function HaveTarget() return UnitExists("target") and UnitCanAttack("player","target") and not UnitIsDeadOrGhost("target") end
local function InMelee() return CheckInteractDistance("target", 3) == 1 end
local function DebuffUp(u, id)
  if not id then return false end
  local n = GetSpellInfo(id); if not n then return false end
  for i=1,40 do local a=UnitDebuff(u,i); if not a then break end; if a==n then return true end end
  return false
end
local function Push(q,id) if id then q[#q+1]=id end end

-- ===== HUNTER FALLBACK (only used if StartEngine_Hunter is nil) =====
local function ensureHunter()
  if TR.StartEngine_Hunter then return end

  local IDS = _G.TacoRot_IDS_Hunter
  local function Fallback(A)
    return (Known(A.AutoShot) and A.AutoShot)
        or (Known(A.RaptorStrike) and A.RaptorStrike)
        or A.AutoShot or A.RaptorStrike or 75
  end
  local function AutoShotActive()
    local A = IDS and IDS.Ability or {}
    local n = (A.AutoShot and GetSpellInfo(A.AutoShot)) or "Auto Shot"
    local ok = IsAutoRepeatSpell and IsAutoRepeatSpell(n)
    return ok==1 or ok==true
  end
  local function InRanged()
    local A = IDS and IDS.Ability or {}
    local n = A.ArcaneShot and GetSpellInfo(A.ArcaneShot)
    if n then local r=IsSpellInRange(n,"target"); return r==1 end
    return not InMelee()
  end

  local function BuildQueue()
    if IDS and IDS.UpdateRanks then IDS:UpdateRanks() end
    local A = IDS and IDS.Ability or {}
    local q = {}
    if not HaveTarget() then local fb=Fallback(A); q[1],q[2],q[3]=fb,fb,fb; return q end

    if not UnitAffectingCombat("player") then
      if ReadyNow(A.HuntersMark) and not DebuffUp("target", A.HuntersMark) then Push(q, A.HuntersMark) end
      if InRanged() and not AutoShotActive() and A.AutoShot then table.insert(q,1,A.AutoShot) end
    end

    if InMelee() then
      if ReadyNow(A.RaptorStrike) then table.insert(q,1,A.RaptorStrike) end
      if #q<3 and ReadySoon(A.WingClip) then Push(q,A.WingClip) end
    else
      if ReadyNow(A.SerpentSting) and not DebuffUp("target", A.SerpentSting) then Push(q,A.SerpentSting) end
      if #q<3 and ReadySoon(A.AimedShot)  then Push(q,A.AimedShot)  end
      if #q<3 and ReadySoon(A.ArcaneShot) then Push(q,A.ArcaneShot) end
      if #q<3 and A.AutoShot then Push(q,A.AutoShot) end
    end
    local fb = Fallback(A); while #q<3 do q[#q+1]=fb end
    return q
  end

  function TR:EngineTick_Hunter()
    local q = BuildQueue()
    self._lastMainSpell = q[1]
    if self.UI and self.UI.Update then
      self.UI.Update(q[1], q[2], q[3])
    elseif self.ApplyIcon then
      if not TacoRotWindow and self.CreateWindows then self:CreateWindows() end
      self:ApplyIcon(TacoRotWindow,  q[1])
      self:ApplyIcon(TacoRotWindow2, q[2])
      self:ApplyIcon(TacoRotWindow3, q[3])
    end
  end
  function TR:StartEngine_Hunter()
    if self._engineTimerHT then return end
    self:EngineTick_Hunter()
    self._engineTimerHT = self:ScheduleRepeatingTimer("EngineTick_Hunter", 0.2)
  end
  function TR:StopEngine_Hunter()
    if self._engineTimerHT then self:CancelTimer(self._engineTimerHT); self._engineTimerHT=nil end
  end

  TR:RegisterMessage("TACOROT_ENABLE_CLASS_MODULE", function()
    local _, class = UnitClass("player")
    if class == "HUNTER" then TR:StartEngine_Hunter() end
  end)

  DEFAULT_CHAT_FRAME:AddMessage("|cffffcc00[TacoRot]|r Hunter engine file missing; using fallback.")
end

-- You can add future safety nets here (e.g., ensureWarrior, ensureMage) if needed.

-- Run safety nets once UI and core are up.
ensureHunter()
