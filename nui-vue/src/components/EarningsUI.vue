<template>
  <div class="container">
    <div class="bg-grid"></div>
    <div class="bg-particles">
      <div class="particle"></div>
      <div class="particle"></div>
      <div class="particle"></div>
    </div>
    
    <div class="header">
      <div class="header-left">
        <div class="logo-icon">💰</div>
        <div class="header-text">
          <h1>EARNINGS POOL</h1>
          <span class="subtitle">ACCUMULATED REVENUE</span>
        </div>
      </div>
      <button class="close-btn" @click="$emit('close')">
        <span class="close-line"></span>
        <span class="close-line"></span>
      </button>
    </div>
    
    <div class="earnings-content">
      <div class="earnings-display">
        <div class="earnings-label">TOTAL BALANCE</div>
        <div class="earnings-amount">
          <span>{{ Math.floor(earnings).toLocaleString() }}</span>
          <span class="currency-symbol"> IC</span>
          <div class="amount-glow"></div>
        </div>
      </div>
      
      <div class="earnings-stats">
        <div class="stat-card">
          <div class="stat-icon">📊</div>
          <div class="stat-info">
            <div class="stat-label">Current Efficiency</div>
            <div class="stat-value">{{ Math.floor(efficiency) }}%</div>
          </div>
        </div>
        <div class="stat-card">
          <div class="stat-icon">⚡</div>
          <div class="stat-info">
            <div class="stat-label">Earning Rate</div>
            <div class="stat-value">{{ earningRateDisplay }} IC/h</div>
          </div>
        </div>
      </div>
      
      <div class="earnings-actions">
        <button class="btn btn-withdraw" @click="$emit('withdraw')">
          <span class="btn-icon">💵</span>
          WITHDRAW FUNDS
        </button>
        <button class="btn btn-back" @click="$emit('back')">
          <span class="btn-icon">←</span>
          BACK
        </button>
      </div>
    </div>
  </div>
</template>

<script>
import { computed } from 'vue'

export default {
  name: 'EarningsUI',
  props: {
    earnings: {
      type: Number,
      default: 0
    },
    efficiency: {
      type: Number,
      default: 0
    }
  },
  emits: ['close', 'withdraw', 'back'],
  setup(props) {
    const earningRateDisplay = computed(() => {
      const basePerHour = 5000
      const rate = basePerHour * (props.efficiency / 100)
      return Math.floor(rate).toLocaleString()
    })
    
    return {
      earningRateDisplay,
      Math
    }
  }
}
</script>
