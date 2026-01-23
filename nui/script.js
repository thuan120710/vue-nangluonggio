let currentSystems = {};
let currentEfficiency = 0;
let currentEarnings = 0;
let minigameActive = false;
let minigameData = {};
let indicatorPosition = 0;
let indicatorDirection = 1;
let currentRound = 0;
let totalRounds = 1;
let isOnDuty = false; // Track duty status
let workLimitReached = false; // Track if work limit has been reached

// Fan minigame variables
let fanMinigameActive = false;
let fanPhase = 1; // 1: Tighten bolts, 2: Rotate fan
let boltsTightened = 0;
let rotationProgress = 0;
let lastMouseAngle = 0;
let mouseTracking = false;

// Circuit breaker minigame variables
let circuitBreakerActive = false;
let breakers = []; // Array of breaker states: {id, status: 'green'|'red'|'yellow', clicksNeeded, clicksDone}

// Crack repair minigame variables
let crackRepairActive = false;
let cracks = []; // Array of crack objects: {id, x, y, width, height, repairProgress, isRepaired}
let trowelActive = false;

// Utility: Post message to client
function post(action, data = {}) {
    fetch(`https://${GetParentResourceName()}/${action}`, {
        method: 'POST',
        headers: { 'Content-Type': 'application/json' },
        body: JSON.stringify(data)
    });
}

// Utility: Play sound effect
function playSound(soundName) {
    const audio = new Audio();
    
    // Map sound names to audio files or use Web Audio API
    const sounds = {
        'click': 'data:audio/wav;base64,UklGRnoGAABXQVZFZm10IBAAAAABAAEAQB8AAEAfAAABAAgAZGF0YQoGAACBhYqFbF1fdJivrJBhNjVgodDbq2EcBj+a2/LDciUFLIHO8tiJNwgZaLvt559NEAxQp+PwtmMcBjiR1/LMeSwFJHfH8N2QQAoUXrTp66hVFApGn+DyvmwhBSuBzvLZiTYIGGe77OeeSwwPUKXi8LdjHAU7k9jyz3ksBS1+zPDdkUALFGC36+uoVRQKRp/g8r5sIQUrgc7y2Yk2CBhnu+znk0sMD1Cl4vC3YxwFO5PY8s95LAUtfsz',
        'success': 'data:audio/wav;base64,UklGRnoGAABXQVZFZm10IBAAAAABAAEAQB8AAEAfAAABAAgAZGF0YQoGAACBhYqFbF1fdJivrJBhNjVgodDbq2EcBj+a2/LDciUFLIHO8tiJNwgZaLvt559NEAxQp+PwtmMcBjiR1/LMeSwFJHfH8N2QQAoUXrTp66hVFApGn+DyvmwhBSuBzvLZiTYIGGe77OeeSwwPUKXi8LdjHAU7k9jyz3ksBS1+zPDdkUALFGC36+uoVRQKRp/g8r5sIQUrgc7y2Yk2CBhnu+znk0sMD1Cl4vC3YxwFO5PY8s95LAUtfsz',
        'fail': 'data:audio/wav;base64,UklGRnoGAABXQVZFZm10IBAAAAABAAEAQB8AAEAfAAABAAgAZGF0YQoGAACBhYqFbF1fdJivrJBhNjVgodDbq2EcBj+a2/LDciUFLIHO8tiJNwgZaLvt559NEAxQp+PwtmMcBjiR1/LMeSwFJHfH8N2QQAoUXrTp66hVFApGn+DyvmwhBSuBzvLZiTYIGGe77OeeSwwPUKXi8LdjHAU7k9jyz3ksBS1+zPDdkUALFGC36+uoVRQKRp/g8r5sIQUrgc7y2Yk2CBhnu+znk0sMD1Cl4vC3YxwFO5PY8s95LAUtfsz',
        'repair': 'data:audio/wav;base64,UklGRnoGAABXQVZFZm10IBAAAAABAAEAQB8AAEAfAAABAAgAZGF0YQoGAACBhYqFbF1fdJivrJBhNjVgodDbq2EcBj+a2/LDciUFLIHO8tiJNwgZaLvt559NEAxQp+PwtmMcBjiR1/LMeSwFJHfH8N2QQAoUXrTp66hVFApGn+DyvmwhBSuBzvLZiTYIGGe77OeeSwwPUKXi8LdjHAU7k9jyz3ksBS1+zPDdkUALFGC36+uoVRQKRp/g8r5sIQUrgc7y2Yk2CBhnu+znk0sMD1Cl4vC3YxwFO5PY8s95LAUtfsz'
    };
    
    // For now, we'll use a simple beep sound
    // In production, you would load actual sound files
    const audioContext = new (window.AudioContext || window.webkitAudioContext)();
    const oscillator = audioContext.createOscillator();
    const gainNode = audioContext.createGain();
    
    oscillator.connect(gainNode);
    gainNode.connect(audioContext.destination);
    
    // Different frequencies for different sounds
    if (soundName === 'success') {
        oscillator.frequency.value = 800;
        gainNode.gain.setValueAtTime(0.3, audioContext.currentTime);
        gainNode.gain.exponentialRampToValueAtTime(0.01, audioContext.currentTime + 0.3);
        oscillator.start(audioContext.currentTime);
        oscillator.stop(audioContext.currentTime + 0.3);
    } else if (soundName === 'fail') {
        oscillator.frequency.value = 200;
        gainNode.gain.setValueAtTime(0.3, audioContext.currentTime);
        gainNode.gain.exponentialRampToValueAtTime(0.01, audioContext.currentTime + 0.2);
        oscillator.start(audioContext.currentTime);
        oscillator.stop(audioContext.currentTime + 0.2);
    } else if (soundName === 'click') {
        oscillator.frequency.value = 600;
        gainNode.gain.setValueAtTime(0.2, audioContext.currentTime);
        gainNode.gain.exponentialRampToValueAtTime(0.01, audioContext.currentTime + 0.1);
        oscillator.start(audioContext.currentTime);
        oscillator.stop(audioContext.currentTime + 0.1);
    } else if (soundName === 'repair') {
        oscillator.frequency.value = 400;
        gainNode.gain.setValueAtTime(0.15, audioContext.currentTime);
        gainNode.gain.exponentialRampToValueAtTime(0.01, audioContext.currentTime + 0.15);
        oscillator.start(audioContext.currentTime);
        oscillator.stop(audioContext.currentTime + 0.15);
    }
}

