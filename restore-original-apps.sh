#!/bin/bash

echo "=== RESTORING ORIGINAL APP FUNCTIONALITY ==="
echo "Replacing placeholder apps with proper component usage"

# Restore Creator Dashboard
echo "Restoring Creator Dashboard..."
cat > "streaming-platform-frontend/packages/creator-dashboard/src/App.tsx" << 'EOF'
import React from 'react';
import { ChakraProvider, extendTheme } from '@chakra-ui/react';
import { BrowserRouter as Router, Routes, Route } from 'react-router-dom';
import { AuthProvider } from './stubs/auth';
import { ErrorBoundary, AppLayout } from './stubs/ui';
import { EnhancedCreatorAnalytics } from './components/Analytics/EnhancedCreatorAnalytics';
import { StreamControls } from './components/Stream/StreamControls';
import { RevenueTracking } from './components/Revenue/RevenueTracking';

const theme = extendTheme({
  colors: {
    brand: {
      50: '#e3f2fd',
      500: '#2196f3',
      900: '#0d47a1',
    },
  },
});

const Dashboard: React.FC = () => {
  return (
    <div style={{ padding: '2rem', backgroundColor: '#f5f5f5', minHeight: '100vh' }}>
      <h1 style={{ color: '#333', marginBottom: '2rem', fontSize: '2rem', fontWeight: 'bold' }}>
        Creator Dashboard
      </h1>
      <div style={{ display: 'flex', flexDirection: 'column', gap: '2rem' }}>
        <EnhancedCreatorAnalytics />
        <div style={{ display: 'grid', gridTemplateColumns: '1fr 1fr', gap: '2rem' }}>
          <StreamControls />
          <RevenueTracking />
        </div>
      </div>
    </div>
  );
};

const App: React.FC = () => {
  return (
    <ChakraProvider theme={theme}>
      <ErrorBoundary>
        <AuthProvider>
          <Router>
            <AppLayout>
              <Routes>
                <Route path="/" element={<Dashboard />} />
                <Route path="/creator-dashboard/*" element={<Dashboard />} />
              </Routes>
            </AppLayout>
          </Router>
        </AuthProvider>
      </ErrorBoundary>
    </ChakraProvider>
  );
};

export default App;
EOF

# Restore Admin Portal
echo "Restoring Admin Portal..."
cat > "streaming-platform-frontend/packages/admin-portal/src/App.tsx" << 'EOF'
import React from 'react';
import { ChakraProvider, extendTheme } from '@chakra-ui/react';
import { BrowserRouter as Router, Routes, Route } from 'react-router-dom';
import { AuthProvider } from './stubs/auth';
import { ErrorBoundary, AppLayout } from './stubs/ui';
import { SystemDashboard } from './components/Monitoring/SystemDashboard';
import { UserManagement } from './components/Users/UserManagement';
import { PerformanceMetrics } from './components/Monitoring/PerformanceMetrics';

const theme = extendTheme({
  colors: {
    brand: {
      50: '#fff3e0',
      500: '#ff9800',
      900: '#e65100',
    },
  },
});

const Dashboard: React.FC = () => {
  return (
    <div style={{ padding: '2rem', backgroundColor: '#f5f5f5', minHeight: '100vh' }}>
      <h1 style={{ color: '#333', marginBottom: '2rem', fontSize: '2rem', fontWeight: 'bold' }}>
        Admin Portal
      </h1>
      <div style={{ display: 'flex', flexDirection: 'column', gap: '2rem' }}>
        <SystemDashboard />
        <div style={{ display: 'grid', gridTemplateColumns: '1fr 1fr', gap: '2rem' }}>
          <UserManagement />
          <PerformanceMetrics />
        </div>
      </div>
    </div>
  );
};

const App: React.FC = () => {
  return (
    <ChakraProvider theme={theme}>
      <ErrorBoundary>
        <AuthProvider>
          <Router>
            <AppLayout>
              <Routes>
                <Route path="/" element={<Dashboard />} />
                <Route path="/admin-portal/*" element={<Dashboard />} />
              </Routes>
            </AppLayout>
          </Router>
        </AuthProvider>
      </ErrorBoundary>
    </ChakraProvider>
  );
};

export default App;
EOF

# Restore Developer Console
echo "Restoring Developer Console..."
cat > "streaming-platform-frontend/packages/developer-console/src/App.tsx" << 'EOF'
import React from 'react';
import { ChakraProvider, extendTheme } from '@chakra-ui/react';
import { BrowserRouter as Router, Routes, Route } from 'react-router-dom';
import { AuthProvider } from './stubs/auth';
import { ErrorBoundary, AppLayout } from './stubs/ui';
import { APIDashboard } from './components/API/APIDashboard';
import { SystemHealth } from './components/Health/SystemHealth';
import { APITesting } from './components/Testing/APITesting';

const theme = extendTheme({
  colors: {
    brand: {
      50: '#e8f5e8',
      500: '#4caf50',
      900: '#1b5e20',
    },
  },
});

