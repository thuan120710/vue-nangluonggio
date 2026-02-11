local TurbineRentals = {}
local TurbineExpiryGracePeriod = {} -- Lưu thời gian grace period (4 giờ để rút tiền)

-- Dữ liệu tracking thời gian làm việc (anti-cheat)
local PlayerWorkData = {} -- [citizenid] = {workStartTime, dailyWorkHours, lastDayReset}

-- SECURITY FIX: Server-side earnings tracking
local PlayerEarnings = {} -- [citizenid] = {earningsPool, systems, lastEarning, lastPenalty, lastFuelConsumption, currentFuel, onDuty}

-- Khởi tạo: Reset GlobalState khi script start
CreateThread(function()
    -- Reset tất cả trạm về trạng thái chưa thuê
    for _, turbineData in ipairs(Config.TurbineLocations) do
        GlobalState['turbine_' .. turbineData.id] = {
            isRented = false,
            ownerName = nil,
            citizenid = nil,
            expiryTime = nil,
            withdrawDeadline = nil,
            isGracePeriod = false
        }
    end
end)

-- Helper: Broadcast rental status qua StateBag (tất cả client tự động nhận - KHÔNG CẦN CHECK LIÊN TỤC!)
local function BroadcastRentalStatus(turbineId)
    local rentalData = TurbineRentals[turbineId]
    local graceData = TurbineExpiryGracePeriod[turbineId]
    
    if rentalData then
        GlobalState['turbine_' .. turbineId] = {
            isRented = true,
            ownerName = rentalData.ownerName,
            citizenid = rentalData.citizenid,
            expiryTime = rentalData.expiryTime,
            withdrawDeadline = nil,
            isGracePeriod = false
        }
    elseif graceData then
        -- Đang trong grace period (4 giờ để rút tiền)
        GlobalState['turbine_' .. turbineId] = {
            isRented = false,
            ownerName = graceData.ownerName,
            citizenid = graceData.citizenid,
            expiryTime = graceData.expiryTime,
            withdrawDeadline = graceData.withdrawDeadline,
            isGracePeriod = true
        }
    else
        GlobalState['turbine_' .. turbineId] = {
            isRented = false,
            ownerName = nil,
            citizenid = nil,
            expiryTime = nil,
            withdrawDeadline = nil,
            isGracePeriod = false
        }
    end
end

-- Helper: Kiểm tra hết hạn
local function CheckRentalExpiry(turbineId)
    local currentTime = os.time()
    
    -- Kiểm tra grace period trước
    if TurbineExpiryGracePeriod[turbineId] then
        local graceData = TurbineExpiryGracePeriod[turbineId]
        
        -- Nếu hết grace period (4 giờ), reset hoàn toàn
        if currentTime >= graceData.withdrawDeadline then
            -- SECURITY FIX: Reset PlayerEarnings khi grace period hết
            if graceData.citizenid and PlayerEarnings[graceData.citizenid] then
                PlayerEarnings[graceData.citizenid] = nil
            end
            
            TurbineExpiryGracePeriod[turbineId] = nil
            BroadcastRentalStatus(turbineId)
            
            -- Thông báo cho owner nếu đang online và trigger reset data
            if graceData.playerId then
                no:Notify(graceData.playerId, '⚠️ Hết thời gian rút tiền! Trạm đã được reset.', 'error', 5000)
                
                -- Trigger event để client reset toàn bộ data
                TriggerClientEvent('windturbine:gracePeriodExpired', graceData.playerId)
            end
            
            return true
        end
        
        return false
    end
    
    -- Kiểm tra rental bình thường
    if not TurbineRentals[turbineId] then return false end
    
    local rentalData = TurbineRentals[turbineId]
    
    -- Nếu hết thời hạn thuê, chuyển sang grace period
    if currentTime >= rentalData.expiryTime then
        -- Chuyển sang grace period
        TurbineExpiryGracePeriod[turbineId] = {
            citizenid = rentalData.citizenid,
            ownerName = rentalData.ownerName,
            playerId = rentalData.playerId,
            expiryTime = rentalData.expiryTime,
            withdrawDeadline = currentTime + Config.GracePeriod
        }
        
        -- Xóa rental data
        TurbineRentals[turbineId] = nil
        
        -- Broadcast
        BroadcastRentalStatus(turbineId)
        
        -- Thông báo cho owner nếu đang online
        if rentalData.playerId then
            local gracePeriodText = Config.TestMode and "30 giây" or "4 giờ"
            no:Notify(rentalData.playerId, string.format('⚠️ Hết thời hạn thuê! Bạn có %s để rút tiền.', gracePeriodText), 'error', 8000)
            
            -- Gửi phone notification
            local phoneNumber = exports["lb-phone"]:GetEquippedPhoneNumber(rentalData.playerId)
            if phoneNumber then
                local expiryMsg = string.format("⚠️ Hết thời hạn thuê Trạm Điện Gió\n\n⏰ Bạn có %s để rút tiền!\n\n💰 Hãy vào trạm và rút tiền ngay.\n\n⚠️ Sau %s, trạm sẽ được reset và bạn sẽ mất toàn bộ tiền chưa rút!", gracePeriodText, gracePeriodText)
                exports['lb-phone']:SendMessage('Trạm Điện Gió', tostring(phoneNumber), expiryMsg, nil, nil, nil)
            end
        end
        
        return true
    end
    
    return false
