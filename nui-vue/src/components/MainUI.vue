<template>
  <div class="main-wrapper">
    <div class="background-image"></div>
    <div class="container">
    <!-- Animated Background -->
    <div class="bg-grid"></div>
    <div class="bg-particles">
      <div class="particle"></div>
      <div class="particle"></div>
      <div class="particle"></div>
      <div class="particle"></div>
      <div class="particle"></div>
    </div>
    
    <div class="header">
      <div class="header-logo">
        <img src="/img/f17.png" alt="F17 Logo" class="logo-image">
      </div>
      
      <div class="header-left">
        <div class="header-text">
          <span class="subtitle">Người thuê: <span class="subtitle-highlight">{{ ownerName }}</span></span>
        </div>
      </div>
      
      <div class="header-center">
        <h1>TRẠM KHAI THÁC ĐIỆN GIÓ</h1>
      </div>
      
      <div class="header-right">
        <span class="time-label">Thời gian thuê còn lại:</span>
        <span class="time-value">{{ remainingTime }}</span>
      </div>
      
      <button class="close-btn" @click="$emit('close')">
        ✕
      </button>
    </div>
    
    <div class="content">
      <!-- Left Info Panel -->
      <div class="left-panel">
        <!-- Efficiency -->
        <div class="stat-item">
          <div class="stat-header">
            <span class="stat-label">HIỆU SUẤT <img src="/img/i.png" alt="info" class="info-icon-img"></span>
            <span class="stat-percent">{{ Math.floor(efficiency) }}%</span>
          </div>
          <div class="stat-bar">
            <div class="stat-bar-fill green" :style="{ width: efficiency + '%' }"></div>
          </div>
        </div>

        <!-- Fuel -->
        <div class="stat-item">
          <div class="stat-header">
            <span class="stat-label">XĂNG <img src="/img/i.png" alt="info" class="info-icon-img"></span>
            <span class="stat-percent red">30%</span>
          </div>
          <div class="stat-bar">
            <div class="stat-bar-fill red" :style="{ width: '30%' }"></div>
          </div>
        </div>

        <!-- System Status -->
        <div class="stat-item status-section">
          <div class="stat-label center">TRẠNG THÁI HỆ THỐNG</div>
          <div class="status-display">
            <span class="status-dot" :class="{ online: isOnDuty }"></span>
            <span class="status-text">{{ fullStatusText }}</span>
          </div>
        </div>

        <!-- Start/Stop Button -->
        <button 
          v-if="!isOnDuty"
          class="btn btn-start"
          :class="{ 'disabled-limit': workLimitReached }"
          :disabled="workLimitReached"
          @click="$emit('startDuty')"
        >
          <span class="btn-icon">⏻</span>
          {{ workLimitReached ? 'ĐÃ ĐẠT GIỚI HẠN' : 'KHỞI ĐỘNG' }}
        </button>
        <button 
          v-else
          class="btn btn-stop"
          @click="$emit('stopDuty')"
        >
          <span class="btn-icon">⏻</span>
          TẠM DỪNG
        </button>
      </div>
      
      <!-- Turbine Center -->
      <div class="turbine-section">
        <div class="turbine-container" @click="$emit('openEarnings')">
          <!-- Outer Rings -->
          <div class="outer-ring ring-1"></div>
          <div class="outer-ring ring-2"></div>
          <div class="outer-ring ring-3"></div>
          
          <!-- Progress Ring -->
          <svg class="progress-ring" width="280" height="280">
            <defs>
              <linearGradient id="progressGradient" x1="0%" y1="0%" x2="100%" y2="100%">
                <stop offset="0%" style="stop-color:#00ffff;stop-opacity:1" />
                <stop offset="100%" style="stop-color:#00ff88;stop-opacity:1" />
              </linearGradient>
              <filter id="glow">
                <feGaussianBlur stdDeviation="4" result="coloredBlur"/>
                <feMerge>
                  <feMergeNode in="coloredBlur"/>
                  <feMergeNode in="SourceGraphic"/>
                </feMerge>
              </filter>
            </defs>
            <circle class="progress-ring-bg" cx="140" cy="140" r="120" />
            <circle 
              class="progress-ring-circle" 
              cx="140" 
              cy="140" 
              r="120"
              :style="{ strokeDashoffset: progressRingOffset }"
            />
          </svg>
          
          <!-- Turbine -->
          <div class="turbine-wrapper">
            <div class="turbine-center">
              <div class="center-core"></div>
              <div class="center-ring"></div>
            </div>
            <div 
              class="blade-container"
              :class="{ stopped: shouldStopBlade }"
              :style="bladeStyle"
            >
              <div class="blade">
                <div class="blade-inner"></div>
                <div class="blade-glow"></div>
              </div>
              <div class="blade">
                <div class="blade-inner"></div>
                <div class="blade-glow"></div>
              </div>
              <div class="blade">
                <div class="blade-inner"></div>
                <div class="blade-glow"></div>
              </div>
            </div>
          </div>
        </div>
      </div>

      <!-- Right Info Panel -->
      <div class="right-panel">
        <!-- Income Rate -->
        <div class="income-item">
          <div class="income-label">THU NHẬP <img src="/img/i.png" alt="info" class="info-icon-img"></div>
          <div class="income-value">{{ earningRateDisplay }} IC/GIỜ</div>
        </div>

        <!-- Total Income with glow -->
        <div class="total-income-section">
          <div class="total-glow"></div>
          <div class="total-label">TỔNG THU NHẬP</div>
          <div class="total-value-wrapper">
            <div class="circle-ring"></div>
            <div class="total-value">{{ Math.floor(earnings).toLocaleString() }} IC</div>
          </div>
        </div>

        <!-- Withdraw Button -->
        <button 
          v-if="isOnDuty"
          class="btn btn-withdraw"
          @click="$emit('openEarnings')"
        >
          <img src="/img/Primary.svg" alt="Money" class="btn-icon-img">
          RÚT TIỀN
        </button>
      </div>
    </div>

    <!-- Systems Grid at Bottom -->
    <div class="systems-bottom">
      <div class="systems-grid">
        <SystemCard
          v-for="(value, system) in systemsList"
          :key="system"
          :system="system"
          :value="value"
          :disabled="!isOnDuty"
          @click="handleSystemClick(system)"
        />
      </div>
    </div>
  </div>
  </div>
