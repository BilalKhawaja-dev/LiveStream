import React from 'react';
import { ChakraProvider } from '@chakra-ui/react';
import { BrowserRouter as Router, Routes, Route } from 'react-router-dom';
import { AuthProvider } from '@streaming/auth';
import { theme } from '@streaming/ui';
import { AppLayout } from '@streaming/ui';
import { CreatorAnalytics } from './components/Analytics/CreatorAnalytics';
import { StreamHealth } from './components/Stream/StreamHealth';
import { ContentManager } from './components/Content/ContentManager';
import { RevenueTracking } from './components/Revenue/RevenueTracking';

function App() {
  return (
    <ChakraProvider theme={theme}>
      <AuthProvider>
        <Router>
          <AppLayout>
            <Routes>
              <Route path="/" element={<CreatorAnalytics />} />
              <Route path="/analytics" element={<CreatorAnalytics />} />
              <Route path="/stream" element={<StreamHealth />} />
              <Route path="/content" element={<ContentManager />} />
              <Route path="/revenue" element={<RevenueTracking />} />
            </Routes>
          </AppLayout>
        </Router>
      </AuthProvider>
    </ChakraProvider>
  );
}

export default App;