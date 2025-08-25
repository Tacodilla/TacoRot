
-- engine_mage.lua — TacoRot Mage (3.3.5)
-- OOC buff padding expanded: choose best Armor (Molten> Mage> Ice> Frost), and keep Arcane Intellect/Brilliance up.

local TR = _G.TacoRot
if not TR then return end

local function ResolveIDS()
  local t
  t = _G.TacoRot_IDS_Mage; if type(t)=="table" and (t.Ability or t.Rank) then return t end
  t = _G.TacoRot_IDS_MAGE; if type(t)=="table" and (t.Ability or t.Rank) then return t end
  t = _G.TacoRot_IDS; if type(t)=="table" and (t.Ability or t.Rank) then return t end
  return nil
end
local IDS = ResolveIDS() or {}; local A = IDS.Ability
-- SAFE fallback constant (should be at top of each engine file)
local SAFE = 6603  -- Attack spell ID - universally available

local function PrimaryTab() local n=(GetNumTalentTabs and GetNumTalentTabs()) or 3; local b,p=1,-1; for i=1,n do local _,_,pt=GetTalentTabInfo(i); pt=pt or 0; if pt>p then b,p=i,pt end end return b end
local function SpecName() local tab=PrimaryTab(); if tab==1 then return "Arcane" elseif tab==2 then return "Fire" else return "Frost" end end

local TOKEN = "MAGE"
local function Pad() local p=TR and TR.db and TR.db.profile and TR.db.profile.pad; local v=p and p[TOKEN]; if not v then return {enabled=true,gcd=1.6} end; if v.enabled==nil then v.enabled=true end; v.gcd=v.gcd or 1.6; return v end
local function BuffCfg() local p=TR and TR.db and TR.db.profile and TR.db.profile.buff; return (p and p[TOKEN]) or {enabled=true} end

local function Known(id) return id and (IsPlayerSpell and IsPlayerSpell(id) or (IsSpellKnown and IsSpellKnown(id))) end
local function ReadyNow(id)
  if not Known(id) then return false end
  local s,d,en = GetSpellCooldown(id)
  if en == 0 then return false end
  return (not s or s==0 or d==0)
end
local function ReadySoon(id)
  local pad = Pad()
  if not pad.enabled then return ReadyNow(id) end
  if not Known(id) then return false end
  local start, duration, enabled = GetSpellCooldown(id)
  if enabled == 0 then return false end
  if (not start or start == 0 or duration == 0) then return true end
  local gcd = 1.5
  local remaining = (start + duration) - GetTime()
  return remaining <= (pad.gcd + gcd)
