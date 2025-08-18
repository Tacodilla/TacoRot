-- engine_druid.lua — TacoRot Druid (Balance/Feral), 3.3.5
-- Single startup log, Wrath-only previews until Moonfire, flash-friendly.

local Engine = {}
_G.TacoRot_Engine_Druid = Engine

-- ===== Helpers =====
local SI = GetSpellInfo
local function buffUP(u,n)   return UnitBuff(u,n)   ~= nil end
local function debuffUP(u,n) return UnitDebuff(u,n) ~= nil end
local function gcdReady() local s,d=GetSpellCooldown(61304); return (s==0) or ((s+d-GetTime())<=0) end
local function cp() return GetComboPoints("player","target") end
local function HasSpell(id) return id and IsSpellKnown and IsSpellKnown(id) or false end
local function ABILS() local t=_G.TacoRot_IDS_Druid; return t and t.Ability or nil, t end

-- ===== Spec detect (level 1–10 safe) =====
local function level() return UnitLevel("player") or 1 end
local function points(i) local _,_,p=GetTalentTabInfo(i,"player"); return p or 0 end
local CAT_FORM_NAME = GetSpellInfo(768)
local function inCat()
  local i=1; while true do local name=UnitBuff("player",i); if not name then break end; if name==CAT_FORM_NAME then return true end; i=i+1 end
  for idx=1,(GetNumShapeshiftForms() or 0) do local _,name,active=GetShapeshiftFormInfo(idx); if active and name==CAT_FORM_NAME then return true end end
  return false
end
local function manaUser() local _,pt=UnitMana("player"),UnitPowerType("player"); return pt==0 end
local function detectSpec()
  if level()<10 then return (inCat() or not manaUser()) and "FERAL" or "BALANCE" end
  local b,f,r=points(1),points(2),points(3); if r>math.max(b,f) then return "UNSUPPORTED" end
  return (f>b) and "FERAL" or "BALANCE"
end

-- ===== Priorities =====
local function balancePrio(A)
  if not A then return nil end
  if not HasSpell(A.Moonfire) and HasSpell(A.Wrath) then return A.Wrath end -- level 1–3
  if HasSpell(A.Moonfire)    and not debuffUP("target", SI(A.Moonfire))    then return A.Moonfire end
  if HasSpell(A.InsectSwarm) and not debuffUP("target", SI(A.InsectSwarm)) then return A.InsectSwarm end
  if HasSpell(A.Starfall)    and IsUsableSpell(A.Starfall) and gcdReady()  then return A.Starfall end
  if HasSpell(A.Starfire)    and IsUsableSpell(A.Starfire)                 then return A.Starfire end
  if HasSpell(A.Wrath)                                                         then return A.Wrath end
  return nil
end
local function feralCatPrio(A)
  if not A then return nil end
  if HasSpell(A.SavageRoar) and cp()>=1 and not buffUP("player",SI(A.SavageRoar)) then return A.SavageRoar end
  if HasSpell(A.Rake)       and not debuffUP("target",SI(A.Rake))                 then return A.Rake end
  local hasMangle = HasSpell(A.MangleCat) and debuffUP("target", SI(A.MangleCat)) or debuffUP("target","Trauma")
  if HasSpell(A.MangleCat)  and not hasMangle                                     then return A.MangleCat end
  if HasSpell(A.Shred)      and cp()<5                                           then return A.Shred end
  if HasSpell(A.Rip)        and IsUsableSpell(A.Rip)                              then return A.Rip end
  if HasSpell(A.FerociousBite)                                                   then return A.FerociousBite end
  return nil
end

-- ===== Lifecycle =====
function Engine:Ready()
  local A = ABILS(); if not A then return false,"IDs" end
  local TR=_G.TacoRot; if not (TR and TR.UI and TR.UI.Update) then return false,"UI" end
  return true
end
function Engine:Init()
  local TR=_G.TacoRot
  local _,ids=ABILS(); if ids and ids.UpdateRanks then pcall(ids.UpdateRanks,ids) end
  self.mode = detectSpec()
  -- Single per-class startup line
  TR:Print(("TacoRot Druid engine active: %s"):format(self.mode))
end

