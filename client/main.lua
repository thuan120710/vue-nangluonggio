-- ============================================
-- SECTION 1: DATA STRUCTURES
-- ============================================

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
local turbineId = nil -- Sẽ được set tự động khi gần trạm
local currentTurbineData = nil -- Lưu thông tin trạm hiện tại
local rentalStatus = {
    isRented = false,
    isOwner = false,
    ownerName = nil,
    expiryTime = nil,
    withdrawDeadline = nil,
    isGracePeriod = false
}

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
    lastFuelConsumption = 0,
    workStartTime = 0,
    totalWorkHours = 0,
    dailyWorkHours = 0,
    lastDayReset = "",
    currentFuel = 0 -- Bắt đầu với 0% xăng, phải đổ 4 can mới hoạt động
}

local turbineObjects = {}

-- ============================================
-- SECTION 2: UTILITY FUNCTIONS
-- ============================================

-- Get current timestamp (milliseconds)
-- @return number - Current game timer
local function GetCurrentTime()
    return GetGameTimer()
end

-- Get current day (reset at 6:00 AM Vietnam time)
-- Reset vào 6:00 sáng giờ Việt Nam (UTC+7)
-- ĐỒNG BỘ VỚI SERVER để cùng logic reset
-- @return string - Số ngày kể từ epoch
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

-- Draw 3D Text
-- @param x number - X coordinate
-- @param y number - Y coordinate
-- @param z number - Z coordinate
-- @param text string - Text to display
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

-- ============================================
-- SECTION 3: DISPLAY CALCULATION FUNCTIONS
-- ============================================
-- LƯU Ý: Các function này CHỈ ĐỂ HIỂN THỊ UI
-- Server mới là nơi tính toán earnings/penalty thực sự

-- Calculate efficiency (average of 5 systems) - DISPLAY ONLY
-- @return number - Efficiency percentage
local function CalculateEfficiency()
    local systems = playerData.systems
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

-- Calculate system profit (expected earning rate) - DISPLAY ONLY
-- Server calculates actual earnings
-- @return number - Expected profit per cycle
local function CalculateSystemProfit()
    local systems = playerData.systems
    local totalProfit = 0
    
    for systemName, value in pairs(systems) do
        local systemProfit = Config.BaseSalary * (Config.SystemProfitContribution / 100)
        
        if value <= 30 then
            systemProfit = 0
        else
            systemProfit = systemProfit * (value / 100)
        end
        
        totalProfit = totalProfit + systemProfit
    end
    
    return totalProfit
end

-- Update UI with current data
local function UpdateUI()
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
end

-- Stop duty and notify server
local function StopDuty()
    if playerData.onDuty then
        playerData.onDuty = false
        isOnDuty = false
        
        -- Gửi lên server để cập nhật
        TriggerServerEvent('windturbine:stopDuty')
    end
end

-- ============================================
-- SECTION 4: UI FUNCTIONS
-- ============================================

-- Close UI
local function CloseUI()
    SetNuiFocus(false, false)
    SendNUIMessage({
        action = 'hideUI'
    })
    if exports['f17-hudv2'] and exports['f17-hudv2'].toggleHud then
        exports['f17-hudv2']:toggleHud(true)
    end
end

-- Open rental UI
local function OpenRentalUI()
    exports['f17-hudv2']:toggleHud(false)
    
    SetNuiFocus(true, true)
    SendNUIMessage({
        action = 'showRentalUI',
        isRented = rentalStatus.isRented,
        isOwner = rentalStatus.isOwner,
        ownerName = rentalStatus.ownerName,
        expiryTime = rentalStatus.expiryTime,
        rentalPrice = Config.RentalPrice
    })
end

-- Open expiry withdraw UI
local function OpenExpiryWithdrawUI()
    exports['f17-hudv2']:toggleHud(false)
    
    SetNuiFocus(true, true)
    SendNUIMessage({
        action = 'showExpiryWithdrawUI',
        earnings = currentEarnings,
        ownerName = rentalStatus.ownerName,
        expiryTime = rentalStatus.expiryTime,
        withdrawDeadline = rentalStatus.withdrawDeadline
    })
end

