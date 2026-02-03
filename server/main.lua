QBCore = exports['qb-core']:GetCoreObject()

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

-- Khởi tạo: Reset GlobalState khi script start
CreateThread(function()
    -- Reset tất cả trạm về trạng thái chưa thuê
    GlobalState['turbine_turbine_1'] = {
        isRented = false,
        ownerName = nil,
        citizenid = nil,
        expiryTime = nil,
        withdrawDeadline = nil,
        isGracePeriod = false
    }
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
        print('[DEBUG] Broadcast rental status: isRented=true, owner=' .. rentalData.ownerName)
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
        print('[DEBUG] Broadcast grace period: withdrawDeadline=' .. graceData.withdrawDeadline .. ', owner=' .. graceData.ownerName)
    else
        GlobalState['turbine_' .. turbineId] = {
            isRented = false,
            ownerName = nil,
            citizenid = nil,
            expiryTime = nil,
            withdrawDeadline = nil,
            isGracePeriod = false
        }
        print('[DEBUG] Broadcast reset: turbine available')
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
            
            -- Thông báo cho owner nếu đang online
            if graceData.playerId then
                TriggerClientEvent('QBCore:Notify', graceData.playerId, 
                    '⚠️ Hết thời gian rút tiền! Trạm đã được reset.', 
                    'error', 5000)
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
            TriggerClientEvent('QBCore:Notify', rentalData.playerId, 
                string.format('⚠️ Hết thời hạn thuê! Bạn có %s để rút tiền.', gracePeriodText), 
                'warning', 8000)
            
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

-- Helper: Lấy thông tin rental
local function GetRentalInfo(turbineId)
    CheckRentalExpiry(turbineId)
    return TurbineRentals[turbineId]
end

-- Helper: Lấy thông tin grace period
local function GetGracePeriodInfo(turbineId)
    CheckRentalExpiry(turbineId)
    return TurbineExpiryGracePeriod[turbineId]
end

-- Event: Rút tiền trong grace period
RegisterNetEvent('windturbine:expiryWithdraw')
AddEventHandler('windturbine:expiryWithdraw', function(turbineId, amount)
    local playerId = source
    local Player = QBCore.Functions.GetPlayer(playerId)
    
    if not Player then
        TriggerClientEvent('QBCore:Notify', playerId, '❌ Lỗi hệ thống!', 'error')
        return
    end
    
    -- Kiểm tra grace period
    CheckRentalExpiry(turbineId)
    local graceData = TurbineExpiryGracePeriod[turbineId]
    
    if not graceData then
        TriggerClientEvent('QBCore:Notify', playerId, '❌ Không có tiền để rút!', 'error')
        return
    end
    
    -- Kiểm tra owner
    local citizenid = Player.PlayerData.citizenid
    if graceData.citizenid ~= citizenid then
        TriggerClientEvent('QBCore:Notify', playerId, '❌ Bạn không phải chủ trạm này!', 'error')
        return
    end
    
    -- Kiểm tra số tiền
    if not amount or amount <= 0 then
        TriggerClientEvent('QBCore:Notify', playerId, '❌ Không có tiền để rút!', 'error')
        return
    end
    
    -- Rút tiền thành công
    Player.Functions.AddMoney('cash', amount)
    
    -- Reset trạm về trạng thái có thể thuê lại
    TurbineExpiryGracePeriod[turbineId] = nil
    BroadcastRentalStatus(turbineId)
    
    -- Thông báo
    TriggerClientEvent('QBCore:Notify', playerId, 
        string.format('✅ Đã rút $%s IC thành công!', string.format("%d", amount)), 
        'success', 5000)
    
    TriggerClientEvent('windturbine:expiryWithdrawSuccess', playerId)
    
    -- Gửi phone notification
    local phoneNumber = exports["lb-phone"]:GetEquippedPhoneNumber(playerId)
    if phoneNumber then
        local withdrawMsg = string.format("💰 Rút tiền thành công\n\nSố tiền: $%s IC\nThời gian: %s\n\n✅ Trạm đã được reset. Bạn có thể thuê lại bất cứ lúc nào!", 
            string.format("%d", amount), os.date("%H:%M:%S - %d/%m/%Y"))
        exports['lb-phone']:SendMessage('Trạm Điện Gió', tostring(phoneNumber), withdrawMsg, nil, nil, nil)
    end
end)

-- Event: Rút tiền
RegisterNetEvent('windturbine:withdrawEarnings')
AddEventHandler('windturbine:withdrawEarnings', function(amount)
    local playerId = source
    
    if not amount or amount <= 0 then
        TriggerClientEvent('QBCore:Notify', playerId, '❌ Không có tiền để rút!', 'error')
        return
    end
    
    local Player = QBCore.Functions.GetPlayer(playerId)
    if Player then
        Player.Functions.AddMoney('cash', amount)
        TriggerClientEvent('windturbine:withdrawSuccess', playerId, amount)
        
        local phoneNumber = exports["lb-phone"]:GetEquippedPhoneNumber(playerId)
        if phoneNumber then
            local withdrawMsg = string.format("💰 Xác nhận rút tiền\n\nSố tiền: $%s IC\nThời gian: %s\n\nTiền đã được chuyển vào ví của bạn. Cảm ơn bạn đã làm việc chăm chỉ!", string.format("%d", amount), os.date("%H:%M:%S - %d/%m/%Y"))
            exports['lb-phone']:SendMessage('Trạm Điện Gió', tostring(phoneNumber), withdrawMsg, nil, nil, nil)
        end
    else
        TriggerClientEvent('QBCore:Notify', playerId, '❌ Lỗi hệ thống!', 'error')
    end
end)

-- Event: Thuê trạm (chỉ trừ tiền)
RegisterNetEvent('windturbine:rentTurbine')
AddEventHandler('windturbine:rentTurbine', function(turbineId, rentalPrice)
    local playerId = source
    local Player = QBCore.Functions.GetPlayer(playerId)
    
    if not Player then
        TriggerClientEvent('QBCore:Notify', playerId, '❌ Lỗi hệ thống!', 'error')
        TriggerClientEvent('windturbine:rentFailed', playerId)
        return
    end
    
    -- Kiểm tra trạm đã được thuê chưa
    CheckRentalExpiry(turbineId)
    if TurbineRentals[turbineId] then
        local ownerName = TurbineRentals[turbineId].ownerName
        TriggerClientEvent('QBCore:Notify', playerId, 
            string.format('❌ Trạm này đã được thuê bởi %s!', ownerName), 
            'error', 5000)
        TriggerClientEvent('windturbine:rentFailed', playerId)
        return
    end
    
    -- Validate rentalPrice
    if rentalPrice == nil or type(rentalPrice) ~= "number" or rentalPrice < 0 then
        TriggerClientEvent('QBCore:Notify', playerId, '❌ Lỗi giá thuê!', 'error')
        TriggerClientEvent('windturbine:rentFailed', playerId)
        return
    end
    
    -- Kiểm tra tiền
    local playerMoney = Player.Functions.GetMoney('cash') or 0
    
    if rentalPrice > 0 and playerMoney < rentalPrice then
        TriggerClientEvent('QBCore:Notify', playerId, 
            string.format('❌ Không đủ tiền! Cần $%s IC (Bạn có: $%s IC)', 
                string.format("%d", rentalPrice),
                string.format("%d", playerMoney)), 
            'error')
        TriggerClientEvent('windturbine:rentFailed', playerId)
        return
    end
    
    -- Trừ tiền
    if rentalPrice > 0 then
        Player.Functions.RemoveMoney('cash', rentalPrice)
    end
    
    -- Lấy thông tin player
    local citizenid = Player.PlayerData.citizenid
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
    
    -- Thông báo thành công
    local durationText = Config.TestMode and "60 giây" or "7 ngày"
    if rentalPrice > 0 then
        TriggerClientEvent('QBCore:Notify', playerId, 
            string.format('✅ Đã thuê trạm điện gió! Giá: $%s IC | Thời hạn: %s', 
                string.format("%d", rentalPrice), durationText), 
            'success', 5000)
    else
        TriggerClientEvent('QBCore:Notify', playerId, 
            string.format('✅ Đã thuê trạm điện gió MIỄN PHÍ! Thời hạn: %s', durationText), 
            'success', 5000)
    end
    
    TriggerClientEvent('windturbine:rentSuccess', playerId, {
        citizenid = citizenid,
        ownerName = ownerName,
        expiryTime = TurbineRentals[turbineId].expiryTime
    })
    
    -- Gửi tin nhắn xác nhận qua lb-phone
    local phoneNumber = exports["lb-phone"]:GetEquippedPhoneNumber(playerId)
    if phoneNumber then
        local durationText = Config.TestMode and "60 giây" or "7 ngày"
        local gracePeriodText = Config.TestMode and "30 giây" or "4 giờ"
        local rentalMsg = ""
        if rentalPrice > 0 then
            rentalMsg = string.format("🌬️ Xác nhận thuê Trạm Điện Gió\n\n💰 Giá thuê: $%s IC\n⏰ Thời hạn: %s\n\n✅ Bạn có thể bắt đầu làm việc ngay bây giờ!\n\n⚠️ Lưu ý: Sau khi hết hạn, bạn có %s để rút tiền.", 
                string.format("%d", rentalPrice), durationText, gracePeriodText)
        else
            rentalMsg = string.format("🌬️ Xác nhận thuê Trạm Điện Gió\n\n💰 Giá thuê: MIỄN PHÍ\n⏰ Thời hạn: %s\n\n✅ Bạn có thể bắt đầu làm việc ngay bây giờ!\n\n⚠️ Lưu ý: Sau khi hết hạn, bạn có %s để rút tiền.", durationText, gracePeriodText)
        end
        exports['lb-phone']:SendMessage('Trạm Điện Gió', tostring(phoneNumber), rentalMsg, nil, nil, nil)
    end
end)

-- Thread: Tự động kiểm tra expiry mỗi 5 giây
CreateThread(function()
    while true do
        Wait(5000) -- Check mỗi 5 giây
        
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
        message = string.format("⏰ Kết thúc ca làm việc\n\n📅 Đã đạt giới hạn ngày: %.1f giờ\n💰 Quỹ tiền lương: $%d IC\n📊 Hiệu suất trung bình: %.1f%%\n\nHãy nghỉ ngơi và quay lại vào ngày mai!", 
            data.totalDailyHours, math.floor(data.earningsPool), data.efficiency)
    
    elseif notifType == 'weeklyLimit' then
        message = string.format("📊 Báo cáo tuần\n\n⏰ Tổng giờ làm: %.1f/%.0f giờ\n💰 Quỹ tiền lương: $%d IC\n� Hiệu suất: %.1f%%\n\n🎉 Bạn đã hoàn thành tuần làm việc!\nHãy nghỉ ngơi và quay lại vào tuần sau.", 
            data.totalWeeklyHours, data.maxWeeklyHours, math.floor(data.earningsPool), data.efficiency)
    end
    
    if message ~= "" then
        exports['lb-phone']:SendMessage('Trạm Điện Gió', tostring(phoneNumber), message, nil, nil, nil)
    end
end)
