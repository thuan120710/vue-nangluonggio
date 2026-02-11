QBCore = exports['qb-core']:GetCoreObject()
local no = exports['f17notify']

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
    lastFuelConsumption = 0,
    workStartTime = 0,
    totalWorkHours = 0,
    dailyWorkHours = 0,
    lastDayReset = "",
    currentFuel = 0 -- Bắt đầu với 0% xăng, phải đổ 4 can mới hoạt động
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
    -- Hiện lại HUD khi đóng UI
    if exports['f17-hudv2'] and exports['f17-hudv2'].toggleHud then
        exports['f17-hudv2']:toggleHud(true)
    end
end

-- Mở UI thuê trạm (Định nghĩa TRƯỚC OpenMainUI)
local function OpenRentalUI()
    -- Ẩn HUD khi mở UI
    if exports['f17-hudv2'] and exports['f17-hudv2'].toggleHud then
        exports['f17-hudv2']:toggleHud(false)
    end
    
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

-- Mở UI rút tiền khi hết hạn (grace period)
local function OpenExpiryWithdrawUI()
    -- Ẩn HUD khi mở UI
    if exports['f17-hudv2'] and exports['f17-hudv2'].toggleHud then
        exports['f17-hudv2']:toggleHud(false)
    end
    
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
        no:Notify('❌ Trạm này đã có người thuê!', 'error', 5000)
        return
    end
    
    -- Ẩn HUD khi mở UI
    if exports['f17-hudv2'] and exports['f17-hudv2'].toggleHud then
        exports['f17-hudv2']:toggleHud(false)
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
        maxHours = Config.MaxDailyHours,
        currentFuel = playerData.currentFuel,
        maxFuel = Config.MaxFuel
    })
end

-- Mở minigame
local function OpenMinigame(system)
    local settings = Config.MinigameSettings[system]
    if not settings then return end
    
    -- Ẩn HUD khi mở minigame
    if exports['f17-hudv2'] and exports['f17-hudv2'].toggleHud then
        exports['f17-hudv2']:toggleHud(false)
    end
    
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
        isGracePeriod = false
    }
end)

-- ============================================
-- LOGIC FUNCTIONS (Chuyển từ server)
-- ============================================

-- Tính hiệu suất tổng (trung bình 5 chỉ số)
-- Nếu hệ thống <= 30% thì coi như 0%
local function CalculateEfficiency()
    local systems = playerData.systems
    local total = 0
    
    for _, value in pairs(systems) do
        if value <= 30 then
            total = total + 0 -- Coi như 0%
        else
            total = total + value
        end
    end
    
    return total / 5
end

-- Tính lợi nhuận dựa trên từng chỉ số (mỗi chỉ số = 20% lợi nhuận)
-- Nếu hệ thống <= 30% thì không sinh tiền (coi như 0%)
local function CalculateSystemProfit()
    local systems = playerData.systems
    local totalProfit = 0
    
    for systemName, value in pairs(systems) do
        local systemProfit = Config.BaseSalary * (Config.SystemProfitContribution / 100)
        
        -- Nếu <= 30% thì không sinh tiền
        if value <= 30 then
            systemProfit = 0
        else
            -- Từ 31% trở lên: tính theo tỷ lệ thực tế
            systemProfit = systemProfit * (value / 100)
        end
        
        totalProfit = totalProfit + systemProfit
    end
    
    return totalProfit
end

-- Kiểm tra điều kiện sinh tiền (nếu 3 chỉ số <= 30% hoặc hết xăng => máy ngừng hoạt động)
local function CanEarnMoney()
    -- Kiểm tra xăng trước
    if playerData.currentFuel <= 0 then
        return false, "OUT_OF_FUEL"
    end
    
    local systems = playerData.systems
    local below30 = 0
    
    for _, value in pairs(systems) do
        if value <= 30 then below30 = below30 + 1 end
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

-- Helper: Cập nhật UI (gộp logic trùng lặp)
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

