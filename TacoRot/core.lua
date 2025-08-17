local AceAddon = LibStub and LibStub("AceAddon-3.0")
if not AceAddon then DEFAULT_CHAT_FRAME:AddMessage("|cffff5555[TacoRot] Ace3 missing; check embeds.xml.|r"); return end

local AceDB          = LibStub("AceDB-3.0")
local AceConfig      = LibStub("AceConfig-3.0")
local AceConfigDialog= LibStub("AceConfigDialog-3.0")
local AceDBOptions   = LibStub("AceDBOptions-3.0")

local TacoRot = AceAddon:NewAddon("TacoRot", "AceConsole-3.0", "AceEvent-3.0", "AceTimer-3.0")
_G.TacoRot = TacoRot

TacoRot.SuggestedSpells = {}

local defaults = {
  profile = {
    unlock = true,
    window = true,
    nextWindows = true,
    showKeys = true,
    showNames = false,
    iconSize = 52,
    nextScale = 0.82,
    flashSize = 48,
    defHealth = 0.45, -- 45%
    enableInterrupt = true,
    enablePurge = true,
    enableDefense = true,
    anchor = {"CENTER", UIParent, "CENTER", -200, 120},
    spells = {},
  },
}

local function msg(...) DEFAULT_CHAT_FRAME:AddMessage("|cff88ff88[TacoRot]|r "..TacoRot_ToStringAll(...)) end

function TacoRot:OnInitialize()
  self.db = AceDB:New("TacoRotDB", defaults, true)

  local opts = {
    type="group", name="TacoRot", args={
      unlock = {type="toggle", name="Unlock", order=1,
        get=function() return self.db.profile.unlock end,
        set=function(_,v) self.db.profile.unlock=v; self:UpdateLock() end},
      window = {type="toggle", name="Enable Display Window", order=2,
        get=function() return self.db.profile.window end,
        set=function(_,v) self.db.profile.window=v; self:UpdateVisibility() end},
      next = {type="toggle", name="Enable Next Windows", order=3,
        get=function() return self.db.profile.nextWindows end,
        set=function(_,v) self.db.profile.nextWindows=v; self:UpdateVisibility() end},
      size = {type="range", name="Main Icon Size", order=4, min=24,max=96,step=1,
        get=function() return self.db.profile.iconSize end,
        set=function(_,v) self.db.profile.iconSize=v; self:ApplySizes() end},
      nscale = {type="range", name="Next Icon Scale", order=5, min=0.5,max=1.2,step=0.01,
        get=function() return self.db.profile.nextScale end,
        set=function(_,v) self.db.profile.nextScale=v; self:ApplySizes() end},
      detectors = {type="group", name="Detectors", order=10, args={
        enInt = {type="toggle", name="Interrupt", order=1,
          get=function() return self.db.profile.enableInterrupt end,
          set=function(_,v) self.db.profile.enableInterrupt=v end},
        enPurge = {type="toggle", name="Purge/Devour", order=2,
          get=function() return self.db.profile.enablePurge end,
          set=function(_,v) self.db.profile.enablePurge=v end},
        enDef = {type="toggle", name="Defense", order=3,
          get=function() return self.db.profile.enableDefense end,
          set=function(_,v) self.db.profile.enableDefense=v end},
        hp = {type="range", name="Defense HP%", order=4, min=0.1,max=0.9,step=0.01,
          get=function() return self.db.profile.defHealth end,
          set=function(_,v) self.db.profile.defHealth=v end},
      }},
      open = {type="execute", name="Open UI", order=99, func=function()
        InterfaceOptionsFrame_OpenToCategory("TacoRot"); InterfaceOptionsFrame_OpenToCategory("TacoRot")
      end},
    }
  }
  AceConfig:RegisterOptionsTable("TacoRot", opts)
  self.optionsFrame = AceConfigDialog:AddToBlizOptions("TacoRot", "TacoRot")

  local p = AceDBOptions:GetOptionsTable(self.db)
  AceConfig:RegisterOptionsTable("TacoRot-Profiles", p)
  AceConfigDialog:AddToBlizOptions("TacoRot-Profiles", "Profiles", "TacoRot")

  self:RegisterChatCommand("tacorot", "Slash")
  self:RegisterChatCommand("tr", "Slash")

  self:CreateWindows()
  self:ApplySizes()
  self:UpdateLock()
  self:UpdateVisibility()
end

function TacoRot:OnEnable()
  msg("OnEnable")
  self:SendMessage("TACOROT_ENABLE_CLASS_MODULE")
end

function TacoRot:Slash(input)
  input = (input or ""):lower()
  if input == "" then
    InterfaceOptionsFrame_OpenToCategory("TacoRot"); InterfaceOptionsFrame_OpenToCategory("TacoRot")
    return
  end
  if input == "ul" or input == "unlock" then self:ToggleUnlock() end
end

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
      TacoRotWindow2:Show(); TacoRotWindow3:Show()
    else
      TacoRotWindow2:Hide(); TacoRotWindow3:Hide()
    end
  else
    TacoRotWindow:Hide(); TacoRotWindow2:Hide(); TacoRotWindow3:Hide()
  end
end

function TacoRot:ApplySizes()
  local s = self.db.profile.iconSize
  local n = self.db.profile.nextScale
  if TacoRotWindow then TacoRotWindow:SetSize(s, s) end
  if TacoRotWindow2 then TacoRotWindow2:SetSize(s*n, s*n) end
  if TacoRotWindow3 then TacoRotWindow3:SetSize(s*n, s*n) end
  if TacoRotIntFlash then TacoRotIntFlash:SetSize(self.db.profile.flashSize*0.25, self.db.profile.flashSize*0.25) end
  if TacoRotPurgeFlash then TacoRotPurgeFlash:SetSize(self.db.profile.flashSize*0.25, self.db.profile.flashSize*0.25) end
end
