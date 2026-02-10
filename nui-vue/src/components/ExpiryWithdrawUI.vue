<template>
  <div class="main-wrapper">
    <div class="container">
      <div class="background-image"></div>
      <div class="bg-grid"></div>
      
      <!-- Header -->
      <div class="header">
        <div class="header-logo">
          <img src="/img/f17.png" alt="F17 Logo" class="logo-image">
        </div>
        
        <div class="header-left">
          <div class="header-text">
            <span class="subtitle">Người thuê: <span class="subtitle-highlight">{{ ownerName }}</span></span>
          </div>
        </div>
        
        <div class="header-center">
          <h1>TRẠM KHAI THÁC ĐIỆN GIÓ</h1>
        </div>
        
        <div class="header-right">
          <span class="time-label">Thời gian rút tiền còn lại:</span>
          <span class="time-value time-warning">{{ remainingTime }}</span>
        </div>
        
        <button class="close-btn" @click="$emit('close')">
          ✕
        </button>
      </div>

      <!-- Content -->
      <div class="expiry-content">
        <!-- Left: Turbine -->
        <div class="expiry-left">
          <div class="turbine-container-expiry">
            <!-- Outer Rings -->
            <div class="outer-ring ring-1"></div>
            <div class="outer-ring ring-2"></div>
            <div class="outer-ring ring-3"></div>
            
            <!-- Progress Ring -->
            <svg class="progress-ring" width="280" height="280">
              <defs>
                <linearGradient id="progressGradient" x1="0%" y1="0%" x2="100%" y2="100%">
                  <stop offset="0%" style="stop-color:#ff4444;stop-opacity:1" />
                  <stop offset="100%" style="stop-color:#cc0000;stop-opacity:1" />
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
                class="progress-ring-circle-expiry" 
                cx="140" 
                cy="140" 
                r="120"
                style="stroke-dashoffset: 0"
              />
            </svg>
            
            <!-- Turbine -->
            <div class="turbine-wrapper">
              <div class="turbine-center">
                <div class="center-core"></div>
                <div class="center-ring"></div>
              </div>
              <div class="blade-container stopped">
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
          </div>
          
          <!-- Status Box dưới cánh quạt -->
          <div class="status-box">
            <div class="status-title">TRẠNG THÁI HỆ THỐNG</div>
            <div class="status-message offline"><span class="red-dot"></span> OFFLINE - HẾT THỜI HẠN THUÊ</div>
          </div>
        </div>

        <!-- Right: Withdraw Info -->
        <div class="expiry-right">
          <!-- Total Income -->
          <div class="total-income-section-expiry">
            <div class="total-glow"></div>
            <div class="total-label">TỔNG THU NHẬP</div>
            <div class="total-value-wrapper">
              <div class="circle-ring"></div>
              <div class="total-value">{{ Math.floor(earnings).toLocaleString() }} IC</div>
            </div>
          </div>

          <!-- Warning Time -->
          <div class="warning-time-box">
            <div class="warning-time-label">THỜI GIAN RÚT TIỀN CÒN LẠI:</div>
            <div class="warning-time-value">{{ remainingTime }}</div>
          </div>

          <!-- Withdraw Button -->
          <button class="btn btn-withdraw-expiry" @click="handleWithdraw">
            <img src="/img/Primary.svg" alt="Money" class="btn-icon-img">
            RÚT TIỀN
          </button>
        </div>
      </div>
    </div>
  </div>
</template>

<script>
import { computed, ref, onMounted, onUnmounted } from 'vue'

