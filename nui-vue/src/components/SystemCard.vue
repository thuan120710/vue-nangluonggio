<template>
  <div 
    class="system-item"
    :class="{ disabled }"
    :data-system="system"
  >
    <div class="system-card" :data-status="statusType">
      <div class="card-glow"></div>
      <div class="system-icon">{{ systemIcon }}</div>
      <div class="system-circle">
        <svg class="circle-svg" width="90" height="90">
          <circle class="circle-bg" cx="45" cy="45" r="38"/>
          <circle 
            class="circle-progress" 
            cx="45" 
            cy="45" 
            r="38" 
            :data-system="system"
            :style="{ strokeDashoffset: circleOffset }"
          />
          <circle class="circle-inner" cx="45" cy="45" r="32"/>
        </svg>
        <div class="system-value" :data-system="system">
          {{ Math.floor(value) }}<span class="percent">%</span>
        </div>
      </div>
      <div class="system-label">{{ systemLabel }}</div>
      <div 
        class="system-status"
        :data-status="statusType"
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
        icon: '❄',
        label: 'ỔN ĐỊNH'
      },
      electric: {
        icon: '⚡',
        label: 'ĐIỆN ÁP'
      },
      lubrication: {
        icon: '⚙',
        label: 'KÉT CẦU'
      },
      blades: {
        icon: '🔄',
        label: 'TRỤC XOAY'
      },
      safety: {
        icon: '🛡',
        label: 'AN TOÀN'
      }
    }
    
    const config = computed(() => systemConfig[props.system] || {})
    
    const systemIcon = computed(() => config.value.icon || '⚙')
    const systemLabel = computed(() => config.value.label || props.system.toUpperCase())
    
    const circleOffset = computed(() => {
      const circumference = 238
      return circumference - (props.value / 100) * circumference
    })
    
    const statusText = computed(() => {
      if (props.value < 30) return 'NGUY HIỂM'
      if (props.value < 50) return 'CẢNH BÁO'
      return 'TỐT'
    })
    
    const statusType = computed(() => {
      if (props.value < 30) return 'critical'
      if (props.value < 50) return 'warning'
      return 'good'
    })
    
    return {
      systemIcon,
      systemLabel,
      circleOffset,
      statusText,
      statusType,
      Math
    }
  }
}
</script>
