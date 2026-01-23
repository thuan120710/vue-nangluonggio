# FLOW GIỚI HẠN THỜI GIAN LÀM VIỆC

## 📋 TỔNG QUAN

Hệ thống giới hạn thời gian làm việc để đảm bảo người chơi nghỉ ngơi hợp lý:
- **Test Mode:** 12 phút/ngày, 84 phút/tuần
- **Production:** 12 giờ/ngày, 84 giờ/tuần

## 🔄 FLOW HOẠT ĐỘNG

```
┌─────────────────────────────────────────────────────────────┐
│                    NGƯỜI CHƠI BẤM "BẮT ĐẦU"                  │
└─────────────────────┬───────────────────────────────────────┘
                      │
                      ▼
         ┌────────────────────────────┐
         │ Kiểm tra dailyWorkHours    │
         │ >= MaxDailyHours?          │
         └────────┬───────────┬───────┘
                  │           │
            ✅ CHƯA ĐẠT    ❌ ĐÃ ĐẠT
                  │           │
                  ▼           ▼
         ┌────────────┐  ┌──────────────────────────────┐
         │ CHO PHÉP   │  │ CHẶN & THÔNG BÁO:            │
         │ BẮT ĐẦU CA │  │ "Phải đợi đến ngày mới"      │
         └─────┬──────┘  └──────────────────────────────┘
               │
               ▼
    ┌──────────────────────┐
    │ Máy hoạt động         │
    │ Sinh tiền mỗi 30s     │
    │ Penalty mỗi 1 phút    │
    └──────────┬────────────┘
               │
               ▼
    ┌──────────────────────────┐
    │ Kiểm tra mỗi giây:       │
    │ totalDailyHours          │
    │ >= MaxDailyHours?        │
    └──────┬───────────┬───────┘
           │           │
     ✅ CHƯA ĐẠT    ❌ ĐÃ ĐẠT
           │           │
           ▼           ▼
    ┌──────────┐  ┌─────────────────────────┐
    │ TIẾP TỤC │  │ AUTO-STOP & THÔNG BÁO:  │
    │ LÀM VIỆC │  │ "Đã hết giờ làm việc"   │
    └──────────┘  │ dailyWorkHours = MAX    │
                  └─────────────────────────┘
```

## 📊 BIẾN TRẠNG THÁI

### 1. `dailyWorkHours` (Tích lũy trong ngày)
- **Khởi tạo:** 0
- **Cập nhật:** Khi kết thúc ca hoặc auto-stop
- **Reset:** Mỗi ngày mới (00:00)
- **Công thức:** `dailyWorkHours += workDuration`

### 2. `totalWorkHours` (Thời gian ca hiện tại)
- **Khởi tạo:** 0 (khi bắt đầu ca)
- **Cập nhật:** Mỗi giây (trong thread)
- **Reset:** Mỗi khi bắt đầu ca mới
- **Công thức:** `(now - workStartTime) / 3600`

### 3. `totalDailyHours` (Tổng thời gian trong ngày)
- **Không lưu trữ** (tính toán động)
- **Công thức:** `dailyWorkHours + totalWorkHours`
- **Dùng để:** Kiểm tra giới hạn trong thread

## 🎯 CÁC TRƯỜNG HỢP

### Trường hợp 1: Làm việc bình thường
```
dailyWorkHours = 0
Bắt đầu ca → totalWorkHours = 0
Làm việc 5 phút → totalWorkHours = 0.083h
totalDailyHours = 0 + 0.083 = 0.083h < 0.2h ✅
→ Tiếp tục làm việc
```

### Trường hợp 2: Hết giờ (Auto-stop)
```
dailyWorkHours = 0
Bắt đầu ca → totalWorkHours = 0
Làm việc 12 phút → totalWorkHours = 0.2h
totalDailyHours = 0 + 0.2 = 0.2h >= 0.2h ❌
→ AUTO-STOP
→ dailyWorkHours = 0.2h (set chính xác)
```

### Trường hợp 3: Bấm start sau khi hết giờ
```
dailyWorkHours = 0.2h (từ ca trước)
Bấm "Bắt đầu" → Kiểm tra: 0.2h >= 0.2h ❌
→ CHẶN & THÔNG BÁO: "Phải đợi đến ngày mới"
```

### Trường hợp 4: Ngày mới
```
dailyWorkHours = 0.2h (từ hôm qua)
Ngày mới → Reset: dailyWorkHours = 0
Bấm "Bắt đầu" → Kiểm tra: 0 < 0.2h ✅
→ CHO PHÉP làm việc lại
```

### Trường hợp 5: Làm nhiều ca trong ngày
```
Ca 1: Làm 5 phút → dailyWorkHours = 0.083h
Ca 2: Làm 5 phút → dailyWorkHours = 0.166h
Ca 3: Làm 2 phút → dailyWorkHours = 0.2h (auto-stop)
Ca 4: Bấm start → CHẶN (đã đạt giới hạn)
```

## 🛠️ COMMANDS

### `/windturbine:reset` (Test only)
```lua
dailyWorkHours = 0
weeklyWorkHours = 0
→ Cho phép làm việc lại ngay lập tức
```

### `/windturbine:info`
```lua
Hiển thị:
- Hôm nay: dailyWorkHours + totalWorkHours
- Tuần này: weeklyWorkHours + totalWorkHours
- Ca hiện tại: totalWorkHours
```

## ⚠️ LƯU Ý QUAN TRỌNG

### 1. Không cho phép làm việc lại sau khi hết giờ
- ❌ **SAI:** Cho phép start lại → Lập tức auto-stop
- ✅ **ĐÚNG:** Chặn ngay từ đầu → Thông báo rõ ràng

### 2. Set giá trị chính xác khi auto-stop
- ❌ **SAI:** `dailyWorkHours += workDuration` (có thể > MAX)
- ✅ **ĐÚNG:** `dailyWorkHours = Config.MaxDailyHours` (chính xác = MAX)

### 3. Reset totalWorkHours khi bắt đầu ca mới
- ❌ **SAI:** Giữ nguyên totalWorkHours từ ca cũ
- ✅ **ĐÚNG:** `totalWorkHours = 0` (reset về 0)

### 4. Thông báo rõ ràng cho người chơi
- ❌ **SAI:** "Đã đạt giới hạn! Hãy nghỉ ngơi."
- ✅ **ĐÚNG:** "Đã đạt giới hạn! Phải đợi đến ngày mới để làm việc tiếp."

## 🧪 TEST CHECKLIST

- [ ] Làm việc đủ 12 phút → Auto-stop với thông báo đúng
- [ ] Bấm start sau khi hết giờ → Chặn với thông báo "Phải đợi đến ngày mới"
- [ ] Dùng `/windturbine:reset` → Cho phép làm việc lại
- [ ] Dùng `/windturbine:info` → Hiển thị thông tin đúng
- [ ] Ngày mới → Reset tự động, cho phép làm việc lại
- [ ] Làm nhiều ca trong ngày → Tích lũy đúng thời gian
- [ ] Disconnect giữa chừng → Lưu thời gian đúng
- [ ] Thời gian hiển thị trên UI → "ONLINE - Xh/12h" đúng

## 📝 KẾT LUẬN

Hệ thống bây giờ hoạt động đúng logic:
1. ✅ **Chặn ngay từ đầu** khi đã hết giờ
2. ✅ **Thông báo rõ ràng** phải đợi đến ngày mới
3. ✅ **Không bị bug** thời gian không hiển thị
4. ✅ **Không bị bug** không sinh tiền
5. ✅ **Có command test** để kiểm tra nhanh
