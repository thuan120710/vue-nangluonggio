QBCore = exports['qb-core']:GetCoreObject()

local playerData = {}

-- Khởi tạo dữ liệu player
local function InitPlayerData(playerId)
    playerData[playerId] = {
        onDuty = false,
        systems = {
            stability = Config.InitialSystemValue,
            electric = Config.InitialSystemValue,
            lubrication = Config.InitialSystemValue,
            blades = Config.InitialSystemValue,
            safety = Config.InitialSystemValue
        },
        earningsPool = 0,
        lastEarning = 0,
        lastPenalty = 0,
        lastDegrade = 0,
        workStartTime = 0,
        totalWorkHours = 0,
        dailyWorkHours = 0,
        weeklyWorkHours = 0,
        lastDayReset = os.date("%Y-%m-%d"),
        lastWeekReset = os.date("%Y-W%W")
    }
end

-- Tính hiệu suất tổng (trung bình 5 chỉ số)
local function CalculateEfficiency(playerId)
    if not playerData[playerId] then return 0 end
    
    local systems = playerData[playerId].systems
    local total = systems.stability + systems.electric + systems.lubrication + 
                  systems.blades + systems.safety
    
    return total / 5
end

-- Tính lợi nhuận dựa trên từng chỉ số (mỗi chỉ số = 20% lợi nhuận)
local function CalculateSystemProfit(playerId)
    if not playerData[playerId] then return 0 end
    
    local systems = playerData[playerId].systems
    local totalProfit = 0
    
    -- Mỗi chỉ số đóng góp 20% lợi nhuận tối đa
    -- Config.BaseSalary = 1,250 IC/15 phút (5,000 IC/giờ)
    -- Config.SystemProfitContribution = 20%
    for systemName, value in pairs(systems) do
        -- Lợi nhuận tối đa của 1 chỉ số = 1,250 * 20% = 250 IC/15 phút
        local systemProfit = Config.BaseSalary * (Config.SystemProfitContribution / 100)
        
        -- Nếu chỉ số < 30%: ngừng sinh lợi nhuận từ chỉ số đó
        if value < 30 then
            systemProfit = 0
        -- Nếu chỉ số 30-50%: giảm 50% lợi nhuận của chỉ số đó
        elseif value < 50 then
            systemProfit = systemProfit * 0.5
        -- Nếu chỉ số >= 50%: sinh lợi nhuận đầy đủ
        else
            -- Giữ nguyên systemProfit (đầy đủ 20%)
            systemProfit = systemProfit
        end
        
        totalProfit = totalProfit + systemProfit
    end
    
    return totalProfit
end

-- Kiểm tra điều kiện sinh tiền (nếu 3 chỉ số < 30% => máy ngừng hoạt động)
local function CanEarnMoney(playerId)
    if not playerData[playerId] then return false end
    
    local systems = playerData[playerId].systems
    local below30 = 0
    
    for _, value in pairs(systems) do
        if value < 30 then below30 = below30 + 1 end
    end
    
    -- Nếu 3 chỉ số < 30% => máy ngừng hoạt động
    if below30 >= 3 then 
        return false, "STOPPED" -- Máy ngừng hoạt động
    end
    
    return true, "RUNNING"
end

-- Tính tiền sinh ra dựa trên từng chỉ số
local function CalculateEarnings(playerId)
    if not playerData[playerId] or not playerData[playerId].onDuty then return 0 end
    
    local canEarn, status = CanEarnMoney(playerId)
    if not canEarn then return 0 end
    
    -- Tính lợi nhuận dựa trên từng chỉ số (mỗi chỉ số = 20%)
    local earnPerMinute = CalculateSystemProfit(playerId)
    
    return earnPerMinute
end

