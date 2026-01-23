<template>
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
      <div class="header-left">
        <div class="logo-icon">⚡</div>
        <div class="header-text">
          <h1>WIND TURBINE CONTROL</h1>
          <span class="subtitle">RENEWABLE ENERGY SYSTEM</span>
        </div>
      </div>
      <button class="close-btn" @click="$emit('close')">
        <span class="close-line"></span>
        <span class="close-line"></span>
      </button>
    </div>
    
    <div class="content">
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
          
          <!-- Info Display -->
          <div class="turbine-info">
            <div class="info-panel">
              <div class="info-label">EFFICIENCY</div>
              <div class="efficiency-display">
                <span>{{ Math.floor(efficiency) }}</span>
                <span class="unit">%</span>
              </div>
            </div>
            <div class="info-divider"></div>
            <div class="info-panel">
              <div class="info-label">EARNING RATE</div>
              <div class="earning-display">
                <span>{{ earningRateDisplay }}</span>
                <span class="unit"> IC/h</span>
              </div>
            </div>
          </div>
        </div>
      </div>
      
      <!-- Systems Grid -->
      <div class="systems-section">
        <div class="section-title">
          <span class="title-icon">⚙</span>
          SYSTEM STATUS
        </div>
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
    
    <div class="footer">
      <div class="footer-info">
        <span 
          class="status-dot"
          :class="{ online: isOnDuty && efficiency > 0 }"
        ></span>
        <span>{{ statusText }}</span>
      </div>
      <div class="footer-actions">
        <button 
          v-if="!isOnDuty"
          class="btn btn-start"
          :class="{ 'disabled-limit': workLimitReached }"
          :disabled="workLimitReached"
          @click="$emit('startDuty')"
        >
          <span class="btn-icon">▶</span>
          {{ workLimitReached ? 'ĐÃ ĐẠT GIỚI HẠN' : 'START SHIFT' }}
        </button>
        <button 
          v-else
          class="btn btn-stop"
          @click="$emit('stopDuty')"
        >
          <span class="btn-icon">■</span>
          END SHIFT
        </button>
      </div>
    </div>
  </div>
</template>

<script>
import { computed, watch } from 'vue'
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
    }
  },
  emits: ['close', 'startDuty', 'stopDuty', 'repair', 'openEarnings'],
  setup(props, { emit }) {
    console.log('🎨 MainUI mounted with props:', {
      isOnDuty: props.isOnDuty,
      efficiency: props.efficiency,
      workHours: props.workHours,
      systems: props.systems
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
      const basePerHour = 5000
      const rate = basePerHour * (props.efficiency / 100)
      return Math.floor(rate).toLocaleString()
    })
    
    const statusText = computed(() => {
      if (props.workLimitReached) {
        return 'ĐÃ ĐẠT GIỚI HẠN - QUAY LẠI NGÀY MAI'
      }
      if (!props.isOnDuty) {
        return 'OFFLINE'
      }
      if (props.workHours > 0) {
        const hours = Math.floor(props.workHours * 10) / 10
        return `ONLINE - ${hours}h/${props.maxHours}h`
      }
      return 'ONLINE'
    })
    
    const handleSystemClick = (system) => {
      console.log('🖱️ System clicked:', system, 'isOnDuty:', props.isOnDuty)
      if (!props.isOnDuty) {
        playSound('fail')
        return
      }
      playSound('click')
      emit('repair', system)
    }
    
    // Watch for prop changes
    watch(() => props.isOnDuty, (newVal) => {
      console.log('👁️ isOnDuty changed:', newVal)
    })
    
    watch(() => props.efficiency, (newVal) => {
      console.log('👁️ efficiency changed:', newVal)
    })
    
    watch(() => props.workHours, (newVal) => {
      console.log('👁️ workHours changed:', newVal)
    })
    
    return {
      systemsList,
      progressRingOffset,
      shouldStopBlade,
      bladeStyle,
      earningRateDisplay,
      statusText,
      handleSystemClick,
      Math
    }
  }
}
</script>
