# 🔍 PHÂN TÍCH TỐI ƯU HÓA CODE

## 📋 Các Vấn Đề Tìm Thấy

### SERVER (server/main.lua)

#### 1. ❌ Validation turbineId Lặp Lại 3 Lần

**Vị trí:**
- Dòng 299-308: `windturbine:withdrawEarnings`
- Dòng 371-380: `windturbine:rentTurbine`
- Dòng 515-524: `windturbine:startDuty`

**Code lặp:**
```lua
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
```

**Giải pháp:** Tạo helper function `ValidateTurbineId(turbineId)`

---

#### 2. ❌ Phone Notification Pattern Lặp Lại

**Vị trí:**
- Dòng 244-248: CheckRentalExpiry
- Dòng 340-354: withdrawEarnings
- Dòng 478-497: rentTurbine
- Dòng 705-710: useJerrycan

**Code lặp:**
```lua
local phoneNumber = exports["lb-phone"]:GetEquippedPhoneNumber(playerId)
if phoneNumber then
    local message = "..."
    exports['lb-phone']:SendMessage('Trạm Điện Gió', tostring(phoneNumber), message, nil, nil, nil)
end
```

**Giải pháp:** Tạo helper function `SendPhoneNotification(playerId, message)`

---

#### 3. ❌ Player Validation Lặp Lại

**Pattern:**
```lua
local Player = QBCore.Functions.GetPlayer(playerId)
if not Player then return end
local citizenid = Player.PlayerData.citizenid
```

Lặp lại trong hầu hết các events.

**Giải pháp:** Tạo helper function `GetPlayerAndCitizenId(playerId)`

---

#### 4. ❌ Money Removal Logic Phức Tạp

**Vị trí:** Dòng 418-434 trong `rentTurbine`

**Code dài:**
```lua
if rentalPrice > 0 then
    if tienkhoa >= rentalPrice then
        Player.Functions.RemoveMoney('tienkhoa', rentalPrice, ...)
    else
        local remainingAmount = rentalPrice - tienkhoa
        if tienkhoa > 0 then
            Player.Functions.RemoveMoney('tienkhoa', tienkhoa, ...)
            Wait(100)
            Player.Functions.RemoveMoney('bank', remainingAmount, ...)
        else
            Player.Functions.RemoveMoney('bank', remainingAmount, ...)
        end
    end
end
```

**Giải pháp:** Tạo helper function `RemoveMoneyFromPlayer(Player, amount, reason)`

---

### CLIENT (client/main.lua)

#### 1. ❌ SendNUIMessage Lặp Lại

**Pattern:**
```lua
SendNUIMessage({
    action = 'updateSystems',
    systems = currentSystems
})
SendNUIMessage({
    action = 'updateEfficiency',
    efficiency = currentEfficiency
})
SendNUIMessage({
    action = 'updateActualEarningRate',
    earningRate = actualEarningRate
})
```

Có thể gộp thành 1 message duy nhất.

**Giải pháp:** Tạo function `UpdateAllUI()` gửi 1 message với nhiều fields

---

#### 2. ❌ Reset PlayerData Lặp Lại 3 Lần

**Vị trí:**
- Dòng ~600: `windturbine:withdrawSuccess` (grace period)
- Dòng ~650: `windturbine:gracePeriodExpired`
- Có thể có thêm chỗ khác

**Code lặp:**
```lua
playerData = {
    onDuty = false,
    systems = {
        stability = Config.InitialSystemValue,
        electric = Config.InitialSystemValue,
        lubrication = Config.InitialSystemValue,
        blades = Config.InitialSystemValue,
        safety = Config.InitialSystemValue
    },
    earningsPool = 0,
    lastEarning = 0,
    lastPenalty = 0,
    lastFuelConsumption = 0,
    workStartTime = 0,
    totalWorkHours = 0,
    dailyWorkHours = 0,
    lastDayReset = GetCurrentDay(),
    currentFuel = 0
}
```

**Giải pháp:** Tạo function `ResetPlayerData()`

---

#### 3. ❌ Notify + PlaySound Pattern

**Pattern:**
```lua
no:Notify('...', 'success', 3000)
PlaySound(-1, "CHECKPOINT_PERFECT", "HUD_MINI_GAME_SOUNDSET", 0, 0, 1)
```

Lặp lại nhiều lần với các sound khác nhau.

**Giải pháp:** Tạo function `NotifyWithSound(message, type, sound)`

---

## 📊 Tổng Kết

### Server Có Thể Tối Ưu:
- ✅ 4 helper functions mới
- ✅ Giảm ~150 dòng code lặp
- ✅ Dễ bảo trì hơn

### Client Có Thể Tối Ưu:
- ✅ 3 helper functions mới
- ✅ Giảm ~100 dòng code lặp
- ✅ Performance tốt hơn (ít NUI messages)

### Tổng:
- ✅ 7 helper functions
- ✅ Giảm ~250 dòng code
- ✅ Logic KHÔNG thay đổi
- ✅ Dễ đọc và bảo trì hơn NHIỀU

## 🚀 Bước Tiếp Theo

Anh có muốn mình implement các optimization này không? Mình sẽ:
1. Tạo các helper functions
2. Thay thế code lặp bằng helper calls
3. Test để đảm bảo logic không thay đổi
