-- core.lua
-- World-entry init + class pick (Warlock/Rogue) + spec cache for Rogue.
-- Ace load order untouched (embeds.xml still drives it).

local AceAddon = LibStub and LibStub("AceAddon-3.0")
if not AceAddon then
  DEFAULT_CHAT_FRAME:AddMessage("|cffff5555[TacoRot] Ace3 missing; check embeds.xml.|r")
  return
end

local AceDB           = LibStub("AceDB-3.0")
local AceConfig       = LibStub("AceConfig-3.0")
local AceConfigDialog = LibStub("AceConfigDialog-3.0")
local AceDBOptions    = LibStub("AceDBOptions-3.0")

local TacoRot = AceAddon:NewAddon("TacoRot", "AceConsole-3.0", "AceEvent-3.0", "AceTimer-3.0")
_G.TacoRot = TacoRot

-- ------------------------------------------------------------
-- Defaults
-- ------------------------------------------------------------
local defaults = {
  profile = {
    unlock        = true,
    window        = true,
    nextWindows   = true,
    showBinds     = true,
    showNames     = false,
    castFlash     = true,   -- glow main icon while casting/instant
    iconSize      = 52,
    nextScale     = 0.82,
    flashSize     = 48,
    defHealth     = 0.45,
    enableInterrupt = true,
    enablePurge     = true,
    enableDefense   = true,
    aoe           = false,
    anchor        = {"CENTER", UIParent, "CENTER", -200, 120},
    spells        = {},
  },
}

-- ------------------------------------------------------------
-- Rogue spec detection (3.3.5 talent API)
-- ------------------------------------------------------------
function TacoRot:GetSpec()
  local _, class = UnitClass("player")
  if class ~= "ROGUE" then return nil end
  local bestPoints, bestIdx = -1, 1
  for i = 1, GetNumTalentTabs() do
    local _, _, points = GetTalentTabInfo(i, "player")
    if points and points > bestPoints then bestPoints, bestIdx = points, i end
  end
  if bestIdx == 1 then return "ASSASSINATION"
  elseif bestIdx == 2 then return "COMBAT"
  else return "SUBTLETY" end
end

-- ------------------------------------------------------------
-- Options (root group; class-specific bits are added by options.lua)
-- ------------------------------------------------------------
local function RegisterOptions(self)
  local opts = {
    type = "group", name = "TacoRot",
    args = {
      unlock = { type="toggle", name="Unlock", order=1,
        get=function() return self.db.profile.unlock end,
        set=function(_,v) self.db.profile.unlock=v; self:UpdateLock() end },
      window = { type="toggle", name="Enable Display Window", order=2,
        get=function() return self.db.profile.window end,
        set=function(_,v) self.db.profile.window=v; self:UpdateVisibility() end },
      next = { type="toggle", name="Enable Next Windows", order=3,
        get=function() return self.db.profile.nextWindows end,
        set=function(_,v) self.db.profile.nextWindows=v; self:UpdateVisibility() end },
      size = { type="range", name="Main Icon Size", order=4, min=24, max=96, step=1,
        get=function() return self.db.profile.iconSize end,
        set=function(_,v) self.db.profile.iconSize=v; self:ApplySizes() end },
      nscale = { type="range", name="Next Icon Scale", order=5, min=0.5, max=1.2, step=0.01,
        get=function() return self.db.profile.nextScale end,
        set=function(_,v) self.db.profile.nextScale=v; self:ApplySizes() end },
      flash = { type="range", name="Flash Size", order=6, min=24, max=96, step=1,
        get=function() return self.db.profile.flashSize end,
        set=function(_,v) self.db.profile.flashSize=v; self:ApplySizes() end },
      castflash = { type="toggle", name="Flash main icon while casting", order=7,
        get=function() return self.db.profile.castFlash end,
        set=function(_,v) self.db.profile.castFlash=v end },
      aoe = { type="toggle", name="AoE Mode (ALT = momentary)", order=8,
        get=function() return self.db.profile.aoe end,
        set=function(_,v) self.db.profile.aoe=v end },
      open = { type="execute", name="Open UI", order=99, func=function()
        InterfaceOptionsFrame_OpenToCategory("TacoRot")
        InterfaceOptionsFrame_OpenToCategory("TacoRot")
      end },
    },
  }

  -- Register with Ace and keep a direct handle so options.lua
  -- never needs to pull through AceConfigRegistry.
  AceConfig:RegisterOptionsTable("TacoRot", opts)
  self.OptionsRoot = opts

  self.optionsFrame = AceConfigDialog:AddToBlizOptions("TacoRot", "TacoRot")

  local p = AceDBOptions:GetOptionsTable(self.db)
  AceConfig:RegisterOptionsTable("TacoRot-Profiles", p)
  AceConfigDialog:AddToBlizOptions("TacoRot-Profiles", "Profiles", "TacoRot")