// Show/Hide UIs
function showMainUI() {
    document.getElementById('mainUI').classList.remove('hidden');
    document.getElementById('minigameUI').classList.add('hidden');
    document.getElementById('earningsUI').classList.add('hidden');
    
    // Update disabled state của systems dựa trên isOnDuty
    document.querySelectorAll('.system-item').forEach(item => {
        if (isOnDuty) {
            item.classList.remove('disabled');
        } else {
            item.classList.add('disabled');
        }
    });
}

function showMinigameUI() {
    document.getElementById('mainUI').classList.add('hidden');
    document.getElementById('minigameUI').classList.remove('hidden');
    document.getElementById('earningsUI').classList.add('hidden');
    document.getElementById('fanMinigameUI').classList.add('hidden');
}

function showFanMinigameUI() {
    document.getElementById('mainUI').classList.add('hidden');
    document.getElementById('minigameUI').classList.add('hidden');
    document.getElementById('earningsUI').classList.add('hidden');
    document.getElementById('fanMinigameUI').classList.remove('hidden');
    document.getElementById('circuitBreakerUI').classList.add('hidden');
}

function showCircuitBreakerUI() {
    document.getElementById('mainUI').classList.add('hidden');
    document.getElementById('minigameUI').classList.add('hidden');
    document.getElementById('earningsUI').classList.add('hidden');
    document.getElementById('fanMinigameUI').classList.add('hidden');
    document.getElementById('circuitBreakerUI').classList.remove('hidden');
    document.getElementById('crackRepairUI').classList.add('hidden');
}

function showCrackRepairUI() {
    document.getElementById('mainUI').classList.add('hidden');
    document.getElementById('minigameUI').classList.add('hidden');
    document.getElementById('earningsUI').classList.add('hidden');
    document.getElementById('fanMinigameUI').classList.add('hidden');
    document.getElementById('circuitBreakerUI').classList.add('hidden');
    document.getElementById('crackRepairUI').classList.remove('hidden');
}

function showEarningsUI() {
    document.getElementById('mainUI').classList.add('hidden');
    document.getElementById('minigameUI').classList.add('hidden');
    document.getElementById('earningsUI').classList.remove('hidden');
}

function hideAllUIs() {
    document.getElementById('mainUI').classList.add('hidden');
    document.getElementById('minigameUI').classList.add('hidden');
    document.getElementById('earningsUI').classList.add('hidden');
    document.getElementById('fanMinigameUI').classList.add('hidden');
    document.getElementById('circuitBreakerUI').classList.add('hidden');
    document.getElementById('crackRepairUI').classList.add('hidden');
}

// Update systems display
function updateSystemsDisplay(systems) {
    currentSystems = systems;
    
    for (const [system, value] of Object.entries(systems)) {
        const valueElement = document.querySelector(`.system-value[data-system="${system}"]`);
        const progressElement = document.querySelector(`.circle-progress[data-system="${system}"]`);
        const statusElement = document.querySelector(`.system-item[data-system="${system}"] .system-status`);
        
        if (valueElement) {
            const numValue = Math.floor(value);
            valueElement.innerHTML = numValue + '<span class="percent">%</span>';
        }
        
        if (progressElement) {
            const circumference = 314;
            const offset = circumference - (value / 100) * circumference;
            progressElement.style.strokeDashoffset = offset;
        }
        
        if (statusElement) {
            if (value < 30) {
                statusElement.textContent = 'CRITICAL';
                statusElement.style.color = '#ff4444';
            } else if (value < 50) {
                statusElement.textContent = 'WARNING';
                statusElement.style.color = '#ffaa00';
            } else {
                statusElement.textContent = 'OPERATIONAL';
                statusElement.style.color = 'rgba(0, 255, 136, 0.6)';
            }
        }
    }
}

// Update efficiency display
function updateEfficiencyDisplay(efficiency) {
    currentEfficiency = efficiency;
    document.getElementById('efficiencyValue').textContent = Math.floor(efficiency);
    
    // Update turbine speed - CHỈ khi đang onDuty
    const turbine = document.querySelector('.blade-container');
    if (turbine && isOnDuty) {
        if (efficiency < 10) {
            // Dừng quạt khi efficiency < 10%
            turbine.classList.add('stopped');
        } else {
            // Xoay quạt khi efficiency >= 10%
            turbine.classList.remove('stopped');
            const speed = 10 - (efficiency / 100) * 7; // 3s to 10s
            turbine.style.animationDuration = speed + 's';
        }
    }
    // Nếu không onDuty, không update turbine (giữ nguyên stopped)
    
    // Update earning rate
    // Tính dựa trên hiệu suất thực tế (efficiency = trung bình 5 chỉ số)
    // Nhưng lợi nhuận thực tế phụ thuộc vào từng chỉ số riêng biệt
    // Để đơn giản, hiển thị theo efficiency (gần đúng)
    const basePerHour = 5000; // IC/giờ (tối đa)
    const earningRatePerHour = basePerHour * (efficiency / 100);
    document.getElementById('earningRate').textContent = Math.floor(earningRatePerHour).toLocaleString();
    
    // Update progress ring
    const progressCircle = document.querySelector('.progress-ring-circle');
    if (progressCircle) {
        const circumference = 754;
        const offset = circumference - (efficiency / 100) * circumference;
        progressCircle.style.strokeDashoffset = offset;
    }
    
    // Update status - CHỈ update khi đang onDuty
    const statusDot = document.querySelector('.status-dot');
    const statusText = document.getElementById('statusText');
    
    if (isOnDuty) {
        // Chỉ update status khi đang làm việc
        if (efficiency > 0) {
            if (statusDot) statusDot.classList.add('online');
            // Giữ nguyên status text nếu đã có work time (ONLINE - Xh/12h)
            if (statusText && statusText.textContent === 'OFFLINE') {
                statusText.textContent = 'ONLINE';
            }
        } else {
            if (statusDot) statusDot.classList.remove('online');
            if (statusText) statusText.textContent = 'OFFLINE';
        }
    }
    // Nếu không onDuty, không update status (giữ nguyên OFFLINE)
}

