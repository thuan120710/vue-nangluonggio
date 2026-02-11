# KẾ HOẠCH FIX LỖ HỔNG BẢO MẬT - EARNINGS SYSTEM

## 🚨 VẤN ĐỀ HIỆN TẠI

### 1. Logic tính tiền ở CLIENT (NGUY HIỂM!)

**File: `client/main.lua`**

#### Vị trí code có vấn đề:

**Dòng 60-63: Lưu earnings pool ở client**
```lua
local playerData = {
    -- ...
    earningsPool = 0,  -- ❌ CLIENT LƯU TIỀN - HACK ĐƯỢC!
    lastEarning = 0,
    lastPenalty = 0,
}
```

**Dòng 241-256: Tính lợi nhuận ở client**
```lua
local function CalculateSystemProfit()
    local systems = playerData.systems
    local totalProfit = 0
    
    for systemName, value in pairs(systems) do
        local systemProfit = Config.BaseSalary * (Config.SystemProfitContribution / 100)  -- ❌ CLIENT TÍNH TIỀN
        
        if value <= 30 then
            systemProfit = 0
        else
            systemProfit = systemProfit * (value / 100)
        end
        
        totalProfit = totalProfit + systemProfit
    end
    
    return totalProfit
end
```

**Dòng 280-290: Tính earnings ở client**
```lua
local function CalculateEarnings()
    if not playerData.onDuty then return 0 end
    
    local canEarn, status = CanEarnMoney()
    if not canEarn then return 0 end
    
    local earnPerMinute = CalculateSystemProfit()  -- ❌ CLIENT QUYẾT ĐỊNH TIỀN
    
    return earnPerMinute
end
```

**Dòng 958-963: Cộng tiền vào pool ở client**
```lua
if earnings > 0 then
    playerData.earningsPool = playerData.earningsPool + earnings  -- ❌ CLIENT TỰ CỘNG TIỀN
    playerData.lastEarning = currentTime
    
    currentEarnings = playerData.earningsPool
    -- ...
end
```

**Dòng 649-667: Rút tiền - client gửi amount lên server**
```lua
RegisterNUICallback('withdrawEarnings', function(data, cb)
    local amount = math.floor(playerData.earningsPool)  -- ❌ CLIENT QUYẾT ĐỊNH SỐ TIỀN RÚT
    
    if amount <= 0 then
        no:Notify('❌ Không có tiền để rút!', 'error')
        cb('ok')
        return
    end
    
    -- ...
    
    -- Gửi request lên server (server sẽ validate và trả về event để reset earnings pool)
    TriggerServerEvent('windturbine:withdrawEarnings', amount, isGracePeriod, turbineId, currentWorkHours)  -- ❌ GỬI AMOUNT TỪ CLIENT
    
    PlaySound(-1, "PICK_UP", "HUD_FRONTEND_DEFAULT_SOUNDSET", 0, 0, 1)
    cb('ok')
end)
```

---

### 2. Server validation YẾU

**File: `server/main.lua`**

**Dòng 194-280: Event rút tiền**
```lua
RegisterNetEvent('windturbine:withdrawEarnings')
AddEventHandler('windturbine:withdrawEarnings', function(amount, isGracePeriod, turbineId, clientWorkHours)
    local playerId = source
    local Player = QBCore.Functions.GetPlayer(playerId)
    
    -- ...
    
    -- ANTI-CHEAT: Validate số tiền với thời gian làm việc (chỉ khi không phải grace period)
    if not isGracePeriod and clientWorkHours then
        local isValid, reason = ValidateWithdrawAmount(citizenid, amount, clientWorkHours)
        
        if not isValid then
            -- Reject
            return
        end
    end
    
    -- ❌ Xử lý rút tiền trong grace period - KHÔNG CÓ VALIDATION!
    if isGracePeriod and turbineId then
        -- Không validate amount gì cả!
    end
    
    -- ❌ Rút tiền - Tin tưởng amount từ client
    Player.Functions.AddMoney('tienkhoa', amount)  -- NGUY HIỂM!
    TriggerClientEvent('windturbine:withdrawSuccess', playerId, amount, isGracePeriod)
end)
```

**Dòng 163-191: Validation function**
```lua
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
    if timeDiff > (clientWorkHours * 0.05 + 0.1) then
        return false, "TIME_MISMATCH"
    end
    
    -- ❌ Tính max earnings - VẪN DỰA VÀO CLIENT DATA
    local maxPossibleEarnings = clientWorkHours * Config.BaseSalary * 1.2
    
    if amount > maxPossibleEarnings then
        return false, "AMOUNT_TOO_HIGH"
    end
    
    return true, "OK"
end
```

