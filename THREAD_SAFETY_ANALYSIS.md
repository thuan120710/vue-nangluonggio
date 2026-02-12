# PHÂN TÍCH AN TOÀN & TỐI ƯU THREAD SERVER

## 1. THREAD: Reset Turbines (Khởi động)
**Tần suất:** Chỉ 1 lần khi script start
**Mục đích:** Reset tất cả trạm về trạng thái chưa thuê

✅ **AN TOÀN HOÀN TOÀN**
- Không có vòng lặp vô hạn
- Chỉ chạy 1 lần duy nhất
- Không ảnh hưởng performance

---

## 2. THREAD: Check Rental Expiry (30 giây)
**Tần suất:** Mỗi 30 giây
**Mục đích:** Kiểm tra trạm hết hạn thuê và grace period

### ✅ ĐIỂM MẠNH:
1. **Memory Cleanup tốt:**
   - Xóa PlayerEarnings khi grace period hết
   - Xóa TurbineExpiryGracePeriod khi hết hạn
   - Không để rò rỉ memory

2. **Logic an toàn:**
   - Validate data trước khi xử lý
   - Có thông báo cho player kịp thời
   - Broadcast qua StateBag (tự động sync tất cả client)

3. **Performance tốt:**
   - Chỉ loop qua trạm ĐANG THUÊ (ít data)
   - Không có tính toán phức tạp
   - 30s là khoảng thời gian hợp lý

### ⚠️ VẤN ĐỀ TIỀM ẨN:
- Nếu có 100 trạm đang thuê → check 100 lần mỗi 30s
- Nhưng thực tế: Ít khi có nhiều trạm thuê cùng lúc

### 💡 KHUYẾN NGHỊ:
**GIỮ NGUYÊN 30 GIÂY** - Đây là tần suất tối ưu vì:
- Cần check kịp thời để thông báo player
- Data ít, không ảnh hưởng performance
- 30s đủ nhanh để phát hiện expiry

---

## 3. THREAD: Calculate Earnings & Penalties (1 giờ)
**Tần suất:** Mỗi 1 giờ (hoặc 1 phút trong test mode)
**Mục đích:** Tính tiền, apply penalty, tiêu hao xăng

### ✅ ĐIỂM MẠNH:
1. **Security tốt:**
   - Validate player còn online trước khi xử lý
   - Cleanup memory cho player offline
   - Skip player không onDuty

2. **Logic chặt chẽ:**
   - Check CanEarnMoney() trước khi tính tiền
   - Penalty system với random range hợp lý
   - Fuel consumption đúng logic

3. **Memory management:**
   ```lua
   if not Player then
       if not earnings.onDuty then
           PlayerEarnings[citizenid] = nil  -- Cleanup!
       end
       goto continue
   end
   ```

### ⚠️ VẤN ĐỀ TIỀM ẨN:
1. **Loop qua TẤT CẢ PlayerEarnings:**
   - Nếu 500 player → check 500 lần mỗi giờ
   - Nhưng có skip logic nên không quá nặng

2. **Nested loops trong penalty:**
   ```lua
   for _, penalty in ipairs(penaltyRange.penalties) do
       for i = 1, numSystems do
           -- Apply penalty
       end
   end
   ```
   - Nhưng số lượng ít nên OK

### 💡 KHUYẾN NGHỊ:
**GIỮ NGUYÊN 1 GIỜ** - Đây là tần suất TỐI ƯU vì:
- Đúng với logic game (tính tiền mỗi giờ)
- Giảm tải server (không cần check liên tục)
- Penalty cũng apply mỗi giờ theo design

---

## SO SÁNH: 30 GIÂY vs 1 GIỜ

### Nếu đổi Earnings Thread từ 1 giờ → 30 giây:
❌ **KHÔNG NÊN** vì:
- Tính tiền quá nhanh → game mất cân bằng
- Server phải tính toán 120 lần/giờ thay vì 1 lần
- Penalty apply quá nhanh → player không kịp sửa
- Fuel tiêu hao quá nhanh

### Nếu đổi Rental Expiry từ 30 giây → 1 giờ:
❌ **KHÔNG NÊN** vì:
- Player có thể hết hạn thuê nhưng không được thông báo kịp
- Grace period không được check đúng lúc
- Trải nghiệm người chơi kém

---

## KẾT LUẬN & KHUYẾN NGHỊ

### ✅ CẤU HÌNH HIỆN TẠI LÀ TỐI ƯU:
1. **Rental Expiry: 30 giây** ✅
   - Đủ nhanh để thông báo kịp thời
   - Không ảnh hưởng performance
   - Data ít, logic đơn giản

2. **Earnings/Penalties: 1 giờ** ✅
   - Đúng với logic game
   - Tối ưu performance
   - Cân bằng gameplay

### 🔧 TỐI ƯU BỔ SUNG (Tùy chọn):

#### Option 1: Thêm limit cho Rental Expiry
```lua
CreateThread(function()
    while true do
        Wait(30000)
        
        local count = 0
        for turbineId, _ in pairs(TurbineRentals) do
            CheckRentalExpiry(turbineId)
            count = count + 1
            
            -- Giới hạn check tối đa 50 trạm mỗi lần
            if count >= 50 then
                Wait(100) -- Nghỉ 100ms trước khi tiếp tục
                count = 0
            end
        end
        
        -- Tương tự cho grace period
        count = 0
        for turbineId, _ in pairs(TurbineExpiryGracePeriod) do
            CheckRentalExpiry(turbineId)
            count = count + 1
            
            if count >= 50 then
                Wait(100)
                count = 0
            end
        end
    end
end)
```

#### Option 2: Thêm batch processing cho Earnings
```lua
CreateThread(function()
    while true do
        Wait(Config.TestMode and 60000 or 3600000)
        
        local count = 0
        for citizenid, earnings in pairs(PlayerEarnings) do
            -- Xử lý như cũ
            
            count = count + 1
            
            -- Mỗi 100 player, nghỉ 50ms
            if count % 100 == 0 then
                Wait(50)
            end
        end
    end
end)
```

### 📊 BENCHMARK DỰ KIẾN:

**Server 500 players:**
- Rental Expiry (30s): ~10-20ms mỗi lần (nếu có 50 trạm thuê)
- Earnings (1h): ~100-200ms mỗi lần (500 players)

**Kết luận:** Cả 2 thread đều AN TOÀN và TỐI ƯU với cấu hình hiện tại!

---

## CHECKLIST AN TOÀN ✅

- [x] Memory cleanup cho player offline
- [x] Validate data trước khi xử lý
- [x] Skip logic cho player không onDuty
- [x] Không có infinite loop blocking
- [x] Không có nested loops quá sâu
- [x] Có error handling (pcall cho phone notifications)
- [x] StateBag sync tự động (không cần manual trigger)
- [x] Tần suất hợp lý với logic game

**ĐÁNH GIÁ TỔNG THỂ: 9/10** ⭐⭐⭐⭐⭐
