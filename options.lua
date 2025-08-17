-- options.lua
-- Extends the root options table that core.lua registered via AceConfig.
-- 3.3.5-safe: no C_Timer, no AddToBlizOptions here.
-- Builds Class -> Spells toggles for the CURRENT player class and notifies Ace.

local TacoRot = _G.TacoRot
if not TacoRot then return end

local Registry = LibStub("AceConfigRegistry-3.0", true)
if not Registry then return end

-- Build (or rebuild) the class-specific subtree inside TacoRot.OptionsRoot
local function BuildClassOptions()
  local opts = TacoRot.OptionsRoot
  if not (opts and opts.args) then return end

  -- Ensure a parent "Class" node exists
  if not opts.args.class then
    opts.args.class = {
      type = "group",
      name = "Class",
      order = 20,
      childGroups = "tree",
      args = {},
    }
  else
    -- Clear children to rebuild cleanly
    opts.args.class.args = {}
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
            return TacoRot.db and TacoRot.db.profile
               and TacoRot.db.profile.spells[spellID] ~= false
          end,
          set   = function(_, v)
            if TacoRot.db and TacoRot.db.profile then
              TacoRot.db.profile.spells[spellID] = (v and true) or false
            end
          end,
        }
        order = order + 1
      end
    end
  end

  -- Only build for the player’s current class to keep the tree lean.
  local _, class = UnitClass("player")

  if class == "WARLOCK" then
    local IDS = _G.TacoRot_IDS
    if IDS and IDS.UpdateRanks then IDS:UpdateRanks() end
    opts.args.class.args.warlock = {
      type = "group",
      name = "Warlock",
      order = 1,
      args = {
        spells = { type="group", name="Spells", order=1, args={} },
      },
    }
    addSpellToggles(opts.args.class.args.warlock.args.spells, IDS and IDS.Ability)

  elseif class == "ROGUE" then
    local IDS = _G.TacoRot_IDS_Rogue
    if IDS and IDS.UpdateRanks then IDS:UpdateRanks() end
    opts.args.class.args.rogue = {
      type = "group",
      name = "Rogue",
      order = 1,
      args = {
        spells = { type="group", name="Spells", order=1, args={} },
      },
    }
    addSpellToggles(opts.args.class.args.rogue.args.spells, IDS and IDS.Ability)

  elseif class == "HUNTER" then
    local IDS = _G.TacoRot_IDS_Hunter
    if IDS and IDS.UpdateRanks then IDS:UpdateRanks() end
    opts.args.class.args.hunter = {
      type = "group",
      name = "Hunter",
      order = 1,
      args = {
        spells = { type="group", name="Spells", order=1, args={} },
      },
    }
    addSpellToggles(opts.args.class.args.hunter.args.spells, IDS and IDS.Ability)
  end

  -- Tell Ace the table changed so the Blizzard panel refreshes.
  Registry:NotifyChange("TacoRot")
end

-- Build once after login (safe point for Ace options tree)
local f = CreateFrame("Frame")
f:RegisterEvent("PLAYER_LOGIN")
f:SetScript("OnEvent", function()
  BuildClassOptions()
end)

-- Optional: public API if modules want to force a rebuild after rank updates
function TacoRot:RebuildOptions()
  BuildClassOptions()
end
