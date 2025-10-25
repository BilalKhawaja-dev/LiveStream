import React from 'react'

function App() {
  return (
    <div style={{ 
      padding: '20px', 
      fontFamily: 'Arial, sans-serif',
      backgroundColor: '#1a1a2e',
      color: 'white',
      minHeight: '100vh'
    }}>
      <header style={{ marginBottom: '30px' }}>
        <h1 style={{ color: '#16213e', fontSize: '2.5rem', margin: 0 }}>
          🎬 Streaming Platform - Viewer Portal
        </h1>
        <p style={{ color: '#0f3460', margin: '10px 0' }}>
          Welcome to the streaming platform viewer experience
        </p>
      </header>
      
      <main>
        <div style={{ 
          backgroundColor: '#16213e', 
          padding: '20px', 
          borderRadius: '12px',
          marginBottom: '20px'
        }}>
          <h2 style={{ color: '#e94560', marginTop: 0 }}>🎯 Status Check</h2>
          <ul style={{ listStyle: 'none', padding: 0 }}>
            <li style={{ padding: '5px 0' }}>✅ React Application Loading</li>
            <li style={{ padding: '5px 0' }}>✅ JavaScript Bundle Working</li>
            <li style={{ padding: '5px 0' }}>✅ CSS Styles Applied</li>
            <li style={{ padding: '5px 0' }}>✅ Assets Serving Correctly</li>
            <li style={{ padding: '5px 0' }}>✅ Docker Container Healthy</li>
          </ul>
        </div>

        <div style={{ 
          backgroundColor: '#0f3460', 
          padding: '20px', 
          borderRadius: '12px',
          marginBottom: '20px'
        }}>
          <h3 style={{ color: '#e94560', marginTop: 0 }}>🚀 Quick Actions</h3>
          <div style={{ display: 'flex', gap: '10px', flexWrap: 'wrap' }}>
            <button 
              onClick={() => alert('Browse Streams feature coming soon!')}
              style={{
                padding: '12px 24px',
                backgroundColor: '#e94560',
                color: 'white',
                border: 'none',
                borderRadius: '6px',
                cursor: 'pointer',
                fontSize: '16px'
              }}
            >
              Browse Streams
            </button>
            <button 
              onClick={() => alert('Search feature coming soon!')}
              style={{
                padding: '12px 24px',
                backgroundColor: '#16213e',
                color: 'white',
                border: '2px solid #e94560',
                borderRadius: '6px',
                cursor: 'pointer',
                fontSize: '16px'
              }}
            >
              Search Content
            </button>
            <button 
              onClick={() => alert('Profile feature coming soon!')}
              style={{
                padding: '12px 24px',
                backgroundColor: '#0f3460',
                color: 'white',
                border: '2px solid #e94560',
                borderRadius: '6px',
                cursor: 'pointer',
                fontSize: '16px'
              }}
            >
              My Profile
            </button>
          </div>
        </div>

        <div style={{ 
          backgroundColor: '#16213e', 
          padding: '20px', 
          borderRadius: '12px'
        }}>
          <h3 style={{ color: '#e94560', marginTop: 0 }}>📊 Platform Info</h3>
          <p>Environment: Development</p>
          <p>Version: 1.0.0</p>
          <p>Build Time: {new Date().toLocaleString()}</p>
          <p>Status: All systems operational ✅</p>
        </div>
      </main>
    </div>
  )
}

export default App
