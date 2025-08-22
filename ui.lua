-- keybinds.lua — TacoRot Keybind Detection System for 3.3.5
local TR = _G.TacoRot
if not TR then return end

TR.Keys = TR.Keys or {}
local keys = TR.Keys

-- Debug storage
local debugInfo = {}
local function DebugLog(msg)
  table.insert(debugInfo, msg)
  if TR.db and TR.db.profile and TR.db.profile.keybindDebug then
    print("TacoRot Keybind: " .. msg)
  end
end

-- Store keybind information from action bars
local function StoreKeybindInfo(barNum, binding, action, actionType)
  if not binding or binding == "" then return end
  if not action then return end
  
  local spellName
  if actionType == "spell" then
    spellName = GetSpellInfo(action)
  elseif actionType == "item" then
    spellName = GetItemInfo(action)
  elseif actionType == "macro" then
    spellName = GetMacroInfo(action)
  else
    return
  end
  
  if not spellName or spellName == "" then return end
  
  -- Store binding data
  keys[spellName] = keys[spellName] or {
    lower = {},
    upper = {},
    console = {}
  }
  
  keys[spellName].lower[1] = binding:lower()
  keys[spellName].upper[1] = binding:upper()
  
  DebugLog("Stored: " .. spellName .. " -> " .. binding)
  return spellName
end

-- Read keybindings from action bars
local function ReadKeybindings()
  if not TR:IsValidSpec() then return end
  
  wipe(keys)
  wipe(debugInfo)
  
  local foundBindings = 0
  
  -- Check standard action bar slots (72 slots = 6 bars x 12 slots)
  for slot = 1, 72 do
    local actionType, actionID = GetActionInfo(slot)
    
    if actionType and actionID then
      local binding
      
      if slot <= 12 then
        binding = GetBindingKey("ACTIONBUTTON" .. slot)
      elseif slot <= 24 then
        binding = GetBindingKey("ACTIONBUTTON" .. (slot - 12))
      elseif slot <= 36 then
        binding = GetBindingKey("MULTIACTIONBAR3BUTTON" .. (slot - 24))
      elseif slot <= 48 then
        binding = GetBindingKey("MULTIACTIONBAR4BUTTON" .. (slot - 36))
      elseif slot <= 60 then
        binding = GetBindingKey("MULTIACTIONBAR2BUTTON" .. (slot - 48))
      elseif slot <= 72 then
        binding = GetBindingKey("MULTIACTIONBAR1BUTTON" .. (slot - 60))
      end
      
      if binding and binding ~= "" then
        local stored = StoreKeybindInfo(math.ceil(slot/12), binding, actionID, actionType)
        if stored then
          foundBindings = foundBindings + 1
        end
      end
    end
  end
  
  -- Bartender4 support
  if _G["Bartender4"] then
    for barNum = 1, 10 do
      local bar = _G["BT4Bar" .. barNum]
      for keyNum = 1, 12 do
        local slot = (barNum - 1) * 12 + keyNum
        local bindingKey = "ACTIONBUTTON" .. keyNum
        
        if barNum > 1 and bar and not bar.disabled then
          bindingKey = "CLICK BT4Button" .. slot .. ":LeftButton"
        end
        
        local binding = GetBindingKey(bindingKey)
        local actionType, actionID = GetActionInfo(slot)
        
        if binding and actionType and actionID then
          local stored = StoreKeybindInfo(barNum, binding, actionID, actionType)
          if stored then
            foundBindings = foundBindings + 1
          end
        end
      end
    end
  end
  
  DebugLog("Total bindings found: " .. foundBindings)
  return foundBindings
end

-- Get keybind for a spell
function TR:GetKeybindForSpell(spellName, displayLower)
  if not spellName or not keys[spellName] then return "" end
  
  local bindData = keys[spellName]
  
  if displayLower and bindData.lower[1] then
    return bindData.lower[1]
  elseif bindData.upper[1] then
    return bindData.upper[1]
  end
  
  return ""
end

-- Validation function
function TR:IsValidSpec()
  local class = select(2, UnitClass("player"))
  return class == "ROGUE" or class == "WARLOCK" or class == "HUNTER"
end

-- 3.3.5 compatible timer function
local function DelayedCall(delay, func)
  local frame = CreateFrame("Frame")
  local elapsed = 0
  frame:SetScript("OnUpdate", function(self, dt)
    elapsed = elapsed + dt
    if elapsed >= delay then
      frame:SetScript("OnUpdate", nil)
      func()
    end
  end)
end

-- Register events for keybind updates
local frame = CreateFrame("Frame")
frame:RegisterEvent("ADDON_LOADED")
frame:RegisterEvent("PLAYER_LOGIN")
frame:RegisterEvent("UPDATE_BINDINGS")
frame:RegisterEvent("ACTIONBAR_SLOT_CHANGED")

frame:SetScript("OnEvent", function(self, event, ...)
  if event == "ADDON_LOADED" and (...) == "TacoRot" then
    DelayedCall(1, ReadKeybindings)
  elseif event == "PLAYER_LOGIN" then
    DelayedCall(2, ReadKeybindings)
  elseif event == "UPDATE_BINDINGS" or event == "ACTIONBAR_SLOT_CHANGED" then
    DelayedCall(0.1, ReadKeybindings)
  end
end)

-- Make function accessible
TR.ReadKeybindings = ReadKeybindings

-- Debug and test functions
function TR:TestKeybinds()
  local oldDebug = self.db.profile.keybindDebug
  self.db.profile.keybindDebug = true
  
  self:Print("=== TacoRot Keybind Test ===")
  local count = ReadKeybindings()
  self:Print("Found " .. count .. " spells with keybinds")
  
  if count > 0 then
    for spellName, data in pairs(keys) do
      local binding = data.upper[1] or data.lower[1]
      if binding then
        self:Print("  " .. spellName .. " -> " .. binding)
      end
    end
  else
    self:Print("No keybinds found. Debug info:")
    for i, msg in ipairs(debugInfo) do
      if i <= 10 then
        self:Print("  " .. msg)
      end
    end
  end
  
  self.db.profile.keybindDebug = oldDebug
end
