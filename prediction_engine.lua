local TR = _G.TacoRot or {}

-- ================= Enhanced Prediction System =================

-- State simulation cache to avoid recalculating
TR.PredictionCache = TR.PredictionCache or {}
TR.LastGameState = TR.LastGameState or {}

local function CaptureGameState()
    local state = {
        time = GetTime(),
        power = UnitPower("player"),
        powerMax = UnitPowerMax("player"),
        powerType = UnitPowerType("player"),
        health = UnitHealth("player"),
        healthMax = UnitHealthMax("player"),
        level = UnitLevel("player"),
        inCombat = UnitAffectingCombat("player"),
        hasTarget = UnitExists("target") and not UnitIsDead("target"),
        targetHealth = UnitExists("target") and UnitHealth("target") or 0,
        targetHealthMax = UnitExists("target") and UnitHealthMax("target") or 1,
        isMoving = false, -- Movement detection not available in 3.3.5a
        isCasting = UnitCastingInfo("player") ~= nil or UnitChannelInfo("player") ~= nil,
        gcdRemaining = 0,
        buffs = {},
        debuffs = {},
        cooldowns = {},
        comboPoints = GetComboPoints and GetComboPoints() or 0, -- Fixed: no parameters in 3.3.5a
        energy = UnitPowerType("player") == 3 and UnitPower("player") or 0,
        rage = UnitPowerType("player") == 1 and UnitPower("player") or 0,
        mana = UnitPowerType("player") == 0 and UnitPower("player") or 0,
    }

    -- Calculate GCD remaining using a spell that exists in 3.3.5a
    local gcdStart, gcdDuration = GetSpellCooldown(75) -- Auto Shot
    if gcdStart and gcdStart > 0 and gcdDuration and gcdDuration > 0 then
        state.gcdRemaining = math.max(0, (gcdStart + gcdDuration) - GetTime())
    end

    -- Capture buffs (player)
    for i = 1, 40 do
        local name, icon, count, debuffType, duration, expirationTime, source, isStealable, nameplateShowPersonal, spellId = UnitBuff("player", i)
        if not name then break end
        state.buffs[spellId or name] = {
            name = name,
            count = count or 1,
            duration = duration or 0,
            expirationTime = expirationTime or 0,
            remaining = expirationTime and (expirationTime - GetTime()) or 0,
            spellId = spellId
        }
    end

    -- Capture debuffs (target)
    if state.hasTarget then
        for i = 1, 40 do
            local name, icon, count, debuffType, duration, expirationTime, source, isStealable, nameplateShowPersonal, spellId = UnitDebuff("target", i)
            if not name then break end
            if source == "player" then
                state.debuffs[spellId or name] = {
                    name = name,
                    count = count or 1,
                    duration = duration or 0,
                    expirationTime = expirationTime or 0,
                    remaining = expirationTime and (expirationTime - GetTime()) or 0,
                    spellId = spellId
                }
            end
        end
    end

    return state
end

-- Basic 3.3.5a compatible cost detection
local function GetSpellCostInfo_335(spellId)
    if not spellId then return nil end

    local spellName = GetSpellInfo(spellId)
    if not spellName then return nil end

    return {{
        cost = 0, -- Safe default
        type = 0  -- Mana by default
    }}
end

