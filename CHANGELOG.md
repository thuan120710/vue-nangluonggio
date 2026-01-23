# Changelog - Wind Turbine Job

## [2.0.0] - 2026-01-19 - HỆ THỐNG NĂNG LƯỢNG GIÓ HOÀN CHỈNH

### ⚡ Added - Tính năng mới

#### Hệ thống 5 chỉ số (Mỗi chỉ số = 20% lợi nhuận)
- **Stability**: Độ ổn định cánh quạt
- **Electric**: Hệ thống điện
- **Lubrication**: Hệ thống bôi trơn
- **Blades**: Thân tháp
- **Safety**: An toàn

#### Penalty System - Giảm độ bền theo giờ hoạt động
- **0-2 giờ**: Không có penalty
- **2-4 giờ**: 
  - 80%: 1 bộ phận -10% độ bền
  - 20%: 1-2 bộ phận -10% độ bền
- **4-8 giờ**:
  - 55%: 1-2 bộ phận -30% độ bền
  - 30%: 1 bộ phận -20% độ bền
  - 15%: Không bị gì
- **8-12 giờ**:
  - 40%: 1 bộ phận -25% độ bền
  - 30%: 1-2 bộ phận -30% độ bền
  - 20%: 1 bộ phận -40% độ bền
  - 10%: Không bị gì

#### Giới hạn thời gian
- ✅ **12 giờ/ngày** tối đa
- ✅ **84 giờ/tuần** tối đa
- ✅ Tự động kết thúc ca khi hết giờ
- ✅ Reset hàng ngày và hàng tuần

#### Logic lợi nhuận mới
- **Lợi nhuận cơ bản**: 5,000 IC/giờ (83.33 IC/phút)
- **Chỉ số < 50%**: Giảm 50% lợi nhuận của chỉ số đó
- **Chỉ số < 30%**: Ngừng sinh lợi nhuận từ chỉ số đó
- **3 chỉ số < 30%**: Máy ngừng hoạt động hoàn toàn
- **Điểm hòa vốn**: 40 giờ
- **Lợi nhuận tối đa**: 220,000 IC/tuần (44 giờ)

### 🔄 Changed - Thay đổi

#### Logic tính toán
- 🔄 Thay đổi từ hiệu suất trung bình → Tính từng chỉ số riêng biệt
- 🔄 Giảm độ bền tự nhiên: 2-5% mỗi giờ (thay vì 1-3% mỗi 2 phút)
- 🔄 Chu kỳ penalty: Mỗi giờ (thay vì không có)
- 🔄 Giá trị khởi tạo: 100% (thay vì 70%)

#### Thông báo
- 🔄 Thông báo penalty khi xảy ra
- 🔄 Thông báo giới hạn thời gian
- 🔄 Thông báo máy ngừng hoạt động (3 chỉ số < 30%)
- 🔄 Hiển thị thời gian làm việc trong log

### 🐛 Fixed - Sửa lỗi

- ✅ Sửa lỗi không theo dõi thời gian làm việc
- ✅ Sửa lỗi không có giới hạn thời gian
- ✅ Sửa lỗi tính lợi nhuận không chính xác theo yêu cầu
- ✅ Sửa lỗi không có penalty system

### 📊 Thống kê

```
Lợi nhuận tối đa/tuần: 220,000 IC
Thời gian hòa vốn: 40 giờ
Thời gian tối đa/ngày: 12 giờ
Thời gian tối đa/tuần: 84 giờ
Số chỉ số: 5 (mỗi chỉ số = 20%)
```

---

## [1.0.0] - 2026-01-18 - PHIÊN BẢN ĐẦU TIÊN

### 🔊 Âm thanh đã thêm

#### Client-side (FiveM Native Sounds):
- **Bắt đầu ca làm việc**: Âm thanh "CHECKPOINT_PERFECT" - Tạo cảm giác tích cực khi bắt đầu
- **Kết thúc ca làm việc**: Âm thanh "QUIT" - Âm thanh thoát nhẹ nhàng
- **Rút tiền**: Âm thanh "PICK_UP" - Âm thanh nhặt tiền
- **Sửa chữa thành công (Perfect)**: Âm thanh "CHECKPOINT_PERFECT" - Âm thanh hoàn hảo
- **Sửa chữa tốt (Good)**: Âm thanh "CHECKPOINT_NORMAL" - Âm thanh bình thường
- **Sửa chữa thất bại (Fail)**: Âm thanh "CHECKPOINT_MISSED" - Âm thanh thất bại
- **Cảnh báo hệ thống**: Âm thanh "CHECKPOINT_MISSED" - Khi hệ thống xuống dưới 30%

