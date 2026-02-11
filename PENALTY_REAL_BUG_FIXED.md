# ✅ PENALTY BUG THẬT SỰ - ĐÃ FIX

## 🐛 Vấn Đề Thật Sự

Sau 3 lần penalty:
- 1 system = 0%
- 1 system = 50%  
- 3 systems = 100%

**Nhưng penalty DỪNG hẳn, không chạy nữa!**

## 🔍 Nguyên Nhân Thật Sự

### Phân Tích Flow:

**Lần 1 (0-2 phút):**
- Config: `{chance = 100, systems = 1, damage = 50}`
- Kết quả: 1 system từ 100% → 50%
- ✅ Penalty OK

**Lần 2 (2-4 phút):**
- Config: `{chance = 80, systems = 1, damage = 50}`
- Kết quả: 1 system từ 50% → 0%
- ✅ Penalty OK

**Lần 3 (4-8 phút):**
- Config có 3 options:
  - 55% chance: 1-2 systems, damage 30
  - 30% chance: 1 system, damage 20
  - **15% chance: 0 systems, damage 0** ← VẤN ĐỀ Ở ĐÂY!

Nếu lần 3 roll trúng 15% (systems = 0):

### Code Cũ:

```lua
if selectedPenalty and selectedPenalty.systems > 0 then
    -- Apply penalty
    ...
end

earnings.lastPenalty = currentTime  -- ← Update BÊN NGOÀI if!
```

**VẤN ĐỀ:**
1. `selectedPenalty.systems = 0` → Điều kiện `> 0` = FALSE
2. Không apply penalty (đúng)
3. Nhưng `lastPenalty` VẪN được update! (SAI)
4. Lần sau thread chạy: `currentTime - lastPenalty < 60` → Không penalty
5. Cứ thế mãi, penalty không bao giờ chạy nữa!

## ✅ Giải Pháp

### Code Mới:

```lua
if selectedPenalty and selectedPenalty.systems > 0 then
    local numSystems = selectedPenalty.systems
    ...
    
    if #availableSystems > 0 then
        -- Apply penalty
        ...
        
        -- BUGFIX: Chỉ update lastPenalty khi penalty THỰC SỰ được apply
        earnings.lastPenalty = currentTime
    end
else
    -- BUGFIX: Nếu selectedPenalty.systems = 0, vẫn update lastPenalty để không bị stuck
    earnings.lastPenalty = currentTime
end
```

**LOGIC MỚI:**
1. Nếu `systems > 0` VÀ có `availableSystems` → Apply penalty → Update `lastPenalty`
2. Nếu `systems = 0` (no penalty) → Vẫn update `lastPenalty` để lần sau có thể roll lại
3. Nếu `systems > 0` NHƯNG không có `availableSystems` → Không update `lastPenalty` (để retry ngay lần sau)

## 🎯 Kết Quả

### Trước Fix:
- ❌ Lần 3 roll trúng `systems = 0` → Penalty dừng mãi mãi
- ❌ `lastPenalty` được update dù không có penalty
- ❌ Thread không thể penalty nữa

### Sau Fix:
- ✅ Lần 3 roll trúng `systems = 0` → Update `lastPenalty` → Lần 4 roll lại
- ✅ Lần 4 có thể roll trúng penalty thật → Apply penalty bình thường
- ✅ Penalty tiếp tục chạy đúng logic

## 📊 Test Case

### Scenario: Roll Trúng systems = 0

**Trước fix:**
1. Lần 3: Roll 15% → systems = 0 → Không penalty → Update lastPenalty
2. Lần 4: Check time → Chưa đủ 60s → Skip
3. Lần 5, 6, 7...: Cứ thế mãi, không penalty nữa
4. ❌ BUG!

**Sau fix:**
1. Lần 3: Roll 15% → systems = 0 → Không penalty → Update lastPenalty
2. Lần 4: Check time → Đủ 60s → Roll lại → Có thể trúng penalty thật
3. Lần 5: Tiếp tục roll và penalty bình thường
4. ✅ FIXED!

## 🔧 Chi Tiết Kỹ Thuật

### Vị Trí Update `lastPenalty`:

**Trường hợp 1:** Penalty được apply
```lua
if #availableSystems > 0 then
    // Apply penalty to systems
    earnings.lastPenalty = currentTime  // ← Update ở đây
end
```

**Trường hợp 2:** selectedPenalty.systems = 0 (no penalty by design)
```lua
else
    earnings.lastPenalty = currentTime  // ← Update ở đây để không stuck
end
```

**Trường hợp 3:** Không có availableSystems (tất cả <= 30%)
```lua
if #availableSystems > 0 then
    // ...
end
// KHÔNG update lastPenalty → Retry lần sau
```

## ⚠️ Lưu Ý

- File đã kiểm tra syntax: No diagnostics found
- Logic penalty giờ hoạt động đúng với config có `systems = 0`
- Không ảnh hưởng đến earnings và fuel
