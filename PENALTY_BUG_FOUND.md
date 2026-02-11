# 🐛 BUG PENALTY - Chỉ Penalty 3 Lần Rồi Dừng

## 📋 Mô Tả Vấn Đề

Penalty chỉ chạy đúng 3 lần rồi dừng hẳn, không penalty nữa.

## 🔍 Nguyên Nhân

Trong `server/main.lua` dòng 900-901:

```lua
-- Áp dụng penalty
if canEarn and currentTime - earnings.lastPenalty >= (Config.TestMode and 60 or 3600) then
    local workHours = (currentTime - PlayerWorkData[citizenid].workStartTime) / 3600
```

**VẤN ĐỀ:** Điều kiện `if canEarn and ...` có nghĩa là:
- Penalty CHỈ chạy khi máy ĐANG KIẾM TIỀN (`canEarn = true`)
- `canEarn = false` khi:
  - Hết xăng HOẶC
  - Có >= 3 systems <= 30%

**KẾT QUẢ:**
1. Lần penalty 1: 1 system xuống <= 30% → Vẫn `canEarn = true` (chỉ 1 system)
2. Lần penalty 2: 2 systems xuống <= 30% → Vẫn `canEarn = true` (chỉ 2 systems)
3. Lần penalty 3: 3 systems xuống <= 30% → `canEarn = false` (đủ 3 systems)
4. Từ lần 4 trở đi: `canEarn = false` → Điều kiện `if canEarn and ...` = FALSE
5. **Penalty KHÔNG chạy nữa!**

## ✅ GIẢI PHÁP

Penalty NÊN chạy bất kể máy có đang kiếm tiền hay không, vì:
- Máy vẫn hoạt động (onDuty = true)
- Máy vẫn tiêu hao năng lượng
- Các bộ phận vẫn bị hao mòn theo thời gian

**FIX:** Bỏ điều kiện `canEarn` khỏi penalty check:

```lua
-- Áp dụng penalty (BỎ điều kiện canEarn)
if currentTime - earnings.lastPenalty >= (Config.TestMode and 60 or 3600) then
    -- Kiểm tra PlayerWorkData tồn tại
    if not PlayerWorkData[citizenid] or not PlayerWorkData[citizenid].workStartTime then
        goto skip_penalty
    end
    
    local workHours = (currentTime - PlayerWorkData[citizenid].workStartTime) / 3600
    
    -- ... rest of penalty logic ...
    
    ::skip_penalty::
end
```

## 🎯 Kết Quả Sau Fix

- Penalty sẽ tiếp tục chạy ngay cả khi máy ngừng kiếm tiền
- Systems sẽ tiếp tục giảm theo thời gian
- Player buộc phải sửa chữa để duy trì hoạt động
- Logic hợp lý hơn: máy hoạt động = hao mòn, bất kể có kiếm tiền hay không