// Update earnings display
function updateEarningsDisplay(earnings) {
    currentEarnings = earnings;
    document.getElementById('totalEarnings').textContent = Math.floor(earnings).toLocaleString();
}

// Start minigame
function startMinigame(system, title, speed, zoneSize, rounds) {
    // Check if this is stability system - use fan minigame
    if (system === 'stability') {
        startFanMinigame(system);
        return;
    }
    
    // Check if this is electrical system - use circuit breaker minigame
    if (system === 'electric') {
        startCircuitBreakerMinigame(system);
        return;
    }
    
    // Check if this is blades system - use crack repair minigame
    if (system === 'blades') {
        startCrackRepairMinigame(system);
        return;
    }
    
    // Regular bar minigame for other systems
    minigameActive = true;
    minigameData = { system, speed, zoneSize };
    currentRound = 1;
    totalRounds = rounds;
    
    document.getElementById('minigameTitle').textContent = title;
    document.getElementById('currentRound').textContent = currentRound;
    document.getElementById('totalRounds').textContent = totalRounds;
    
    // Setup zone
    const zone = document.getElementById('minigameZone');
    const zoneStart = Math.random() * (1 - zoneSize);
    zone.style.left = (zoneStart * 100) + '%';
    zone.style.width = (zoneSize * 100) + '%';
    
    // Reset indicator
    indicatorPosition = 0;
    indicatorDirection = 1;
    
    showMinigameUI();
    animateIndicator();
}

// Start fan minigame (for stability)
function startFanMinigame(system) {
    fanMinigameActive = true;
    fanPhase = 1;
    boltsTightened = 0;
    rotationProgress = 0;
    minigameData = { system };
    
    // Reset UI
    document.getElementById('boltCount').textContent = '0';
    document.getElementById('rotationProgress').style.width = '0%';
    document.getElementById('rotationValue').textContent = '0';
    document.getElementById('fanPhase1').classList.remove('hidden');
    document.getElementById('fanPhase2').classList.add('hidden');
    
    // Reset bolts
    document.querySelectorAll('.bolt').forEach(bolt => {
        bolt.classList.remove('tightened');
    });
    
    // Change cursor to wrench
    document.body.style.cursor = 'url("data:image/svg+xml;utf8,<svg xmlns=\'http://www.w3.org/2000/svg\' width=\'32\' height=\'32\' viewBox=\'0 0 32 32\'><text y=\'24\' font-size=\'24\'>🔧</text></svg>") 16 16, auto';
    
    showFanMinigameUI();
}

// Animate minigame indicator
function animateIndicator() {
    if (!minigameActive) return;
    
    const indicator = document.getElementById('minigameIndicator');
    indicatorPosition += indicatorDirection * minigameData.speed * 0.01;
    
    if (indicatorPosition >= 1) {
        indicatorPosition = 1;
        indicatorDirection = -1;
    } else if (indicatorPosition <= 0) {
        indicatorPosition = 0;
        indicatorDirection = 1;
    }
    
    indicator.style.left = (indicatorPosition * 100) + '%';
    
    requestAnimationFrame(animateIndicator);
}

// Check minigame result
function checkMinigameResult() {
    if (!minigameActive) return;
    
    const zone = document.getElementById('minigameZone');
    const zoneLeft = parseFloat(zone.style.left) / 100;
    const zoneWidth = parseFloat(zone.style.width) / 100;
    const zoneRight = zoneLeft + zoneWidth;
    
    let result = 'fail';
    
    if (indicatorPosition >= zoneLeft && indicatorPosition <= zoneRight) {
        const zoneCenter = zoneLeft + zoneWidth / 2;
        const distance = Math.abs(indicatorPosition - zoneCenter);
        const perfectThreshold = zoneWidth * 0.2;
        
        if (distance <= perfectThreshold) {
            result = 'perfect';
            playSound('success');
        } else {
            result = 'good';
            playSound('click');
        }
    } else {
        playSound('fail');
    }
    
    minigameActive = false;
    post('minigameResult', {
        system: minigameData.system,
        result: result
    });
}

// Event Listeners
document.getElementById('closeBtn').addEventListener('click', () => {
    post('close');
});

document.getElementById('startDutyBtn').addEventListener('click', () => {
    // Kiểm tra nếu đã đạt giới hạn
    if (workLimitReached) {
        playSound('fail');
        // Thông báo đã được hiển thị từ server
        return;
    }
    
    post('startDuty');
    isOnDuty = true; // Set duty status
    document.getElementById('startDutyBtn').classList.add('hidden');
    document.getElementById('stopDutyBtn').classList.remove('hidden');
    
    const statusDot = document.querySelector('.status-dot');
    const statusText = document.getElementById('statusText');
    if (statusDot) statusDot.classList.add('online');
    if (statusText) statusText.textContent = 'ONLINE';
    
    // Enable systems (cho phép sửa chữa)
    document.querySelectorAll('.system-item').forEach(item => {
        item.classList.remove('disabled');
    });
});