-- Helper: Tắt duty (gộp logic trùng lặp)
local function StopDuty()
    if playerData.onDuty then
        local workDuration = (GetCurrentTime() - playerData.workStartTime) / 1000 / 3600
        playerData.dailyWorkHours = playerData.dailyWorkHours + workDuration
        playerData.onDuty = false
        isOnDuty = false
        
        -- Gửi work duration lên server để cập nhật
        TriggerServerEvent('windturbine:stopDuty', workDuration)
    end
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
        no:Notify('✅ May mắn! Không có hư hỏng nào xảy ra!', 'success', 3000)
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
    
    -- Lọc ra các hệ thống còn > 30%
    local availableSystems = {}
    for _, systemName in ipairs(systemNames) do
        if playerData.systems[systemName] > 30 then
            table.insert(availableSystems, systemName)
        end
    end
    
    -- Nếu không còn hệ thống nào > 30%, không áp dụng penalty
    if #availableSystems == 0 then
        no:Notify('⚠️ Tất cả hệ thống đã ở mức nguy hiểm! Không thể hư hỏng thêm.', 'error', 3000)
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
        -- Đảm bảo không giảm xuống dưới 0%
        local afterValue = math.max(0, beforeValue - selectedPenalty.damage)
        playerData.systems[systemName] = afterValue
        
        table.insert(affectedSystems, systemName)
        table.insert(systemDetails, string.format('%s: %d%% → %d%%', systemDisplayNames[systemName], beforeValue, afterValue))
    end
    
    -- Thông báo chi tiết
    local detailsText = table.concat(systemDetails, ' | ')
    no:Notify(
        string.format('⚠️ Cảnh báo hư hỏng! Giảm %d%%: %s', selectedPenalty.damage, detailsText), 
        'error', 7000)
    
    -- Gửi cảnh báo penalty qua lb-phone
    TriggerServerEvent('windturbine:sendPhoneNotification', 'penalty', {
        workHours = workHours,
        numSystems = numSystems,
        damage = selectedPenalty.damage,
        systemDetails = systemDetails
    })
    
    -- Update UI
    UpdateUI()
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
    -- Không cho phép bật duty khi đang grace period
    if rentalStatus.isGracePeriod then
        no:Notify('❌ Không thể làm việc trong thời gian grace period!', 'error', 5000)
        cb('ok')
        return
    end
    
    -- Kiểm tra xăng tối thiểu
    -- Nếu hết xăng hoàn toàn (0 fuel), cần đổ 4 can (100 fuel)
    -- Nếu còn xăng, chỉ cần > 0 là được
    if playerData.currentFuel == 0 then
        no:Notify(string.format('❌ Hết xăng! Cần đổ %d can xăng  để khởi động lại máy.', math.ceil(Config.MinFuelToStart / Config.FuelPerJerrycan)), 'error', 7000)
        cb('ok')
        return
    elseif playerData.currentFuel < Config.MinFuelToStart and playerData.currentFuel > 0 then
        -- Nếu còn xăng nhưng chưa đủ 100, vẫn cho chạy (để tiêu hao hết)
        -- Không block
    end
    
    -- Kiểm tra giới hạn thời gian
    local canWork, reason = CheckTimeLimit()
    if not canWork then
        if reason == "DAILY_LIMIT" then
            no:Notify('❌ Đã đạt giới hạn 12 giờ/ngày! Hãy quay lại sau 6:00 sáng.', 'error', 5000)
            SendNUIMessage({
                action = 'workLimitReached'
            })
        end
        cb('ok')
        return
    end
    
    -- Trigger server validation trước khi start duty
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
    
    -- Update UI
    UpdateUI()
    
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
    -- Kiểm tra có jerrycan không
    QBCore.Functions.TriggerCallback('windturbine:hasJerrycan', function(hasItem)
        if not hasItem then
            no:Notify('❌ Bạn không có can xăng (Jerrycan)!', 'error', 5000)
            cb('ok')
            return
        end
        
        -- Kiểm tra xăng đã đầy chưa
        if playerData.currentFuel >= Config.MaxFuel then
            no:Notify('❌ Bình xăng đã đầy!', 'error', 3000)
            cb('ok')
            return
        end
        
        -- Nếu đang ở trạng thái hết xăng (0 fuel), cần đổ đủ 4 can
        if playerData.currentFuel == 0 then
            -- Kiểm tra số lượng jerrycan
            QBCore.Functions.TriggerCallback('windturbine:getJerrycanCount', function(count)
                local cansNeeded = math.ceil(Config.MinFuelToStart / Config.FuelPerJerrycan)
                
                if count < cansNeeded then
                    no:Notify(string.format('❌ Cần %d can xăng để khởi động lại! (Bạn có: %d can)', cansNeeded, count), 'error', 7000)
                    cb('ok')
                    return
                end
                
                -- Đổ đủ 4 can
                TriggerServerEvent('windturbine:useMultipleJerrycans', cansNeeded, Config.MinFuelToStart)
                cb('ok')
            end)
        else
            -- Đổ bình thường (1 can)
            local fuelNeeded = Config.MaxFuel - playerData.currentFuel
            local fuelToAdd = math.min(Config.FuelPerJerrycan, fuelNeeded)
            
            TriggerServerEvent('windturbine:useJerrycan', fuelToAdd)
            cb('ok')
        end
    end)
