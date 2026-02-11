# 🔧 HƯỚNG DẪN REFACTOR CHI TIẾT

## ❌ VẤN ĐỀ PHÁT HIỆN

### 1. Function `CheckAndResetDailyHours()` bị duplicate:
- **Định nghĩa 1:** Dòng ~135 (GỌI `GetCurrentDay()` nhưng function chưa được định nghĩa!)
- **Định nghĩa 2:** Dòng ~521 (Sau khi `GetCurrentDay()` đã được định nghĩa)

### 2. Function `GetCurrentDay()` định nghĩa muộn:
- **Định nghĩa:** Dòng ~509
- **Được gọi:** Dòng ~137 (TRƯỚC KHI ĐỊNH NGHĨA!)

### 3. Function `ValidateWithdrawAmount()` không dùng:
- Định nghĩa ở dòng ~541
- Không được gọi ở đâu cả (đã thay bằng logic mới)

---

## ✅ GIẢI PHÁP

### Bước 1: Di chuyển `GetCurrentDay()` lên đầu
```lua
-- Dòng ~10 (sau data structures)
local function GetCurrentDay()
    local timestamp = os.time()
    local vietnamOffset = (7 * 3600) - (6 * 3600)
    local adjustedTime = timestamp + vietnamOffset
    local days = math.floor(adjustedTime / 86400)
    return tostring(days)
end
```

### Bước 2: Xóa định nghĩa duplicate của `CheckAndResetDailyHours()`
- Giữ định nghĩa ở dòng ~135
- Xóa định nghĩa ở dòng ~521

### Bước 3: Xóa `ValidateWithdrawAmount()`
- Xóa toàn bộ function (dòng ~541-565)

### Bước 4: Tổ chức lại theo sections

---

## 📝 CẤU TRÚC MỚI (CHI TIẾT)

```lua
-- ============================================
-- SECTION 1: DATA STRUCTURES
-- ============================================
local TurbineRentals = {}
local TurbineExpiryGracePeriod = {}
local PlayerWorkData = {}
local PlayerEarnings = {}

-- ============================================
-- SECTION 2: UTILITY FUNCTIONS
-- ============================================

-- Get current day (reset at 6:00 AM Vietnam time)
local function GetCurrentDay()
    -- Implementation
end

-- Count jerrycan items
local function GetJerrycanCount(Player)
    -- Implementation
end

-- ============================================
-- SECTION 3: CALCULATION FUNCTIONS
-- ============================================

-- Calculate system profit based on system values
local function CalculateSystemProfit(systems)
    -- Implementation
end

-- Check if turbine can earn money
local function CanEarnMoney(systems, currentFuel)
    -- Implementation
end

-- ============================================
-- SECTION 4: PLAYER DATA MANAGEMENT
-- ============================================

-- Initialize player earnings data
local function InitPlayerEarnings(citizenid)
    -- Implementation
end

-- Check and reset daily work hours
local function CheckAndResetDailyHours(citizenid)
    -- Implementation
end

-- ============================================
-- SECTION 5: RENTAL SYSTEM
-- ============================================

-- Broadcast rental status via StateBag
local function BroadcastRentalStatus(turbineId)
    -- Implementation
end

-- Check rental expiry and handle grace period
local function CheckRentalExpiry(turbineId)
    -- Implementation
end

-- ============================================
-- SECTION 6: INITIALIZATION
-- ============================================
CreateThread(function()
    -- Reset all turbines on script start
end)

-- ============================================
-- SECTION 7: EVENTS - RENTAL MANAGEMENT
-- ============================================

-- Event: Rent turbine
RegisterNetEvent('windturbine:rentTurbine')

-- Event: Withdraw earnings
RegisterNetEvent('windturbine:withdrawEarnings')

-- ============================================
-- SECTION 8: EVENTS - WORK MANAGEMENT
-- ============================================

-- Event: Start duty
RegisterNetEvent('windturbine:startDuty')

-- Event: Stop duty
RegisterNetEvent('windturbine:stopDuty')

-- Event: Repair system
RegisterNetEvent('windturbine:repairSystem')

-- Event: Update system (deprecated but kept for compatibility)
RegisterNetEvent('windturbine:updateSystem')

-- ============================================
-- SECTION 9: EVENTS - FUEL MANAGEMENT
-- ============================================

-- Event: Use jerrycan
RegisterNetEvent('f17_tramdiengio:sv:useJerrycan')

-- ============================================
-- SECTION 10: EVENTS - NOTIFICATIONS
-- ============================================

-- Event: Send phone notification
RegisterNetEvent('windturbine:sendPhoneNotification')

-- ============================================
-- SECTION 11: CALLBACKS
-- ============================================

-- Callback: Get server data
QBCore.Functions.CreateCallback('windturbine:getServerData')

-- Callback: Get daily work hours
QBCore.Functions.CreateCallback('windturbine:getDailyWorkHours')

-- Callback: Check if player has jerrycan
QBCore.Functions.CreateCallback('windturbine:hasJerrycan')

-- Callback: Get jerrycan count
QBCore.Functions.CreateCallback('windturbine:getJerrycanCount')

-- Callback: Check money
QBCore.Functions.CreateCallback('windturbine:checkMoney')

-- ============================================
-- SECTION 12: BACKGROUND THREADS
-- ============================================

-- Thread: Check rental expiry
CreateThread(function()
    -- Check every 30 seconds
end)

-- Thread: Calculate earnings and apply penalties
CreateThread(function()
    -- Run every 1 minute (test) / 1 hour (production)
end)
```

---

## 🎯 CÁC THAY ĐỔI CỤ THỂ

### 1. Di chuyển functions:
```
GetCurrentDay: Dòng 509 → Dòng 10
```

### 2. Xóa duplicates:
```
CheckAndResetDailyHours: Xóa định nghĩa ở dòng 521
```

### 3. Xóa unused:
```
ValidateWithdrawAmount: Xóa toàn bộ (dòng 541-565)
```

### 4. Thêm section headers:
```lua
-- ============================================
-- SECTION X: Tên section
-- ============================================
```

### 5. Thêm function comments:
```lua
-- Function description
-- @param param1 Type - Description
-- @return Type - Description
local function FunctionName(param1)
```

---

## ⚠️ LƯU Ý QUAN TRỌNG

1. **Không thay đổi logic** - Chỉ di chuyển và tổ chức lại
2. **Giữ nguyên tên functions** - Để không break code
3. **Giữ nguyên tên events** - Để client vẫn hoạt động
4. **Test sau mỗi thay đổi** - Đảm bảo không lỗi

---

## 📊 KẾT QUẢ

### Trước:
- ❌ Functions không theo thứ tự
- ❌ Có duplicate code
- ❌ Khó tìm function cần thiết
- ❌ Không có structure rõ ràng

### Sau:
- ✅ Functions theo thứ tự logic
- ✅ Không có duplicate
- ✅ Dễ tìm function (theo sections)
- ✅ Structure rõ ràng, professional

---

## 🚀 THỰC HIỆN

Bạn có muốn tôi thực hiện refactor ngay không?
Tôi sẽ:
1. Xóa duplicates
2. Di chuyển functions
3. Thêm sections
4. Thêm comments

**Lưu ý:** Code sẽ dễ đọc hơn NHIỀU nhưng logic hoàn toàn giống nhau!
