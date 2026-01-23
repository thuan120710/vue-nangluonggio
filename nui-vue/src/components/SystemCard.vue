<template>
  <div 
    class="system-item"
    :class="{ disabled }"
    :data-system="system"
  >
    <div class="system-card">
      <div class="card-glow"></div>
      <div class="system-icon">{{ systemIcon }}</div>
      <div class="system-circle">
        <svg class="circle-svg" width="120" height="120">
          <defs>
            <linearGradient :id="`grad-${system}`" x1="0%" y1="0%" x2="100%" y2="100%">
              <stop offset="0%" :style="`stop-color:${gradientStart};stop-opacity:1`" />
              <stop offset="100%" :style="`stop-color:${gradientEnd};stop-opacity:1`" />
            </linearGradient>
          </defs>
          <circle class="circle-bg" cx="60" cy="60" r="50"/>
          <circle 
            class="circle-progress" 
            cx="60" 
            cy="60" 
            r="50" 
            :data-system="system"
            :style="{ strokeDashoffset: circleOffset }"
          />
          <circle class="circle-inner" cx="60" cy="60" r="42"/>
        </svg>
        <div class="system-value" :data-system="system">
          {{ Math.floor(value) }}<span class="percent">%</span>
        </div>
      </div>
      <div class="system-label">{{ systemLabel }}</div>
      <div 
        class="system-status"
        :style="{ color: statusColor }"
      >
        {{ statusText }}
      </div>
    </div>
  </div>
</template>

<script>
import { computed } from 'vue'

export default {
  name: 'SystemCard',
  props: {
    system: {
      type: String,
      required: true
    },
    value: {
      type: Number,
      default: 70
    },
    disabled: {
      type: Boolean,
      default: false
    }
  },
  setup(props) {
    const systemConfig = {
      stability: {
        icon: '⚖',
        label: 'STABILITY',
        gradientStart: '#00ffff',
        gradientEnd: '#0088ff'
      },
      electric: {
        icon: '⚡',
        label: 'ELECTRICAL',
        gradientStart: '#ffff00',
        gradientEnd: '#ffaa00'
      },
      lubrication: {
        icon: '💧',
        label: 'LUBRICATION',
        gradientStart: '#00ffff',
        gradientEnd: '#00ff88'
      },
      blades: {
        icon: '🔄',
        label: 'BLADES',
        gradientStart: '#ff00ff',
        gradientEnd: '#ff0088'
      },
      safety: {
        icon: '🛡',
        label: 'SAFETY',
        gradientStart: '#00ff88',
        gradientEnd: '#00cc6a'
      }
    }
    
    const config = computed(() => systemConfig[props.system] || {})
    
    const systemIcon = computed(() => config.value.icon || '⚙')
    const systemLabel = computed(() => config.value.label || props.system.toUpperCase())
    const gradientStart = computed(() => config.value.gradientStart || '#00ffff')
    const gradientEnd = computed(() => config.value.gradientEnd || '#00ff88')
    
    const circleOffset = computed(() => {
      const circumference = 314
      return circumference - (props.value / 100) * circumference
    })
    
    const statusText = computed(() => {
      if (props.value < 30) return 'CRITICAL'
      if (props.value < 50) return 'WARNING'
      return 'OPERATIONAL'
    })
    
    const statusColor = computed(() => {
      if (props.value < 30) return '#ff4444'
      if (props.value < 50) return '#ffaa00'
      return 'rgba(0, 255, 136, 0.6)'
    })
    
    return {
      systemIcon,
      systemLabel,
      gradientStart,
      gradientEnd,
      circleOffset,
      statusText,
      statusColor,
      Math
    }
  }
}
</script>