end)

RegisterNUICallback('withdrawEarnings', function(data, cb)
    local amount = math.floor(playerData.earningsPool)
    
    if amount <= 0 then
        no:Notify('❌ Không có tiền để rút!', 'error')
        cb('ok')
        return
    end
    
    -- Kiểm tra xem có phải rút tiền grace period không
    local isGracePeriod = data.isGracePeriod or false
    
    -- Tính thời gian làm việc hiện tại để gửi lên server validation
    local currentWorkHours = 0
    if playerData.onDuty and playerData.workStartTime > 0 then
        currentWorkHours = (GetCurrentTime() - playerData.workStartTime) / 1000 / 3600
    end
    
    -- Gửi request lên server (server sẽ validate và trả về event để reset earnings pool)
    TriggerServerEvent('windturbine:withdrawEarnings', amount, isGracePeriod, turbineId, currentWorkHours)
    
    PlaySound(-1, "PICK_UP", "HUD_FRONTEND_DEFAULT_SOUNDSET", 0, 0, 1)
    cb('ok')
end)

-- NUI Callback: Thuê trạm
RegisterNUICallback('rentTurbine', function(data, cb)
    local rentalPrice = Config.RentalPrice or 0
    
    -- Kiểm tra trạng thái hiện tại (StateBag đã tự động cập nhật)
    if rentalStatus.isRented and not rentalStatus.isOwner then
        no:Notify('❌ Trạm này đã có người thuê!', 'error', 5000)
        cb('ok')
        return
    end
    
    -- Gửi request lên server để thuê (server sẽ kiểm tra lần nữa)
    TriggerServerEvent('windturbine:rentTurbine', turbineId, rentalPrice)
    cb('ok')
end)

-- NUI Callback: Kiểm tra số tiền trước khi thuê
RegisterNUICallback('checkMoneyForRent', function(data, cb)
    local rentalPrice = data.rentalPrice or Config.RentalPrice or 0
    
    QBCore.Functions.TriggerCallback('windturbine:checkMoney', function(result)
        cb(result)
    end, rentalPrice)
end)

-- Server Events
RegisterNetEvent('windturbine:notify')
AddEventHandler('windturbine:notify', function(message, type, duration)
    no:Notify(message, type, duration)
end)

