<template>
  <div class="main-wrapper">
    <div class="container">
    <div class="background-image"></div>
    <div class="bg-grid"></div>
    <div class="header">
      <div class="header-left">
        <div class="logo-icon">⚡</div>
        <div class="header-text">
          <h1>SỬA CHỮA HỆ THỐNG ĐIỆN</h1>
          <span class="subtitle">RESET CIRCUIT BREAKERS</span>
        </div>
      </div>
    </div>
    
    <div class="circuit-breaker-content">
      <div class="circuit-instruction">
        <div class="instruction-icon">⚠️</div>
        <div class="instruction-text">CHUYỂN TẤT CẢ CẦU DAO VỀ MÀU XANH</div>
        <div class="instruction-hint">
          <span class="hint-item">
            <span class="color-dot green"></span> Xanh: Đã ổn
          </span>
          <span class="hint-item">
            <span class="color-dot yellow"></span> Vàng: Kéo lên 1 lần
          </span>
          <span class="hint-item">
            <span class="color-dot red"></span> Đỏ: Kéo lên 2 lần
          </span>
        </div>
        <div class="instruction-sub">Giữ chuột và kéo lên để gạt cầu dao</div>
      </div>
      
      <div class="breakers-panel">
        <div class="panel-frame">
          <div class="panel-header">
            <div class="panel-title">ELECTRICAL PANEL</div>
            <div class="panel-voltage">480V</div>
          </div>
          
          <div class="breakers-grid">
            <div 
              v-for="breaker in breakers"
              :key="breaker.id"
              class="breaker"
              :class="[
                `status-${breaker.status}`,
                { dragging: breaker.isDragging }
              ]"
              :data-breaker="breaker.id"
              @mousedown="startDragging(breaker.id, $event)"
            >
              <div class="breaker-label">BREAKER {{ breaker.id }}</div>
              <div class="breaker-body">
                <div 
                  class="breaker-indicator"
                  :style="{ background: indicatorColor(breaker.status) }"
                ></div>
                <div class="breaker-switch" :class="{ on: breaker.status === 'green' }">
                  <div 
                    class="switch-handle"
                    :style="{ transform: `translate(-50%, ${breaker.handlePosition}%)` }"
                  ></div>
                  <div class="drag-progress">
                    <div 
                      class="drag-progress-bar"
                      :style="{ width: breaker.dragProgress + '%' }"
                    ></div>
                  </div>
                </div>
              </div>
              <div class="breaker-rating">{{ breaker.rating }}A</div>
            </div>
          </div>
          
          <div class="panel-footer">
            <div class="warning-strip">⚠ CAUTION: HIGH VOLTAGE ⚠</div>
          </div>
        </div>
      </div>
      
      <div class="breaker-counter">
        Cầu dao đã sửa: <span>{{ completedCount }}</span>/4
      </div>
    </div>
  </div>
  </div>
</template>

<script>
import { ref, computed, onMounted, onUnmounted } from 'vue'
import { playSound } from '../utils/sound'

export default {
  name: 'CircuitBreakerUI',
  props: {
    minigameData: {
      type: Object,
      required: true
    }
  },
  emits: ['result'],
  setup(props, { emit }) {
    const breakers = ref([])
    
    const completedCount = computed(() => {
      return breakers.value.filter(b => b.status === 'green').length
    })
    
    const indicatorColor = (status) => {
      if (status === 'green') return '#00ff88'
      if (status === 'yellow') return '#ffaa00'
      return '#ff4444'
    }
    
    const initBreakers = () => {
      const states = ['green', 'red', 'red', 'yellow']
      const ratings = [20, 30, 25, 40]
      
      // Shuffle states
      for (let i = states.length - 1; i > 0; i--) {
        const j = Math.floor(Math.random() * (i + 1));
        [states[i], states[j]] = [states[j], states[i]]
      }
      
      breakers.value = states.map((status, index) => ({
        id: index + 1,
        status: status,
        rating: ratings[index],
        clicksNeeded: status === 'green' ? 0 : (status === 'red' ? 2 : 1),
        clicksDone: 0,
        isDragging: false,
        dragStartY: 0,
        dragProgress: 0,
        handlePosition: status === 'green' ? -60 : 10
      }))
    }
    
    const startDragging = (breakerId, event) => {
      const breaker = breakers.value.find(b => b.id === breakerId)
      if (!breaker || breaker.status === 'green') return
      
      breaker.isDragging = true
      breaker.dragStartY = event.clientY
      breaker.dragProgress = 0
    }
    
    const handleMouseMove = (event) => {
      breakers.value.forEach(breaker => {
        if (!breaker.isDragging) return
        
        const dragDistance = breaker.dragStartY - event.clientY
        const requiredDistance = 80
        
        breaker.dragProgress = Math.max(0, Math.min(100, (dragDistance / requiredDistance) * 100))
        
        const translateY = 10 - (breaker.dragProgress / 100) * 70
        breaker.handlePosition = translateY
      })
    }
    
    const handleMouseUp = () => {
      breakers.value.forEach(breaker => {
        if (!breaker.isDragging) return
        
        breaker.isDragging = false
        
        if (breaker.dragProgress >= 100) {
          breaker.clicksDone++
          playSound('click')
          
          if (breaker.clicksDone >= breaker.clicksNeeded) {
            breaker.status = 'green'
            breaker.handlePosition = -60
            playSound('success')
            
            // Check if all completed
            if (breakers.value.every(b => b.status === 'green')) {
              setTimeout(() => {
                emit('result', {
                  system: props.minigameData.system,
                  result: 'perfect'
                })
              }, 800)
            }
          }
        }
        
        breaker.dragProgress = 0
        if (breaker.status !== 'green') {
          breaker.handlePosition = 10
        }
      })
    }
    
    onMounted(() => {
      initBreakers()
      document.addEventListener('mousemove', handleMouseMove)
      document.addEventListener('mouseup', handleMouseUp)
    })
    
    onUnmounted(() => {
      document.removeEventListener('mousemove', handleMouseMove)
      document.removeEventListener('mouseup', handleMouseUp)
    })
    
    return {
      breakers,
      completedCount,
      indicatorColor,
      startDragging
    }
  }
}
</script>
