QBCore = exports['qb-core']:GetCoreObject()
local no = exports['f17notify']

-- ============================================
-- SERVER XỬ LÝ:
-- 1. Rút tiền (withdrawEarnings)
-- 2. Trừ tiền thuê trạm (rentTurbine)
-- 3. Gửi phone notifications
-- 4. Quản lý rental data (StateBag - broadcast tự động cho 500 người)
-- ============================================

-- Dữ liệu thuê trạm (lưu ở server)
local TurbineRentals = {}
local TurbineExpiryGracePeriod = {} -- Lưu thời gian grace period (4 giờ để rút tiền)

-- Dữ liệu tracking thời gian làm việc (anti-cheat)
local PlayerWorkData = {} -- [citizenid] = {workStartTime, dailyWorkHours, lastDayReset}

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
            TurbineExpiryGracePeriod[turbineId] = nil
            BroadcastRentalStatus(turbineId)
            
            -- Thông báo cho owner nếu đang online và trigger reset data
            if graceData.playerId then
                TriggerClientEvent('windturbine:notify', graceData.playerId, 
                    '⚠️ Hết thời gian rút tiền! Trạm đã được reset.', 
                    'error', 5000)
                
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
            TriggerClientEvent('windturbine:notify', rentalData.playerId, 
                string.format('⚠️ Hết thời hạn thuê! Bạn có %s để rút tiền.', gracePeriodText), 
                'error', 8000)
            
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

