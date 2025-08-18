-- ui.lua — TacoRot lightweight UI for 3.3.5
-- Drag to move, saves position, safe spellID textures only, defensive DB init.

local TR = _G.TacoRot or {}
_G.TacoRot = TR

-- ===================== DB Helpers =====================
local function EnsureDB()
    _G.TacoRotDB = _G.TacoRotDB or {}
    local DB = _G.TacoRotDB
    DB.UI = DB.UI or {}
    if DB.UI.locked == nil then DB.UI.locked = false end
    if DB.UI.scale  == nil then DB.UI.scale  = 1.0  end
    return DB
end
EnsureDB()

-- ===================== Icon Helpers =====================
_G.TacoRotIconFallbacks = _G.TacoRotIconFallbacks or {}
local fb = _G.TacoRotIconFallbacks

local function SafeSpellTexture(id)
    if type(id) == "number" and id > 0 then
        -- try direct spell texture
        local tex = GetSpellTexture(id)
        if tex then return tex end
        -- 3.3.5 sometimes doesn’t return a texture for unknown ranks/spells:
        local _, _, icon = GetSpellInfo(id)
        if icon then return icon end
    end
  
  return fb[id] or "Interface\\Icons\\INV_Misc_QuestionMark"
end

local function EnableDrag(frame, enable)
    if not frame then return end
    frame:SetMovable(true)
    frame:SetClampedToScreen(true)
    if enable then
        frame:EnableMouse(true)
        frame:RegisterForDrag("LeftButton")
        frame:SetScript("OnDragStart", function(self) self:StartMoving() end)
        frame:SetScript("OnDragStop", function(self)
            self:StopMovingOrSizing()
            if self == TacoRotWindow then
                local DB = EnsureDB()
                local point, rel, relPoint, x, y = self:GetPoint(1)
                DB.UI.point, DB.UI.relPoint, DB.UI.x, DB.UI.y = point, relPoint, x, y
            end
        end)
    else
        frame:EnableMouse(false)
        frame:SetScript("OnDragStart", nil)
        frame:SetScript("OnDragStop", nil)
    end
end

local function CreateIconFrame(name, parent, size, x, y)
    local f = CreateFrame("Frame", name, parent or UIParent)
    f:SetSize(size, size)
    f:SetPoint("CENTER", UIParent, "CENTER", x or 0, y or 0)
    f:SetFrameStrata("HIGH")

    local t = f:CreateTexture(nil, "ARTWORK")
    t:SetAllPoints(f)
    t:SetTexture("Interface\\Icons\\INV_Misc_QuestionMark")
    f.icon = t

    f:Show()
    return f
end

TacoRotWindow  = TacoRotWindow  or CreateIconFrame("TacoRotWindow",  UIParent, 52, -90, 0)
TacoRotWindow2 = TacoRotWindow2 or CreateIconFrame("TacoRotWindow2", UIParent, 40, -40, 0)
TacoRotWindow3 = TacoRotWindow3 or CreateIconFrame("TacoRotWindow3", UIParent, 32,   0, 0)

local function AnchorSecondaries()
    TacoRotWindow2:ClearAllPoints()
    TacoRotWindow3:ClearAllPoints()
    TacoRotWindow2:SetPoint("LEFT", TacoRotWindow, "RIGHT", 12, 0)
    TacoRotWindow3:SetPoint("LEFT", TacoRotWindow2, "RIGHT", 10, 0)
end

local function RestoreUI()
    local DB = EnsureDB()
    local ui = DB.UI

    local scale = tonumber(ui.scale) or 1.0
    TacoRotWindow:SetScale(scale)
    TacoRotWindow2:SetScale(scale)
    TacoRotWindow3:SetScale(scale)

    if ui.point and ui.relPoint and ui.x and ui.y then
        TacoRotWindow:ClearAllPoints()
        TacoRotWindow:SetPoint(ui.point, UIParent, ui.relPoint, ui.x, ui.y)
    end
    AnchorSecondaries()
    EnableDrag(TacoRotWindow, not ui.locked)
end

-- public API for engines to update icons
function TR.UI_Update(mainID, next1, next2)
    if TacoRotWindow and TacoRotWindow.icon then
        TacoRotWindow.icon:SetTexture(SafeSpellTexture(mainID))
    end
    if TacoRotWindow2 and TacoRotWindow2.icon then
        TacoRotWindow2.icon:SetTexture(SafeSpellTexture(next1))
    end
    if TacoRotWindow3 and TacoRotWindow3.icon then
        TacoRotWindow3.icon:SetTexture(SafeSpellTexture(next2))
    end
end

-- adapter for newer engines that call TR.UI:Update(...)
TR.UI = TR.UI or {}
function TR.UI:Update(a,b,c) TR.UI_Update(a,b,c) end

-- flash helper the core toggles during cast
function TR:SetMainCastFlash(on)
    if not TacoRotWindow or not TacoRotWindow.icon then return end
    TacoRotWindow.icon:SetDesaturated(on and false or false) -- no-op visual; kept for compatibility
end

SLASH_TACOROTUI1 = "/trui"
SlashCmdList["TACOROTUI"] = function(msg)
    msg = (msg or ""):lower()
    local DB = EnsureDB()
    if msg == "unlock" then
        DB.UI.locked = false; EnableDrag(TacoRotWindow, true)
        DEFAULT_CHAT_FRAME:AddMessage("|cffffcc00[TacoRot]|r UI unlocked. Drag the main icon.")
    elseif msg == "lock" then
        DB.UI.locked = true; EnableDrag(TacoRotWindow, false)
        DEFAULT_CHAT_FRAME:AddMessage("|cffffcc00[TacoRot]|r UI locked.")
    elseif msg:find("^scale") then
        local v = tonumber(msg:match("scale%s+([%d%.]+)"))
        if v and v >= 0.5 and v <= 2.0 then
            DB.UI.scale = v; RestoreUI()
            DEFAULT_CHAT_FRAME:AddMessage("|cffffcc00[TacoRot]|r UI scale set to "..v)
        else
            DEFAULT_CHAT_FRAME:AddMessage("|cffffcc00[TacoRot]|r Usage: /trui scale 0.5 - 2.0")
        end
    elseif msg == "reset" then
        DB.UI.point, DB.UI.relPoint, DB.UI.x, DB.UI.y = nil, nil, nil, nil
        DB.UI.scale = 1.0
        RestoreUI()
        DEFAULT_CHAT_FRAME:AddMessage("|cffffcc00[TacoRot]|r UI position reset.")
    else
        DEFAULT_CHAT_FRAME:AddMessage("|cffffcc00[TacoRot]|r /trui unlock | lock | reset | scale <0.5-2.0>")
    end
end

local f = CreateFrame("Frame")
f:RegisterEvent("PLAYER_LOGIN")
f:SetScript("OnEvent", function()
    RestoreUI()
    DEFAULT_CHAT_FRAME:AddMessage("|cff55ff55[TacoRot]|r UI loaded (movable, safe spellID textures)")
end)
