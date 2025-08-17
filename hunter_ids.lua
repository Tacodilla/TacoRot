-- hunter_ids.lua — WotLK-safe IDs + rank promotion + icon fallbacks
DEFAULT_CHAT_FRAME:AddMessage("|cff55ff55[TacoRot]|r Hunter IDS loaded")

local IDS = {
  Ability = {
    HuntersMark   = 1130,
    SerpentSting  = 1978,
    ArcaneShot    = 3044,
    AimedShot     = 19434,
    MultiShot     = 2643,
    RapidFire     = 3045,
    RaptorStrike  = 2973,
    WingClip      = 2974,
    AutoShot      = 75,
  },
  Rank = {
    -- All ranks below are valid in 3.3.5
    HuntersMark   = {1130,14323,14324,14325},
    SerpentSting  = {1978,13549,13550,13551,13552,13553,13554,13555,25295,27016},
    ArcaneShot    = {3044,14281,14282,14283,14284,14285,14286,14287,25291,27019},
    AimedShot     = {19434,20900,20901,20902,20903,20904,27065},
    MultiShot     = {2643,14288,14289,14290,25294,27021},
    RapidFire     = {3045},
    RaptorStrike  = {2973,14260,14261,14262,14263,14264,14265,14266},
    WingClip      = {2974,14267,14268},
    AutoShot      = {75},
  },
}

local function bestRank(list)
  if not list then return nil end
  local lastKnown
  for i = #list, 1, -1 do
    local id = list[i]
    if GetSpellInfo(id) then
      lastKnown = lastKnown or id
      if IsSpellKnown and IsSpellKnown(id) then return id end
    end
  end
  return lastKnown or list[#list] or list[1]
end

function IDS:UpdateRanks()
  for key, list in pairs(self.Rank) do
    local id = bestRank(list)
    if id then self.Ability[key] = id end
  end
end

_G.TacoRot_IDS_Hunter = IDS

-- Guaranteed textures so you never see ??? even at level 1
_G.TacoRotIconFallbacks = _G.TacoRotIconFallbacks or {}
local fb = _G.TacoRotIconFallbacks
local function setOnce(id, tex) if id and not fb[id] then fb[id] = tex end end
setOnce(75,    "Interface\\Icons\\INV_Weapon_Bow_07")
setOnce(2973,  "Interface\\Icons\\Ability_MeleeDamage")
setOnce(1978,  "Interface\\Icons\\Ability_Hunter_Quickshot")
setOnce(3044,  "Interface\\Icons\\Ability_ImpalingBolt")
setOnce(19434, "Interface\\Icons\\INV_Spear_07")
setOnce(2643,  "Interface\\Icons\\INV_Ammo_Arrow_02")
setOnce(1130,  "Interface\\Icons\\Ability_Hunter_SniperShot")
setOnce(2974,  "Interface\\Icons\\Ability_Rogue_Trip")
setOnce(3045,  "Interface\\Icons\\Ability_Hunter_RunningShot")