-- Áp dụng penalty theo giờ hoạt động
local function ApplyPenalty(playerId)
    if not playerData[playerId] or not playerData[playerId].onDuty then return end
    
    local workHours = playerData[playerId].totalWorkHours
    
    -- Tìm penalty range phù hợp
    local penaltyRange = nil
    for _, range in ipairs(Config.PenaltyRanges) do
        if workHours >= range.minHours and workHours < range.maxHours then
            penaltyRange = range
            break
        end
    end
    
    -- Nếu không có penalty range hoặc không có penalties (0-2h)
    if not penaltyRange or #penaltyRange.penalties == 0 then 
        print(('[Wind Turbine] Player %s: No penalty (%.1f hours worked)'):format(playerId, workHours))
        return 
    end
    
    -- Random penalty dựa trên tỷ lệ
    local roll = math.random(1, 100)
    local cumulativeChance = 0
    local selectedPenalty = nil
    
    for _, penalty in ipairs(penaltyRange.penalties) do
        cumulativeChance = cumulativeChance + penalty.chance
        if roll <= cumulativeChance then
            selectedPenalty = penalty
            break
        end
    end
    
    if not selectedPenalty or selectedPenalty.systems == 0 then 
        -- Không bị penalty
        TriggerClientEvent('QBCore:Notify', playerId, '✅ May mắn! Không có hư hỏng nào xảy ra!', 'success', 3000)
        return 
    end
    
    -- Xác định số lượng hệ thống bị ảnh hưởng
    local numSystems = selectedPenalty.systems
    if type(numSystems) == "table" then
        numSystems = math.random(numSystems[1], numSystems[2])
    end
    
    -- Random chọn hệ thống bị ảnh hưởng
    local systemNames = {"stability", "electric", "lubrication", "blades", "safety"}
    local systemDisplayNames = {
        stability = "Độ ổn định",
        electric = "Hệ thống điện",
        lubrication = "Bôi trơn",
        blades = "Thân tháp",
        safety = "An toàn"
    }
    local affectedSystems = {}
    local systemDetails = {}
    
    for i = 1, numSystems do
        local randomIndex = math.random(1, #systemNames)
        local systemName = table.remove(systemNames, randomIndex)
        
        -- Lưu giá trị trước khi giảm
        local beforeValue = playerData[playerId].systems[systemName]
        
        -- Áp dụng damage
        local afterValue = math.max(0, beforeValue - selectedPenalty.damage)
        playerData[playerId].systems[systemName] = afterValue
        
        table.insert(affectedSystems, systemName)
        table.insert(systemDetails, string.format('%s: %d%% → %d%%', systemDisplayNames[systemName], beforeValue, afterValue))
    end
    
    -- Thông báo chi tiết
    local detailsText = table.concat(systemDetails, ' | ')
    TriggerClientEvent('QBCore:Notify', playerId, 
        string.format('⚠️ Penalty! Giảm %d%%: %s', selectedPenalty.damage, detailsText), 
        'error', 7000)
    
    local actualEarningRate = CalculateSystemProfit(playerId) * 4 -- Chuyển sang IC/giờ (15 phút x 4 = 1 giờ)
    
    TriggerClientEvent('windturbine:updateSystems', playerId, playerData[playerId].systems)
    TriggerClientEvent('windturbine:updateEfficiency', playerId, CalculateEfficiency(playerId))
    TriggerClientEvent('windturbine:updateActualEarningRate', playerId, actualEarningRate)
    
    print(('[Wind Turbine] Player %s penalty: %d systems -%d%% (%.1f hours worked)'):format(
        playerId, numSystems, selectedPenalty.damage, workHours))
end

-- Kiểm tra và reset giới hạn thời gian
local function CheckTimeLimit(playerId)
    if not playerData[playerId] then return true end
    
    local currentDay = os.date("%Y-%m-%d")
    local currentWeek = os.date("%Y-W%W")
    
    -- Reset daily counter
    if playerData[playerId].lastDayReset ~= currentDay then
        playerData[playerId].dailyWorkHours = 0
        playerData[playerId].lastDayReset = currentDay
        
        -- Thông báo cho client reset work limit UI
        TriggerClientEvent('windturbine:resetWorkLimit', playerId)
    end
    
    -- Reset weekly counter
    if playerData[playerId].lastWeekReset ~= currentWeek then
        playerData[playerId].weeklyWorkHours = 0
        playerData[playerId].lastWeekReset = currentWeek
        
        -- Thông báo cho client reset work limit UI
        TriggerClientEvent('windturbine:resetWorkLimit', playerId)
    end
    
    -- Kiểm tra giới hạn
    if playerData[playerId].dailyWorkHours >= Config.MaxDailyHours then
        return false, "DAILY_LIMIT"
    end
    
    if playerData[playerId].weeklyWorkHours >= Config.MaxWeeklyHours then
        return false, "WEEKLY_LIMIT"
    end
    
    return true, "OK"
end

-- Event: Bắt đầu ca
RegisterNetEvent('windturbine:startDuty')
AddEventHandler('windturbine:startDuty', function()
    local playerId = source
    
    if not playerData[playerId] then
        InitPlayerData(playerId)
    end
    
    -- Kiểm tra giới hạn thời gian
    local canWork, reason = CheckTimeLimit(playerId)
    if not canWork then
        if reason == "DAILY_LIMIT" then
            TriggerClientEvent('QBCore:Notify', playerId, 
                '❌ Đã đạt giới hạn! Hãy quay lại vào ngày mai.', 
                'error', 5000)
            TriggerClientEvent('windturbine:workLimitReached', playerId)
        elseif reason == "WEEKLY_LIMIT" then
            TriggerClientEvent('QBCore:Notify', playerId, 
                '❌ Đã đạt giới hạn tuần! Hãy quay lại vào tuần sau.', 
                'error', 5000)
            TriggerClientEvent('windturbine:workLimitReached', playerId)
        end
        return
    end
    
    playerData[playerId].onDuty = true
    playerData[playerId].workStartTime = os.time()
    playerData[playerId].lastEarning = os.time()
    playerData[playerId].lastPenalty = os.time()
    playerData[playerId].lastDegrade = os.time()
    
    local actualEarningRate = CalculateSystemProfit(playerId) * 4 -- Chuyển sang IC/giờ (15 phút x 4 = 1 giờ)
    
    TriggerClientEvent('windturbine:updateSystems', playerId, playerData[playerId].systems)
    TriggerClientEvent('windturbine:updateEfficiency', playerId, CalculateEfficiency(playerId))
    TriggerClientEvent('windturbine:updateEarningsPool', playerId, playerData[playerId].earningsPool)
    TriggerClientEvent('windturbine:updateActualEarningRate', playerId, actualEarningRate)
    TriggerClientEvent('windturbine:updateWorkTime', playerId, 0, Config.MaxDailyHours)
    
    print(('[Wind Turbine] Player %s started duty (Daily: %.1fh/%.0fh, Weekly: %.1fh/%.0fh)'):format(
        playerId, 
        playerData[playerId].dailyWorkHours, Config.MaxDailyHours,
        playerData[playerId].weeklyWorkHours, Config.MaxWeeklyHours))
end)

-- Event: Kết thúc ca
RegisterNetEvent('windturbine:stopDuty')
AddEventHandler('windturbine:stopDuty', function()
    local playerId = source
    
    if playerData[playerId] and playerData[playerId].onDuty then
        -- Tính thời gian làm việc
        local workDuration = (os.time() - playerData[playerId].workStartTime) / 3600 -- giờ
        playerData[playerId].dailyWorkHours = playerData[playerId].dailyWorkHours + workDuration
        playerData[playerId].weeklyWorkHours = playerData[playerId].weeklyWorkHours + workDuration
        
        playerData[playerId].onDuty = false
        TriggerClientEvent('windturbine:stopTurbine', playerId)
        
        print(('[Wind Turbine] Player %s stopped duty (Worked: %.1fh, Daily: %.1fh, Weekly: %.1fh)'):format(
            playerId, workDuration, 
            playerData[playerId].dailyWorkHours, 
            playerData[playerId].weeklyWorkHours))
    end
end)

-- Event: Sửa chữa hệ thống
RegisterNetEvent('windturbine:repairSystem')
AddEventHandler('windturbine:repairSystem', function(system, result)
    local playerId = source
    
    if not playerData[playerId] or not playerData[playerId].onDuty then return end
    if not playerData[playerId].systems[system] then return end
    
    local reward = 0
    
    if result == 'perfect' then
        reward = Config.RepairRewards.perfect
    elseif result == 'good' then
        reward = Config.RepairRewards.good
    else
        reward = Config.RepairRewards.fail
    end
    
    playerData[playerId].systems[system] = math.min(100, playerData[playerId].systems[system] + reward)
    
    local actualEarningRate = CalculateSystemProfit(playerId) * 4 -- Chuyển sang IC/giờ (15 phút x 4 = 1 giờ)
    
    TriggerClientEvent('windturbine:updateSystems', playerId, playerData[playerId].systems)
    TriggerClientEvent('windturbine:updateEfficiency', playerId, CalculateEfficiency(playerId))
    TriggerClientEvent('windturbine:updateActualEarningRate', playerId, actualEarningRate)
    
    print(('[Wind Turbine] Player %s repaired %s: %s (+%d%%)'):format(playerId, system, result, reward))
end)

-- Event: Rút tiền
RegisterNetEvent('windturbine:withdrawEarnings')
AddEventHandler('windturbine:withdrawEarnings', function()
    local playerId = source
    
    if not playerData[playerId] then return end
    
    local amount = math.floor(playerData[playerId].earningsPool)
    
    if amount <= 0 then
        TriggerClientEvent('QBCore:Notify', playerId, '❌ Không có tiền để rút!', 'error')
        return
    end
    
    -- QBCore: Thêm tiền vào ví
    local Player = QBCore.Functions.GetPlayer(playerId)
    if Player then
        Player.Functions.AddMoney('cash', amount)
        TriggerClientEvent('QBCore:Notify', playerId, string.format('💰 Đã rút $%d từ quỹ tiền lương!', amount), 'success')
        
        playerData[playerId].earningsPool = 0
        TriggerClientEvent('windturbine:updateEarningsPool', playerId, 0)
        
        print(('[Wind Turbine] Player %s withdrew $%d'):format(playerId, amount))
    else
        TriggerClientEvent('QBCore:Notify', playerId, '❌ Lỗi hệ thống!', 'error')
    end
end)

-- Thread: Sinh tiền và penalty
CreateThread(function()
    while true do
        Wait(1000)
        
        local currentTime = os.time()
        
        for playerId, data in pairs(playerData) do
            if data.onDuty then
                -- Tính thời gian làm việc hiện tại (giờ)
                local currentWorkHours = (currentTime - data.workStartTime) / 3600
                data.totalWorkHours = currentWorkHours
                
                -- Kiểm tra giới hạn thời gian (bao gồm cả thời gian ca hiện tại)
                local totalDailyHours = data.dailyWorkHours + currentWorkHours
                local totalWeeklyHours = data.weeklyWorkHours + currentWorkHours
                
                -- Kiểm tra nếu vượt quá giới hạn
                if totalDailyHours >= Config.MaxDailyHours then
                    -- Tự động kết thúc ca khi hết giờ
                    data.onDuty = false
                    TriggerClientEvent('windturbine:stopTurbine', playerId)
                    
                    TriggerClientEvent('QBCore:Notify', playerId, 
                        '⏰ Đã hết giờ làm việc trong ngày! Ca làm việc tự động kết thúc.', 
                        'error', 5000)
                    
                    -- Cập nhật thời gian làm việc
                    data.dailyWorkHours = totalDailyHours
                    data.weeklyWorkHours = totalWeeklyHours
                    
                    print(('[Wind Turbine] Player %s auto-stopped: DAILY_LIMIT (Daily: %.1fh, Weekly: %.1fh)'):format(
                        playerId, data.dailyWorkHours, data.weeklyWorkHours))
                    
                    goto continue
                end
                
                if totalWeeklyHours >= Config.MaxWeeklyHours then
                    -- Tự động kết thúc ca khi hết giờ
                    data.onDuty = false
                    TriggerClientEvent('windturbine:stopTurbine', playerId)
                    
                    TriggerClientEvent('QBCore:Notify', playerId, 
                        '⏰ Đã hết giờ làm việc trong tuần! Ca làm việc tự động kết thúc.', 
                        'error', 5000)
                    
                    -- Cập nhật thời gian làm việc
                    data.dailyWorkHours = totalDailyHours
                    data.weeklyWorkHours = totalWeeklyHours
                    
                    print(('[Wind Turbine] Player %s auto-stopped: WEEKLY_LIMIT (Daily: %.1fh, Weekly: %.1fh)'):format(
                        playerId, data.dailyWorkHours, data.weeklyWorkHours))
                    
                    goto continue
                end
                
                -- Sinh tiền mỗi chu kỳ (15 phút)
                if currentTime - data.lastEarning >= (Config.EarningCycle / 1000) then
                    local canEarn, status = CanEarnMoney(playerId)
                    
                    if canEarn then
                        local earnings = CalculateEarnings(playerId)
                        if earnings > 0 then
                            data.earningsPool = data.earningsPool + earnings
                            data.lastEarning = currentTime
                            
                            TriggerClientEvent('windturbine:updateEarningsPool', playerId, data.earningsPool)
                            
                            -- Thông báo thu nhập
                            local efficiency = CalculateEfficiency(playerId)
                            if efficiency >= 80 then
                                TriggerClientEvent('QBCore:Notify', playerId, 
                                    string.format('💵 +$%d IC | Hiệu suất tuyệt vời!', math.floor(earnings)), 
                                    'success', 2000)
                            elseif efficiency >= 50 then
                                TriggerClientEvent('QBCore:Notify', playerId, 
                                    string.format('💵 +$%d IC', math.floor(earnings)), 
                                    'primary', 2000)
                            end
                        end
                    else
                        -- Máy ngừng hoạt động
                        TriggerClientEvent('QBCore:Notify', playerId, 
                            '🚨 Máy ngừng hoạt động! 3 chỉ số dưới 30%! Cần sửa chữa ngay!', 
                            'error', 5000)
                        data.lastEarning = currentTime
                    end
                end
                
                -- Áp dụng penalty mỗi giờ (CHỈ CÓ PENALTY, KHÔNG CÓ DEGRADE TỰ NHIÊN)
                if currentTime - data.lastPenalty >= (Config.PenaltyCycle / 1000) then
                    -- Cập nhật work time mỗi giờ (LUÔN LUÔN, bất kể có penalty hay không)
                    local currentWorkHours = (currentTime - data.workStartTime) / 3600
                    TriggerClientEvent('windturbine:updateWorkTime', playerId, currentWorkHours, Config.MaxDailyHours)
                    
                    print(('[Wind Turbine] Player %s: Work time updated to %.1fh'):format(playerId, currentWorkHours))
                    
                    -- Sau đó mới check penalty
                    ApplyPenalty(playerId)
                    data.lastPenalty = currentTime
                end
            end
            
            ::continue::
        end
    end
end)

-- Cleanup khi player disconnect
AddEventHandler('playerDropped', function()
    local playerId = source
    if playerData[playerId] then
        -- Lưu thời gian làm việc trước khi disconnect
        if playerData[playerId].onDuty then
            local workDuration = (os.time() - playerData[playerId].workStartTime) / 3600
            playerData[playerId].dailyWorkHours = playerData[playerId].dailyWorkHours + workDuration
            playerData[playerId].weeklyWorkHours = playerData[playerId].weeklyWorkHours + workDuration
            
            print(('[Wind Turbine] Player %s disconnected while working (%.1fh)'):format(playerId, workDuration))
        end
        
        playerData[playerId] = nil
    end
end)
