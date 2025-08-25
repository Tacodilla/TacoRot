-- core.lua — Ace3 core for TacoRot (3.3.5) - FIXED
local AceAddon = LibStub and LibStub("AceAddon-3.0")
if not AceAddon then return end

local AceDB           = LibStub("AceDB-3.0")
local AceConfig       = LibStub("AceConfig-3.0")
local AceConfigDialog = LibStub("AceConfigDialog-3.0")
local AceDBOptions    = LibStub("AceDBOptions-3.0")

local TR = AceAddon:NewAddon("TacoRot", "AceConsole-3.0", "AceEvent-3.0", "AceTimer-3.0")
_G.TacoRot = TR

local function GetEnhancedDefaults()
  local defaults = {
    profile = {
      unlock      = true,
      nextWindows = true,
      iconSize    = 52,
      nextScale   = 0.82,
      castFlash   = true,
      aoe         = false,
      anchor      = {"CENTER", UIParent, "CENTER", -200, 120},
      spells      = {},
      -- Add missing config sections
      pad         = {},
      buff        = {},
      pet         = {},
      keybinds    = {
        enabled = true,
        lowercase = false,
      },
      keybindDebug = false,

      -- New display system defaults
      displays = {
        Primary = {
          enabled = true,
          numIcons = 3,
          iconSize = 50,
          spacing = 5,
          position = { anchor = "CENTER", x = 0, y = 0 },
          visibility = {
            combat = true,
            outOfCombat = false,
            mounted = false,
          },
        },
        Secondary = {
          enabled = false,
          numIcons = 2,
          iconSize = 40,
          spacing = 5,
          position = { anchor = "CENTER", x = 0, y = 60 },
        },
      },

      -- Enhanced class-specific settings
      classSettings = {
        ROGUE = {
          padding = { enabled = true, gcd = 1.6 },
          buffs   = { enabled = true },
          pets    = { enabled = false },
        },
        WARLOCK = {
          padding = { enabled = true, gcd = 1.6 },
          buffs   = { enabled = true },
          pets    = { enabled = true },
        },
        HUNTER = {
          padding = { enabled = true, gcd = 1.6 },
          buffs   = { enabled = true },
          pets    = { enabled = true },
        },
      },
    },
  }
  return defaults
end

-- ================= Display System =================
function TR:CreateAdditionalDisplays()
  local displays = {"Primary", "Secondary", "Cooldowns", "Defensive", "AoE"}

  for i, name in ipairs(displays) do
    self.UI = self.UI or {}
    self.UI.displays = self.UI.displays or {}
    if not self.UI.displays[name] then
      self.UI.displays[name] = {
        enabled = (i == 1), -- Only Primary enabled by default
        frame = nil,
        buttons = {},
        config = {
          numIcons = (i == 1) and 3 or 2,
          iconSize = 50,
          spacing = 5,
          anchor = "CENTER",
          x = 0,
          y = 0 + (i - 1) * 60,
        },
      }
    end
  end
end

