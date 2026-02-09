# Hướng Dẫn Hệ Thống Responsive Scaling

## Tổng Quan
Hệ thống UI được thiết kế chuẩn cho màn hình **2560x1440** và tự động scale theo tỷ lệ cho các màn hình khác.

## Cách Hoạt Động

### 1. Design Base
- **Màn hình chuẩn**: 2560x1440 pixels
- **Base font-size**: 16px (1rem = 16px)
- **Container size**: 93.75rem x 56.25rem (1500px x 900px)
- **Scale gốc**: 1.09 (để UI vừa khít với màn 2560x1440)

### 2. Auto Scaling System

#### JavaScript Scaling (App.vue)
```javascript
const updateScale = () => {
  const designWidth = 2560
  const designHeight = 1440
  
  const viewportWidth = window.innerWidth
  const viewportHeight = window.innerHeight
  
  // Tính scale theo cả width và height
  const scaleX = viewportWidth / designWidth
  const scaleY = viewportHeight / designHeight
  
  // Sử dụng scale nhỏ hơn để đảm bảo UI không bị cắt
  // Nhân với 1.09 để giữ nguyên scale gốc trên màn 2560x1440
  const scale = Math.min(scaleX, scaleY) * 1.09
  
  // Apply scale to CSS variable
  document.documentElement.style.setProperty('--ui-scale', scale)
}
```

#### CSS Scaling (style.css)
```css
:root {
    --ui-scale: 1.09;
}

.container {
    transform: scale(var(--ui-scale));
    transform-origin: center center;
}
```

### 3. Responsive Font Sizes
```css
html {
    font-size: 16px; /* Base cho màn 2560x1440 */
}

/* Auto scale theo viewport */
@media (max-width: 2560px) {
    html { 
        font-size: calc(16px * (100vw / 2560));
    }
}

@media (max-height: 1440px) {
    html { 
        font-size: calc(16px * min(100vw / 2560, 100vh / 1440));
    }
}
```

## Ví Dụ Scale Theo Màn Hình

| Màn hình | Scale Calculation | Final Scale | Kết quả |
|----------|-------------------|-------------|---------|
| 2560x1440 | 1.0 × 1.09 | 1.09 | UI chuẩn 100% (như thiết kế gốc) |
| 1920x1080 | 0.75 × 1.09 | 0.8175 | UI thu nhỏ 75% |
| 1600x900 | 0.625 × 1.09 | 0.68125 | UI thu nhỏ 62.5% |
| 1366x768 | 0.533 × 1.09 | 0.581 | UI thu nhỏ 53.3% |
| 1280x720 | 0.5 × 1.09 | 0.545 | UI thu nhỏ 50% |

## Lợi Ích

✅ **Tự động scale**: UI tự động điều chỉnh theo màn hình
✅ **Giữ nguyên tỷ lệ**: Layout không bị méo, giữ nguyên tỷ lệ thiết kế
✅ **Background scale theo**: Background image cũng scale cùng UI
✅ **Không bị cắt**: UI luôn vừa khít trong viewport
✅ **Responsive hoàn hảo**: Hoạt động tốt trên mọi kích thước màn hình

## Cách Sử Dụng

### Thêm Component Mới
Khi thêm component mới, chỉ cần sử dụng **rem** thay vì **px**:

```css
/* ❌ Sai - dùng px */
.my-element {
    width: 200px;
    height: 100px;
    padding: 20px;
}

/* ✅ Đúng - dùng rem */
.my-element {
    width: 12.5rem;  /* 200px / 16 = 12.5rem */
    height: 6.25rem; /* 100px / 16 = 6.25rem */
    padding: 1.25rem; /* 20px / 16 = 1.25rem */
}
```

### Công Thức Chuyển Đổi
```
rem = px / 16
```

Ví dụ:
- 16px = 1rem
- 32px = 2rem
- 8px = 0.5rem
- 24px = 1.5rem

## Kiểm Tra

### Test Trên Các Màn Hình
1. Mở DevTools (F12)
2. Chuyển sang Responsive Mode (Ctrl+Shift+M)
3. Test các kích thước:
   - 2560x1440 (chuẩn)
   - 1920x1080 (phổ biến)
   - 1600x900
   - 1366x768
   - 1280x720

### Debug Scale
Mở Console và xem log:
```
Viewport: 1920x1080, Scale: 0.7500
```

## Lưu Ý

⚠️ **Không dùng px**: Luôn dùng rem cho mọi kích thước
⚠️ **Không dùng fixed width/height**: Để container tự scale
⚠️ **Không dùng media queries cũ**: Hệ thống tự động scale
⚠️ **Test trên nhiều màn hình**: Đảm bảo UI hoạt động tốt

## Troubleshooting

### UI bị cắt
- Kiểm tra container có overflow: hidden
- Kiểm tra transform-origin: center center

### UI quá nhỏ/lớn
- Kiểm tra --ui-scale trong DevTools
- Kiểm tra base font-size trong html

### Background không scale
- Kiểm tra .background-image có position: absolute
- Kiểm tra .main-wrapper có display: flex và align-items: center

## Kết Luận

Hệ thống responsive scaling này đảm bảo UI của bạn:
- ✅ Luôn chuẩn trên màn 2560x1440 với scale 1.09 (như thiết kế gốc)
- ✅ Tự động scale đẹp trên mọi màn hình nhỏ hơn
- ✅ Giữ nguyên tỷ lệ và layout
- ✅ Background scale theo UI
- ✅ Dễ dàng maintain và mở rộng

**Lưu ý quan trọng**: Scale 1.09 trên màn 2560x1440 là scale gốc của thiết kế, đảm bảo UI hiển thị đúng như mong muốn.
