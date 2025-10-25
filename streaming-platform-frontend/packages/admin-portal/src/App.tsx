import './styles/admin-theme.css';
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
    <div className="admin-portal">
      <header className="admin-header">
        <h1>Admin Portal</h1>
        <nav className="admin-nav">
          <a href="#dashboard">Dashboard</a>
          <a href="#users">Users</a>
          <a href="#monitoring">Monitoring</a>
          <a href="#settings">Settings</a>
        </nav>
      </header>
      
      <main className="admin-content">
        <div className="admin-card">
          <SystemDashboard />
        </div>
        <div className="admin-grid">
          <div className="admin-card">
            <UserManagement />
          </div>
          <div className="admin-card">
            <PerformanceMetrics />
          </div>
        </div>
      </main>
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
