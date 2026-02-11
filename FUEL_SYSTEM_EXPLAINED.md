# ⛽ HỆ THỐNG XĂNG - GIẢI THÍCH CHI TIẾT

## 📊 TỔNG QUAN

Xăng giảm **TỰ ĐỘNG THEO THỜI GIAN**, KHÔNG liên quan đến penalty!

---

## ⚙️ CẤU HÌNH (config.lua)

### Test Mode (Hiện tại):
```lua
Config.MaxFuel = 100                    -- Tối đa 100 fuel units
Config.MinFuelToStart = 100             -- Cần 100 fuel để khởi động
Config.FuelPerJerrycan = 25             -- 1 can xăng = 25 fuel
Config.FuelConsumptionCycle = 60        -- Tiêu hao mỗi 60 giây (1 phút)
```

**Nghĩa là:**
- Cần đổ **4 can xăng** để khởi động (4 × 25 = 100 fuel)
- Mỗi **1 phút** (test mode) = Trừ **1 fuel**
- Tổng thời gian hoạt động: **100 phút** (với 100 fuel)

### Production Mode:
```lua
Config.MaxFuel = 100                    -- Tối đa 100 fuel units
Config.MinFuelToStart = 100             -- Cần 100 fuel để khởi động
Config.FuelPerJerrycan = 25             -- 1 can xăng = 25 fuel
Config.FuelConsumptionCycle = 3600000   -- Tiêu hao mỗi 3600 giây (1 giờ)
```

**Nghĩa là:**
- Cần đổ **4 can xăng** để khởi động
- Mỗi **1 giờ** (thực tế) = Trừ **1 fuel**
- Tổng thời gian hoạt động: **100 giờ** (với 100 fuel)

---

## 🔄 CÁCH HOẠT ĐỘNG

### 1. Khởi động máy:
```
Fuel = 0 → Cần đổ 4 can (100 fuel) → Có thể khởi động
```

### 2. Tiêu hao xăng (Server-side):
```lua
-- Server thread chạy mỗi 1 phút (test) / 1 giờ (production)
if currentTime - earnings.lastFuelConsumption >= FuelConsumptionCycle then
    if earnings.currentFuel > 0 then
        earnings.currentFuel = earnings.currentFuel - 1  -- Trừ 1 fuel
        
        -- Gửi update về client
        TriggerClientEvent('windturbine:updateFuel', playerId, earnings.currentFuel)
        
        -- Nếu hết xăng → Tắt máy
        if earnings.currentFuel == 0 then
            earnings.onDuty = false
            TriggerClientEvent('windturbine:outOfFuel', playerId)
        end
    end
    
    earnings.lastFuelConsumption = currentTime
end
```

### 3. Cảnh báo:
- **Còn 10 fuel:** "⚠️ Cảnh báo: Còn 10 giờ xăng!"
- **Còn 5 fuel:** "🚨 Khẩn cấp: Còn 5 giờ xăng!"
- **Còn 0 fuel:** "⛽ Hết xăng! Máy đã dừng hoạt động."

---

## 📈 TIMELINE (Test Mode)

```
Phút 0:   Đổ 4 can xăng → Fuel = 100
Phút 1:   Fuel = 99
Phút 2:   Fuel = 98
...
Phút 90:  Fuel = 10 → Cảnh báo
Phút 95:  Fuel = 5  → Khẩn cấp
Phút 100: Fuel = 0  → Máy tắt
```

---

## 📈 TIMELINE (Production Mode)

```
Giờ 0:   Đổ 4 can xăng → Fuel = 100
Giờ 1:   Fuel = 99
Giờ 2:   Fuel = 98
...
Giờ 90:  Fuel = 10 → Cảnh báo
Giờ 95:  Fuel = 5  → Khẩn cấp
Giờ 100: Fuel = 0  → Máy tắt
```

---

## ❓ CÂU HỎI THƯỜNG GẶP

### Q1: Xăng có giảm do penalty không?
**A:** ❌ KHÔNG! Xăng chỉ giảm theo thời gian, không liên quan penalty.

### Q2: Penalty ảnh hưởng gì?
**A:** Penalty chỉ giảm **5 chỉ số hệ thống** (stability, electric, lubrication, blades, safety), KHÔNG ảnh hưởng xăng.

### Q3: Máy ngừng hoạt động (3 chỉ số ≤ 30%) có tiêu hao xăng không?
**A:** ✅ CÓ! Xăng vẫn tiêu hao khi máy đang chạy (onDuty = true), kể cả khi hư hỏng.

### Q4: Tắt duty có tiêu hao xăng không?
**A:** ❌ KHÔNG! Chỉ tiêu hao khi onDuty = true.

### Q5: Có thể đổ xăng khi đang chạy không?
**A:** ✅ CÓ! Có thể đổ xăng bất cứ lúc nào.

### Q6: Đổ xăng khi còn 50 fuel thì sao?
**A:** Đổ 1 can (25 fuel) → Fuel = 75. Có thể đổ tối đa đến 100 fuel.

---

## 🔧 LOGIC CHI TIẾT

### Điều kiện tiêu hao xăng:
```lua
if playerData.onDuty                              -- Đang làm việc
   AND currentTime >= lastFuelConsumption + Cycle -- Đủ thời gian
   AND currentFuel > 0                            -- Còn xăng
then
    currentFuel = currentFuel - 1                 -- Trừ 1 fuel
end
```

### Điều kiện máy ngừng hoạt động:
```lua
-- Hết xăng
if currentFuel == 0 then
    onDuty = false
    → Máy tắt
end

-- 3 chỉ số ≤ 30%
if (số chỉ số ≤ 30%) >= 3 then
    → Không sinh tiền (nhưng vẫn tiêu hao xăng)
end
```

---

## 📊 SO SÁNH VỚI PENALTY

| Aspect | Xăng (Fuel) | Penalty |
|--------|-------------|---------|
| Giảm theo | Thời gian cố định | Random theo work hours |
| Chu kỳ | 1 phút/1 giờ | 1 phút/1 giờ |
| Ảnh hưởng | Fuel giảm 1 | Systems giảm 10-50% |
| Khi máy hư | Vẫn tiêu hao | Không áp dụng |
| Có thể sửa | Đổ xăng | Repair systems |
| Khi hết | Máy tắt | Không sinh tiền |

---

## ✅ KẾT LUẬN

**Xăng giảm:**
- ✅ Tự động theo thời gian
- ✅ Mỗi 1 phút (test) / 1 giờ (production) = -1 fuel
- ✅ Không liên quan penalty
- ✅ Tiêu hao kể cả khi máy hư hỏng
- ✅ Chỉ dừng khi tắt duty hoặc hết xăng

**Penalty:**
- ✅ Random giảm systems
- ✅ Không ảnh hưởng xăng
- ✅ Chỉ áp dụng khi máy hoạt động bình thường

**Hai hệ thống hoàn toàn độc lập!**
