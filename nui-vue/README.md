# Wind Turbine Operator - Vue.js UI

Đây là phiên bản Vue.js của UI cho minigame Wind Turbine Operator FiveM.

## Cài đặt

```bash
cd nui-vue
npm install
```

## Development

```bash
npm run dev
```

Server sẽ chạy tại http://localhost:5173

## Build cho Production

```bash
npm run build
```

File build sẽ được tạo trong thư mục `nui-dist/`

## Tích hợp vào FiveM

1. Build project: `npm run build`
2. Copy toàn bộ nội dung trong `nui-dist/` vào thư mục `nui/` của resource FiveM
3. Cập nhật `fxmanifest.lua`:

```lua
ui_page 'nui/index.html'

files {
    'nui/index.html',
    'nui/assets/*.js',
    'nui/assets/*.css',
    'nui/img/*.png',
    'nui/img/*.svg'
}
```

## Cấu trúc Components

- **App.vue**: Component chính, quản lý state và routing giữa các view
- **MainUI.vue**: Giao diện chính với turbine và systems
- **SystemCard.vue**: Card hiển thị từng hệ thống (stability, electric, etc.)
- **MinigameUI.vue**: Minigame dạng bar (cho lubrication, safety)
- **FanMinigameUI.vue**: Minigame sửa cánh quạt (cho stability)
- **CircuitBreakerUI.vue**: Minigame sửa cầu dao điện (cho electric)
- **CrackRepairUI.vue**: Minigame sửa vết nứt (cho blades)
- **EarningsUI.vue**: Giao diện hiển thị và rút tiền

## Tính năng

✅ Chuyển đổi 100% từ vanilla JS sang Vue.js
✅ Giữ nguyên toàn bộ logic và thiết kế
✅ Component-based architecture
✅ Reactive state management
✅ Tất cả 5 minigame types
✅ Animations và effects
✅ Sound effects
✅ Work time tracking
✅ Work limit system

## Lưu ý

- File CSS được giữ nguyên 100% từ bản gốc
- Tất cả logic game được chuyển đổi sang Vue composition API
- API communication với FiveM client được giữ nguyên
- Tương thích hoàn toàn với server-side Lua code hiện tại