end

-- ------------------------------------------------------------
-- Lifecycle
-- ------------------------------------------------------------
function TacoRot:OnInitialize()
  self.db = AceDB:New("TacoRotDB", defaults, true)

  RegisterOptions(self)

  -- slash commands
  self:RegisterChatCommand("tacorot", "Slash")
  self:RegisterChatCommand("tr", "Slash")

  -- build UI frames (implemented in ui.lua)
  if self.CreateWindows then
    self:CreateWindows()
    self:ApplySizes()
    self:UpdateLock()
    self:UpdateVisibility()
  end
end

function TacoRot:OnEnable()
  -- Start engines only after we actually enter the world.
  self:RegisterEvent("PLAYER_ENTERING_WORLD", "HandleWorldEnter")

  -- Keep spec fresh for Rogue APLs
  self:RegisterEvent("PLAYER_TALENT_UPDATE",      function() self._spec = self:GetSpec() end)
  self:RegisterEvent("CHARACTER_POINTS_CHANGED",  function() self._spec = self:GetSpec() end)

  -- Casting overlay (used by ui.lua)
  self:RegisterEvent("UNIT_SPELLCAST_START",         "_CastStart")
  self:RegisterEvent("UNIT_SPELLCAST_CHANNEL_START", "_CastStart")
  self:RegisterEvent("UNIT_SPELLCAST_STOP",          "_CastStop")
  self:RegisterEvent("UNIT_SPELLCAST_CHANNEL_STOP",  "_CastStop")
  self:RegisterEvent("UNIT_SPELLCAST_INTERRUPTED",   "_CastStop")
  self:RegisterEvent("UNIT_SPELLCAST_SUCCEEDED",     "_CastSucceeded") -- instants
end

function TacoRot:OnDisable()
  if self.StopEngine_Warlock then self:StopEngine_Warlock() end
  if self.StopEngine_Rogue  then self:StopEngine_Rogue()  end
  self._wlStarted, self._rgStarted = nil, nil
end

-- ------------------------------------------------------------
-- World entry -> choose class engine
-- ------------------------------------------------------------
function TacoRot:HandleWorldEnter()
  self._spec = self:GetSpec() -- cache spec now that talents are sane

  local _, class = UnitClass("player")
  if class == "WARLOCK" then
    if self.StartEngine_Warlock and not self._wlStarted then
      self:StartEngine_Warlock()
      self._wlStarted = true
    end
  elseif class == "ROGUE" then
    if self.StartEngine_Rogue and not self._rgStarted then
      self:StartEngine_Rogue()
      self._rgStarted = true
    end
  end

  self:UnregisterEvent("PLAYER_ENTERING_WORLD") -- one-shot per UI load
end

-- ------------------------------------------------------------
-- Cast flash hookup (ui.lua supplies SetMainCastFlash)
-- ------------------------------------------------------------
function TacoRot:_CastStart(_, unit, spellName, _, _, spellID)
  if unit ~= "player" then return end
  local rec = self._lastMainSpell
  if not rec then return end
  local recName = GetSpellInfo(rec)
  if (spellID and spellID == rec) or (recName and spellName == recName) then
    if self.SetMainCastFlash and (self.db and self.db.profile.castFlash) then
      self:SetMainCastFlash(true)
    end
  end
