local TacoRot = _G.TacoRot
if not TacoRot then return end
local IDS = _G.TacoRot_IDS

local reg = LibStub("AceConfigRegistry-3.0")
local opts = reg and reg:GetOptionsTable("TacoRot")
if not (opts and opts.args) then return end

local function spellToggleEntry(sid, key, order)
  local name, _, icon = GetSpellInfo(sid)
  name = name or (key or ("Spell "..tostring(sid)))
  return {
    type  = "toggle",
    width = "full",
    order = order,
    name  = (icon and ("|T"..icon..":16|t ") or "") .. name,
    get   = function() return TacoRot.db.profile.spells[sid] ~= false end,
    set   = function(_, v) TacoRot.db.profile.spells[sid] = v and true or false end,
  }
end

local i=1
opts.args.warlock = { type="group", name="Warlock", order=20, childGroups="tab", args = { spells = { type="group", name="Spells", args = {} } } }

-- Make sure ranks are current before populating
if IDS and IDS.UpdateRanks then IDS:UpdateRanks() end

for key, sid in pairs(IDS.Ability) do
  if type(sid)=="number" then
    opts.args.warlock.args.spells.args["s"..sid] = spellToggleEntry(sid, key, i); i=i+1
  end
end

reg:NotifyChange("TacoRot")
