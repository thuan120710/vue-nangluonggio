<template>
  <div>
    <!-- Rental UI -->
    <RentalUI
      v-if="currentView === 'rental'"
      :isRented="rentalData.isRented"
      :isOwner="rentalData.isOwner"
      :ownerName="rentalData.ownerName"
      :expiryTime="rentalData.expiryTime"
      :rentalPrice="rentalData.rentalPrice"
      @rent="handleRentTurbine"
      @close="handleClose"
    />
    
    <!-- Main UI -->
    <MainUI 
      v-if="currentView === 'main'"
      :systems="currentSystems"
      :efficiency="currentEfficiency"
      :earnings="currentEarnings"
      :earningRate="currentEarningRate"
      :isOnDuty="isOnDuty"
      :workLimitReached="workLimitReached"
      :workHours="workHours"
      :maxHours="maxHours"
      :ownerName="ownerName"
      :expiryTime="expiryTime"
      :currentFuel="currentFuel"
      :maxFuel="maxFuel"
      @close="handleClose"
      @startDuty="handleStartDuty"
      @stopDuty="handleStopDuty"
      @repair="handleRepair"
      @withdraw="handleWithdraw"
      @refuel="handleRefuel"
    />
    
    <!-- Minigame UI (Bar Type) -->
    <MinigameUI
      v-if="currentView === 'minigame'"
      :minigameData="minigameData"
      :currentRound="currentRound"
      :totalRounds="totalRounds"
      @result="handleMinigameResult"
    />
    
    <!-- Fan Minigame UI (Stability) -->
    <FanMinigameUI
      v-if="currentView === 'fanMinigame'"
      :minigameData="minigameData"
      @result="handleMinigameResult"
    />
    
    <!-- Circuit Breaker Minigame UI (Electrical) -->
    <CircuitBreakerUI
      v-if="currentView === 'circuitBreaker'"
      :minigameData="minigameData"
      @result="handleMinigameResult"
    />
    
    <!-- Crack Repair Minigame UI (Blades) -->
    <CrackRepairUI
      v-if="currentView === 'crackRepair'"
      :minigameData="minigameData"
      @result="handleMinigameResult"
    />
    
    <!-- Expiry Withdraw UI -->
    <ExpiryWithdrawUI
      v-if="currentView === 'expiryWithdraw'"
      :earnings="currentEarnings"
      :ownerName="ownerName"
      :expiryTime="expiryTime"
      :withdrawDeadline="withdrawDeadline"
      @close="handleClose"
      @withdraw="handleExpiryWithdraw"
    />
  </div>
</template>

<script>
import { ref, onMounted, onUnmounted } from 'vue'
import RentalUI from './components/RentalUI.vue'
import MainUI from './components/MainUI.vue'
import MinigameUI from './components/MinigameUI.vue'
import FanMinigameUI from './components/FanMinigameUI.vue'
import CircuitBreakerUI from './components/CircuitBreakerUI.vue'
import CrackRepairUI from './components/CrackRepairUI.vue'
import ExpiryWithdrawUI from './components/ExpiryWithdrawUI.vue'
import { post } from './utils/api'

