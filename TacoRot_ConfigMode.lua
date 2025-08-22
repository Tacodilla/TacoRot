-- TacoRot_ConfigMode.lua
local TR, ns = _G.TacoRot, _G.TacoRot.ns
TR._movers = TR._movers or {}

function TR.RegisterDisplayFrame(frame, label)
  if not frame or TR._movers[frame] then return end
  TR._movers[frame] = { frame = frame, label = label or frame:GetName() or "Display" }
end

local headers = {}

local function makeHeader(m)
  local h = CreateFrame("Frame", nil, m.frame)
  h:SetAllPoints(m.frame)
  h:EnableMouse(true)
  h:SetMovable(true)
  h:RegisterForDrag("LeftButton")
  h:SetScript("OnDragStart", function() m.frame:StartMoving() end)
  h:SetScript("OnDragStop",  function() m.frame:StopMovingOrSizing() end)
  local t = h:CreateTexture(nil, "BACKGROUND"); t:SetAllPoints(); t:SetTexture(0,0,0,0.4)
  local fs = h:CreateFontString(nil, "OVERLAY", "GameFontHighlight")
  fs:SetPoint("TOP", 0, -2); fs:SetText(m.label or "Display")
  headers[m.frame] = h
end

function TR.StartConfiguration()
  for _,m in pairs(TR._movers) do
    m.frame:SetMovable(true); m.frame:EnableMouse(true)
    m.frame:SetClampedToScreen(true)
    if not headers[m.frame] then makeHeader(m) end
    headers[m.frame]:Show()
  end
end

function TR.StopConfiguration()
  for _,m in pairs(TR._movers) do
    m.frame:EnableMouse(false)
    if headers[m.frame] then headers[m.frame]:Hide() end
  end
end

SLASH_TACOROTCFG1 = "/trcfg"
SlashCmdList.TACOROTCFG = function(msg)
  msg = msg and msg:lower() or ""
  if msg == "on" then TR.StartConfiguration()
  elseif msg == "off" then TR.StopConfiguration()
  else
    DEFAULT_CHAT_FRAME:AddMessage("|cff00ffffTacoRot|r /trcfg on | off")
  end
end
