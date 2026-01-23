<template>
  <div class="container">
    <div class="bg-grid"></div>
    <div class="header">
      <div class="header-left">
        <div class="logo-icon">🔧</div>
        <div class="header-text">
          <h1>SỬA CHỮA CÁNH QUẠT</h1>
          <span class="subtitle">TIGHTEN BOLTS & ROTATE FAN</span>
        </div>
      </div>
    </div>
    
    <div class="fan-minigame-content">
      <!-- Phase 1: Tighten Bolts -->
      <div v-if="phase === 1" class="fan-phase">
        <div class="fan-instruction">
          <div class="instruction-icon">🔩</div>
          <div class="instruction-text">SIẾT ỐC CÁNH QUẠT</div>
          <div class="instruction-hint">Click vào ốc để siết (3 lần)</div>
        </div>
        
        <div class="fan-container">
          <div class="fan-center">
            <div class="fan-core"></div>
          </div>
          <div class="fan-blades">
            <div class="fan-blade"></div>
            <div class="fan-blade"></div>
            <div class="fan-blade"></div>
          </div>
          <!-- Bolts -->
          <div 
            v-for="bolt in bolts"
            :key="bolt.id"
            class="bolt"
            :class="[`bolt-${bolt.id}`, { tightened: bolt.tightened }]"
            :data-bolt="bolt.id"
            @click="tightenBolt(bolt.id)"
          >
            <div class="bolt-head"></div>
            <div class="bolt-glow"></div>
          </div>
        </div>
        
        <div class="bolt-counter">
          Ốc đã siết: <span>{{ boltsTightened }}</span>/3
        </div>
      </div>
      
      <!-- Phase 2: Rotate Fan -->
      <div v-if="phase === 2" class="fan-phase">
        <div class="fan-instruction">
          <div class="instruction-icon">🔄</div>
          <div class="instruction-text">XOAY CÁNH QUẠT</div>
          <div class="instruction-hint">Xoay chuột theo chiều kim đồng hồ</div>
        </div>
        
        <div 
          class="fan-container"
          @mousemove="handleMouseMove"
        >
          <div class="fan-center">
            <div class="fan-core"></div>
            <div class="rotation-arrow">↻</div>
          </div>
          <div 
            class="fan-blades rotating"
            :style="{ animationDuration: fanSpeed + 's' }"
          >
            <div class="fan-blade"></div>
            <div class="fan-blade"></div>
            <div class="fan-blade"></div>
          </div>
        </div>
        
        <div class="rotation-progress">
          <div class="progress-label">Tiến độ xoay</div>
          <div class="progress-bar-container">
            <div 
              class="progress-bar"
              :style="{ width: rotationProgress + '%' }"
            ></div>
          </div>
          <div class="progress-value">
            <span>{{ Math.floor(rotationProgress) }}</span>%
          </div>
        </div>
      </div>
    </div>
  </div>
</template>

<script>
import { ref, computed, onMounted, onUnmounted } from 'vue'
import { playSound } from '../utils/sound'

export default {
  name: 'FanMinigameUI',
  props: {
    minigameData: {
      type: Object,
      required: true
    }
  },
  emits: ['result'],
  setup(props, { emit }) {
    const phase = ref(1)
    const boltsTightened = ref(0)
    const rotationProgress = ref(0)
    const lastMouseAngle = ref(0)
    const mouseTracking = ref(false)
    
    const bolts = ref([
      { id: 1, tightened: false },
      { id: 2, tightened: false },
      { id: 3, tightened: false }
    ])
    
    const fanSpeed = computed(() => {
      const progress = rotationProgress.value
      let speed
      
      if (progress < 30) {
        speed = 6 - (progress / 30) * 1.5
      } else if (progress < 50) {
        speed = 4.5 - ((progress - 30) / 20) * 1.5
      } else if (progress < 70) {
        speed = 3 - ((progress - 50) / 20) * 1.5
      } else {
        speed = 1.5 - ((progress - 70) / 30) * 1.2
      }
      
      return speed.toFixed(2)
    })
    
    const tightenBolt = (boltId) => {
      const bolt = bolts.value.find(b => b.id === boltId)
      if (!bolt || bolt.tightened) return
      
      bolt.tightened = true
      boltsTightened.value++
      playSound('click')
      
      if (boltsTightened.value >= 3) {
        playSound('success')
        setTimeout(() => {
          phase.value = 2
          mouseTracking.value = true
        }, 500)
      }
    }
    
    const calculateMouseAngle = (e, container) => {
      const rect = container.getBoundingClientRect()
      const centerX = rect.left + rect.width / 2
      const centerY = rect.top + rect.height / 2
      
      const deltaX = e.clientX - centerX
      const deltaY = e.clientY - centerY
      
      return Math.atan2(deltaY, deltaX) * (180 / Math.PI)
    }
    
    const handleMouseMove = (e) => {
      if (phase.value !== 2 || !mouseTracking.value) return
      
      const container = e.currentTarget
      const currentAngle = calculateMouseAngle(e, container)
      
      if (lastMouseAngle.value !== 0) {
        let angleDiff = currentAngle - lastMouseAngle.value
        
        // Handle angle wrap-around
        if (angleDiff > 180) angleDiff -= 360
        if (angleDiff < -180) angleDiff += 360
        
        // Only count clockwise rotation (positive angles)
        if (angleDiff > 0 && angleDiff < 90) {
          rotationProgress.value += angleDiff / 25
          rotationProgress.value = Math.min(100, rotationProgress.value)
          
          // Check completion
          if (rotationProgress.value >= 100) {
            completeMinigame('perfect')
          }
        }
      }
      
      lastMouseAngle.value = currentAngle
    }
    
    const completeMinigame = (result) => {
      mouseTracking.value = false
      playSound('success')
      
      emit('result', {
        system: props.minigameData.system,
        result: result
      })
    }
    
    onMounted(() => {
      document.body.style.cursor = 'url("data:image/svg+xml;utf8,<svg xmlns=\'http://www.w3.org/2000/svg\' width=\'32\' height=\'32\' viewBox=\'0 0 32 32\'><text y=\'24\' font-size=\'24\'>🔧</text></svg>") 16 16, auto'
    })
    
    onUnmounted(() => {
      document.body.style.cursor = 'default'
    })
    
    return {
      phase,
      boltsTightened,
      rotationProgress,
      bolts,
      fanSpeed,
      tightenBolt,
      handleMouseMove,
      Math
    }
  }
}
</script>