#### NUI-side (Web Audio API):
- **Click**: Âm thanh click nhẹ (600Hz, 0.1s) - Khi click vào hệ thống, siết ốc, gạt cầu dao
- **Success**: Âm thanh thành công (800Hz, 0.3s) - Khi hoàn thành minigame hoàn hảo
- **Fail**: Âm thanh thất bại (200Hz, 0.2s) - Khi thất bại trong minigame
- **Repair**: Âm thanh sửa chữa (400Hz, 0.15s) - Khi trét xi măng vào vết nứt

### 📢 Thông báo đã thêm

#### Thông báo trạng thái ca làm việc:
- ✅ **Bắt đầu ca**: "Đã bắt đầu ca làm việc tại cối xay gió!" (success, 3s)
- 👋 **Kết thúc ca**: "Đã kết thúc ca làm việc!" (primary, 3s)

#### Thông báo thu nhập:
- 💵 **Thu nhập thường**: "+$[số tiền]" (primary, 2s) - Khi hiệu suất 50-79%
- 💵 **Thu nhập cao**: "+$[số tiền] | Hiệu suất tuyệt vời!" (success, 2s) - Khi hiệu suất ≥80%
- ⚠️ **Ngừng sinh tiền**: "Cối xay gió ngừng sinh tiền! Cần sửa chữa hệ thống!" (error, 3s)
- 💰 **Rút tiền thành công**: "Đã rút $[số tiền] từ quỹ tiền lương!" (success)
- ❌ **Không có tiền**: "Không có tiền để rút!" (error)

#### Thông báo hệ thống:
- 🔧 **Xuống cấp**: "Các hệ thống đang xuống cấp theo thời gian..." (warning, 2s)
- ⚠️ **Cần bảo trì**: "Chú ý: Hệ thống [TÊN] cần bảo trì!" (warning, 3s) - Khi hệ thống 30-49%
- ⚠️ **Nguy hiểm**: "Cảnh báo: Hệ thống [TÊN] đang ở mức nguy hiểm!" (error, 5s) - Khi hệ thống <30%

#### Thông báo hiệu suất:
- 🚨 **Ngừng hoạt động**: "Cối xay gió đã ngừng hoạt động! Hiệu suất quá thấp!" (error, 5s) - Khi hiệu suất <10%
- ⚠️ **Hiệu suất thấp**: "Hiệu suất rất thấp! Cần sửa chữa ngay!" (error, 3s) - Khi hiệu suất <30%

#### Thông báo kết quả sửa chữa:
- 🌟 **Hoàn hảo**: "Hoàn hảo! Hệ thống [TÊN] đã được sửa chữa tốt!" (success, 3s)
- ✅ **Tốt**: "Tốt! Hệ thống [TÊN] đã được cải thiện!" (success, 3s)
- ❌ **Thất bại**: "Thất bại! Hệ thống [TÊN] bị giảm hiệu suất!" (error, 3s)

#### Thông báo khoảng cách:
- ⚠️ **Rời xa**: "Bạn đang rời xa cối xay gió! Ca làm việc vẫn tiếp tục." (warning, 5s) - Khi cách >50m (thông báo mỗi 30s)

### 🎮 Tính năng

1. **UI hiện đại**: Quạt tuabin quay, thanh tròn progress, industrial design
2. **5 hệ thống**: Stability, Electric, Lubrication, Blades, Safety
3. **4 loại minigame**: 
   - Bar (Lubrication, Safety)
   - Fan (Stability) - Siết ốc và xoay quạt
   - Circuit Breaker (Electric) - Gạt cầu dao
   - Crack Repair (Blades) - Trét xi măng
4. **Quỹ tiền**: Earnings pool, không cộng tiền trực tiếp
5. **Logic server-side**: 100% tính toán trên server, chống exploit
6. **Tích hợp QBCore**: Sử dụng QBCore notify và money system

### 📝 Ghi chú kỹ thuật

- Sử dụng QBCore.Functions.Notify cho thông báo
- Sử dụng FiveM Native Sounds (PlaySound) cho âm thanh client-side
- Sử dụng Web Audio API cho âm thanh NUI-side
- Tất cả thông báo đều có icon emoji để dễ nhận biết
- Thời gian hiển thị thông báo được tối ưu theo mức độ quan trọng
