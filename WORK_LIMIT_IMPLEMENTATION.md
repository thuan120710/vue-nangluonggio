# Triển khai Giới hạn Thời gian Làm việc

## Tổng quan
Hệ thống đã được cập nhật để ngăn người chơi bắt đầu ca làm việc mới sau khi đạt giới hạn 12 phút (trong test mode) hoặc 12 giờ (trong production mode).

## Các thay đổi chính

### 1. Server (server/main.lua)

#### Thay đổi thông báo khi đạt giới hạn
- Khi người chơi cố gắng bắt đầu ca làm việc nhưng đã đạt giới hạn:
  - **Daily limit**: Hiển thị "❌ Đã đạt giới hạn! Hãy quay lại vào ngày mai."
  - **Weekly limit**: Hiển thị "❌ Đã đạt giới hạn tuần! Hãy quay lại vào tuần sau."
- Gửi event `windturbine:workLimitReached` đến client để cập nhật UI

#### Reset giới hạn tự động
- Khi ngày mới hoặc tuần mới bắt đầu, server tự động:
  - Reset counter (dailyWorkHours hoặc weeklyWorkHours)
  - Gửi event `windturbine:resetWorkLimit` đến client để enable lại nút Start

### 2. Client (client/main.lua)

#### Event mới
- `windturbine:workLimitReached`: Nhận thông báo từ server khi đạt giới hạn
- `windturbine:resetWorkLimit`: Nhận thông báo từ server khi reset giới hạn (ngày mới)

### 3. UI (nui/script.js)

#### Biến trạng thái mới
```javascript
let workLimitReached = false; // Track if work limit has been reached
```

#### Logic nút Start
- Kiểm tra `workLimitReached` trước khi cho phép bấm Start
- Nếu đã đạt giới hạn:
  - Phát âm thanh fail
  - Không gửi request startDuty đến server
  - Thông báo đã được hiển thị từ server

#### Action mới trong message handler

**workLimitReached**:
- Đánh dấu `workLimitReached = true`
- Disable nút Start:
  - `disabled = true`
  - Thêm class `disabled-limit`
  - Đổi text thành "ĐÃ ĐẠT GIỚI HẠN"
- Cập nhật status text: "ĐÃ ĐẠT GIỚI HẠN - QUAY LẠI NGÀY MAI" (màu đỏ)

**resetWorkLimit**:
- Reset `workLimitReached = false`
- Enable lại nút Start:
  - `disabled = false`
  - Xóa class `disabled-limit`
  - Đổi text về "BẮT ĐẦU CA"
- Reset status text về "OFFLINE"

### 4. CSS (nui/style.css)

#### Style mới cho nút disabled
```css
.btn-start.disabled-limit {
    background: rgba(255, 68, 68, 0.2);
    border-color: #ff4444;
    color: #ff4444;
    cursor: not-allowed;
    opacity: 0.6;
}
```

## Luồng hoạt động

### Khi đạt giới hạn (12 phút trong test mode)

1. **Server tự động dừng ca làm việc**:
   - Kiểm tra `totalDailyHours >= Config.MaxDailyHours`
   - Set `onDuty = false`
   - Gửi event `windturbine:stopTurbine` đến client
   - Hiển thị thông báo: "⏰ Đã hết giờ làm việc trong ngày!"

2. **Người chơi cố gắng bấm Start lại**:
   - Client kiểm tra `workLimitReached` → Nếu true, không cho phép
   - Nếu somehow vẫn gửi request, server sẽ reject:
     - Gọi `CheckTimeLimit(playerId)`
     - Return `false, "DAILY_LIMIT"`
     - Gửi thông báo: "❌ Đã đạt giới hạn! Hãy quay lại vào ngày mai."
     - Gửi event `windturbine:workLimitReached` đến client

3. **Client nhận event workLimitReached**:
   - Disable nút Start
   - Đổi text thành "ĐÃ ĐẠT GIỚI HẠN"
   - Cập nhật status: "ĐÃ ĐẠT GIỚI HẠN - QUAY LẠI NGÀY MAI"

### Khi ngày mới bắt đầu

1. **Server tự động reset**:
   - Kiểm tra `lastDayReset != currentDay`
   - Reset `dailyWorkHours = 0`
   - Gửi event `windturbine:resetWorkLimit` đến client

2. **Client nhận event resetWorkLimit**:
   - Reset `workLimitReached = false`
   - Enable lại nút Start
   - Đổi text về "BẮT ĐẦU CA"
   - Reset status về "OFFLINE"

## Test Mode vs Production Mode

### Test Mode (Config.TestMode = true)
- Giới hạn: 12 phút (0.2 giờ)
- Chu kỳ sinh tiền: 30 giây
- Chu kỳ penalty: 1 phút

### Production Mode (Config.TestMode = false)
- Giới hạn: 12 giờ
- Chu kỳ sinh tiền: 15 phút
- Chu kỳ penalty: 1 giờ

## Lưu ý quan trọng

1. **Không thể bypass**: Người chơi không thể bắt đầu ca mới sau khi đạt giới hạn cho đến ngày mai
2. **Reset tự động**: Hệ thống tự động reset vào ngày mới (00:00)
3. **UI feedback rõ ràng**: Nút Start bị disable và hiển thị thông báo rõ ràng
4. **Server-side validation**: Ngay cả khi client bị hack, server vẫn kiểm tra và reject request

## Kết quả

✅ Sau 12 phút (test mode), hệ thống sẽ:
- Tự động dừng ca làm việc
- Không cho phép bấm Start lại
- Hiển thị thông báo: "Đã đạt giới hạn! Hãy quay lại vào ngày mai"
- Nút Start bị disable với text "ĐÃ ĐẠT GIỚI HẠN"
- Status hiển thị: "ĐÃ ĐẠT GIỚI HẠN - QUAY LẠI NGÀY MAI"
