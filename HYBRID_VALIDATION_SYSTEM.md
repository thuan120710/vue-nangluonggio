# Hệ thống Validation Hybrid - Anti-Cheat

## Tổng quan
Đã implement hệ thống validation hybrid kết hợp client và server để chống cheat, đồng thời tối ưu hiệu năng.

## Kiến trúc

### Client-side (Real-time UX)
- Tính toán và hiển thị thời gian làm việc real-time
- Tự động kết thúc ca khi hết giờ (UX tốt)
- Kiểm tra giới hạn trước khi start duty (giảm lag)
- Gửi dữ liệu lên server khi có action quan trọng
- `GetCurrentDay()`: Tính ngày dựa trên `GetCloudTimeAsInt()` (client time)

### Server-side (Validation & Anti-cheat)
- Lưu trữ: `PlayerWorkData[citizenid]` với:
  - `workStartTime`: Thời điểm bắt đầu ca (timestamp)
  - `dailyWorkHours`: Tổng giờ làm việc trong ngày
  - `lastDayReset`: Ngày reset cuối cùng (số ngày từ epoch)
- `GetCurrentDay()`: Tính ngày dựa trên `os.time()` (server time) - ĐỒNG BỘ với client
- Validate CHỈ khi cần:
  - StartDuty: Kiểm tra `dailyWorkHours < MaxDailyHours`
  - WithdrawEarnings: Validate số tiền với thời gian làm việc
  - StopDuty: Cập nhật `dailyWorkHours`

## GetCurrentDay() - Đồng bộ Client & Server

Cả client và server đều dùng CÙNG LOGIC để tính ngày:

```lua
-- Reset vào 6:00 sáng giờ Việt Nam (UTC+7)
local function GetCurrentDay()
    local timestamp = GetCloudTimeAsInt() -- Client: GetCloudTimeAsInt() | Server: os.time()
    -- Điều chỉnh để reset vào 6:00 sáng VN thay vì 00:00 VN
    -- 6:00 VN = 23:00 UTC ngày hôm trước
    local vietnamOffset = (7 * 3600) - (6 * 3600) -- UTC+7 - 6 giờ = UTC+1
    local adjustedTime = timestamp + vietnamOffset
    local days = math.floor(adjustedTime / 86400)
    return tostring(days) -- Trả về số ngày kể từ epoch
end
```

**Lý do giữ cả 2:**
- Client cần để kiểm tra local và hiển thị UI
- Server cần để validate và anti-cheat
- Cùng logic đảm bảo đồng bộ (reset cùng lúc vào 6:00 sáng VN)

## Flow hoạt động

### 1. Start Duty
```
Client: Click "Bắt đầu ca" 
  → Kiểm tra xăng, grace period
  → TriggerServerEvent('windturbine:startDuty')

Server: Nhận request
  → CheckAndResetDailyHours() // Reset nếu qua ngày mới
  → Validate: dailyWorkHours < MaxDailyHours
  → Lưu workStartTime = os.time()
  → TriggerClientEvent('windturbine:startDutySuccess')

Client: Nhận success
  → Bắt đầu ca làm việc
  → Hiển thị UI, bắt đầu tính tiền
```

### 2. Stop Duty
```
Client: Click "Kết thúc ca" hoặc tự động khi hết giờ
  → Tính workDuration = (now - workStartTime) / 3600
  → TriggerServerEvent('windturbine:stopDuty', workDuration)
  → Cập nhật local dailyWorkHours

Server: Nhận request
  → Tính serverWorkDuration từ workStartTime
  → So sánh với client (cho phép sai số 5%)
  → Cập nhật dailyWorkHours
  → Reset workStartTime = 0
```

### 3. Withdraw Earnings
```
Client: Click "Rút tiền"
  → Tính currentWorkHours nếu đang onDuty
  → TriggerServerEvent('windturbine:withdrawEarnings', amount, isGracePeriod, turbineId, currentWorkHours)

Server: Nhận request
  → ValidateWithdrawAmount():
    - Tính serverWorkHours từ workStartTime
    - So sánh với clientWorkHours (sai số < 5%)
    - Tính maxPossibleEarnings = hours * BaseSalary * 1.2
    - Validate: amount <= maxPossibleEarnings
  → Nếu valid: Cho rút tiền + cập nhật dailyWorkHours
  → Nếu invalid: Reject với lý do cụ thể
```

## Anti-cheat Features

### 1. Time Validation
- Server lưu `workStartTime` độc lập
- So sánh thời gian client vs server (cho phép sai số 5% + 0.1h buffer)
- Phát hiện nếu client modify thời gian

### 2. Earnings Validation
- Tính max earnings có thể: `hours * BaseSalary * 1.2` (20% buffer cho bonus)
- Reject nếu số tiền vượt quá giới hạn
- Phát hiện nếu client hack earnings pool

### 3. Daily Limit Enforcement
- Server track `dailyWorkHours` độc lập
- Validate trước khi StartDuty
- Validate khi WithdrawEarnings
- Auto-reset vào 6:00 sáng mỗi ngày

## Ưu điểm

### Performance
- Server KHÔNG chạy thread liên tục
- Chỉ validate khi có action (StartDuty, StopDuty, Withdraw)
- Client tự do tính toán real-time
- Giảm tải server đáng kể

### Security
- Chống cheat ở các điểm quan trọng
- Validate thời gian và số tiền
- Server có quyền quyết định cuối cùng

### UX
- Client vẫn responsive và real-time
- Không có lag khi hiển thị UI
- Tự động kết thúc ca mượt mà

## Các trường hợp xử lý

### Disconnect/Reconnect
- Server lưu `workStartTime` và `dailyWorkHours`
- Khi reconnect, client sẽ sync lại từ server
- Không mất dữ liệu thời gian làm việc

### Time Mismatch
- Nếu sai số > 5%: Server dùng thời gian của mình
- Client được thông báo "Lỗi đồng bộ thời gian"
- Không cho rút tiền nếu time không khớp

### Cheat Detection
- TIME_MISMATCH: Client modify thời gian
- AMOUNT_TOO_HIGH: Client hack earnings pool
- DAILY_LIMIT: Vượt quá giới hạn 12 giờ/ngày

## Testing

### Test Cases
1. Start duty bình thường → OK
2. Start duty khi đã hết giờ → Reject với DAILY_LIMIT
3. Withdraw với số tiền hợp lý → OK
4. Withdraw với số tiền quá cao → Reject với AMOUNT_TOO_HIGH
5. Disconnect giữa ca → Reconnect vẫn giữ dailyWorkHours
6. Qua ngày mới (6:00 sáng) → Auto reset dailyWorkHours

### Commands để test
```lua
-- Test mode: 12 phút = 12 giờ
-- Production: 12 giờ thực

-- Kiểm tra dailyWorkHours từ server
QBCore.Functions.CreateCallback('windturbine:getDailyWorkHours', ...)
```

## Kết luận
Hệ thống hybrid này cân bằng tốt giữa performance và security, phù hợp cho server có nhiều người chơi.
