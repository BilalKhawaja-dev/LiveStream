import './styles/analytics-theme.css';
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
    <div className="analytics-dashboard">
      <header className="analytics-header">
        <h1>Analytics Dashboard</h1>
        <nav className="analytics-nav">
          <a href="#realtime">Real-time</a>
          <a href="#streamers">Streamers</a>
          <a href="#revenue">Revenue</a>
          <a href="#reports">Reports</a>
        </nav>
      </header>
      
      <main className="analytics-content">
        <div className="analytics-card">
          <RealTimeMetrics />
        </div>
        <div className="analytics-grid">
          <div className="analytics-card">
            <StreamerAnalytics />
          </div>
          <div className="analytics-card">
            <RevenueAnalytics />
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
