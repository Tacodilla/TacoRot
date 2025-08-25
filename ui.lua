-- Enhanced ui.lua with GCD Spiral and Quality Improvements
-- Adds circular GCD progress indicator and fixes several issues

local TR = _G.TacoRot
if not TR then return end

-- ===== QUALITY IMPROVEMENT: Better error handling and validation =====
local function SafeCall(func, ...)
    if not func then return nil end
    local success, result = pcall(func, ...)
    if not success then
        print("|cffff0000[TacoRot]|r Error: " .. tostring(result))
        return nil
    end
    return result
end

local function ValidateFrame(frame, name)
    if not frame then
        error("[TacoRot] Failed to create frame: " .. (name or "unknown"))
        return false
    end
    return true
end

-- ===== ENHANCED DATABASE HANDLING =====
local function EnsureDB()
    TR.db = TR.db or {}
    TR.db.profile = TR.db.profile or {}
    TR.db.profile.UI = TR.db.profile.UI or {
        locked = false,
        scale = 1.0,
        point = "CENTER",
        relPoint = "CENTER", 
        x = -90,
        y = 0,
        -- NEW: GCD Cooldown options (simplified since we use Blizzard's system)
        gcdSpiral = {
            enabled = true
        }
    }
    return TR.db.profile
end

-- ===== SPELL TEXTURE SAFETY =====
local function SafeSpellTexture(spellID)
    if not spellID or spellID == 0 then 
        return "Interface\\Icons\\INV_Misc_QuestionMark"
    end
    
    local texture = GetSpellTexture(spellID)
    if texture and texture ~= "" then
        return texture
    end
    
    -- Fallback: try GetSpellInfo
    local name, _, icon = GetSpellInfo(spellID)
    if icon and icon ~= "" then
        return icon
    end
    
    return "Interface\\Icons\\INV_Misc_QuestionMark"
end

-- ===== GCD TRACKING (Using Blizzard's built-in system) =====
-- We use GetSpellCooldown(61304) to get GCD information directly from WoW
-- This is the same method Blizzard uses for action bar cooldowns

-- ===== DRAG FUNCTIONALITY =====
local function EnableDrag(frame, enabled)
    if not ValidateFrame(frame, "drag target") then return end
    
    local DB = EnsureDB()
    
    if enabled then
        frame:EnableMouse(true)
        frame:SetMovable(true)
        frame:RegisterForDrag("LeftButton")
        frame:SetScript("OnDragStart", function(self)
            self:StartMoving()
        end)
        frame:SetScript("OnDragStop", function(self)
            self:StopMovingOrSizing()
            local point, _, relPoint, x, y = self:GetPoint()
            if point and relPoint and x and y then
                DB.UI.x, DB.UI.y = x, y
                DB.UI.point, DB.UI.relPoint = point, relPoint
            end
        end)
    else
        frame:EnableMouse(false)
        frame:SetScript("OnDragStart", nil)
        frame:SetScript("OnDragStop", nil)
    end
end

-- ===== ICON FRAME CREATION =====
local function CreateIconFrame(name, parent, size, x, y)
    if not parent then parent = UIParent end
    
    local f = CreateFrame("Frame", name, parent)
    if not ValidateFrame(f, name) then return nil end
    
    f:SetSize(size, size)
    f:SetPoint("CENTER", UIParent, "CENTER", x or 0, y or 0)
    f:SetFrameStrata("HIGH")

    -- Main icon texture
    local t = f:CreateTexture(nil, "ARTWORK")
    t:SetAllPoints(f)
    t:SetTexture("Interface\\Icons\\INV_Misc_QuestionMark")
    f.icon = t

    -- Highlight texture for cast flash effect
    local highlight = f:CreateTexture(nil, "OVERLAY")
    highlight:SetAllPoints(f)
    highlight:SetTexture("Interface\\Buttons\\UI-Common-MouseHilight")
    highlight:SetBlendMode("ADD")
    highlight:Hide()
    f.highlight = highlight

    f:Show()
    return f
end

-- ===== BLIZZARD-STYLE GCD COOLDOWN CREATION =====
local function CreateGCDCooldown(parent)
    if not ValidateFrame(parent, "GCD cooldown parent") then return nil end
    
    local DB = EnsureDB()
    local config = DB.UI.gcdSpiral
    
    if not config.enabled then return nil end
    
    -- Create cooldown frame (same as Blizzard action buttons)
    local cooldown = CreateFrame("Cooldown", "TacoRotGCDCooldown", parent, "CooldownFrameTemplate")
    cooldown:SetAllPoints(parent) -- Cover the entire main icon
    cooldown:SetFrameLevel(parent:GetFrameLevel() + 2)
    
    -- Configure cooldown appearance to match action bar buttons
    cooldown:SetDrawEdge(true) -- Show the edge highlight
    cooldown:SetDrawSwipe(true) -- Show the sweep animation
    cooldown:SetReverse(false) -- Same direction as action buttons
    
    -- Set cooldown colors to match default UI
    if cooldown.SetSwipeColor then
        cooldown:SetSwipeColor(0, 0, 0, 0.6) -- Dark semi-transparent sweep
    end
    
    cooldown:Show()
    return cooldown
end

-- ===== FRAME CREATION WITH ERROR HANDLING =====
TacoRotWindow = TacoRotWindow or SafeCall(CreateIconFrame, "TacoRotWindow", UIParent, 52, -90, 0)
TacoRotWindow2 = TacoRotWindow2 or SafeCall(CreateIconFrame, "TacoRotWindow2", UIParent, 40, -40, 0)
TacoRotWindow3 = TacoRotWindow3 or SafeCall(CreateIconFrame, "TacoRotWindow3", UIParent, 32, 0, 0)

-- Create GCD Cooldown using Blizzard's system
TacoRotGCDCooldown = nil
if TacoRotWindow then
    TacoRotGCDCooldown = SafeCall(CreateGCDCooldown, TacoRotWindow)
end

-- ===== SECONDARY ANCHOR LOGIC =====
local function AnchorSecondaries()
    if not (TacoRotWindow and TacoRotWindow2 and TacoRotWindow3) then
        print("|cffff0000[TacoRot]|r Warning: Some UI frames missing, skipping anchor")
        return
    end
    
    TacoRotWindow2:ClearAllPoints()
    TacoRotWindow3:ClearAllPoints()
    TacoRotWindow2:SetPoint("LEFT", TacoRotWindow, "RIGHT", 12, 0)
    TacoRotWindow3:SetPoint("LEFT", TacoRotWindow2, "RIGHT", 10, 0)
end

-- ===== UI RESTORATION =====
local function RestoreUI()
    local DB = EnsureDB()
    local ui = DB.UI

    local scale = tonumber(ui.scale) or 1.0
    
    -- Apply scale to all frames safely
    local frames = {TacoRotWindow, TacoRotWindow2, TacoRotWindow3, TacoRotGCDCooldown}
    for _, frame in ipairs(frames) do
        if frame then
            SafeCall(frame.SetScale, frame, scale)
        end
    end

    -- Restore position
    if TacoRotWindow and ui.point and ui.relPoint and ui.x and ui.y then
        TacoRotWindow:ClearAllPoints()
        TacoRotWindow:SetPoint(ui.point, UIParent, ui.relPoint, ui.x, ui.y)
    end
    
    AnchorSecondaries()
    
    if TacoRotWindow then
        EnableDrag(TacoRotWindow, not ui.locked)
    end
    
    -- The GCD cooldown automatically follows the main icon since it uses SetAllPoints()
end

-- ================= Enhanced Frame Creation =================
function TR:CreateEnhancedFrame(displayName, config)
    local frame = CreateFrame("Frame", "TacoRot" .. tostring(displayName), UIParent)
    frame:SetWidth(config.iconSize * config.numIcons + config.spacing * (config.numIcons - 1))
    frame:SetHeight(config.iconSize)
    frame:SetPoint(config.anchor, UIParent, config.anchor, config.x, config.y)

    -- Backdrop for configuration mode
    frame.backdrop = CreateFrame("Frame", nil, frame)
    frame.backdrop:SetAllPoints()
    frame.backdrop:SetBackdrop({
        bgFile = "Interface\\Tooltips\\UI-Tooltip-Background",
        edgeFile = "Interface\\Tooltips\\UI-Tooltip-Border",
        tile = true, tileSize = 16, edgeSize = 16,
        insets = { left = 4, right = 4, top = 4, bottom = 4 },
    })
    frame.backdrop:SetBackdropColor(0, 0, 0, 0.8)
    frame.backdrop:SetBackdropBorderColor(1, 1, 1, 1)
    frame.backdrop:Hide()

    return frame
end

-- ================= Icon Helpers =================
function TR:CreateEnhancedIcon(parent, size)
    local icon = CreateFrame("Button", nil, parent)
    icon:SetSize(size, size)

    icon.texture = icon:CreateTexture(nil, "ARTWORK")
    icon.texture:SetAllPoints()
    icon.texture:SetTexCoord(0.1, 0.9, 0.1, 0.9)

    icon.border = icon:CreateTexture(nil, "OVERLAY")
    icon.border:SetTexture("Interface\\Buttons\\UI-ActionButton-Border")
    icon.border:SetAllPoints()
    icon.border:Hide()

    icon.cooldown = CreateFrame("Cooldown", nil, icon)
    icon.cooldown:SetAllPoints()

    icon.count = icon:CreateFontString(nil, "OVERLAY", "NumberFontNormal")
    icon.count:SetPoint("BOTTOMRIGHT", -2, 2)

    icon.hotkey = icon:CreateFontString(nil, "OVERLAY", "NumberFontNormalSmall")
    icon.hotkey:SetPoint("TOPLEFT", 2, -2)

    return icon
end

-- Add function to create icons with keybind display
function TR:CreateIconWithKeybind(parent, size)
  local icon = CreateFrame("Button", nil, parent)
  icon:SetSize(size, size)

  -- Main texture
  icon.texture = icon:CreateTexture(nil, "ARTWORK")
  icon.texture:SetAllPoints()
  icon.texture:SetTexCoord(0.1, 0.9, 0.1, 0.9)

  -- Keybind text
  icon.hotkey = icon:CreateFontString(nil, "OVERLAY", "NumberFontNormalSmall")
  icon.hotkey:SetPoint("TOPLEFT", 2, -2)
  icon.hotkey:SetJustifyH("LEFT")
  icon.hotkey:SetTextColor(1, 1, 1, 0.8)

  -- Count text
  icon.count = icon:CreateFontString(nil, "OVERLAY", "NumberFontNormal")
  icon.count:SetPoint("BOTTOMRIGHT", -2, 2)

  return icon
end

-- Function to update keybind display on icons
function TR:UpdateIconKeybind(icon, spellName)
  if not icon or not icon.hotkey then return end

  local settings = self.db.profile.keybinds or { enabled = true, lowercase = false }

  if not settings.enabled then
    icon.hotkey:SetText("")
    return
  end

  local keybind = self:GetKeybindForSpell(spellName, settings.lowercase)

  if keybind and keybind ~= "" then
    local displayText = keybind
    displayText = displayText:gsub("CTRL%-", "C-")
    displayText = displayText:gsub("ALT%-", "A-")
    displayText = displayText:gsub("SHIFT%-", "S-")
    displayText = displayText:gsub("BUTTON", "M")

    if string.len(displayText) > 6 then
      displayText = string.sub(displayText, 1, 6)
    end

    icon.hotkey:SetText(displayText)
  else
    icon.hotkey:SetText("")
  end
end

function TR:UpdateIconAppearance(icon, spellID, isUsable, inRange)
    if not icon or not spellID then return end

    local texture = GetSpellTexture(spellID)
    if texture then
        icon.texture:SetTexture(texture)
        icon.texture:Show()
    else
        icon.texture:Hide()
    end

    if not isUsable then
        icon.texture:SetVertexColor(0.4, 0.4, 0.4)
    elseif not inRange then
        icon.texture:SetVertexColor(1, 0.4, 0.4)
    else
        icon.texture:SetVertexColor(1, 1, 1)
    end

    if isUsable and inRange then
        icon.border:Show()
    else
        icon.border:Hide()
    end
end

-- ===== BLIZZARD GCD COOLDOWN UPDATE LOGIC =====
local function UpdateGCDCooldown()
    if not TacoRotGCDCooldown then return end
    
    -- Get GCD information directly from WoW
    local start, duration = GetSpellCooldown(61304) -- Global Cooldown spell ID
    
    if start and start > 0 and duration and duration > 0 then
        -- GCD is active - show the cooldown spiral
        TacoRotGCDCooldown:SetCooldown(start, duration)
        TacoRotGCDCooldown:Show()
    else
        -- No GCD - hide the cooldown
        TacoRotGCDCooldown:SetCooldown(0, 0)
        TacoRotGCDCooldown:Hide()
    end
end

-- ===== PUBLIC API =====
function TR.UI_Update(mainID, next1, next2)
    -- Update ability icons
    if TacoRotWindow and TacoRotWindow.icon then
        TacoRotWindow.icon:SetTexture(SafeSpellTexture(mainID))
    end
    if TacoRotWindow2 and TacoRotWindow2.icon then
        TacoRotWindow2.icon:SetTexture(SafeSpellTexture(next1))
    end
    if TacoRotWindow3 and TacoRotWindow3.icon then
        TacoRotWindow3.icon:SetTexture(SafeSpellTexture(next2))
    end
    
    -- Update GCD cooldown (Blizzard-style)
    UpdateGCDCooldown()
end

-- Adapter for newer engines
TR.UI = TR.UI or {}
function TR.UI:Update(a, b, c) 
    TR.UI_Update(a, b, c) 
end

-- ===== CAST FLASH SYSTEM =====
function TR:SetMainCastFlash(on)
    if not (TacoRotWindow and TacoRotWindow.highlight) then return end
    
    if on then
        TacoRotWindow.highlight:Show()
    else
        TacoRotWindow.highlight:Hide()
    end
end

-- ===== GCD COOLDOWN CONFIGURATION API =====
function TR:ConfigureGCDCooldown(options)
    local DB = EnsureDB()
    if options then
        for k, v in pairs(options) do
            DB.UI.gcdSpiral[k] = v -- Keep same config structure for compatibility
        end
    end
    
    -- Recreate cooldown with new settings
    if TacoRotGCDCooldown then
        TacoRotGCDCooldown:Hide()
        TacoRotGCDCooldown = nil
    end
    
    if TacoRotWindow and DB.UI.gcdSpiral.enabled then
        TacoRotGCDCooldown = SafeCall(CreateGCDCooldown, TacoRotWindow)
        RestoreUI()
    end
end

-- ===== ENHANCED SLASH COMMANDS =====
SLASH_TACOROTUI1 = "/trui"
SlashCmdList["TACOROTUI"] = function(msg)
    local args = {strsplit(" ", msg:lower())}
    local cmd = args[1] or ""
    local DB = EnsureDB()
    
    if cmd == "unlock" then
        DB.UI.locked = false
        if TacoRotWindow then
            EnableDrag(TacoRotWindow, true)
        end
        DEFAULT_CHAT_FRAME:AddMessage("|cffffcc00[TacoRot]|r UI unlocked. Drag the main icon.")
        
    elseif cmd == "lock" then
        DB.UI.locked = true
        if TacoRotWindow then
            EnableDrag(TacoRotWindow, false)
        end
        DEFAULT_CHAT_FRAME:AddMessage("|cffffcc00[TacoRot]|r UI locked.")
        
    elseif cmd == "scale" then
        local v = tonumber(args[2])
        if v and v >= 0.5 and v <= 2.0 then
            DB.UI.scale = v
            RestoreUI()
            DEFAULT_CHAT_FRAME:AddMessage("|cffffcc00[TacoRot]|r UI scale set to " .. v)
        else
            DEFAULT_CHAT_FRAME:AddMessage("|cffffcc00[TacoRot]|r Usage: /trui scale 0.5 - 2.0")
        end
        
    elseif cmd == "spiral" or cmd == "gcd" then
        local subcmd = args[2] or ""
        if subcmd == "on" then
            TR:ConfigureGCDCooldown({enabled = true})
            DEFAULT_CHAT_FRAME:AddMessage("|cffffcc00[TacoRot]|r GCD Cooldown enabled.")
        elseif subcmd == "off" then
            TR:ConfigureGCDCooldown({enabled = false})
            DEFAULT_CHAT_FRAME:AddMessage("|cffffcc00[TacoRot]|r GCD Cooldown disabled.")
        else
            DEFAULT_CHAT_FRAME:AddMessage("|cffffcc00[TacoRot]|r Usage: /trui gcd [on|off]")
        end
        
    elseif cmd == "reset" then
        DB.UI.point, DB.UI.relPoint, DB.UI.x, DB.UI.y = nil, nil, nil, nil
        DB.UI.scale = 1.0
        RestoreUI()
        DEFAULT_CHAT_FRAME:AddMessage("|cffffcc00[TacoRot]|r UI position reset.")
        
    elseif cmd == "debug" then
        DEFAULT_CHAT_FRAME:AddMessage("|cffffcc00[TacoRot]|r Debug Info:")
        DEFAULT_CHAT_FRAME:AddMessage("  Frames: " .. 
            (TacoRotWindow and "1" or "0") .. "/" ..
            (TacoRotWindow2 and "1" or "0") .. "/" ..
            (TacoRotWindow3 and "1" or "0") .. "/" ..
            (TacoRotGCDCooldown and "1" or "0"))
        
        -- Show current GCD status
        local start, duration = GetSpellCooldown(61304)
        local gcdActive = start and start > 0 and duration and duration > 0
        local remaining = gcdActive and ((start + duration) - GetTime()) or 0
        
        DEFAULT_CHAT_FRAME:AddMessage("  GCD: " .. 
            (gcdActive and "Active" or "Inactive") .. 
            " (" .. string.format("%.2f", remaining) .. "s)")
            
    else
        DEFAULT_CHAT_FRAME:AddMessage("|cffffcc00[TacoRot]|r Commands:")
        DEFAULT_CHAT_FRAME:AddMessage("  /trui unlock|lock - Toggle UI drag mode")
        DEFAULT_CHAT_FRAME:AddMessage("  /trui scale <0.5-2.0> - Set UI scale")
        DEFAULT_CHAT_FRAME:AddMessage("  /trui gcd [on|off] - Configure GCD cooldown display")
        DEFAULT_CHAT_FRAME:AddMessage("  /trui reset - Reset position and scale")
        DEFAULT_CHAT_FRAME:AddMessage("  /trui debug - Show debug information")
    end
end

-- ===== IMPROVED EVENT HANDLING =====
local eventFrame = CreateFrame("Frame")
eventFrame:RegisterEvent("PLAYER_LOGIN")
eventFrame:RegisterEvent("ADDON_LOADED")

-- Update GCD cooldown when spells are cast
local cooldownUpdateFrame = CreateFrame("Frame")
cooldownUpdateFrame:RegisterEvent("SPELL_UPDATE_COOLDOWN")
cooldownUpdateFrame:RegisterEvent("ACTIONBAR_UPDATE_COOLDOWN")
cooldownUpdateFrame:SetScript("OnEvent", function()
    UpdateGCDCooldown()
end)

eventFrame:SetScript("OnEvent", function(self, event, addonName)
    if event == "PLAYER_LOGIN" then
        SafeCall(RestoreUI)
        DEFAULT_CHAT_FRAME:AddMessage("|cff55ff55[TacoRot]|r Enhanced UI loaded with Blizzard GCD Cooldown")
    elseif event == "ADDON_LOADED" and addonName == "TacoRot" then
        -- Additional initialization if needed
        if not TacoRotGCDCooldown and EnsureDB().UI.gcdSpiral.enabled then
            SafeCall(function()
                TacoRotGCDCooldown = CreateGCDCooldown(TacoRotWindow)
                RestoreUI()
            end)
        end
    end
end)