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

-- Call once at file load just in case
EnsureDB()

-- ===================== Icon Helpers =====================
_G.TacoRotIconFallbacks = _G.TacoRotIconFallbacks or {}
local fb = _G.TacoRotIconFallbacks

local function SafeSpellTexture(id)
    if type(id) == "number" and id > 0 then
        local tex = GetSpellTexture(id)  -- correct for spellID on 3.3.5
        if tex then return tex end
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
            -- save position of main window
            if self == TacoRotWindow then
                local DB = EnsureDB()
                local point, rel, relPoint, x, y = self:GetPoint(1)
                DB.UI.pos = { point, rel and rel:GetName() or "UIParent", relPoint, x, y }
                DB.UI.scale = self:GetScale()
            end
        end)
    else
        frame:EnableMouse(false)
        frame:RegisterForDrag()
        frame:SetScript("OnDragStart", nil)
        frame:SetScript("OnDragStop",  nil)
    end
end

-- ===================== Frames ======================
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

-- Main + two next icons (positions will be anchored off main)
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

    TacoRotWindow:ClearAllPoints()
    if ui.pos and ui.pos[1] then
        local p, relName, rp, x, y = ui.pos[1], ui.pos[2], ui.pos[3], ui.pos[4], ui.pos[5]
        local rel = (type(relName) == "string" and _G[relName]) or UIParent
        TacoRotWindow:SetPoint(p, rel, rp, x, y)
    else
        TacoRotWindow:SetPoint("CENTER", UIParent, "CENTER", -90, 0)
    end

    AnchorSecondaries()
    EnableDrag(TacoRotWindow, not ui.locked)
    -- Dragging the small frames too? flip to true:
    EnableDrag(TacoRotWindow2, false)
    EnableDrag(TacoRotWindow3, false)
end

-- ================== Public UI API ===================
function TR:ApplyIcon(frame, spellID)
    if not frame then return end
    local tex = SafeSpellTexture(spellID)
    if frame.icon then
        frame.icon:SetTexture(tex)
        frame.spellID = spellID
    elseif frame.tex then
        frame.tex:SetTexture(tex)
        frame.spellID = spellID
    end
end

TR.UI = TR.UI or {}
function TR.UI:Update(a, b, c)
    if TacoRotWindow  then TR:ApplyIcon(TacoRotWindow,  a) end
    if TacoRotWindow2 then TR:ApplyIcon(TacoRotWindow2, b) end
    if TacoRotWindow3 then TR:ApplyIcon(TacoRotWindow3, c) end
end

-- ================= Slash Commands ==================
SLASH_TACOROTUI1 = "/tacorotui"
SLASH_TACOROTUI2 = "/trui"
SlashCmdList["TACOROTUI"] = function(msg)
    msg = (msg or ""):lower()
    local DB = EnsureDB()
    if msg == "unlock" then
        DB.UI.locked = false
        EnableDrag(TacoRotWindow, true)
        DEFAULT_CHAT_FRAME:AddMessage("|cffffcc00[TacoRot]|r UI unlocked (drag the MAIN icon).")
    elseif msg == "lock" then
        DB.UI.locked = true
        EnableDrag(TacoRotWindow, false)
        DEFAULT_CHAT_FRAME:AddMessage("|cffffcc00[TacoRot]|r UI locked.")
    elseif msg:match("^scale%s+[%d%.]+") then
        local val = tonumber(msg:match("[%d%.]+"))
        if val and val >= 0.5 and val <= 2.0 then
            DB.UI.scale = val
            TacoRotWindow:SetScale(val)
            DEFAULT_CHAT_FRAME:AddMessage("|cffffcc00[TacoRot]|r UI scale set to "..val)
        else
            DEFAULT_CHAT_FRAME:AddMessage("|cffff5555[TacoRot]|r Scale must be between 0.5 and 2.0")
        end
    elseif msg == "reset" then
        DB.UI.pos = nil
        DB.UI.scale = 1.0
        RestoreUI()
        DEFAULT_CHAT_FRAME:AddMessage("|cffffcc00[TacoRot]|r UI position reset.")
    else
        DEFAULT_CHAT_FRAME:AddMessage("|cffffcc00[TacoRot]|r /trui unlock | lock | reset | scale <0.5-2.0>")
    end
end

-- ================= Events ==================
local f = CreateFrame("Frame")
f:RegisterEvent("PLAYER_LOGIN")
f:SetScript("OnEvent", function()
    RestoreUI()
    DEFAULT_CHAT_FRAME:AddMessage("|cff55ff55[TacoRot]|r UI loaded (movable, safe spellID textures)")
end)