---

## 🎯 CÁC LỖ HỔNG CỤ THỂ

### Lỗ hổng 1: Chỉnh sửa earnings pool
**Cách hack:**
```lua
-- Hacker inject code vào client
playerData.earningsPool = 999999999
```
**Hậu quả:** Rút tiền không giới hạn

---

### Lỗ hổng 2: Chỉnh sửa BaseSalary
**Cách hack:**
```lua
-- Hacker inject code vào client
Config.BaseSalary = 999999999
```
**Hậu quả:** Mỗi chu kỳ kiếm hàng tỷ

---

### Lỗ hổng 3: Bypass validation khi grace period
**Cách hack:**
```lua
-- Hacker gửi event với isGracePeriod = true
TriggerServerEvent('windturbine:withdrawEarnings', 999999999, true, 1, 0)
```
**Hậu quả:** Server không validate amount, thêm tiền trực tiếp!

---

### Lỗ hổng 4: Chỉnh sửa system values
**Cách hack:**
```lua
-- Hacker inject code vào client
playerData.systems = {
    electrical = 100,
    mechanical = 100,
    cooling = 100,
    hydraulic = 100,
    safety = 100
}
```
**Hậu quả:** Luôn kiếm tiền tối đa, không cần sửa chữa

---

### Lỗ hổng 5: Gửi clientWorkHours giả
**Cách hack:**
```lua
-- Hacker gửi workHours cao
TriggerServerEvent('windturbine:withdrawEarnings', 10000000, false, nil, 1000)
-- Server tính: maxPossibleEarnings = 1000 * 5000 * 1.2 = 6,000,000
-- Cho phép rút 6 triệu!
```
**Hậu quả:** Bypass validation bằng cách gửi workHours tương ứng

---

## ✅ GIẢI PHÁP: DI CHUYỂN LOGIC SANG SERVER

### Kiến trúc mới:

```
CLIENT                          SERVER
------                          ------
[UI Display]  <----------->  [Earnings Pool Storage]
[Send Events]               [Calculate Earnings]
[Receive Updates]           [Validate Everything]
                            [Add Money to Account]
```

---

## 📝 CÁC THAY ĐỔI CẦN THỰC HIỆN

### 1. SERVER (server/main.lua)

#### Thêm vào đầu file (sau dòng 17):
```lua
-- Dữ liệu earnings pool (lưu ở server - AN TOÀN!)
local PlayerEarnings = {} -- [citizenid] = {earningsPool, systems, currentFuel, lastEarning, onDuty}
```

#### Thêm các hàm tính toán (sau dòng 90):
```lua
-- ============================================
-- EARNINGS CALCULATION (SERVER-SIDE)
-- ============================================

-- Tính hiệu suất từ 5 hệ thống
local function CalculateEfficiency(systems)
    if not systems then return 0 end
    
    local total = 0
    for _, value in pairs(systems) do
        total = total + value
    end
    
    return total / 5
end

-- Tính lợi nhuận từ từng hệ thống
local function CalculateSystemProfit(systems)
    if not systems then return 0 end
    
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

-- Kiểm tra điều kiện sinh tiền
local function CanEarnMoney(systems, fuel)
    -- Kiểm tra xăng
    if fuel <= 0 then
        return false, "OUT_OF_FUEL"
    end
    
    -- Kiểm tra hệ thống
    local below30 = 0
    for _, value in pairs(systems) do
        if value <= 30 then below30 = below30 + 1 end
    end
    
    if below30 >= 3 then 
        return false, "STOPPED"
    end
    
    return true, "RUNNING"
end

-- Tính earnings
local function CalculateEarnings(citizenid)
    local data = PlayerEarnings[citizenid]
    if not data or not data.onDuty then return 0 end
    
    local canEarn, status = CanEarnMoney(data.systems, data.currentFuel)
    if not canEarn then return 0 end
    
    return CalculateSystemProfit(data.systems)
end
```