document.getElementById('stopDutyBtn').addEventListener('click', () => {
    isOnDuty = false; // Set duty status to false
    post('stopDuty');
});

document.querySelectorAll('.system-item').forEach(item => {
    item.addEventListener('click', () => {
        // Chỉ cho phép sửa chữa khi đang onDuty
        if (!isOnDuty) {
            // Có thể thêm thông báo hoặc hiệu ứng để báo không được phép
            playSound('fail');
            return;
        }
        
        const system = item.getAttribute('data-system');
        playSound('click');
        post('repair', { system });
    });
});

document.getElementById('turbineContainer').addEventListener('click', () => {
    post('openEarnings');
});

document.getElementById('closeEarningsBtn').addEventListener('click', () => {
    showMainUI();
});

document.getElementById('withdrawBtn').addEventListener('click', () => {
    post('withdrawEarnings');
    showMainUI();
});

document.getElementById('backBtn').addEventListener('click', () => {
    post('backToMain');
});

// Keyboard events for minigame
document.addEventListener('keydown', (e) => {
    if (minigameActive && (e.key === ' ' || e.key === 'e' || e.key === 'E')) {
        e.preventDefault();
        checkMinigameResult();
    }
});

// ESC to close
document.addEventListener('keydown', (e) => {
    if (e.key === 'Escape') {
        post('close');
    }
});

// Message handler from client
window.addEventListener('message', (event) => {
    const data = event.data;
    
    switch (data.action) {
        case 'showMainUI':
            showMainUI();
            if (data.systems) updateSystemsDisplay(data.systems);
            if (data.efficiency !== undefined) updateEfficiencyDisplay(data.efficiency);
            if (data.earnings !== undefined) updateEarningsDisplay(data.earnings);
            
            // Kiểm tra onDuty status từ server
            if (data.onDuty !== undefined) {
                isOnDuty = data.onDuty;
                
                // Update UI dựa trên onDuty status
                if (isOnDuty) {
                    document.getElementById('startDutyBtn').classList.add('hidden');
                    document.getElementById('stopDutyBtn').classList.remove('hidden');
                } else {
                    document.getElementById('stopDutyBtn').classList.add('hidden');
                    document.getElementById('startDutyBtn').classList.remove('hidden');
                }
            }
            break;
            
        case 'hideUI':
            hideAllUIs();
            break;
            
        case 'showMinigame':
            startMinigame(data.system, data.title, data.speed, data.zoneSize, data.rounds);
            break;
            
        case 'showEarningsUI':
            showEarningsUI();
            if (data.earnings !== undefined) {
                document.getElementById('totalEarnings').textContent = Math.floor(data.earnings).toLocaleString();
            }
            if (data.efficiency !== undefined) {
                document.getElementById('currentEfficiency').textContent = Math.floor(data.efficiency) + '%';
                // Hiển thị earning rate theo giờ
                const basePerHour = 5000; // IC/giờ (tối đa)
                const earningRatePerHour = basePerHour * (data.efficiency / 100);
                document.getElementById('currentEarningRate').textContent = Math.floor(earningRatePerHour).toLocaleString();
            }
            break;
            
        case 'updateSystems':
            updateSystemsDisplay(data.systems);
            break;
            
        case 'updateEfficiency':
            updateEfficiencyDisplay(data.efficiency);
            break;
            
        case 'updateEarnings':
            updateEarningsDisplay(data.earnings);
            break;
            
        case 'updateActualEarningRate':
            if (data.earningRate !== undefined) {
                document.getElementById('earningRate').textContent = Math.floor(data.earningRate).toLocaleString();
            }
            break;
            
        case 'updateWorkTime':
            if (data.workHours !== undefined && data.maxHours !== undefined) {
                const statusText = document.getElementById('statusText');
                if (statusText) {
                    const hours = Math.floor(data.workHours * 10) / 10; // 1 chữ số thập phân
                    statusText.textContent = `ONLINE - ${hours}h/${data.maxHours}h`;
                }
            }
            break;
            
        case 'resetStatus':
            const statusText = document.getElementById('statusText');
            const statusDot = document.querySelector('.status-dot');
            if (statusText) statusText.textContent = 'OFFLINE';
            if (statusDot) statusDot.classList.remove('online');
            break;
            
        case 'resetToInitialState':
            // Set duty status
            isOnDuty = false;
            
            // Reset buttons
            document.getElementById('stopDutyBtn').classList.add('hidden');
            document.getElementById('startDutyBtn').classList.remove('hidden');
            
            // Reset status
            const statusTextReset = document.getElementById('statusText');
            const statusDotReset = document.querySelector('.status-dot');
            if (statusTextReset) statusTextReset.textContent = 'OFFLINE';
            if (statusDotReset) statusDotReset.classList.remove('online');
            
            // DỪNG HOÀN TOÀN quạt (không xoay)
            const turbineReset = document.querySelector('.blade-container');
            if (turbineReset) {
                turbineReset.classList.add('stopped'); // Thêm class stopped để dừng animation
                turbineReset.style.animationDuration = ''; // Reset inline style
            }
            
            // Reset efficiency display về 0 (chỉ hiển thị, không ảnh hưởng systems)
            document.getElementById('efficiencyValue').textContent = '0';
            
            // Reset progress ring to 0
            const progressCircleReset = document.querySelector('.progress-ring-circle');
            if (progressCircleReset) {
                const circumference = 754;
                progressCircleReset.style.strokeDashoffset = circumference;
            }
            
            // Reset earning rate to 0
            document.getElementById('earningRate').textContent = '0';
            
            // Disable systems (không cho phép sửa chữa)
            document.querySelectorAll('.system-item').forEach(item => {
                item.classList.add('disabled');
            });
            
            // GIỮ NGUYÊN:
            // - Systems (stability, electric, lubrication, blades, safety) - không reset
            // - Earnings pool (quỹ tiền) - không reset
            break;
            
        case 'workLimitReached':
            // Đánh dấu đã đạt giới hạn
            workLimitReached = true;
            
            // Disable nút Start và thay đổi text
            const startBtn = document.getElementById('startDutyBtn');
            if (startBtn) {
                startBtn.disabled = true;
                startBtn.classList.add('disabled-limit');
                startBtn.textContent = 'ĐÃ ĐẠT GIỚI HẠN';
            }
            
            // Hiển thị thông báo trên status
            const statusTextLimit = document.getElementById('statusText');
            if (statusTextLimit) {
                statusTextLimit.textContent = 'ĐÃ ĐẠT GIỚI HẠN - QUAY LẠI NGÀY MAI';
                statusTextLimit.style.color = '#ff4444';
            }
            break;
            
        case 'resetWorkLimit':
            // Reset work limit khi ngày mới
            workLimitReached = false;
            
            // Enable lại nút Start
            const startBtnReset = document.getElementById('startDutyBtn');
            if (startBtnReset) {
                startBtnReset.disabled = false;
                startBtnReset.classList.remove('disabled-limit');
                startBtnReset.textContent = 'BẮT ĐẦU CA';
            }
            
            // Reset status text
            const statusTextReset2 = document.getElementById('statusText');
            if (statusTextReset2 && statusTextReset2.textContent.includes('ĐÃ ĐẠT GIỚI HẠN')) {
                statusTextReset2.textContent = 'OFFLINE';
                statusTextReset2.style.color = '';
            }
            break;
    }
});