end

-- Helper: Reset daily work hours nếu qua ngày mới
local function CheckAndResetDailyHours(citizenid)
    local currentDay = GetCurrentDay()
    
    if not PlayerWorkData[citizenid] then
        PlayerWorkData[citizenid] = {
            workStartTime = 0,
            dailyWorkHours = 0,
            lastDayReset = currentDay
        }
        return
    end
    
    -- Reset nếu qua ngày mới (6:00 sáng)
    if PlayerWorkData[citizenid].lastDayReset ~= currentDay then
        PlayerWorkData[citizenid].dailyWorkHours = 0
        PlayerWorkData[citizenid].lastDayReset = currentDay
    end
end

-- SECURITY FIX: Server-side calculation functions
local function CalculateSystemProfit(systems)
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

local function CanEarnMoney(systems, currentFuel)
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

local function InitPlayerEarnings(citizenid)
    if not PlayerEarnings[citizenid] then
        PlayerEarnings[citizenid] = {
            earningsPool = 0,
            systems = {
                stability = Config.InitialSystemValue,
                electric = Config.InitialSystemValue,
                lubrication = Config.InitialSystemValue,
                blades = Config.InitialSystemValue,
                safety = Config.InitialSystemValue
            },
            lastEarning = 0,
            lastPenalty = 0,
            lastFuelConsumption = 0,
            currentFuel = 0,
            onDuty = false
        }
    end
end

-- SECURITY FIX: Event rút tiền - Server tính toán số tiền + VALIDATE TURBINE ID
RegisterNetEvent('windturbine:withdrawEarnings')
AddEventHandler('windturbine:withdrawEarnings', function(isGracePeriod, turbineId)
    local playerId = source
    local Player = QBCore.Functions.GetPlayer(playerId)
    if not Player then return end
    
    local citizenid = Player.PlayerData.citizenid
    InitPlayerEarnings(citizenid)
    
    -- SECURITY: Server tính toán số tiền, KHÔNG tin client
    local amount = math.floor(PlayerEarnings[citizenid].earningsPool)
    
    if amount <= 0 then
        no:Notify(playerId, 'Không có tiền để rút!', 'error', 3000)
        return
    end
    
    if isGracePeriod and turbineId then
        -- SECURITY FIX: Validate turbineId
        local validTurbineId = false
        for _, turbineData in ipairs(Config.TurbineLocations) do
            if turbineData.id == turbineId then
                validTurbineId = true
                break
            end
        end
        
        if not validTurbineId then
            no:Notify(playerId, 'Trạm không hợp lệ!', 'error', 3000)
            return
        end
        
        CheckRentalExpiry(turbineId)
        local graceData = TurbineExpiryGracePeriod[turbineId]
        
        if not graceData then
            no:Notify(playerId, 'Không có tiền để rút!', 'error', 3000)
            return
        end
        
        if graceData.citizenid ~= citizenid then
            no:Notify(playerId, 'Bạn không phải chủ trạm này!', 'error', 3000)
            return
        end
        
        -- Reset trạm và earnings
        TurbineExpiryGracePeriod[turbineId] = nil
        BroadcastRentalStatus(turbineId)
        PlayerEarnings[citizenid] = nil
    else
        -- Rút tiền bình thường - chỉ reset earnings pool
        PlayerEarnings[citizenid].earningsPool = 0
    end
    
    -- Rút tiền
    Player.Functions.AddMoney('tienkhoa', amount)
    TriggerClientEvent('windturbine:withdrawSuccess', playerId, amount, isGracePeriod)
    
    -- Gửi phone notification (PROTECTED: Kiểm tra lb-phone tồn tại)
    local success, phoneNumber = pcall(function()
        return exports["lb-phone"]:GetEquippedPhoneNumber(playerId)
    end)
    
    if success and phoneNumber then
        local withdrawMsg
        if isGracePeriod then
            withdrawMsg = string.format("💰 Rút tiền thành công\n\nSố tiền: $%s IC\nThời gian: %s\n\n✅ Trạm đã được reset. Bạn có thể thuê lại bất cứ lúc nào!", 
                string.format("%d", amount), os.date("%H:%M:%S - %d/%m/%Y"))
        else
            withdrawMsg = string.format("💰 Xác nhận rút tiền\n\nSố tiền: $%s IC\nThời gian: %s\n\nTiền đã được chuyển vào tài khoản IC của bạn. Cảm ơn bạn đã làm việc chăm chỉ!", 
                string.format("%d", amount), os.date("%H:%M:%S - %d/%m/%Y"))
        end
        
        pcall(function()
            exports['lb-phone']:SendMessage('Trạm Điện Gió', tostring(phoneNumber), withdrawMsg, nil, nil, nil)
        end)
    end
end)

