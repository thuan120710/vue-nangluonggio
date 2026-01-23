# CƠ CHẾ CUỐI CÙNG - HỆ THỐNG NĂNG LƯỢNG GIÓ

## 📋 TỔNG QUAN

### Thông số cơ bản
- **Lợi nhuận**: 5,000 IC/giờ (1,250 IC/15 phút)
- **Chu kỳ sinh tiền**: 15 phút (900 giây)
- **Giới hạn thời gian**: 12 giờ/ngày, 84 giờ/tuần
- **Điểm hòa vốn**: 40 giờ
- **Lợi nhuận tối đa**: 220,000 IC/tuần (44 giờ)

---

## ⚙️ HỆ THỐNG 5 CHỈ SỐ

Mỗi chỉ số đóng góp **20% lợi nhuận tổng**:

### 1. Stability (Độ ổn định) ⚖
- Icon: Cân bằng
- Màu: Cyan
- Minigame: Fan (Siết ốc + Xoay quạt)

### 2. Electric (Hệ thống điện) ⚡
- Icon: Tia chớp
- Màu: Vàng
- Minigame: Circuit Breaker (Gạt cầu dao)

### 3. Lubrication (Bôi trơn) 💧
- Icon: Giọt nước
- Màu: Cyan xanh
- Minigame: Bar (Thanh chạy)

### 4. Blades (Thân tháp) 🔄
- Icon: Xoay
- Màu: Hồng
- Minigame: Crack Repair (Trét xi măng)

### 5. Safety (An toàn) 🛡
- Icon: Khiên
- Màu: Xanh lá
- Minigame: Bar (Thanh chạy)

---

## 💰 LOGIC LỢI NHUẬN

### Công thức tính
```
Mỗi chỉ số = 1,250 IC/15 phút × 20% = 250 IC/15 phút
Tổng 5 chỉ số = 1,250 IC/15 phút = 5,000 IC/giờ
```

### Điều kiện theo độ bền

#### Chỉ số >= 50% (Tốt) ✅
- **Lợi nhuận**: 100% (250 IC/15 phút)
- **Màu**: Xanh lá
- **Trạng thái**: OPERATIONAL

#### Chỉ số 30-49% (Cảnh báo) ⚠️
- **Lợi nhuận**: 50% (125 IC/15 phút)
- **Màu**: Vàng
- **Trạng thái**: WARNING
- **Giảm**: 50% lợi nhuận của chỉ số đó

#### Chỉ số < 30% (Nguy hiểm) 🚨
- **Lợi nhuận**: 0% (0 IC/15 phút)
- **Màu**: Đỏ
- **Trạng thái**: CRITICAL
- **Ngừng**: Không sinh lợi nhuận từ chỉ số đó

#### 3 chỉ số < 30% (Máy ngừng) 🛑
- **Lợi nhuận**: 0 IC (toàn bộ)
- **Trạng thái**: STOPPED
- **Thông báo**: "Máy ngừng hoạt động!"

---

## 📊 VÍ DỤ TÍNH TOÁN

### Ví dụ 1: Tất cả 100%
```
Stability:    100% → 250 IC/15p
Electric:     100% → 250 IC/15p
Lubrication:  100% → 250 IC/15p
Blades:       100% → 250 IC/15p
Safety:       100% → 250 IC/15p
─────────────────────────────────
TỔNG:         1,250 IC/15p = 5,000 IC/h
```

### Ví dụ 2: 1 chỉ số 40%
```
Stability:    100% → 250 IC/15p
Electric:     100% → 250 IC/15p
Lubrication:   40% → 125 IC/15p (giảm 50%)
Blades:       100% → 250 IC/15p
Safety:       100% → 250 IC/15p
─────────────────────────────────
TỔNG:         1,125 IC/15p = 4,500 IC/h
```

### Ví dụ 3: 1 chỉ số 20%
```
Stability:    100% → 250 IC/15p
Electric:     100% → 250 IC/15p
Lubrication:   20% → 0 IC/15p (ngừng)
Blades:       100% → 250 IC/15p
Safety:       100% → 250 IC/15p
─────────────────────────────────
TỔNG:         1,000 IC/15p = 4,000 IC/h
```

