# Test Work Time Update

## Vấn đề đã sửa
Work time không cập nhật sau 1 giờ vì:
- Trước: Cập nhật work time SAU khi gọi `ApplyPenalty()`
- Nếu 0-2h (không có penalty), function return sớm → không cập nhật work time

## Giải pháp
Đổi thứ tự:
1. **Cập nhật work time TRƯỚC** (luôn luôn)
2. Sau đó mới gọi `ApplyPenalty()` (có thể return sớm)

## Code mới
```lua
-- Áp dụng penalty mỗi giờ
if currentTime - data.lastPenalty >= (Config.PenaltyCycle / 1000) then
    -- 1. Cập nhật work time TRƯỚC (luôn luôn chạy)
    local currentWorkHours = (currentTime - data.workStartTime) / 3600
    TriggerClientEvent('windturbine:updateWorkTime', playerId, currentWorkHours, Config.MaxDailyHours)
    
    print(('[Wind Turbine] Player %s: Work time updated to %.1fh'):format(playerId, currentWorkHours))
    
    -- 2. Sau đó mới check penalty (có thể return sớm)
    ApplyPenalty(playerId)
    data.lastPenalty = currentTime
end
```

## Timeline test
```
00:00 → Bắt đầu ca
        UI: ONLINE - 0.0h/12h
        Server log: "Player X started duty"

01:00 → Sau 1 giờ (penalty cycle)
        Server log: "Player X: Work time updated to 1.0h"
        Server log: "Player X: No penalty (1.0 hours worked)" (0-2h không penalty)
        UI: ONLINE - 1.0h/12h ✅

02:00 → Sau 2 giờ
        Server log: "Player X: Work time updated to 2.0h"
        Server log: "Player X penalty: ..." (bắt đầu có penalty)
        UI: ONLINE - 2.0h/12h ✅

03:00 → Sau 3 giờ
        Server log: "Player X: Work time updated to 3.0h"
        UI: ONLINE - 3.0h/12h ✅
```

## Cách test
1. Bắt đầu ca làm việc
2. Đợi 1 giờ (3600 giây)
3. Check server console: Phải thấy log "Work time updated to 1.0h"
4. Check UI: Phải thấy "ONLINE - 1.0h/12h"

## Lưu ý
- `Config.PenaltyCycle = 3600000` (1 giờ = 3600 giây = 3600000 ms)
- Work time cập nhật mỗi giờ, không phải mỗi 15 phút
- Penalty chỉ áp dụng từ giờ thứ 2 trở đi (0-2h không penalty)
