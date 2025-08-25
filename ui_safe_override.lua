-- ui_safe_override.lua — safe icon application for 3.3.5 using spellIDs
-- Loads after ui.lua. If TacoRot:ApplyIcon exists, we wrap it; otherwise we define one.

local fb = _G.TacoRotIconFallbacks or {}
_G.TacoRotIconFallbacks = fb

local function SafeSpellTexture(id)
  if type(id) == "number" and id > 0 then
    local t = GetSpellTexture(id)    -- correct API for spellID on 3.3.5
    if t then return t end
  end
  return fb[id] or "Interface\\Icons\\INV_Misc_QuestionMark"
end

local TR = _G.TacoRot or {}
_G.TacoRot = TR

-- Wrap existing ApplyIcon if present; else define it.
local old = TR.ApplyIcon
TR.ApplyIcon = function(self, frame, spellID)
  local tex = SafeSpellTexture(spellID)
  if frame and frame.icon then
    frame.icon:SetTexture(tex); frame.spellID = spellID
  elseif frame and frame.tex then
    frame.tex:SetTexture(tex);  frame.spellID = spellID
  end
  if old then return old(self, frame, spellID) end
end

-- Also harden the default UI updater if it exists and does raw GetSpellInfo
if TR.UI and type(TR.UI.Update) == "function" then
  local _u = TR.UI.Update
  TR.UI.Update = function(selfUI, a, b, c)
    -- Call original first (in case it sets sizes/positions)
    _u(selfUI, a, b, c)
    -- Then force safe textures so no "Invalid spell slot" ever fires
    if TacoRotWindow  and TacoRotWindow.icon  then TacoRotWindow.icon:SetTexture(SafeSpellTexture(a)) end
    if TacoRotWindow2 and TacoRotWindow2.icon then TacoRotWindow2.icon:SetTexture(SafeSpellTexture(b)) end
    if TacoRotWindow3 and TacoRotWindow3.icon then TacoRotWindow3.icon:SetTexture(SafeSpellTexture(c)) end
  end
end

DEFAULT_CHAT_FRAME:AddMessage("|cff55ff55[TacoRot]|r Safe icon override active")
