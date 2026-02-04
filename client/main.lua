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
local lastNotifyTime = 0 -- Chống spam notify

-- Dữ liệu thuê trạm (StateBag tự động đồng bộ - KHÔNG CẦN CHECK!)
local turbineId = "turbine_1"
local rentalStatus = {
    isRented = false,
    isOwner = false,
    ownerName = nil,
    expiryTime = nil,
    withdrawDeadline = nil,
    isGracePeriod = false,
    rentalPrice = 0
}



-- Helper: Lấy timestamp hiện tại (milliseconds)
local function GetCurrentTime()
    return GetGameTimer()
end

-- Helper: Lấy ngày hiện tại (format: YYYY-MM-DD)
-- Reset vào 6:00 sáng giờ Việt Nam (UTC+7)
local function GetCurrentDay()
    local timestamp = GetCloudTimeAsInt()
    -- Điều chỉnh để reset vào 6:00 sáng VN thay vì 00:00 VN
    -- 6:00 VN = 23:00 UTC ngày hôm trước
    -- Nên ta trừ đi 1 giờ (3600 giây) từ UTC+7
    local vietnamOffset = (7 * 3600) - (6 * 3600) -- UTC+7 - 6 giờ = UTC+1
    local adjustedTime = timestamp + vietnamOffset
    local days = math.floor(adjustedTime / 86400)
    return tostring(days) -- Trả về số ngày kể từ epoch
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
    lastDayReset = ""
}

-- ============================================
-- UI FUNCTIONS (Định nghĩa trước để StateBag handler có thể dùng)
-- ============================================

-- Đóng UI
local function CloseUI()
    SetNuiFocus(false, false)
    SendNUIMessage({
        action = 'hideUI'
    })
end

-- Mở UI thuê trạm (Định nghĩa TRƯỚC OpenMainUI)
local function OpenRentalUI()
    SetNuiFocus(true, true)
    SendNUIMessage({
        action = 'showRentalUI',
        isRented = rentalStatus.isRented,
        isOwner = rentalStatus.isOwner,
        ownerName = rentalStatus.ownerName,
        expiryTime = rentalStatus.expiryTime,
        rentalPrice = rentalStatus.rentalPrice
    })
end

-- Mở UI rút tiền khi hết hạn (grace period)
local function OpenExpiryWithdrawUI()
    SetNuiFocus(true, true)
    SendNUIMessage({
        action = 'showExpiryWithdrawUI',
        earnings = currentEarnings,
        ownerName = rentalStatus.ownerName,
        expiryTime = rentalStatus.expiryTime,
        withdrawDeadline = rentalStatus.withdrawDeadline
    })
end