### Ví dụ 4: 3 chỉ số < 30%
```
Stability:     25% → 0 IC/15p
Electric:      25% → 0 IC/15p
Lubrication:   25% → 0 IC/15p
Blades:       100% → 0 IC/15p (máy ngừng)
Safety:       100% → 0 IC/15p (máy ngừng)
─────────────────────────────────
TỔNG:         0 IC/15p = 0 IC/h
⚠️ MÁY NGỪNG HOẠT ĐỘNG!
```

---

## ⏱️ PENALTY SYSTEM (Giảm độ bền theo giờ)

### Cơ chế
- **CHỈ CÓ PENALTY** - Không có giảm tự nhiên
- Kiểm tra **mỗi 1 giờ**
- Random theo tỷ lệ (hên xui)
- Chỉ giảm **1-2 bộ phận** mỗi lần

### 0-2 giờ: An toàn 🟢
```
Không có penalty
```

### 2-4 giờ: Nhẹ 🟡
```
80% → 1 bộ phận -10%
20% → 1-2 bộ phận -10%
```

### 4-8 giờ: Trung bình 🟠
```
55% → 1-2 bộ phận -30%
30% → 1 bộ phận -20%
15% → Không bị gì (may mắn)
```

### 8-12 giờ: Nặng 🔴
```
40% → 1 bộ phận -25%
30% → 1-2 bộ phận -30%
20% → 1 bộ phận -40%
10% → Không bị gì (may mắn)
```

---

## 🎮 MINIGAME SỬA CHỮA

### Kết quả
- **Perfect** (Hoàn hảo): +20% độ bền
- **Good** (Tốt): +10% độ bền
- **Fail** (Thất bại): -5% độ bền

### 1. Bar Minigame (Lubrication, Safety)
- Thanh chạy ngang
- Nhấn SPACE/E khi ở vùng xanh

### 2. Fan Minigame (Stability)
- **Phase 1**: Click 3 ốc để siết
- **Phase 2**: Xoay chuột theo chiều kim đồng hồ

### 3. Circuit Breaker (Electric)
- Kéo cầu dao lên
- Đỏ: Kéo 2 lần | Vàng: Kéo 1 lần

### 4. Crack Repair (Blades)
- Click/kéo chuột trên vết nứt
- Trét xi măng để sửa

---

## ⏰ TIMELINE HOẠT ĐỘNG

### Chu kỳ sinh tiền (15 phút)
```
00:00 → Bắt đầu ca
00:15 → +1,250 IC (lần 1)
00:30 → +1,250 IC (lần 2)
00:45 → +1,250 IC (lần 3)
01:00 → +1,250 IC (lần 4) + Penalty check
─────────────────────────────────
Tổng 1 giờ: 5,000 IC
```

### Penalty check (mỗi giờ)
```
00:00 → Bắt đầu (không penalty)
01:00 → Check penalty (0-2h: không bị)
02:00 → Check penalty (2-4h: bắt đầu)
03:00 → Check penalty (2-4h)
04:00 → Check penalty (4-8h: tăng)
...
12:00 → Đạt giới hạn → Tự động kết thúc
```

---

## 📱 HIỂN THỊ UI

### Footer Status
```
OFFLINE              → Chưa bắt đầu
ONLINE - 0.0h/12h   → Vừa bắt đầu
ONLINE - 1.0h/12h   → Làm được 1 giờ
ONLINE - 5.5h/12h   → Làm được 5.5 giờ
ONLINE - 12.0h/12h  → Đạt giới hạn
OFFLINE              → Tự động kết thúc
```

### Earning Rate
```
5,000 IC/h   → Tất cả 100%
4,500 IC/h   → 1 chỉ số 40%
4,000 IC/h   → 1 chỉ số 20%
0 IC/h       → 3 chỉ số < 30%
```

### Total Balance
```
125,000 IC   → Số tiền tích lũy
(Có dấu phẩy ngăn cách)
```

---

## 🎯 CHIẾN LƯỢC CHƠI

### Tối ưu lợi nhuận
1. **Giữ tất cả chỉ số >= 50%** → Lợi nhuận đầy đủ
2. **Sửa ngay khi < 50%** → Tránh mất 50% lợi nhuận
3. **Ưu tiên sửa chỉ số < 30%** → Tránh máy ngừng

