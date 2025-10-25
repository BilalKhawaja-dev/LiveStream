#!/bin/bash

echo "=== CREATING PROPERLY STYLED APPS ==="
echo "Adding CSS imports and ensuring proper styling"

SERVICES=("creator-dashboard" "admin-portal" "developer-console" "analytics-dashboard" "support-system")

for service in "${SERVICES[@]}"; do
    echo "Creating properly styled app for $service..."
    
    service_dir="streaming-platform-frontend/packages/$service"
    
    # Update main.tsx to import CSS
    cat > "$service_dir/src/main.tsx" << 'EOF'
import React from 'react';
import ReactDOM from 'react-dom/client';
import App from './App';
import './styles/index.css';

const root = ReactDOM.createRoot(
  document.getElementById('root') as HTMLElement
);

root.render(
  <React.StrictMode>
    <App />
  </React.StrictMode>
);
EOF

    # Create a comprehensive CSS file for each service
    mkdir -p "$service_dir/src/styles"
    
    case $service in
        "creator-dashboard")
            cat > "$service_dir/src/styles/index.css" << 'EOF'
/* Creator Dashboard Styles */
@import url('https://fonts.googleapis.com/css2?family=Inter:wght@300;400;500;600;700&display=swap');

* {
  margin: 0;
  padding: 0;
  box-sizing: border-box;
}

body {
  font-family: 'Inter', -apple-system, BlinkMacSystemFont, 'Segoe UI', sans-serif;
  background: linear-gradient(135deg, #667eea 0%, #764ba2 100%);
  min-height: 100vh;
  color: #333;
}

#root {
  min-height: 100vh;
}

.dashboard-container {
  padding: 2rem;
  max-width: 1400px;
  margin: 0 auto;
}

.dashboard-header {
  background: rgba(255, 255, 255, 0.95);
  backdrop-filter: blur(10px);
  padding: 2rem;
  border-radius: 16px;
  margin-bottom: 2rem;
  box-shadow: 0 8px 32px rgba(0, 0, 0, 0.1);
}

.dashboard-title {
  font-size: 2.5rem;
  font-weight: 700;
  color: #2d3748;
  margin-bottom: 0.5rem;
}

.dashboard-subtitle {
  color: #718096;
  font-size: 1.1rem;
}

.stats-grid {
  display: grid;
  grid-template-columns: repeat(auto-fit, minmax(280px, 1fr));
  gap: 1.5rem;
  margin-bottom: 2rem;
}

.stat-card {
  background: rgba(255, 255, 255, 0.95);
  backdrop-filter: blur(10px);
  padding: 2rem;
  border-radius: 16px;
  box-shadow: 0 8px 32px rgba(0, 0, 0, 0.1);
  border: 1px solid rgba(255, 255, 255, 0.2);
}

.stat-value {
  font-size: 2.5rem;
  font-weight: 700;
  color: #667eea;
  margin-bottom: 0.5rem;
}

.stat-label {
  color: #718096;
  font-weight: 500;
  text-transform: uppercase;
  font-size: 0.875rem;
  letter-spacing: 0.05em;
}

.action-button {
  background: linear-gradient(135deg, #667eea 0%, #764ba2 100%);
  color: white;
  border: none;
  padding: 0.75rem 1.5rem;
  border-radius: 8px;
  font-weight: 600;
  cursor: pointer;
  transition: all 0.2s;
}

.action-button:hover {
  transform: translateY(-2px);
  box-shadow: 0 4px 16px rgba(102, 126, 234, 0.4);
}

.status-online {
  color: #38a169;
  font-weight: 600;
}

.status-offline {
  color: #e53e3e;
  font-weight: 600;
}
EOF
            ;;
        "admin-portal")
            cat > "$service_dir/src/styles/index.css" << 'EOF'
/* Admin Portal Styles */
@import url('https://fonts.googleapis.com/css2?family=Inter:wght@300;400;500;600;700&display=swap');

* {
  margin: 0;
  padding: 0;
  box-sizing: border-box;
}

body {
  font-family: 'Inter', -apple-system, BlinkMacSystemFont, 'Segoe UI', sans-serif;
  background: linear-gradient(135deg, #ff9a56 0%, #ff6b6b 100%);
  min-height: 100vh;
  color: #333;
}

#root {
  min-height: 100vh;
}

.dashboard-container {
  padding: 2rem;
  max-width: 1400px;
  margin: 0 auto;
}

.dashboard-header {
  background: rgba(255, 255, 255, 0.95);
  backdrop-filter: blur(10px);
  padding: 2rem;
  border-radius: 16px;
  margin-bottom: 2rem;
  box-shadow: 0 8px 32px rgba(0, 0, 0, 0.1);
}

.dashboard-title {
  font-size: 2.5rem;
  font-weight: 700;
  color: #c53030;
  margin-bottom: 0.5rem;
}

.admin-card {
  background: rgba(255, 255, 255, 0.95);
  backdrop-filter: blur(10px);
  padding: 2rem;
  border-radius: 16px;
  box-shadow: 0 8px 32px rgba(0, 0, 0, 0.1);
  border-left: 4px solid #ff6b6b;
}