end

function TacoRot:_CastSucceeded(_, unit, spellName, rank, lineID, spellID)
  if unit ~= "player" then return end
  local rec = self._lastMainSpell
  if not rec then return end
  local recName = GetSpellInfo(rec)
  if (spellID and spellID == rec) or (recName and spellName == recName) then
    if self.SetMainCastFlash and (self.db and self.db.profile.castFlash) then
      self:SetMainCastFlash(true)
      self:ScheduleTimer(function() if self.SetMainCastFlash then self:SetMainCastFlash(false) end end, 0.25)
    end
  end
end

function TacoRot:_CastStop(_, unit)
  if unit ~= "player" then return end
  if self.SetMainCastFlash then self:SetMainCastFlash(false) end
end

-- ------------------------------------------------------------
-- UI helpers used by options + keybinding (Bindings.xml)
-- ------------------------------------------------------------
function TacoRot:ToggleUnlock()
  self.db.profile.unlock = not self.db.profile.unlock
  self:UpdateLock()
end

function TacoRot:UpdateLock()
  local ul = self.db.profile.unlock
  for _, f in pairs({TacoRotWindow, TacoRotWindow2, TacoRotWindow3, TacoRotDefWindow, TacoRotIntFlash, TacoRotPurgeFlash}) do
    if f then f:EnableMouse(ul); f:SetMovable(ul) end
  end
end

function TacoRot:UpdateVisibility()
  if not TacoRotWindow then return end
  if self.db.profile.window then
    TacoRotWindow:Show()
    if self.db.profile.nextWindows then
      if TacoRotWindow2 then TacoRotWindow2:Show() end
      if TacoRotWindow3 then TacoRotWindow3:Show() end
    else
      if TacoRotWindow2 then TacoRotWindow2:Hide() end
      if TacoRotWindow3 then TacoRotWindow3:Hide() end
    end
  else
    TacoRotWindow:Hide()
    if TacoRotWindow2 then TacoRotWindow2:Hide() end
    if TacoRotWindow3 then TacoRotWindow3:Hide() end
  end
end

function TacoRot:ApplySizes()
  if not self.db or not TacoRotWindow then return end
  local s = self.db.profile.iconSize
  local n = self.db.profile.nextScale
  if TacoRotWindow  then TacoRotWindow:SetSize(s, s) end
  if TacoRotWindow2 then TacoRotWindow2:SetSize(s*n, s*n) end
  if TacoRotWindow3 then TacoRotWindow3:SetSize(s*n, s*n) end
  if TacoRotIntFlash  then TacoRotIntFlash:SetSize(self.db.profile.flashSize*0.25, self.db.profile.flashSize*0.25) end
  if TacoRotPurgeFlash then TacoRotPurgeFlash:SetSize(self.db.profile.flashSize*0.25, self.db.profile.flashSize*0.25) end
end

-- ------------------------------------------------------------
-- Slash commands
-- ------------------------------------------------------------
function TacoRot:Slash(input)
  input = (input or ""):lower()
  if input == "" then
    InterfaceOptionsFrame_OpenToCategory("TacoRot")
    InterfaceOptionsFrame_OpenToCategory("TacoRot")
    return
  end
  if input == "ul" or input == "unlock" then
    self:ToggleUnlock()
    return
  end
  if input == "aoe" then
    self.db.profile.aoe = not self.db.profile.aoe
    DEFAULT_CHAT_FRAME:AddMessage("|cffffcc00[TacoRot]|r AoE mode: "..(self.db.profile.aoe and "ON" or "OFF").." (hold ALT for temporary AoE)")
    return
  end
  if input == "binds" then
    self.db.profile.showBinds = not self.db.profile.showBinds
    DEFAULT_CHAT_FRAME:AddMessage("|cffffcc00[TacoRot]|r Keybind labels: "..(self.db.profile.showBinds and "ON" or "OFF"))
    return
  end
end
