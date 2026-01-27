QBCore = exports['qb-core']:GetCoreObject()

local isOnDuty = false
local isNearTurbine = false
local currentSystems = {
    stability = Config.InitialSystemValue,
    electric = Config.InitialSystemValue,
    lubrication = Config.InitialSystemValue,
    blades = Config.InitialSystemValue,
    safety = Config.InitialSystemValue
}
local currentEfficiency = 0
local currentEarnings = 0
local turbineSoundId = -1

-- Helper: Lấy timestamp hiện tại (milliseconds)
local function GetCurrentTime()
    return GetGameTimer()
end

-- Helper: Lấy ngày hiện tại (format: YYYY-MM-DD)
local function GetCurrentDay()
    local timestamp = GetCloudTimeAsInt()
    local days = math.floor(timestamp / 86400)
    return tostring(days) -- Trả về số ngày kể từ epoch
end

-- Helper: Lấy tuần hiện tại (format: week number)
local function GetCurrentWeek()
    local timestamp = GetCloudTimeAsInt()
    local weeks = math.floor(timestamp / 604800) -- 604800 = 7 days in seconds
    return tostring(weeks) -- Trả về số tuần kể từ epoch
end

-- Dữ liệu player (chuyển từ server)
local playerData = {
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
    workStartTime = 0,
    totalWorkHours = 0,
    dailyWorkHours = 0,
    weeklyWorkHours = 0,
    lastDayReset = "",
    lastWeekReset = ""
}

-- Khởi tạo ngày/tuần khi script load
CreateThread(function()
    Wait(1000) -- Đợi game load xong
    playerData.lastDayReset = GetCurrentDay()
    playerData.lastWeekReset = GetCurrentWeek()
end)

-- ============================================
-- LOGIC FUNCTIONS (Chuyển từ server)
-- ============================================

-- Tính hiệu suất tổng (trung bình 5 chỉ số)
local function CalculateEfficiency()
    local systems = playerData.systems
    local total = systems.stability + systems.electric + systems.lubrication + 
                  systems.blades + systems.safety
    
    return total / 5
end

-- Tính lợi nhuận dựa trên từng chỉ số (mỗi chỉ số = 20% lợi nhuận)
local function CalculateSystemProfit()
    local systems = playerData.systems
    local totalProfit = 0
    
    for systemName, value in pairs(systems) do
        local systemProfit = Config.BaseSalary * (Config.SystemProfitContribution / 100)
        
        if value < 30 then
            systemProfit = 0
        elseif value < 50 then
            systemProfit = systemProfit * 0.5
        else
            systemProfit = systemProfit
        end
        
        totalProfit = totalProfit + systemProfit
    end
    
    return totalProfit
end

-- Kiểm tra điều kiện sinh tiền (nếu 3 chỉ số < 30% => máy ngừng hoạt động)
local function CanEarnMoney()
    local systems = playerData.systems
    local below30 = 0
    
    for _, value in pairs(systems) do
        if value < 30 then below30 = below30 + 1 end
    end
    
    if below30 >= 3 then 
        return false, "STOPPED"
    end
    
    return true, "RUNNING"
end

-- Tính tiền sinh ra dựa trên từng chỉ số
local function CalculateEarnings()
    if not playerData.onDuty then return 0 end
    
    local canEarn, status = CanEarnMoney()
    if not canEarn then return 0 end
    
    local earnPerMinute = CalculateSystemProfit()
    
    return earnPerMinute
end