-- Open main UI
local function OpenMainUI()
    if rentalStatus.isGracePeriod and rentalStatus.isOwner then
        OpenExpiryWithdrawUI()
        return
    end
    
    if not rentalStatus.isRented then
        OpenRentalUI()
        return
    end
    
    if not rentalStatus.isOwner then
        no:Notify('❌ Trạm này đã có người thuê!', 'error', 5000)
        return
    end
    
    exports['f17-hudv2']:toggleHud(false)
    
    local currentWorkHours = 0
    if playerData.onDuty and playerData.workStartTime > 0 then
        currentWorkHours = (GetCurrentTime() - playerData.workStartTime) / 1000 / 3600
    end

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
        maxHours = Config.MaxDailyHours,
        currentFuel = playerData.currentFuel,
        maxFuel = Config.MaxFuel
    })
end

-- Open minigame
-- @param system string - System name to repair
local function OpenMinigame(system)
    local settings = Config.MinigameSettings[system]
    if not settings then return end
    
    exports['f17-hudv2']:toggleHud(false)
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

-- ============================================
-- SECTION 5: INITIALIZATION
-- ============================================

-- Initialize day when script loads
CreateThread(function()
    Wait(1000)
    playerData.lastDayReset = GetCurrentDay()
    
    rentalStatus = {
        isRented = false,
        isOwner = false,
        ownerName = nil,
        expiryTime = nil,
        withdrawDeadline = nil,
        isGracePeriod = false
    }
end)

-- Initialize turbine objects for all stations
CreateThread(function()
    local modelHash = GetHashKey("f17_bangdieukhiendiengio")
    
    -- Load model vào bộ nhớ
    RequestModel(modelHash)
    while not HasModelLoaded(modelHash) do
        Wait(1)
    end

    -- Tạo Object cho mỗi trạm
    for _, turbineData in ipairs(Config.TurbineLocations) do
        local coords = turbineData.coords
        local obj = CreateObject(modelHash, coords.x, coords.y, coords.z - 1.0, false, false, false)
        SetEntityHeading(obj, coords.w or 0.0)
        FreezeEntityPosition(obj, true)
        SetEntityInvincible(obj, true)
        turbineObjects[turbineData.id] = obj
    end
end)

-- ============================================
-- SECTION 6: NUI CALLBACKS
-- ============================================

RegisterNUICallback('close', function(data, cb)
    CloseUI()
    cb('ok')
end)

RegisterNUICallback('startDuty', function(data, cb)
    -- Không cho phép bật duty khi đang grace period
    if rentalStatus.isGracePeriod then
        no:Notify('❌ Không thể làm việc trong thời gian grace period!', 'error', 5000)
        cb('ok')
        return
    end
    
    -- Kiểm tra xăng tối thiểu
    if playerData.currentFuel == 0 then
        no:Notify(string.format('❌ Hết xăng! Cần đổ %d can xăng  để khởi động lại máy.', math.ceil(Config.MinFuelToStart / Config.FuelPerJerrycan)), 'error', 7000)
        cb('ok')
        return
    elseif playerData.currentFuel < Config.MinFuelToStart and playerData.currentFuel > 0 then
        -- Nếu còn xăng nhưng chưa đủ 100, vẫn cho chạy (để tiêu hao hết)
    end
    
    -- Server sẽ kiểm tra giới hạn thời gian và ownership
    TriggerServerEvent('windturbine:startDuty', turbineId)
    
    cb('ok')
end)

RegisterNUICallback('stopDuty', function(data, cb)
    StopDuty()
    CloseUI()
    
    no:Notify('👋 Đã kết thúc ca làm việc!', 'primary', 3000)
    PlaySound(-1, "QUIT", "HUD_FRONTEND_DEFAULT_SOUNDSET", 0, 0, 1)
    
    SendNUIMessage({
        action = 'resetToInitialState'
    })
    
    cb('ok')
end)

