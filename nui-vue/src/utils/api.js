// Utility: Post message to client
export function post(action, data = {}) {
  const resourceName = GetParentResourceName()
  console.log(`📤 POST: ${action}`, data, `to https://${resourceName}/${action}`)
  
  fetch(`https://${resourceName}/${action}`, {
    method: 'POST',
    headers: { 'Content-Type': 'application/json' },
    body: JSON.stringify(data)
  }).catch(err => {
    console.error('❌ POST failed:', err)
  })
}

// Get resource name
function GetParentResourceName() {
  // In FiveM NUI, this is a global function
  if (window.GetParentResourceName) {
    return window.GetParentResourceName()
  }
  
  // Fallback for development
  if (window.location.hostname === 'nui-frame-overlay') {
    return 'windturbine'
  }
  
  return window.location.hostname
}
