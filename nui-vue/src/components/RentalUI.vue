<template>
  <div class="rental-overlay">
    <div class="rental-container">
      <!-- Close Button -->
      <button class="close-btn" @click="handleClose">
        <span>✕</span>
      </button>
      
      <!-- Header -->
      <div class="rental-header">
        <div class="header-icon">🌬️</div>
        <h1>Trạm Điện Gió</h1>
        <p class="subtitle">Hệ thống năng lượng tái tạo</p>
      </div>

      <!-- Content -->
      <div class="rental-content">
        <!-- Thông tin trạm -->
        <div class="info-section">
          <div class="info-card">
            <div class="info-icon">💰</div>
            <div class="info-details">
              <span class="info-label">Giá thuê</span>
              <span class="info-value">${{ formatMoney(rentalPrice) }} IC</span>
            </div>
          </div>

          <div class="info-card">
            <div class="info-icon">⏰</div>
            <div class="info-details">
              <span class="info-label">Thời hạn</span>
              <span class="info-value">7 ngày</span>
            </div>
          </div>

          <div class="info-card">
            <div class="info-icon">💵</div>
            <div class="info-details">
              <span class="info-label">Thu nhập dự kiến</span>
              <span class="info-value">~5,000 IC/giờ</span>
            </div>
          </div>
        </div>

        <!-- Mô tả -->
        <div class="description-section">
          <h3>📋 Thông tin chi tiết</h3>
          <ul class="feature-list">
            <li>✅ Làm việc tối đa 12 giờ/ngày, 84 giờ/tuần</li>
            <li>✅ Thu nhập dựa trên hiệu suất hệ thống</li>
            <li>✅ Cần bảo trì định kỳ để duy trì hiệu suất</li>
            <li>✅ Tự động reset sau khi hết hạn thuê</li>
            <li>⚠️ Sau 7 ngày cần thuê lại để tiếp tục</li>
          </ul>
        </div>

        <!-- Trạng thái -->
        <div v-if="isRented" class="status-section rented">
          <div class="status-icon">🔒</div>
          <div class="status-text">
            <h3>Trạm đã được thuê</h3>
            <p>Chủ sở hữu: <strong>{{ ownerName }}</strong></p>
            <p v-if="expiryTime" class="expiry-time">
              Hết hạn: {{ formatExpiryTime(expiryTime) }}
            </p>
          </div>
        </div>

        <div v-else class="status-section available">
          <div class="status-icon">✅</div>
          <div class="status-text">
            <h3>Trạm có sẵn</h3>
            <p>Bạn có thể thuê trạm này ngay bây giờ</p>
          </div>
        </div>
      </div>

      <!-- Actions -->
      <div class="rental-actions">
        <button 
          v-if="!isRented" 
          class="btn btn-rent" 
          @click="handleRent"
        >
          <span class="btn-icon">💰</span>
          <span>Thuê trạm - ${{ formatMoney(rentalPrice) }} IC</span>
        </button>

        <button 
          v-else 
          class="btn btn-close" 
          @click="handleClose"
        >
          <span class="btn-icon">❌</span>
          <span>Đóng</span>
        </button>
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
      default: null
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
.rental-overlay {
  position: fixed;
  top: 0;
  left: 0;
  width: 100vw;
  height: 100vh;
  background: rgba(0, 0, 0, 0.85);
  display: flex;
  justify-content: center;
  align-items: center;
  z-index: 1000;
  animation: fadeIn 0.3s ease;
}

@keyframes fadeIn {
  from {
    opacity: 0;
  }
  to {
    opacity: 1;
  }
}

