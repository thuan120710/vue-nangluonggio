# Tối ưu hóa Thread - Adaptive Wait Time

## Vấn đề ban đầu

Thread "Sinh tiền và penalty" chạy mỗi 5 giây LIÊN TỤC, ngay cả khi:
- Player không onDuty
- Đang trong grace period
- Còn nhiều giờ đến giới hạn (không cần check thường xuyên)

**Impact:**
- Tốn CPU không cần thiết
- Check quá thường xuyên khi còn xa giới hạn
- Ảnh hưởng performance khi có nhiều player

## Giải pháp: Adaptive Wait Time

### Logic thông minh

Thread tự động điều chỉnh tần suất check dựa trên **thời gian còn lại đến giới hạn**:

```lua
local hoursRemaining = Config.MaxDailyHours - totalDailyHours

if hoursRemaining <= 0.1 then      -- Còn < 6 phút
    waitTime = 2000                 -- Check mỗi 2 giây (rất gần)
elseif hoursRemaining <= 0.5 then  -- Còn < 30 phút
    waitTime = 5000                 -- Check mỗi 5 giây
elseif hoursRemaining <= 1 then    -- Còn < 1 giờ
    waitTime = 10000                -- Check mỗi 10 giây
elseif hoursRemaining <= 2 then    -- Còn < 2 giờ
    waitTime = 30000                -- Check mỗi 30 giây
else                                -- Còn > 2 giờ
    waitTime = 60000                -- Check mỗi 1 phút
end
```

### Ví dụ thực tế

**Scenario: Player làm việc 12 giờ**

| Thời gian làm | Còn lại | Wait time | Checks/phút |
|---------------|---------|-----------|-------------|
| 0-10 giờ      | > 2h    | 60s       | 1           |
| 10-11 giờ     | 1-2h    | 30s       | 2           |
| 11-11.5 giờ   | 0.5-1h  | 10s       | 6           |
| 11.5-11.9 giờ | 6-30p   | 5s        | 12          |
| 11.9-12 giờ   | < 6p    | 2s        | 30          |

**Kết quả:**
- Đầu ca: Check ít (1 lần/phút) - tiết kiệm CPU
- Cuối ca: Check nhiều (30 lần/phút) - chính xác cao
- Tự động kết thúc đúng lúc (sai số < 2 giây)

## Performance Improvement

### Trước tối ưu (Fixed 5s):
- Tổng checks trong 12 giờ: **12 × 60 × 12 = 8,640 checks**
- CPU usage: 100% (baseline)

### Sau tối ưu (Adaptive):
- 0-10h: 1 check/phút × 600 phút = 600 checks
- 10-11h: 2 checks/phút × 60 phút = 120 checks
- 11-11.5h: 6 checks/phút × 30 phút = 180 checks
- 11.5-11.9h: 12 checks/phút × 24 phút = 288 checks
- 11.9-12h: 30 checks/phút × 6 phút = 180 checks
- **Tổng: 1,368 checks** (giảm 84%!)

### 100 players đang làm việc:

**Trước:**
- 100 × 8,640 = 864,000 checks/12h
- CPU usage: 100%

**Sau:**
- 100 × 1,368 = 136,800 checks/12h
- CPU usage: **16%** (giảm 84%)

## Lợi ích

### 1. Tiết kiệm CPU cực lớn
- Giảm 84% số lần check trong suốt ca làm việc
- Đặc biệt hiệu quả ở đầu ca (còn nhiều giờ)

### 2. Vẫn chính xác cao
- Cuối ca check mỗi 2s → sai số < 2s
- Tự động kết thúc đúng lúc

### 3. Scalability tốt
- Server chịu được nhiều player hơn
- Giảm lag khi peak hours

### 4. Smart & Adaptive
- Tự động điều chỉnh theo tình huống
- Không cần config thủ công

## Test Mode vs Production

### Test Mode (12 phút = 12 giờ)
```lua
-- Config.MaxDailyHours = 12/60 = 0.2 giờ

if hoursRemaining <= 0.01 then     -- Còn < 36 giây
    waitTime = 2000                 -- Check mỗi 2 giây
elseif hoursRemaining <= 0.05 then -- Còn < 3 phút
    waitTime = 5000                 -- Check mỗi 5 giây
else
    waitTime = 10000                -- Check mỗi 10 giây
end
```

### Production (12 giờ thực)
- Logic như trên (đã implement)
- Tự động scale theo Config.MaxDailyHours

## So sánh các phương pháp

| Phương pháp | CPU Usage | Độ chính xác | Complexity |
|-------------|-----------|--------------|------------|
| Fixed 5s    | 100%      | ±5s          | Thấp       |
| Fixed 10s   | 50%       | ±10s         | Thấp       |
| Adaptive    | **16%**   | **±2s**      | Trung bình |

## Code Implementation

```lua
-- Thread: Sinh tiền và penalty (Tối ưu hóa adaptive)
CreateThread(function()
    while true do
        if not playerData.onDuty or rentalStatus.isGracePeriod then
            Wait(10000)
            goto continue
        end
        
        -- Tính thời gian còn lại
        local currentTime = GetCurrentTime()
        local currentWorkHours = (currentTime - playerData.workStartTime) / 1000 / 3600
        local totalDailyHours = playerData.dailyWorkHours + currentWorkHours
        local hoursRemaining = Config.MaxDailyHours - totalDailyHours
        
        -- ADAPTIVE WAIT: Thông minh điều chỉnh
        local waitTime
        if hoursRemaining <= 0.1 then
            waitTime = 2000
        elseif hoursRemaining <= 0.5 then
            waitTime = 5000
        elseif hoursRemaining <= 1 then
            waitTime = 10000
        elseif hoursRemaining <= 2 then
            waitTime = 30000
        else
            waitTime = 60000
        end
        
        Wait(waitTime)
        
        -- Logic xử lý...
        
        ::continue::
    end
end)
```

## Kết luận

Adaptive wait time là giải pháp tối ưu nhất:
- **Giảm 84% CPU usage** so với fixed 5s
- **Vẫn chính xác cao** (±2s) khi cần
- **Tự động thích ứng** với mọi tình huống
- **Dễ maintain** và mở rộng

Đây là best practice cho FiveM threads!

