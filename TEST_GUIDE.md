# 🧪 HƯỚNG DẪN TEST HỆ THỐNG THUÊ TRẠM ĐIỆN GIÓ

## ✅ ĐÃ HOÀN THÀNH

### 1. Chuyển logic từ server sang client
- ✅ Client xử lý toàn bộ logic tính toán (earnings, penalty, efficiency, work hours)
- ✅ Server chỉ xử lý: rút tiền, trừ tiền thuê, gửi phone notifications
- ✅ Fixed lỗi `os.time()` và `os.date()` bằng `GetGameTimer()` và `GetCloudTimeAsInt()`

### 2. Hệ thống thuê trạm
- ✅ UI thuê trạm chuyên nghiệp với nút X
- ✅ Giá thuê: Config.RentalPrice = 0 (miễn phí để test)
- ✅ Thời hạn: 7 ngày
- ✅ Server trừ tiền và gửi phone notifications

### 3. Xóa debug logs
- ✅ Đã xóa toàn bộ print statements
- ✅ Script chạy sạch sẽ, không spam console

### 4. Tối ưu cho 500 người - StateBag System
- ✅ **Server**: Dùng GlobalState để broadcast rental status
- ✅ **Client**: Dùng AddStateBagChangeHandler để tự động nhận cập nhật
- ✅ **KHÔNG CẦN CHECK LIÊN TỤC** - StateBag tự động đồng bộ
- ✅ Xóa toàn bộ code cũ (RequestRentalStatus, rentalStatusResponse event)

### 5. Thông báo trạm đã có chủ
- ✅ Hiển thị 3 dòng text ở dưới màn hình khi gần trạm đã có chủ
- ✅ Nội dung: "⚠️ TRẠM ĐIỆN GIÓ ĐÃ CÓ CHỦ", "Chủ sở hữu: [Tên]", "Bạn không thể sử dụng trạm này!"

---

## 🧪 CÁCH TEST VỚI 2 NGƯỜI CHƠI

### Bước 1: Player A thuê trạm
1. Player A đến gần trạm điện gió
2. Bấm E → Hiển thị UI thuê trạm
3. Click "Thuê trạm" → Thành công (miễn phí)
4. UI tự động chuyển sang UI làm việc

### Bước 2: Player B kiểm tra
1. Player B đến gần trạm điện gió
2. **Kiểm tra marker text**: Phải hiển thị "Đã thuê bởi: [Tên Player A]"
3. **Kiểm tra thông báo dưới màn hình**: Phải hiển thị:
   - "⚠️ TRẠM ĐIỆN GIÓ ĐÃ CÓ CHỦ"
   - "Chủ sở hữu: [Tên Player A]"
   - "Bạn không thể sử dụng trạm này!"
4. Bấm E → Phải thấy notify "❌ Trạm này đã được thuê bởi [Tên Player A]!"
5. **KHÔNG ĐƯỢC** mở UI thuê trạm

### Bước 3: Player B thử thuê (nếu vẫn mở được UI)
1. Nếu Player B vẫn mở được UI thuê trạm (không nên xảy ra)
2. Click "Thuê trạm" → Server phải reject
3. Notify: "❌ Trạm này đã được thuê bởi [Tên Player A]!"

### Bước 4: Player A làm việc bình thường
1. Player A bấm E → Mở UI làm việc
2. Bắt đầu ca làm việc → Hoạt động bình thường
3. Sửa chữa hệ thống → OK
4. Rút tiền → OK

---

## 🔍 ĐIỂM KIỂM TRA QUAN TRỌNG

### ✅ StateBag hoạt động đúng
- [ ] Player A thuê → Player B **NGAY LẬP TỨC** thấy trạm đã có chủ (không cần reload/reconnect)
- [ ] Player B không cần bấm E để check, chỉ cần đứng gần là thấy thông báo
- [ ] Không có log "RequestRentalStatus" trong console (đã xóa)

### ✅ UI và thông báo
- [ ] Marker text hiển thị đúng chủ sở hữu
- [ ] Thông báo dưới màn hình hiển thị 3 dòng rõ ràng
- [ ] Player B bấm E → Notify lỗi, không mở UI

### ✅ Server validation
- [ ] Player B thử thuê → Server reject ngay lập tức
- [ ] Không bị trừ tiền khi thuê thất bại

---

## 🐛 NẾU CÓ LỖI

### Lỗi: Player B vẫn thuê được trạm
**Nguyên nhân**: StateBag chưa load kịp hoặc client chưa lắng nghe đúng

**Cách fix**:
1. Kiểm tra console có log lỗi không
2. Restart script: `/restart f17_nangluonggio`
3. Kiểm tra lại AddStateBagChangeHandler trong client/main.lua

### Lỗi: Thông báo dưới màn hình không hiển thị
**Nguyên nhân**: DrawNotificationText() chưa được gọi đúng

**Cách fix**:
1. Kiểm tra thread "Hiển thị marker và text" có chạy không
2. Kiểm tra điều kiện: `rentalStatus.isRented and not rentalStatus.isOwner`

### Lỗi: Marker text không đổi
**Nguyên nhân**: rentalStatus chưa được cập nhật từ StateBag

**Cách fix**:
1. Kiểm tra GlobalState['turbine_turbine_1'] có data không (F8 console)
2. Restart script

---

## 📊 KẾT QUẢ MONG ĐỢI

✅ **Tối ưu cho 500 người**:
- Server chỉ broadcast 1 lần qua StateBag
- 500 client tự động nhận, không cần check liên tục
- Không có network spam

✅ **UX tốt**:
- Player B thấy ngay trạm đã có chủ khi đến gần
- Thông báo rõ ràng, không gây nhầm lẫn
- Không mở UI vô ích

✅ **Bảo mật**:
- Server validate 2 lần (trước khi trừ tiền + khi lưu data)
- Client không thể fake rental status

---

## 🎯 NEXT STEPS (NẾU CẦN)

1. Test với nhiều người hơn (5-10 người)
2. Test hết hạn thuê (7 ngày)
3. Thêm UI xem danh sách trạm đã thuê
4. Thêm lệnh admin để reset rental