end
local function BuffUpID(u, id) if not id then return false end local wanted=GetSpellInfo(id) for i=1,40 do local name=UnitBuff(u,i); if not name then break end if name==wanted then return true end end return false end
local function DebuffUpID(u, id) if not id then return false end local wanted=GetSpellInfo(id) for i=1,40 do local name,_,_,_,_,_,_,caster,_,_,sid=UnitDebuff(u,i); if not name then break end if sid==id or (name==wanted and caster=="player") then return true end end return false end
local function Push(q,id) if id then q[#q+1]=id end end
local function pad3(q, fb) q[1]=q[1] or fb; q[2]=q[2] or q[1]; q[3]=q[3] or q[2]; return q end
local function HaveTarget() return UnitExists("target") and not UnitIsDead("target") end

-- Fallback safe
local function Fallback()
  return SAFE
end

-- Armor choice
local function ArmorID()
  if A then
    if A.MoltenArmor and Known(A.MoltenArmor) then return A.MoltenArmor end
    if A.MageArmor and Known(A.MageArmor) then return A.MageArmor end
    if A.IceArmor and Known(A.IceArmor) then return A.IceArmor end
    if A.FrostArmor and Known(A.FrostArmor) then return A.FrostArmor end
  end
  local molten = 43045; if Known(molten) then return molten end
  local mage   = 43024; if Known(mage)   then return mage end
  local ice    = 43008; if Known(ice)    then return ice end
  local frost  = 168;   if Known(frost)  then return frost end
end

-- Intellect choice
local function IntellectID()
  if A then
    if A.ArcaneBrilliance and Known(A.ArcaneBrilliance) then return A.ArcaneBrilliance end
    if A.ArcaneIntellect and Known(A.ArcaneIntellect) then return A.ArcaneIntellect end
  end
  local br = 43002; if Known(br) then return br end -- Arcane Brilliance
  local ai = 42995; if Known(ai) then return ai end -- Arcane Intellect (high rank)
  return 1459 -- Arcane Intellect rank 1
end

local function BuildBuffQueue()
  local cfg = BuffCfg(); if not (cfg.enabled ~= false) then return end
  local q = {}
  if (cfg.armor ~= false) then
    local armor = ArmorID(); if armor and not BuffUpID("player", armor) and ReadySoon(armor) then Push(q, armor) end
  end
  if (cfg.intellect ~= false) then
    local intel = IntellectID(); if intel and not BuffUpID("player", intel) and ReadySoon(intel) then Push(q, intel) end
  end
  return q
end

-- DPS
local function BuildQueue()
  local q = {}
  local tab = PrimaryTab()
  if tab == 1 then
    if A and ReadySoon(A.ArcaneMissiles) and BuffUpID("player", 44401) then Push(q, A.ArcaneMissiles) end
    if A and ReadySoon(A.ArcaneBlast) then Push(q, A.ArcaneBlast) end
    if A and ReadySoon(A.ArcaneBarrage) then Push(q, A.ArcaneBarrage) end
  elseif tab == 2 then
    if A and ReadySoon(A.Pyroblast) and BuffUpID("player", 48108) then Push(q, A.Pyroblast) end
    if A and A.LivingBomb and not DebuffUpID("target", A.LivingBomb) and ReadySoon(A.LivingBomb) then Push(q, A.LivingBomb) end
    if A and ReadySoon(A.Fireball) then Push(q, A.Fireball) end
    if A and ReadySoon(A.Scorch) then Push(q, A.Scorch) end
  else
    if A and ReadySoon(A.FrostfireBolt) and BuffUpID("player", 57761) then Push(q, A.FrostfireBolt) end
    if A and ReadySoon(A.IceLance) and BuffUpID("player", 44544) then Push(q, A.IceLance) end
    if A and ReadySoon(A.Frostbolt) then Push(q, A.Frostbolt) end
  end
  return pad3(q, SAFE)
end

function TR:EngineTick_Mage()
  IDS = ResolveIDS() or IDS; A = (IDS and IDS.Ability) or A
  if IDS and IDS.UpdateRanks then pcall(IDS.UpdateRanks, IDS) end

  local q
  if not A or not next(A) then
    local fb = Fallback()
    q = {fb,fb,fb}
  elseif not UnitAffectingCombat("player") then
    q = BuildBuffQueue() or BuildQueue()
    if not (q and q[1]) then q = BuildQueue() end
  else
    q = BuildQueue()
  end

  q = pad3(q or {}, Fallback())
  -- DEBUG: Add this TEMPORARILY to troubleshoot (remove after fixing)
  if not q or not q[1] then
    DEFAULT_CHAT_FRAME:AddMessage("|cff55ff55[TacoRot DEBUG]|r Empty queue for " .. (UnitClass("player") or "Unknown"))
    DEFAULT_CHAT_FRAME:AddMessage("|cff55ff55[TacoRot DEBUG]|r A table: " .. tostring(A and next(A) and "has spells" or "empty/nil"))
  end
  self._lastMainSpell = q[1]

  -- Standardized UI update call
  if TR.UI_Update then
    TR.UI_Update(q[1], q[2], q[3])
  elseif self.UI and self.UI.Update then
    self.UI:Update(q[1], q[2], q[3])
  end
end

function TR:StartEngine_Mage()
  self:StopEngine_Mage(); self:EngineTick_Mage()
  local AceTimer=LibStub and LibStub("AceTimer-3.0",true)
  if AceTimer and AceTimer.ScheduleRepeatingTimer then
    self._engineTimer_MA = AceTimer:ScheduleRepeatingTimer(function() _G.TacoRot:EngineTick_Mage() end, 0.20)
  else
    local acc,f=0,CreateFrame("Frame"); f:SetScript("OnUpdate", function(_,e) acc=acc+(e or 0); if acc>=0.20 then acc=acc-0.20; _G.TacoRot:EngineTick_Mage() end end); self._engineTimer_MA=f
  end
  self:Print("TacoRot Mage engine active: "..SpecName())
end
function TR:StopEngine_Mage()
  local t=self._engineTimer_MA; if not t then return end
  local AceTimer=LibStub and LibStub("AceTimer-3.0",true)
  if AceTimer and type(t)=="number" then AceTimer:CancelTimer(t,true) elseif type(t)=="table" and t.SetScript then t:SetScript("OnUpdate",nil); t:Hide() end
  self._engineTimer_MA=nil
end

do local _,c=UnitClass("player"); if c=="MAGE" then TR:StartEngine_Mage() end end