### Quản lý thời gian
1. **0-2h**: An toàn, không penalty
2. **2-4h**: Bắt đầu penalty nhẹ
3. **4-8h**: Penalty tăng, cần chú ý
4. **8-12h**: Penalty nặng, cân nhắc dừng

### Khi nào nên dừng?
- Nhiều chỉ số < 30%
- Gần 12 giờ (penalty nặng)
- Đã đủ tiền cần thiết

---

## 📈 THỐNG KÊ

### Lợi nhuận theo thời gian
```
1 giờ:    5,000 IC
4 giờ:   20,000 IC
8 giờ:   40,000 IC (hòa vốn)
12 giờ:  60,000 IC (1 ngày)
44 giờ: 220,000 IC (1 tuần max)
```

### Tỷ lệ penalty
```
0-2h:   0% bị penalty
2-4h:  100% bị penalty (nhẹ)
4-8h:   85% bị penalty (trung bình)
8-12h:  90% bị penalty (nặng)
```

---

## 🔧 CẤU HÌNH

### Config.lua
```lua
Config.BaseSalary = 1250              -- IC/15 phút
Config.EarningCycle = 900000          -- 15 phút
Config.PenaltyCycle = 3600000         -- 1 giờ
Config.MaxDailyHours = 12             -- 12 giờ/ngày
Config.MaxWeeklyHours = 84            -- 84 giờ/tuần
Config.SystemProfitContribution = 20  -- 20% mỗi chỉ số
Config.InitialSystemValue = 100       -- Bắt đầu 100%
```

### Penalty Ranges
```lua
0-2h:  Không penalty
2-4h:  80% (1 bộ phận -10%), 20% (1-2 bộ phận -10%)
4-8h:  55% (1-2 bộ phận -30%), 30% (1 bộ phận -20%), 15% (không)
8-12h: 40% (1 bộ phận -25%), 30% (1-2 bộ phận -30%), 20% (1 bộ phận -40%), 10% (không)
```

---

## ✅ CHECKLIST HOẠT ĐỘNG

### Khi bắt đầu ca
- [ ] UI hiển thị: ONLINE - 0.0h/12h
- [ ] Earning rate: 5,000 IC/h
- [ ] Tất cả chỉ số: 100%
- [ ] Quạt tuabin quay

### Sau 15 phút
- [ ] Nhận 1,250 IC
- [ ] Thông báo: "+1,250 IC"
- [ ] Balance tăng

### Sau 1 giờ
- [ ] UI cập nhật: ONLINE - 1.0h/12h
- [ ] Penalty check (0-2h: không bị)
- [ ] Server log: "Work time updated to 1.0h"

### Sau 2 giờ
- [ ] UI cập nhật: ONLINE - 2.0h/12h
- [ ] Penalty check (2-4h: bắt đầu)
- [ ] Có thể bị giảm 1-2 chỉ số

### Khi chỉ số < 50%
- [ ] Màu chuyển vàng
- [ ] Status: WARNING
- [ ] Earning rate giảm

### Khi chỉ số < 30%
- [ ] Màu chuyển đỏ
- [ ] Status: CRITICAL
- [ ] Thông báo cảnh báo

### Khi 3 chỉ số < 30%
- [ ] Earning rate: 0 IC/h
- [ ] Thông báo: "Máy ngừng hoạt động!"
- [ ] Cần sửa ngay

### Khi đạt 12 giờ
- [ ] Tự động kết thúc ca
- [ ] UI: OFFLINE
- [ ] Thông báo: "Đã đạt giới hạn"

---

## 🎓 TÓM TẮT

1. **Sinh tiền**: Mỗi 15 phút, 1,250 IC (nếu máy hoạt động)
2. **Penalty**: Mỗi 1 giờ, random giảm 1-2 chỉ số (hên xui)
3. **Sửa chữa**: Click vào chỉ số → Minigame → +10% hoặc +20%
4. **Giới hạn**: 12 giờ/ngày, tự động kết thúc
5. **Mục tiêu**: Giữ chỉ số >= 50%, tối đa hóa lợi nhuận

---

**Hệ thống hoàn chỉnh, cân bằng giữa AFK và tương tác!** 🎮
