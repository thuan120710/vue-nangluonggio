<template>
  <div class="main-wrapper">
    <div class="background-image"></div>
    <div class="container">
      <div class="bg-grid"></div>
      
      <!-- Header -->
      <div class="header">
        <div class="header-logo">
          <img src="/img/f17.png" alt="F17 Logo" class="logo-image">
        </div>
        
        <div class="header-center">
          <h1>TRẠM KHAI THÁC ĐIỆN GIÓ</h1>
        </div>
        
        <button class="close-btn" @click="handleClose">
          ✕
        </button>
      </div>

      <!-- Content -->
      <div class="rental-content-wrapper">
        <!-- Left: Hướng dẫn -->
        <div class="rental-left-panel">
          <div class="panel-title">HƯỚNG DẪN</div>
          <div class="rental-info-box">
            <ul class="feature-list">
              <li>• Đây là hoạt động mang lại thu nhập thụ động cho cộng đồng.</li>
              <li>• Trạm điện gió có thể hoạt động liên tục tối đa 12 giờ/ngày, sau đó cần bảo trì để tiếp tục vận hành.</li>
              <li>• Thời gian kết thúc kỳ của toàn bộ các trạm điện gió là <span class="highlight">6 GIỜ SÁNG</span> mỗi ngày.</li>
              <li>• Thu nhập sẽ dao động theo hiệu suất vận hành thực tế. <span class="highlight1">Công dân cần theo dõi sửa chữa chỉ số định kỳ để duy trì hiệu suất tối đa.</span></li>
              <li>• Công dân có thể rút tiền bất kỳ lúc nào.</li>
              <li>• <span class="highlight1">Sau 168h kể từ khi thuê, hệ thống sẽ tự động kết thúc hợp đồng thuê,<span class="highlight">công dân có thêm 4h để rút tiền</span> nếu vẫn còn số dư trong máy.</span></li>
            </ul>
          </div>
        </div>

        <!-- Center: Turbine -->
        <div class="rental-center">
          <div class="turbine-section-rental">
            <div class="turbine-container-rental">
              <!-- Outer Rings -->
              <div class="outer-ring ring-1"></div>
              <div class="outer-ring ring-2"></div>
              <div class="outer-ring ring-3"></div>
              
              <!-- Progress Ring -->
              <svg class="progress-ring" width="280" height="280">
                <defs>
                  <linearGradient id="progressGradient" x1="0%" y1="0%" x2="100%" y2="100%">
                    <stop offset="0%" style="stop-color:#00ffff;stop-opacity:1" />
                    <stop offset="100%" style="stop-color:#00ff88;stop-opacity:1" />
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
                  class="progress-ring-circle" 
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
                <div class="blade-container">
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
          </div>
          
          <button 
            v-if="!isRented" 
            class="btn btn-rent" 
            @click="handleRent"
          >
            THUÊ TRẠM - ${{ formatMoney(rentalPrice) }} IC
          </button>
          
          <div v-else class="rented-status">
            <div class="status-icon">🔒</div>
            <div class="status-text">ĐÃ ĐƯỢC THUÊ</div>
          </div>
        </div>

        <!-- Right: Thông tin -->
        <div class="rental-right-panel">
          <div class="panel-title">THÔNG TIN</div>
          
          <div class="info-card-rental">
            <div class="info-icon-rental">
              <img src="/img/tien.png" alt="Giá Thuê" class="info-icon-img">
            </div>
            <div class="info-label-rental">Giá Thuê</div>
            <div class="info-value-rental">${{ formatMoney(rentalPrice) }} IC</div>
          </div>

          <div class="info-card-rental">
            <div class="info-icon-rental">
              <img src="/img/dongho.png" alt="Thời Hạn" class="info-icon-img">
            </div>
            <div class="info-label-rental">Thời Hạn</div>
            <div class="info-value-rental">7 NGÀY</div>
          </div>

          <div class="info-card-rental">
            <div class="info-icon-rental">
              <img src="/img/thunhap.png" alt="Thu Nhập" class="info-icon-img">
            </div>
            <div class="info-label-rental">Thu Nhập</div>
            <div class="info-value-rental">lên tới 5,000 IC / GIỜ</div>
          </div>

          <div v-if="isRented" class="owner-info">
            <div class="owner-label">Chủ sở hữu:</div>
            <div class="owner-name">{{ ownerName }}</div>
            <div v-if="expiryTime" class="expiry-time">
              Hết hạn: {{ formatExpiryTime(expiryTime) }}
            </div>
          </div>
        </div>
      </div>
    </div>
  </div>
</template>