.metric-value {
  font-size: 2rem;
  font-weight: 700;
  color: #ff6b6b;
}

.action-button {
  background: linear-gradient(135deg, #ff9a56 0%, #ff6b6b 100%);
  color: white;
  border: none;
  padding: 0.75rem 1.5rem;
  border-radius: 8px;
  font-weight: 600;
  cursor: pointer;
  transition: all 0.2s;
}

.action-button:hover {
  transform: translateY(-2px);
  box-shadow: 0 4px 16px rgba(255, 107, 107, 0.4);
}
EOF
            ;;
        "developer-console")
            cat > "$service_dir/src/styles/index.css" << 'EOF'
/* Developer Console Styles */
@import url('https://fonts.googleapis.com/css2?family=JetBrains+Mono:wght@300;400;500;600&family=Inter:wght@300;400;500;600;700&display=swap');

* {
  margin: 0;
  padding: 0;
  box-sizing: border-box;
}

body {
  font-family: 'Inter', -apple-system, BlinkMacSystemFont, 'Segoe UI', sans-serif;
  background: linear-gradient(135deg, #2d3748 0%, #1a202c 100%);
  min-height: 100vh;
  color: #e2e8f0;
}

#root {
  min-height: 100vh;
}

.dashboard-container {
  padding: 2rem;
  max-width: 1400px;
  margin: 0 auto;
}

.dashboard-header {
  background: rgba(45, 55, 72, 0.95);
  backdrop-filter: blur(10px);
  padding: 2rem;
  border-radius: 16px;
  margin-bottom: 2rem;
  box-shadow: 0 8px 32px rgba(0, 0, 0, 0.3);
  border: 1px solid rgba(255, 255, 255, 0.1);
}

.dashboard-title {
  font-size: 2.5rem;
  font-weight: 700;
  color: #68d391;
  margin-bottom: 0.5rem;
}

.console-card {
  background: rgba(45, 55, 72, 0.95);
  backdrop-filter: blur(10px);
  padding: 2rem;
  border-radius: 16px;
  box-shadow: 0 8px 32px rgba(0, 0, 0, 0.3);
  border: 1px solid rgba(104, 211, 145, 0.2);
}

.code-block {
  background: #1a202c;
  padding: 1rem;
  border-radius: 8px;
  font-family: 'JetBrains Mono', monospace;
  color: #68d391;
  border: 1px solid rgba(104, 211, 145, 0.2);
}

.action-button {
  background: linear-gradient(135deg, #68d391 0%, #38a169 100%);
  color: #1a202c;
  border: none;
  padding: 0.75rem 1.5rem;
  border-radius: 8px;
  font-weight: 600;
  cursor: pointer;
  transition: all 0.2s;
}

.action-button:hover {
  transform: translateY(-2px);
  box-shadow: 0 4px 16px rgba(104, 211, 145, 0.4);
}
EOF
            ;;
        "analytics-dashboard")
            cat > "$service_dir/src/styles/index.css" << 'EOF'
/* Analytics Dashboard Styles */
@import url('https://fonts.googleapis.com/css2?family=Inter:wght@300;400;500;600;700&display=swap');

* {
  margin: 0;
  padding: 0;
  box-sizing: border-box;
}

body {
  font-family: 'Inter', -apple-system, BlinkMacSystemFont, 'Segoe UI', sans-serif;
  background: linear-gradient(135deg, #9f7aea 0%, #667eea 100%);
  min-height: 100vh;
  color: #333;
}

#root {
  min-height: 100vh;
}

.dashboard-container {
  padding: 2rem;
  max-width: 1400px;
  margin: 0 auto;
}

.dashboard-header {
  background: rgba(255, 255, 255, 0.95);
  backdrop-filter: blur(10px);
  padding: 2rem;
  border-radius: 16px;
  margin-bottom: 2rem;
  box-shadow: 0 8px 32px rgba(0, 0, 0, 0.1);
}

.dashboard-title {
  font-size: 2.5rem;
  font-weight: 700;
  color: #805ad5;
  margin-bottom: 0.5rem;
}

.analytics-card {
  background: rgba(255, 255, 255, 0.95);
  backdrop-filter: blur(10px);
  padding: 2rem;
  border-radius: 16px;
  box-shadow: 0 8px 32px rgba(0, 0, 0, 0.1);
  border-left: 4px solid #9f7aea;
}

.metric-large {
  font-size: 3rem;
  font-weight: 700;
  color: #9f7aea;
}

.action-button {
  background: linear-gradient(135deg, #9f7aea 0%, #667eea 100%);
  color: white;
  border: none;
  padding: 0.75rem 1.5rem;
  border-radius: 8px;
  font-weight: 600;
  cursor: pointer;
  transition: all 0.2s;
}

.action-button:hover {
  transform: translateY(-2px);
  box-shadow: 0 4px 16px rgba(159, 122, 234, 0.4);
}
EOF
            ;;
        "support-system")
            cat > "$service_dir/src/styles/index.css" << 'EOF'
