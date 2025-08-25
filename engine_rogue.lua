-- engine_rogue.lua — TacoRot Rogue (3.3.5)
-- Adds Buff padding (OOC) and Pets maintenance (where applicable) for new-player accessibility.

local TR = _G.TacoRot
if not TR then return end

-- Resolve IDS table
local function ResolveIDS()
  local t
  t = _G.TacoRot_IDS_Rogue;       if type(t)=="table" and (t.Ability or t.Rank) then return t end
  t = _G.TacoRot_IDS_ROGUE;       if type(t)=="table" and (t.Ability or t.Rank) then return t end
  if type(_G.TacoRot_IDS)=="table" then
    t = _G.TacoRot_IDS["ROGUE"]; if type(t)=="table" and (t.Ability or t.Rank) then return t end
    t = _G.TacoRot_IDS["Rogue"]; if type(t)=="table" and (t.Ability or t.Rank) then return t end
    if _G.TacoRot_IDS.Ability then return _G.TacoRot_IDS end
  end
  return nil
end

local IDS = ResolveIDS() or {}; local A = IDS.Ability
local SAFE = 6603  -- Attack spell ID - universally available

-- Spec name
local function PrimaryTab() local n=(GetNumTalentTabs and GetNumTalentTabs()) or 3; local b,p=1,-1; for i=1,n do local _,_,pt=GetTalentTabInfo(i); pt=pt or 0; if pt>p then b,p=i,pt end end return b end
local function SpecName() local tab=PrimaryTab(); return (tab==1 and "Assassination") or (tab==2 and "Combat") or "Subtlety" end

-- Config
local TOKEN = "ROGUE"
local function Pad() local p=TR and TR.db and TR.db.profile and TR.db.profile.pad; local v=p and p[TOKEN]; if not v then return {enabled=true,gcd=1.6} end; if v.enabled==nil then v.enabled=true end; v.gcd=v.gcd or 1.6; return v end
local function BuffCfg() local p=TR and TR.db and TR.db.profile and TR.db.profile.buff; return (p and p[TOKEN]) or {enabled=true} end
local function PetCfg() local p=TR and TR.db and TR.db.profile and TR.db.profile.pet; return (p and p[TOKEN]) or {enabled=true} end

-- Helpers
local function Known(id) return id and (IsPlayerSpell and IsPlayerSpell(id) or (IsSpellKnown and IsSpellKnown(id))) end
local function ReadyNow(id) if not Known(id) then return false end local s,d,en = GetSpellCooldown(id); if en==0 then return false end return (not s or s==0 or d==0) end
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
local function DebuffUpID(u, id) if not id then return false end local wanted=GetSpellInfo(id) for i=1,40 do local name,_,_,_,_,_,_,caster,_,_,sid=UnitDebuff(u,i); if not name then break end if sid==id or (name==wanted and caster=="player") then return true end end return false end
local function BuffUpID(u, id) if not id then return false end local wanted=GetSpellInfo(id) for i=1,40 do local name=UnitBuff(u,i); if not name then break end if name==wanted then return true end end return false end
local function HaveTarget() return UnitExists("target") and not UnitIsDead("target") end
local function pad3(q, fb) q[1]=q[1] or fb; q[2]=q[2] or q[1]; q[3]=q[3] or q[2]; return q end
local function Push(q,id) if id then q[#q+1]=id end end

-- OOC Buffs

local function BuildBuffQueue()
  -- No persistent OOC self-buff for Rogue in Wrath by default (poisons are item buffs).
  return nil
end


-- Pets

local function BuildPetQueue() return nil end


-- DPS Priorities (existing style, trimmed)

local function BuildQueue()
  local q = {}
  local tree = PrimaryTab()
  if A and ReadySoon(A.Mutilate) then Push(q, A.Mutilate) end
  if A and ReadySoon(A.SinisterStrike) then Push(q, A.SinisterStrike) end
  if tree == 1 and A and ReadySoon(A.Envenom) then
    Push(q, A.Envenom)
  elseif A and ReadySoon(A.Eviscerate) then
    Push(q, A.Eviscerate)
  end
  return q
end

-- Add keybind updates to existing engine recommendations
local function UpdateKeybindsForRecommendations(recommendations)
  if not TR.UI or not TR.UI.icons then return end

  for i, spellID in ipairs(recommendations) do
    if TR.UI.icons[i] and spellID then
      local spellName = GetSpellInfo(spellID)
      if spellName then
        TR:UpdateIconKeybind(TR.UI.icons[i], spellName)
      end
    end
  end
end


function TR:EngineTick_Rogue()
  IDS = ResolveIDS() or IDS
  A = (IDS and IDS.Ability) or A
  if IDS and IDS.UpdateRanks then pcall(IDS.UpdateRanks, IDS) end

  local q = {}
  if not A or not next(A) then
    q = {SAFE,SAFE,SAFE}
  elseif not UnitAffectingCombat("player") then
    q = BuildPetQueue() or BuildBuffQueue() or {} -- prefer getting a pet up first
    if not q[1] then
      if HaveTarget() then q = BuildQueue() else q = {SAFE,SAFE,SAFE} end
    end
  else
    q = BuildQueue()
  end

  q = pad3(q or {}, SAFE)
  self._lastMainSpell = q[1]
  if self.UI and self.UI.Update then self.UI:Update(q[1], q[2], q[3]) end
  UpdateKeybindsForRecommendations({q[1], q[2], q[3]})
end

function TR:StartEngine_Rogue()
  self:StopEngine_Rogue()
  self:EngineTick_Rogue()
  local AceTimer = LibStub and LibStub("AceTimer-3.0", true)
  if AceTimer and AceTimer.ScheduleRepeatingTimer then
    self._engineTimer_RO = AceTimer:ScheduleRepeatingTimer(function() _G.TacoRot:EngineTick_Rogue() end, 0.20)
  else
    local acc, f = 0, CreateFrame("Frame")
    f:SetScript("OnUpdate", function(_, e) acc=acc+(e or 0); if acc>=0.20 then acc=acc-0.20; _G.TacoRot:EngineTick_Rogue() end end)
    self._engineTimer_RO = f
  end
  self:Print("TacoRot Rogue engine active: " .. SpecName())
end

function TR:StopEngine_Rogue()
  local t = self._engineTimer_RO
  if not t then return end
  local AceTimer = LibStub and LibStub("AceTimer-3.0", true)
  if AceTimer and type(t)=="number" then AceTimer:CancelTimer(t,true) elseif type(t)=="table" and t.SetScript then t:SetScript("OnUpdate",nil); t:Hide() end
  self._engineTimer_RO = nil
end

do local _,c=UnitClass("player"); if c=="ROGUE" then TR:StartEngine_Rogue() end end
