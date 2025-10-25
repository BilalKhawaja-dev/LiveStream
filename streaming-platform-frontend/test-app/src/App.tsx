import React from 'react'

function App() {
  return (
    <div style={{ 
      padding: '20px', 
      fontFamily: 'Arial, sans-serif',
      backgroundColor: '#f0f0f0',
      minHeight: '100vh'
    }}>
      <h1 style={{ color: '#333' }}>🎉 Test App Working!</h1>
      <p>If you can see this, the React app is loading correctly.</p>
      <div style={{ 
        backgroundColor: 'white', 
        padding: '15px', 
        borderRadius: '8px',
        marginTop: '20px'
      }}>
        <h2>Status Check:</h2>
        <ul>
          <li>✅ React is working</li>
          <li>✅ JavaScript is loading</li>
          <li>✅ CSS is working</li>
          <li>✅ Assets are being served</li>
        </ul>
      </div>
      <button 
        onClick={() => alert('Button works!')}
        style={{
          padding: '10px 20px',
          backgroundColor: '#007bff',
          color: 'white',
          border: 'none',
          borderRadius: '4px',
          cursor: 'pointer',
          marginTop: '20px'
        }}
      >
        Test Button
      </button>
    </div>
  )
}

export default App