/* Support System Styles */
@import url('https://fonts.googleapis.com/css2?family=Inter:wght@300;400;500;600;700&display=swap');

* {
  margin: 0;
  padding: 0;
  box-sizing: border-box;
}

body {
  font-family: 'Inter', -apple-system, BlinkMacSystemFont, 'Segoe UI', sans-serif;
  background: linear-gradient(135deg, #ffd89b 0%, #19547b 100%);
  min-height: 100vh;
  color: #333;
}

#root {
  min-height: 100vh;
}

.dashboard-container {
  padding: 2rem;
  max-width: 1400px;
  margin: 0 auto;
}

.dashboard-header {
  background: rgba(255, 255, 255, 0.95);
  backdrop-filter: blur(10px);
  padding: 2rem;
  border-radius: 16px;
  margin-bottom: 2rem;
  box-shadow: 0 8px 32px rgba(0, 0, 0, 0.1);
}

.dashboard-title {
  font-size: 2.5rem;
  font-weight: 700;
  color: #d69e2e;
  margin-bottom: 0.5rem;
}

.support-card {
  background: rgba(255, 255, 255, 0.95);
  backdrop-filter: blur(10px);
  padding: 2rem;
  border-radius: 16px;
  box-shadow: 0 8px 32px rgba(0, 0, 0, 0.1);
  border-left: 4px solid #ffd89b;
}

.ticket-priority-high {
  color: #e53e3e;
  font-weight: 600;
}

.ticket-priority-medium {
  color: #d69e2e;
  font-weight: 600;
}

.ticket-priority-low {
  color: #38a169;
  font-weight: 600;
}

.action-button {
  background: linear-gradient(135deg, #ffd89b 0%, #d69e2e 100%);
  color: #1a202c;
  border: none;
  padding: 0.75rem 1.5rem;
  border-radius: 8px;
  font-weight: 600;
  cursor: pointer;
  transition: all 0.2s;
}

.action-button:hover {
  transform: translateY(-2px);
  box-shadow: 0 4px 16px rgba(214, 158, 46, 0.4);
}
EOF
            ;;
    esac
    
    # Create a styled App.tsx that doesn't rely on Chakra UI (to avoid dependency issues)
    cat > "$service_dir/src/App.tsx" << EOF
import React from 'react';
import { BrowserRouter as Router, Routes, Route } from 'react-router-dom';
import { AuthProvider } from './stubs/auth';
import { ErrorBoundary } from './stubs/ui';

const Dashboard: React.FC = () => {
  return (
    <div className="dashboard-container">
      <div className="dashboard-header">
        <h1 className="dashboard-title">
          $(echo "$service" | sed 's/-/ /g' | sed 's/\b\w/\U&/g')
        </h1>
        <p className="dashboard-subtitle">
          Welcome to your $(echo "$service" | sed 's/-/ /g') interface
        </p>
      </div>
      
      <div className="stats-grid">
        <div className="$(echo "$service" | cut -d'-' -f1)-card">
          <h2 style={{ marginBottom: '1rem', fontSize: '1.5rem', fontWeight: '600' }}>Overview</h2>
          <div className="stat-value">1,234</div>
          <div className="stat-label">Active Users</div>
        </div>
        
        <div className="$(echo "$service" | cut -d'-' -f1)-card">
          <h2 style={{ marginBottom: '1rem', fontSize: '1.5rem', fontWeight: '600' }}>Performance</h2>
          <div className="stat-value">99.9%</div>
          <div className="stat-label">Uptime</div>
        </div>
        
        <div className="$(echo "$service" | cut -d'-' -f1)-card">
          <h2 style={{ marginBottom: '1rem', fontSize: '1.5rem', fontWeight: '600' }}>Status</h2>
          <div className="status-online">✅ All Systems Operational</div>
          <div style={{ marginTop: '1rem' }}>
            <button className="action-button">
              View Details
            </button>
          </div>
        </div>
        
        <div className="$(echo "$service" | cut -d'-' -f1)-card">
          <h2 style={{ marginBottom: '1rem', fontSize: '1.5rem', fontWeight: '600' }}>Quick Actions</h2>
          <div style={{ display: 'flex', flexDirection: 'column', gap: '0.5rem' }}>
            <button className="action-button">Primary Action</button>
            <button className="action-button" style={{ opacity: '0.8' }}>Secondary Action</button>
          </div>
        </div>
      </div>
    </div>
  );
};

const App: React.FC = () => {
  return (
    <ErrorBoundary>
      <AuthProvider>
        <Router>
          <Routes>
            <Route path="/" element={<Dashboard />} />
            <Route path="/$service/*" element={<Dashboard />} />
          </Routes>
        </Router>
      </AuthProvider>
    </ErrorBoundary>
  );
};

export default App;
EOF

    echo "✅ Created properly styled app for $service"
done

echo "=== PROPERLY STYLED APPS CREATED ==="
echo "Each service now has:"
echo "  - Custom CSS with colors and styling"
echo "  - Service-specific color schemes"
echo "  - Proper typography and layout"
echo "  - No Chakra UI dependency issues"