<script>
export default {
  name: 'RentalUI',
  props: {
    isRented: {
      type: Boolean,
      default: false
    },
    isOwner: {
      type: Boolean,
      default: false
    },
    ownerName: {
      type: String,
      default: 'N/A'
    },
    expiryTime: {
      type: Number,
      default: null
    },
    rentalPrice: {
      type: Number,
      default: 50000
    }
  },
  emits: ['rent', 'close'],
  methods: {
    handleRent() {
      this.$emit('rent')
    },
    handleClose() {
      this.$emit('close')
    },
    formatMoney(value) {
      return value.toString().replace(/\B(?=(\d{3})+(?!\d))/g, ',')
    },
    formatExpiryTime(timestamp) {
      const date = new Date(timestamp * 1000)
      return date.toLocaleString('vi-VN', {
        year: 'numeric',
        month: '2-digit',
        day: '2-digit',
        hour: '2-digit',
        minute: '2-digit'
      })
    }
  }
}
</script>


<style scoped>
/* Header override for Rental UI */
.header {
    margin-top: 1rem;
    padding-left: 2.5rem;
    padding-right: 2.5rem;
}

.header-logo {
    left: 3.5rem;
}

.close-btn {
    right: 3.5rem;
}

/* Rental UI Styles */
.rental-content-wrapper {
    padding: 6.125rem 5.25rem;
    display: flex;
    gap: 3.125rem;
    align-items: flex-start;
    justify-content: space-between;
    height: calc(100% - 150px);
}

.rental-left-panel {
    flex: 0 0 23rem;
    display: flex;
    flex-direction: column;
}

.rental-right-panel {
    flex: 0 0 23rem;
    display: flex;
    flex-direction: column;
    margin: 0 3px;
}