-- Keep first icon and flash in sync
local function SetFirst(TR, main, next1, next2)
  TR._lastMainSpell = main or TR._lastMainSpell
  TR.UI:Update(main, next1, next2)
end

function Engine:Tick()
  local TR=_G.TacoRot; if not (TR and TR.UI and TR.UI.Update) then return end
  local A,ids=ABILS(); if not A then TR.UI:Update(nil,nil,nil); return end
  if not self._ranksOK and ids and ids.UpdateRanks then self._ranksOK = pcall(ids.UpdateRanks, ids) end

  if self.mode=="UNSUPPORTED" or not InCombatLockdown() then
    if self.mode=="BALANCE" then
      if not HasSpell(A.Moonfire) then
        local w = HasSpell(A.Wrath) and A.Wrath or nil
        SetFirst(TR, w, nil, nil)
      else
        SetFirst(TR,
          HasSpell(A.Wrath) and A.Wrath or nil,
          HasSpell(A.Moonfire) and A.Moonfire or nil,
          HasSpell(A.Starfire) and A.Starfire or nil)
      end
    elseif self.mode=="FERAL" then
      SetFirst(TR,
        HasSpell(A.Rake) and A.Rake or nil,
        HasSpell(A.MangleCat) and A.MangleCat or nil,
        HasSpell(A.Shred) and A.Shred or nil)
    else
      TR.UI:Update(nil,nil,nil)
    end
    return
  end

  local nextID
  if self.mode=="BALANCE" then
    nextID = balancePrio(A)
    if not HasSpell(A.Moonfire) then
      local w = HasSpell(A.Wrath) and A.Wrath or nil
      SetFirst(TR, nextID or w, nil, nil)
    else
      SetFirst(TR, nextID,
        HasSpell(A.Moonfire) and A.Moonfire or nil,
        HasSpell(A.Starfire) and A.Starfire or nil)
    end
  elseif self.mode=="FERAL" then
    nextID = feralCatPrio(A)
    SetFirst(TR, nextID,
      HasSpell(A.SavageRoar) and A.SavageRoar or nil,
      HasSpell(A.Rake) and A.Rake or nil)
  else
    TR.UI:Update(nil,nil,nil)
  end
end

-- ===== Bind Start/Stop to addon (quiet) =====
local function bindToAddon(addon)
  if addon._druidBound then return end
  function addon:StartEngine_Druid()
    if self._drTicker then self:StopEngine_Druid() end
    local E=_G.TacoRot_Engine_Druid
    if self._drBoot then self:CancelTimer(self._drBoot) end
    E._bootTries=0
    self._drBoot = self:ScheduleRepeatingTimer(function()
      E._bootTries = E._bootTries + 1
      local ok = E:Ready()
      if ok then
        if self._drBoot then self:CancelTimer(self._drBoot); self._drBoot=nil end
        E:Init()
        self._drEngine = E
        self._drTicker = self:ScheduleRepeatingTimer(function() E:Tick() end, 0.10)
      elseif E._bootTries >= 50 then
        self:CancelTimer(self._drBoot); self._drBoot=nil
      end
    end, 0.10)
  end
  function addon:StopEngine_Druid()
    if self._drBoot   then self:CancelTimer(self._drBoot);   self._drBoot=nil end
    if self._drTicker then self:CancelTimer(self._drTicker); self._drTicker=nil end
    self._drEngine=nil
  end
  addon._druidBound = true
end

if _G.TacoRot then
  bindToAddon(_G.TacoRot)
else
  local binder=CreateFrame("Frame")
  binder:RegisterEvent("PLAYER_LOGIN")
  binder:SetScript("OnEvent", function(self)
    if _G.TacoRot then bindToAddon(_G.TacoRot) end
    self:UnregisterAllEvents(); self:SetScript("OnEvent", nil)
  end)
end

-- Optional PEW self-start for race conditions
local selfKick=CreateFrame("Frame")
selfKick:RegisterEvent("PLAYER_ENTERING_WORLD")
selfKick:SetScript("OnEvent", function()
  local TR=_G.TacoRot; if not TR then return end
  local _,class=UnitClass("player")
  if class=="DRUID" and TR.StartEngine_Druid and not TR._drStarted then
    TR:StartEngine_Druid(); TR._drStarted=true
  end
end)