export default {
  name: 'ExpiryWithdrawUI',
  props: {
    earnings: {
      type: Number,
      default: 0
    },
    ownerName: {
      type: String,
      default: 'N/A'
    },
    expiryTime: {
      type: Number,
      default: null
    },
    withdrawDeadline: {
      type: Number,
      default: null
    }
  },
  emits: ['close', 'withdraw'],
  setup(props, { emit }) {
    const currentTime = ref(Math.floor(Date.now() / 1000))
    let timeInterval = null
    
    // Cập nhật thời gian mỗi giây
    onMounted(() => {
      timeInterval = setInterval(() => {
        currentTime.value = Math.floor(Date.now() / 1000)
      }, 1000)
    })
    
    // CRITICAL FIX: onUnmounted phải ở ngoài onMounted
    onUnmounted(() => {
      if (timeInterval) {
        clearInterval(timeInterval)
        timeInterval = null
      }
    })
    
    const remainingTime = computed(() => {
      if (!props.withdrawDeadline) return '0h 0m'
      
      const remainingSeconds = props.withdrawDeadline - currentTime.value
      
      if (remainingSeconds <= 0) return 'HẾT HẠN'
      
      const hours = Math.floor(remainingSeconds / 3600)
      const minutes = Math.floor((remainingSeconds % 3600) / 60)
      
      return `${hours}h ${minutes}m`
    })
    
    const handleWithdraw = () => {
      emit('withdraw')
    }
    
    return {
      remainingTime,
      handleWithdraw,
      Math
    }
  }
}
</script>

<style scoped>
/* Header override */
.header-logo {
    left: 4rem;
}

.close-btn {
    right: 4rem;
}

.time-warning {
    color: #ff4444 !important;
    text-shadow: 0 0 0.625rem rgba(255, 68, 68, 0.8) !important;
    animation: timeBlink 1s ease-in-out infinite;
}

@keyframes timeBlink {
    0%, 100% { opacity: 1; }
    50% { opacity: 0.5; }
}

/* Expiry Content */
.expiry-content {
    padding: 6rem 10rem;
    display: flex;
    gap: 15rem;
    align-items: center;
    justify-content: center;
    height: calc(100% - 210px);
}

.expiry-left {
    flex: 0 0 auto;
    display: flex;
    flex-direction: column;
    align-items: center;
    gap: 2rem;
    transform: translateX(3rem);
}

.turbine-container-expiry {
    position: relative;
    width: 21.875rem;
    height: 21.875rem;
}

/* Outer Rings */
.outer-ring {
    position: absolute;
    top: 50%;
    left: 50%;
    border: 0.0625rem solid rgba(255, 68, 68, 0.3);
    border-radius: 50%;
    animation: ringRotate 20s linear infinite;
}

.ring-1 {
    width: 20rem;
    height: 20rem;
    margin: -10rem 0 0 -10rem;
    border-style: dashed;
}

.ring-2 {
    width: 22.5rem;
    height: 22.5rem;
    margin: -11.25rem 0 0 -11.25rem;
    animation-duration: 30s;
    animation-direction: reverse;
}

.ring-3 {
    width: 25rem;
    height: 25rem;
    margin: -12.5rem 0 0 -12.5rem;
    border-style: dotted;
    animation-duration: 40s;
}

@keyframes ringRotate {
    from { transform: rotate(0deg); }
    to { transform: rotate(360deg); }
}

/* Progress Ring */
.progress-ring {
    position: absolute;
    top: 50%;
    left: 50%;
    transform: translate(-50%, -50%) rotate(-90deg);
}

.progress-ring-bg {
    fill: none;
    stroke: rgba(255, 68, 68, 0.1);
    stroke-width: 6;
}