-- Áp dụng penalty theo giờ hoạt động
local function ApplyPenalty()
    if not playerData.onDuty then return end
    
    local workHours = playerData.totalWorkHours
    
    -- Tìm penalty range phù hợp
    local penaltyRange = nil
    for _, range in ipairs(Config.PenaltyRanges) do
        if workHours >= range.minHours and workHours < range.maxHours then
            penaltyRange = range
            break
        end
    end
    
    if not penaltyRange or #penaltyRange.penalties == 0 then 
        print(('[Wind Turbine] No penalty (%.1f hours worked)'):format(workHours))
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
        QBCore.Functions.Notify('✅ May mắn! Không có hư hỏng nào xảy ra!', 'success', 3000)
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
        
        local beforeValue = playerData.systems[systemName]
        local afterValue = math.max(0, beforeValue - selectedPenalty.damage)
        playerData.systems[systemName] = afterValue
        
        table.insert(affectedSystems, systemName)
        table.insert(systemDetails, string.format('%s: %d%% → %d%%', systemDisplayNames[systemName], beforeValue, afterValue))
    end
    
    -- Thông báo chi tiết
    local detailsText = table.concat(systemDetails, ' | ')
    QBCore.Functions.Notify(
        string.format('⚠️ Penalty! Giảm %d%%: %s', selectedPenalty.damage, detailsText), 
        'error', 7000)
    
    -- Gửi cảnh báo penalty qua lb-phone
    TriggerServerEvent('windturbine:sendPhoneNotification', 'penalty', {
        workHours = workHours,
        numSystems = numSystems,
        damage = selectedPenalty.damage,
        systemDetails = systemDetails
    })
    
    local actualEarningRate = CalculateSystemProfit() * 4
    
    -- Update UI
    currentSystems = playerData.systems
    currentEfficiency = CalculateEfficiency()
    
    SendNUIMessage({
        action = 'updateSystems',
        systems = currentSystems
    })
    SendNUIMessage({
        action = 'updateEfficiency',
        efficiency = currentEfficiency
    })
    SendNUIMessage({
        action = 'updateActualEarningRate',
        earningRate = actualEarningRate
    })
    
    print(('[Wind Turbine] Penalty: %d systems -%d%% (%.1f hours worked)'):format(
        numSystems, selectedPenalty.damage, workHours))
end

-- Kiểm tra và reset giới hạn thời gian
local function CheckTimeLimit()
    local currentDay = GetCurrentDay()
    local currentWeek = GetCurrentWeek()
    
    -- Reset daily counter
    if playerData.lastDayReset ~= currentDay then
        playerData.dailyWorkHours = 0
        playerData.lastDayReset = currentDay
        
        SendNUIMessage({
            action = 'resetWorkLimit'
        })
    end
    
    -- Reset weekly counter
    if playerData.lastWeekReset ~= currentWeek then
        playerData.weeklyWorkHours = 0
        playerData.lastWeekReset = currentWeek
        
        SendNUIMessage({
            action = 'resetWorkLimit'
        })
    end
    
    -- Kiểm tra giới hạn
    if playerData.dailyWorkHours >= Config.MaxDailyHours then
        return false, "DAILY_LIMIT"
    end
    
    if playerData.weeklyWorkHours >= Config.MaxWeeklyHours then
        return false, "WEEKLY_LIMIT"
    end
    
    return true, "OK"
end

-- Mở UI chính
local function OpenMainUI()
    SetNuiFocus(true, true)
    SendNUIMessage({
        action = 'showMainUI',
        systems = currentSystems,
        efficiency = currentEfficiency,
        earnings = currentEarnings,
        onDuty = isOnDuty
    })
end

-- Đóng UI
local function CloseUI()
    SetNuiFocus(false, false)
    SendNUIMessage({
        action = 'hideUI'
    })
end

-- Mở minigame
local function OpenMinigame(system)
    local settings = Config.MinigameSettings[system]
    if not settings then return end
    
    SetNuiFocus(true, true)
    SendNUIMessage({
        action = 'showMinigame',
        system = system,
        title = settings.title,
        speed = settings.speed,
        zoneSize = settings.zoneSize,
        rounds = settings.rounds
    })
end

-- Mở UI quỹ tiền
local function OpenEarningsUI()
    SetNuiFocus(true, true)
    SendNUIMessage({
        action = 'showEarningsUI',
        earnings = currentEarnings,
        efficiency = currentEfficiency
    })
end

-- NUI Callbacks
RegisterNUICallback('close', function(data, cb)
    CloseUI()
    cb('ok')
end)

