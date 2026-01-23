<template>
  <div class="container">
    <div class="bg-grid"></div>
    <div class="header">
      <div class="header-left">
        <div class="logo-icon">🔨</div>
        <div class="header-text">
          <h1>SỬA CHỮA THÂN THÁP</h1>
          <span class="subtitle">REPAIR TOWER CRACKS</span>
        </div>
      </div>
    </div>
    
    <div class="crack-repair-content">
      <div class="crack-instruction">
        <div class="instruction-icon">⚠️</div>
        <div class="instruction-text">SỬA CHỮA VẾT NỨT TRÊN THÂN THÁP</div>
        <div class="instruction-hint">
          Click hoặc giữ chuột và di chuyển trên vết nứt để trét xi măng
        </div>
      </div>
      
      <div 
        class="tower-structure"
        @mousedown="handleMouseDown"
        @mousemove="handleMouseMove"
      >
        <!-- Tower visual -->
        <div class="tower-body">
          <div class="tower-segment"></div>
          <div class="tower-segment"></div>
          <div class="tower-segment"></div>
          <div class="tower-segment"></div>
          <div class="tower-segment"></div>
        </div>
        
        <!-- Cracks -->
        <div class="cracks-container">
          <div 
            v-for="crack in cracks"
            :key="crack.id"
            class="crack"
            :class="{ repaired: crack.isRepaired }"
            :data-crack="crack.id"
            :style="{
              left: crack.x + '%',
              top: crack.y + '%',
              width: crack.width + 'px',
              height: crack.height + 'px',
              transform: `translate(-50%, -50%) rotate(${crack.rotation}deg)`
            }"
          >
            <svg 
              class="crack-svg"
              :width="crack.width"
              :height="crack.height * 3"
            >
              <path 
                :d="crack.mainPath"
                class="crack-shadow-path"
                stroke="rgba(0, 0, 0, 0.5)"
                stroke-width="5"
                fill="none"
              />
              <path 
                :d="crack.mainPath"
                class="crack-main-path"
                stroke="rgba(0, 0, 0, 0.9)"
                stroke-width="3"
                fill="none"
              />
              <path 
                v-for="(branch, idx) in crack.branches"
                :key="idx"
                :d="branch.path"
                class="crack-branch-path"
                stroke="rgba(0, 0, 0, 0.8)"
                stroke-width="2"
                fill="none"
              />
            </svg>
            
            <div 
              class="repair-overlay"
              :style="{ width: crack.repairProgress + '%' }"
            ></div>
            
            <div class="crack-progress">
              <div 
                class="crack-progress-fill"
                :style="{ width: crack.repairProgress + '%' }"
              ></div>
            </div>
            
            <div v-if="!crack.isRepaired" class="crack-glow"></div>
          </div>
        </div>
        
        <!-- Tower details -->
        <div class="tower-rivets">
          <div class="rivet"></div>
          <div class="rivet"></div>
          <div class="rivet"></div>
          <div class="rivet"></div>
          <div class="rivet"></div>
          <div class="rivet"></div>
          <div class="rivet"></div>
          <div class="rivet"></div>
        </div>
        
        <!-- Cement splatters -->
        <div 
          v-for="splatter in splatters"
          :key="splatter.id"
          class="cement-splatter"
          :style="{
            left: splatter.x + 'px',
            top: splatter.y + 'px'
          }"
        ></div>
      </div>
      
      <div class="crack-counter">
        Vết nứt đã sửa: <span>{{ repairedCount }}</span>/<span>{{ cracks.length }}</span>
      </div>
    </div>
  </div>
</template>

<script>
import { ref, computed, onMounted, onUnmounted } from 'vue'
import { playSound } from '../utils/sound'