-- Event: Rút tiền (merge cả 2 loại: bình thường và grace period)
RegisterNetEvent('windturbine:withdrawEarnings')
AddEventHandler('windturbine:withdrawEarnings', function(amount, isGracePeriod, turbineId, clientWorkHours)
    local playerId = source
    local Player = QBCore.Functions.GetPlayer(playerId)
    
    if not Player then
        TriggerClientEvent('windturbine:notify', playerId, '❌ Lỗi hệ thống!', 'error')
        return
    end
    
    local citizenid = Player.PlayerData.citizenid
    
    -- Kiểm tra số tiền
    if not amount or amount <= 0 then
        TriggerClientEvent('windturbine:notify', playerId, '❌ Không có tiền để rút!', 'error')
        return
    end
    
    -- ANTI-CHEAT: Validate số tiền với thời gian làm việc (chỉ khi không phải grace period)
    if not isGracePeriod and clientWorkHours then
        local isValid, reason = ValidateWithdrawAmount(citizenid, amount, clientWorkHours)
        
        if not isValid then
            if reason == "TIME_MISMATCH" then
                TriggerClientEvent('windturbine:notify', playerId, '❌ Lỗi đồng bộ thời gian! Vui lòng thử lại.', 'error')
            elseif reason == "AMOUNT_TOO_HIGH" then
                TriggerClientEvent('windturbine:notify', playerId, '❌ Số tiền không hợp lệ!', 'error')
            else
                TriggerClientEvent('windturbine:notify', playerId, '❌ Dữ liệu không hợp lệ!', 'error')
            end
            return
        end
        
        -- Cập nhật daily work hours khi rút tiền
        if PlayerWorkData[citizenid] then
            PlayerWorkData[citizenid].dailyWorkHours = PlayerWorkData[citizenid].dailyWorkHours + clientWorkHours
            PlayerWorkData[citizenid].workStartTime = 0 -- Reset work start time
        end
    end
    
    -- Xử lý rút tiền trong grace period
    if isGracePeriod and turbineId then
        -- Kiểm tra grace period
        CheckRentalExpiry(turbineId)
        local graceData = TurbineExpiryGracePeriod[turbineId]
        
        if not graceData then
            TriggerClientEvent('windturbine:notify', playerId, '❌ Không có tiền để rút!', 'error')
            return
        end
        
        -- Kiểm tra owner
        local citizenid = Player.PlayerData.citizenid
        if graceData.citizenid ~= citizenid then
            TriggerClientEvent('windturbine:notify', playerId, '❌ Bạn không phải chủ trạm này!', 'error')
            return
        end
        
        -- Reset trạm về trạng thái có thể thuê lại
        TurbineExpiryGracePeriod[turbineId] = nil
        BroadcastRentalStatus(turbineId)
    end
    
    -- Rút tiền - Thêm tiền khóa
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

-- Event: Thuê trạm (chỉ trừ tiền)
RegisterNetEvent('windturbine:rentTurbine')
AddEventHandler('windturbine:rentTurbine', function(turbineId, rentalPrice)
    local playerId = source
    local Player = QBCore.Functions.GetPlayer(playerId)
    
    if not Player then
        TriggerClientEvent('windturbine:notify', playerId, '❌ Lỗi hệ thống!', 'error')
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
        TriggerClientEvent('windturbine:notify', playerId, '❌ Trạm không hợp lệ!', 'error')
        TriggerClientEvent('windturbine:rentFailed', playerId)
        return
    end
    
    local citizenid = Player.PlayerData.citizenid
    
    -- Kiểm tra xem player đã thuê trạm nào chưa
    for tId, rentalData in pairs(TurbineRentals) do
        if rentalData.citizenid == citizenid then
            TriggerClientEvent('windturbine:notify', playerId, 
                '❌ Bạn đã thuê một trạm khác rồi! Không thể thuê nhiều trạm cùng lúc.', 
                'error', 5000)
            TriggerClientEvent('windturbine:rentFailed', playerId)
            return
        end
    end
    
    -- Kiểm tra xem player có đang trong grace period của trạm nào không
    for tId, graceData in pairs(TurbineExpiryGracePeriod) do
        if graceData.citizenid == citizenid then
            TriggerClientEvent('windturbine:notify', playerId, 
                '❌ Bạn cần rút tiền từ trạm cũ trước khi thuê trạm mới!', 
                'error', 5000)
            TriggerClientEvent('windturbine:rentFailed', playerId)
            return
        end
    end
    
    -- Kiểm tra trạm đã được thuê chưa
    CheckRentalExpiry(turbineId)
    if TurbineRentals[turbineId] then
        local ownerName = TurbineRentals[turbineId].ownerName
        TriggerClientEvent('windturbine:notify', playerId, 
            string.format('❌ Trạm này đã được thuê bởi %s!', ownerName), 
            'error', 5000)
        TriggerClientEvent('windturbine:rentFailed', playerId)
        return
    end
    
    -- Validate rentalPrice
    if rentalPrice == nil or type(rentalPrice) ~= "number" or rentalPrice < 0 then
        TriggerClientEvent('windturbine:notify', playerId, '❌ Lỗi giá thuê!', 'error')
        TriggerClientEvent('windturbine:rentFailed', playerId)
        return
    end
    
    -- Kiểm tra tiền khóa và bank
    local tienkhoa = Player.Functions.GetMoney('tienkhoa') or 0
    local bank = Player.Functions.GetMoney('bank') or 0
    local totalMoney = tienkhoa + bank
    
    if rentalPrice > 0 and totalMoney < rentalPrice then
        TriggerClientEvent('windturbine:notify', playerId, 
            string.format('❌ Không đủ tiền! Cần $%s IC (Bạn có: $%s IC + $%s Bank)', 
                string.format("%d", rentalPrice),
                string.format("%d", tienkhoa),
                string.format("%d", bank)), 
            'error', 7000)
        TriggerClientEvent('windturbine:rentFailed', playerId)
        return
    end
    
    -- Trừ tiền: Ưu tiên trừ tiền khóa trước, thiếu thì trừ bank
    if rentalPrice > 0 then
        if tienkhoa >= rentalPrice then
            -- Đủ tiền khóa, chỉ trừ tiền khóa
            Player.Functions.RemoveMoney('tienkhoa', rentalPrice)
        else
            -- Không đủ tiền khóa, trừ hết tiền khóa + phần còn lại từ bank
            local remainingAmount = rentalPrice - tienkhoa
            if tienkhoa > 0 then
                Player.Functions.RemoveMoney('tienkhoa', tienkhoa)
            end
            Player.Functions.RemoveMoney('bank', remainingAmount)
        end
    end
    
    -- Lấy thông tin player
    local ownerName = Player.PlayerData.charinfo.firstname .. ' ' .. Player.PlayerData.charinfo.lastname
    
    -- Lưu rental data ở server
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

-- Event: Start Duty (với validation)
RegisterNetEvent('windturbine:startDuty')
AddEventHandler('windturbine:startDuty', function(turbineId)
    local playerId = source
    local Player = QBCore.Functions.GetPlayer(playerId)
    
    if not Player then
        TriggerClientEvent('windturbine:startDutyFailed', playerId, 'SYSTEM_ERROR')
        return
    end
    
    local citizenid = Player.PlayerData.citizenid
    
    -- Reset daily hours nếu qua ngày mới
    CheckAndResetDailyHours(citizenid)
    
    -- ANTI-CHEAT: Kiểm tra giới hạn thời gian
    if PlayerWorkData[citizenid].dailyWorkHours >= Config.MaxDailyHours then
        TriggerClientEvent('windturbine:startDutyFailed', playerId, 'DAILY_LIMIT')
        return
    end
    
    -- Lưu work start time
    PlayerWorkData[citizenid].workStartTime = os.time()
    
    -- Thông báo thành công
    TriggerClientEvent('windturbine:startDutySuccess', playerId)
end)

-- Event: Stop Duty (cập nhật work hours)
RegisterNetEvent('windturbine:stopDuty')
AddEventHandler('windturbine:stopDuty', function(workDuration)
    local playerId = source
    local Player = QBCore.Functions.GetPlayer(playerId)
    
    if not Player then return end
    
    local citizenid = Player.PlayerData.citizenid
    
    -- Cập nhật daily work hours
    if PlayerWorkData[citizenid] and PlayerWorkData[citizenid].workStartTime > 0 then
        -- Tính thời gian từ server để validate
        local serverWorkDuration = (os.time() - PlayerWorkData[citizenid].workStartTime) / 3600
        
        -- Chấp nhận client duration nếu sai số < 5%
        local timeDiff = math.abs(serverWorkDuration - workDuration)
        if timeDiff <= (workDuration * 0.05 + 0.1) then
            PlayerWorkData[citizenid].dailyWorkHours = PlayerWorkData[citizenid].dailyWorkHours + workDuration
        else
            -- Dùng server time nếu client không khớp
            PlayerWorkData[citizenid].dailyWorkHours = PlayerWorkData[citizenid].dailyWorkHours + serverWorkDuration
        end
        
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

-- Event: Sử dụng jerrycan để đổ xăng
RegisterNetEvent('windturbine:useJerrycan')
AddEventHandler('windturbine:useJerrycan', function(fuelToAdd)
    local playerId = source
    local Player = QBCore.Functions.GetPlayer(playerId)
    
    if not Player then return end
    
    if GetJerrycanCount(Player) <= 0 then
        TriggerClientEvent('windturbine:notify', playerId, '❌ Bạn không có can xăng!', 'error')
        return
    end
    
    -- Trừ 1 jerrycan
    Player.Functions.RemoveItem(Config.JerrycanItemName, 1)
    TriggerClientEvent('inventory:client:ItemBox', playerId, QBCore.Shared.Items[Config.JerrycanItemName], "remove")
    
    -- Thông báo thành công cho client
    TriggerClientEvent('windturbine:refuelSuccess', playerId, fuelToAdd)
    
    -- Gửi phone notification
    local phoneNumber = exports["lb-phone"]:GetEquippedPhoneNumber(playerId)
    if phoneNumber then
        local refuelMsg = string.format("⛽ Đổ xăng thành công!\n\n✅ Đã thêm %d giờ nhiên liệu\n📦 Đã sử dụng 1 Jerrycan\n\n💡 Mỗi giờ hoạt động tiêu hao 1 fuel unit", fuelToAdd)
        exports['lb-phone']:SendMessage('Trạm Điện Gió', tostring(phoneNumber), refuelMsg, nil, nil, nil)
    end
end)

-- Event: Sử dụng nhiều jerrycan (khi hết xăng hoàn toàn)
RegisterNetEvent('windturbine:useMultipleJerrycans')
AddEventHandler('windturbine:useMultipleJerrycans', function(canCount, fuelToAdd)
    local playerId = source
    local Player = QBCore.Functions.GetPlayer(playerId)
    
    if not Player then return end
    
    local totalCans = GetJerrycanCount(Player)
    
    if totalCans < canCount then
        TriggerClientEvent('windturbine:notify', playerId, string.format('❌ Không đủ can xăng! Cần: %d, Có: %d', canCount, totalCans), 'error')
        return
    end
    
    -- Trừ nhiều jerrycan
    Player.Functions.RemoveItem(Config.JerrycanItemName, canCount)
    TriggerClientEvent('inventory:client:ItemBox', playerId, QBCore.Shared.Items[Config.JerrycanItemName], "remove")
    
    -- Thông báo thành công cho client
    TriggerClientEvent('windturbine:refuelSuccess', playerId, fuelToAdd)
    
    -- Gửi phone notification
    local phoneNumber = exports["lb-phone"]:GetEquippedPhoneNumber(playerId)
    if phoneNumber then
        local refuelMsg = string.format("⛽ Đổ xăng khởi động lại!\n\n✅ Đã thêm %d giờ nhiên liệu\n📦 Đã sử dụng %d Jerrycan\n\n💡 Máy đã sẵn sàng hoạt động trở lại!", fuelToAdd, canCount)
        exports['lb-phone']:SendMessage('Trạm Điện Gió', tostring(phoneNumber), refuelMsg, nil, nil, nil)
    end
end)
