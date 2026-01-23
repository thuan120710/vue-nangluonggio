<template>
  <div class="container">
    <div class="bg-grid"></div>
    <div class="header">
      <div class="header-left">
        <div class="logo-icon">🔧</div>
        <div class="header-text">
          <h1>{{ minigameData.title || 'SYSTEM CALIBRATION' }}</h1>
          <span class="subtitle">PRECISION REQUIRED</span>
        </div>
      </div>
    </div>
    
    <div class="minigame-content">
      <div class="minigame-wrapper">
        <div class="minigame-bar">
          <div class="bar-glow"></div>
          <div 
            class="minigame-zone"
            :style="{ left: zoneLeft + '%', width: zoneWidth + '%' }"
          ></div>
          <div 
            class="minigame-indicator"
            :style="{ left: indicatorPosition + '%' }"
          >
            <div class="indicator-glow"></div>
          </div>
        </div>
        <div class="minigame-instruction">
          <span class="key-hint">[SPACE]</span> or <span class="key-hint">[E]</span> when indicator is in green zone
        </div>
        <div class="minigame-round">
          Round: <span>{{ currentRound }}</span>/<span>{{ totalRounds }}</span>
        </div>
      </div>
    </div>
  </div>
</template>

<script>
import { ref, computed, onMounted, onUnmounted } from 'vue'
import { playSound } from '../utils/sound'

export default {
  name: 'MinigameUI',
  props: {
    minigameData: {
      type: Object,
      required: true
    },
    currentRound: {
      type: Number,
      default: 1
    },
    totalRounds: {
      type: Number,
      default: 1
    }
  },
  emits: ['result'],
  setup(props, { emit }) {
    const indicatorPosition = ref(0)
    const indicatorDirection = ref(1)
    const zoneLeft = ref(0)
    const zoneWidth = ref(0)
    const active = ref(true)
    let animationId = null
    
    // Setup zone
    const setupZone = () => {
      const zoneSize = props.minigameData.zoneSize || 0.2
      const zoneStart = Math.random() * (1 - zoneSize)
      zoneLeft.value = zoneStart * 100
      zoneWidth.value = zoneSize * 100
    }
    
    // Animate indicator
    const animate = () => {
      if (!active.value) return
      
      const speed = props.minigameData.speed || 1.0
      indicatorPosition.value += indicatorDirection.value * speed * 0.01
      
      if (indicatorPosition.value >= 100) {
        indicatorPosition.value = 100
        indicatorDirection.value = -1
      } else if (indicatorPosition.value <= 0) {
        indicatorPosition.value = 0
        indicatorDirection.value = 1
      }
      
      animationId = requestAnimationFrame(animate)
    }
    
    // Check result
    const checkResult = () => {
      if (!active.value) return
      
      const zoneLeftVal = zoneLeft.value / 100
      const zoneWidthVal = zoneWidth.value / 100
      const zoneRight = zoneLeftVal + zoneWidthVal
      const indicatorPos = indicatorPosition.value / 100
      
      let result = 'fail'
      
      if (indicatorPos >= zoneLeftVal && indicatorPos <= zoneRight) {
        const zoneCenter = zoneLeftVal + zoneWidthVal / 2
        const distance = Math.abs(indicatorPos - zoneCenter)
        const perfectThreshold = zoneWidthVal * 0.2
        
        if (distance <= perfectThreshold) {
          result = 'perfect'
          playSound('success')
        } else {
          result = 'good'
          playSound('click')
        }
      } else {
        playSound('fail')
      }
      
      active.value = false
      emit('result', {
        system: props.minigameData.system,
        result: result
      })
    }
    
    // Keyboard handler
    const handleKeydown = (e) => {
      if (active.value && (e.key === ' ' || e.key === 'e' || e.key === 'E')) {
        e.preventDefault()
        checkResult()
      }
    }
    
    onMounted(() => {
      setupZone()
      animate()
      document.addEventListener('keydown', handleKeydown)
    })
    
    onUnmounted(() => {
      active.value = false
      if (animationId) {
        cancelAnimationFrame(animationId)
      }
      document.removeEventListener('keydown', handleKeydown)
    })
    
    return {
      indicatorPosition,
      zoneLeft,
      zoneWidth
    }
  }
}
</script>
