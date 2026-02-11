# 🔧 KẾ HOẠCH REFACTOR CODE

## 📋 VẤN ĐỀ HIỆN TẠI

### Server (server/main.lua):
1. ❌ `GetCurrentDay()` - Định nghĩa 2 lần (dòng ~135 và ~509)
2. ❌ `CheckAndResetDailyHours()` - Định nghĩa 2 lần (dòng ~135 và ~521)
3. ❌ `ValidateWithdrawAmount()` - Không dùng nữa nhưng vẫn còn
4. ❌ Các helper functions không được nhóm theo chức năng
5. ❌ Code dài ~1000 dòng, khó đọc

### Client (client/main.lua):
1. ❌ Code dài ~1300 dòng
2. ❌ Nhiều callbacks NUI không được nhóm
3. ❌ Threads không được tổ chức rõ ràng

---

## 🎯 MỤC TIÊU REFACTOR

### 1. Xóa code duplicate
- Xóa các function định nghĩa 2 lần
- Xóa code không dùng nữa

### 2. Tổ chức code theo modules
```
=== CONSTANTS & DATA ===
- Global variables
- Data structures

=== HELPER FUNCTIONS ===
- Calculation helpers
- Validation helpers
- Utility helpers

=== CORE LOGIC ===
- Rental system
- Earnings system
- Fuel system

=== EVENTS & CALLBACKS ===
- Server events
- Client callbacks

=== THREADS ===
- Background tasks
```

### 3. Cải thiện naming
- Tên function rõ ràng
- Comment đầy đủ
- Nhóm logic liên quan

---

## 📝 CẤU TRÚC MỚI

### Server/main.lua:
```lua
-- ============================================
-- SECTION 1: DATA STRUCTURES
-- ============================================
local TurbineRentals = {}
local PlayerEarnings = {}
local PlayerWorkData = {}

-- ============================================
-- SECTION 2: UTILITY HELPERS
-- ============================================
local function GetCurrentDay() end
local function GetJerrycanCount() end

-- ============================================
-- SECTION 3: CALCULATION HELPERS
-- ============================================
local function CalculateSystemProfit() end
local function CanEarnMoney() end

-- ============================================
-- SECTION 4: VALIDATION HELPERS
-- ============================================
local function ValidateTurbineId() end
local function CheckOwnership() end

-- ============================================
-- SECTION 5: PLAYER DATA MANAGEMENT
-- ============================================
local function InitPlayerEarnings() end
local function CheckAndResetDailyHours() end

-- ============================================
-- SECTION 6: RENTAL SYSTEM
-- ============================================
local function BroadcastRentalStatus() end
local function CheckRentalExpiry() end

-- ============================================
-- SECTION 7: EVENTS - RENTAL
-- ============================================
RegisterNetEvent('windturbine:rentTurbine')
RegisterNetEvent('windturbine:withdrawEarnings')

-- ============================================
-- SECTION 8: EVENTS - WORK
-- ============================================
RegisterNetEvent('windturbine:startDuty')
RegisterNetEvent('windturbine:stopDuty')
RegisterNetEvent('windturbine:repairSystem')

-- ============================================
-- SECTION 9: EVENTS - FUEL
-- ============================================
RegisterNetEvent('f17_tramdiengio:sv:useJerrycan')

-- ============================================
-- SECTION 10: CALLBACKS
-- ============================================
QBCore.Functions.CreateCallback('windturbine:getServerData')
QBCore.Functions.CreateCallback('windturbine:checkMoney')

-- ============================================
-- SECTION 11: BACKGROUND THREADS
-- ============================================
CreateThread(function() -- Rental expiry checker
CreateThread(function() -- Earnings calculator
```

---

## ✅ HÀNH ĐỘNG

### Bước 1: Xóa duplicate
- [x] Xác định các function duplicate
- [ ] Xóa định nghĩa thứ 2
- [ ] Xóa code không dùng

### Bước 2: Tổ chức lại
- [ ] Nhóm functions theo chức năng
- [ ] Thêm section headers
- [ ] Sắp xếp theo thứ tự logic

### Bước 3: Cải thiện code
- [ ] Tên function rõ ràng hơn
- [ ] Comment đầy đủ
- [ ] Extract magic numbers thành constants

### Bước 4: Test
- [ ] Test tất cả chức năng
- [ ] Đảm bảo không có breaking changes

---

## 🎨 CODING STANDARDS

### Naming Convention:
```lua
-- Functions: PascalCase hoặc camelCase
local function CalculateProfit() end
local function checkOwnership() end

-- Constants: UPPER_SNAKE_CASE
local MAX_FUEL = 100
local FUEL_PER_CAN = 25

-- Variables: camelCase
local playerData = {}
local currentFuel = 0
```

### Comments:
```lua
-- ============================================
-- SECTION: Tên section
-- ============================================

-- Function description
-- @param param1 Description
-- @return Description
local function FunctionName(param1)
    -- Implementation
end
```

---

## 📊 KẾT QUẢ MONG ĐỢI

### Trước refactor:
- Server: ~1000 dòng, khó đọc
- Client: ~1300 dòng, khó đọc
- Có duplicate code
- Không có structure rõ ràng

### Sau refactor:
- Server: ~900 dòng, dễ đọc
- Client: ~1200 dòng, dễ đọc
- Không có duplicate
- Structure rõ ràng, dễ maintain

---

## ⚠️ LƯU Ý

1. **Không thay đổi logic** - Chỉ refactor structure
2. **Test kỹ sau mỗi thay đổi**
3. **Giữ nguyên tên events** - Để tương thích
4. **Comment đầy đủ** - Giải thích logic phức tạp