const Dashboard: React.FC = () => {
  return (
    <div style={{ padding: '2rem', backgroundColor: '#f5f5f5', minHeight: '100vh' }}>
      <h1 style={{ color: '#333', marginBottom: '2rem', fontSize: '2rem', fontWeight: 'bold' }}>
        Developer Console
      </h1>
      <div style={{ display: 'flex', flexDirection: 'column', gap: '2rem' }}>
        <APIDashboard />
        <div style={{ display: 'grid', gridTemplateColumns: '1fr 1fr', gap: '2rem' }}>
          <SystemHealth />
          <APITesting />
        </div>
      </div>
    </div>
  );
};

const App: React.FC = () => {
  return (
    <ChakraProvider theme={theme}>
      <ErrorBoundary>
        <AuthProvider>
          <Router>
            <AppLayout>
              <Routes>
                <Route path="/" element={<Dashboard />} />
                <Route path="/developer-console/*" element={<Dashboard />} />
              </Routes>
            </AppLayout>
          </Router>
        </AuthProvider>
      </ErrorBoundary>
    </ChakraProvider>
  );
};

export default App;
EOF

# Restore Analytics Dashboard
echo "Restoring Analytics Dashboard..."
cat > "streaming-platform-frontend/packages/analytics-dashboard/src/App.tsx" << 'EOF'
import React from 'react';
import { ChakraProvider, extendTheme } from '@chakra-ui/react';
import { BrowserRouter as Router, Routes, Route } from 'react-router-dom';
import { AuthProvider } from './stubs/auth';
import { ErrorBoundary, AppLayout } from './stubs/ui';
import { RealTimeMetrics } from './components/RealTime/RealTimeMetrics';
import { StreamerAnalytics } from './components/Streamers/StreamerAnalytics';
import { RevenueAnalytics } from './components/Revenue/RevenueAnalytics';

const theme = extendTheme({
  colors: {
    brand: {
      50: '#f3e5f5',
      500: '#9c27b0',
      900: '#4a148c',
    },
  },
});

const Dashboard: React.FC = () => {
  return (
    <div style={{ padding: '2rem', backgroundColor: '#f5f5f5', minHeight: '100vh' }}>
      <h1 style={{ color: '#333', marginBottom: '2rem', fontSize: '2rem', fontWeight: 'bold' }}>
        Analytics Dashboard
      </h1>
      <div style={{ display: 'flex', flexDirection: 'column', gap: '2rem' }}>
        <RealTimeMetrics />
        <div style={{ display: 'grid', gridTemplateColumns: '1fr 1fr', gap: '2rem' }}>
          <StreamerAnalytics />
          <RevenueAnalytics />
        </div>
      </div>
    </div>
  );
};

const App: React.FC = () => {
  return (
    <ChakraProvider theme={theme}>
      <ErrorBoundary>
        <AuthProvider>
          <Router>
            <AppLayout>
              <Routes>
                <Route path="/" element={<Dashboard />} />
                <Route path="/analytics-dashboard/*" element={<Dashboard />} />
              </Routes>
            </AppLayout>
          </Router>
        </AuthProvider>
      </ErrorBoundary>
    </ChakraProvider>
  );
};

export default App;
EOF

# Restore Support System
echo "Restoring Support System..."
cat > "streaming-platform-frontend/packages/support-system/src/App.tsx" << 'EOF'
import React from 'react';
import { ChakraProvider, extendTheme } from '@chakra-ui/react';
import { BrowserRouter as Router, Routes, Route } from 'react-router-dom';
import { AuthProvider } from './stubs/auth';
import { ErrorBoundary, AppLayout } from './stubs/ui';
import { TicketDashboard } from './components/TicketManagement/TicketDashboard';

const theme = extendTheme({
  colors: {
    brand: {
      50: '#fff8e1',
      500: '#ffc107',
      900: '#ff6f00',
    },
  },
});

const Dashboard: React.FC = () => {
  return (
    <div style={{ padding: '2rem', backgroundColor: '#f5f5f5', minHeight: '100vh' }}>
      <h1 style={{ color: '#333', marginBottom: '2rem', fontSize: '2rem', fontWeight: 'bold' }}>
        Support System
      </h1>
      <div style={{ display: 'flex', flexDirection: 'column', gap: '2rem' }}>
        <TicketDashboard />
      </div>
    </div>
  );
};

const App: React.FC = () => {
  return (
    <ChakraProvider theme={theme}>
      <ErrorBoundary>
        <AuthProvider>
          <Router>
            <AppLayout>
              <Routes>
                <Route path="/" element={<Dashboard />} />
                <Route path="/support-system/*" element={<Dashboard />} />
              </Routes>
            </AppLayout>
          </Router>
        </AuthProvider>
      </ErrorBoundary>
    </ChakraProvider>
  );
};

export default App;
EOF

echo "✅ All App.tsx files restored with original component usage"
echo "=== ORIGINAL APP FUNCTIONALITY RESTORED ==="