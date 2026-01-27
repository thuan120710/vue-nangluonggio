# 🌬️ HỆ THỐNG THUÊ TRẠM ĐIỆN GIÓ

## ✅ Đã hoàn thành

### 🎯 Tính năng mới

1. **UI Thuê Trạm** - Giao diện chuyên nghiệp hiển thị:
   - Giá thuê: $50,000 IC
   - Thời hạn: 7 ngày
   - Thu nhập dự kiến: ~5,000 IC/giờ
   - Thông tin chi tiết về hệ thống

2. **Hệ thống thuê**:
   - Trừ tiền khi thuê
   - Lưu chủ sở hữu (citizenid)
   - Chỉ chủ mới được làm việc
   - Người khác không thể thuê/dùng

3. **Tự động reset**:
   - Sau 7 ngày tự động hết hạn
   - Phải thuê lại để tiếp tục
   - Thông báo trước 24h khi sắp hết hạn

4. **Thông báo qua Phone**:
   - Xác nhận thuê thành công
   - Cảnh báo sắp hết hạn (24h trước)
   - Thông tin chi tiết về thời hạn

## 📋 Cách hoạt động

### Khi chưa thuê trạm
```
1. Player đến gần trạm
2. Hiển thị: "[E] Thuê trạm điện gió"
3. Bấm E → Mở UI thuê trạm
4. Hiển thị giá, thời hạn, thông tin
5. Bấm "Thuê trạm" → Trừ tiền → Thành công
```

### Khi đã thuê (là chủ)
```
1. Player đến gần trạm
2. Hiển thị: "[E] Bắt đầu ca làm việc"
3. Bấm E → Mở UI làm việc bình thường
4. Làm việc như cũ
```

### Khi đã thuê (không phải chủ)
```
1. Player đến gần trạm
2. Hiển thị: "Đã thuê bởi: [Tên chủ]"
3. Bấm E → Thông báo lỗi
4. Không thể thuê/dùng
```

### Khi hết hạn (sau 7 ngày)
```
1. Tự động xóa thông tin thuê
2. Trạm trở về trạng thái "Chưa thuê"
3. Bất kỳ ai cũng có thể thuê lại
4. Chủ cũ phải thuê lại nếu muốn tiếp tục
```

## 🔧 Config

```lua
-- config.lua
Config.RentalPrice = 50000 -- Giá thuê (IC)
Config.RentalDuration = 604800 -- 7 ngày (giây)
```

## 📁 Files đã thay đổi

### Server (server/main.lua)
- ✅ Thêm `TurbineRentals` - Lưu dữ liệu thuê
- ✅ Thêm `CheckRentalExpiry()` - Kiểm tra hết hạn
- ✅ Thêm `GetRentalInfo()` - Lấy thông tin thuê
- ✅ Event `windturbine:checkRentalStatus` - Kiểm tra trạng thái
- ✅ Event `windturbine:rentTurbine` - Thuê trạm
- ✅ Thread kiểm tra hết hạn mỗi giờ

### Client (client/main.lua)
- ✅ Thêm `rentalStatus` - Lưu trạng thái thuê
- ✅ Thêm `turbineId` - ID trạm
- ✅ Thêm `OpenRentalUI()` - Mở UI thuê
- ✅ Sửa `OpenMainUI()` - Kiểm tra quyền trước khi mở
- ✅ Sửa `startDuty` - Kiểm tra quyền chủ
- ✅ Sửa marker text - Hiển thị theo trạng thái
- ✅ Event `windturbine:rentalStatusResponse`
- ✅ Event `windturbine:rentSuccess`
- ✅ Event `windturbine:rentFailed`

### NUI (nui-vue/src/)
- ✅ Thêm `RentalUI.vue` - Component UI thuê trạm
- ✅ Sửa `App.vue` - Thêm rental view
- ✅ Thêm action `showRentalUI`
- ✅ Thêm callback `rentTurbine`

### Config (config.lua)
- ✅ Thêm `Config.RentalPrice`
- ✅ Thêm `Config.RentalDuration`

## 🚀 Cách build NUI

```bash
cd nui-vue
npm install
npm run build
```

Sau khi build xong, file sẽ được tạo trong `nui-dist/`

## 🎨 UI Design

### RentalUI Features:
- ✅ Gradient background chuyên nghiệp
- ✅ Icon xoay (cối xay gió)
- ✅ Info cards với hover effect
- ✅ Feature list chi tiết
- ✅ Status section (Available/Rented)
- ✅ Button với animation
- ✅ Responsive design
- ✅ Format tiền và thời gian

## 📊 Database

**Không cần database!** Dữ liệu lưu trong bộ nhớ server:

```lua
TurbineRentals = {
    ["turbine_1"] = {
        citizenid = "ABC12345",
        ownerName = "John Doe",
        playerId = 1,
        rentalTime = 1234567890,
        expiryTime = 1235172690
    }
}
```

## ⚠️ Lưu ý

1. **Restart server** → Mất dữ liệu thuê (vì lưu trong RAM)
2. **Muốn lưu vĩnh viễn** → Cần thêm MySQL/oxmysql
3. **Test mode** → Có thể giảm `RentalDuration` để test nhanh
4. **Multiple turbines** → Có thể thêm nhiều trạm với ID khác nhau

## 🧪 Test

1. Đến gần trạm → Hiển thị "[E] Thuê trạm"
2. Bấm E → Mở UI thuê
3. Bấm "Thuê trạm" → Trừ $50,000
4. Thông báo thành công
5. Bấm E lại → Mở UI làm việc
6. Player khác đến → Không thể thuê/dùng
7. Sau 7 ngày → Tự động reset

## 🎯 Kết quả

- ✅ UI chuyên nghiệp, đẹp mắt
- ✅ Hệ thống thuê hoàn chỉnh
- ✅ Bảo vệ trạm (chỉ chủ dùng được)
- ✅ Tự động reset sau 7 ngày
- ✅ Thông báo qua phone
- ✅ Không có lỗi syntax

---

**Tác giả:** Senior FiveM Developer  
**Ngày:** 2026-01-27  
**Trạng thái:** ✅ Hoàn thành - Cần build NUI
