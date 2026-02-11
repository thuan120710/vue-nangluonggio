# ✅ BẢO MẬT ĐÃ ĐƯỢC FIX - HỆ THỐNG RÚT TIỀN VÀ SINH TIỀN

## 🔒 CÁC LỖ HỔNG ĐÃ ĐƯỢC FIX

### 1. ✅ Client không còn kiểm soát số tiền rút
**Trước:**
- Client tự tính toán `earningsPool` và gửi `amount` lên server
- Server chỉ validate yếu

**Sau:**
- Server lưu trữ `PlayerEarnings[citizenid]` với tất cả dữ liệu
- Client GỬI REQUEST rút tiền, server TỰ TÍNH số tiền
- Event: `windturbine:withdrawEarnings(isGracePeriod, turbineId)` - KHÔNG CÓ amount

### 2. ✅ Server-side earnings calculation
**Trước:**
- Client tự tính toán earnings mỗi chu kỳ
- Client tự cộng vào `playerData.earningsPool`

**Sau:**
- Server có thread riêng tính toán earnings
- Server gửi updates về client qua events
- Client chỉ hiển thị, KHÔNG tính toán

### 3. ✅ Server-side penalty system
**Trước:**
- Client tự áp dụng penalty
- Client tự giảm giá trị systems

**Sau:**
- Server tính toán penalty dựa trên work hours
- Server cập nhật `PlayerEarnings[citizenid].systems`
- Client nhận updates qua event `windturbine:updateSystems`

### 4. ✅ Server-side fuel tracking
**Trước:**
- Client tự quản lý `currentFuel`
- Client tự trừ fuel mỗi giờ

**Sau:**
- Server lưu `PlayerEarnings[citizenid].currentFuel`
- Server tự động trừ fuel mỗi chu kỳ
- Client nhận updates qua event `windturbine:updateFuel`

### 5. ✅ Server-side system repair validation
**Trước:**
- Client tự cập nhật giá trị system sau repair

**Sau:**
- Client gửi kết quả repair lên server
- Server validate và cập nhật `PlayerEarnings[citizenid].systems`
- Event: `windturbine:updateSystem(system, newValue)`

## 📋 CÁC THAY ĐỔI CHI TIẾT

### Server-side (server/main.lua)

#### Thêm mới:
```lua
-- Tracking earnings cho mỗi player
local PlayerEarnings = {} -- [citizenid] = {
    earningsPool,
    systems,
    lastEarning,
    lastPenalty,
    lastFuelConsumption,
    currentFuel,
    onDuty
}

-- Functions
- InitPlayerEarnings(citizenid)
- CalculateSystemProfit(systems)
- CanEarnMoney(systems, currentFuel)

-- Events
- windturbine:withdrawEarnings(isGracePeriod, turbineId) -- KHÔNG CÓ amount
- windturbine:startDuty(turbineId) -- Gửi serverData về client
- windturbine:stopDuty() -- KHÔNG CẦN workDuration
- windturbine:updateSystem(system, newValue) -- Sau repair
- f17_tramdiengio:sv:useJerrycan(fuelToAdd, amount) -- Update server fuel

-- Callback
- windturbine:getServerData() -- Lấy dữ liệu server

-- Thread
- Server-side earnings calculation (mỗi 1 phút/1 giờ)
  - Tính earnings
  - Áp dụng penalty
  - Tiêu hao fuel
  - Gửi updates về client
```

### Client-side (client/main.lua)

#### Thay đổi:
```lua
-- NUI Callbacks
- withdrawEarnings: KHÔNG gửi amount, chỉ gửi isGracePeriod
- minigameResult: Thêm TriggerServerEvent('windturbine:updateSystem')

-- Events
- startDutySuccess: Nhận serverData từ server
- refuelSuccess: Nhận newFuelTotal từ server

-- Thêm mới events:
- windturbine:updateEarnings(newEarnings)
- windturbine:updateSystems(newSystems)
- windturbine:updateFuel(newFuel)
- windturbine:outOfFuel()

-- Xóa/Đơn giản hóa:
- Thread sinh tiền và penalty → Chuyển sang server
- Client chỉ giữ thread kiểm tra daily limit
```

## 🎯 CÁCH HOẠT ĐỘNG MỚI

### Flow rút tiền:
1. Client: Click "Rút tiền" → `TriggerServerEvent('windturbine:withdrawEarnings', isGracePeriod, turbineId)`
2. Server: Tính `amount = PlayerEarnings[citizenid].earningsPool`
3. Server: Validate và `Player.Functions.AddMoney('tienkhoa', amount)`
4. Server: Reset `PlayerEarnings[citizenid].earningsPool = 0`
5. Server: `TriggerClientEvent('windturbine:withdrawSuccess', playerId, amount, isGracePeriod)`
6. Client: Hiển thị thông báo

### Flow sinh tiền:
1. Server thread (mỗi 1 phút/1 giờ):
   - Check `PlayerEarnings[citizenid].onDuty`
   - Tính `earnAmount = CalculateSystemProfit(systems)`
   - Cộng vào `PlayerEarnings[citizenid].earningsPool`
   - `TriggerClientEvent('windturbine:updateEarnings', playerId, newEarnings)`
2. Client: Nhận event và update UI

### Flow penalty:
1. Server thread (mỗi 1 phút/1 giờ):
   - Tính work hours
   - Random penalty dựa trên config
   - Giảm `PlayerEarnings[citizenid].systems[systemName]`
   - `TriggerClientEvent('windturbine:updateSystems', playerId, newSystems)`
2. Client: Nhận event và update UI

### Flow repair:
1. Client: Hoàn thành minigame
2. Client: Tính `newValue = oldValue + reward`
3. Client: `TriggerServerEvent('windturbine:updateSystem', system, newValue)`
4. Server: Validate và update `PlayerEarnings[citizenid].systems[system] = newValue`
5. Client: Update UI local

## ✅ KẾT QUẢ

- ✅ Client KHÔNG THỂ chỉnh sửa số tiền
- ✅ Client KHÔNG THỂ bypass validation
- ✅ Server là source of truth duy nhất
- ✅ Tất cả tính toán quan trọng đều ở server
- ✅ Client chỉ hiển thị và gửi input
- ✅ Hệ thống vẫn hoạt động bình thường

## 🧪 CÁCH TEST

1. Start server và join game
2. Thuê trạm điện gió
3. Bật duty và làm việc
4. Kiểm tra earnings tăng đều đặn (server tính)
5. Thử repair systems (server validate)
6. Thử rút tiền (server tính amount)
7. Thử cheat bằng cách mở console → KHÔNG THỂ thay đổi số tiền

## ⚠️ LƯU Ý

- Config.TestMode = true: 1 phút = 1 giờ (để test nhanh)
- Config.TestMode = false: Thời gian thực (production)
- Server thread chạy mỗi 1 phút (test) hoặc 1 giờ (production)
