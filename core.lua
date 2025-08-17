-- core.lua — 3.3.5 safe
-- Exports the addon globally, registers options root, and starts class engines
-- (WARLOCK / ROGUE / HUNTER) on PLAYER_ENTERING_WORLD.

local AceAddon = LibStub and LibStub("AceAddon-3.0")
if not AceAddon then
  DEFAULT_CHAT_FRAME:AddMessage("|cffff5555[TacoRot] Ace3 missing; check embeds.xml.|r")
  return
end

local AceDB           = LibStub("AceDB-3.0")
local AceConfig       = LibStub("AceConfig-3.0")
local AceConfigDialog = LibStub("AceConfigDialog-3.0")
local AceDBOptions    = LibStub("AceDBOptions-3.0")

-- Create addon and export to the global table immediately (so /run can see it)
local _addon = AceAddon:NewAddon("TacoRot", "AceConsole-3.0", "AceEvent-3.0", "AceTimer-3.0")
_G.TacoRot = _addon
local TacoRot = _addon

-- -----------------------------------------------------------------------------
-- Defaults
-- -----------------------------------------------------------------------------
local defaults = {
  profile = {
    unlock       = true,     -- drag frames
    nextWindows  = true,     -- show the two prediction boxes
    iconSize     = 52,
    nextScale    = 0.82,
    castFlash    = true,
    aoe          = false,    -- ALT = momentary AoE
    anchor       = {"CENTER", UIParent, "CENTER", -200, 120},
    spells       = {},       -- per-spell toggles filled by options.lua
  },
}

-- Rogue spec detection (Wrath/3.3.5 talent API)
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

-- -----------------------------------------------------------------------------
-- Options root (extensions are added by options.lua)
-- -----------------------------------------------------------------------------
local function RegisterOptions(self)
  local opts = {
    type = "group",
    name = "TacoRot",
    args = {
      unlock = {
        type = "toggle", order = 1, name = "Unlock",
        desc = "Drag the recommendation icons",
        get = function() return self.db.profile.unlock end,
        set = function(_, v) self.db.profile.unlock = v; self:UpdateLock() end,
      },
      next = {
        type = "toggle", order = 2, name = "Show Next Windows",
        get = function() return self.db.profile.nextWindows end,
        set = function(_, v) self.db.profile.nextWindows = v; self:UpdateVisibility() end,
      },
      size = {
        type = "range", order = 3, name = "Main Icon Size",
        min = 24, max = 96, step = 1,
        get = function() return self.db.profile.iconSize end,
        set = function(_, v) self.db.profile.iconSize = v
          if self.UI and self.UI.ApplySettings then self.UI:ApplySettings() end
        end,
      },
      nscale = {
        type = "range", order = 4, name = "Next Icon Scale",
        min = 0.5, max = 1.2, step = 0.01,
        get = function() return self.db.profile.nextScale end,
        set = function(_, v) self.db.profile.nextScale = v
          if self.UI and self.UI.ApplySettings then self.UI:ApplySettings() end
        end,
      },
      castflash = {
        type = "toggle", order = 5, name = "Flash while casting",
        get = function() return self.db.profile.castFlash end,
        set = function(_, v) self.db.profile.castFlash = v end,
      },
      aoe = {
        type = "toggle", order = 6, name = "AoE Mode (ALT = momentary)",
        get = function() return self.db.profile.aoe end,
        set = function(_, v) self.db.profile.aoe = v end,
      },
      open = {
        type = "execute", order = 99, name = "Open in Interface Options",
        func = function()
          InterfaceOptionsFrame_OpenToCategory("TacoRot")
          InterfaceOptionsFrame_OpenToCategory("TacoRot") -- 3.3.5 quirk
        end,
      },
    },
  }

  AceConfig:RegisterOptionsTable("TacoRot", opts)
  self.OptionsRoot = opts
  self.optionsFrame = AceConfigDialog:AddToBlizOptions("TacoRot", "TacoRot")

  local prof = AceDBOptions:GetOptionsTable(self.db)
  AceConfig:RegisterOptionsTable("TacoRot-Profiles", prof)
  AceConfigDialog:AddToBlizOptions("TacoRot-Profiles", "Profiles", "TacoRot")
end

-- -----------------------------------------------------------------------------
-- Lifecycle
-- -----------------------------------------------------------------------------
function TacoRot:OnInitialize()
  self.db = AceDB:New("TacoRotDB", defaults, true)
  RegisterOptions(self)

  self:RegisterChatCommand("tacorot", "Slash")
  self:RegisterChatCommand("tr", "Slash")

  -- If UI exposes init/apply, call them after DB exists (safe no-ops otherwise).
  if self.UI and self.UI.Init then
    self.UI:Init()
    if self.UI.ApplySettings then self.UI:ApplySettings() end
  end
end

function TacoRot:OnEnable()
  -- Start correct engine on world entry (not at login).
  self:RegisterEvent("PLAYER_ENTERING_WORLD", "HandleWorldEnter")

  -- Rogue spec cache
  self:RegisterEvent("PLAYER_TALENT_UPDATE",     function() self._spec = self:GetSpec() end)
  self:RegisterEvent("CHARACTER_POINTS_CHANGED", function() self._spec = self:GetSpec() end)

  -- Cast-flash (ui.lua listens via TacoRot:SetMainCastFlash)
  self:RegisterEvent("UNIT_SPELLCAST_START",         "_CastStart")
  self:RegisterEvent("UNIT_SPELLCAST_CHANNEL_START", "_CastStart")
  self:RegisterEvent("UNIT_SPELLCAST_STOP",          "_CastStop")
  self:RegisterEvent("UNIT_SPELLCAST_CHANNEL_STOP",  "_CastStop")
  self:RegisterEvent("UNIT_SPELLCAST_INTERRUPTED",   "_CastStop")
  self:RegisterEvent("UNIT_SPELLCAST_SUCCEEDED",     "_CastSucceeded")
