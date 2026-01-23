# Logic Tính Toán Lợi Nhuận - Wind Turbine

## Thông số cơ bản

- **Lợi nhuận mục tiêu**: 5,000 IC/giờ
- **Server tính toán**: 1,250 IC/15 phút (5,000 ÷ 4)
- **Chu kỳ sinh tiền**: 900 giây (15 phút) - Server sinh tiền mỗi 15 phút
- **Số chỉ số**: 5 (Stability, Electric, Lubrication, Blades, Safety)
- **Đóng góp mỗi chỉ số**: 20% lợi nhuận tổng

## Công thức tính toán

### 1. Lợi nhuận tối đa của 1 chỉ số
```
Lợi nhuận 1 chỉ số = 1,250 IC/15 phút × 20% = 250 IC/15 phút
```

### 2. Logic theo độ bền chỉ số

#### Chỉ số >= 50% (Tốt)
- **Lợi nhuận**: 100% (250 IC/15 phút)
- **Ví dụ**: Chỉ số 80% → 250 IC/15 phút

#### Chỉ số 30-49% (Cảnh báo)
- **Lợi nhuận**: 50% (125 IC/15 phút)
- **Ví dụ**: Chỉ số 40% → 125 IC/15 phút

#### Chỉ số < 30% (Nguy hiểm)
- **Lợi nhuận**: 0% (0 IC/15 phút)
- **Ví dụ**: Chỉ số 20% → 0 IC/15 phút

### 3. Điều kiện ngừng hoạt động
- **3 chỉ số < 30%**: Máy ngừng hoạt động hoàn toàn → 0 IC/15 phút

## Ví dụ tính toán

### Ví dụ 1: Tất cả chỉ số 100%
```
Stability:    100% → 250 IC/15 phút
Electric:     100% → 250 IC/15 phút
Lubrication:  100% → 250 IC/15 phút
Blades:       100% → 250 IC/15 phút
Safety:       100% → 250 IC/15 phút
-----------------------------------
TỔNG:         1,250 IC/15 phút = 5,000 IC/giờ
```

### Ví dụ 2: 1 chỉ số xuống 40%
```
Stability:    100% → 250 IC/15 phút
Electric:     100% → 250 IC/15 phút
Lubrication:   40% → 125 IC/15 phút (giảm 50%)
Blades:       100% → 250 IC/15 phút
Safety:       100% → 250 IC/15 phút
-----------------------------------
TỔNG:         1,125 IC/15 phút = 4,500 IC/giờ
```

### Ví dụ 3: 1 chỉ số xuống 20%
```
Stability:    100% → 250 IC/15 phút
Electric:     100% → 250 IC/15 phút
Lubrication:   20% → 0 IC/15 phút (ngừng sinh lợi)
Blades:       100% → 250 IC/15 phút
Safety:       100% → 250 IC/15 phút
-----------------------------------
TỔNG:         1,000 IC/15 phút = 4,000 IC/giờ
```

### Ví dụ 4: 3 chỉ số < 30% (Máy ngừng)
```
Stability:     25% → 0 IC/15 phút
Electric:      25% → 0 IC/15 phút
Lubrication:   25% → 0 IC/15 phút
Blades:       100% → 0 IC/15 phút (máy ngừng)
Safety:       100% → 0 IC/15 phút (máy ngừng)
-----------------------------------
TỔNG:          0 IC/15 phút = 0 IC/giờ
⚠️ MÁY NGỪNG HOẠT ĐỘNG!
```

## Hiển thị UI

### Server → Client
- **Server tính**: 1,250 IC/15 phút (mỗi chu kỳ 900 giây)
- **Server gửi**: 
  - `earningsPool` (tổng tiền tích lũy)
  - `efficiency` (hiệu suất trung bình - chỉ để tham khảo)
  - `actualEarningRate` (tỷ lệ sinh tiền thực tế theo giờ)

### Client hiển thị
- **Earning Rate**: Nhận trực tiếp từ server (đã nhân 4)
  - Server: `CalculateSystemProfit(playerId) × 4`
  - Client: Hiển thị số đã nhận (IC/giờ)
- **Total Balance**: Hiển thị số tiền tích lũy với dấu phẩy
  - `125000 → 125,000 IC`

### Tại sao cần actualEarningRate?
- **Efficiency** (hiệu suất trung bình) không phản ánh chính xác lợi nhuận
- Ví dụ: 1 chỉ số 40%, 4 chỉ số 100%
  - Efficiency = (40 + 100 + 100 + 100 + 100) / 5 = 88%
  - Nhưng lợi nhuận thực tế = 4,500 IC/giờ (không phải 88% × 5,000 = 4,400)
- **actualEarningRate** tính chính xác dựa trên logic từng chỉ số

## Code Implementation