// Fan Minigame Functions
function tightenBolt(boltElement) {
    if (!fanMinigameActive || fanPhase !== 1) return;
    if (boltElement.classList.contains('tightened')) return;
    
    boltElement.classList.add('tightened');
    boltsTightened++;
    
    document.getElementById('boltCount').textContent = boltsTightened;
    
    // Play sound
    playSound('click');
    
    // Play tighten animation
    boltElement.style.transform = 'scale(1.2) rotate(360deg)';
    setTimeout(() => {
        boltElement.style.transform = '';
    }, 300);
    
    // Check if all bolts tightened
    if (boltsTightened >= 3) {
        playSound('success');
        setTimeout(() => {
            switchToRotationPhase();
        }, 500);
    }
}

function switchToRotationPhase() {
    fanPhase = 2;
    document.getElementById('fanPhase1').classList.add('hidden');
    document.getElementById('fanPhase2').classList.remove('hidden');
    
    // Reset cursor
    document.body.style.cursor = 'default';
    
    // Start tracking mouse for rotation
    mouseTracking = true;
}

function calculateMouseAngle(e) {
    const fanContainer = document.querySelector('#fanPhase2 .fan-container');
    if (!fanContainer) return 0;
    
    const rect = fanContainer.getBoundingClientRect();
    const centerX = rect.left + rect.width / 2;
    const centerY = rect.top + rect.height / 2;
    
    const deltaX = e.clientX - centerX;
    const deltaY = e.clientY - centerY;
    
    return Math.atan2(deltaY, deltaX) * (180 / Math.PI);
}

function updateRotation(e) {
    if (!fanMinigameActive || fanPhase !== 2 || !mouseTracking) return;
    
    const currentAngle = calculateMouseAngle(e);
    
    if (lastMouseAngle !== 0) {
        let angleDiff = currentAngle - lastMouseAngle;
        
        // Handle angle wrap-around
        if (angleDiff > 180) angleDiff -= 360;
        if (angleDiff < -180) angleDiff += 360;
        
        // Only count clockwise rotation (positive angles)
        if (angleDiff > 0 && angleDiff < 90) {
            // Giảm độ nhạy - xoay chậm hơn để tăng tiến độ
            rotationProgress += angleDiff / 25; // Giảm từ /10 xuống /25 (chậm hơn 2.5 lần)
            rotationProgress = Math.min(100, rotationProgress);
            
            // Update UI
            document.getElementById('rotationProgress').style.width = rotationProgress + '%';
            document.getElementById('rotationValue').textContent = Math.floor(rotationProgress);
            
            // Update fan rotation speed với các mốc rõ ràng
            const fanBlades = document.getElementById('fanBladesRotate');
            if (fanBlades) {
                let speed;
                
                // Tạo các mốc tốc độ rõ ràng
                if (rotationProgress < 30) {
                    // 0-30%: Cực chậm (6s -> 4.5s)
                    speed = 6 - (rotationProgress / 30) * 1.5;
                } else if (rotationProgress < 50) {
                    // 30-50%: Chậm (4.5s -> 3s)
                    speed = 4.5 - ((rotationProgress - 30) / 20) * 1.5;
                } else if (rotationProgress < 70) {
                    // 50-70%: Trung bình (3s -> 1.5s)
                    speed = 3 - ((rotationProgress - 50) / 20) * 1.5;
                } else {
                    // 70-100%: Nhanh (1.5s -> 0.3s)
                    speed = 1.5 - ((rotationProgress - 70) / 30) * 1.2;
                }
                
                fanBlades.style.animationDuration = speed + 's';
            }
            
            // Check completion
            if (rotationProgress >= 100) {
                completeFanMinigame('perfect');
            }
        }
    }
    
    lastMouseAngle = currentAngle;
}

function completeFanMinigame(result) {
    fanMinigameActive = false;
    mouseTracking = false;
    document.body.style.cursor = 'default';
    
    // Play completion sound
    if (result === 'perfect') {
        playSound('success');
    }
    
    post('minigameResult', {
        system: minigameData.system,
        result: result
    });
}

// Event listeners for fan minigame
document.addEventListener('click', (e) => {
    if (!fanMinigameActive || fanPhase !== 1) return;
    
    const bolt = e.target.closest('.bolt');
    if (bolt) {
        tightenBolt(bolt);
    }
});