-- Mở UI chính
local function OpenMainUI()
    -- Kiểm tra grace period trước
    if rentalStatus.isGracePeriod and rentalStatus.isOwner then
        -- Đang trong grace period (4 giờ để rút tiền)
        OpenExpiryWithdrawUI()
        return
    end
    
    -- Kiểm tra trạng thái thuê trước khi mở UI
    if not rentalStatus.isRented then
        -- Chưa thuê -> Hiển thị UI thuê trạm
        OpenRentalUI()
        return
    end
    
    if not rentalStatus.isOwner then
        -- Đã thuê nhưng không phải chủ
        QBCore.Functions.Notify('❌ Trạm này đã có người thuê!', 'error', 5000)
        return
    end
    
    -- Tính thời gian làm việc hiện tại
    local currentWorkHours = 0
    if playerData.onDuty and playerData.workStartTime > 0 then
        currentWorkHours = (GetCurrentTime() - playerData.workStartTime) / 1000 / 3600
    end
    
    -- Là chủ -> Mở UI làm việc bình thường
    SetNuiFocus(true, true)
    SendNUIMessage({
        action = 'showMainUI',
        systems = currentSystems,
        efficiency = currentEfficiency,
        earnings = currentEarnings,
        onDuty = isOnDuty,
        ownerName = rentalStatus.ownerName or 'N/A',
        expiryTime = rentalStatus.expiryTime,
        workHours = currentWorkHours,
        maxHours = Config.MaxDailyHours
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

-- ============================================
-- KHỞI TẠO VÀ STATEBAG HANDLER
-- ============================================

-- Khởi tạo ngày khi script load
CreateThread(function()
    Wait(1000)
    playerData.lastDayReset = GetCurrentDay()
    
    rentalStatus = {
        isRented = false,
        isOwner = false,
        ownerName = nil,
        expiryTime = nil,
        withdrawDeadline = nil,
        isGracePeriod = false,
        rentalPrice = Config.RentalPrice
    }
    
    -- Lắng nghe StateBag - TỰ ĐỘNG CẬP NHẬT KHI CÓ THAY ĐỔI (KHÔNG CẦN CHECK!)
    AddStateBagChangeHandler('turbine_' .. turbineId, 'global', function(bagName, key, value)
        print('[DEBUG CLIENT] StateBag changed:', json.encode(value))
        
        local wasGracePeriod = rentalStatus.isGracePeriod
        local wasOwner = rentalStatus.isOwner
        
        if value then
            local Player = QBCore.Functions.GetPlayerData()
            local isOwner = (value.isRented and Player.citizenid == value.citizenid) or 
                           (value.isGracePeriod and Player.citizenid == value.citizenid)
            
            rentalStatus.isRented = value.isRented
            rentalStatus.isOwner = isOwner
            rentalStatus.ownerName = value.ownerName
            rentalStatus.expiryTime = value.expiryTime
            rentalStatus.withdrawDeadline = value.withdrawDeadline
            rentalStatus.isGracePeriod = value.isGracePeriod or false
            
            print('[DEBUG CLIENT] Updated rentalStatus: isGracePeriod=' .. tostring(rentalStatus.isGracePeriod) .. ', isOwner=' .. tostring(rentalStatus.isOwner))
            
            -- Nếu chuyển sang grace period và đang là owner → CHỈ đóng UI và tắt duty, KHÔNG tự động mở ExpiryWithdrawUI
            if not wasGracePeriod and rentalStatus.isGracePeriod and rentalStatus.isOwner then
                print('[DEBUG CLIENT] Entering grace period - closing UI and stopping duty')
                
                -- Chạy trong thread riêng để tránh block StateBag handler
                CreateThread(function()
                    -- Đóng UI hiện tại
                    CloseUI()
                    
                    -- Tắt duty nếu đang bật
                    if playerData.onDuty then
                        local workDuration = (GetCurrentTime() - playerData.workStartTime) / 1000 / 3600
                        playerData.dailyWorkHours = playerData.dailyWorkHours + workDuration
                        playerData.onDuty = false
                        isOnDuty = false
                    end
                    
                    -- KHÔNG tự động mở ExpiryWithdrawUI - chỉ mở khi người chơi tương tác với máy
                end)
            end
        else
            -- Server reset hoặc trạm hết hạn → Reset client
            rentalStatus.isRented = false
            rentalStatus.isOwner = false
            rentalStatus.ownerName = nil
            rentalStatus.expiryTime = nil
            rentalStatus.withdrawDeadline = nil
            rentalStatus.isGracePeriod = false
            
            -- Đóng UI nếu đang mở
            if wasOwner then
                CloseUI()
            end
        end
    end)
    
    -- Load rental status ban đầu
    local initialState = GlobalState['turbine_' .. turbineId]
    if initialState and initialState.isRented then
        local Player = QBCore.Functions.GetPlayerData()
        local isOwner = initialState.isRented and Player.citizenid == initialState.citizenid
        
        rentalStatus.isRented = initialState.isRented
        rentalStatus.isOwner = isOwner
        rentalStatus.ownerName = initialState.ownerName
        rentalStatus.expiryTime = initialState.expiryTime
    else
        -- Không có data từ server → Reset về trạng thái chưa thuê
        rentalStatus.isRented = false
        rentalStatus.isOwner = false
        rentalStatus.ownerName = nil
        rentalStatus.expiryTime = nil
    end
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
        
        -- Tính theo % thực tế của hệ thống
        if value < 30 then
            systemProfit = 0 -- Dưới 30% không sinh tiền
        else
            -- Từ 30% trở lên: tính theo tỷ lệ thực tế
            systemProfit = systemProfit * (value / 100)
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
    
    -- Random chọn hệ thống bị ảnh hưởng (loại bỏ các hệ thống đã 0%)
    local systemNames = {"stability", "electric", "lubrication", "blades", "safety"}
    local systemDisplayNames = {
        stability = "Độ ổn định",
        electric = "Hệ thống điện",
        lubrication = "Bôi trơn",
        blades = "Thân tháp",
        safety = "An toàn"
    }
    
    -- Lọc ra các hệ thống còn > 0%
    local availableSystems = {}
    for _, systemName in ipairs(systemNames) do
        if playerData.systems[systemName] > 0 then
            table.insert(availableSystems, systemName)
        end
    end
    
    -- Nếu không còn hệ thống nào > 0%, không áp dụng penalty
    if #availableSystems == 0 then
        QBCore.Functions.Notify('⚠️ Tất cả hệ thống đã hỏng hoàn toàn!', 'error', 3000)
        return
    end
    
    -- Giới hạn số lượng hệ thống bị ảnh hưởng theo số hệ thống còn lại
    numSystems = math.min(numSystems, #availableSystems)
    
    local affectedSystems = {}
    local systemDetails = {}
    
    for i = 1, numSystems do
        local randomIndex = math.random(1, #availableSystems)
        local systemName = table.remove(availableSystems, randomIndex)
        
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
end

-- Kiểm tra và reset giới hạn thời gian
local function CheckTimeLimit()
    local currentDay = GetCurrentDay()
    
    -- Reset daily counter
    if playerData.lastDayReset ~= currentDay then
        playerData.dailyWorkHours = 0
        playerData.lastDayReset = currentDay
        
        SendNUIMessage({
            action = 'resetWorkLimit'
        })
    end
    
    -- Kiểm tra giới hạn ngày
    if playerData.dailyWorkHours >= Config.MaxDailyHours then
        return false, "DAILY_LIMIT"
    end
    
    return true, "OK"
end

-- NUI Callbacks
RegisterNUICallback('close', function(data, cb)
    CloseUI()
    cb('ok')
end)

RegisterNUICallback('startDuty', function(data, cb)
    -- Kiểm tra quyền sở hữu trạm
    if not rentalStatus.isOwner then
        QBCore.Functions.Notify('❌ Bạn không phải chủ trạm này!', 'error')
        cb('ok')
        return
    end
    
    -- Kiểm tra giới hạn thời gian
    local canWork, reason = CheckTimeLimit()
    if not canWork then
        if reason == "DAILY_LIMIT" then
            QBCore.Functions.Notify('❌ Đã đạt giới hạn 12 giờ/ngày! Hãy quay lại sau 6:00 sáng.', 'error', 5000)
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
    
    cb('ok')
end)

RegisterNUICallback('stopDuty', function(data, cb)
    if playerData.onDuty then
        -- Tính thời gian làm việc (milliseconds -> hours)
        local workDuration = (GetCurrentTime() - playerData.workStartTime) / 1000 / 3600
        playerData.dailyWorkHours = playerData.dailyWorkHours + workDuration
        
        playerData.onDuty = false
        isOnDuty = false
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

-- NUI Callback: Rút tiền trong grace period
RegisterNUICallback('expiryWithdraw', function(data, cb)
    local amount = math.floor(playerData.earningsPool)
    
    if amount <= 0 then
        QBCore.Functions.Notify('❌ Không có tiền để rút!', 'error')
        cb('ok')
        return
    end
    
    -- Gửi request lên server
    TriggerServerEvent('windturbine:expiryWithdraw', turbineId, amount)
    
    -- Reset earnings pool
    playerData.earningsPool = 0
    currentEarnings = 0
    
    cb('ok')
end)

-- NUI Callback: Thuê trạm
RegisterNUICallback('rentTurbine', function(data, cb)
    local rentalPrice = Config.RentalPrice or 0
    
    -- Kiểm tra trạng thái hiện tại (StateBag đã tự động cập nhật)
    if rentalStatus.isRented and not rentalStatus.isOwner then
        QBCore.Functions.Notify('❌ Trạm này đã có người thuê!', 'error', 5000)
        cb('ok')
        return
    end
    
    -- Gửi request lên server để thuê (server sẽ kiểm tra lần nữa)
    TriggerServerEvent('windturbine:rentTurbine', turbineId, rentalPrice)
    cb('ok')
end)

-- Server Events
RegisterNetEvent('windturbine:rentSuccess')
AddEventHandler('windturbine:rentSuccess', function(data)
    -- StateBag sẽ tự động cập nhật rentalStatus, không cần làm gì thêm
    
    -- Thông báo thành công
    if Config.RentalPrice > 0 then
        QBCore.Functions.Notify(
            string.format('✅ Đã thuê trạm điện gió! Giá: $%s IC | Thời hạn: 7 ngày', 
                string.format("%d", Config.RentalPrice)), 
            'success', 5000)
    else
        QBCore.Functions.Notify('✅ Đã thuê trạm điện gió MIỄN PHÍ! Thời hạn: 7 ngày', 'success', 5000)
    end
    
    -- Đóng UI thuê và mở UI làm việc
    CloseUI()
    Wait(500)
    OpenMainUI()
end)

RegisterNetEvent('windturbine:rentFailed')
AddEventHandler('windturbine:rentFailed', function()
    -- StateBag đã tự động cập nhật, không cần làm gì
    QBCore.Functions.Notify('❌ Không thể thuê trạm này!', 'error', 3000)
end)
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

RegisterNetEvent('windturbine:expiryWithdrawSuccess')
AddEventHandler('windturbine:expiryWithdrawSuccess', function()
    -- Reset player data
    playerData.earningsPool = 0
    currentEarnings = 0
    
    -- Đóng UI
    CloseUI()
    
    QBCore.Functions.Notify('✅ Đã rút tiền thành công! Trạm đã được reset.', 'success', 5000)
end)

-- Thread: Cập nhật thời gian làm việc liên tục (mỗi giây)
CreateThread(function()
    while true do
        Wait(1000) -- Cập nhật mỗi giây
        
        if playerData.onDuty then
            local currentTime = GetCurrentTime()
            local currentWorkHours = (currentTime - playerData.workStartTime) / 1000 / 3600
            
            -- Cập nhật UI với thời gian hiện tại
            SendNUIMessage({
                action = 'updateWorkTime',
                workHours = currentWorkHours,
                maxHours = Config.MaxDailyHours
            })
        end
    end
end)

-- Thread: Sinh tiền và penalty (Chuyển từ server)
CreateThread(function()
    while true do
        Wait(5000) -- Check mỗi 5 giây để chính xác hơn
        
        if playerData.onDuty then
            local currentTime = GetCurrentTime()
            
            -- Tính thời gian làm việc hiện tại (milliseconds -> hours)
            local currentWorkHours = (currentTime - playerData.workStartTime) / 1000 / 3600
            playerData.totalWorkHours = currentWorkHours
            
            -- Kiểm tra giới hạn thời gian (bao gồm cả thời gian ca hiện tại)
            local totalDailyHours = playerData.dailyWorkHours + currentWorkHours
            
            -- Kiểm tra nếu vượt quá giới hạn ngày
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
                
                SendNUIMessage({
                    action = 'resetToInitialState'
                })
                CloseUI()
                
                goto continue
            end
            
            -- Sinh tiền mỗi chu kỳ
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
                -- Áp dụng penalty
                ApplyPenalty()
                playerData.lastPenalty = currentTime
            end
        end
        
        ::continue::
    end
end)

-- Thread: Kiểm tra khoảng cách (KHÔNG CẦN CHECK RENTAL NỮA - STATEBAG TỰ ĐỘNG!)
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
        
        -- Cảnh báo khi rời xa trong khi đang làm việc
        if isOnDuty and distance > 50.0 then
            local currentTime = GetGameTimer()
            if currentTime - lastWarningTime > 30000 then
                QBCore.Functions.Notify('⚠️ Bạn đang rời xa cối xay gió! Ca làm việc vẫn tiếp tục.', 'warning', 5000)
                lastWarningTime = currentTime
            end
        end
    end
end)

local turbineObject = nil

-- Hàm khởi tạo Object (Chỉ chạy 1 lần hoặc khi cần thiết)
CreateThread(function()
    local modelHash = GetHashKey("f17_bangdieukhiendiengio")
    
    -- Load model vào bộ nhớ
    RequestModel(modelHash)
    while not HasModelLoaded(modelHash) do
        Wait(1)
    end

    -- Tạo Object tại vị trí Config (Đặt z - 1.0 hoặc tùy chỉnh để nó chạm đất)
    turbineObject = CreateObject(modelHash, Config.TurbineLocation.x, Config.TurbineLocation.y, Config.TurbineLocation.z - 1.0, false, false, false)
    SetEntityHeading(turbineObject, Config.TurbineLocation.w or 0.0) -- Thêm Heading trong Config nếu muốn xoay bảng
    FreezeEntityPosition(turbineObject, true) -- Giữ bảng cố định, không bị tông đổ
    SetEntityInvincible(turbineObject, true) -- Không bị phá hủy
end)

-- Vòng lặp xử lý logic
CreateThread(function()
    while true do
        local sleep = 1000 -- Tối ưu hiệu năng khi ở xa
        local playerPed = PlayerPedId()
        local playerCoords = GetEntityCoords(playerPed)
        local dist = #(playerCoords - vector3(Config.TurbineLocation.x, Config.TurbineLocation.y, Config.TurbineLocation.z))

        if dist < 3.0 then -- Chỉ xử lý khi ở gần bảng điều khiển trong bán kính 3m
            sleep = 0 
            
            local displayText = ""
            if not rentalStatus.isRented then
                displayText = "[~g~E~w~] Thuê trạm điện gió"
            elseif rentalStatus.isOwner then
                if not isOnDuty then
                    displayText = "[~g~E~w~] Bắt đầu ca làm việc"
                else
                    displayText = "[~g~E~w~] Mở bảng điều khiển"
                end
            else
                displayText = "~r~Trạm đã có chủ sở hữu"
            end

            -- Vẽ chữ 3D ngay trên mặt bảng điều khiển
            DrawText3D(Config.TurbineLocation.x, Config.TurbineLocation.y, Config.TurbineLocation.z + 0.5, displayText)

            -- Kiểm tra bấm phím E
            if IsControlJustReleased(0, 38) then 
                if rentalStatus.isRented and not rentalStatus.isOwner then
                    local currentTime = GetGameTimer()
                    if currentTime - (lastNotifyTime or 0) > 5000 then
                        QBCore.Functions.Notify('❌ Trạm này đã có người thuê!', 'error', 5000)
                        lastNotifyTime = currentTime
                    end
                else
                    OpenMainUI()
                end
            end
        end
        Wait(sleep)
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