### Server (server/main.lua)
```lua
-- Tính lợi nhuận thực tế (IC/15 phút)
local function CalculateSystemProfit(playerId)
    local totalProfit = 0
    
    for systemName, value in pairs(systems) do
        local systemProfit = Config.BaseSalary * 0.2  -- 250 IC/15 phút
        
        if value < 30 then
            systemProfit = 0
        elseif value < 50 then
            systemProfit = systemProfit * 0.5
        end
        
        totalProfit = totalProfit + systemProfit
    end
    
    return totalProfit  -- IC/15 phút
end

-- Gửi cho client (chuyển sang IC/giờ)
local actualEarningRate = CalculateSystemProfit(playerId) * 4
TriggerClientEvent('windturbine:updateActualEarningRate', playerId, actualEarningRate)
```

### Client (client/main.lua)
```lua
RegisterNetEvent('windturbine:updateActualEarningRate')
AddEventHandler('windturbine:updateActualEarningRate', function(earningRate)
    SendNUIMessage({
        action = 'updateActualEarningRate',
        earningRate = earningRate  -- IC/giờ
    })
end)
```

### NUI (nui/script.js)
```javascript
case 'updateActualEarningRate':
    // Hiển thị earning rate thực tế từ server
    document.getElementById('earningRate').textContent = 
        Math.floor(data.earningRate).toLocaleString();
    break;
```

## Chu kỳ sinh tiền

### Timeline
```
0:00  → Bắt đầu ca
0:15  → Sinh tiền lần 1 (1,250 IC)
0:30  → Sinh tiền lần 2 (1,250 IC)
0:45  → Sinh tiền lần 3 (1,250 IC)
1:00  → Sinh tiền lần 4 (1,250 IC)
-----------------------------------
Tổng sau 1 giờ: 5,000 IC
```

### Lợi ích của chu kỳ 15 phút
- ✅ Giảm spam thông báo (4 lần/giờ thay vì 60 lần/giờ)
- ✅ Giảm tải server (ít tính toán hơn)
- ✅ Người chơi vẫn nhận đủ tiền (5,000 IC/giờ)
- ✅ Dễ theo dõi tiến độ (mỗi 15 phút check 1 lần)

## Kiểm tra đúng sai

### ✅ Đúng
- Tất cả chỉ số 100% → UI hiển thị: **5,000 IC/h**
- 1 chỉ số 40%, 4 chỉ số 100% → UI hiển thị: **4,500 IC/h**
- 1 chỉ số 20%, 4 chỉ số 100% → UI hiển thị: **4,000 IC/h**
- 3 chỉ số < 30% → UI hiển thị: **0 IC/h** (máy ngừng)
- Sau 15 phút (tất cả 100%) → Nhận: **1,250 IC**
- Sau 1 giờ (tất cả 100%) → Nhận: **5,000 IC**

### ❌ Sai (nếu có)
- Nếu earning rate hiển thị khác 5,000 khi tất cả chỉ số 100%
- Nếu earning rate không cập nhật khi sửa chữa hệ thống
- Nếu earning rate tính theo efficiency thay vì logic thực tế
- Nếu sinh tiền không đúng 15 phút 1 lần

## Lưu ý quan trọng

1. **Server sinh tiền mỗi 15 phút** (900 giây)
2. **UI hiển thị theo giờ** để dễ hiểu (nhân 4)
3. **actualEarningRate** được gửi mỗi khi:
   - Bắt đầu ca làm việc
   - Sửa chữa hệ thống
   - Hệ thống bị giảm (degrade/penalty)
4. **Efficiency** chỉ để tham khảo, không dùng để tính lợi nhuận
5. **Config.BaseSalary = 1,250** (IC/15 phút)
6. **Config.EarningCycle = 900000** (15 phút = 900 giây)

## Công thức tính toán

### 1. Lợi nhuận tối đa của 1 chỉ số
```
Lợi nhuận 1 chỉ số = 83.33 IC/phút × 20% = 16.67 IC/phút
```

### 2. Logic theo độ bền chỉ số

#### Chỉ số >= 50% (Tốt)
- **Lợi nhuận**: 100% (16.67 IC/phút)
- **Ví dụ**: Chỉ số 80% → 16.67 IC/phút

#### Chỉ số 30-49% (Cảnh báo)
- **Lợi nhuận**: 50% (8.33 IC/phút)
- **Ví dụ**: Chỉ số 40% → 8.33 IC/phút

#### Chỉ số < 30% (Nguy hiểm)
- **Lợi nhuận**: 0% (0 IC/phút)
- **Ví dụ**: Chỉ số 20% → 0 IC/phút

### 3. Điều kiện ngừng hoạt động
- **3 chỉ số < 30%**: Máy ngừng hoạt động hoàn toàn → 0 IC/phút

## Ví dụ tính toán

### Ví dụ 1: Tất cả chỉ số 100%
```
Stability:    100% → 16.67 IC/phút
Electric:     100% → 16.67 IC/phút
Lubrication:  100% → 16.67 IC/phút
Blades:       100% → 16.67 IC/phút
Safety:       100% → 16.67 IC/phút
-----------------------------------
TỔNG:         83.33 IC/phút = 5,000 IC/giờ
```