document.addEventListener('mousemove', (e) => {
    if (fanMinigameActive && fanPhase === 2) {
        updateRotation(e);
    }
});

// Circuit Breaker Minigame Functions
function startCircuitBreakerMinigame(system) {
    circuitBreakerActive = true;
    minigameData = { system };
    
    // Initialize 4 breakers with random states
    breakers = [];
    const states = ['green', 'red', 'red', 'yellow']; // 1 green (already ok), 2 red (need 2 clicks), 1 yellow (need 1 click)
    
    // Shuffle states
    for (let i = states.length - 1; i > 0; i--) {
        const j = Math.floor(Math.random() * (i + 1));
        [states[i], states[j]] = [states[j], states[i]];
    }
    
    // Create breaker objects
    for (let i = 0; i < 4; i++) {
        const status = states[i];
        breakers.push({
            id: i + 1,
            status: status,
            clicksNeeded: status === 'green' ? 0 : (status === 'red' ? 2 : 1),
            clicksDone: 0,
            isDragging: false,
            dragStartY: 0,
            dragProgress: 0
        });
    }
    
    // Update UI
    updateCircuitBreakerUI();
    showCircuitBreakerUI();
}

function updateCircuitBreakerUI() {
    breakers.forEach(breaker => {
        const element = document.querySelector(`.breaker[data-breaker="${breaker.id}"]`);
        if (!element) return;
        
        // Remove all status classes
        element.classList.remove('status-green', 'status-red', 'status-yellow');
        
        // Add current status class
        element.classList.add(`status-${breaker.status}`);
        
        // Update switch position
        const switchElement = element.querySelector('.breaker-switch');
        if (switchElement) {
            if (breaker.status === 'green') {
                switchElement.classList.add('on');
            } else {
                switchElement.classList.remove('on');
            }
        }
        
        // Update indicator
        const indicator = element.querySelector('.breaker-indicator');
        if (indicator) {
            indicator.style.background = breaker.status === 'green' ? '#00ff88' : 
                                        breaker.status === 'red' ? '#ff4444' : '#ffaa00';
        }
    });
    
    // Update counter
    const completedCount = breakers.filter(b => b.status === 'green').length;
    document.getElementById('breakerCount').textContent = completedCount;
}

function startDraggingBreaker(breakerId, startY) {
    if (!circuitBreakerActive) return;
    
    const breaker = breakers.find(b => b.id === breakerId);
    if (!breaker || breaker.status === 'green') return;
    
    breaker.isDragging = true;
    breaker.dragStartY = startY;
    breaker.dragProgress = 0;
    
    const element = document.querySelector(`.breaker[data-breaker="${breakerId}"]`);
    element.classList.add('dragging');
}

function updateDraggingBreaker(breakerId, currentY) {
    if (!circuitBreakerActive) return;
    
    const breaker = breakers.find(b => b.id === breakerId);
    if (!breaker || !breaker.isDragging) return;
    
    // Calculate drag distance (negative = dragging up)
    const dragDistance = breaker.dragStartY - currentY;
    const requiredDistance = 80; // pixels needed to drag up
    
    breaker.dragProgress = Math.max(0, Math.min(100, (dragDistance / requiredDistance) * 100));
    
    // Update switch visual position
    const element = document.querySelector(`.breaker[data-breaker="${breakerId}"]`);
    const switchHandle = element.querySelector('.switch-handle');
    
    if (switchHandle) {
        const translateY = 10 - (breaker.dragProgress / 100) * 70; // From 10% to -60%
        switchHandle.style.transform = `translate(-50%, ${translateY}%)`;
    }
    
    // Update progress bar if exists
    const progressBar = element.querySelector('.drag-progress-bar');
    if (progressBar) {
        progressBar.style.width = breaker.dragProgress + '%';
    }
}

function stopDraggingBreaker(breakerId) {
    if (!circuitBreakerActive) return;
    
    const breaker = breakers.find(b => b.id === breakerId);
    if (!breaker || !breaker.isDragging) return;
    
    breaker.isDragging = false;
    
    const element = document.querySelector(`.breaker[data-breaker="${breakerId}"]`);
    element.classList.remove('dragging');
    
    // Check if drag was successful (reached 100%)
    if (breaker.dragProgress >= 100) {
        breaker.clicksDone++;
        
        // Play click sound
        playSound('click');
        
        // Play success animation
        element.classList.add('switch-success');
        setTimeout(() => {
            element.classList.remove('switch-success');
        }, 300);
        
        // Check if breaker is fixed
        if (breaker.clicksDone >= breaker.clicksNeeded) {
            breaker.status = 'green';
            
            // Play success sound
            playSound('success');
            
            // Success animation
            element.classList.add('success-flash');
            setTimeout(() => {
                element.classList.remove('success-flash');
            }, 500);
        }
    }
    
    // Reset drag progress
    breaker.dragProgress = 0;
    
    // Reset switch position if not fixed
    const switchHandle = element.querySelector('.switch-handle');
    if (switchHandle && breaker.status !== 'green') {
        switchHandle.style.transform = '';
    }
    
    // Reset progress bar
    const progressBar = element.querySelector('.drag-progress-bar');
    if (progressBar) {
        progressBar.style.width = '0%';
    }
    
    updateCircuitBreakerUI();
    
    // Check if all breakers are green
    if (breakers.every(b => b.status === 'green')) {
        setTimeout(() => {
            completeCircuitBreakerMinigame('perfect');
        }, 800);
    }
}

function completeCircuitBreakerMinigame(result) {
    circuitBreakerActive = false;
    
    post('minigameResult', {
        system: minigameData.system,
        result: result
    });
}