#### Thêm event khởi tạo player data (sau các hàm trên):
```lua
-- Event: Client gửi system data lên server
RegisterNetEvent('windturbine:syncSystemData')
AddEventHandler('windturbine:syncSystemData', function(systems, fuel, onDuty)
    local playerId = source
    local Player = QBCore.Functions.GetPlayer(playerId)
    if not Player then return end
    
    local citizenid = Player.PlayerData.citizenid
    
    -- Khởi tạo hoặc cập nhật data
    if not PlayerEarnings[citizenid] then
        PlayerEarnings[citizenid] = {
            earningsPool = 0,
            systems = systems,
            currentFuel = fuel,
            lastEarning = os.time(),
            onDuty = onDuty
        }
    else
        PlayerEarnings[citizenid].systems = systems
        PlayerEarnings[citizenid].currentFuel = fuel
        PlayerEarnings[citizenid].onDuty = onDuty
    end
end)

-- Event: Client bắt đầu làm việc
RegisterNetEvent('windturbine:startDuty')
AddEventHandler('windturbine:startDuty', function()
    local playerId = source
    local Player = QBCore.Functions.GetPlayer(playerId)
    if not Player then return end
    
    local citizenid = Player.PlayerData.citizenid
    
    if PlayerEarnings[citizenid] then
        PlayerEarnings[citizenid].onDuty = true
        PlayerEarnings[citizenid].lastEarning = os.time()
    end
end)

-- Event: Client kết thúc làm việc
RegisterNetEvent('windturbine:stopDutyServer')
AddEventHandler('windturbine:stopDutyServer', function()
    local playerId = source
    local Player = QBCore.Functions.GetPlayer(playerId)
    if not Player then return end
    
    local citizenid = Player.PlayerData.citizenid
    
    if PlayerEarnings[citizenid] then
        PlayerEarnings[citizenid].onDuty = false
    end
end)

-- Thread: Tính earnings mỗi chu kỳ (SERVER TÍNH!)
CreateThread(function()
    while true do
        Wait(Config.EarningCycle)
        
        for citizenid, data in pairs(PlayerEarnings) do
            if data.onDuty then
                local currentTime = os.time()
                
                -- Kiểm tra đã đủ thời gian chưa
                if currentTime - data.lastEarning >= (Config.EarningCycle / 1000) then
                    local earnings = CalculateEarnings(citizenid)
                    
                    if earnings > 0 then
                        data.earningsPool = data.earningsPool + earnings
                        data.lastEarning = currentTime
                        
                        -- Gửi update về client để hiển thị
                        local Player = QBCore.Functions.GetPlayerByCitizenId(citizenid)
                        if Player then
                            local efficiency = CalculateEfficiency(data.systems)
                            TriggerClientEvent('windturbine:updateEarnings', Player.PlayerData.source, data.earningsPool, earnings, efficiency)
                        end
                    end
                end
            end
        end
    end
end)

-- Event: Client request lấy earnings hiện tại
RegisterNetEvent('windturbine:requestEarnings')
AddEventHandler('windturbine:requestEarnings', function()
    local playerId = source
    local Player = QBCore.Functions.GetPlayer(playerId)
    if not Player then return end
    
    local citizenid = Player.PlayerData.citizenid
    local earnings = PlayerEarnings[citizenid] and PlayerEarnings[citizenid].earningsPool or 0
    
    TriggerClientEvent('windturbine:receiveEarnings', playerId, earnings)
end)
```

#### Sửa event withdrawEarnings (thay thế từ dòng 194-280):
```lua
-- Event: Rút tiền (SERVER LẤY AMOUNT TỪ POOL CỦA MÌNH!)
RegisterNetEvent('windturbine:withdrawEarnings')
AddEventHandler('windturbine:withdrawEarnings', function(isGracePeriod, turbineId)
    local playerId = source
    local Player = QBCore.Functions.GetPlayer(playerId)
    
    if not Player then
        TriggerClientEvent('windturbine:notify', playerId, '❌ Lỗi hệ thống!', 'error')
        return
    end
    
    local citizenid = Player.PlayerData.citizenid
    
    -- ✅ SERVER TỰ LẤY AMOUNT TỪ POOL - CLIENT KHÔNG GỬI!
    local amount = 0
    
    if isGracePeriod and turbineId then
        -- Rút tiền grace period - lấy từ rental data
        CheckRentalExpiry(turbineId)
        local graceData = TurbineExpiryGracePeriod[turbineId]
        
        if not graceData then
            TriggerClientEvent('windturbine:notify', playerId, '❌ Không có tiền để rút!', 'error')
            return
        end
        
        -- Kiểm tra owner
        if graceData.citizenid ~= citizenid then
            TriggerClientEvent('windturbine:notify', playerId, '❌ Bạn không phải chủ trạm này!', 'error')
            return
        end
        
        -- Lấy amount từ server pool
        if PlayerEarnings[citizenid] then
            amount = math.floor(PlayerEarnings[citizenid].earningsPool)
        end
        
        -- Reset trạm
        TurbineExpiryGracePeriod[turbineId] = nil
        BroadcastRentalStatus(turbineId)
    else
        -- Rút tiền bình thường
        if not PlayerEarnings[citizenid] then
            TriggerClientEvent('windturbine:notify', playerId, '❌ Không có dữ liệu!', 'error')
            return
        end
        
        amount = math.floor(PlayerEarnings[citizenid].earningsPool)
    end
    
    -- Kiểm tra số tiền
    if amount <= 0 then
        TriggerClientEvent('windturbine:notify', playerId, '❌ Không có tiền để rút!', 'error')
        return
    end
    
    -- ✅ Rút tiền - Thêm tiền vào tài khoản
    Player.Functions.AddMoney('tienkhoa', amount)
    
    -- ✅ Reset earnings pool trên server
    if PlayerEarnings[citizenid] then
        PlayerEarnings[citizenid].earningsPool = 0
    end
    
    TriggerClientEvent('windturbine:withdrawSuccess', playerId, amount, isGracePeriod)
    
    -- Gửi phone notification
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
```