### Ví dụ 2: 1 chỉ số xuống 40%
```
Stability:    100% → 16.67 IC/phút
Electric:     100% → 16.67 IC/phút
Lubrication:   40% → 8.33 IC/phút (giảm 50%)
Blades:       100% → 16.67 IC/phút
Safety:       100% → 16.67 IC/phút
-----------------------------------
TỔNG:         75.00 IC/phút = 4,500 IC/giờ
```

### Ví dụ 3: 1 chỉ số xuống 20%
```
Stability:    100% → 16.67 IC/phút
Electric:     100% → 16.67 IC/phút
Lubrication:   20% → 0.00 IC/phút (ngừng sinh lợi)
Blades:       100% → 16.67 IC/phút
Safety:       100% → 16.67 IC/phút
-----------------------------------
TỔNG:         66.67 IC/phút = 4,000 IC/giờ
```

### Ví dụ 4: 3 chỉ số < 30% (Máy ngừng)
```
Stability:     25% → 0.00 IC/phút
Electric:      25% → 0.00 IC/phút
Lubrication:   25% → 0.00 IC/phút
Blades:       100% → 0.00 IC/phút (máy ngừng)
Safety:       100% → 0.00 IC/phút (máy ngừng)
-----------------------------------
TỔNG:          0.00 IC/phút = 0 IC/giờ
⚠️ MÁY NGỪNG HOẠT ĐỘNG!
```

## Hiển thị UI

### Server → Client
- **Server tính**: 83.33 IC/phút (mỗi chu kỳ 60 giây)
- **Server gửi**: 
  - `earningsPool` (tổng tiền tích lũy)
  - `efficiency` (hiệu suất trung bình - chỉ để tham khảo)
  - `actualEarningRate` (tỷ lệ sinh tiền thực tế theo giờ)

### Client hiển thị
- **Earning Rate**: Nhận trực tiếp từ server (đã nhân 60)
  - Server: `CalculateSystemProfit(playerId) * 60`
  - Client: Hiển thị số đã nhận (IC/giờ)
- **Total Balance**: Hiển thị số tiền tích lũy với dấu phẩy
  - `125000 → 125,000 IC`

### Tại sao cần actualEarningRate?
- **Efficiency** (hiệu suất trung bình) không phản ánh chính xác lợi nhuận
- Ví dụ: 1 chỉ số 40%, 4 chỉ số 100%
  - Efficiency = (40 + 100 + 100 + 100 + 100) / 5 = 88%
  - Nhưng lợi nhuận thực tế = 4,500 IC/giờ (không phải 88% × 5,000 = 4,400)
- **actualEarningRate** tính chính xác dựa trên logic từng chỉ số

## Code Implementation

### Server (server/main.lua)
```lua
-- Tính lợi nhuận thực tế (IC/phút)
local function CalculateSystemProfit(playerId)
    local totalProfit = 0
    
    for systemName, value in pairs(systems) do
        local systemProfit = Config.BaseSalary * 0.2  -- 16.67 IC/phút
        
        if value < 30 then
            systemProfit = 0
        elseif value < 50 then
            systemProfit = systemProfit * 0.5
        end
        
        totalProfit = totalProfit + systemProfit
    end
    
    return totalProfit  -- IC/phút
end

-- Gửi cho client (chuyển sang IC/giờ)
local actualEarningRate = CalculateSystemProfit(playerId) * 60
TriggerClientEvent('windturbine:updateActualEarningRate', playerId, actualEarningRate)
```

### Client (client/main.lua)
```lua
RegisterNetEvent('windturbine:updateActualEarningRate')
AddEventHandler('windturbine:updateActualEarningRate', function(earningRate)
    SendNUIMessage({
        action = 'updateActualEarningRate',
        earningRate = earningRate  -- IC/giờ
    })
end)
```

### NUI (nui/script.js)
```javascript
case 'updateActualEarningRate':
    // Hiển thị earning rate thực tế từ server
    document.getElementById('earningRate').textContent = 
        Math.floor(data.earningRate).toLocaleString();
    break;
```

## Kiểm tra đúng sai

### ✅ Đúng
- Tất cả chỉ số 100% → UI hiển thị: **5,000 IC/h**
- 1 chỉ số 40%, 4 chỉ số 100% → UI hiển thị: **4,500 IC/h**
- 1 chỉ số 20%, 4 chỉ số 100% → UI hiển thị: **4,000 IC/h**
- 3 chỉ số < 30% → UI hiển thị: **0 IC/h** (máy ngừng)

### ❌ Sai (nếu có)
- Nếu earning rate hiển thị khác 5,000 khi tất cả chỉ số 100%
- Nếu earning rate không cập nhật khi sửa chữa hệ thống
- Nếu earning rate tính theo efficiency thay vì logic thực tế

## Lưu ý quan trọng

1. **Server sinh tiền mỗi 60 giây** (1 phút)
2. **UI hiển thị theo giờ** để dễ hiểu (nhân 60)
3. **actualEarningRate** được gửi mỗi khi:
   - Bắt đầu ca làm việc
   - Sửa chữa hệ thống
   - Hệ thống bị giảm (degrade/penalty)
4. **Efficiency** chỉ để tham khảo, không dùng để tính lợi nhuận
