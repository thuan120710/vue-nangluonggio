QBCore = exports['qb-core']:GetCoreObject()

-- ============================================
-- SERVER CHỈ XỬ LÝ:
-- 1. Rút tiền (withdrawEarnings)
-- 2. Gửi phone notifications
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
        
        print(('[Wind Turbine] Player %s withdrew $%d'):format(playerId, amount))
    else
        TriggerClientEvent('QBCore:Notify', playerId, '❌ Lỗi hệ thống!', 'error')
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