// Event listeners for circuit breakers - Mouse events
document.addEventListener('mousedown', (e) => {
    if (!circuitBreakerActive) return;
    
    const breaker = e.target.closest('.breaker');
    if (breaker) {
        const breakerId = parseInt(breaker.getAttribute('data-breaker'));
        startDraggingBreaker(breakerId, e.clientY);
    }
});

document.addEventListener('mousemove', (e) => {
    if (!circuitBreakerActive) return;
    
    breakers.forEach(breaker => {
        if (breaker.isDragging) {
            updateDraggingBreaker(breaker.id, e.clientY);
        }
    });
});

document.addEventListener('mouseup', (e) => {
    if (!circuitBreakerActive) return;
    
    breakers.forEach(breaker => {
        if (breaker.isDragging) {
            stopDraggingBreaker(breaker.id);
        }
    });
});

// Touch events for mobile support
document.addEventListener('touchstart', (e) => {
    if (!circuitBreakerActive) return;
    
    const breaker = e.target.closest('.breaker');
    if (breaker) {
        const breakerId = parseInt(breaker.getAttribute('data-breaker'));
        const touch = e.touches[0];
        startDraggingBreaker(breakerId, touch.clientY);
        e.preventDefault();
    }
});

document.addEventListener('touchmove', (e) => {
    if (!circuitBreakerActive) return;
    
    const touch = e.touches[0];
    breakers.forEach(breaker => {
        if (breaker.isDragging) {
            updateDraggingBreaker(breaker.id, touch.clientY);
        }
    });
    e.preventDefault();
});

document.addEventListener('touchend', (e) => {
    if (!circuitBreakerActive) return;
    
    breakers.forEach(breaker => {
        if (breaker.isDragging) {
            stopDraggingBreaker(breaker.id);
        }
    });
});

// Crack Repair Minigame Functions
function startCrackRepairMinigame(system) {
    crackRepairActive = true;
    trowelActive = true;
    minigameData = { system };
    
    // Generate 2-3 random cracks ON THE TOWER BODY
    const numCracks = Math.floor(Math.random() * 2) + 2; // 2 or 3 cracks
    cracks = [];
    
    // Tower body boundaries (centered, trapezoid shape)
    const towerCenterX = 50; // 50% from left
    const towerTopWidth = 30; // 30% width at top
    const towerBottomWidth = 40; // 40% width at bottom
    
    for (let i = 0; i < numCracks; i++) {
        // Random Y position (20% to 80% of tower height)
        const yPos = 20 + Math.random() * 60;
        
        // Calculate tower width at this Y position (trapezoid)
        const widthAtY = towerTopWidth + (towerBottomWidth - towerTopWidth) * (yPos - 20) / 60;
        
        // Random X position within tower bounds at this Y
        const xOffset = (Math.random() - 0.5) * widthAtY * 0.7; // 70% of width to stay safe
        const xPos = towerCenterX + xOffset;
        
        const crack = {
            id: i + 1,
            x: xPos,
            y: yPos,
            width: 100 + Math.random() * 80, // 100-180px
            height: 8 + Math.random() * 6, // 8-14px
            rotation: -25 + Math.random() * 50, // -25 to 25 degrees
            repairProgress: 0,
            isRepaired: false,
            branches: generateCrackBranches() // Add branch details
        };
        cracks.push(crack);
    }
    
    // Change cursor to trowel using CSS class
    document.body.classList.add('trowel-cursor');
    
    // Render cracks
    renderCracks();
    showCrackRepairUI();
}

function generateCrackBranches() {
    // Generate 2-4 small branches for realistic crack
    const numBranches = 2 + Math.floor(Math.random() * 3);
    const branches = [];
    
    for (let i = 0; i < numBranches; i++) {
        branches.push({
            position: 20 + Math.random() * 60, // % along main crack
            angle: -45 + Math.random() * 90, // -45 to 45 degrees
            length: 15 + Math.random() * 25 // 15-40px
        });
    }
    
    return branches;
}

