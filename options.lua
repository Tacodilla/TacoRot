
-- options.lua — extend existing Ace options with per-class "Padding" controls.
-- We keep your old logic (AceConfig) and just add the same section Hunter had
-- to Warrior, Paladin, Mage, Priest, and Shaman. Safe defaults are created
-- on the fly under TacoRot.db.profile.pad[CLASS_TOKEN].

local TR = _G.TacoRot
if not TR then return end

local Registry = LibStub("AceConfigRegistry-3.0", true)
if not Registry then return end

local CLASS_CAPS = {
  WARRIOR="Warrior", PALADIN="Paladin", HUNTER="Hunter", ROGUE="Rogue",
  PRIEST="Priest", DEATHKNIGHT="Death Knight", SHAMAN="Shaman", MAGE="Mage",
  WARLOCK="Warlock", DRUID="Druid",
}

local function PlayerToken()
  local _, class = UnitClass("player")
  return class
end

local function EnsurePad(token)
  if not (TR and TR.db and TR.db.profile) then return end
  TR.db.profile.pad = TR.db.profile.pad or {}
  local pad = TR.db.profile.pad[token]
  if not pad then
    pad = { enabled = true, gcd = 1.6 }
    TR.db.profile.pad[token] = pad
  else
    if pad.enabled == nil then pad.enabled = true end
    if not pad.gcd then pad.gcd = 1.6 end
  end
end

local function GetPad(token)
  if not (TR and TR.db and TR.db.profile and TR.db.profile.pad) then return {enabled=true,gcd=1.6} end
  return TR.db.profile.pad[token] or {enabled=true,gcd=1.6}
end

local function addPaddingGroup(node, token)
  EnsurePad(token)
  node.args.padding = {
    type = "group",
    name = "Padding",
    order = 2,
    inline = true,
    args = {
      enabled = {
        type="toggle", order=1, name="Enable low-level padding",
        desc="Fills the queue with soon-ready abilities and safe fallbacks so early levels never feel empty.",
        get=function() return GetPad(token).enabled end,
        set=function(_,v) EnsurePad(token); TR.db.profile.pad[token].enabled = v and true or false end,
      },
      gcd = {
        type="range", order=2, name="Pad window (seconds)",
        min=0.0, max=2.0, step=0.05,
        get=function() return GetPad(token).gcd end,
        set=function(_,v) EnsurePad(token); TR.db.profile.pad[token].gcd = tonumber(v) or 1.6 end,
      },
    },
  }
end

local function addSpellToggles(groupNode, abilities)
  local order = 1
  for key, spellID in pairs(abilities or {}) do
    if type(spellID) == "number" then
      local name, _, icon = GetSpellInfo(spellID)
      name = name or tostring(key) or ("Spell "..spellID)
      groupNode.args["s"..spellID] = {
        type  = "toggle",
        width = "full",
        order = order,
        name  = (icon and ("|T"..icon..":16|t ") or "")..name,
        get   = function()
          local v = TR.db and TR.db.profile and TR.db.profile.spells and TR.db.profile.spells[spellID]
          return v ~= false
        end,
        set   = function(_, v)
          TR.db.profile.spells = TR.db.profile.spells or {}
          TR.db.profile.spells[spellID] = v and true or false
        end,
      }
      order = order + 1
    end
  end
end

local function BuildClassOptions()
  local opts = TR.OptionsRoot
  if not (opts and opts.args) then return end
  -- Ensure parent "Class"
  if not opts.args.class then
    opts.args.class = { type="group", name="Class", order=20, childGroups="tree", args={} }
  else
    opts.args.class.args = {}
  end

  local _, class = UnitClass("player")
  local token = class

  local function addClass(camel, idsGlobalName, key)
    local IDS = _G[idsGlobalName]
    if IDS and IDS.UpdateRanks then IDS:UpdateRanks() end
    local node = {
      type = "group",
      name = camel,
      order = 1,
      args = {
        spells = { type="group", name="Spells", order=1, args={} },
      },
    }
    addSpellToggles(node.args.spells, IDS and IDS.Ability)
    addPaddingGroup(node, token)
    opts.args.class.args[key] = node
  end

  if token == "ROGUE" then
    addClass("Rogue", "TacoRot_IDS_Rogue", "rogue")
  elseif token == "WARLOCK" then
    addClass("Warlock", "TacoRot_IDS", "warlock")
  elseif token == "HUNTER" then
    addClass("Hunter", "TacoRot_IDS_Hunter", "hunter")
  elseif token == "DRUID" then
    addClass("Druid", "TacoRot_IDS_Druid", "druid")
  elseif token == "WARRIOR" then
    addClass("Warrior", "TacoRot_IDS_Warrior", "warrior")
  elseif token == "PALADIN" then
    addClass("Paladin", "TacoRot_IDS_Paladin", "paladin")
  elseif token == "MAGE" then
    addClass("Mage", "TacoRot_IDS_Mage", "mage")
  elseif token == "PRIEST" then
    addClass("Priest", "TacoRot_IDS_Priest", "priest")
  elseif token == "SHAMAN" then
    addClass("Shaman", "TacoRot_IDS_Shaman", "shaman")
  elseif token == "DEATHKNIGHT" then
    -- Hooked later when DK is added
    local IDS = _G.TacoRot_IDS_Deathknight
    local node = { type="group", name="Death Knight", order=1, args = { spells={type="group", name="Spells", order=1, args={}} } }
    addSpellToggles(node.args.spells, IDS and IDS.Ability)
    addPaddingGroup(node, token)
    opts.args.class.args.dk = node
  end

  Registry:NotifyChange("TacoRot")
end

-- Build once after login
local f = CreateFrame("Frame")
f:RegisterEvent("PLAYER_LOGIN")
f:SetScript("OnEvent", function()
  -- Seed pad defaults for all classes once so options always show sane values
  for tok in pairs(CLASS_CAPS) do EnsurePad(tok) end
  BuildClassOptions()
end)

function TR:RebuildOptions()
  BuildClassOptions()
end