export default {
  name: 'CrackRepairUI',
  props: {
    minigameData: {
      type: Object,
      required: true
    }
  },
  emits: ['result'],
  setup(props, { emit }) {
    const cracks = ref([])
    const splatters = ref([])
    const isMouseDown = ref(false)
    let splatterId = 0
    
    const repairedCount = computed(() => {
      return cracks.value.filter(c => c.isRepaired).length
    })
    
    const generateCrackPath = (width, height) => {
      let path = `M 0 ${height * 1.5}`
      const segments = 8
      
      for (let i = 1; i <= segments; i++) {
        const x = (width / segments) * i
        const y = height * 1.5 + (Math.random() - 0.5) * height * 0.8
        path += ` L ${x} ${y}`
      }
      
      return path
    }
    
    const generateBranches = (width, height) => {
      const numBranches = 2 + Math.floor(Math.random() * 3)
      const branches = []
      
      for (let i = 0; i < numBranches; i++) {
        const position = 20 + Math.random() * 60
        const angle = -45 + Math.random() * 90
        const length = 15 + Math.random() * 25
        
        const branchX = (width * position) / 100
        const branchY = height * 1.5
        const branchEndX = branchX + Math.cos(angle * Math.PI / 180) * length
        const branchEndY = branchY + Math.sin(angle * Math.PI / 180) * length
        
        branches.push({
          path: `M ${branchX} ${branchY} L ${branchEndX} ${branchEndY}`
        })
      }
      
      return branches
    }
    
    const initCracks = () => {
      const numCracks = Math.floor(Math.random() * 2) + 2
      const newCracks = []
      
      const towerCenterX = 50
      const towerTopWidth = 30
      const towerBottomWidth = 40
      
      for (let i = 0; i < numCracks; i++) {
        const yPos = 20 + Math.random() * 60
        const widthAtY = towerTopWidth + (towerBottomWidth - towerTopWidth) * (yPos - 20) / 60
        const xOffset = (Math.random() - 0.5) * widthAtY * 0.7
        const xPos = towerCenterX + xOffset
        
        const width = 100 + Math.random() * 80
        const height = 8 + Math.random() * 6
        const rotation = -25 + Math.random() * 50
        
        const crack = {
          id: i + 1,
          x: xPos,
          y: yPos,
          width: width,
          height: height,
          rotation: rotation,
          repairProgress: 0,
          isRepaired: false,
          mainPath: generateCrackPath(width, height),
          branches: generateBranches(width, height)
        }
        
        newCracks.push(crack)
      }
      
      cracks.value = newCracks
    }
    
    const handleMouseDown = (e) => {
      isMouseDown.value = true
      repairAtPosition(e)
    }
    
    const handleMouseMove = (e) => {
      if (!isMouseDown.value) return
      repairAtPosition(e)
    }
    
    const handleMouseUp = () => {
      isMouseDown.value = false
    }
    
    const repairAtPosition = (e) => {
      const crackElement = e.target.closest('.crack')
      if (!crackElement) return
      
      const crackId = parseInt(crackElement.getAttribute('data-crack'))
      const crack = cracks.value.find(c => c.id === crackId)
      
      if (!crack || crack.isRepaired) return
      
      crack.repairProgress += 3
      
      if (Math.random() < 0.3) {
        playSound('repair')
      }
      
      if (crack.repairProgress >= 100) {
        crack.repairProgress = 100
        crack.isRepaired = true
        playSound('success')
        
        // Check if all repaired
        if (cracks.value.every(c => c.isRepaired)) {
          setTimeout(() => {
            emit('result', {
              system: props.minigameData.system,
              result: 'perfect'
            })
          }, 1000)
        }
      }
      
      // Create splatter effect
      const rect = e.currentTarget.getBoundingClientRect()
      createSplatter(e.clientX - rect.left, e.clientY - rect.top)
    }
    
    const createSplatter = (x, y) => {
      const splatter = {
        id: splatterId++,
        x: x,
        y: y
      }
      
      splatters.value.push(splatter)
      
      setTimeout(() => {
        const index = splatters.value.findIndex(s => s.id === splatter.id)
        if (index > -1) {
          splatters.value.splice(index, 1)
        }
      }, 500)
    }
    
    onMounted(() => {
      initCracks()
      document.body.classList.add('trowel-cursor')
      document.addEventListener('mouseup', handleMouseUp)
    })
    
    onUnmounted(() => {
      document.body.classList.remove('trowel-cursor')
      document.removeEventListener('mouseup', handleMouseUp)
    })
    
    return {
      cracks,
      splatters,
      repairedCount,
      handleMouseDown,
      handleMouseMove
    }
  }
}
</script>
