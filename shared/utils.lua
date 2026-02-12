-- ============================================
-- SHARED UTILITIES
-- Các hàm dùng chung giữa client và server
-- ============================================

Utils = {}

-- ============================================
-- TIME UTILITIES
-- ============================================

-- Get current day (reset at 6:00 AM Vietnam time)
-- Reset vào 6:00 sáng giờ Việt Nam (UTC+7)
-- ĐỒNG BỘ GIỮA CLIENT VÀ SERVER
-- @param timestamp number - Unix timestamp
-- @return string - Số ngày kể từ epoch
function Utils.GetCurrentDay(timestamp)
    -- Điều chỉnh để reset vào 6:00 sáng VN thay vì 00:00 VN
    -- 6:00 VN = 23:00 UTC ngày hôm trước
    -- Nên ta trừ đi 1 giờ (3600 giây) từ UTC+7
    local vietnamOffset = (7 * 3600) - (6 * 3600) -- UTC+7 - 6 giờ = UTC+1
    local adjustedTime = timestamp + vietnamOffset
    local days = math.floor(adjustedTime / 86400)
    return tostring(days) -- Trả về số ngày kể từ epoch
end

-- ============================================
-- CALCULATION UTILITIES
-- ============================================

-- Calculate system profit based on system values
-- @param systems table - System values (stability, electric, etc.)
-- @param baseSalary number - Base salary from config
-- @param contribution number - System profit contribution percentage
-- @return number - Total profit amount
function Utils.CalculateSystemProfit(systems, baseSalary, contribution)
    local totalProfit = 0
    
    for systemName, value in pairs(systems) do
        local systemProfit = baseSalary * (contribution / 100)
        
        if value <= 30 then
            systemProfit = 0
        else
            systemProfit = systemProfit * (value / 100)
        end
        
        totalProfit = totalProfit + systemProfit
    end
    
    return totalProfit
end

-- Calculate efficiency (average of 5 systems)
-- @param systems table - System values
-- @return number - Efficiency percentage
function Utils.CalculateEfficiency(systems)
    local total = 0
    
    for _, value in pairs(systems) do
        if value <= 30 then
            total = total + 0
        else
            total = total + value
        end
    end
    
    return total / 5
end

-- Check if turbine can earn money
-- @param systems table - System values
-- @param currentFuel number - Current fuel level
-- @return boolean, string - Can earn status and reason
function Utils.CanEarnMoney(systems, currentFuel)
    if currentFuel <= 0 then
        return false, "OUT_OF_FUEL"
    end
    
    local below30 = 0
    for _, value in pairs(systems) do
        if value <= 30 then below30 = below30 + 1 end
    end
    
    if below30 >= 3 then 
        return false, "STOPPED"
    end
    
    return true, "RUNNING"
end

-- ============================================
-- VALIDATION UTILITIES
-- ============================================

-- Validate turbine ID
-- @param turbineId string - Turbine ID to validate
-- @param turbineLocations table - Config.TurbineLocations
-- @return boolean - True if valid, false otherwise
function Utils.ValidateTurbineId(turbineId, turbineLocations)
    for _, turbineData in ipairs(turbineLocations) do
        if turbineData.id == turbineId then
            return true
        end
    end
    return false
end

-- Check if daily hours should be reset
-- @param lastDayReset string - Last day reset value
-- @param currentDay string - Current day value
-- @return boolean - True if should reset
function Utils.ShouldResetDailyHours(lastDayReset, currentDay)
    return lastDayReset ~= currentDay
end

-- ============================================
-- DATA INITIALIZATION UTILITIES
-- ============================================

-- Get initial player data structure
-- @param currentDay string - Current day for reset tracking
-- @param initialSystemValue number - Initial value for all systems
-- @return table - Fresh player data
function Utils.GetInitialPlayerData(currentDay, initialSystemValue)
    return {
        onDuty = false,
        systems = {
            stability = initialSystemValue,
            electric = initialSystemValue,
            lubrication = initialSystemValue,
            blades = initialSystemValue,
            safety = initialSystemValue
        },
        earningsPool = 0,
        lastEarning = 0,
        lastPenalty = 0,
        lastFuelConsumption = 0,
        workStartTime = 0,
        totalWorkHours = 0,
        dailyWorkHours = 0,
        lastDayReset = currentDay,
        currentFuel = 0
    }
end

-- Get initial rental state structure
-- @return table - Fresh rental state
function Utils.GetInitialRentalState()
    return {
        isRented = false,
        ownerName = nil,
        citizenid = nil,
        expiryTime = nil,
        withdrawDeadline = nil,
        isGracePeriod = false
    }
end

