import "./styles/support-theme.css";
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