.panel-title {
    letter-spacing: 0.1875rem;
    background: linear-gradient(180deg, #80F0FF 0%, #00C4DD 100%);
    -webkit-background-clip: text;
    -webkit-text-fill-color: transparent;
    text-shadow: 0 0 0.9375rem rgba(0, 255, 255, 0.8);
    text-align: center;
    margin-bottom: 1.25rem;
    font-family: Goldman;
    font-size: 1.25rem;
    font-style: normal;
    font-weight: 700;
    line-height: normal;
}

.rental-info-box {
    background: rgba(0, 255, 255, 0.05);
    border: 0.125rem solid rgba(0, 255, 255, 0.3);
    border-radius: 0.9375rem;
    padding: 1.8rem;
    background: #5D5D5F4D;
    line-height: normal;
    color: #FFF;
    font-family: "Baloo 2";
    font-size: 0.875rem;
    font-style: normal;
    font-weight: 400;
    line-height: normal;

}

.feature-list {
    list-style: none;
    padding: 0;
    margin: 0;
}

.feature-list li {
    color: rgba(255, 255, 255, 0.8);
    padding: 0.5rem 0;
    font-size: 0.9825rem;
    line-height: 1.6;
    letter-spacing: 0.03125rem;
    font-family: 'Baloo 2', cursive;
}

.feature-list .highlight {
    color: #ffaa00;
    font-weight: 700;
}
.feature-list .highlight1 {
    color: #ffffff;
    font-weight: 700;
}

.rental-center {
    flex: 1;
    display: flex;
    flex-direction: column;
    align-items: center;
    justify-content: center;
    gap: 7.5rem;
    margin-top: 4.125rem;
}

.turbine-section-rental {
    flex: 0 0 21.875rem;
}

.turbine-container-rental {
    position: relative;
    width: 21.875rem;
    height: 21.875rem;
    margin: 0 auto;
}

/* Outer Rings */
.outer-ring {
    position: absolute;
    top: 50%;
    left: 50%;
    border: 0.0625rem solid rgba(0, 255, 255, 0.2);
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
    stroke: rgba(0, 255, 255, 0.1);
    stroke-width: 6;
}

.progress-ring-circle {
    fill: none;
    stroke: url(#progressGradient);
    stroke-width: 6;
    stroke-dasharray: 754;
    stroke-dashoffset: 0;
    stroke-linecap: round;
    filter: url(#glow);
    transition: stroke-dashoffset 0.5s ease;
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
    background: radial-gradient(circle, #00ffff 0%, #0088ff 100%);
    border-radius: 50%;
    box-shadow: 
        0 0 1.25rem rgba(0, 255, 255, 0.8),
        0 0 2.5rem rgba(0, 255, 255, 0.4),
        inset 0 0 1.25rem rgba(255, 255, 255, 0.3);
    animation: corePulse 2s ease-in-out infinite;
}

@keyframes corePulse {
    0%, 100% { transform: scale(1); box-shadow: 0 0 1.25rem rgba(0, 255, 255, 0.8); }
    50% { transform: scale(1.1); box-shadow: 0 0 2.5rem rgba(0, 255, 255, 1); }
}

.center-ring {
    position: absolute;
    top: 50%;
    left: 50%;
    width: 3.75rem;
    height: 3.75rem;
    margin: -1.875rem 0 0 -1.875rem;
    border: 0.125rem solid rgba(0, 255, 255, 0.5);
    border-radius: 50%;
    animation: ringPulse 2s ease-in-out infinite;
}

@keyframes ringPulse {
    0%, 100% { transform: scale(1); opacity: 1; }
    50% { transform: scale(1.2); opacity: 0.5; }
}

.blade-container {
    width: 100%;
    height: 100%;
    animation: bladeRotate 3s linear infinite;
}

@keyframes bladeRotate {
    from { transform: rotate(0deg); }
    to { transform: rotate(360deg); }
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
    border-bottom: 6.25rem solid rgba(0, 255, 255, 0.8);
    filter: drop-shadow(0 0 0.625rem rgba(0, 255, 255, 0.6));
}

.blade-glow {
    position: absolute;
    top: 0;
    left: 50%;
    transform: translateX(-50%);
    width: 1.25rem;
    height: 6.25rem;
    background: linear-gradient(180deg, 
        rgba(0, 255, 255, 0.4) 0%, 
        transparent 100%);
    filter: blur(0.5rem);
}

.btn-rent {
    background: linear-gradient(180deg, rgba(0, 255, 81, 0) 0%, rgba(0, 255, 81, 0.5) 100%);
    border: 0.125rem solid #00ff51;
    border-radius: 0.9375rem;
    color: #00ff51;
    padding: 1.25rem 3.125rem;
    letter-spacing: 0.125rem;
    cursor: pointer;
    transition: all 0.3s;
    text-transform: uppercase;
    color: #00FF51;
    font-family: Goldman;
    font-size: 1.25rem;
    font-style: normal;
    font-weight: 700;
    line-height: normal;
}

.btn-rent:hover {
    background: rgba(0, 255, 136, 0.2);
    box-shadow: 0 0 1.875rem rgba(0, 255, 136, 0.6);
    transform: translateY(-0.125rem);
}

.rented-status {
    display: flex;
    align-items: center;
    gap: 0.9375rem;
    padding: 1.25rem 2.5rem;
    background: rgba(255, 68, 68, 0.1);
    border: 0.125rem solid rgba(255, 68, 68, 0.5);
    border-radius: 0.9375rem;
}

.rented-status .status-icon {
    font-size: 2rem;
}

.rented-status .status-text {
    font-size: 1.25rem;
    font-weight: 700;
    color: #ff4444;
    letter-spacing: 0.125rem;
}

.info-card-rental {
    background: rgba(0, 255, 255, 0.05);
    border: 0.125rem solid rgba(0, 255, 255, 0.3);
    border-radius: 0.9375rem;
    padding: 1.1rem 1.25rem;
    display: flex;
    flex-direction: column;
    align-items: center;
    justify-content: center;
    gap: 0.625rem;
    transition: all 0.3s;
    text-align: center;
    min-height: 11rem;
    background: #5D5D5F4D;
    margin-bottom: 1rem;
}

.info-card-rental:hover {
    background: rgba(0, 255, 255, 0.1);
    border-color: rgba(0, 255, 255, 0.5);
    transform: translateY(-0.125rem);
}

.info-icon-rental {
    font-size: 1.25rem;
    margin-bottom: 0.625rem;
    display: flex;
    align-items: center;
    justify-content: center;
}

.info-icon-img {
    width: 2rem;
    height: 2rem;
    object-fit: contain;
    filter: drop-shadow(0 0 0.625rem rgba(0, 255, 255, 0.6));
}

.info-label-rental {
    color: rgba(255, 255, 255, 0.8);
    letter-spacing: 0.0625rem;
    margin-bottom: 0.3125rem;
    color: #FFF;
    font-family: Goldman;
    font-size: 1.25rem;
    font-style: normal;
    font-weight: 400;
    line-height: normal;
}

.info-value-rental {
    font-size: 1.25rem;
    letter-spacing: 0.0625rem;
    line-height: 1.4;
    color: #00FF51;
    font-family: Goldman;
    font-size: 1.25rem;
    font-style: normal;
    font-weight: 700;
    line-height: normal;
}

.owner-info {
    background: rgba(255, 170, 0, 0.1);
    border: 0.125rem solid rgba(255, 170, 0, 0.3);
    border-radius: 0.9375rem;
    padding: 1.25rem;
    margin-top: 1.25rem;
}

.owner-label {
    font-size: 0.875rem;
    color: rgba(255, 170, 0, 0.6);
    margin-bottom: 0.3125rem;
}

.owner-name {
    font-size: 1.125rem;
    font-weight: 700;
    color: #ffaa00;
    text-shadow: 0 0 0.625rem rgba(255, 170, 0, 0.6);
    margin-bottom: 0.625rem;
}

.expiry-time {
    font-size: 0.8125rem;
    color: rgba(255, 255, 255, 0.7);
}
</style>
