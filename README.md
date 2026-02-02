# Wind Turbine Operator - Semi-AFK Job

Nghề vận hành trạm điện gió cho FiveM GTA V - Cho phép người chơi AFK vẫn sinh tiền.

## Tính năng

- ✅ **Semi-AFK**: Người chơi AFK vẫn sinh tiền dựa trên hiệu suất máy
- ✅ **5 hệ thống**: Stability, Electric, Lubrication, Blades, Safety
- ✅ **UI hiện đại**: Quạt tuabin quay, thanh tròn progress, industrial design
- ✅ **Minigame sửa chữa**: System Calibration với độ khó khác nhau
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
Config.TurbineLocation = vector3(2476.85, 1589.21, 32.73)

-- Lương cơ bản ($/phút)
Config.BaseSalary = 100

-- Chu kỳ sinh tiền (ms)
Config.EarningCycle = 60000 -- 60 giây

-- Chu kỳ giảm hệ thống (ms)
Config.DegradeCycle = 120000 -- 2 phút
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
   - Vàng (30-50%): Cảnh báo
   - Đỏ (<30%): Nguy hiểm
5. Click vào thanh để sửa chữa (minigame)
6. Click vào quạt tuabin để xem quỹ tiền
7. Nhấn **RÚT TIỀN** để nhận lương

## Logic sinh tiền

- Tiền sinh ra = `BaseSalary × (Hiệu suất / 100)`
- Hiệu suất = Trung bình 5 hệ thống
- **Điều kiện giảm tiền:**
  - 1 thanh < 30%: Giảm 30%
  - 2 thanh < 30%: Giảm 60%
  - ≥3 thanh < 50%: Ngừng sinh tiền

## Minigame

- Thanh chạy ngang với vùng xanh
- Nhấn **SPACE** hoặc **E** khi thanh ở vùng xanh
- **Perfect**: +20%
- **Good**: +10%
- **Fail**: -5%

## Hỗ trợ

- Discord: [Your Discord]
- GitHub: [Your GitHub]

## License

MIT License
