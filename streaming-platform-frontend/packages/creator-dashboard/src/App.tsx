import React from 'react';
import { ChakraProvider } from '@chakra-ui/react';
import { BrowserRouter as Router, Routes, Route } from 'react-router-dom';
import { AuthProvider } from '@streaming/auth';
import { theme } from '@streaming/ui';
import { AppLayout, ErrorBoundary } from '@streaming/ui';
import { CreatorAnalytics } from './components/Analytics/CreatorAnalytics';
import { StreamHealth } from './components/Stream/StreamHealth';
import { ContentManager } from './components/Content/ContentManager';
import { RevenueTracking } from './components/Revenue/RevenueTracking';

function App() {
  return (
    <ChakraProvider theme={theme}>
      <ErrorBoundary
        onError={(error, errorInfo) => {
          // Log to monitoring service
          // Use secure logging to prevent log injection
          import('@streaming/shared').then(({ secureLogger }) => {
            secureLogger.error('Creator Dashboard Error', error, { 
              component: 'CreatorDashboard',
              errorInfo: errorInfo?.componentStack 
            });
          });
          // Send to error tracking service in production
        }}
      >
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
      </ErrorBoundary>
    </ChakraProvider>
  );
}

export default App;