</template>

<script>
import { computed, ref, onMounted, onUnmounted } from 'vue'
import SystemCard from './SystemCard.vue'
import { playSound } from '../utils/sound'

export default {
  name: 'MainUI',
  components: {
    SystemCard
  },
  props: {
    systems: {
      type: Object,
      default: () => ({})
    },
    efficiency: {
      type: Number,
      default: 0
    },
    earnings: {
      type: Number,
      default: 0
    },
    earningRate: {
      type: Number,
      default: 0
    },
    isOnDuty: {
      type: Boolean,
      default: false
    },
    workLimitReached: {
      type: Boolean,
      default: false
    },
    workHours: {
      type: Number,
      default: 0
    },
    maxHours: {
      type: Number,
      default: 12
    },
    ownerName: {
      type: String,
      default: 'N/A'
    },
    expiryTime: {
      type: Number,
      default: null
    }
  },
  emits: ['close', 'startDuty', 'stopDuty', 'repair', 'openEarnings'],
  setup(props, { emit }) {
    const currentTime = ref(Math.floor(Date.now() / 1000))
    
    // Cập nhật thời gian mỗi giây
    onMounted(() => {
      const interval = setInterval(() => {
        currentTime.value = Math.floor(Date.now() / 1000)
      }, 1000)
      
      onUnmounted(() => {
        clearInterval(interval)
      })
    })
    
    // Đảm bảo systems luôn có đầy đủ 5 hệ thống
    const systemsList = computed(() => {
      const defaultSystems = {
        stability: 70,
        electric: 70,
        lubrication: 70,
        blades: 70,
        safety: 70
      }
      return { ...defaultSystems, ...props.systems }
    })
    
    const progressRingOffset = computed(() => {
      const circumference = 754
      return circumference - (props.efficiency / 100) * circumference
    })
    
    // Logic giống code gốc: CHỈ dừng khi không onDuty HOẶC efficiency < 10
    const shouldStopBlade = computed(() => {
      if (!props.isOnDuty) return true
      if (props.efficiency < 10) return true
      return false
    })
    
    // Chỉ set animation duration khi đang xoay
    const bladeStyle = computed(() => {
      if (shouldStopBlade.value) {
        return {}
      }
      const speed = 10 - (props.efficiency / 100) * 7 // 3s to 10s
      return {
        animationDuration: speed + 's'
      }
    })
    
    const earningRateDisplay = computed(() => {
      // Luôn tính toán dựa trên efficiency để đồng bộ với EarningsUI
      const basePerHour = 5000
      const rate = basePerHour * (props.efficiency / 100)
      return Math.floor(rate).toLocaleString()
    })
    
    // Tính thời gian còn lại
    const remainingTime = computed(() => {
      if (!props.expiryTime) return 'N/A'
      
      const remainingSeconds = props.expiryTime - currentTime.value
      
      if (remainingSeconds <= 0) return 'Hết hạn'
      
      const days = Math.floor(remainingSeconds / 86400)
      const hours = Math.floor((remainingSeconds % 86400) / 3600)
      const minutes = Math.floor((remainingSeconds % 3600) / 60)
      
      if (days > 0) {
        return `${days}d ${hours}h ${minutes}p`
      } else if (hours > 0) {
        return `${hours}h ${minutes}p`
      } else {
        return `${minutes}p`
      }
    })
    
    const statusText = computed(() => {
      if (props.workLimitReached) {
        return 'ĐÃ ĐẠT GIỚI HẠN'
      }
      if (!props.isOnDuty) {
        return 'OFFLINE'
      }
      return 'ONLINE'
    })
    
    const fullStatusText = computed(() => {
      if (props.workLimitReached) {
        return 'ĐÃ ĐẠT GIỚI HẠN'
      }
      if (!props.isOnDuty) {
        return 'OFFLINE'
      }
      // Format: ONLINE - 0.2 / 12 GIỜ
      const currentHours = (Math.floor(props.workHours * 10) / 10).toFixed(1)
      const maxHoursFormatted = (Math.floor(props.maxHours * 10) / 10).toFixed(1)
      return `ONLINE - ${currentHours} / ${maxHoursFormatted} GIỜ`
    })
    
    const formatWorkTime = (hours) => {
      // Hiển thị theo giờ với 1 số thập phân
      return `${(Math.floor(hours * 10) / 10).toFixed(1)}h`
    }
    
    const handleSystemClick = (system) => {
      if (!props.isOnDuty) {
        playSound('fail')
        return
      }
      playSound('click')
      emit('repair', system)
    }
    
    return {
      systemsList,
      progressRingOffset,
      shouldStopBlade,
      bladeStyle,
      earningRateDisplay,
      remainingTime,
      statusText,
      fullStatusText,
      formatWorkTime,
      handleSystemClick,
      Math
    }
  }
}
</script>

<style scoped>
/* Header override for Main UI */
.header-logo {
    left: 4rem;
}

.close-btn {
    right: 4rem;
}
</style>