export default {
  name: 'App',
  components: {
    RentalUI,
    MainUI,
    MinigameUI,
    FanMinigameUI,
    CircuitBreakerUI,
    CrackRepairUI,
    ExpiryWithdrawUI
  },
  setup() {
    // Responsive scaling system - Scale toàn bộ UI theo tỷ lệ màn hình
    const updateScale = () => {
      const designWidth = 1920  // Base design cho 1920x1080
      const designHeight = 1080
      
      const viewportWidth = window.innerWidth
      const viewportHeight = window.innerHeight
      
      // Tính scale theo cả width và height
      const scaleX = viewportWidth / designWidth
      const scaleY = viewportHeight / designHeight
      const scaleRatio = Math.min(scaleX, scaleY)
      
      // Base scale cho 1920x1080 là 0.82
      // Khi lên màn lớn hơn (2560x1440), tăng thêm 1% để UI to hơn
      let baseScale = 0.82
      if (scaleRatio > 1.0) {
        // Màn lớn hơn 1920x1080 -> tăng baseScale thêm 1%
        baseScale = 0.82 * 1.0
      }
      
      const scale = scaleRatio * baseScale
      
      // Apply scale to CSS variable
      document.documentElement.style.setProperty('--ui-scale', scale.toFixed(4))
      
      // Debug log
      console.log(`Viewport: ${viewportWidth}x${viewportHeight}, Scale: ${scale.toFixed(4)}`)
    }
    
    const currentView = ref('hidden')
    const currentSystems = ref({})
    const currentEfficiency = ref(0)
    const currentEarnings = ref(0)
    const currentEarningRate = ref(0)
    const isOnDuty = ref(false)
    const workLimitReached = ref(false)
    const workHours = ref(0)
    const maxHours = ref(12)
    const ownerName = ref('N/A')
    const expiryTime = ref(null)
    const withdrawDeadline = ref(null)
    const currentFuel = ref(84)
    const maxFuel = ref(84)
    
    const rentalData = ref({
      isRented: false,
      isOwner: false,
      ownerName: null,
      expiryTime: null,
      rentalPrice: 50000
    })
    
    const minigameData = ref({})
    const currentRound = ref(0)
    const totalRounds = ref(1)
    
    // Handlers
    const handleClose = () => {
      post('close')
    }
    
    const handleRentTurbine = () => {
      post('rentTurbine')
    }
    
    const handleStartDuty = () => {
      if (workLimitReached.value) {
        return
      }
      post('startDuty')
      isOnDuty.value = true
      
      // NGAY LẬP TỨC update UI như code gốc
      // Server sẽ gửi updateWorkTime sau
    }
    
    const handleStopDuty = () => {
      post('stopDuty')
      isOnDuty.value = false
    }
    
    const handleRepair = (system) => {
      post('repair', { system })
    }
    
    const handleWithdraw = () => {
      post('withdrawEarnings', { isGracePeriod: false })
      // Không chuyển view, giữ nguyên ở MainUI
    }
    
    const handleMinigameResult = (result) => {
      post('minigameResult', result)
    }
    
    const handleExpiryWithdraw = () => {
      post('withdrawEarnings', { isGracePeriod: true })
    }
    
    const handleRefuel = () => {
      post('refuelTurbine')
    }
    
    // Message handler from client
    const handleMessage = (event) => {
      const data = event.data
      
      switch (data.action) {
        case 'showRentalUI':
          currentView.value = 'rental'
          rentalData.value = {
            isRented: data.isRented || false,
            isOwner: data.isOwner || false,
            ownerName: data.ownerName || null,
            expiryTime: data.expiryTime || null,
            rentalPrice: data.rentalPrice || 50000
          }
          break
          
        case 'showMainUI':
          currentView.value = 'main'
          if (data.systems) currentSystems.value = data.systems
          if (data.efficiency !== undefined) currentEfficiency.value = data.efficiency
          if (data.earnings !== undefined) currentEarnings.value = data.earnings
          if (data.onDuty !== undefined) isOnDuty.value = data.onDuty
          if (data.ownerName !== undefined) ownerName.value = data.ownerName
          if (data.expiryTime !== undefined) expiryTime.value = data.expiryTime
          if (data.workHours !== undefined) workHours.value = data.workHours
          if (data.maxHours !== undefined) maxHours.value = data.maxHours
          if (data.currentFuel !== undefined) currentFuel.value = data.currentFuel
          if (data.maxFuel !== undefined) maxFuel.value = data.maxFuel
          break
          
        case 'hideUI':
          currentView.value = 'hidden'
          break
          
        case 'showMinigame':
          minigameData.value = {
            system: data.system,
            title: data.title,
            speed: data.speed,
            zoneSize: data.zoneSize
          }
          currentRound.value = 1
          totalRounds.value = data.rounds
          
          // Determine minigame type
          if (data.system === 'stability') {
            currentView.value = 'fanMinigame'
          } else if (data.system === 'electric') {
            currentView.value = 'circuitBreaker'
          } else if (data.system === 'blades') {
            currentView.value = 'crackRepair'
          } else {
            currentView.value = 'minigame'
          }
          break
          
        case 'showExpiryWithdrawUI':
          currentView.value = 'expiryWithdraw'
          if (data.earnings !== undefined) currentEarnings.value = data.earnings
          if (data.ownerName !== undefined) ownerName.value = data.ownerName
          if (data.expiryTime !== undefined) expiryTime.value = data.expiryTime
          if (data.withdrawDeadline !== undefined) withdrawDeadline.value = data.withdrawDeadline
          break
          
        case 'updateSystems':
          currentSystems.value = data.systems
          break
          
        case 'updateEfficiency':
          currentEfficiency.value = data.efficiency
          break
          
        case 'updateEarnings':
          currentEarnings.value = data.earnings
          break
          
        case 'updateEarningsPool':
          currentEarnings.value = data.earnings
          break
          
        case 'updateActualEarningRate':
          if (data.earningRate !== undefined) currentEarningRate.value = data.earningRate
          break
          
        case 'updateWorkTime':
          if (data.workHours !== undefined) workHours.value = data.workHours
          if (data.maxHours !== undefined) maxHours.value = data.maxHours
          break
          
        case 'resetStatus':
          // Handled in MainUI
          break
          
        case 'resetToInitialState':
          isOnDuty.value = false
          break
          
        case 'workLimitReached':
          workLimitReached.value = true
          break
          
        case 'resetWorkLimit':
          workLimitReached.value = false
          break
          
        case 'updateFuel':
          if (data.currentFuel !== undefined) currentFuel.value = data.currentFuel
          if (data.maxFuel !== undefined) maxFuel.value = data.maxFuel
          break
          
        case 'outOfFuel':
          isOnDuty.value = false
          break
      }
    }
    
    // Keyboard handler for testing (F2 to toggle MainUI)
    const handleKeyPress = (event) => {
      if (event.key === 'F2') {
        if (currentView.value === 'main') {
          currentView.value = 'hidden'
        } else {
          // Show MainUI with test data
          currentView.value = 'main'
          currentSystems.value = {
            stability: 85,
            electric: 70,
            lubrication: 90,
            blades: 65,
            safety: 95
          }
          currentEfficiency.value = 81
          currentEarnings.value = 15000
          currentEarningRate.value = 4050
          isOnDuty.value = true
          workLimitReached.value = false
          workHours.value = 3.5
          maxHours.value = 12
          ownerName.value = 'Test User'
          expiryTime.value = Math.floor(Date.now() / 1000) + (7 * 24 * 60 * 60) // 7 days from now
          currentFuel.value = 42
          maxFuel.value = 84
        }
      }
      
      // F3 to toggle RentalUI
      if (event.key === 'F3') {
        if (currentView.value === 'rental') {
          currentView.value = 'hidden'
        } else {
          // Show RentalUI with test data
          currentView.value = 'rental'
          rentalData.value = {
            isRented: false,
            isOwner: false,
            ownerName: 'Test Owner',
            expiryTime: Math.floor(Date.now() / 1000) + (7 * 24 * 60 * 60), // 7 days from now
            rentalPrice: 550000
          }
        }
      }
      
      // F4 to toggle ExpiryWithdrawUI
      if (event.key === 'F4') {
        if (currentView.value === 'expiryWithdraw') {
          currentView.value = 'hidden'
        } else {
          // Show ExpiryWithdrawUI with test data
          currentView.value = 'expiryWithdraw'
          currentEarnings.value = 13500
          ownerName.value = 'Test User'
          expiryTime.value = Math.floor(Date.now() / 1000) - 100 // Expired 100 seconds ago
          withdrawDeadline.value = Math.floor(Date.now() / 1000) + (3 * 60 * 60 + 45 * 60) // 3h 45m remaining
        }
      }
    }
    
    onMounted(() => {
      updateScale()
      window.addEventListener('resize', updateScale)
      window.addEventListener('message', handleMessage)
      window.addEventListener('keydown', handleKeyPress)
    })
    
    onUnmounted(() => {
      window.removeEventListener('resize', updateScale)
      window.removeEventListener('message', handleMessage)
      window.removeEventListener('keydown', handleKeyPress)
    })
    
    return {
      currentView,
      currentSystems,
      currentEfficiency,
      currentEarnings,
      currentEarningRate,
      isOnDuty,
      workLimitReached,
      workHours,
      maxHours,
      ownerName,
      expiryTime,
      withdrawDeadline,
      currentFuel,
      maxFuel,
      rentalData,
      minigameData,
      currentRound,
      totalRounds,
      handleClose,
      handleRentTurbine,
      handleStartDuty,
      handleStopDuty,
      handleRepair,
      handleWithdraw,
      handleMinigameResult,
      handleExpiryWithdraw,
      handleRefuel
    }
  }
}
</script>