-- ================= Options (root) =================
local function RegisterOptions(self)
  local opts = {
    type = "group",
    name = "TacoRot",
    args = {
      unlock = {
        type="toggle", order=1, name="Unlock",
        get=function() return self.db.profile.unlock end,
        set=function(_,v) self.db.profile.unlock=v; self:UpdateLock() end,
      },
      next = {
        type="toggle", order=2, name="Show Next Windows",
        get=function() return self.db.profile.nextWindows end,
        set=function(_,v) self.db.profile.nextWindows=v; self:UpdateVisibility() end,
      },
      size = {
        type="range", order=3, name="Main Icon Size", min=24, max=96, step=1,
        get=function() return self.db.profile.iconSize end,
        set=function(_,v) self.db.profile.iconSize=v; if self.UI and self.UI.ApplySettings then self.UI:ApplySettings() end end,
      },
      nscale = {
        type="range", order=4, name="Next Icon Scale", min=0.5, max=1.2, step=0.01,
        get=function() return self.db.profile.nextScale end,
        set=function(_,v) self.db.profile.nextScale=v; if self.UI and self.UI.ApplySettings then self.UI:ApplySettings() end end,
      },
      castflash = {
        type="toggle", order=5, name="Flash while casting",
        get=function() return self.db.profile.castFlash end,
        set=function(_,v) self.db.profile.castFlash=v end,
      },
      aoe = {
        type="toggle", order=6, name="AoE Mode (ALT = momentary)",
        get=function() return self.db.profile.aoe end,
        set=function(_,v) self.db.profile.aoe=v end,
      },
      open = {
        type="execute", order=99, name="Open in Interface Options",
        func=function()
          InterfaceOptionsFrame_OpenToCategory("TacoRot")
          InterfaceOptionsFrame_OpenToCategory("TacoRot")
        end,
      },
    },
  }
  AceConfig:RegisterOptionsTable("TacoRot", opts)
  self.OptionsRoot  = opts
  self.optionsFrame = AceConfigDialog:AddToBlizOptions("TacoRot", "TacoRot")

  local prof = AceDBOptions:GetOptionsTable(self.db)
  AceConfig:RegisterOptionsTable("TacoRot-Profiles", prof)
  AceConfigDialog:AddToBlizOptions("TacoRot-Profiles", "Profiles", "TacoRot")
end

-- ================= Lifecycle =================
function TR:OnInitialize()
  self.db = AceDB:New("TacoRotDB", GetEnhancedDefaults(), true)
  RegisterOptions(self)
  self:RegisterChatCommand("tacorot", "Slash")
  self:RegisterChatCommand("tr", "Slash")
  
  -- Initialize spell cooldown tracking
  self.spellCooldowns = {}
  self.lastCastTime = 0
  self.isChanneling = false
  
  if self.UI and self.UI.Init then
    self.UI:Init()
    if self.UI.ApplySettings then self.UI:ApplySettings() end
  end

  -- Initialize additional displays
  if self.CreateAdditionalDisplays then
    self:CreateAdditionalDisplays()
  end
end

function TR:OnEnable()
  self:RegisterEvent("PLAYER_ENTERING_WORLD", "HandleWorldEnter")
  self:RegisterEvent("UNIT_SPELLCAST_START",         "CastStart")
  self:RegisterEvent("UNIT_SPELLCAST_CHANNEL_START", "CastStart")
  self:RegisterEvent("UNIT_SPELLCAST_STOP",          "CastStop")
  self:RegisterEvent("UNIT_SPELLCAST_CHANNEL_STOP",  "CastStop")
  self:RegisterEvent("UNIT_SPELLCAST_INTERRUPTED",   "CastStop")
  self:RegisterEvent("UNIT_SPELLCAST_SUCCEEDED",     "CastSucceeded")
  self:RegisterEvent("SPELL_UPDATE_COOLDOWN",        "SpellCooldownUpdate")
  self:RegisterEvent("ACTIONBAR_UPDATE_COOLDOWN",    "ActionCooldownUpdate")
end

function TR:OnDisable()
  -- Fixed: Use proper method names that exist
  local engines = {"Warlock", "Rogue", "Hunter", "Druid", "Mage", "Paladin", "Priest", "Shaman", "Warrior"}
  for _, class in ipairs(engines) do
    local stopMethod = "StopEngine_" .. class
    if self[stopMethod] then 
      self[stopMethod](self) 
    end
  end
  -- Clear engine flags
  self._engineStates = {}
end

function TR:HandleWorldEnter()
  local _, class = UnitClass("player")
  if not class then return end
  
  self._engineStates = self._engineStates or {}
  
  local startMethod = "StartEngine_" .. class
  if self[startMethod] and not self._engineStates[class] then
    self[startMethod](self)
    self._engineStates[class] = true
  end
  
  if self.SendMessage then 
    self:SendMessage("TACOROT_ENABLE_CLASS_MODULE") 
  end
  
  self:UnregisterEvent("PLAYER_ENTERING_WORLD")