end

function TacoRot:OnDisable()
  if self.StopEngine_Warlock then self:StopEngine_Warlock() end
  if self.StopEngine_Rogue  then self:StopEngine_Rogue()  end
  if self.StopEngine_Hunter then self:StopEngine_Hunter() end
  self._wlStarted, self._rgStarted, self._htStarted = nil, nil, nil
end

-- Start the correct class engine when the world is ready.
function TacoRot:HandleWorldEnter()
  local _, class = UnitClass("player")
  self._spec = self:GetSpec() -- harmless for non-Rogue

  if class == "WARLOCK" then
    if self.StartEngine_Warlock and not self._wlStarted then
      self:StartEngine_Warlock(); self._wlStarted = true
    end

  elseif class == "ROGUE" then
    if self.StartEngine_Rogue and not self._rgStarted then
      self:StartEngine_Rogue(); self._rgStarted = true
    end

  elseif class and string.upper(class) == "HUNTER" then
    DEFAULT_CHAT_FRAME:AddMessage("|cffff0000DEBUG:|r core.lua is attempting to start the Hunter engine.")
    if self.StartEngine_Hunter and not self._htStarted then
      self:StartEngine_Hunter(); self._htStarted = true
    else
      DEFAULT_CHAT_FRAME:AddMessage("|cffff0000DEBUG:|r core.lua check failed: StartEngine_Hunter function not found or engine already started.")
    end
  end

  -- Let per-class modules listen for finalization.
  if self.SendMessage then self:SendMessage("TACOROT_ENABLE_CLASS_MODULE") end

  self:UnregisterEvent("PLAYER_ENTERING_WORLD")
end

-- -----------------------------------------------------------------------------
-- Cast-flash integration (UI pulse)
-- -----------------------------------------------------------------------------
function TacoRot:_CastStart(_, unit, spellName, _, _, spellID)
  if unit ~= "player" then return end
  local rec = self._lastMainSpell
  if not rec then return end
  local recName = GetSpellInfo(rec)
  if (spellID and spellID == rec) or (recName and spellName == recName) then
    if self.SetMainCastFlash and self.db.profile.castFlash then self:SetMainCastFlash(true) end
  end
end

function TacoRot:_CastSucceeded(_, unit, spellName, _, _, spellID)
  if unit ~= "player" then return end
  local rec = self._lastMainSpell
  if not rec then return end
  local recName = GetSpellInfo(rec)
  if (spellID and spellID == rec) or (recName and spellName == recName) then
    if self.SetMainCastFlash and self.db.profile.castFlash then
      self:SetMainCastFlash(true)
      -- brief pulse using AceTimer (3.3.5 friendly)
      self:ScheduleTimer(function()
        if self.SetMainCastFlash then self:SetMainCastFlash(false) end
      end, 0.25)
    end
  end
end

function TacoRot:_CastStop(_, unit)
  if unit ~= "player" then return end
  if self.SetMainCastFlash then self:SetMainCastFlash(false) end
end

-- -----------------------------------------------------------------------------
-- Small helpers
-- -----------------------------------------------------------------------------
function TacoRot:UpdateLock()
  local unlocked = self.db.profile.unlock
  -- If your UI.lua tracks frames in TacoRot.UI.frames, honor it; otherwise use globals.
  if self.UI and self.UI.frames then
    for _, f in pairs(self.UI.frames) do if f then f:EnableMouse(unlocked) end end
  else
    if TacoRotWindow then TacoRotWindow:EnableMouse(unlocked) end
    if TacoRotWindow2 then TacoRotWindow2:EnableMouse(unlocked) end
    if TacoRotWindow3 then TacoRotWindow3:EnableMouse(unlocked) end
  end
end

function TacoRot:UpdateVisibility()
  local showNext = self.db.profile.nextWindows
  if self.UI and self.UI.f2 and self.UI.f3 then
    if showNext then self.UI.f2:Show(); self.UI.f3:Show() else self.UI.f2:Hide(); self.UI.f3:Hide() end
  else
    if TacoRotWindow2 and TacoRotWindow3 then
      if showNext then TacoRotWindow2:Show(); TacoRotWindow3:Show() else TacoRotWindow2:Hide(); TacoRotWindow3:Hide() end
    end
  end
end

function TacoRot:Slash(input)
  input = (input or ""):lower()
  if input == "" then
    InterfaceOptionsFrame_OpenToCategory("TacoRot")
    InterfaceOptionsFrame_OpenToCategory("TacoRot")
    return
  end
  if input == "ul" or input == "unlock" then
    self.db.profile.unlock = not self.db.profile.unlock; self:UpdateLock(); return
  end
  if input == "aoe" then
    self.db.profile.aoe = not self.db.profile.aoe
    DEFAULT_CHAT_FRAME:AddMessage("|cffffcc00[TacoRot]|r AoE mode: "..(self.db.profile.aoe and "ON" or "OFF"))
    return
  end
end