RegisterNetEvent('windturbine:rentSuccess')
AddEventHandler('windturbine:rentSuccess', function(data)
    -- StateBag sẽ tự động cập nhật rentalStatus, không cần làm gì thêm
    
    -- Thông báo thành công
    if Config.RentalPrice > 0 then
        no:Notify(
            string.format('✅ Đã thuê trạm điện gió! Giá: $%s IC | Thời hạn: 7 ngày', 
                string.format("%d", Config.RentalPrice)), 
            'success', 5000)
    else
        no:Notify('✅ Đã thuê trạm điện gió MIỄN PHÍ! Thời hạn: 7 ngày', 'success', 5000)
    end
    
    -- Đóng UI thuê và mở UI làm việc
    CloseUI()
    Wait(500)
    OpenMainUI()
end)

-- RegisterNetEvent('windturbine:rentFailed')
-- AddEventHandler('windturbine:rentFailed', function()
--     -- StateBag đã tự động cập nhật, không cần làm gì
--     no:Notify('❌ Không thể thuê trạm này!', 'error', 3000)
-- end)

RegisterNetEvent('windturbine:startDutySuccess')
AddEventHandler('windturbine:startDutySuccess', function()
    -- Server đã validate, bây giờ mới thực sự start duty
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
AddEventHandler('windturbine:refuelSuccess', function(fuelAdded)
    playerData.currentFuel = playerData.currentFuel + fuelAdded
    
    no:Notify(string.format('⛽ Đã đổ %d giờ xăng! Tổng: %d/%d giờ', fuelAdded, playerData.currentFuel, Config.MaxFuel), 'success', 5000)
    PlaySound(-1, "PICK_UP", "HUD_FRONTEND_DEFAULT_SOUNDSET", 0, 0, 1)
    
    -- Cập nhật UI ngay lập tức với giá trị xăng mới
    SendNUIMessage({
        action = 'updateFuel',
        currentFuel = playerData.currentFuel,
        maxFuel = Config.MaxFuel
    })
    
    -- Nếu UI đang mở, refresh lại để hiển thị bar xăng đầy
    -- Nếu UI chưa mở, mở UI để người chơi thấy kết quả
    Wait(300)
    OpenMainUI()
end)

-- Event: Grace period hết hạn - Reset toàn bộ data
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

-- Thread: Cập nhật thời gian làm việc liên tục (OPTIMIZATION: 1 phút/lần)
CreateThread(function()
    while true do
        -- OPTIMIZATION: Chỉ chạy khi cần thiết
        if playerData.onDuty and not rentalStatus.isGracePeriod then
            Wait(60000) -- Cập nhật mỗi 1 phút (đủ chính xác cho thời gian tính bằng giờ)
            
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

-- Thread: Sinh tiền và penalty (Tối ưu hóa adaptive)
CreateThread(function()
    while true do
        -- OPTIMIZATION: Chỉ check khi onDuty, adaptive wait time dựa trên thời gian còn lại
        if not playerData.onDuty or rentalStatus.isGracePeriod then
            Wait(10000) -- Wait 10s khi không làm việc
            goto continue
        end
        
        -- Tính thời gian còn lại đến giới hạn
        local currentTime = GetCurrentTime()
        local currentWorkHours = (currentTime - playerData.workStartTime) / 1000 / 3600
        local totalDailyHours = playerData.dailyWorkHours + currentWorkHours
        local hoursRemaining = Config.MaxDailyHours - totalDailyHours
        
        -- ADAPTIVE WAIT: Điều chỉnh tần suất check dựa trên thời gian còn lại
        local waitTime
        if hoursRemaining <= 0.1 then -- Còn < 6 phút (0.1 giờ)
            waitTime = 2000 -- Check mỗi 2 giây (rất gần giới hạn)
        elseif hoursRemaining <= 0.5 then -- Còn < 30 phút
            waitTime = 5000 -- Check mỗi 5 giây
        elseif hoursRemaining <= 1 then -- Còn < 1 giờ
            waitTime = 10000 -- Check mỗi 10 giây
        elseif hoursRemaining <= 2 then -- Còn < 2 giờ
            waitTime = 30000 -- Check mỗi 30 giây
        else
            waitTime = 60000 -- Check mỗi 1 phút (còn nhiều thời gian)
        end
        
        Wait(waitTime)
        
        -- Cập nhật lại thời gian sau khi wait
        currentTime = GetCurrentTime()
        currentWorkHours = (currentTime - playerData.workStartTime) / 1000 / 3600
        playerData.totalWorkHours = currentWorkHours
        
        -- Kiểm tra giới hạn thời gian (bao gồm cả thời gian ca hiện tại)
        totalDailyHours = playerData.dailyWorkHours + currentWorkHours
        
        -- Kiểm tra nếu vượt quá giới hạn ngày
        if totalDailyHours >= Config.MaxDailyHours then
            -- Tự động kết thúc ca khi hết giờ
            local workDuration = currentWorkHours
            playerData.dailyWorkHours = totalDailyHours
            playerData.onDuty = false
            isOnDuty = false
            
            -- Gửi work duration lên server
            TriggerServerEvent('windturbine:stopDuty', workDuration)
            
            no:Notify('⏰ Đã hết giờ làm việc trong ngày! Ca làm việc tự động kết thúc.', 'error', 5000)
            
            -- Gửi báo cáo ca làm việc qua lb-phone
            TriggerServerEvent('windturbine:sendPhoneNotification', 'dailyLimit', {
                totalDailyHours = totalDailyHours,
                earningsPool = playerData.earningsPool,
                efficiency = CalculateEfficiency()
            })
            
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
                        no:Notify(string.format('💵 +$%d IC | Hiệu suất tuyệt vời!', math.floor(earnings)), 'success', 2000)
                        
                        -- Gửi tin nhắn khen thưởng qua lb-phone (chỉ khi hiệu suất cao)
                        TriggerServerEvent('windturbine:sendPhoneNotification', 'bonus', {
                            earnings = earnings,
                            efficiency = efficiency,
                            earningsPool = playerData.earningsPool
                        })
                    elseif efficiency >= 50 then
                        no:Notify(string.format('💵 +$%d IC', math.floor(earnings)), 'primary', 2000)
                    end
                end
            else
                -- Máy ngừng hoạt động - TẮT DUTY NHƯNG GIỮ UI
                if status == "STOPPED" then
                    -- Máy vẫn chạy nhưng không sinh tiền (3 chỉ số <= 30%)
                    -- KHÔNG tắt duty, chỉ bỏ qua chu kỳ sinh tiền này
                    
                    -- Thông báo 1 lần duy nhất (tránh spam)
                    if currentTime - lastNotifyTime > 60000 then -- Chỉ thông báo mỗi 1 phút
                        no:Notify('🚨 Cảnh báo: 3 chỉ số <= 30%! Không sinh tiền. Hãy sửa chữa!', 'error', 5000)
                        lastNotifyTime = currentTime
                    end
                    
                    playerData.lastEarning = currentTime
                elseif status == "OUT_OF_FUEL" then
                    -- Hết xăng - logic xử lý ở phần fuel consumption
                    playerData.lastEarning = currentTime
                end
            end
        end
        
        -- Áp dụng penalty mỗi giờ (CHỈ CÓ PENALTY, KHÔNG CÓ DEGRADE TỰ NHIÊN)
        -- KHÔNG áp dụng penalty khi máy ngừng hoạt động (3 chỉ số <= 30% hoặc hết xăng)
        if currentTime - playerData.lastPenalty >= Config.PenaltyCycle then
            local canEarn, status = CanEarnMoney()
            
            -- Chỉ áp dụng penalty khi máy đang hoạt động bình thường
            if canEarn then
                ApplyPenalty()
            end
            
            playerData.lastPenalty = currentTime
        end
        
        -- Tiêu hao xăng mỗi chu kỳ (KHI ĐANG HOẠT ĐỘNG - kể cả khi hư hỏng)
        if currentTime - playerData.lastFuelConsumption >= Config.FuelConsumptionCycle then
            -- Tiêu hao xăng khi máy đang chạy (onDuty = true), kể cả khi 3 chỉ số <= 30%
            if playerData.onDuty and playerData.currentFuel > 0 then
                playerData.currentFuel = playerData.currentFuel - 1
                
                -- Cập nhật UI
                SendNUIMessage({
                    action = 'updateFuel',
                    currentFuel = playerData.currentFuel,
                    maxFuel = Config.MaxFuel
                })
                
                -- Cảnh báo khi sắp hết xăng
                if playerData.currentFuel == 10 then
                    no:Notify('⚠️ Cảnh báo: Còn 10 giờ xăng!', 'error', 5000)
                elseif playerData.currentFuel == 5 then
                    no:Notify('🚨 Khẩn cấp: Còn 5 giờ xăng!', 'error', 5000)
                elseif playerData.currentFuel == 0 then
                    -- Hết xăng -> Tắt máy
                    playerData.onDuty = false
                    isOnDuty = false
                    
                    no:Notify('⛽ Hết xăng! Máy đã dừng hoạt động.', 'error', 7000)
                    
                    SendNUIMessage({
                        action = 'outOfFuel'
                    })
                    
                    -- Gửi thông báo qua phone
                    TriggerServerEvent('windturbine:sendPhoneNotification', 'outOfFuel', {})
                end
            end
            
            playerData.lastFuelConsumption = currentTime
        end
        
        ::continue::
    end
end)

-- Thread: Kiểm tra khoảng cách (hỗ trợ nhiều trạm)
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

local turbineObjects = {}

-- Hàm khởi tạo Objects cho TẤT CẢ các trạm
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

-- OPTIMIZATION FIX: Gộp tất cả trạm vào 1 thread duy nhất thay vì 5 threads riêng biệt
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
    
    -- OPTIMIZATION FIX: Vòng lặp chính xử lý TẤT CẢ trạm trong 1 thread
    while true do
        local sleep = 500 -- OPTIMIZATION: Tăng sleep mặc định từ 1000 lên 500ms để responsive hơn
        local playerPed = PlayerPedId()
        local playerCoords = GetEntityCoords(playerPed)
        local nearestDist = 999999
        local nearestTurbine = nil
        
        -- Tìm trạm gần nhất
        for _, turbineData in ipairs(Config.TurbineLocations) do
            local coords = turbineData.coords
            local dist = #(playerCoords - vector3(coords.x, coords.y, coords.z))
            
            if dist < nearestDist then
                nearestDist = dist
                nearestTurbine = turbineData
            end
        end
        
        -- Chỉ xử lý trạm gần nhất nếu trong phạm vi 10m
        if nearestTurbine and nearestDist < 10.0 then
            local turbineData = nearestTurbine
            local tId = turbineData.id
            local coords = turbineData.coords
            local tName = turbineData.name
            local localRentalStatus = turbineStates[tId]
            
            -- OPTIMIZATION FIX: Chỉ vẽ text khi < 3m, nhưng sleep = 5 thay vì 0
            if nearestDist < 3.0 then
                sleep = 5 -- CRITICAL FIX: Thay vì Wait(0), dùng Wait(5) để giảm CPU usage
                
                local displayText = ""
                
                if not localRentalStatus.isRented then
                    displayText = string.format("[~g~E~w~] Thuê %s", tName)
                elseif localRentalStatus.isOwner then
                    if not isOnDuty then
                        displayText = "[~g~E~w~] Bắt đầu ca làm việc"
                    else
                        displayText = "[~g~E~w~] Mở bảng điều khiển"
                    end
                else
                    displayText = "~r~Trạm đã có chủ sở hữu"
                end

                -- Vẽ chữ 3D
                DrawText3D(coords.x, coords.y, coords.z + 0.5, displayText)

                -- Kiểm tra bấm phím E
                if IsControlJustReleased(0, 38) then
                    -- Set turbineId và rentalStatus cho trạm này
                    turbineId = tId
                    currentTurbineData = turbineData
                    rentalStatus = localRentalStatus
                    OpenMainUI()
                end
            elseif nearestDist < 10.0 then
                sleep = 200 -- Gần nhưng chưa đủ gần để tương tác
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