RegisterNUICallback('repair', function(data, cb)
    -- Không cho phép sửa chữa khi đang grace period
    if rentalStatus.isGracePeriod then
        no:Notify('❌ Không thể sửa chữa trong thời gian grace period!', 'error', 5000)
        cb('ok')
        return
    end
    
    if data.system then
        -- Kiểm tra nếu hệ thống > 70% thì không cho sửa
        local systemValue = playerData.systems[data.system]
        if systemValue and systemValue > 70 then
            no:Notify('⚠️ Bảo trì bị từ chối: Mức hư hại hiện tại quá thấp. Yêu cầu ≤ 70%.', 'error', 5000)
            PlaySound(-1, "CHECKPOINT_MISSED", "HUD_MINI_GAME_SOUNDSET", 0, 0, 1)
            cb('ok')
            return
        end
        
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
    
    -- SECURITY FIX: Chỉ gửi result lên server, để server tự tính reward và afterValue
    local reward = 0
    
    if result == 'perfect' then
        reward = Config.RepairRewards.perfect
    elseif result == 'good' then
        reward = Config.RepairRewards.good
    else
        reward = Config.RepairRewards.fail
    end
    
    local beforeValue = playerData.systems[system]
    local afterValue = math.min(100, playerData.systems[system] + reward)
    
    -- Update UI tạm thời (server sẽ gửi giá trị chính xác về sau)
    playerData.systems[system] = afterValue
    UpdateUI()
    
    -- SECURITY FIX: Gửi result lên server, server sẽ tự tính afterValue
    TriggerServerEvent('windturbine:repairSystem', system, result)
    
    -- Thông báo kết quả sửa chữa
    if result == 'perfect' then
        no:Notify('🌟 Hoàn hảo! Hệ thống ' .. system:upper() .. ' đã được sửa chữa tốt!', 'success', 3000)
        PlaySound(-1, "CHECKPOINT_PERFECT", "HUD_MINI_GAME_SOUNDSET", 0, 0, 1)
    elseif result == 'good' then
        no:Notify('✅ Tốt! Hệ thống ' .. system:upper() .. ' đã được cải thiện!', 'success', 3000)
        PlaySound(-1, "CHECKPOINT_NORMAL", "HUD_MINI_GAME_SOUNDSET", 0, 0, 1)
    else
        no:Notify('❌ Thất bại! Hệ thống ' .. system:upper() .. ' bị giảm hiệu suất!', 'error', 3000)
        PlaySound(-1, "CHECKPOINT_MISSED", "HUD_MINI_GAME_SOUNDSET", 0, 0, 1)
    end
    
    -- Gửi thông báo sửa chữa qua lb-phone (chỉ khi perfect hoặc good)
    if result == 'perfect' or result == 'good' then
        local actualEarningRate = CalculateSystemProfit() * 4
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

RegisterNUICallback('refuelTurbine', function(data, cb)
    local countXang = ox:Search('count', 'jerrycan')

    if countXang < 4 then
        no:Notify('Bạn không đủ 4 can xăng!', 'error', 3000)
        cb('ok')
        return
    end

    if playerData.currentFuel >= Config.MaxFuel then
        no:Notify('Bình xăng đã đầy!', 'error', 3000)
        cb('ok')
        return
    end
    
    local cansNeeded = math.ceil(Config.MinFuelToStart / Config.FuelPerJerrycan)
    if playerData.currentFuel == 0 then
        if countXang < cansNeeded then
            no:Notify(string.format('Cần %d can xăng để khởi động lại! (Bạn có: %d can)', cansNeeded, countXang), 'primary', 5000)
            cb('ok')
            return
        end
        
        TriggerServerEvent('f17_tramdiengio:sv:useJerrycan', Config.MinFuelToStart, cansNeeded)
        cb('ok')
    else
        local fuelNeeded = Config.MaxFuel - playerData.currentFuel
        local fuelToAdd = math.min(Config.FuelPerJerrycan, fuelNeeded)

        TriggerServerEvent('f17_tramdiengio:sv:useJerrycan', fuelToAdd, cansNeeded)
        cb('ok')
    end
end)

RegisterNUICallback('withdrawEarnings', function(data, cb)
    local isGracePeriod = data.isGracePeriod or false
    
    -- SECURITY FIX: Không gửi amount, server sẽ tính
    TriggerServerEvent('windturbine:withdrawEarnings', isGracePeriod, turbineId)
    
    PlaySound(-1, "PICK_UP", "HUD_FRONTEND_DEFAULT_SOUNDSET", 0, 0, 1)
    cb('ok')
end)

RegisterNUICallback('rentTurbine', function(data, cb)
    -- SECURITY: Client gửi rentalPrice từ Config để server validate
    local rentalPrice = Config.RentalPrice or 0
    
    -- Kiểm tra trạng thái hiện tại (StateBag đã tự động cập nhật)
    if rentalStatus.isRented and not rentalStatus.isOwner then
        no:Notify('❌ Trạm này đã có người thuê!', 'error', 5000)
        cb('ok')
        return
    end
    
    -- Gửi request lên server để thuê (server sẽ validate rentalPrice)
    TriggerServerEvent('windturbine:rentTurbine', turbineId, rentalPrice)
    cb('ok')
end)

RegisterNUICallback('checkMoneyForRent', function(data, cb)
    local rentalPrice = data.rentalPrice or Config.RentalPrice or 0
    
    QBCore.Functions.TriggerCallback('windturbine:checkMoney', function(result)
        cb(result)
    end, rentalPrice)
end)

-- ============================================
-- SECTION 7: SERVER EVENTS
-- ============================================

RegisterNetEvent('windturbine:rentSuccess')
AddEventHandler('windturbine:rentSuccess', function(data)
    if Config.RentalPrice > 0 then
        no:Notify(string.format('[Điện gió] Đã thuê trạm điện gió | Giá: $%s IC | Thời hạn: 7 ngày', string.format("%d", Config.RentalPrice)), 'success', 5000)
    else
        no:Notify('[Điện gió] Đã thuê trạm điện gió MIỄN PHÍ! Thời hạn: 7 ngày', 'success', 5000)
    end
    
    CloseUI()
    Wait(500)
    OpenMainUI()
end)

RegisterNetEvent('windturbine:startDutySuccess')
AddEventHandler('windturbine:startDutySuccess', function(serverData)
    -- SECURITY FIX: Nhận dữ liệu từ server
    if serverData then
        playerData.systems = serverData.systems
        playerData.earningsPool = serverData.earningsPool
        playerData.currentFuel = serverData.currentFuel
    end
    
    playerData.onDuty = true
    playerData.workStartTime = GetCurrentTime()
    playerData.lastEarning = GetCurrentTime()
    playerData.lastPenalty = GetCurrentTime()
    playerData.lastFuelConsumption = GetCurrentTime()
    
    isOnDuty = true
    currentSystems = playerData.systems
    currentEfficiency = CalculateEfficiency()
    currentEarnings = playerData.earningsPool
    
    SendNUIMessage({
        action = 'updateEarningsPool',
        earnings = currentEarnings
    })
    SendNUIMessage({
        action = 'updateWorkTime',
        workHours = 0,
        maxHours = Config.MaxDailyHours
    })
    SendNUIMessage({
        action = 'updateFuel',
        currentFuel = playerData.currentFuel,
        maxFuel = Config.MaxFuel
    })
    
    -- Update UI (systems, efficiency, earningRate)
    UpdateUI()
    
    no:Notify('✅ Đã bắt đầu ca làm việc tại cối xay gió!', 'success', 3000)
    PlaySound(-1, "CHECKPOINT_PERFECT", "HUD_MINI_GAME_SOUNDSET", 0, 0, 1)
    
    -- Gửi tin nhắn chào mừng qua lb-phone
    local actualEarningRate = CalculateSystemProfit() * 4
    TriggerServerEvent('windturbine:sendPhoneNotification', 'welcome', {
        systems = playerData.systems,
        earningRate = actualEarningRate
    })
end)

RegisterNetEvent('windturbine:startDutyFailed')
AddEventHandler('windturbine:startDutyFailed', function(reason)
    if reason == 'DAILY_LIMIT' then
        no:Notify('❌ Đã đạt giới hạn 12 giờ/ngày! Hãy quay lại sau 6:00 sáng.', 'error', 5000)
        SendNUIMessage({
            action = 'workLimitReached'
        })
    else
        no:Notify('❌ Không thể bắt đầu ca làm việc!', 'error', 5000)
    end
end)

RegisterNetEvent('windturbine:withdrawSuccess')
AddEventHandler('windturbine:withdrawSuccess', function(amount, isGracePeriod)
    -- Xử lý theo loại rút tiền
    if isGracePeriod then
        -- Rút tiền grace period: Reset TOÀN BỘ dữ liệu player
        playerData = {
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
            lastFuelConsumption = 0,
            workStartTime = 0,
            totalWorkHours = 0,
            dailyWorkHours = 0,
            lastDayReset = GetCurrentDay(),
            currentFuel = 0
        }
        
        -- Reset các biến global
        isOnDuty = false
        currentSystems = playerData.systems
        currentEfficiency = 0
        currentEarnings = 0
        
        -- Đóng UI
        CloseUI()
        no:Notify('✅ Đã rút tiền thành công! Trạm đã được reset.', 'success', 5000)
    else
        -- Rút tiền bình thường: Chỉ reset earnings
        playerData.earningsPool = 0
        currentEarnings = 0
        
        SendNUIMessage({
            action = 'updateEarnings',
            earnings = 0
        })
        
        -- Giữ UI mở
        no:Notify(string.format('💰 Đã rút $%d từ quỹ tiền lương!', amount), 'success')
    end
end)

RegisterNetEvent('windturbine:refuelSuccess')
AddEventHandler('windturbine:refuelSuccess', function(fuelAdded, newFuelTotal)
    -- SECURITY FIX: Nhận fuel từ server
    playerData.currentFuel = newFuelTotal
    
    no:Notify(string.format('⛽ Đã đổ %d giờ xăng! Tổng: %d/%d giờ', fuelAdded, playerData.currentFuel, Config.MaxFuel), 'success', 5000)
    PlaySound(-1, "PICK_UP", "HUD_FRONTEND_DEFAULT_SOUNDSET", 0, 0, 1)
    
    -- Cập nhật UI ngay lập tức với giá trị xăng mới
    SendNUIMessage({
        action = 'updateFuel',
        currentFuel = playerData.currentFuel,
        maxFuel = Config.MaxFuel
    })
    
    -- Refresh UI
    Wait(300)
    OpenMainUI()
end)

RegisterNetEvent('windturbine:gracePeriodExpired')
AddEventHandler('windturbine:gracePeriodExpired', function()
    -- Reset TOÀN BỘ dữ liệu player
    playerData = {
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
        lastFuelConsumption = 0,
        workStartTime = 0,
        totalWorkHours = 0,
        dailyWorkHours = 0,
        lastDayReset = GetCurrentDay(),
        currentFuel = 0
    }
    
    -- Reset các biến global
    isOnDuty = false
    currentSystems = playerData.systems
    currentEfficiency = 0
    currentEarnings = 0
    
    -- Đóng UI nếu đang mở
    CloseUI()
end)

RegisterNetEvent('windturbine:updateEarnings')
AddEventHandler('windturbine:updateEarnings', function(newEarnings)
    playerData.earningsPool = newEarnings
    currentEarnings = newEarnings
    
    SendNUIMessage({
        action = 'updateEarnings',
        earnings = currentEarnings
    })
end)

RegisterNetEvent('windturbine:updateSystems')
AddEventHandler('windturbine:updateSystems', function(newSystems)
    playerData.systems = newSystems
    currentSystems = newSystems
    currentEfficiency = CalculateEfficiency()
    
    SendNUIMessage({
        action = 'updateSystems',
        systems = currentSystems
    })
    SendNUIMessage({
        action = 'updateEfficiency',
        efficiency = currentEfficiency
    })
end)

RegisterNetEvent('windturbine:updateFuel')
AddEventHandler('windturbine:updateFuel', function(newFuel)
    playerData.currentFuel = newFuel
    
    SendNUIMessage({
        action = 'updateFuel',
        currentFuel = playerData.currentFuel,
        maxFuel = Config.MaxFuel
    })
    
    if newFuel == 10 then
        no:Notify('⚠️ Cảnh báo: Còn 10 giờ xăng!', 'error', 5000)
    elseif newFuel == 5 then
        no:Notify('🚨 Khẩn cấp: Còn 5 giờ xăng!', 'error', 5000)
    end
end)

RegisterNetEvent('windturbine:outOfFuel')
AddEventHandler('windturbine:outOfFuel', function()
    playerData.onDuty = false
    isOnDuty = false
    
    no:Notify('⛽ Hết xăng! Máy đã dừng hoạt động.', 'error', 7000)
    
    SendNUIMessage({
        action = 'outOfFuel'
    })
    
    TriggerServerEvent('windturbine:sendPhoneNotification', 'outOfFuel', {})
end)

-- ============================================
-- SECTION 8: BACKGROUND THREADS
-- ============================================

-- Thread: Update work time continuously (every 1 minute)
CreateThread(function()
    while true do
        -- OPTIMIZATION: Chỉ chạy khi cần thiết
        if playerData.onDuty and not rentalStatus.isGracePeriod then
            Wait(60000) -- Cập nhật mỗi 1 phút
            
            local currentTime = GetCurrentTime()
            local currentWorkHours = (currentTime - playerData.workStartTime) / 1000 / 3600
            
            -- Cập nhật UI với thời gian hiện tại
            SendNUIMessage({
                action = 'updateWorkTime',
                workHours = currentWorkHours,
                maxHours = Config.MaxDailyHours
            })
        else
            Wait(60000) -- Khi không làm việc, cũng check mỗi 1 phút
        end
    end
end)

-- Thread: Check daily limit (every 1 minute)
CreateThread(function()
    while true do
        Wait(60000) -- Check mỗi 1 phút
        
        if not playerData.onDuty or rentalStatus.isGracePeriod then
            goto continue
        end
        
        -- Tính thời gian còn lại đến giới hạn
        local currentTime = GetCurrentTime()
        local currentWorkHours = (currentTime - playerData.workStartTime) / 1000 / 3600
        local totalDailyHours = playerData.dailyWorkHours + currentWorkHours
        
        -- Kiểm tra nếu vượt quá giới hạn ngày
        if totalDailyHours >= Config.MaxDailyHours then
            playerData.onDuty = false
            isOnDuty = false
            
            TriggerServerEvent('windturbine:stopDuty')
            
            no:Notify('⏰ Đã hết giờ làm việc trong ngày! Ca làm việc tự động kết thúc.', 'error', 5000)
            
            TriggerServerEvent('windturbine:sendPhoneNotification', 'dailyLimit', {
                totalDailyHours = totalDailyHours,
                earningsPool = playerData.earningsPool,
                efficiency = CalculateEfficiency()
            })
            
            SendNUIMessage({
                action = 'resetToInitialState'
            })
            CloseUI()
        end
        
        ::continue::
    end
end)

-- Thread: Check distance from turbine
CreateThread(function()
    local lastWarningTime = 0
    
    while true do
        Wait(1000)
        
        if isOnDuty and currentTurbineData then
            local playerPed = PlayerPedId()
            local playerCoords = GetEntityCoords(playerPed)
            local turbineCoords = currentTurbineData.coords
            local distance = #(playerCoords - vector3(turbineCoords.x, turbineCoords.y, turbineCoords.z))
            
            isNearTurbine = distance < 5.0
            
            -- Cảnh báo khi rời xa trong khi đang làm việc
            if distance > 50.0 then
                local currentTime = GetGameTimer()
                if currentTime - lastWarningTime > 30000 then
                    no:Notify('⚠️ Bạn đang rời xa cối xay gió! Ca làm việc vẫn tiếp tục.', 'error', 5000)
                    lastWarningTime = currentTime
                end
            end
        end
    end
end)

-- Thread: Main turbine handler (OPTIMIZATION: All turbines in one thread)
CreateThread(function()
    -- Load rental status ban đầu cho tất cả trạm
    local turbineStates = {}
    
    for _, turbineData in ipairs(Config.TurbineLocations) do
        local tId = turbineData.id
        local initialState = GlobalState['turbine_' .. tId]
        
        turbineStates[tId] = {
            isRented = false,
            isOwner = false,
            ownerName = nil,
            expiryTime = nil,
            withdrawDeadline = nil,
            isGracePeriod = false
        }
        
        if initialState and initialState.isRented then
            local Player = QBCore.Functions.GetPlayerData()
            local isOwner = initialState.isRented and Player.citizenid == initialState.citizenid
            
            turbineStates[tId].isRented = initialState.isRented
            turbineStates[tId].isOwner = isOwner
            turbineStates[tId].ownerName = initialState.ownerName
            turbineStates[tId].expiryTime = initialState.expiryTime
            turbineStates[tId].withdrawDeadline = initialState.withdrawDeadline
            turbineStates[tId].isGracePeriod = initialState.isGracePeriod or false
        end
        
        -- StateBag handler cho từng trạm (chỉ đăng ký 1 lần)
        AddStateBagChangeHandler('turbine_' .. tId, 'global', function(bagName, key, value)
            local localRentalStatus = turbineStates[tId]
            local wasGracePeriod = localRentalStatus.isGracePeriod
            local wasOwner = localRentalStatus.isOwner
            
            if value then
                -- RACE CONDITION FIX: Kiểm tra Player trước khi truy cập
                local Player = QBCore.Functions.GetPlayerData()
                if not Player or not Player.citizenid then
                    -- Player chưa load xong, bỏ qua update này
                    return
                end
                
                local isOwner = (value.isRented and Player.citizenid == value.citizenid) or 
                               (value.isGracePeriod and Player.citizenid == value.citizenid)
                
                local newIsGracePeriod = value.isGracePeriod or false
                
                localRentalStatus.isRented = value.isRented
                localRentalStatus.isOwner = isOwner
                localRentalStatus.ownerName = value.ownerName
                localRentalStatus.expiryTime = value.expiryTime
                localRentalStatus.withdrawDeadline = value.withdrawDeadline
                localRentalStatus.isGracePeriod = newIsGracePeriod
                
                -- Nếu đang làm việc ở trạm này và chuyển sang grace period
                if turbineId == tId and not wasGracePeriod and newIsGracePeriod and isOwner then
                    if playerData.onDuty then
                        local workDuration = (GetCurrentTime() - playerData.workStartTime) / 1000 / 3600
                        playerData.dailyWorkHours = playerData.dailyWorkHours + workDuration
                        playerData.onDuty = false
                        isOnDuty = false
                        
                        -- Gửi work duration lên server
                        TriggerServerEvent('windturbine:stopDuty', workDuration)
                    end
                    
                    SetNuiFocus(false, false)
                    SendNUIMessage({
                        action = 'hideUI'
                    })
                    
                    no:Notify('⏰ Thời hạn thuê đã hết! Bạn có 4 giờ để rút tiền.', 'error', 7000)
                end
                
                -- Cập nhật rentalStatus global nếu đây là trạm hiện tại
                if turbineId == tId then
                    rentalStatus = localRentalStatus
                end
            else
                localRentalStatus.isRented = false
                localRentalStatus.isOwner = false
                localRentalStatus.ownerName = nil
                localRentalStatus.expiryTime = nil
                localRentalStatus.withdrawDeadline = nil
                localRentalStatus.isGracePeriod = false
                
                if turbineId == tId and wasOwner then
                    SetNuiFocus(false, false)
                    SendNUIMessage({
                        action = 'hideUI'
                    })
                    rentalStatus = localRentalStatus
                end
            end
        end)
    end
    
    while true do
        local sleep = 1000
        local playerPed = PlayerPedId()
        local playerCoords = GetEntityCoords(playerPed)
        local nearestDist = 999999
        local nearestTurbine = nil
        
        for _, turbineData in ipairs(Config.TurbineLocations) do
            local coords = turbineData.coords
            local dist = #(playerCoords - vector3(coords.x, coords.y, coords.z))
            
            if dist < nearestDist then
                nearestDist = dist
                nearestTurbine = turbineData
            end
        end
        
        if nearestTurbine and nearestDist < 10.0 then
            local turbineData = nearestTurbine
            local tId = turbineData.id
            local coords = turbineData.coords
            local tName = turbineData.name
            local localRentalStatus = turbineStates[tId]
            
            if nearestDist < 3.0 then
                sleep = 0
                
                local displayText = ""  
                
                if not localRentalStatus.isRented then
                    displayText = string.format("~g~[E]~w~ Thuê %s", tName)
                elseif localRentalStatus.isOwner then
                    if not isOnDuty then
                        displayText = "~g~[E]~w~ Bắt đầu ca làm việc"
                    else
                        displayText = "~g~[E]~w~ Mở bảng điều khiển"
                    end
                else
                    displayText = "~r~Trạm đã có chủ sở hữu"
                end

                DrawText3D(coords.x, coords.y, coords.z + 0.5, displayText)

                if IsControlJustReleased(0, 38) then
                    turbineId = tId
                    currentTurbineData = turbineData
                    rentalStatus = localRentalStatus
                    OpenMainUI()
                end
            end
        end
        
        Wait(sleep)
    end
end)
