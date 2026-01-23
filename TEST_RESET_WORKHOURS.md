# HƯỚNG DẪN TEST VÀ SỬA LỖI

## VẤN ĐỀ ĐÃ SỬA

Sau khi hết 12 phút (test mode), khi bấm "Bắt đầu" lại:
- ❌ **TRƯỚC:** Không hiển thị thời gian, không sinh tiền, máy dừng ngay
- ✅ **SAU:** Hiển thị thông báo "Đã đạt giới hạn", không cho phép bắt đầu ca mới

## NGUYÊN NHÂN

1. Khi auto-stop do hết giờ, `dailyWorkHours` được set = `Config.MaxDailyHours` (0.2 giờ = 12 phút)
2. Khi bấm start lại, hệ thống kiểm tra `dailyWorkHours >= MaxDailyHours` → **CHẶN NGAY**
3. Người chơi phải đợi đến ngày mới (hoặc dùng command reset)

## CÁC THAY ĐỔI

### 1. Server (server/main.lua)

#### a) Reset `totalWorkHours` khi bắt đầu ca mới
```lua
playerData[playerId].totalWorkHours = 0 -- Reset total work hours khi bắt đầu ca mới
```

#### b) Set chính xác giá trị khi auto-stop
```lua
-- Khi hết giờ ngày
data.dailyWorkHours = Config.MaxDailyHours -- Set chính xác = giới hạn

-- Khi hết giờ tuần
data.weeklyWorkHours = Config.MaxWeeklyHours -- Set chính xác = giới hạn
```

#### c) Thêm log để debug
```lua
print(('[Wind Turbine] Player %s: Daily hours reset (new day)'):format(playerId))
```

### 2. Thêm Admin Commands

#### Command 1: Reset thời gian làm việc
```
/windturbine:reset
```
- Reset `dailyWorkHours` và `weeklyWorkHours` về 0
- Cho phép làm việc lại ngay lập tức
- **CHỈ ĐỂ TEST**, không dùng trong production

#### Command 2: Xem thông tin thời gian
```
/windturbine:info
```
- Hiển thị thời gian làm việc hôm nay, tuần này, ca hiện tại
- Giúp debug và kiểm tra trạng thái

## CÁCH TEST

### Test 1: Hết giờ và không cho start lại
1. Bắt đầu ca làm việc
2. Đợi 12 phút (test mode) hoặc 12 giờ (production)
3. Máy tự động dừng với thông báo:
   ```
   ⏰ Đã hết giờ làm việc trong ngày (12 phút)!
   🚫 Ca làm việc tự động kết thúc.
   💡 Dùng /windturbine:reset để test lại.
   ```
4. Bấm "Bắt đầu" lại
5. **KẾT QUẢ MONG ĐỢI:** Thông báo:
   ```
   ❌ Đã đạt giới hạn 12 phút/ngày!
   ⏰ Phải đợi đến ngày mới hoặc dùng /windturbine:reset để test.
   ```
   **KHÔNG CHO BẮT ĐẦU CA MỚI**

### Test 2: Reset và làm việc lại
1. Sau khi hết giờ (test 1)
2. Gõ command: `/windturbine:reset`
3. Thông báo: "✅ Đã reset thời gian làm việc! Bạn có thể làm việc lại."
4. Bấm "Bắt đầu" lại
5. **KẾT QUẢ MONG ĐỢI:** 
   - Máy hoạt động bình thường
   - Hiển thị "ONLINE - 0h/12h"
   - Sinh tiền bình thường

### Test 3: Kiểm tra thông tin
1. Trong khi đang làm việc
2. Gõ command: `/windturbine:info`
3. **KẾT QUẢ MONG ĐỢI:** Hiển thị:
   ```
   📊 Thời gian làm việc:
   • Hôm nay: 0.1h/0.2h
   • Tuần này: 0.1h/1.4h
   • Ca hiện tại: 0.1h
   ```

## LOGIC HOẠT ĐỘNG

### Khi bắt đầu ca (`windturbine:startDuty`)
1. Kiểm tra `dailyWorkHours >= MaxDailyHours`
2. Nếu đạt giới hạn → **CHẶN**, hiển thị thông báo
3. Nếu chưa đạt → Cho phép bắt đầu, reset `totalWorkHours = 0`

### Trong khi làm việc (Thread)
1. Tính `currentWorkHours = (now - workStartTime) / 3600`
2. Tính `totalDailyHours = dailyWorkHours + currentWorkHours`
3. Nếu `totalDailyHours >= MaxDailyHours` → **AUTO-STOP**
4. Set `dailyWorkHours = MaxDailyHours` (chính xác)

### Khi kết thúc ca (`windturbine:stopDuty`)
1. Tính `workDuration = (now - workStartTime) / 3600`
2. Cộng vào: `dailyWorkHours += workDuration`
3. Cộng vào: `weeklyWorkHours += workDuration`

### Reset tự động
- **Mỗi ngày mới:** Reset `dailyWorkHours = 0`
- **Mỗi tuần mới:** Reset `weeklyWorkHours = 0`

## THÔNG BÁO CHO NGƯỜI CHƠI

### Khi hết giờ (Auto-stop)

**Test Mode:**
```
⏰ Đã hết giờ làm việc trong ngày (12 phút)!
🚫 Ca làm việc tự động kết thúc.
💡 Dùng /windturbine:reset để test lại.
```

**Production:**
```
⏰ Đã hết giờ làm việc trong ngày (12 giờ)!
🚫 Ca làm việc tự động kết thúc.
💤 Hãy nghỉ ngơi và quay lại vào ngày mai.
```

### Khi bấm "Bắt đầu" sau khi hết giờ

**Test Mode:**
```
❌ Đã đạt giới hạn 12 phút/ngày!
⏰ Phải đợi đến ngày mới hoặc dùng /windturbine:reset để test.
```

**Production:**
```
❌ Đã đạt giới hạn 12 giờ/ngày!
⏰ Phải đợi đến ngày mới để làm việc tiếp.
```

### Khi reset thành công
```
✅ Đã reset thời gian làm việc! Bạn có thể làm việc lại.
```

## LƯU Ý

### Test Mode vs Production
- **Test Mode:** 12 phút = 0.2 giờ
- **Production:** 12 giờ thực

### Commands chỉ để test
- `/windturbine:reset` - Chỉ dùng khi test
- `/windturbine:info` - Có thể giữ lại để admin kiểm tra

### Nếu muốn cho phép làm việc lại ngay
Có 2 cách:
1. **Dùng command reset** (khuyến nghị cho test)
2. **Sửa config:** Tăng `MaxDailyHours` lên cao hơn

## CHECKLIST

- [x] Sửa logic auto-stop (set chính xác giá trị)
- [x] Sửa logic start duty (reset totalWorkHours)
- [x] Thêm command reset
- [x] Thêm command info
- [x] Thêm log để debug
- [x] Test hết giờ và không cho start lại
- [ ] Test reset và làm việc lại
- [ ] Test thông tin hiển thị đúng

## KẾT LUẬN

Hệ thống bây giờ hoạt động đúng logic:
1. **Hết giờ → Không cho làm tiếp** (phải đợi ngày mới)
2. **Có command reset** để test nhanh
3. **Hiển thị thông báo rõ ràng** khi đạt giới hạn
4. **Không bị bug** thời gian không hiển thị hoặc không sinh tiền