-- Event: Thuê trạm (chỉ trừ tiền) - SECURITY FIX: Validate rental price
RegisterNetEvent('windturbine:rentTurbine')
AddEventHandler('windturbine:rentTurbine', function(turbineId, rentalPrice)
    local playerId = source
    local Player = QBCore.Functions.GetPlayer(playerId)

    if not Player then
        TriggerClientEvent('windturbine:rentFailed', playerId)
        return
    end
    
    -- SECURITY FIX: Validate turbineId
    local validTurbineId = false
    for _, turbineData in ipairs(Config.TurbineLocations) do
        if turbineData.id == turbineId then
            validTurbineId = true
            break
        end
    end
    
    if not validTurbineId then
        no:Notify(playerId, 'Trạm không hợp lệ!', 'error', 3000)
        TriggerClientEvent('windturbine:rentFailed', playerId)
        return
    end
    
    local citizenid = Player.PlayerData.citizenid
    
    -- Kiểm tra xem player đã thuê trạm nào chưa
    for tId, rentalData in pairs(TurbineRentals) do
        if rentalData.citizenid == citizenid then
            no:Notify(playerId, 'Bạn đã thuê một trạm khác rồi! Không thể thuê nhiều trạm cùng lúc.', 'error', 3000)
            TriggerClientEvent('windturbine:rentFailed', playerId)
            return
        end
    end
    
    -- Kiểm tra xem player có đang trong grace period của trạm nào không
    for tId, graceData in pairs(TurbineExpiryGracePeriod) do
        if graceData.citizenid == citizenid then
            no:Notify(playerId, 'Bạn cần rút tiền từ trạm cũ trước khi thuê trạm mới!', 'error', 3000)
            TriggerClientEvent('windturbine:rentFailed', playerId)
            return
        end
    end
    
    -- Kiểm tra trạm đã được thuê chưa
    CheckRentalExpiry(turbineId)
    if TurbineRentals[turbineId] then
        local ownerName = TurbineRentals[turbineId].ownerName
        no:Notify(playerId, string.format('❌ Trạm này đã được thuê bởi %s!', ownerName), 'error', 5000)
        TriggerClientEvent('windturbine:rentFailed', playerId)
        return
    end
    
    -- SECURITY FIX: Validate rentalPrice matches Config
    if rentalPrice ~= Config.RentalPrice then
        print(string.format('[CHEAT DETECTED] Player %s tried to rent with price %d instead of %d', citizenid, rentalPrice, Config.RentalPrice))
        no:Notify(playerId, '❌ Lỗi giá thuê!', 'error')
        TriggerClientEvent('windturbine:rentFailed', playerId)
        return
    end
    
    -- Validate rentalPrice type
    if rentalPrice == nil or type(rentalPrice) ~= "number" or rentalPrice < 0 then
        no:Notify(playerId, '❌ Lỗi giá thuê!', 'error')
        TriggerClientEvent('windturbine:rentFailed', playerId)
        return
    end
    
    -- Kiểm tra tiền khóa và bank
    local tienkhoa = Player.Functions.GetMoney('tienkhoa') or 0
    local bank = Player.Functions.GetMoney('bank') or 0
    local totalMoney = tienkhoa + bank
    
    if rentalPrice > 0 and totalMoney < rentalPrice then
        no:Notify(playerId, string.format('Bạn không đủ tiền (Cần $%s IC)', string.format("%d", rentalPrice)), 'error', 7000)
        TriggerClientEvent('windturbine:rentFailed', playerId)
        return
    end
    
    if rentalPrice > 0 then
        if tienkhoa >= rentalPrice then
            Player.Functions.RemoveMoney('tienkhoa', rentalPrice, citizenid..' Thuê trạm điện gió #'..turbineId..' | Tiền khoá')
        else
            local remainingAmount = rentalPrice - tienkhoa
            if tienkhoa > 0 then
                Player.Functions.RemoveMoney('tienkhoa', tienkhoa, citizenid..' Thuê trạm điện gió #'..turbineId..' Lần 1 tiền khoá')
                Wait(100)
                Player.Functions.RemoveMoney('bank', remainingAmount, citizenid..' Thuê trạm điện gió #'..turbineId..' Lần 2 tiền IC')
            else
                Player.Functions.RemoveMoney('bank', remainingAmount, citizenid..' Thuê trạm điện gió #'..turbineId..' | Tiền IC')
            end
        end
    end

    local ownerName = Player.PlayerData.charinfo.firstname .. ' ' .. Player.PlayerData.charinfo.lastname 
    local currentTime = os.time()
    TurbineRentals[turbineId] = {
        citizenid = citizenid,
        ownerName = ownerName,
        playerId = playerId,
        rentalTime = currentTime,
        expiryTime = currentTime + Config.RentalDuration
    }
    
    -- Broadcast qua StateBag - TẤT CẢ 500 CLIENT TỰ ĐỘNG NHẬN (KHÔNG CẦN CHECK!)
    BroadcastRentalStatus(turbineId)
    
    TriggerClientEvent('windturbine:rentSuccess', playerId, {
        citizenid = citizenid,
        ownerName = ownerName,
        expiryTime = TurbineRentals[turbineId].expiryTime
    })
    
    -- Gửi tin nhắn xác nhận qua lb-phone (PROTECTED)
    local success, phoneNumber = pcall(function()
        return exports["lb-phone"]:GetEquippedPhoneNumber(playerId)
    end)
    
    if success and phoneNumber then
        local durationText = Config.TestMode and "60 giây" or "7 ngày"
        local gracePeriodText = Config.TestMode and "30 giây" or "4 giờ"
        local rentalMsg = ""
        if rentalPrice > 0 then
            rentalMsg = string.format("🌬️ Xác nhận thuê Trạm Điện Gió\n\n💰 Giá thuê: $%s IC\n⏰ Thời hạn: %s\n\n✅ Bạn có thể bắt đầu làm việc ngay bây giờ!\n\n⚠️ Lưu ý: Sau khi hết hạn, bạn có %s để rút tiền.", 
                string.format("%d", rentalPrice), durationText, gracePeriodText)
        else
            rentalMsg = string.format("🌬️ Xác nhận thuê Trạm Điện Gió\n\n💰 Giá thuê: MIỄN PHÍ\n⏰ Thời hạn: %s\n\n✅ Bạn có thể bắt đầu làm việc ngay bây giờ!\n\n⚠️ Lưu ý: Sau khi hết hạn, bạn có %s để rút tiền.", durationText, gracePeriodText)
        end
        
        pcall(function()
            exports['lb-phone']:SendMessage('Trạm Điện Gió', tostring(phoneNumber), rentalMsg, nil, nil, nil)
        end)
    end
end)