.rental-container {
  background: linear-gradient(135deg, #1a1a2e 0%, #16213e 100%);
  border-radius: 20px;
  padding: 30px;
  max-width: 600px;
  width: 90%;
  box-shadow: 0 20px 60px rgba(0, 0, 0, 0.5);
  animation: slideUp 0.4s ease;
  position: relative;
}

.close-btn {
  position: absolute;
  top: 15px;
  right: 15px;
  width: 40px;
  height: 40px;
  border: none;
  background: rgba(255, 255, 255, 0.1);
  border-radius: 50%;
  color: #fff;
  font-size: 24px;
  cursor: pointer;
  display: flex;
  align-items: center;
  justify-content: center;
  transition: all 0.3s ease;
  z-index: 10;
}

.close-btn:hover {
  background: rgba(255, 68, 68, 0.8);
  transform: rotate(90deg);
}

@keyframes slideUp {
  from {
    transform: translateY(50px);
    opacity: 0;
  }
  to {
    transform: translateY(0);
    opacity: 1;
  }
}

.rental-header {
  text-align: center;
  margin-bottom: 30px;
  padding-bottom: 20px;
  border-bottom: 2px solid rgba(255, 255, 255, 0.1);
}

.header-icon {
  font-size: 60px;
  margin-bottom: 10px;
  animation: rotate 3s linear infinite;
}

@keyframes rotate {
  from {
    transform: rotate(0deg);
  }
  to {
    transform: rotate(360deg);
  }
}

.rental-header h1 {
  font-size: 32px;
  color: #00ff88;
  margin: 10px 0;
  text-shadow: 0 0 20px rgba(0, 255, 136, 0.5);
}

.subtitle {
  color: rgba(255, 255, 255, 0.6);
  font-size: 14px;
}

.rental-content {
  margin-bottom: 25px;
}

.info-section {
  display: grid;
  grid-template-columns: repeat(auto-fit, minmax(150px, 1fr));
  gap: 15px;
  margin-bottom: 25px;
}

.info-card {
  background: rgba(255, 255, 255, 0.05);
  border: 1px solid rgba(255, 255, 255, 0.1);
  border-radius: 12px;
  padding: 15px;
  display: flex;
  align-items: center;
  gap: 12px;
  transition: all 0.3s ease;
}

.info-card:hover {
  background: rgba(255, 255, 255, 0.08);
  transform: translateY(-2px);
}

.info-icon {
  font-size: 28px;
}

.info-details {
  display: flex;
  flex-direction: column;
}

.info-label {
  font-size: 12px;
  color: rgba(255, 255, 255, 0.5);
  margin-bottom: 4px;
}

.info-value {
  font-size: 16px;
  font-weight: bold;
  color: #00ff88;
}

.description-section {
  background: rgba(255, 255, 255, 0.03);
  border-radius: 12px;
  padding: 20px;
  margin-bottom: 20px;
}

.description-section h3 {
  color: #00ff88;
  margin-bottom: 15px;
  font-size: 18px;
}

.feature-list {
  list-style: none;
  padding: 0;
  margin: 0;
}

.feature-list li {
  color: rgba(255, 255, 255, 0.8);
  padding: 8px 0;
  font-size: 14px;
  line-height: 1.6;
}

.status-section {
  background: rgba(255, 255, 255, 0.05);
  border-radius: 12px;
  padding: 20px;
  display: flex;
  align-items: center;
  gap: 15px;
  border: 2px solid;
}

.status-section.available {
  border-color: #00ff88;
  background: rgba(0, 255, 136, 0.1);
}

.status-section.rented {
  border-color: #ff4444;
  background: rgba(255, 68, 68, 0.1);
}

.status-icon {
  font-size: 40px;
}

.status-text h3 {
  margin: 0 0 8px 0;
  font-size: 18px;
  color: #fff;
}

.status-text p {
  margin: 4px 0;
  color: rgba(255, 255, 255, 0.7);
  font-size: 14px;
}

.expiry-time {
  color: #ffaa00 !important;
  font-weight: bold;
}

.rental-actions {
  display: flex;
  gap: 15px;
}

.btn {
  flex: 1;
  padding: 15px 25px;
  border: none;
  border-radius: 12px;
  font-size: 16px;
  font-weight: bold;
  cursor: pointer;
  display: flex;
  align-items: center;
  justify-content: center;
  gap: 10px;
  transition: all 0.3s ease;
}

.btn-icon {
  font-size: 20px;
}

.btn-rent {
  background: linear-gradient(135deg, #00ff88 0%, #00cc6a 100%);
  color: #000;
  box-shadow: 0 5px 20px rgba(0, 255, 136, 0.3);
}

.btn-rent:hover {
  transform: translateY(-2px);
  box-shadow: 0 8px 30px rgba(0, 255, 136, 0.5);
}

.btn-close {
  background: rgba(255, 255, 255, 0.1);
  color: #fff;
  border: 1px solid rgba(255, 255, 255, 0.2);
}

.btn-close:hover {
  background: rgba(255, 255, 255, 0.15);
}
</style>