RegisterNUICallback('startDuty', function(data, cb)
    -- Kiểm tra giới hạn thời gian
    local canWork, reason = CheckTimeLimit()
    if not canWork then
        if reason == "DAILY_LIMIT" then
            QBCore.Functions.Notify('❌ Đã đạt giới hạn! Hãy quay lại vào ngày mai.', 'error', 5000)
            SendNUIMessage({
                action = 'workLimitReached'
            })
        elseif reason == "WEEKLY_LIMIT" then
            QBCore.Functions.Notify('❌ Đã đạt giới hạn tuần! Hãy quay lại vào tuần sau.', 'error', 5000)
            SendNUIMessage({
                action = 'workLimitReached'
            })
        end
        cb('ok')
        return
    end
    
    playerData.onDuty = true
    playerData.workStartTime = GetCurrentTime()
    playerData.lastEarning = GetCurrentTime()
    playerData.lastPenalty = GetCurrentTime()
    
    isOnDuty = true
    currentSystems = playerData.systems
    currentEfficiency = CalculateEfficiency()
    currentEarnings = playerData.earningsPool
    
    local actualEarningRate = CalculateSystemProfit() * 4
    
    SendNUIMessage({
        action = 'updateSystems',
        systems = currentSystems
    })
    SendNUIMessage({
        action = 'updateEfficiency',
        efficiency = currentEfficiency
    })
    SendNUIMessage({
        action = 'updateEarningsPool',
        earnings = currentEarnings
    })
    SendNUIMessage({
        action = 'updateActualEarningRate',
        earningRate = actualEarningRate
    })
    SendNUIMessage({
        action = 'updateWorkTime',
        workHours = 0,
        maxHours = Config.MaxDailyHours
    })
    
    QBCore.Functions.Notify('✅ Đã bắt đầu ca làm việc tại cối xay gió!', 'success', 3000)
    PlaySound(-1, "CHECKPOINT_PERFECT", "HUD_MINI_GAME_SOUNDSET", 0, 0, 1)
    
    -- Gửi tin nhắn chào mừng qua lb-phone
    TriggerServerEvent('windturbine:sendPhoneNotification', 'welcome', {
        systems = playerData.systems,
        earningRate = actualEarningRate
    })
    
    print(('[Wind Turbine] Started duty (Daily: %.1fh/%.0fh, Weekly: %.1fh/%.0fh)'):format(
        playerData.dailyWorkHours, Config.MaxDailyHours,
        playerData.weeklyWorkHours, Config.MaxWeeklyHours))
    
    cb('ok')
end)

RegisterNUICallback('stopDuty', function(data, cb)
    if playerData.onDuty then
        -- Tính thời gian làm việc (milliseconds -> hours)
        local workDuration = (GetCurrentTime() - playerData.workStartTime) / 1000 / 3600
        playerData.dailyWorkHours = playerData.dailyWorkHours + workDuration
        playerData.weeklyWorkHours = playerData.weeklyWorkHours + workDuration
        
        playerData.onDuty = false
        isOnDuty = false
        
        print(('[Wind Turbine] Stopped duty (Worked: %.1fh, Daily: %.1fh, Weekly: %.1fh)'):format(
            workDuration, playerData.dailyWorkHours, playerData.weeklyWorkHours))
    end
    
    CloseUI()
    
    QBCore.Functions.Notify('👋 Đã kết thúc ca làm việc!', 'primary', 3000)
    PlaySound(-1, "QUIT", "HUD_FRONTEND_DEFAULT_SOUNDSET", 0, 0, 1)
    
    SendNUIMessage({
        action = 'resetToInitialState'
    })
    
    cb('ok')
end)

RegisterNUICallback('repair', function(data, cb)
    if data.system then
        OpenMinigame(data.system)
    end
    cb('ok')
end)