-- Thread: Tự động kiểm tra expiry (OPTIMIZATION: Tăng interval lên 30 giây thay vì 5 giây)
CreateThread(function()
    while true do
        Wait(30000) -- OPTIMIZATION FIX: Check mỗi 30 giây thay vì 5 giây (vẫn đủ nhanh cho test mode 60s)
        
        -- Kiểm tra tất cả các trạm
        for turbineId, _ in pairs(TurbineRentals) do
            CheckRentalExpiry(turbineId)
        end
        
        -- Kiểm tra grace period
        for turbineId, _ in pairs(TurbineExpiryGracePeriod) do
            CheckRentalExpiry(turbineId)
        end
    end
end)

-- Event: Gửi phone notifications
RegisterNetEvent('windturbine:sendPhoneNotification')
AddEventHandler('windturbine:sendPhoneNotification', function(notifType, data)
    local playerId = source
    local phoneNumber = exports["lb-phone"]:GetEquippedPhoneNumber(playerId)
    
    if not phoneNumber then return end
    
    local message = ""
    
    if notifType == 'welcome' then
        message = string.format("🌬️ Chào mừng đến Trạm Điện Gió!\n\n📊 Trạng thái hệ thống:\n• Độ ổn định: %d%%\n• Hệ thống điện: %d%%\n• Bôi trơn: %d%%\n• Thân tháp: %d%%\n• An toàn: %d%%\n\n💰 Thu nhập dự kiến: $%d IC/giờ\n\nChúc bạn làm việc hiệu quả!", 
            data.systems.stability, data.systems.electric, data.systems.lubrication, 
            data.systems.blades, data.systems.safety, math.floor(data.earningRate))
    
    elseif notifType == 'penalty' then
        local systemDetails = table.concat(data.systemDetails, "\n")
        message = string.format("⚠️ Cảnh báo hư hỏng!\n\nThời gian làm việc: %.1f giờ\nSố hệ thống bị ảnh hưởng: %d\nMức độ hư hỏng: -%d%%\n\nChi tiết:\n%s\n\n� Hãy sửa chữa để duy trì hiệu suất!", 
            data.workHours, data.numSystems, data.damage, systemDetails)
    
    elseif notifType == 'repair' then
        local systemNames = {
            stability = "Độ ổn định",
            electric = "Hệ thống điện",
            lubrication = "Bôi trơn",
            blades = "Thân tháp",
            safety = "An toàn"
        }
        
        local resultEmoji = data.result == 'perfect' and '🌟' or '✅'
        local resultText = data.result == 'perfect' and 'Hoàn hảo' or 'Tốt'
        
        message = string.format("%s Sửa chữa %s!\n\nHệ thống: %s\nKết quả: %s (+%d%%)\nTrước: %d%% → Sau: %d%%\n\n📊 Hiệu suất hiện tại: %.1f%%\n💰 Thu nhập/giờ: $%d IC", 
            resultEmoji, resultText, systemNames[data.system] or data.system, resultText, 
            data.reward, data.beforeValue, data.afterValue, data.efficiency, math.floor(data.earningRate))
    
    elseif notifType == 'bonus' then
        message = string.format("🌟 Hiệu suất xuất sắc!\n\n💵 Thu nhập: +$%d IC\n📊 Hiệu suất: %.1f%%\n💰 Tổng quỹ: $%d IC\n\nTiếp tục duy trì!", 
            math.floor(data.earnings), data.efficiency, math.floor(data.earningsPool))
    
    elseif notifType == 'emergency' then
        local criticalList = {}
        for _, sys in ipairs(data.criticalSystems) do
            table.insert(criticalList, string.format("• %s: %d%%", sys.name, sys.value))
        end
        
        message = string.format("🚨 CẢNH BÁO KHẨN CẤP!\n\nMáy điện gió đã ngừng hoạt động!\n\nHệ thống nguy kịch:\n%s\n\n⚠️ Cần sửa chữa ngay lập tức để tiếp tục kiếm tiền!", 
            table.concat(criticalList, "\n"))
    
    elseif notifType == 'dailyLimit' then
        message = string.format("⏰ Kết thúc ca làm việc\n\n📅 Đã đạt giới hạn ngày: %.1f giờ\n💰 Quỹ tiền lương: $%d IC\n📊 Hiệu suất trung bình: %.1f%%\n\nHãy nghỉ ngơi và quay lại sau 6:00 sáng!", 
            data.totalDailyHours, math.floor(data.earningsPool), data.efficiency)
    
    elseif notifType == 'outOfFuel' then
        message = "⛽ HẾT XĂNG!\n\nMáy điện gió đã dừng hoạt động do hết nhiên liệu.\n\n🔧 Hãy sử dụng Jerrycan để đổ xăng và tiếp tục làm việc!\n\n💡 Mỗi can xăng = 25 giờ hoạt động"
    end
    
    if message ~= "" then
        exports['lb-phone']:SendMessage('Trạm Điện Gió', tostring(phoneNumber), message, nil, nil, nil)
    end
end)