---

### 2. CLIENT (client/main.lua)

#### Sửa playerData (dòng 60):
```lua
local playerData = {
    -- ... giữ nguyên các field khác
    -- ❌ XÓA: earningsPool = 0,  -- Không lưu ở client nữa!
    lastEarning = 0,
    lastPenalty = 0,
}
```

#### Thêm biến lưu earnings từ server (sau playerData):
```lua
-- Earnings từ server (chỉ để hiển thị UI)
local serverEarnings = 0
```

#### Xóa các hàm tính toán (dòng 236-290):
```lua
-- ❌ XÓA CÁC HÀM NÀY:
-- local function CalculateSystemProfit()
-- local function CanEarnMoney()
-- local function CalculateEarnings()
```

#### Thêm hàm sync data lên server (sau các hàm helper):
```lua
-- Sync system data lên server
local function SyncSystemDataToServer()
    TriggerServerEvent('windturbine:syncSystemData', playerData.systems, playerData.currentFuel, playerData.onDuty)
end
```

#### Sửa event bắt đầu làm việc (tìm RegisterNetEvent('windturbine:startDuty')):
```lua
RegisterNetEvent('windturbine:startDuty')
AddEventHandler('windturbine:startDuty', function()
    playerData.onDuty = true
    isOnDuty = true
    playerData.workStartTime = GetCurrentTime()
    
    -- ✅ Gửi lên server
    TriggerServerEvent('windturbine:startDuty')
    SyncSystemDataToServer()
    
    -- ... giữ nguyên phần còn lại
end)
```

#### Sửa callback withdrawEarnings (dòng 649):
```lua
RegisterNUICallback('withdrawEarnings', function(data, cb)
    -- ❌ XÓA: local amount = math.floor(playerData.earningsPool)
    -- ✅ SỬ DỤNG: serverEarnings
    local amount = math.floor(serverEarnings)
    
    if amount <= 0 then
        no:Notify('❌ Không có tiền để rút!', 'error')
        cb('ok')
        return
    end
    
    local isGracePeriod = data.isGracePeriod or false
    local turbineId = data.turbineId
    
    -- ✅ KHÔNG GỬI AMOUNT - Server tự lấy!
    TriggerServerEvent('windturbine:withdrawEarnings', isGracePeriod, turbineId)
    
    PlaySound(-1, "PICK_UP", "HUD_FRONTEND_DEFAULT_SOUNDSET", 0, 0, 1)
    cb('ok')
end)
```

#### Thêm event nhận earnings từ server (sau các RegisterNetEvent khác):
```lua
-- Event: Nhận earnings update từ server
RegisterNetEvent('windturbine:updateEarnings')
AddEventHandler('windturbine:updateEarnings', function(earningsPool, earnings, efficiency)
    serverEarnings = earningsPool
    currentEarnings = earningsPool
    
    -- Cập nhật UI
    SendNUIMessage({
        action = 'updateEarnings',
        earnings = currentEarnings
    })
    
    -- Thông báo
    if efficiency >= 80 then
        no:Notify(string.format('💵 +$%d IC | Hiệu suất tuyệt vời!', math.floor(earnings)), 'success', 2000)
    elseif efficiency >= 50 then
        no:Notify(string.format('💵 +$%d IC', math.floor(earnings)), 'primary', 2000)
    end
end)

-- Event: Nhận earnings hiện tại từ server
RegisterNetEvent('windturbine:receiveEarnings')
AddEventHandler('windturbine:receiveEarnings', function(earnings)
    serverEarnings = earnings
    currentEarnings = earnings
    
    SendNUIMessage({
        action = 'updateEarnings',
        earnings = currentEarnings
    })
end)
```

