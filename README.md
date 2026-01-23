# Wind Turbine Operator - Semi-AFK Job

Nghề vận hành trạm điện gió cho FiveM GTA V - Cho phép người chơi AFK vẫn sinh tiền với hệ thống penalty và giới hạn thời gian.

## Tính năng

- ✅ **Semi-AFK**: Người chơi AFK vẫn sinh tiền dựa trên hiệu suất máy
- ✅ **5 hệ thống**: Stability, Electric, Lubrication, Blades, Safety (mỗi chỉ số = 20% lợi nhuận)
- ✅ **Penalty System**: Độ bền giảm theo giờ hoạt động (0-2h, 2-4h, 4-8h, 8-12h)
- ✅ **Giới hạn thời gian**: 12 giờ/ngày, 84 giờ/tuần
- ✅ **UI hiện đại**: Quạt tuabin quay, thanh tròn progress, industrial design
- ✅ **4 loại minigame**: Bar, Fan (Stability), Circuit Breaker (Electric), Crack Repair (Blades)
- ✅ **Quỹ tiền**: Earnings pool, không cộng tiền trực tiếp
- ✅ **Logic server-side**: 100% tính toán trên server, chống exploit

## Cài đặt

1. Copy folder `windturbine` vào `resources/`
2. Thêm vào `server.cfg`:
```
ensure windturbine
```

## Cấu hình

Chỉnh sửa `config.lua`:

```lua
-- Vị trí trạm điện gió
Config.TurbineLocation = vector4(2319.23, 1608.74, 57.94, 357.2)

-- Lợi nhuận: 5,000 IC/giờ = 83.33 IC/phút
Config.BaseSalary = 83.33

-- Thời gian làm việc tối đa
Config.MaxDailyHours = 12  -- 12 giờ/ngày
Config.MaxWeeklyHours = 84 -- 84 giờ/tuần

-- Mỗi chỉ số đóng góp 20% lợi nhuận
Config.SystemProfitContribution = 20
```

## Framework

Resource này đã được tích hợp sẵn với **QBCore**.

- Sử dụng `QBCore:Notify` cho thông báo
- Tiền được thêm vào `cash` khi rút
- Tự động load QBCore object

## Cách chơi

1. Đến vị trí trạm điện gió (marker xanh)
2. Nhấn **E** để mở UI
3. Nhấn **BẮT ĐẦU CA**
4. Theo dõi 5 thanh hệ thống:
   - Xanh (>50%): Tốt
   - Vàng (30-50%): Cảnh báo, giảm 50% lợi nhuận của chỉ số đó
   - Đỏ (<30%): Nguy hiểm, ngừng sinh lợi nhuận từ chỉ số đó
5. Click vào thanh để sửa chữa (minigame khác nhau cho mỗi hệ thống)
6. Click vào quạt tuabin để xem quỹ tiền
7. Nhấn **RÚT TIỀN** để nhận lương

## Logic sinh tiền

### Lợi nhuận cơ bản
- **5,000 IC/giờ** (83.33 IC/phút)
- Mỗi chỉ số đóng góp **20% lợi nhuận tổng**

### Điều kiện giảm lợi nhuận
- **Chỉ số < 50%**: Giảm 50% lợi nhuận của chỉ số đó
- **Chỉ số < 30%**: Ngừng sinh lợi nhuận từ chỉ số đó
- **3 chỉ số < 30%**: Máy ngừng hoạt động hoàn toàn

### Ví dụ tính toán
- Tất cả chỉ số 100%: 5,000 IC/giờ
- 1 chỉ số 40% (< 50%): Mất 10% lợi nhuận → 4,500 IC/giờ
- 1 chỉ số 20% (< 30%): Mất 20% lợi nhuận → 4,000 IC/giờ
- 3 chỉ số < 30%: Máy ngừng → 0 IC/giờ

## Hệ thống Penalty

Độ bền các chỉ số sẽ giảm **CHỈ theo penalty random mỗi giờ** (KHÔNG có giảm tự nhiên):

### 0-2 giờ
- **Không có penalty**

### 2-4 giờ
- 80%: 1 bộ phận -10% độ bền
- 20%: 1-2 bộ phận -10% độ bền

### 4-8 giờ
- 55%: 1-2 bộ phận -30% độ bền
- 30%: 1 bộ phận -20% độ bền
- 15%: Không bị gì

### 8-12 giờ
- 40%: 1 bộ phận -25% độ bền
- 30%: 1-2 bộ phận -30% độ bền
- 20%: 1 bộ phận -40% độ bền
- 10%: Không bị gì

**Lưu ý**: 
- Chỉ số chỉ giảm khi có penalty (random mỗi giờ)
- KHÔNG có giảm tự nhiên
- Tùy vào may mắn, có thể không bị penalty hoặc bị giảm nhiều

## Giới hạn thời gian

- **Tối đa 12 giờ/ngày**
- **Tối đa 84 giờ/tuần**
- Tự động kết thúc ca khi hết giờ
- Reset hàng ngày và hàng tuần

## Điểm hòa vốn

- **40 giờ** làm việc để hòa vốn
- **Lợi nhuận tối đa**: 44 giờ × 5,000 IC = **220,000 IC/tuần**

## Minigame

### 1. Bar Minigame (Lubrication, Safety)
- Thanh chạy ngang với vùng xanh
- Nhấn **SPACE** hoặc **E** khi thanh ở vùng xanh

### 2. Fan Minigame (Stability)
- **Phase 1**: Click vào 3 ốc để siết
- **Phase 2**: Xoay chuột theo chiều kim đồng hồ

### 3. Circuit Breaker (Electric)
- Kéo cầu dao lên để chuyển về màu xanh
- Đỏ: Kéo 2 lần | Vàng: Kéo 1 lần | Xanh: Đã ổn

### 4. Crack Repair (Blades)
- Click hoặc kéo chuột trên vết nứt để trét xi măng
- Sửa hết tất cả vết nứt

### Kết quả
- **Perfect**: +20% độ bền
- **Good**: +10% độ bền
- **Fail**: -5% độ bền

## Hỗ trợ

- Discord: [Your Discord]
- GitHub: [Your GitHub]

## License

MIT License