-- Helper: Lấy ngày hiện tại (format: số ngày từ epoch)
-- Reset vào 6:00 sáng giờ Việt Nam (UTC+7)
-- ĐỒNG BỘ VỚI CLIENT để cùng logic reset
local function GetCurrentDay()
    local timestamp = os.time()
    -- Điều chỉnh để reset vào 6:00 sáng VN thay vì 00:00 VN
    -- 6:00 VN = 23:00 UTC ngày hôm trước
    -- Nên ta trừ đi 1 giờ (3600 giây) từ UTC+7
    local vietnamOffset = (7 * 3600) - (6 * 3600) -- UTC+7 - 6 giờ = UTC+1
    local adjustedTime = timestamp + vietnamOffset
    local days = math.floor(adjustedTime / 86400)
    return tostring(days) -- Trả về số ngày kể từ epoch
end

-- Helper: Reset daily work hours nếu qua ngày mới
local function CheckAndResetDailyHours(citizenid)
    local currentDay = GetCurrentDay()
    
    if not PlayerWorkData[citizenid] then
        PlayerWorkData[citizenid] = {
            workStartTime = 0,
            dailyWorkHours = 0,
            lastDayReset = currentDay
        }
        return
    end
    
    -- Reset nếu qua ngày mới (6:00 sáng)
    if PlayerWorkData[citizenid].lastDayReset ~= currentDay then
        PlayerWorkData[citizenid].dailyWorkHours = 0
        PlayerWorkData[citizenid].lastDayReset = currentDay
    end
end

-- Helper: Validate số tiền rút có hợp lý không
local function ValidateWithdrawAmount(citizenid, amount, clientWorkHours)
    -- Kiểm tra work data tồn tại
    if not PlayerWorkData[citizenid] then
        return false, "NO_WORK_DATA"
    end
    
    local workData = PlayerWorkData[citizenid]
    
    -- Tính thời gian làm việc thực tế từ server
    local serverWorkHours = 0
    if workData.workStartTime > 0 then
        serverWorkHours = (os.time() - workData.workStartTime) / 3600
    end
    
    -- So sánh với client (cho phép sai số 5%)
    local timeDiff = math.abs(serverWorkHours - clientWorkHours)
    if timeDiff > (clientWorkHours * 0.05 + 0.1) then -- 5% + 0.1 giờ buffer
        return false, "TIME_MISMATCH"
    end
    
    -- Tính max earnings có thể (BaseSalary * hours * 120% buffer cho bonus)
    local maxPossibleEarnings = clientWorkHours * Config.BaseSalary * 1.2
    
    if amount > maxPossibleEarnings then
        return false, "AMOUNT_TOO_HIGH"
    end
    
    return true, "OK"
end

