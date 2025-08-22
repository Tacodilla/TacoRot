-- Enhanced ui.lua with GCD Spiral and Quality Improvements
-- Adds circular GCD progress indicator and fixes several issues

local TR = _G.TacoRot
if not TR then return end
local floor = math.floor

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

    -- Keybind overlay
    local keybindText = f:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall")
    keybindText:SetPoint("BOTTOM", f, "BOTTOM", 0, 2)
    keybindText:SetTextColor(1, 1, 0.5)
    f.keybind = keybindText

    -- Cooldown sweep
    local cooldown = CreateFrame("Cooldown", nil, f, "CooldownFrameTemplate")
    cooldown:SetAllPoints(f)
    f.cooldown = cooldown

    -- Priority number
    local priorityText = f:CreateFontString(nil, "OVERLAY", "GameFontNormalLarge")
    priorityText:SetPoint("TOPRIGHT", f, "TOPRIGHT", -2, -2)
    priorityText:SetTextColor(1, 1, 1, 0.9)
    f.priority = priorityText

    -- Conditional border
    local border = f:CreateTexture(nil, "OVERLAY")
    border:SetTexture("Interface\\Buttons\\UI-ActionButton-Border")
    border:SetBlendMode("ADD")
    border:SetAllPoints(f)
    border:Hide()
    f.border = border

    -- Spell name display
    local nameText = f:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall")
    nameText:SetPoint("BOTTOM", f, "TOP", 0, 2)
    nameText:SetTextColor(1, 1, 1)
    f.spellName = nameText

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
local function CreateAllFrames()
    TacoRotWindow = SafeCall(CreateIconFrame, "TacoRotWindow", UIParent, 52, -90, 0)
    TacoRotWindow2 = SafeCall(CreateIconFrame, "TacoRotWindow2", UIParent, 40, -40, 0)
    TacoRotWindow3 = SafeCall(CreateIconFrame, "TacoRotWindow3", UIParent, 32, 0, 0)

    TacoRotGCDCooldown = SafeCall(CreateGCDCooldown, TacoRotWindow)

    -- Resource display
    local resourceBar = CreateFrame("StatusBar", nil, TacoRotWindow)
    resourceBar:SetSize(120, 8)
    resourceBar:SetPoint("BOTTOM", TacoRotWindow, "TOP", 0, 2)
    resourceBar:SetStatusBarTexture("Interface\\TargetingFrame\\UI-StatusBar")
    TR.ResourceBar = resourceBar

    local resourceText = resourceBar:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall")
    resourceText:SetPoint("CENTER")
    TR.ResourceText = resourceText

    -- AoE toggle button
    local aoeButton = CreateFrame("Button", "TacoRotAoEButton", UIParent, "SecureActionButtonTemplate")
    aoeButton:SetSize(40, 40)
    aoeButton:SetPoint("LEFT", TacoRotWindow, "RIGHT", 5, 0)
    aoeButton:SetNormalTexture("Interface\\Icons\\Spell_Fire_SelfDestruct")
    aoeButton:RegisterForClicks("AnyUp")

    local aoeHighlight = aoeButton:CreateTexture(nil, "OVERLAY")
    aoeHighlight:SetTexture("Interface\\Buttons\\CheckButtonHilight")
    aoeHighlight:SetBlendMode("ADD")
    aoeHighlight:SetAllPoints()
    aoeHighlight:Hide()
    aoeButton.highlight = aoeHighlight

    aoeButton:SetScript("OnClick", function()
        if not TR.db or not TR.db.profile then return end
        TR.db.profile.aoe = not TR.db.profile.aoe
        if TR.db.profile.aoe then
            aoeButton.highlight:Show()
            print("|cff00ff00AoE Mode: ON|r")
        else
            aoeButton.highlight:Hide()
            print("|cffff0000AoE Mode: OFF|r")
        end
    end)

    aoeButton:SetScript("OnEnter", function(self)
        GameTooltip:SetOwner(self, "ANCHOR_RIGHT")
        GameTooltip:SetText("Toggle AoE Mode")
        GameTooltip:AddLine("Click to switch between single-target and AoE rotations", 1, 1, 1, true)
        GameTooltip:Show()
    end)
    aoeButton:SetScript("OnLeave", function() GameTooltip:Hide() end)
end