RegisterNUICallback('minigameResult', function(data, cb)
    if not playerData.onDuty then 
        cb('ok')
        return 
    end
    
    local system = data.system
    local result = data.result
    
    if not playerData.systems[system] then 
        cb('ok')
        return 
    end
    
    local reward = 0
    
    if result == 'perfect' then
        reward = Config.RepairRewards.perfect
    elseif result == 'good' then
        reward = Config.RepairRewards.good
    else
        reward = Config.RepairRewards.fail
    end
    
    local beforeValue = playerData.systems[system]
    playerData.systems[system] = math.min(100, playerData.systems[system] + reward)
    local afterValue = playerData.systems[system]
    
    local actualEarningRate = CalculateSystemProfit() * 4
    
    currentSystems = playerData.systems
    currentEfficiency = CalculateEfficiency()
    
    SendNUIMessage({
        action = 'updateSystems',
        systems = currentSystems
    })
    SendNUIMessage({
        action = 'updateEfficiency',
        efficiency = currentEfficiency
    })
    SendNUIMessage({
        action = 'updateActualEarningRate',
        earningRate = actualEarningRate
    })
    
    -- Thông báo kết quả sửa chữa
    if result == 'perfect' then
        QBCore.Functions.Notify('🌟 Hoàn hảo! Hệ thống ' .. system:upper() .. ' đã được sửa chữa tốt!', 'success', 3000)
        PlaySound(-1, "CHECKPOINT_PERFECT", "HUD_MINI_GAME_SOUNDSET", 0, 0, 1)
    elseif result == 'good' then
        QBCore.Functions.Notify('✅ Tốt! Hệ thống ' .. system:upper() .. ' đã được cải thiện!', 'success', 3000)
        PlaySound(-1, "CHECKPOINT_NORMAL", "HUD_MINI_GAME_SOUNDSET", 0, 0, 1)
    else
        QBCore.Functions.Notify('❌ Thất bại! Hệ thống ' .. system:upper() .. ' bị giảm hiệu suất!', 'error', 3000)
        PlaySound(-1, "CHECKPOINT_MISSED", "HUD_MINI_GAME_SOUNDSET", 0, 0, 1)
    end
    
    -- Gửi thông báo sửa chữa qua lb-phone (chỉ khi perfect hoặc good)
    if result == 'perfect' or result == 'good' then
        TriggerServerEvent('windturbine:sendPhoneNotification', 'repair', {
            system = system,
            result = result,
            reward = reward,
            beforeValue = beforeValue,
            afterValue = afterValue,
            efficiency = currentEfficiency,
            earningRate = actualEarningRate
        })
    end
    
    print(('[Wind Turbine] Repaired %s: %s (+%d%%)'):format(system, result, reward))
    
    -- Đợi 2.5 giây trước khi đóng và mở lại UI
    Wait(2500)
    CloseUI()
    Wait(300)
    OpenMainUI()
    cb('ok')
end)

RegisterNUICallback('openEarnings', function(data, cb)
    OpenEarningsUI()
    cb('ok')
end)

RegisterNUICallback('withdrawEarnings', function(data, cb)
    local amount = math.floor(playerData.earningsPool)
    
    if amount <= 0 then
        QBCore.Functions.Notify('❌ Không có tiền để rút!', 'error')
        cb('ok')
        return
    end
    
    -- Gửi request lên server để thêm tiền
    TriggerServerEvent('windturbine:withdrawEarnings', amount)
    
    PlaySound(-1, "PICK_UP", "HUD_FRONTEND_DEFAULT_SOUNDSET", 0, 0, 1)
    cb('ok')
end)

RegisterNUICallback('backToMain', function(data, cb)
    OpenMainUI()
    cb('ok')
end)

-- Server Events
RegisterNetEvent('windturbine:withdrawSuccess')
AddEventHandler('windturbine:withdrawSuccess', function(amount)
    playerData.earningsPool = 0
    currentEarnings = 0
    
    SendNUIMessage({
        action = 'updateEarnings',
        earnings = 0
    })
    
    QBCore.Functions.Notify(string.format('💰 Đã rút $%d từ quỹ tiền lương!', amount), 'success')
end)