end

-- ================= Spell Tracking (Hekili-like) =================
function TR:SpellCooldownUpdate()
  -- Update internal cooldown tracking
  self:ScheduleTimer("UpdateRotationDisplay", 0.1)
end

function TR:ActionCooldownUpdate()
  -- Update internal cooldown tracking
  self:ScheduleTimer("UpdateRotationDisplay", 0.1)
end

function TR:UpdateRotationDisplay()
  -- Trigger current engine tick if available
  local _, class = UnitClass("player")
  if class then
    local tickMethod = "EngineTick_" .. class
    if self[tickMethod] then
      self[tickMethod](self)
    end
  end
end

-- ================= Cast flash bridge (FIXED) =================
TR._lastMainSpell = TR._lastMainSpell or nil

local function _matchSpell(recID, evtName, evtID)
  if evtID and recID and evtID == recID then return true end
  local recName = recID and GetSpellInfo(recID)
  if not recName or not evtName then return false end
  return recName:lower() == tostring(evtName):lower()
end

function TR:CastStart(_, unit, spellName, _, _, spellID)
  if unit ~= "player" then return end
  
  self.isChanneling = true
  self.lastCastTime = GetTime()
  
  local rec = self._lastMainSpell
  if rec and self.SetMainCastFlash and self.db.profile.castFlash and _matchSpell(rec, spellName, spellID) then
    self:SetMainCastFlash(true)
  end
end

function TR:CastSucceeded(_, unit, spellName, _, _, spellID)
  if unit ~= "player" then return end

  self.lastCastTime = GetTime()

  local rec = self._lastMainSpell
  if rec and self.SetMainCastFlash and self.db.profile.castFlash and _matchSpell(rec, spellName, spellID) then
    -- Flash already enabled in CastStart; delay turning it off briefly
    self:ScheduleTimer(function()
      if self.SetMainCastFlash then self:SetMainCastFlash(false) end
    end, 0.2)

    if spellID then
      self.spellCooldowns[spellID] = GetTime()
    end
  end

  self:ScheduleTimer("UpdateRotationDisplay", 0.1)
end

function TR:CastStop(_, unit)
  if unit ~= "player" then return end

  self.isChanneling = false

  -- Update rotation after cast stops

  -- Flash handled in CastSucceeded; just refresh rotation
  self:ScheduleTimer("UpdateRotationDisplay", 0.1)
end

-- ================= Helpers used by UI/options (FIXED) =================
function TR:UpdateLock()
  local unlocked = self.db.profile.unlock
  
  -- Handle both new UI structure and legacy frames
  if self.UI and self.UI.frames then
    for _, f in pairs(self.UI.frames) do 
      if f and f.EnableMouse then 
        f:EnableMouse(unlocked) 
      end 
    end
  end
  
  -- Legacy frame support
  local frames = {TacoRotWindow, TacoRotWindow2, TacoRotWindow3}
  for _, frame in ipairs(frames) do
    if frame and frame.EnableMouse then
      frame:EnableMouse(unlocked)
    end
  end
end

function TR:UpdateVisibility()
  local showNext = self.db.profile.nextWindows
  
  if self.UI and self.UI.f2 and self.UI.f3 then
    if showNext then 
      self.UI.f2:Show()
      self.UI.f3:Show() 
    else 
      self.UI.f2:Hide()
      self.UI.f3:Hide() 
    end
  end
  
  -- Legacy frame support
  if TacoRotWindow2 and TacoRotWindow3 then
    if showNext then 
      TacoRotWindow2:Show()
      TacoRotWindow3:Show() 
    else 
      TacoRotWindow2:Hide()
      TacoRotWindow3:Hide() 
    end
  end
end