function TR:FindKeybind(spellID)
    local spellName = GetSpellInfo(spellID)
    if not spellName then return "" end

    for i = 1, 120 do
        local actionType, id = GetActionInfo(i)
        if actionType == "spell" then
            local actionSpellName = GetSpellInfo(id)
            if actionSpellName and actionSpellName == spellName then
                local key = GetBindingKey("ACTIONBUTTON" .. i) or
                           GetBindingKey("MULTIACTIONBAR1BUTTON" .. (i - 12)) or
                           GetBindingKey("MULTIACTIONBAR2BUTTON" .. (i - 24))
                if key then
                    key = key:gsub("SHIFT%-", "S-")
                    key = key:gsub("CTRL%-", "C-")
                    key = key:gsub("ALT%-", "A-")
                    return key
                end
            end
        end
    end
    return ""
end

function TR:CheckSpecialConditions(spellID)
    local hp = UnitHealth("player") or 0
    local max = UnitHealthMax("player") or 1
    if max > 0 and (hp / max) < 0.3 then
        return {1, 0, 0, 1}
    end

    if UnitBuff and UnitBuff("player", "Clearcasting") then
        return {0, 1, 0, 1}
    end

    return nil
end

function TR:UpdateResource()
    if not (self.ResourceBar and self.ResourceText) then return end
    local powerType = UnitPowerType("player")
    local current = UnitPower("player", powerType)
    local max = UnitPowerMax("player", powerType)

    if not (current and max and max > 0) then return end

    self.ResourceBar:SetMinMaxValues(0, max)
    self.ResourceBar:SetValue(current)
    self.ResourceText:SetText(floor(current / max * 100) .. "%")

    local colors = {
        [0] = {0.0, 0.0, 1.0},
        [1] = {1.0, 0.0, 0.0},
        [3] = {1.0, 1.0, 0.0},
    }
    local r, g, b = unpack(colors[powerType] or {1, 1, 1})
    self.ResourceBar:SetStatusBarColor(r, g, b)
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
    local icons = {
        { frame = TacoRotWindow,  spell = mainID, index = 1 },
        { frame = TacoRotWindow2, spell = next1, index = 2 },
        { frame = TacoRotWindow3, spell = next2, index = 3 },
    }

    for _, data in ipairs(icons) do
        local frame = data.frame
        local spellID = data.spell
        if frame and frame.icon then
            frame.icon:SetTexture(SafeSpellTexture(spellID))
        end
        if frame and frame.keybind then
            local keybind = TR:FindKeybind(spellID)
            frame.keybind:SetText(keybind)
        end
        if frame and frame.cooldown then
            local start, duration = GetSpellCooldown(spellID or 0)
            if start and duration and duration > 0 then
                frame.cooldown:SetCooldown(start, duration)
                frame.cooldown:Show()
            else
                frame.cooldown:Hide()
            end
        end
        if frame and frame.priority then
            frame.priority:SetText(tostring(data.index))
        end
        if frame and frame.spellName then
            if TR.db and TR.db.profile and TR.db.profile.showSpellNames and spellID then
                local name = GetSpellInfo(spellID)
                frame.spellName:SetText(name or "")
                frame.spellName:Show()
            else
                frame.spellName:Hide()
            end
        end
        if frame and frame.border then
            local color = TR:CheckSpecialConditions(spellID)
            if color then
                frame.border:SetVertexColor(unpack(color))
                frame.border:Show()
            else
                frame.border:Hide()
            end
        end
    end

    UpdateGCDCooldown()
    TR:UpdateResource()
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
eventFrame:RegisterEvent("UNIT_POWER_FREQUENT")
eventFrame:RegisterEvent("UNIT_DISPLAYPOWER")

-- Update GCD cooldown when spells are cast
local cooldownUpdateFrame = CreateFrame("Frame")
cooldownUpdateFrame:RegisterEvent("SPELL_UPDATE_COOLDOWN")
cooldownUpdateFrame:RegisterEvent("ACTIONBAR_UPDATE_COOLDOWN")
cooldownUpdateFrame:SetScript("OnEvent", function()
    UpdateGCDCooldown()
end)

eventFrame:SetScript("OnEvent", function(self, event, arg1)
    if event == "PLAYER_LOGIN" then
        SafeCall(CreateAllFrames)
        SafeCall(RestoreUI)
        TR:UpdateResource()
        DEFAULT_CHAT_FRAME:AddMessage("|cff55ff55[TacoRot]|r Enhanced UI loaded with Blizzard GCD Cooldown")
    elseif event == "ADDON_LOADED" and arg1 == "TacoRot" then
        if not TacoRotGCDCooldown and EnsureDB().UI.gcdSpiral.enabled and TacoRotWindow then
            SafeCall(function()
                TacoRotGCDCooldown = CreateGCDCooldown(TacoRotWindow)
                RestoreUI()
            end)
        end
    elseif event == "UNIT_POWER_FREQUENT" or event == "UNIT_DISPLAYPOWER" then
        if arg1 == "player" then
            TR:UpdateResource()
        end
    end
end)