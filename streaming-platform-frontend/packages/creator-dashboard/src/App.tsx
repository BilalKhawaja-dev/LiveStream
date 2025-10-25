import "./styles/creator-theme.css";
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
