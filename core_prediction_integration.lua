local TR = _G.TacoRot

-- ================= Enhanced Core Integration =================

-- Default configuration for prediction system
local predictionDefaults = {
    profile = {
        prediction = {
            enabled = true,
            maxDepth = 6,              -- How many spells to predict ahead
            updateInterval = 0.1,       -- Base update interval (seconds)
            adaptiveInterval = true,    -- Adjust interval based on combat state
            combatInterval = 0.05,      -- Interval during active combat
            idleInterval = 0.5,         -- Interval when idle
            useSimulation = true,       -- Enable state simulation
            debugMode = false,          -- Show prediction debug info
            cacheSize = 100,           -- Max cached predictions
        }
    }
}

-- Merge prediction defaults with existing defaults
if TR.defaults then
    for k, v in pairs(predictionDefaults.profile) do
        TR.defaults.profile[k] = v
    end
else
    TR.defaults = predictionDefaults
end

-- ================= Enhanced OnEnable =================

-- Store original OnEnable if it exists
TR._originalOnEnable = TR._originalOnEnable or TR.OnEnable

function TR:OnEnable()
    -- Call original OnEnable
    if self._originalOnEnable then
        self._originalOnEnable(self)
    end

    -- Initialize prediction system
    if self.db.profile.prediction.enabled then
        self:InitializePredictionSystem()
    end
end

function TR:InitializePredictionSystem()
    -- Initialize prediction state
    self.PredictionCache = {}
    self.LastGameState = {}
    self.PredictionStats = {
        updates = 0,
        cacheHits = 0,
        cacheMisses = 0,
        avgUpdateTime = 0,
    }

    -- Register events for real-time updates
    if self.RegisterPredictionEvents then
        self:RegisterPredictionEvents()
    end

    -- Start performance monitoring
    self:ScheduleRepeatingTimer("CleanupPredictionCache", 30) -- Cleanup every 30 seconds

    self:Print("Enhanced prediction system initialized")
end

-- ================= Performance Monitoring =================

function TR:CleanupPredictionCache()
    local cfg = self.db.profile.prediction
    local maxSize = cfg.cacheSize or 100

    -- Clear old cache entries
    local count = 0
    for k, v in pairs(self.PredictionCache) do
        count = count + 1
    end

    if count > maxSize then
        self.PredictionCache = {}
        if cfg.debugMode then
            self:Print("Prediction cache cleared (" .. count .. " entries)")
        end
    end
end

function TR:GetPredictionStats()
    if not self.PredictionStats then return "Prediction system not initialized" end

    local stats = self.PredictionStats
    return string.format(
        "Prediction Stats - Updates: %d, Cache: %.1f%% hit rate, Avg: %.2fms", 
        stats.updates,
        stats.cacheHits / math.max(1, stats.cacheHits + stats.cacheMisses) * 100,
        stats.avgUpdateTime * 1000
    )
end

-- ================= Enhanced UpdateRotationDisplay =================

-- Store original UpdateRotationDisplay
TR._originalUpdateRotationDisplay = TR._originalUpdateRotationDisplay or TR.UpdateRotationDisplay

function TR:UpdateRotationDisplay()
    local cfg = self.db.profile.prediction

    if cfg.enabled and cfg.useSimulation then
        self:UpdatePredictiveRotationDisplay()
    else
        -- Fallback to original system
        if self._originalUpdateRotationDisplay then
            self._originalUpdateRotationDisplay(self)
        end
    end
end

function TR:UpdatePredictiveRotationDisplay()
    local startTime = GetTime()

    -- Update prediction stats
    self.PredictionStats.updates = self.PredictionStats.updates + 1

    -- Trigger current engine tick if available
    local _, class = UnitClass("player")
    if class then
        local enhancedTickMethod = "EngineTick_" .. class .. "_Enhanced"
        local normalTickMethod = "EngineTick_" .. class

        if self[enhancedTickMethod] then
            self[enhancedTickMethod](self)
        elseif self[normalTickMethod] then
            self[normalTickMethod](self)
        end
    end

    -- Update performance stats
    local endTime = GetTime()
    local updateTime = endTime - startTime
    local stats = self.PredictionStats
    stats.avgUpdateTime = (stats.avgUpdateTime * 0.95) + (updateTime * 0.05) -- Rolling average
end

-- ================= Dynamic Timer System =================

function TR:GetOptimalUpdateInterval()
    local cfg = self.db.profile.prediction
    if not cfg.adaptiveInterval then
        return cfg.updateInterval or 0.1
    end

    local now = GetTime()
    local timeSinceLastCast = now - (self.lastCastTime or 0)
    local inCombat = UnitAffectingCombat("player")
    local isCasting = UnitCastingInfo("player") ~= nil or UnitChannelInfo("player") ~= nil
    local isMoving = false -- Movement detection not available in 3.3.5a

    -- High frequency during active gameplay
    if isCasting or (inCombat and timeSinceLastCast < 2) then
        return cfg.combatInterval or 0.05 -- 50ms
    end

    -- Medium frequency during combat
    if inCombat or isMoving then
        return cfg.updateInterval or 0.1 -- 100ms
    end

    -- Low frequency when idle
    if timeSinceLastCast > 5 then
        return cfg.idleInterval or 0.5 -- 500ms
    end

    return cfg.updateInterval or 0.1
end

-- Enhanced UpdatePredictionEngine
TR.UpdatePredictionEngine = TR.GetOptimalUpdateInterval

-- ================= Configuration Options =================

