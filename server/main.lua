QBCore = exports['qb-core']:GetCoreObject()

-- ============================================
-- SERVER CHỈ XỬ LÝ:
-- 1. Rút tiền (withdrawEarnings)
-- 2. Trừ tiền thuê trạm (rentTurbine)
-- 3. Gửi phone notifications
-- ============================================

-- Event: Rút tiền
RegisterNetEvent('windturbine:withdrawEarnings')
AddEventHandler('windturbine:withdrawEarnings', function(amount)
    local playerId = source
    
    if not amount or amount <= 0 then
        TriggerClientEvent('QBCore:Notify', playerId, '❌ Không có tiền để rút!', 'error')
        return
    end
    
    -- QBCore: Thêm tiền vào ví
    local Player = QBCore.Functions.GetPlayer(playerId)
    if Player then
        Player.Functions.AddMoney('cash', amount)
        
        -- Thông báo cho client rút tiền thành công
        TriggerClientEvent('windturbine:withdrawSuccess', playerId, amount)
        
        -- Gửi tin nhắn xác nhận qua lb-phone
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
    
    -- Validate rentalPrice
    if rentalPrice == nil or type(rentalPrice) ~= "number" or rentalPrice < 0 then
        TriggerClientEvent('QBCore:Notify', playerId, '❌ Lỗi giá thuê!', 'error')
        TriggerClientEvent('windturbine:rentFailed', playerId)
        return
    end
    
    -- Kiểm tra tiền (bỏ qua nếu giá = 0)
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
    
    -- Trừ tiền (chỉ khi giá > 0)
    if rentalPrice > 0 then
        Player.Functions.RemoveMoney('cash', rentalPrice)
    end
    
    -- Lấy thông tin player
    local citizenid = Player.PlayerData.citizenid
    local ownerName = Player.PlayerData.charinfo.firstname .. ' ' .. Player.PlayerData.charinfo.lastname
    
    -- Thông báo thành công
    if rentalPrice > 0 then
        TriggerClientEvent('QBCore:Notify', playerId, 
            string.format('✅ Đã thuê trạm điện gió! Giá: $%s IC | Thời hạn: 7 ngày', 
                string.format("%d", rentalPrice)), 
            'success', 5000)
    else
        TriggerClientEvent('QBCore:Notify', playerId, 
            '✅ Đã thuê trạm điện gió MIỄN PHÍ! Thời hạn: 7 ngày', 
            'success', 5000)
    end
    
    -- Thông báo thành công cho client
    TriggerClientEvent('windturbine:rentSuccess', playerId, {
        citizenid = citizenid,
        ownerName = ownerName
    })
    
    -- Gửi tin nhắn xác nhận qua lb-phone
    local phoneNumber = exports["lb-phone"]:GetEquippedPhoneNumber(playerId)
    if phoneNumber then
        local rentalMsg = ""
        if rentalPrice > 0 then
            rentalMsg = string.format("🌬️ Xác nhận thuê Trạm Điện Gió\n\n💰 Giá thuê: $%s IC\n⏰ Thời hạn: 7 ngày\n\n✅ Bạn có thể bắt đầu làm việc ngay bây giờ!\n\n⚠️ Lưu ý: Sau khi hết hạn, bạn cần thuê lại để tiếp tục sử dụng.", 
                string.format("%d", rentalPrice))
        else
            rentalMsg = "🌬️ Xác nhận thuê Trạm Điện Gió\n\n💰 Giá thuê: MIỄN PHÍ\n⏰ Thời hạn: 7 ngày\n\n✅ Bạn có thể bắt đầu làm việc ngay bây giờ!\n\n⚠️ Lưu ý: Sau khi hết hạn, bạn cần thuê lại để tiếp tục sử dụng."
        end
        exports['lb-phone']:SendMessage('Trạm Điện Gió', tostring(phoneNumber), rentalMsg, nil, nil, nil)
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
        message = string.format("⚠️ Cảnh báo hư hỏng!\n\nThời gian làm việc: %.1f giờ\nSố hệ thống bị ảnh hưởng: %d\nMức độ hư hỏng: -%d%%\n\nChi tiết:\n%s\n\n💡 Hãy sửa chữa để duy trì hiệu suất!", 
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
        message = string.format("📊 Báo cáo tuần\n\n⏰ Tổng giờ làm: %.1f/%.0f giờ\n💰 Quỹ tiền lương: $%d IC\n📈 Hiệu suất: %.1f%%\n\n🎉 Bạn đã hoàn thành tuần làm việc!\nHãy nghỉ ngơi và quay lại vào tuần sau.", 
            data.totalWeeklyHours, data.maxWeeklyHours, math.floor(data.earningsPool), data.efficiency)
    end
    
    if message ~= "" then
        exports['lb-phone']:SendMessage('Trạm Điện Gió', tostring(phoneNumber), message, nil, nil, nil)
    end
end)