.progress-ring-circle-expiry {
    fill: none;
    stroke: #ff4444;
    stroke-width: 6;
    stroke-dasharray: 754;
    stroke-dashoffset: 0;
    stroke-linecap: round;
    filter: url(#glow);
}

/* Turbine */
.turbine-wrapper {
    position: absolute;
    top: 50%;
    left: 50%;
    transform: translate(-50%, -50%);
    width: 12.5rem;
    height: 12.5rem;
}

.turbine-center {
    position: absolute;
    top: 50%;
    left: 50%;
    transform: translate(-50%, -50%);
    z-index: 10;
}

.center-core {
    width: 2.5rem;
    height: 2.5rem;
    background: radial-gradient(circle, #ff4444 0%, #cc0000 100%);
    border-radius: 50%;
    box-shadow: 
        0 0 1.25rem rgba(255, 68, 68, 0.8),
        0 0 2.5rem rgba(255, 68, 68, 0.4),
        inset 0 0 1.25rem rgba(255, 255, 255, 0.3);
}

.center-ring {
    position: absolute;
    top: 50%;
    left: 50%;
    width: 3.75rem;
    height: 3.75rem;
    margin: -1.875rem 0 0 -1.875rem;
    border: 0.125rem solid rgba(255, 68, 68, 0.5);
    border-radius: 50%;
}

.blade-container {
    width: 100%;
    height: 100%;
}

.blade-container.stopped {
    animation: none;
}

.blade {
    position: absolute;
    width: 100%;
    height: 100%;
    top: 0;
    left: 0;
}

.blade:nth-child(1) { transform: rotate(0deg); }
.blade:nth-child(2) { transform: rotate(120deg); }
.blade:nth-child(3) { transform: rotate(240deg); }

.blade-inner {
    position: absolute;
    top: 0;
    left: 50%;
    transform: translateX(-50%);
    width: 0;
    height: 0;
    border-left: 0.9375rem solid transparent;
    border-right: 0.9375rem solid transparent;
    border-bottom: 6.25rem solid rgba(255, 68, 68, 0.6);
    filter: drop-shadow(0 0 0.625rem rgba(255, 68, 68, 0.4));
}

.blade-glow {
    position: absolute;
    top: 0;
    left: 50%;
    transform: translateX(-50%);
    width: 1.25rem;
    height: 6.25rem;
    background: linear-gradient(180deg, 
        rgba(255, 68, 68, 0.3) 0%, 
        transparent 100%);
    filter: blur(0.5rem);
}

/* Status Box */
.status-box {
    display: flex;
    padding: 0.625rem 0;
    flex-direction: column;
    justify-content: center;
    align-items: center;
    gap: 1rem;
    align-self: stretch;
    transform: translateY(120px);
}

.status-title {
   font-family: Goldman;
  font-size: 1rem;
  font-style: normal;
  font-weight: 400;
  line-height: normal;
  background: linear-gradient(180deg, #80F0FF 0%, #00C4DD 100%);
  background-clip: text;
  -webkit-background-clip: text;
  -webkit-text-fill-color: transparent;
}

.status-message.offline {
  color: rgba(255, 255, 255, 0.50);
  font-family: Goldman;
  font-size: 1rem;
  font-style: normal;
  font-weight: 400;
  line-height: normal;
  display: flex;
  align-items: center;
  justify-content: center;
  gap: 0.5rem;
}

.red-dot {
  width: 0.75rem;
  height: 0.75rem;
  background: #ff4444;
  border-radius: 50%;
  box-shadow: 0 0 0.625rem rgba(255, 68, 68, 0.8);
  animation: dotBlink 1s ease-in-out infinite;
  flex-shrink: 0;
  align-self: center;
}

@keyframes dotBlink {
  0%, 100% { opacity: 1; }
  50% { opacity: 0.3; }
}

/* Right Section */
.expiry-right {
    flex: 0 0 34rem;
    display: flex;
    flex-direction: column;
    align-items: center;
    gap: 1rem;
    justify-content: center;
    margin-top: 5rem;
    transform: translateX(3.6rem);
}

.withdraw-section {
    display: flex;
    flex-direction: column;
    gap: 2.5rem;
    align-items: center;
    min-width: 25rem;
}

/* Total Income Section (giống MainUI) */
.total-income-section-expiry {
    position: relative;
    text-align: center;
    padding: 9rem 1.5rem;
}

.total-glow {
    position: absolute;
    top: 50%;
    left: 50%;
    transform: translate(-50%, -50%);
    width: 16rem;
    height: 16rem;
    background: radial-gradient(circle, rgba(255, 0, 255, 0.4) 0%, rgba(138, 43, 226, 0.2) 40%, transparent 70%);
    filter: blur(2.5rem);
    z-index: 0;
    animation: glowPulse 3s ease-in-out infinite;
}

@keyframes glowPulse {
    0%, 100% { opacity: 0.6; transform: translate(-50%, -50%) scale(1); }
    50% { opacity: 1; transform: translate(-50%, -50%) scale(1.1); }
}

.total-label {
    margin-bottom: 0.75rem;
    position: relative;
    z-index: 1;
    text-align: center;
    font-family: Goldman;
    font-size: 2.2rem;
    font-style: normal;
    font-weight: 700;
    line-height: normal;
    background: linear-gradient(180deg, #80F0FF 0%, #00C4DD 100%);
    background-clip: text;
    -webkit-background-clip: text;
    -webkit-text-fill-color: transparent;
}

.total-value-wrapper {
    position: relative;
    display: inline-block;
}

.circle-ring {
    position: absolute;
    top: 0%;
    left: 50%;
    transform: translate(-50%, -50%);
    width: 12rem;
    height: 12rem;
    border: 0.25rem solid rgba(138, 43, 226, 0.9);
    border-radius: 50%;
    z-index: 0;
    box-shadow: 
        0 0 1.875rem rgba(138, 43, 226, 1),
        0 0 3.75rem rgba(138, 43, 226, 0.8),
        0 0 5.625rem rgba(138, 43, 226, 0.6),
        inset 0 0 1.875rem rgba(138, 43, 226, 0.6),
        inset 0 0 3.75rem rgba(138, 43, 226, 0.4);
    animation: circleRotate 8s linear infinite, circlePulse 2s ease-in-out infinite;
}

@keyframes circleRotate {
    from { transform: translate(-50%, -50%) rotate(0deg); }
    to { transform: translate(-50%, -50%) rotate(360deg); }
}

@keyframes circlePulse {
    0%, 100% { 
        box-shadow: 
            0 0 1.875rem rgba(138, 43, 226, 1),
            0 0 3.75rem rgba(138, 43, 226, 0.8),
            0 0 5.625rem rgba(138, 43, 226, 0.6),
            inset 0 0 1.875rem rgba(138, 43, 226, 0.6),
            inset 0 0 3.75rem rgba(138, 43, 226, 0.4);
    }
    50% { 
        box-shadow: 
            0 0 2.5rem rgba(138, 43, 226, 1),
            0 0 5rem rgba(138, 43, 226, 1),
            0 0 7.5rem rgba(138, 43, 226, 0.8),
            inset 0 0 2.5rem rgba(138, 43, 226, 0.8),
            inset 0 0 5rem rgba(138, 43, 226, 0.6);
    }
}

.total-value {
    position: relative;
    z-index: 1;
    text-align: center;
    text-shadow: 0 0 1.9px #4CBA6F;
    font-family: Goldman;
    font-size: 3.2rem;
    font-style: normal;
    font-weight: 700;
    line-height: normal;
    }

/* Warning Time Box */
.warning-time-box {
    display: flex;
    flex-direction: column;
    justify-content: center;
    align-items: center;
    gap: 0.625rem;
    transform: translateY(5px);
}

.warning-time-label {
    font-family: Goldman;
    font-size: 1rem;
    font-style: normal;
    font-weight: 400;
    line-height: normal;
}

.warning-time-value {
    font-size: 1rem;
    font-weight: 900;
    color: #ff4444;
    text-shadow: 0 0 1.25rem rgba(255, 68, 68, 0.8);
    animation: timeBlink 1s ease-in-out infinite;
}

/* Withdraw Button */
.btn-withdraw-expiry {
    cursor: pointer;
    font-family: 'Goldman';
    min-width: 18rem;
    display: flex;
    padding: 2rem 4.5rem;
    justify-content: center;
    align-items: center;
    gap: 0.625rem;
    border-radius: 0.625rem;
    border: 1px solid var(--FECD08, #FECD08);
    background: linear-gradient(0deg, rgba(254, 205, 8, 0.30) 0%, rgba(152, 123, 5, 0.00) 100%);
    color: var(--FECD08, #FECD08);
    font-family: Goldman;
    font-size: 2.5rem;
    font-style: normal;
    font-weight: 700;
    line-height: normal;
    transform: translateY(13px);
}

.btn-withdraw-expiry .btn-icon-img {
   width: 1.9375rem;
   height: 1.75rem;
   aspect-ratio: 31/28;
   fill: var(--FECD08, #FECD08);
}

.btn-withdraw-expiry:hover {
    background: rgba(255, 170, 0, 0.2);
    box-shadow: 0 0 2.5rem rgba(255, 170, 0, 0.8);
    transform: translateY(-0.125rem);
}
</style>