function TR:EnterConfigMode()
  self.configMode = true

  for name, display in pairs(self.UI and self.UI.displays or {}) do
    if display.frame and display.frame.backdrop then
      display.frame.backdrop:Show()
      display.frame:EnableMouse(true)
      display.frame:SetMovable(true)
      display.frame:RegisterForDrag("LeftButton")
      display.frame:SetScript("OnDragStart", function(frame)
        frame:StartMoving()
      end)
      display.frame:SetScript("OnDragStop", function(frame)
        frame:StopMovingOrSizing()
        local point, _, _, x, y = frame:GetPoint()
        self.db.profile.displays = self.db.profile.displays or {}
        self.db.profile.displays[name] = self.db.profile.displays[name] or {}
        self.db.profile.displays[name].position = { anchor = point, x = x, y = y }
      end)
    end
  end

  self:Print("Configuration mode enabled. Drag frames to reposition.")
end

function TR:ExitConfigMode()
  self.configMode = false

  for _, display in pairs(self.UI and self.UI.displays or {}) do
    if display.frame then
      if display.frame.backdrop then display.frame.backdrop:Hide() end
      display.frame:EnableMouse(false)
      display.frame:SetMovable(false)
      display.frame:SetScript("OnDragStart", nil)
      display.frame:SetScript("OnDragStop", nil)
    end
  end

  self:Print("Configuration mode disabled.")
end

function TR:Slash(input)
  input = (input or ""):lower()
  if input == "" then
    InterfaceOptionsFrame_OpenToCategory("TacoRot")
    InterfaceOptionsFrame_OpenToCategory("TacoRot")
    return
  end
  if input == "ul" or input == "unlock" then
    self.db.profile.unlock = not self.db.profile.unlock
    self:UpdateLock()
    self:Print("UI " .. (self.db.profile.unlock and "unlocked" or "locked"))
    return
  end
  if input == "aoe" then
    self.db.profile.aoe = not self.db.profile.aoe
    self:Print("AoE mode " .. (self.db.profile.aoe and "enabled" or "disabled"))
    return
  end
  if input == "config" then
    InterfaceOptionsFrame_OpenToCategory("TacoRot")
    InterfaceOptionsFrame_OpenToCategory("TacoRot")
    return
  end

  if input:match("^keybind") or input:match("^kb") then
    self:SlashKeybinds(input)
    return
  end

  -- Help text
  self:Print("Commands: /tr config, /tr unlock, /tr aoe")
end

-- Add this new function to core.lua
function TR:SlashKeybinds(input)
  if input == "keybinds test" or input == "kb test" then
    self:TestKeybinds()
    return
  end

  if input == "keybinds refresh" or input == "kb refresh" then
    self:ReadKeybindings()
    self:Print("Keybindings refreshed")
    return
  end

  if input == "keybinds toggle" or input == "kb toggle" then
    local enabled = self.db.profile.keybinds.enabled
    self.db.profile.keybinds.enabled = not enabled
    self:Print("Keybind display " .. (enabled and "disabled" or "enabled"))
    return
  end

  if input == "keybinds debug on" then
    self.db.profile.keybindDebug = true
    self:Print("Keybind debug enabled")
    return
  end

  if input == "keybinds debug off" then
    self.db.profile.keybindDebug = false
    self:Print("Keybind debug disabled")
    return
  end

  if input == "keybinds info" or input == "kb info" then
    self:Print("Current keybind data:")
    local count = 0
    for spell, data in pairs(self.Keys) do
      local bind = self:GetKeybindForSpell(spell)
      if bind ~= "" then
        self:Print("  " .. spell .. " -> " .. bind)
        count = count + 1
      end
    end
    if count == 0 then
      self:Print("  No keybinds found. Try '/tr kb test' for debug info.")
    end
    return
  end

  -- Help
  self:Print("Keybind commands:")
  self:Print("  /tr kb test - Debug keybind detection")
  self:Print("  /tr kb info - Show current keybinds") 
  self:Print("  /tr kb refresh - Refresh keybinds")
  self:Print("  /tr kb toggle - Toggle keybind display")
  self:Print("  /tr kb debug on/off - Toggle debug mode")
end