-- Thread: Sinh tiền và penalty (Chuyển từ server)
CreateThread(function()
    while true do
        Wait(60000) -- Check mỗi phút
        
        if playerData.onDuty then
            local currentTime = GetCurrentTime()
            
            -- Tính thời gian làm việc hiện tại (milliseconds -> hours)
            local currentWorkHours = (currentTime - playerData.workStartTime) / 1000 / 3600
            playerData.totalWorkHours = currentWorkHours
            
            -- Kiểm tra giới hạn thời gian (bao gồm cả thời gian ca hiện tại)
            local totalDailyHours = playerData.dailyWorkHours + currentWorkHours
            local totalWeeklyHours = playerData.weeklyWorkHours + currentWorkHours
            
            -- Kiểm tra nếu vượt quá giới hạn
            if totalDailyHours >= Config.MaxDailyHours then
                -- Tự động kết thúc ca khi hết giờ
                playerData.onDuty = false
                isOnDuty = false
                
                QBCore.Functions.Notify('⏰ Đã hết giờ làm việc trong ngày! Ca làm việc tự động kết thúc.', 'error', 5000)
                
                -- Gửi báo cáo ca làm việc qua lb-phone
                TriggerServerEvent('windturbine:sendPhoneNotification', 'dailyLimit', {
                    totalDailyHours = totalDailyHours,
                    earningsPool = playerData.earningsPool,
                    efficiency = CalculateEfficiency()
                })
                
                -- Cập nhật thời gian làm việc
                playerData.dailyWorkHours = totalDailyHours
                playerData.weeklyWorkHours = totalWeeklyHours
                
                SendNUIMessage({
                    action = 'resetToInitialState'
                })
                CloseUI()
                
                print(('[Wind Turbine] Auto-stopped: DAILY_LIMIT (Daily: %.1fh, Weekly: %.1fh)'):format(
                    playerData.dailyWorkHours, playerData.weeklyWorkHours))
                
                goto continue
            end
            
            if totalWeeklyHours >= Config.MaxWeeklyHours then
                -- Tự động kết thúc ca khi hết giờ
                playerData.onDuty = false
                isOnDuty = false
                
                QBCore.Functions.Notify('⏰ Đã hết giờ làm việc trong tuần! Ca làm việc tự động kết thúc.', 'error', 5000)
                
                -- Gửi báo cáo tuần qua lb-phone
                TriggerServerEvent('windturbine:sendPhoneNotification', 'weeklyLimit', {
                    totalWeeklyHours = totalWeeklyHours,
                    maxWeeklyHours = Config.MaxWeeklyHours,
                    earningsPool = playerData.earningsPool,
                    efficiency = CalculateEfficiency()
                })
                
                -- Cập nhật thời gian làm việc
                playerData.dailyWorkHours = totalDailyHours
                playerData.weeklyWorkHours = totalWeeklyHours
                
                SendNUIMessage({
                    action = 'resetToInitialState'
                })
                CloseUI()
                
                print(('[Wind Turbine] Auto-stopped: WEEKLY_LIMIT (Daily: %.1fh, Weekly: %.1fh)'):format(
                    playerData.dailyWorkHours, playerData.weeklyWorkHours))
                
                goto continue
            end
            
            -- Sinh tiền mỗi chu kỳ (15 phút hoặc 30 giây trong test mode)
            if currentTime - playerData.lastEarning >= Config.EarningCycle then
                local canEarn, status = CanEarnMoney()
                
                if canEarn then
                    local earnings = CalculateEarnings()
                    if earnings > 0 then
                        playerData.earningsPool = playerData.earningsPool + earnings
                        playerData.lastEarning = currentTime
                        
                        currentEarnings = playerData.earningsPool
                        
                        SendNUIMessage({
                            action = 'updateEarnings',
                            earnings = currentEarnings
                        })
                        
                        -- Thông báo thu nhập
                        local efficiency = CalculateEfficiency()
                        if efficiency >= 80 then
                            QBCore.Functions.Notify(string.format('💵 +$%d IC | Hiệu suất tuyệt vời!', math.floor(earnings)), 'success', 2000)
                            
                            -- Gửi tin nhắn khen thưởng qua lb-phone (chỉ khi hiệu suất cao)
                            TriggerServerEvent('windturbine:sendPhoneNotification', 'bonus', {
                                earnings = earnings,
                                efficiency = efficiency,
                                earningsPool = playerData.earningsPool
                            })
                        elseif efficiency >= 50 then
                            QBCore.Functions.Notify(string.format('💵 +$%d IC', math.floor(earnings)), 'primary', 2000)
                        end
                    end
                else
                    -- Máy ngừng hoạt động
                    QBCore.Functions.Notify('🚨 Máy ngừng hoạt động! 3 chỉ số dưới 30%! Cần sửa chữa ngay!', 'error', 5000)
                    
                    -- Gửi cảnh báo khẩn cấp qua lb-phone
                    local criticalSystems = {}
                    for name, value in pairs(playerData.systems) do
                        if value < 30 then
                            table.insert(criticalSystems, {name = name, value = value})
                        end
                    end
                    
                    TriggerServerEvent('windturbine:sendPhoneNotification', 'emergency', {
                        criticalSystems = criticalSystems
                    })
                    
                    playerData.lastEarning = currentTime
                end
            end
            
            -- Áp dụng penalty mỗi giờ (CHỈ CÓ PENALTY, KHÔNG CÓ DEGRADE TỰ NHIÊN)
            if currentTime - playerData.lastPenalty >= Config.PenaltyCycle then
                -- Cập nhật work time mỗi giờ (LUÔN LUÔN, bất kể có penalty hay không)
                local currentWorkHours = (currentTime - playerData.workStartTime) / 1000 / 3600
                SendNUIMessage({
                    action = 'updateWorkTime',
                    workHours = currentWorkHours,
                    maxHours = Config.MaxDailyHours
                })
                
                print(('[Wind Turbine] Work time updated to %.1fh'):format(currentWorkHours))
                
                -- Sau đó mới check penalty
                ApplyPenalty()
                playerData.lastPenalty = currentTime
            end
        end
        
        ::continue::
    end
end)