-- Simulate casting a spell and predict the resulting game state
local function SimulateSpellCast(currentState, spellId, castTime)
    if not spellId or not currentState then return currentState end

    -- Create a copy of current state
    local newState = {}
    for k, v in pairs(currentState) do
        if type(v) == "table" then
            newState[k] = {}
            for k2, v2 in pairs(v) do
                if type(v2) == "table" then
                    newState[k][k2] = {}
                    for k3, v3 in pairs(v2) do newState[k][k2][k3] = v3 end
                else
                    newState[k][k2] = v2
                end
            end
        else
            newState[k] = v
        end
    end

    castTime = castTime or 0
    newState.time = newState.time + castTime

    -- Get spell info
    local spellName, _, _, _, _, _, spellCastTime, _, _ = GetSpellInfo(spellId)
    if not spellName then return newState end

    spellCastTime = (spellCastTime or 0) / 1000
    local actualCastTime = math.max(spellCastTime, 1.5) -- Minimum GCD

    -- Simulate resource changes based on spell
    local powerCost = GetSpellCostInfo_335(spellId)
    if powerCost and powerCost[1] then
        local cost = powerCost[1].cost or 0
        local powerType = powerCost[1].type

        if powerType == 0 then -- Mana
            newState.mana = math.max(0, newState.mana - cost)
        elseif powerType == 1 then -- Rage
            newState.rage = math.max(0, newState.rage - cost)
        elseif powerType == 3 then -- Energy
            newState.energy = math.max(0, newState.energy - cost)
        end
    end

    -- Simulate resource regeneration during cast time
    if newState.energy > 0 then
        newState.energy = math.min(100, newState.energy + (actualCastTime * 10)) -- 10 energy/sec
    end
    if newState.rage > 0 and newState.inCombat then
        newState.rage = math.min(100, newState.rage + (actualCastTime * 2)) -- 2 rage/sec in combat
    end

    -- Update time-based effects (buffs/debuffs decay)
    for id, buff in pairs(newState.buffs) do
        if buff.remaining > 0 then
            buff.remaining = math.max(0, buff.remaining - actualCastTime)
            if buff.remaining <= 0 then
                newState.buffs[id] = nil
            end
        end
    end

    for id, debuff in pairs(newState.debuffs) do
        if debuff.remaining > 0 then
            debuff.remaining = math.max(0, debuff.remaining - actualCastTime)
            if debuff.remaining <= 0 then
                newState.debuffs[id] = nil
            end
        end
    end

    -- Update cooldowns
    for id, cooldown in pairs(newState.cooldowns) do
        cooldown.remaining = math.max(0, cooldown.remaining - actualCastTime)
    end

    -- Set spell on cooldown
    local cooldownStart, cooldownDuration = GetSpellCooldown(spellId)
    if cooldownDuration and cooldownDuration > 0 then
        newState.cooldowns[spellId] = {
            remaining = cooldownDuration,
            duration = cooldownDuration
        }
    end

    -- Simulate specific spell effects (you'll want to expand this per spell)
    newState = SimulateSpellEffects(newState, spellId, spellName)

    return newState
end

-- Simulate specific spell effects (expand this for each class/spell)
function SimulateSpellEffects(state, spellId, spellName)
    -- Example implementations - expand based on your class engines

    -- Combo point generators
    local comboGenerators = {
        [1752] = 1, -- Sinister Strike
        [48691] = 2, -- Mutilate
        [48654] = 1, -- Hemorrhage
    }

    if comboGenerators[spellId] then
        state.comboPoints = math.min(5, state.comboPoints + comboGenerators[spellId])
    end

    -- Combo point finishers
    local comboFinishers = {
        [48668] = true, -- Eviscerate
        [57993] = true, -- Envenom
    }

    if comboFinishers[spellId] then
        state.comboPoints = 0
    end

    -- DoT applications (simplified)
    local dots = {
        [48672] = {duration = 18, id = 48672}, -- Rupture
        [26688] = {duration = 21, id = 26688}, -- Anesthetic Poison
    }

    if dots[spellId] then
        state.debuffs[spellId] = {
            name = spellName,
            remaining = dots[spellId].duration,
            duration = dots[spellId].duration,
            spellId = spellId
        }
    end

    return state
end

-- Enhanced ReadySoon that considers predicted state
local function PredictiveReadySoon(spellId, futureState, timeOffset)
    timeOffset = timeOffset or 0
    futureState = futureState or CaptureGameState()

    if not spellId then return false end

    -- Check if spell is known
    if not (IsSpellKnown and IsSpellKnown(spellId)) then
        return false
    end

    -- Check cooldown in future state
    local cooldown = futureState.cooldowns[spellId]
    if cooldown and cooldown.remaining > timeOffset then
        return false
    end

    -- Check GCD
    if futureState.gcdRemaining > timeOffset then
        return false
    end

    -- Check resource costs
    local powerCost = GetSpellCostInfo_335(spellId)
    if powerCost and powerCost[1] then
        local cost = powerCost[1].cost or 0
        local powerType = powerCost[1].type

        if powerType == 0 and futureState.mana < cost then return false end
        if powerType == 1 and futureState.rage < cost then return false end
        if powerType == 3 and futureState.energy < cost then return false end
    end

    return true
end

-- Enhanced queue building with prediction
function TR:BuildPredictiveQueue(baseQueue, maxDepth)
    maxDepth = maxDepth or 6
    local currentState = CaptureGameState()
    local queue = {}
    local workingState = currentState

    -- Start with base queue or build from scratch
    if baseQueue and baseQueue[1] then
        table.insert(queue, baseQueue[1])
        workingState = SimulateSpellCast(workingState, baseQueue[1])
    end

    -- Predict future spells
    for depth = #queue + 1, maxDepth do
        local nextSpell = self:PredictNextSpell(workingState, queue)
        if nextSpell and PredictiveReadySoon(nextSpell, workingState) then
            table.insert(queue, nextSpell)
            workingState = SimulateSpellCast(workingState, nextSpell)
        else
            break
        end
    end

    return queue
end

-- Predict the next optimal spell based on current state and priority
function TR:PredictNextSpell(gameState, currentQueue)
    -- This should be implemented per class
    -- For now, return a basic priority based on your existing BuildQueue logic

    -- Example for rogue (you'll need to implement this for each class)
    local _, class = UnitClass("player")
    if class == "ROGUE" then
        return self:PredictNextSpell_Rogue(gameState, currentQueue)
    elseif class == "MAGE" then
        return self:PredictNextSpell_Mage(gameState, currentQueue)
    -- Add other classes...
    end

    return nil
end

-- Example implementation for Rogue
function TR:PredictNextSpell_Rogue(state, queue)
    local A = (self.IDS and self.IDS.Ability) or {}

    -- Simplified rogue priority with state consideration
    if state.comboPoints >= 4 and A.Eviscerate and PredictiveReadySoon(A.Eviscerate, state) then
        return A.Eviscerate
    end

    if state.comboPoints < 5 and A.Mutilate and PredictiveReadySoon(A.Mutilate, state) then
        return A.Mutilate
    end

    if state.comboPoints < 5 and A.SinisterStrike and PredictiveReadySoon(A.SinisterStrike, state) then
        return A.SinisterStrike
    end

    return nil
end

-- Enhanced update frequency based on game events
function TR:UpdatePredictionEngine()
    -- Increase update frequency during active gameplay
    local now = GetTime()
    local timeSinceLastCast = now - (self.lastCastTime or 0)
    local updateInterval = 0.1 -- Default to 100ms for smoother updates

    -- Reduce frequency when not much is happening
    if not UnitAffectingCombat("player") and timeSinceLastCast > 5 then
        updateInterval = 0.5 -- 500ms when idle
    elseif self.isChanneling or UnitCastingInfo("player") then
        updateInterval = 0.05 -- 50ms during casting for precise updates
    end

    return updateInterval
end

-- Integration function to replace your existing ReadySoon in engines
function TR:GetEnhancedReadySoon()
    return PredictiveReadySoon
end

-- Cache invalidation for performance
function TR:InvalidatePredictionCache()
    self.PredictionCache = {}
end

-- Event handlers for real-time updates
function TR:RegisterPredictionEvents()
    self:RegisterEvent("SPELL_UPDATE_COOLDOWN", "InvalidatePredictionCache")
    self:RegisterEvent("UNIT_POWER_FREQUENT", "InvalidatePredictionCache") 
    self:RegisterEvent("UNIT_AURA", "InvalidatePredictionCache")
    self:RegisterEvent("PLAYER_TARGET_CHANGED", "InvalidatePredictionCache")
    self:RegisterEvent("UNIT_COMBO_POINTS", "InvalidatePredictionCache")
end

-- Enhanced state checking functions for your engines
function TR:StateHasBuffID(state, buffId)
    return state.buffs[buffId] and state.buffs[buffId].remaining > 0
end

function TR:StateHasDebuffID(state, debuffId)
    return state.debuffs[debuffId] and state.debuffs[debuffId].remaining > 0
end

function TR:StateSpellReady(state, spellId, timeOffset)
    return PredictiveReadySoon(spellId, state, timeOffset or 0)
end

-- Export functions for backward compatibility
TR.CaptureGameState = CaptureGameState
TR.SimulateSpellCast = SimulateSpellCast
TR.PredictiveReadySoon = PredictiveReadySoon
