# Tính năng hiển thị thời gian làm việc

## Mô tả
Hiển thị thời gian làm việc trên UI footer, cập nhật **mỗi giờ**.

## Vị trí hiển thị
**Footer UI** - Status (góc dưới trái):
- `OFFLINE` - Chưa bắt đầu ca
- `ONLINE - 2.0h/12h` - Đang làm việc (2 giờ / tối đa 12 giờ)

## Chu kỳ cập nhật
Cập nhật **mỗi 1 giờ** (khi degrade hệ thống):
- ✅ 00:00 → Bắt đầu ca: `ONLINE - 0.0h/12h`
- ✅ 01:00 → Degrade: `ONLINE - 1.0h/12h`
- ✅ 02:00 → Degrade: `ONLINE - 2.0h/12h`
- ✅ 03:00 → Degrade: `ONLINE - 3.0h/12h`
- ...
- ✅ 12:00 → Đạt giới hạn: `OFFLINE` (tự động kết thúc)

## Lợi ích
- ✅ Đơn giản, dễ hiểu
- ✅ Cập nhật đúng mỗi giờ (1 request/giờ)
- ✅ Tiết kiệm tài nguyên server
- ✅ Đồng bộ với degrade cycle

## Code
```lua
-- Server: Cập nhật work time mỗi giờ (khi degrade)
if currentTime - data.lastDegrade >= (Config.DegradeCycle / 1000) then
    DegradeSystems(playerId)
    
    -- Cập nhật work time
    local currentWorkHours = (currentTime - data.workStartTime) / 3600
    TriggerClientEvent('windturbine:updateWorkTime', playerId, currentWorkHours, Config.MaxDailyHours)
end
```

## Timeline ví dụ
```
00:00 → ONLINE - 0.0h/12h (bắt đầu ca)
01:00 → ONLINE - 1.0h/12h (degrade)
02:00 → ONLINE - 2.0h/12h (degrade)
03:00 → ONLINE - 3.0h/12h (degrade)
...
12:00 → OFFLINE (tự động kết thúc)
```

## Lưu ý
- Hiển thị số nguyên giờ (1.0h, 2.0h, 3.0h...)
- Không cập nhật khi sinh tiền (15 phút)
- Chỉ cập nhật khi degrade (1 giờ)
- Tự động reset về OFFLINE khi kết thúc ca