-- SECURITY FIX: Event Start Duty - Khởi tạo server-side tracking + OWNERSHIP CHECK
RegisterNetEvent('windturbine:startDuty')
AddEventHandler('windturbine:startDuty', function(turbineId)
    local playerId = source
    local Player = QBCore.Functions.GetPlayer(playerId)
    
    if not Player then
        TriggerClientEvent('windturbine:startDutyFailed', playerId, 'SYSTEM_ERROR')
        return
    end
    
    local citizenid = Player.PlayerData.citizenid
    
    -- SECURITY FIX: Validate turbineId
    local validTurbineId = false
    for _, turbineData in ipairs(Config.TurbineLocations) do
        if turbineData.id == turbineId then
            validTurbineId = true
            break
        end
    end
    
    if not validTurbineId then
        no:Notify(playerId, 'Trạm không hợp lệ!', 'error', 3000)
        TriggerClientEvent('windturbine:startDutyFailed', playerId, 'INVALID_TURBINE')
        return
    end
    
    -- SECURITY FIX: Check ownership
    CheckRentalExpiry(turbineId)
    local rentalData = TurbineRentals[turbineId]
    
    if not rentalData then
        no:Notify(playerId, 'Bạn cần thuê trạm này trước!', 'error', 3000)
        TriggerClientEvent('windturbine:startDutyFailed', playerId, 'NOT_RENTED')
        return
    end
    
    if rentalData.citizenid ~= citizenid then
        no:Notify(playerId, 'Bạn không phải chủ trạm này!', 'error', 3000)
        TriggerClientEvent('windturbine:startDutyFailed', playerId, 'NOT_OWNER')
        return
    end
    
    -- Reset daily hours nếu qua ngày mới
    CheckAndResetDailyHours(citizenid)
    
    -- ANTI-CHEAT: Kiểm tra giới hạn thời gian
    if PlayerWorkData[citizenid].dailyWorkHours >= Config.MaxDailyHours then
        TriggerClientEvent('windturbine:startDutyFailed', playerId, 'DAILY_LIMIT')
        return
    end
    
    -- SECURITY: Khởi tạo earnings tracking
    InitPlayerEarnings(citizenid)
    PlayerEarnings[citizenid].onDuty = true
    PlayerEarnings[citizenid].lastEarning = os.time()
    PlayerEarnings[citizenid].lastPenalty = os.time()
    PlayerEarnings[citizenid].lastFuelConsumption = os.time()
    
    -- Lưu work start time
    PlayerWorkData[citizenid].workStartTime = os.time()
    
    -- Gửi dữ liệu server về client
    TriggerClientEvent('windturbine:startDutySuccess', playerId, {
        systems = PlayerEarnings[citizenid].systems,
        earningsPool = PlayerEarnings[citizenid].earningsPool,
        currentFuel = PlayerEarnings[citizenid].currentFuel
    })
end)

-- SECURITY FIX: Event Stop Duty
RegisterNetEvent('windturbine:stopDuty')
AddEventHandler('windturbine:stopDuty', function()
    local playerId = source
    local Player = QBCore.Functions.GetPlayer(playerId)
    
    if not Player then return end
    
    local citizenid = Player.PlayerData.citizenid
    
    if PlayerEarnings[citizenid] then
        PlayerEarnings[citizenid].onDuty = false
    end
    
    -- Cập nhật daily work hours
    if PlayerWorkData[citizenid] and PlayerWorkData[citizenid].workStartTime > 0 then
        local serverWorkDuration = (os.time() - PlayerWorkData[citizenid].workStartTime) / 3600
        PlayerWorkData[citizenid].dailyWorkHours = PlayerWorkData[citizenid].dailyWorkHours + serverWorkDuration
        PlayerWorkData[citizenid].workStartTime = 0
    end
end)

-- Callback: Lấy daily work hours từ server
QBCore.Functions.CreateCallback('windturbine:getDailyWorkHours', function(source, cb)
    local Player = QBCore.Functions.GetPlayer(source)
    if not Player then
        cb(0)
        return
    end
    
    local citizenid = Player.PlayerData.citizenid
    CheckAndResetDailyHours(citizenid)
    
    cb(PlayerWorkData[citizenid].dailyWorkHours or 0)
end)

-- Helper: Đếm tổng số jerrycan
local function GetJerrycanCount(Player)
    if not Player then return 0 end
    
    local totalCans = 0
    for _, item in pairs(Player.PlayerData.items) do
        if item and item.name == Config.JerrycanItemName then
            totalCans = totalCans + (item.amount or 1)
        end
    end
    
    return totalCans
end

-- Callback: Kiểm tra có jerrycan không
QBCore.Functions.CreateCallback('windturbine:hasJerrycan', function(source, cb)
    local Player = QBCore.Functions.GetPlayer(source)
    cb(GetJerrycanCount(Player) > 0)
end)