#### Sửa event withdrawSuccess (tìm RegisterNetEvent('windturbine:withdrawSuccess')):
```lua
RegisterNetEvent('windturbine:withdrawSuccess')
AddEventHandler('windturbine:withdrawSuccess', function(amount, isGracePeriod)
    if isGracePeriod then
        -- Reset toàn bộ khi rút tiền grace period
        -- ... giữ nguyên logic reset
    else
        -- ✅ Reset earnings từ server
        serverEarnings = 0
        currentEarnings = 0
    end
    
    -- ... giữ nguyên phần còn lại
end)
```

#### Xóa phần tính earnings trong main thread (dòng 965-1000):
```lua
-- ❌ XÓA TOÀN BỘ PHẦN NÀY:
-- -- Sinh tiền mỗi chu kỳ
-- if currentTime - playerData.lastEarning >= Config.EarningCycle then
--     local canEarn, status = CanEarnMoney()
--     if canEarn then
--         local earnings = CalculateEarnings()
--         if earnings > 0 then
--             playerData.earningsPool = playerData.earningsPool + earnings
--             ...
--         end
--     end
-- end
```

#### Thêm sync định kỳ trong main thread (thay thế phần trên):
```lua
-- Sync system data lên server mỗi 5 giây
if currentTime - lastSyncTime >= 5000 then
    SyncSystemDataToServer()
    lastSyncTime = currentTime
end
```

#### Thêm biến lastSyncTime (đầu main thread):
```lua
CreateThread(function()
    local lastSyncTime = 0
    
    while true do
        -- ... code hiện tại
    end
end)
```

#### Sửa hàm OpenUI (tìm function OpenUI()):
```lua
local function OpenUI()
    -- ... code hiện tại
    
    -- ✅ Request earnings từ server
    TriggerServerEvent('windturbine:requestEarnings')
    
    -- ... code hiện tại
end
```

---

## 📊 SO SÁNH TRƯỚC VÀ SAU

### TRƯỚC (Không an toàn):
```
CLIENT                                    SERVER
------                                    ------
playerData.earningsPool = 0          ❌ Không lưu gì
CalculateEarnings() → earnings       ❌ Không tính gì
earningsPool += earnings             ❌ Không kiểm soát
TriggerServerEvent(amount) --------> ⚠️ Nhận amount từ client
                                     ⚠️ Validate yếu
                                     Player.AddMoney(amount)
```

### SAU (An toàn):
```
CLIENT                                    SERVER
------                                    ------
❌ Không lưu earnings                 ✅ PlayerEarnings[citizenid]
❌ Không tính earnings                ✅ CalculateEarnings()
SyncSystemData() ------------------> ✅ Nhận system data
                                     ✅ Thread tính earnings
                                     ✅ earningsPool += earnings
<---------------------- UpdateEarnings   (Gửi về client để hiển thị)
serverEarnings = value (chỉ hiển thị)
TriggerServerEvent() --------------> ✅ Không gửi amount
                                     ✅ Server lấy từ pool của mình
                                     ✅ Player.AddMoney(serverAmount)
                                     ✅ Reset pool
```

---

## ⚠️ LƯU Ý KHI THỰC HIỆN

1. **Backup code cũ** trước khi sửa
2. **Test kỹ** trên server test trước
3. **Xóa dữ liệu cũ** của players (earnings pool cũ ở client không còn giá trị)
4. **Thông báo players** về maintenance
5. **Monitor logs** sau khi deploy để phát hiện lỗi

---

## 🎯 KẾT QUẢ SAU KHI FIX

✅ Hacker không thể chỉnh sửa earnings pool (lưu ở server)
✅ Hacker không thể chỉnh sửa BaseSalary (server tính)
✅ Hacker không thể bypass validation (server kiểm soát toàn bộ)
✅ Hacker không thể gửi amount giả (server không nhận amount từ client)
✅ Grace period withdraw cũng được validate đúng

---

## 📞 HỖ TRỢ

Nếu cần hỗ trợ khi implement, hãy hỏi về:
- Cách test từng phần
- Cách migrate dữ liệu cũ
- Cách rollback nếu có vấn đề
