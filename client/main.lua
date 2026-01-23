QBCore = exports['qb-core']:GetCoreObject()

local isOnDuty = false
local isNearTurbine = false
local currentSystems = {}
local currentEfficiency = 0
local currentEarnings = 0
local turbineSoundId = -1

-- Mở UI chính
local function OpenMainUI()
    SetNuiFocus(true, true)
    SendNUIMessage({
        action = 'showMainUI',
        systems = currentSystems,
        efficiency = currentEfficiency,
        earnings = currentEarnings,
        onDuty = isOnDuty  -- Gửi trạng thái onDuty
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
    TriggerServerEvent('windturbine:startDuty')
    isOnDuty = true
    QBCore.Functions.Notify('✅ Đã bắt đầu ca làm việc tại cối xay gió!', 'success', 3000)
    PlaySound(-1, "CHECKPOINT_PERFECT", "HUD_MINI_GAME_SOUNDSET", 0, 0, 1)
    
    -- Bắt đầu âm thanh cối xay gió
    StartTurbineSound()
    
    cb('ok')
end)

RegisterNUICallback('stopDuty', function(data, cb)
    TriggerServerEvent('windturbine:stopDuty')
    isOnDuty = false
    
    
    CloseUI()
    
    QBCore.Functions.Notify('👋 Đã kết thúc ca làm việc!', 'primary', 3000)
    PlaySound(-1, "QUIT", "HUD_FRONTEND_DEFAULT_SOUNDSET", 0, 0, 1)
    
    -- Dừng âm thanh cối xay gió
    StopTurbineSound()
    
    -- Reset toàn bộ UI về trạng thái ban đầu
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
    TriggerServerEvent('windturbine:repairSystem', data.system, data.result)
    
    -- Thông báo kết quả sửa chữa
    if data.result == 'perfect' then
        QBCore.Functions.Notify('🌟 Hoàn hảo! Hệ thống ' .. data.system:upper() .. ' đã được sửa chữa tốt!', 'success', 3000)
        PlaySound(-1, "CHECKPOINT_PERFECT", "HUD_MINI_GAME_SOUNDSET", 0, 0, 1)
    elseif data.result == 'good' then
        QBCore.Functions.Notify('✅ Tốt! Hệ thống ' .. data.system:upper() .. ' đã được cải thiện!', 'success', 3000)
        PlaySound(-1, "CHECKPOINT_NORMAL", "HUD_MINI_GAME_SOUNDSET", 0, 0, 1)
    else
        QBCore.Functions.Notify('❌ Thất bại! Hệ thống ' .. data.system:upper() .. ' bị giảm hiệu suất!', 'error', 3000)
        PlaySound(-1, "CHECKPOINT_MISSED", "HUD_MINI_GAME_SOUNDSET", 0, 0, 1)
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
    TriggerServerEvent('windturbine:withdrawEarnings')
    PlaySound(-1, "PICK_UP", "HUD_FRONTEND_DEFAULT_SOUNDSET", 0, 0, 1)
    cb('ok')
end)

RegisterNUICallback('backToMain', function(data, cb)
    OpenMainUI()
    cb('ok')
end)

-- Server Events
RegisterNetEvent('windturbine:updateSystems')
AddEventHandler('windturbine:updateSystems', function(systems)
    currentSystems = systems
    SendNUIMessage({
        action = 'updateSystems',
        systems = systems
    })
    
    -- Kiểm tra và thông báo hệ thống xuống dưới 30%
    for system, value in pairs(systems) do
        if value < 30 and value > 0 then
            QBCore.Functions.Notify('⚠️ Cảnh báo: Hệ thống ' .. system:upper() .. ' đang ở mức nguy hiểm!', 'error', 5000)
            PlaySound(-1, "CHECKPOINT_MISSED", "HUD_MINI_GAME_SOUNDSET", 0, 0, 1)
        elseif value < 50 and value >= 30 then
            QBCore.Functions.Notify('⚠️ Chú ý: Hệ thống ' .. system:upper() .. ' cần bảo trì!', 'warning', 3000)
        end
    end
end)

RegisterNetEvent('windturbine:updateEfficiency')
AddEventHandler('windturbine:updateEfficiency', function(efficiency)
    currentEfficiency = efficiency
    SendNUIMessage({
        action = 'updateEfficiency',
        efficiency = efficiency
    })
    
    -- Thông báo khi hiệu suất quá thấp
    if efficiency < 10 then
        QBCore.Functions.Notify('🚨 Cối xay gió đã ngừng hoạt động! Hiệu suất quá thấp!', 'error', 5000)
        PlaySound(-1, "CHECKPOINT_MISSED", "HUD_MINI_GAME_SOUNDSET", 0, 0, 1)
    elseif efficiency < 30 then
        QBCore.Functions.Notify('⚠️ Hiệu suất rất thấp! Cần sửa chữa ngay!', 'error', 3000)
    end
end)

RegisterNetEvent('windturbine:updateEarningsPool')
AddEventHandler('windturbine:updateEarningsPool', function(earnings)
    currentEarnings = earnings
    SendNUIMessage({
        action = 'updateEarnings',
        earnings = earnings
    })
end)

RegisterNetEvent('windturbine:updateActualEarningRate')
AddEventHandler('windturbine:updateActualEarningRate', function(earningRate)
    SendNUIMessage({
        action = 'updateActualEarningRate',
        earningRate = earningRate
    })
end)

RegisterNetEvent('windturbine:updateWorkTime')
AddEventHandler('windturbine:updateWorkTime', function(workHours, maxHours)
    SendNUIMessage({
        action = 'updateWorkTime',
        workHours = workHours,
        maxHours = maxHours
    })
end)

RegisterNetEvent('windturbine:resetWorkLimit')
AddEventHandler('windturbine:resetWorkLimit', function()
    -- Reset work limit khi ngày mới
    SendNUIMessage({
        action = 'resetWorkLimit'
    })
end)

RegisterNetEvent('windturbine:stopTurbine')
AddEventHandler('windturbine:stopTurbine', function()
    isOnDuty = false
    
    -- Reset UI về trạng thái ban đầu
    SendNUIMessage({
        action = 'resetToInitialState'
    })
    
    CloseUI()
end)

RegisterNetEvent('windturbine:workLimitReached')
AddEventHandler('windturbine:workLimitReached', function()
    -- Gửi thông báo đến UI để disable nút Start
    SendNUIMessage({
        action = 'workLimitReached'
    })
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
