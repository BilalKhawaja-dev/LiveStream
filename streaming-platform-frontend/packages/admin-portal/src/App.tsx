import React from 'react';
import { ChakraProvider } from '@chakra-ui/react';
import { BrowserRouter as Router, Routes, Route } from 'react-router-dom';
import { AuthProvider } from '@streaming/auth';
import { theme } from '@streaming/ui';
import { AppLayout } from '@streaming/ui';
import { SystemDashboard } from './components/Monitoring/SystemDashboard';

function App() {
  return (
    <ChakraProvider theme={theme}>
      <AuthProvider>
        <Router>
          <AppLayout>
            <Routes>
              <Route path="/" element={<SystemDashboard />} />
              <Route path="/monitoring" element={<SystemDashboard />} />
            </Routes>
          </AppLayout>
        </Router>
      </AuthProvider>
    </ChakraProvider>
  );
}

export default App;