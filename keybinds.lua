local TR = _G.TacoRot
if not TR then return end

TR.Keys = TR.Keys or {}
local keys = TR.Keys

local keybindData = {}

local function StoreKeybindInfo(barNum, binding, action, actionType, consoleType)
  if not binding or binding == "" or not action then return end

  local spellName, spellID
  if actionType == "spell" then
    spellName = GetSpellInfo(action)
    spellID = action
  elseif actionType == "item" then
    spellName = GetItemInfo(action)
    spellID = action
  else
    return
  end

  if not spellName then return end

  keybindData[spellName] = keybindData[spellName] or { lower = {}, upper = {}, console = {} }

  local bindingText = binding

  if consoleType == "cPort" then
    keybindData[spellName].console[1] = bindingText
  else
    local lowerBinding = bindingText:lower()
    local upperBinding = bindingText:upper()
    keybindData[spellName].lower[1] = lowerBinding
    keybindData[spellName].upper[1] = upperBinding
  end

  return spellName
end

local function ReadKeybindings()
  if TR.IsValidSpec and not TR:IsValidSpec() then return end

  wipe(keybindData)

  for slot = 1, 120 do
    local actionType, actionID = GetActionInfo(slot)
    if actionType and actionID then
      local barNum = math.ceil(slot / 12)
      local keyNum = slot - ((barNum - 1) * 12)
      local binding
      if barNum == 1 then
        binding = GetBindingKey("ACTIONBUTTON" .. keyNum)
      elseif barNum == 2 then
        binding = GetBindingKey("ACTIONBUTTON" .. (keyNum + 12))
      elseif barNum == 3 then
        binding = GetBindingKey("MULTIACTIONBAR3BUTTON" .. keyNum)
      elseif barNum == 4 then
        binding = GetBindingKey("MULTIACTIONBAR4BUTTON" .. keyNum)
      elseif barNum == 5 then
        binding = GetBindingKey("MULTIACTIONBAR2BUTTON" .. keyNum)
      elseif barNum == 6 then
        binding = GetBindingKey("MULTIACTIONBAR1BUTTON" .. keyNum)
      end
      if binding then
        StoreKeybindInfo(barNum, binding, actionID, actionType)
      end
    end
  end

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
          StoreKeybindInfo(barNum, binding, actionID, actionType)
        end
      end
    end
  end

  for spellName, data in pairs(keybindData) do
    keys[spellName] = data
  end
end

function TR:GetKeybindForSpell(spellName, displayLower)
  if not spellName or not keys[spellName] then return "" end
  local bindData = keys[spellName]
  local useLower = displayLower or false
  if useLower and bindData.lower[1] then
    return bindData.lower[1]
  elseif bindData.upper[1] then
    return bindData.upper[1]
  end
  return ""
end

local frame = CreateFrame("Frame")
frame:RegisterEvent("ADDON_LOADED")
frame:RegisterEvent("PLAYER_LOGIN")
frame:RegisterEvent("UPDATE_BINDINGS")
frame:RegisterEvent("ACTIONBAR_SLOT_CHANGED")
frame:RegisterEvent("SPELLS_CHANGED")
frame:SetScript("OnEvent", function(self, event, ...)
  if event == "ADDON_LOADED" and (...) == "TacoRot" then
    if TR.ScheduleTimer then TR:ScheduleTimer(ReadKeybindings, 1) else ReadKeybindings() end
  elseif event == "PLAYER_LOGIN" then
    if TR.ScheduleTimer then TR:ScheduleTimer(ReadKeybindings, 2) else ReadKeybindings() end
  elseif event == "UPDATE_BINDINGS" or event == "ACTIONBAR_SLOT_CHANGED" or event == "SPELLS_CHANGED" then
    if TR.ScheduleTimer then TR:ScheduleTimer(ReadKeybindings, 0.1) else ReadKeybindings() end
  end
end)

TR.ReadKeybindings = ReadKeybindings