-- Thread: Kiểm tra khoảng cách
CreateThread(function()
    local lastWarningTime = 0
    
    while true do
        Wait(1000)
        
        local playerPed = PlayerPedId()
        local playerCoords = GetEntityCoords(playerPed)
        local turbineCoords = Config.TurbineLocation
        local distance = math.sqrt(
            math.pow(playerCoords.x - turbineCoords.x, 2) +
            math.pow(playerCoords.y - turbineCoords.y, 2) +
            math.pow(playerCoords.z - turbineCoords.z, 2)
        )
        
        isNearTurbine = distance < 5.0
        
        -- Cảnh báo khi rời xa trong khi đang làm việc (không tự động kết thúc ca)
        if isOnDuty and distance > 50.0 then
            local currentTime = GetGameTimer()
            -- Chỉ thông báo mỗi 30 giây để tránh spam
            if currentTime - lastWarningTime > 30000 then
                QBCore.Functions.Notify('⚠️ Bạn đang rời xa cối xay gió! Ca làm việc vẫn tiếp tục.', 'warning', 5000)
                lastWarningTime = currentTime
            end
        end
    end
end)

-- Thread: Hiển thị marker và text
CreateThread(function()
    while true do
        Wait(0)
        
        if isNearTurbine then
            DrawMarker(1, Config.TurbineLocation.x, Config.TurbineLocation.y, Config.TurbineLocation.z - 1.0,
                0.0, 0.0, 0.0, 0.0, 0.0, 0.0, 2.0, 2.0, 1.0, 0, 255, 0, 100, false, true, 2, false, nil, nil, false)
            
            if not isOnDuty then
                DrawText3D(Config.TurbineLocation.x, Config.TurbineLocation.y, Config.TurbineLocation.z,
                    "[~g~E~w~] Bắt đầu ca làm việc")
                
                if IsControlJustReleased(0, 38) then -- E
                    OpenMainUI()
                end
            else
                DrawText3D(Config.TurbineLocation.x, Config.TurbineLocation.y, Config.TurbineLocation.z,
                    "[~g~E~w~] Mở bảng điều khiển")
                
                if IsControlJustReleased(0, 38) then -- E
                    OpenMainUI()
                end
            end
        end
    end
end)

-- Helper: Draw 3D Text
function DrawText3D(x, y, z, text)
    local onScreen, _x, _y = World3dToScreen2d(x, y, z)
    local px, py, pz = table.unpack(GetGameplayCamCoords())
    
    SetTextScale(0.35, 0.35)
    SetTextFont(4)
    SetTextProportional(1)
    SetTextColour(255, 255, 255, 215)
    SetTextEntry("STRING")
    SetTextCentre(1)
    AddTextComponentString(text)
    DrawText(_x, _y)
end
