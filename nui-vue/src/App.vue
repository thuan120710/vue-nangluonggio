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
      :isOnDuty="isOnDuty"
      :workLimitReached="workLimitReached"
      :workHours="workHours"
      :maxHours="maxHours"
      @close="handleClose"
      @startDuty="handleStartDuty"
      @stopDuty="handleStopDuty"
      @repair="handleRepair"
      @openEarnings="handleOpenEarnings"
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
    
    <!-- Earnings UI -->
    <EarningsUI
      v-if="currentView === 'earnings'"
      :earnings="currentEarnings"
      :efficiency="currentEfficiency"
      @close="handleCloseEarnings"
      @withdraw="handleWithdraw"
      @back="handleBackToMain"
    />
  </div>
</template>

<script>
import { ref, onMounted } from 'vue'
import RentalUI from './components/RentalUI.vue'
import MainUI from './components/MainUI.vue'
import MinigameUI from './components/MinigameUI.vue'
import FanMinigameUI from './components/FanMinigameUI.vue'
import CircuitBreakerUI from './components/CircuitBreakerUI.vue'
import CrackRepairUI from './components/CrackRepairUI.vue'
import EarningsUI from './components/EarningsUI.vue'
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
    EarningsUI
  },
  setup() {
    const currentView = ref('hidden')
    const currentSystems = ref({})
    const currentEfficiency = ref(0)
    const currentEarnings = ref(0)
    const isOnDuty = ref(false)
    const workLimitReached = ref(false)
    const workHours = ref(0)
    const maxHours = ref(12)
    
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
    
    const handleOpenEarnings = () => {
      post('openEarnings')
    }
    
    const handleCloseEarnings = () => {
      currentView.value = 'main'
    }
    
    const handleWithdraw = () => {
      post('withdrawEarnings')
      currentView.value = 'main'
    }
    
    const handleBackToMain = () => {
      post('backToMain')
    }
    
    const handleMinigameResult = (result) => {
      post('minigameResult', result)
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
          
        case 'showEarningsUI':
          currentView.value = 'earnings'
          if (data.earnings !== undefined) currentEarnings.value = data.earnings
          if (data.efficiency !== undefined) currentEfficiency.value = data.efficiency
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
          
        case 'updateActualEarningRate':
          // Update earning rate display
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
      }
    }
    
    onMounted(() => {
      window.addEventListener('message', handleMessage)
    })
    
    return {
      currentView,
      currentSystems,
      currentEfficiency,
      currentEarnings,
      isOnDuty,
      workLimitReached,
      workHours,
      maxHours,
      rentalData,
      minigameData,
      currentRound,
      totalRounds,
      handleClose,
      handleRentTurbine,
      handleStartDuty,
      handleStopDuty,
      handleRepair,
      handleOpenEarnings,
      handleCloseEarnings,
      handleWithdraw,
      handleBackToMain,
      handleMinigameResult
    }
  }
}
</script>