-- Callback: Lấy số lượng jerrycan
QBCore.Functions.CreateCallback('windturbine:getJerrycanCount', function(source, cb)
    local Player = QBCore.Functions.GetPlayer(source)
    cb(GetJerrycanCount(Player))
end)

-- Callback: Kiểm tra số tiền IC Khóa và IC Thường
QBCore.Functions.CreateCallback('windturbine:checkMoney', function(source, cb, rentalPrice)
    local Player = QBCore.Functions.GetPlayer(source)
    
    if not Player then
        cb({hasEnough = false, tienkhoa = 0, bank = 0})
        return
    end
    
    local tienkhoa = Player.Functions.GetMoney('tienkhoa') or 0
    local bank = Player.Functions.GetMoney('bank') or 0
    local totalMoney = tienkhoa + bank
    
    cb({
        hasEnough = totalMoney >= rentalPrice,
        tienkhoa = tienkhoa,
        bank = bank,
        totalMoney = totalMoney
    })
end)

-- SECURITY FIX: Event refuel - Update server-side fuel
RegisterNetEvent('f17_tramdiengio:sv:useJerrycan')
AddEventHandler('f17_tramdiengio:sv:useJerrycan', function(fuelToAdd, amount)
    local src = source
    local xPlayer = QBCore.Functions.GetPlayer(src)
    if not xPlayer then return end
    
    local citizenid = xPlayer.PlayerData.citizenid
    InitPlayerEarnings(citizenid)
    
    local countXang = ox:GetItem(src, 'jerrycan', nil, true)
    if countXang <= 0 then
        no:Notify(src, 'Bạn không có can xăng!', 'error', 3000)
        return
    end
    
    ox:RemoveItem(src, Config.JerrycanItemName, amount)
    
    -- SECURITY: Update server-side fuel
    PlayerEarnings[citizenid].currentFuel = PlayerEarnings[citizenid].currentFuel + fuelToAdd
    
    TriggerClientEvent('windturbine:refuelSuccess', src, fuelToAdd, PlayerEarnings[citizenid].currentFuel)
    
    local phoneNumber = exports["lb-phone"]:GetEquippedPhoneNumber(src)
    if phoneNumber then
        local refuelMsg = string.format("⛽ Đổ xăng thành công!\n\nBạn đã sử dụng %d can xăng để thêm %d giờ nhiên liệu\n\nMỗi giờ hoạt động tiêu hao 1 fuel unit", amount, fuelToAdd)
        exports['lb-phone']:SendMessage('Trạm Điện Gió', tostring(phoneNumber), refuelMsg, nil, nil, nil)
    end
end)

-- SECURITY FIX: Event repair system - Server tự tính afterValue từ result
RegisterNetEvent('windturbine:repairSystem')
AddEventHandler('windturbine:repairSystem', function(system, result)
    local playerId = source
    local Player = QBCore.Functions.GetPlayer(playerId)
    if not Player then return end
    
    local citizenid = Player.PlayerData.citizenid
    InitPlayerEarnings(citizenid)
    
    -- SECURITY: Validate system exists
    if not PlayerEarnings[citizenid].systems[system] then
        return
    end
    
    -- SECURITY: Validate player is on duty
    if not PlayerEarnings[citizenid].onDuty then
        return
    end
    
    -- SECURITY: Validate result
    if result ~= 'perfect' and result ~= 'good' and result ~= 'fail' then
        print(string.format('[CHEAT DETECTED] Player %s sent invalid result: %s', citizenid, tostring(result)))
        return
    end
    
    -- Server tự tính reward dựa trên result
    local reward = 0
    if result == 'perfect' then
        reward = Config.RepairRewards.perfect
    elseif result == 'good' then
        reward = Config.RepairRewards.good
    else
        reward = Config.RepairRewards.fail
    end
    
    -- Server tự tính afterValue
    local oldValue = PlayerEarnings[citizenid].systems[system]
    local newValue = math.min(100, math.max(0, oldValue + reward))
    
    -- Update value
    PlayerEarnings[citizenid].systems[system] = newValue
    
    -- Gửi giá trị chính xác về client
    TriggerClientEvent('windturbine:updateSystems', playerId, PlayerEarnings[citizenid].systems)
end)

-- DEPRECATED: Event cũ vẫn giữ để tương thích (nhưng có validation chặt)
RegisterNetEvent('windturbine:updateSystem')
AddEventHandler('windturbine:updateSystem', function(system, newValue)
    local playerId = source
    local Player = QBCore.Functions.GetPlayer(playerId)
    if not Player then return end
    
    local citizenid = Player.PlayerData.citizenid
    InitPlayerEarnings(citizenid)
    
    -- SECURITY: Validate system exists
    if not PlayerEarnings[citizenid].systems[system] then
        return
    end
    
    -- SECURITY: Validate player is on duty
    if not PlayerEarnings[citizenid].onDuty then
        return
    end
    
    -- SECURITY: Validate newValue is reasonable (can only increase by max repair reward)
    local oldValue = PlayerEarnings[citizenid].systems[system]
    local maxIncrease = Config.RepairRewards.perfect -- 20
    local minDecrease = Config.RepairRewards.fail -- -5
    
    -- Chỉ cho phép thay đổi trong khoảng hợp lý
    if newValue > oldValue + maxIncrease or newValue < oldValue + minDecrease then
        -- Cheat detected - log và reject
        print(string.format('[CHEAT DETECTED] Player %s tried to set %s from %d to %d', citizenid, system, oldValue, newValue))
        return
    end
    
    -- Update value
    PlayerEarnings[citizenid].systems[system] = math.min(100, math.max(0, newValue))
end)

