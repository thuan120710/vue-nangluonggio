# 🚨 LỖ HỔNG BẢO MẬT BỔ SUNG ĐÃ PHÁT HIỆN

## 1. 🔴 CRITICAL: Client có thể cheat repair system
**Vị trí:** `server/main.lua` - Event `windturbine:updateSystem`

**Vấn đề:**
```lua
RegisterNetEvent('windturbine:updateSystem')
AddEventHandler('windturbine:updateSystem', function(system, newValue)
    -- Client GỬI newValue, server TIN TƯỞNG hoàn toàn!
    PlayerEarnings[citizenid].systems[system] = math.min(100, math.max(0, newValue))
end)
```

**Cách khai thác:**
- Client có thể gửi `newValue = 100` cho tất cả systems
- Không có validation nào kiểm tra giá trị cũ
- Không kiểm tra xem có đang làm minigame không
- Có thể spam event này để set tất cả systems = 100%

**Mức độ:** 🔴 CRITICAL

---

## 2. 🔴 CRITICAL: Client có thể bypass rental price validation
**Vị trí:** `server/main.lua` - Event `windturbine:rentTurbine`

**Vấn đề:**
```lua
RegisterNetEvent('windturbine:rentTurbine')
AddEventHandler('windturbine:rentTurbine', function(turbineId, rentalPrice)
    -- Client GỬI rentalPrice, server chỉ validate type
    if rentalPrice == nil or type(rentalPrice) ~= "number" or rentalPrice < 0 then
        return
    end
    
    -- Nhưng KHÔNG kiểm tra rentalPrice == Config.RentalPrice!
    if rentalPrice > 0 then
        Player.Functions.RemoveMoney('tienkhoa', rentalPrice, ...)
    end
end)
```

**Cách khai thác:**
- Client có thể gửi `rentalPrice = 0` hoặc `rentalPrice = 1`
- Server sẽ chỉ trừ số tiền client gửi lên
- Thuê trạm 200,000 IC chỉ với 1 IC!

**Mức độ:** 🔴 CRITICAL

---

## 3. 🟡 MEDIUM: Race condition khi grace period expire
**Vị trí:** `server/main.lua` - Function `CheckRentalExpiry`

**Vấn đề:**
```lua
if currentTime >= graceData.withdrawDeadline then
    TurbineExpiryGracePeriod[turbineId] = nil
    BroadcastRentalStatus(turbineId)
    
    -- KHÔNG reset PlayerEarnings!
    -- Player vẫn giữ earnings sau khi grace period hết
end
```

**Cách khai thác:**
- Đợi grace period hết hạn
- PlayerEarnings vẫn còn data
- Thuê lại trạm và có thể rút tiền cũ

**Mức độ:** 🟡 MEDIUM

---

## 4. 🟡 MEDIUM: Không validate turbineId khi withdraw
**Vị trí:** `server/main.lua` - Event `windturbine:withdrawEarnings`

**Vấn đề:**
```lua
RegisterNetEvent('windturbine:withdrawEarnings')
AddEventHandler('windturbine:withdrawEarnings', function(isGracePeriod, turbineId)
    -- Không validate turbineId có hợp lệ không
    if isGracePeriod and turbineId then
        CheckRentalExpiry(turbineId)
        local graceData = TurbineExpiryGracePeriod[turbineId]
        // ...
    }
end)
```

**Cách khai thác:**
- Client có thể gửi turbineId bất kỳ
- Có thể gây crash server nếu turbineId = nil hoặc invalid

**Mức độ:** 🟡 MEDIUM

---

## 5. 🟡 MEDIUM: Không kiểm tra ownership khi startDuty
**Vị trí:** `server/main.lua` - Event `windturbine:startDuty`

**Vấn đề:**
```lua
RegisterNetEvent('windturbine:startDuty')
AddEventHandler('windturbine:startDuty', function(turbineId)
    -- KHÔNG kiểm tra player có thuê trạm này không!
    InitPlayerEarnings(citizenid)
    PlayerEarnings[citizenid].onDuty = true
    // ...
end)
```

**Cách khai thác:**
- Player có thể start duty mà không cần thuê trạm
- Có thể làm việc và sinh tiền miễn phí

**Mức độ:** 🟡 MEDIUM

---

## 6. 🟢 LOW: Server thread không cleanup PlayerEarnings khi player offline
**Vị trí:** `server/main.lua` - Server-side earnings thread

**Vấn đề:**
```lua
CreateThread(function()
    while true do
        for citizenid, earnings in pairs(PlayerEarnings) do
            -- Không kiểm tra player còn online không
            if earnings.onDuty then
                // tính toán earnings
            end
        end
    end
end)
```

**Cách khai thác:**
- PlayerEarnings sẽ tích lũy theo thời gian
- Memory leak nếu nhiều player join/leave
- Có thể gây lag server

**Mức độ:** 🟢 LOW (Performance issue)

---

## 📊 TỔNG KẾT

- 🔴 CRITICAL: 2 lỗ hổng
- 🟡 MEDIUM: 3 lỗ hổng  
- 🟢 LOW: 1 lỗ hổng

**Ưu tiên fix:**
1. Fix #1 (updateSystem validation)
2. Fix #2 (rental price validation)
3. Fix #5 (startDuty ownership check)
4. Fix #3 (grace period cleanup)
5. Fix #4 (turbineId validation)
6. Fix #6 (memory cleanup)
