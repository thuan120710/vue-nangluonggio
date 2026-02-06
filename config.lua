Config = {}

-- ============================================
-- TEST MODE - Bật để test nhanh
-- ============================================
Config.TestMode = true -- Đổi thành false khi production

-- ============================================

-- ============================================
-- HỆ THỐNG THUÊ TRẠM ĐIỆN GIÓ
-- ============================================
Config.RentalPrice = 0 -- MIỄN PHÍ để test

if Config.TestMode then
    -- TEST MODE: Expiry nhanh để test
    Config.RentalDuration = 1200 -- 60 giây = 1 phút (thay vì 7 ngày)
    Config.GracePeriod = 300 -- 30 giây (thay vì 4 giờ)
else
    -- PRODUCTION: Thời gian thực
    Config.RentalDuration = 604800 -- 7 ngày (giây) - 604800 seconds = 7 days
    Config.GracePeriod = 14400 -- 4 giờ (giây) - 14400 seconds = 4 hours
end

-- Vị trí trạm điện gió
Config.TurbineLocation = vector4(2318.64, 1608.59, 57.94, 92.39)

-- ============================================
-- HỆ THỐNG LỢI NHUẬN
-- ============================================
if Config.TestMode then
    -- TEST MODE: 1 phút = 1 giờ (để test nhanh)
    Config.BaseSalary = 5000 -- IC/chu kỳ (1 phút = 1 giờ) → 5,000 IC/giờ khi 100% hiệu suất
    Config.EarningCycle = 60000 -- 60 giây = 1 phút (tương đương 1 giờ thực tế)
    Config.MaxDailyHours = 12/60 -- 12 phút = 0.2 giờ (tương đương 12 giờ thực tế)
else
    -- PRODUCTION: Thời gian thực
    Config.BaseSalary = 5000 -- IC/giờ (5,000 IC/giờ)
    Config.EarningCycle = 3600000 -- 3600 giây = 1 giờ
    Config.MaxDailyHours = 12 -- 12 giờ/ngày
end

-- ============================================
-- HỆ THỐNG PENALTY (GIẢM ĐỘ BỀN THEO GIỜ)
-- ============================================
if Config.TestMode then
    -- TEST MODE: Penalty mỗi 1 phút (thay vì 1 giờ)
    Config.PenaltyCycle = 60000 -- 1 phút = 60 giây
    
    -- Penalty theo thời gian hoạt động (tính bằng PHÚT trong test mode)
    Config.PenaltyRanges = {
        -- 0-2 phút: Penalty nhẹ
        {
            minHours = 0,
            maxHours = 2/60, -- 2 phút = 0.033 giờ
            penalties = {
                {chance = 100, systems = 1, damage = 10}
            }
        },
        -- 2-4 phút
        {
            minHours = 2/60,
            maxHours = 4/60,
            penalties = {
                {chance = 80, systems = 1, damage = 10},
                {chance = 20, systems = {1, 2}, damage = 10}
            }
        },
        -- 4-8 phút
        {
            minHours = 4/60,
            maxHours = 8/60,
            penalties = {
                {chance = 55, systems = {1, 2}, damage = 30},
                {chance = 30, systems = 1, damage = 20},
                {chance = 15, systems = 0, damage = 0}
            }
        },
        -- 8+ phút (cho đến khi auto-stop)
        {
            minHours = 8/60,
            maxHours = 999, -- Không giới hạn trên (cho đến khi auto-stop)
            penalties = {
                {chance = 40, systems = 1, damage = 25},
                {chance = 30, systems = {1, 2}, damage = 30},
                {chance = 20, systems = 1, damage = 40},
                {chance = 10, systems = 0, damage = 0}
            }
        }
    }
else
    -- PRODUCTION: Penalty mỗi giờ
    Config.PenaltyCycle = 3600000 -- 1 giờ = 3600 giây
    
    -- Penalty theo thời gian hoạt động
    Config.PenaltyRanges = {
        -- 0-2 giờ: Penalty nhẹ
        {
            minHours = 0,
            maxHours = 2,
            penalties = {
                {chance = 100, systems = 1, damage = 10}
            }
        },
        -- 2-4 giờ
        {
            minHours = 2,
            maxHours = 4,
            penalties = {
                {chance = 80, systems = 1, damage = 10},
                {chance = 20, systems = {1, 2}, damage = 10}
            }
        },
        -- 4-8 giờ
        {
            minHours = 4,
            maxHours = 8,
            penalties = {
                {chance = 55, systems = {1, 2}, damage = 30},
                {chance = 30, systems = 1, damage = 20},
                {chance = 15, systems = 0, damage = 0}
            }
        },
        -- 8+ giờ (cho đến khi auto-stop ở 12h)
        {
            minHours = 8,
            maxHours = 999, -- Không giới hạn trên (cho đến khi auto-stop)
            penalties = {
                {chance = 40, systems = 1, damage = 25},
                {chance = 30, systems = {1, 2}, damage = 30},
                {chance = 20, systems = 1, damage = 40},
                {chance = 10, systems = 0, damage = 0}
            }
        }
    }
end

-- ============================================
-- HỆ THỐNG 5 CHỈ SỐ
-- ============================================
-- Giá trị khởi tạo hệ thống
Config.InitialSystemValue = 100

-- Mỗi chỉ số đóng góp 20% lợi nhuận
Config.SystemProfitContribution = 20 -- %

-- Cấu hình minigame cho từng hệ thống
Config.MinigameSettings = {
    stability = {
        title = "Sửa chữa cánh quạt",
        type = "fan", -- Minigame đặc biệt cho stability
        speed = 1.2,
        zoneSize = 0.22,
        rounds = 1
    },
    electric = {
        title = "Sửa chữa hệ thống điện",
        type = "circuit", -- Minigame đặc biệt cho electrical
        speed = 1.3,
        zoneSize = 0.2,
        rounds = 1
    },
    lubrication = {
        title = "Bơm dầu bôi trơn",
        type = "bar",
        speed = 1.1,
        zoneSize = 0.25,
        rounds = 1
    },
    blades = {
        title = "Sửa chữa thân tháp",
        type = "crack", -- Minigame đặc biệt cho blades
        speed = 1.4,
        zoneSize = 0.18,
        rounds = 1
    },
    safety = {
        title = "Kiểm tra an toàn",
        type = "bar",
        speed = 1.0,
        zoneSize = 0.28,
        rounds = 1
    }
}

-- Phần thưởng sửa chữa
Config.RepairRewards = {
    perfect = 20,
    good = 10,
    fail = -5
}

-- ============================================
-- HỆ THỐNG XĂNG (FUEL)
-- ============================================
Config.MaxFuel = 100 -- Tổng nhiên liệu tối đa (84 giờ)
Config.MinFuelToStart = 100 -- Cần tối thiểu 100 fuel (4 can) để khởi động
Config.FuelPerJerrycan = 25 -- 1 can xăng = 25 fuel units
Config.JerrycanItemName = "jerrycan" -- Tên item trong QBCore

if Config.TestMode then
    -- TEST MODE: Tiêu hao xăng nhanh (mỗi phút = 1 giờ)
    Config.FuelConsumptionCycle = 600 -- 1 phút = 1 fuel unit
else
    -- PRODUCTION: Tiêu hao xăng thực tế
    Config.FuelConsumptionCycle = 3600000 -- 1 giờ = 1 fuel unit
end