-- SECURITY FIX: Callback get server data
QBCore.Functions.CreateCallback('windturbine:getServerData', function(source, cb)
    local Player = QBCore.Functions.GetPlayer(source)
    if not Player then
        cb(nil)
        return
    end
    
    local citizenid = Player.PlayerData.citizenid
    InitPlayerEarnings(citizenid)
    
    cb({
        systems = PlayerEarnings[citizenid].systems,
        earningsPool = PlayerEarnings[citizenid].earningsPool,
        currentFuel = PlayerEarnings[citizenid].currentFuel
    })
end)

-- SECURITY FIX: Server-side earnings calculation thread + MEMORY CLEANUP
CreateThread(function()
    while true do
        Wait(Config.TestMode and 60000 or 3600000) -- 1 phút (test) hoặc 1 giờ (production)
        
        for citizenid, earnings in pairs(PlayerEarnings) do
            -- SECURITY FIX: Check if player is still online
            local Player = QBCore.Functions.GetPlayerByCitizenId(citizenid)
            
            if not Player then
                -- Player offline - cleanup if not on duty
                if not earnings.onDuty then
                    PlayerEarnings[citizenid] = nil
                end
                goto continue
            end
            
            if earnings.onDuty then
                local currentTime = os.time()
                
                -- Sinh tiền
                local canEarn, status = CanEarnMoney(earnings.systems, earnings.currentFuel)
                if canEarn then
                    local earnAmount = CalculateSystemProfit(earnings.systems)
                    earnings.earningsPool = earnings.earningsPool + earnAmount
                    earnings.lastEarning = currentTime
                    
                    -- Gửi update về client
                    TriggerClientEvent('windturbine:updateEarnings', Player.PlayerData.source, earnings.earningsPool)
                end
                
                -- Áp dụng penalty
                if canEarn and currentTime - earnings.lastPenalty >= (Config.TestMode and 60 or 3600) then
                    local workHours = (currentTime - PlayerWorkData[citizenid].workStartTime) / 3600
                    
                    -- Tìm penalty range
                    local penaltyRange = nil
                    for _, range in ipairs(Config.PenaltyRanges) do
                        if workHours >= range.minHours and workHours < range.maxHours then
                            penaltyRange = range
                            break
                        end
                    end
                    
                    if penaltyRange and #penaltyRange.penalties > 0 then
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
                        
                        if selectedPenalty and selectedPenalty.systems > 0 then
                            local numSystems = selectedPenalty.systems
                            if type(numSystems) == "table" then
                                numSystems = math.random(numSystems[1], numSystems[2])
                            end
                            
                            local systemNames = {"stability", "electric", "lubrication", "blades", "safety"}
                            local availableSystems = {}
                            for _, systemName in ipairs(systemNames) do
                                if earnings.systems[systemName] > 30 then
                                    table.insert(availableSystems, systemName)
                                end
                            end
                            
                            if #availableSystems > 0 then
                                numSystems = math.min(numSystems, #availableSystems)
                                
                                for i = 1, numSystems do
                                    local randomIndex = math.random(1, #availableSystems)
                                    local systemName = table.remove(availableSystems, randomIndex)
                                    earnings.systems[systemName] = math.max(0, earnings.systems[systemName] - selectedPenalty.damage)
                                end
                                
                                -- Gửi update về client
                                if Player then
                                    TriggerClientEvent('windturbine:updateSystems', Player.PlayerData.source, earnings.systems)
                                end
                            end
                        end
                    end
                    
                    earnings.lastPenalty = currentTime
                end
                
                -- Tiêu hao xăng
                if currentTime - earnings.lastFuelConsumption >= (Config.TestMode and 60 or 3600) then
                    if earnings.currentFuel > 0 then
                        earnings.currentFuel = earnings.currentFuel - 1
                        
                        -- Gửi update về client
                        if Player then
                            TriggerClientEvent('windturbine:updateFuel', Player.PlayerData.source, earnings.currentFuel)
                            
                            if earnings.currentFuel == 0 then
                                earnings.onDuty = false
                                TriggerClientEvent('windturbine:outOfFuel', Player.PlayerData.source)
                            end
                        end
                    end
                    
                    earnings.lastFuelConsumption = currentTime
                end
            end
            
            ::continue::
        end
    end
end)