function renderCracks() {
    const container = document.getElementById('cracksContainer');
    container.innerHTML = '';
    
    cracks.forEach(crack => {
        const crackElement = document.createElement('div');
        crackElement.className = 'crack';
        crackElement.setAttribute('data-crack', crack.id);
        crackElement.style.left = crack.x + '%';
        crackElement.style.top = crack.y + '%';
        crackElement.style.width = crack.width + 'px';
        crackElement.style.height = crack.height + 'px';
        crackElement.style.transform = `translate(-50%, -50%) rotate(${crack.rotation}deg)`;
        
        if (crack.isRepaired) {
            crackElement.classList.add('repaired');
        }
        
        // Create main crack line with SVG for better quality
        const crackSvg = document.createElementNS('http://www.w3.org/2000/svg', 'svg');
        crackSvg.setAttribute('class', 'crack-svg');
        crackSvg.setAttribute('width', crack.width);
        crackSvg.setAttribute('height', crack.height * 3);
        crackSvg.style.position = 'absolute';
        crackSvg.style.top = '50%';
        crackSvg.style.left = '0';
        crackSvg.style.transform = 'translateY(-50%)';
        
        // Main crack path (jagged line)
        const mainPath = document.createElementNS('http://www.w3.org/2000/svg', 'path');
        let pathData = `M 0 ${crack.height * 1.5}`;
        
        // Create jagged main crack
        const segments = 8;
        for (let i = 1; i <= segments; i++) {
            const x = (crack.width / segments) * i;
            const y = crack.height * 1.5 + (Math.random() - 0.5) * crack.height * 0.8;
            pathData += ` L ${x} ${y}`;
        }
        
        mainPath.setAttribute('d', pathData);
        mainPath.setAttribute('stroke', 'rgba(0, 0, 0, 0.9)');
        mainPath.setAttribute('stroke-width', '3');
        mainPath.setAttribute('fill', 'none');
        mainPath.setAttribute('class', 'crack-main-path');
        crackSvg.appendChild(mainPath);
        
        // Add shadow path
        const shadowPath = mainPath.cloneNode();
        shadowPath.setAttribute('stroke', 'rgba(0, 0, 0, 0.5)');
        shadowPath.setAttribute('stroke-width', '5');
        shadowPath.setAttribute('class', 'crack-shadow-path');
        crackSvg.insertBefore(shadowPath, mainPath);
        
        // Add branches
        crack.branches.forEach(branch => {
            const branchX = (crack.width * branch.position) / 100;
            const branchY = crack.height * 1.5;
            const branchEndX = branchX + Math.cos(branch.angle * Math.PI / 180) * branch.length;
            const branchEndY = branchY + Math.sin(branch.angle * Math.PI / 180) * branch.length;
            
            const branchPath = document.createElementNS('http://www.w3.org/2000/svg', 'path');
            branchPath.setAttribute('d', `M ${branchX} ${branchY} L ${branchEndX} ${branchEndY}`);
            branchPath.setAttribute('stroke', 'rgba(0, 0, 0, 0.8)');
            branchPath.setAttribute('stroke-width', '2');
            branchPath.setAttribute('fill', 'none');
            branchPath.setAttribute('class', 'crack-branch-path');
            crackSvg.appendChild(branchPath);
        });
        
        crackElement.appendChild(crackSvg);
        
        // Create repair overlay
        const repairOverlay = document.createElement('div');
        repairOverlay.className = 'repair-overlay';
        repairOverlay.style.width = crack.repairProgress + '%';
        crackElement.appendChild(repairOverlay);
        
        // Create progress bar
        const progressBar = document.createElement('div');
        progressBar.className = 'crack-progress';
        const progressFill = document.createElement('div');
        progressFill.className = 'crack-progress-fill';
        progressFill.style.width = crack.repairProgress + '%';
        progressBar.appendChild(progressFill);
        crackElement.appendChild(progressBar);
        
        // Add glow effect for unrepaired cracks
        if (!crack.isRepaired) {
            const glowElement = document.createElement('div');
            glowElement.className = 'crack-glow';
            crackElement.appendChild(glowElement);
        }
        
        container.appendChild(crackElement);
    });
    
    updateCrackCounter();
}

function updateCrackCounter() {
    const repairedCount = cracks.filter(c => c.isRepaired).length;
    document.getElementById('crackCount').textContent = repairedCount;
    document.getElementById('totalCracks').textContent = cracks.length;
}

function repairCrack(crackId, mouseX, mouseY) {
    if (!crackRepairActive) return;
    
    const crack = cracks.find(c => c.id === crackId);
    if (!crack || crack.isRepaired) return;
    
    // Increase repair progress
    crack.repairProgress += 3; // 3% per click/move
    
    // Play repair sound occasionally
    if (Math.random() < 0.3) {
        playSound('repair');
    }
    
    if (crack.repairProgress >= 100) {
        crack.repairProgress = 100;
        crack.isRepaired = true;
        
        // Play success sound
        playSound('success');
        
        // Mark as repaired
        const crackElement = document.querySelector(`.crack[data-crack="${crackId}"]`);
        if (crackElement) {
            crackElement.classList.add('repaired');
        }
    }
    
    // Update only the progress bars without re-rendering entire crack
    updateCrackProgress(crackId);
    
    // Create cement splatter effect
    createCementSplatter(mouseX, mouseY);
    
    // Check if all cracks are repaired
    if (cracks.every(c => c.isRepaired)) {
        setTimeout(() => {
            completeCrackRepairMinigame('perfect');
        }, 1000);
    }
}

function updateCrackProgress(crackId) {
    const crack = cracks.find(c => c.id === crackId);
    if (!crack) return;
    
    const crackElement = document.querySelector(`.crack[data-crack="${crackId}"]`);
    if (!crackElement) return;
    
    // Update repair overlay width
    const repairOverlay = crackElement.querySelector('.repair-overlay');
    if (repairOverlay) {
        repairOverlay.style.width = crack.repairProgress + '%';
    }
    
    // Update progress bar
    const progressFill = crackElement.querySelector('.crack-progress-fill');
    if (progressFill) {
        progressFill.style.width = crack.repairProgress + '%';
    }
    
    // Update counter
    updateCrackCounter();
}

function createCementSplatter(x, y) {
    const splatter = document.createElement('div');
    splatter.className = 'cement-splatter';
    splatter.style.left = x + 'px';
    splatter.style.top = y + 'px';
    
    document.getElementById('crackRepairUI').appendChild(splatter);
    
    setTimeout(() => {
        splatter.remove();
    }, 500);
}

function completeCrackRepairMinigame(result) {
    crackRepairActive = false;
    trowelActive = false;
    document.body.classList.remove('trowel-cursor');
    
    post('minigameResult', {
        system: minigameData.system,
        result: result
    });
}

// Event listeners for crack repair
document.addEventListener('mousedown', (e) => {
    if (!crackRepairActive) return;
    
    const crack = e.target.closest('.crack');
    if (crack && !crack.classList.contains('repaired')) {
        const crackId = parseInt(crack.getAttribute('data-crack'));
        const rect = document.getElementById('towerStructure').getBoundingClientRect();
        repairCrack(crackId, e.clientX - rect.left, e.clientY - rect.top);
    }
});

document.addEventListener('mousemove', (e) => {
    if (!crackRepairActive) return;
    
    // Check if mouse button is pressed
    if (e.buttons === 1) {
        const crack = e.target.closest('.crack');
        if (crack && !crack.classList.contains('repaired')) {
            const crackId = parseInt(crack.getAttribute('data-crack'));
            const rect = document.getElementById('towerStructure').getBoundingClientRect();
            repairCrack(crackId, e.clientX - rect.left, e.clientY - rect.top);
        }
    }
});