-- Add to your options table (in options.lua)
function TR:AddPredictionOptions(optionsTable)
    if not optionsTable.args then optionsTable.args = {} end

    optionsTable.args.prediction = {
        type = "group",
        name = "Prediction System",
        order = 50,
        args = {
            enabled = {
                type = "toggle",
                name = "Enable Enhanced Prediction",
                desc = "Use Hekili-style real-time prediction system",
                order = 1,
                get = function() return self.db.profile.prediction.enabled end,
                set = function(_, v) 
                    self.db.profile.prediction.enabled = v
                    if v then
                        self:InitializePredictionSystem()
                    end
                end,
            },
            maxDepth = {
                type = "range",
                name = "Prediction Depth",
                desc = "How many spells to predict ahead (higher = more CPU usage)",
                order = 2,
                min = 3, max = 10, step = 1,
                get = function() return self.db.profile.prediction.maxDepth end,
                set = function(_, v) self.db.profile.prediction.maxDepth = v end,
                disabled = function() return not self.db.profile.prediction.enabled end,
            },
            adaptiveInterval = {
                type = "toggle",
                name = "Adaptive Update Rate", 
                desc = "Automatically adjust update frequency based on combat state",
                order = 3,
                get = function() return self.db.profile.prediction.adaptiveInterval end,
                set = function(_, v) self.db.profile.prediction.adaptiveInterval = v end,
                disabled = function() return not self.db.profile.prediction.enabled end,
            },
            updateInterval = {
                type = "range",
                name = "Base Update Interval",
                desc = "Base update frequency in seconds (lower = more responsive, higher CPU)",
                order = 4,
                min = 0.05, max = 0.5, step = 0.01,
                get = function() return self.db.profile.prediction.updateInterval end,
                set = function(_, v) self.db.profile.prediction.updateInterval = v end,
                disabled = function() return not self.db.profile.prediction.enabled end,
            },
            combatInterval = {
                type = "range", 
                name = "Combat Update Interval",
                desc = "Update frequency during active combat",
                order = 5,
                min = 0.01, max = 0.2, step = 0.01,
                get = function() return self.db.profile.prediction.combatInterval end,
                set = function(_, v) self.db.profile.prediction.combatInterval = v end,
                disabled = function() return not (self.db.profile.prediction.enabled and self.db.profile.prediction.adaptiveInterval) end,
            },
            debugMode = {
                type = "toggle",
                name = "Debug Mode",
                desc = "Show prediction system debug information",
                order = 10,
                get = function() return self.db.profile.prediction.debugMode end,
                set = function(_, v) self.db.profile.prediction.debugMode = v end,
                disabled = function() return not self.db.profile.prediction.enabled end,
            },
            stats = {
                type = "execute",
                name = "Show Performance Stats",
                desc = "Display prediction system performance statistics",
                order = 20,
                func = function() 
                    self:Print(self:GetPredictionStats())
                end,
                disabled = function() return not self.db.profile.prediction.enabled end,
            },
            clearCache = {
                type = "execute", 
                name = "Clear Prediction Cache",
                desc = "Manually clear the prediction cache",
                order = 21,
                func = function()
                    self.PredictionCache = {}
                    self:Print("Prediction cache cleared")
                end,
                disabled = function() return not self.db.profile.prediction.enabled end,
            },
        },
    }
end

-- ================= Debug Functions =================

function TR:DebugPrediction(message)
    if self.db.profile.prediction.debugMode then
        self:Print("[Prediction] " .. tostring(message))
    end
end

function TR:DumpGameState()
    if not self.CaptureGameState then 
        self:Print("Prediction system not loaded")
        return 
    end

    local state = self:CaptureGameState()
    self:Print("=== Current Game State ===")
    self:Print("Time: " .. state.time)
    self:Print("Power: " .. state.power .. "/" .. state.powerMax)
    self:Print("In Combat: " .. tostring(state.inCombat))
    self:Print("Has Target: " .. tostring(state.hasTarget))
    self:Print("GCD Remaining: " .. state.gcdRemaining)

    if state.comboPoints > 0 then
        self:Print("Combo Points: " .. state.comboPoints)
    end

    self:Print("Active Buffs: " .. self:CountTable(state.buffs))
    self:Print("Active Debuffs: " .. self:CountTable(state.debuffs))
    self:Print("=========================")
end

function TR:CountTable(t)
    local count = 0
    for _ in pairs(t) do count = count + 1 end
    return count
end

-- ================= Slash Commands =================

SLASH_TACOROTPRED1 = "/trpred"
SlashCmdList["TACOROTPRED"] = function(msg)
    msg = (msg or ""):lower()

    if msg == "enable" then
        TR.db.profile.prediction.enabled = true
        TR:InitializePredictionSystem()
        TR:Print("Enhanced prediction enabled")
    elseif msg == "disable" then
        TR.db.profile.prediction.enabled = false
        TR:Print("Enhanced prediction disabled")
    elseif msg == "stats" then
        TR:Print(TR:GetPredictionStats())
    elseif msg == "debug" then
        TR:DumpGameState()
    elseif msg == "clear" then
        TR.PredictionCache = {}
        TR:Print("Prediction cache cleared")
    else
        TR:Print("TacoRot Prediction Commands:")
        TR:Print("/trpred enable|disable - Toggle prediction system")
        TR:Print("/trpred stats - Show performance statistics") 
        TR:Print("/trpred debug - Dump current game state")
        TR:Print("/trpred clear - Clear prediction cache")
    end
end

-- ================= Auto-Integration =================

-- Automatically integrate with existing options if they exist
if TR.OptionsRoot and TR.OptionsRoot.args then
    TR:AddPredictionOptions(TR.OptionsRoot)
end

TR:Print("Enhanced prediction core integration loaded. Use /trpred for commands.")
