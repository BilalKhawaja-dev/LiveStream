import './styles/developer-theme.css';
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
    <div className="developer-console">
      <header className="developer-header">
        <h1>Developer Console</h1>
        <nav className="developer-nav">
          <a href="#api">API</a>
          <a href="#health">Health</a>
          <a href="#testing">Testing</a>
          <a href="#docs">Documentation</a>
        </nav>
      </header>
      
      <main className="developer-content">
        <div className="developer-card">
          <APIDashboard />
        </div>
        <div className="developer-grid">
          <div className="developer-card">
            <SystemHealth />
          </div>
          <div className="developer-card">
            <APITesting />
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
