-- engine_hunter.lua — 3.3.5 Hunter engine (load-order proof)
-- Binds to TacoRot core after it's ready and starts even if AceTimer is missing.

DEFAULT_CHAT_FRAME:AddMessage("|cff55ff55[TacoRot]|r Hunter engine file loaded")

local IDS = _G.TacoRot_IDS_Hunter
local GCD_CUTOFF = 1.6

-- ===== helpers =====
local function Known(id) return id and IsSpellKnown and IsSpellKnown(id) end

local function ReadyNow(id)
  if not Known(id) then return false end
  local s,d,en = GetSpellCooldown(id); if en == 0 then return false end
  return (not s or s == 0 or d == 0)
end

local function ReadySoon(id)
  if not Known(id) then return false end
  local s,d,en = GetSpellCooldown(id); if en == 0 then return false end
  if (not s or s == 0 or d == 0) then return true end
  return (s + d - GetTime()) <= GCD_CUTOFF
end

local function DebuffUp(unit, spellID)
  if not spellID then return false end
  local wanted = GetSpellInfo(spellID)
  for i = 1, 40 do
    local name, _, _, _, _, _, _, caster, _, _, id = UnitDebuff(unit, i)
    if not name then break end
    if id == spellID or (name == wanted and caster == "player") then return true end
  end
  return false
end

local function InMelee()  return CheckInteractDistance("target", 3) end
local function InRanged() return CheckInteractDistance("target", 4) end
local function HaveTarget() return UnitExists("target") and not UnitIsDead("target") end

local function AutoShotActive()
  local A = IDS and IDS.Ability or {}
  local n = (A.AutoShot and GetSpellInfo(A.AutoShot)) or "Auto Shot"
  local ok = IsAutoRepeatSpell and IsAutoRepeatSpell(n)
  return ok == 1 or ok == true
end

local function Fallback(A)
  return (Known(A.AutoShot) and A.AutoShot)
      or (Known(A.RaptorStrike) and A.RaptorStrike)
      or A.AutoShot or A.RaptorStrike or 75
end

local function Push(q,id) if id then q[#q+1]=id end end

local function BuildQueue()
  if IDS and IDS.UpdateRanks then IDS:UpdateRanks() end
  local A = IDS and IDS.Ability or {}
  local q = {}

  if not HaveTarget() then local fb=Fallback(A); q[1],q[2],q[3]=fb,fb,fb; return q end

  -- Out-of-combat niceties
  if not UnitAffectingCombat("player") then
    if ReadyNow(A.HuntersMark) and not DebuffUp("target", A.HuntersMark) then Push(q, A.HuntersMark) end
    if InRanged() and not AutoShotActive() and A.AutoShot then table.insert(q,1,A.AutoShot) end
  end

  if InMelee() then
    if ReadyNow(A.RaptorStrike) then table.insert(q,1,A.RaptorStrike) end
    if #q < 3 and ReadySoon(A.WingClip) then Push(q, A.WingClip) end
  else
    if ReadySoon(A.AimedShot)   then Push(q, A.AimedShot) end
    if ReadySoon(A.MultiShot)   then Push(q, A.MultiShot) end
    if ReadySoon(A.ArcaneShot)  then Push(q, A.ArcaneShot) end
    if #q < 3 and A.SerpentSting and not DebuffUp("target", A.SerpentSting) and ReadySoon(A.SerpentSting) then
      Push(q, A.SerpentSting)
    end
    if #q < 1 and A.AutoShot then Push(q, A.AutoShot) end
  end

  q[1] = q[1] or Fallback(A)
  q[2] = q[2] or q[1]
  q[3] = q[3] or q[2]
  return q
end

-- ===== attach to core when ready (no race conditions) =====
local function AttachHunter()
  local TR = _G.TacoRot
  if not TR or TR._hunter_bound then return end

  -- Ensure ranks ready before first tick
  if IDS and IDS.UpdateRanks then IDS:UpdateRanks() end

  function TR:EngineTick_Hunter()
    local q = BuildQueue()
    if self.UI and self.UI.Update then
      self.UI:Update(q[1], q[2], q[3])
    else
      -- Fallback direct texture set if core ApplyIcon isn’t present
      local fb = _G.TacoRotIconFallbacks or {}
      if TacoRotWindow  and TacoRotWindow.icon  then TacoRotWindow.icon:SetTexture(GetSpellTexture(q[1]) or fb[q[1]]) end
      if TacoRotWindow2 and TacoRotWindow2.icon then TacoRotWindow2.icon:SetTexture(GetSpellTexture(q[2]) or fb[q[2]]) end
      if TacoRotWindow3 and TacoRotWindow3.icon then TacoRotWindow3.icon:SetTexture(GetSpellTexture(q[3]) or fb[q[3]]) end
    end
  end

  function TR:StartEngine_Hunter()
    if self._engineTimerHT then return end
    if IDS and IDS.UpdateRanks then IDS:UpdateRanks() end
    self:EngineTick_Hunter()
    if self.ScheduleRepeatingTimer then
      self._engineTimerHT = self:ScheduleRepeatingTimer("EngineTick_Hunter", 0.2)
      DEFAULT_CHAT_FRAME:AddMessage("|cff55ff55[TacoRot]|r Hunter engine started (AceTimer)")
    else
      local f = CreateFrame("Frame")
      f._t = 0
      f:SetScript("OnUpdate", function(s,e)
        s._t = s._t + e
        if s._t >= 0.2 then s._t = 0; if TR.EngineTick_Hunter then TR:EngineTick_Hunter() end end
      end)
      self._engineTimerHT = f
      DEFAULT_CHAT_FRAME:AddMessage("|cff55ff55[TacoRot]|r Hunter engine started (OnUpdate)")
    end
  end

  function TR:StopEngine_Hunter()
    if not self._engineTimerHT then return end
    local t = self._engineTimerHT
    if type(t)=="table" and t.Cancel then self:CancelTimer(t)
    elseif type(t)=="table" and t.SetScript then t:SetScript("OnUpdate", nil); t:Hide() end
    self._engineTimerHT = nil
  end

  -- If already on a Hunter, start immediately
  local _, class = UnitClass("player")
  if class == "HUNTER" then TR:StartEngine_Hunter() end

  TR._hunter_bound = true
  DEFAULT_CHAT_FRAME:AddMessage("|cff55ff55[TacoRot]|r Hunter engine bound to core")
end

-- Bind now or when TacoRot finishes loading
if _G.TacoRot then
  AttachHunter()
else
  local f = CreateFrame("Frame")
  f:RegisterEvent("ADDON_LOADED")
  f:SetScript("OnEvent", function(_,_,addon)
    if addon == "TacoRot" then AttachHunter(); f:UnregisterAllEvents(); f:Hide() end
  end)
end
