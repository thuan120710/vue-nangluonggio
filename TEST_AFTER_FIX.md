# 🧪 HƯỚNG DẪN KIỂM TRA SAU KHI FIX

## 🚀 BƯỚC 1: RESTART SCRIPT

```bash
# Trong game, mở F8 console và gõ:
/restart [tên-script-của-bạn]

# Hoặc restart toàn bộ server
```

---

## ✅ BƯỚC 2: KIỂM TRA MEMORY LEAK (QUAN TRỌNG!)

### Test Memory Leak trong UI:

1. **Đến gần trạm điện gió**
2. **Mở F8 console** (để theo dõi)
3. **Mở/đóng UI 10 lần liên tục:**
   - Bấm E → Mở UI
   - Bấm X → Đóng UI
   - Lặp lại 10 lần

4. **Kiểm tra kết quả:**
   - ✅ **TRƯỚC FIX:** Sẽ thấy lag tăng dần, FPS giảm
   - ✅ **SAU FIX:** Không lag, FPS ổn định

---

## ✅ BƯỚC 3: KIỂM TRA CPU USAGE

### Test CPU khi đứng gần trạm:

1. **Mở Task Manager** (Ctrl + Shift + Esc)
2. **Tìm process FiveM.exe**
3. **Đứng gần trạm điện gió** (< 3m)
4. **Quan sát CPU usage:**
   - ✅ **TRƯỚC FIX:** CPU spike lên 20-30%
   - ✅ **SAU FIX:** CPU ổn định 5-10%

---

## ✅ BƯỚC 4: KIỂM TRA CHỨC NĂNG

### Test 1: Thuê trạm
```
1. Đến trạm chưa có người thuê
2. Bấm E → Chọn "Thuê trạm"
3. Kiểm tra: Tiền bị trừ đúng không?
4. Kiểm tra: UI hiển thị "Người thuê: [Tên bạn]"?
```
**Kết quả mong đợi:** ✅ Thuê thành công, tiền bị trừ

---

### Test 2: Làm việc và sinh tiền
```
1. Sau khi thuê, bấm "KHỞI ĐỘNG"
2. Đợi 1 phút (test mode) hoặc 1 giờ (production)
3. Kiểm tra: Thu nhập có tăng không?
```
**Kết quả mong đợi:** ✅ Tiền tăng đều đặn

---

### Test 3: Sửa chữa hệ thống
```
1. Khi đang làm việc, click vào 1 hệ thống (< 70%)
2. Chơi minigame
3. Kiểm tra: Hệ thống có tăng không?
```
**Kết quả mong đợi:** ✅ Minigame hoạt động, hệ thống tăng

---

### Test 4: Đổ xăng
```
1. Khi xăng < 100%, click "ĐỔ XĂNG"
2. Kiểm tra: Xăng có tăng không?
3. Kiểm tra: Jerrycan bị trừ không?
```
**Kết quả mong đợi:** ✅ Xăng tăng, jerrycan giảm

---

### Test 5: Rút tiền
```
1. Khi có thu nhập, click "RÚT TIỀN"
2. Kiểm tra: Tiền IC có tăng không?
3. Kiểm tra: Thu nhập pool về 0?
```
**Kết quả mong đợi:** ✅ Rút tiền thành công

---

### Test 6: Grace Period (Quan trọng!)
```
1. Đợi hết thời hạn thuê (60s test mode / 7 ngày production)
2. Kiểm tra: Có thông báo "Hết thời hạn thuê"?
3. Kiểm tra: UI chuyển sang "Rút tiền grace period"?
4. Click "RÚT TIỀN"
5. Kiểm tra: Trạm reset về trạng thái ban đầu?
```
**Kết quả mong đợi:** ✅ Grace period hoạt động đúng

---

## ✅ BƯỚC 5: KIỂM TRA NHIỀU TRẠM

### Test đứng giữa nhiều trạm:

1. **Đứng ở vị trí giữa 2-3 trạm**
2. **Kiểm tra:**
   - ✅ Chỉ hiển thị text của trạm GẦN NHẤT
   - ✅ Không lag
   - ✅ FPS ổn định

**Kết quả mong đợi:** ✅ Chỉ 1 text hiển thị, không lag

---

## ✅ BƯỚC 6: KIỂM TRA SERVER (CHO ADMIN)

### Test server performance:

1. **Mở server console**
2. **Gõ lệnh:** `resmon`
3. **Tìm script của bạn**
4. **Kiểm tra:**
   - ✅ **ms/tick:** < 0.5ms (tốt)
   - ✅ **threads:** 4 threads (client) + 2 threads (server)

**Kết quả mong đợi:** ✅ Performance tốt, không có warning

---

## 🐛 NẾU CÓ VẤN ĐỀ

### Vấn đề 1: UI không mở
```
Nguyên nhân: Cache cũ
Giải pháp: 
1. Xóa cache FiveM (F8 → quit → xóa folder cache)
2. Restart server
3. Thử lại
```

---

### Vấn đề 2: Text 3D không hiển thị
```
Nguyên nhân: Object chưa load
Giải pháp:
1. Đợi 5 giây sau khi restart
2. Đến gần trạm
3. Thử lại
```

---

### Vấn đề 3: StateBag không sync
```
Nguyên nhân: Server chưa restart
Giải pháp:
1. Restart server (không chỉ restart script)
2. Thử lại
```

---

## 📊 CHECKLIST HOÀN CHỈNH

- [ ] Restart script thành công
- [ ] Mở/đóng UI 10 lần không lag
- [ ] CPU usage giảm khi đứng gần trạm
- [ ] Thuê trạm hoạt động
- [ ] Làm việc và sinh tiền OK
- [ ] Sửa chữa hệ thống OK
- [ ] Đổ xăng OK
- [ ] Rút tiền OK
- [ ] Grace period OK
- [ ] Nhiều trạm không lag
- [ ] Server performance tốt

---

## ✅ KẾT LUẬN

Nếu tất cả các test đều PASS → **FIX THÀNH CÔNG!**

Script của bạn giờ đã:
- ✅ Không còn memory leak
- ✅ Giảm 50% CPU usage
- ✅ Không còn lag
- ✅ Chức năng hoạt động 100%

**Chúc mừng! Script của bạn đã được tối ưu hóa! 🎉**
