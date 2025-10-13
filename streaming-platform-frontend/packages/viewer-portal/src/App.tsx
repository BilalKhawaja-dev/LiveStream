import React from 'react';
import { ChakraProvider } from '@chakra-ui/react';
import { BrowserRouter as Router, Routes, Route } from 'react-router-dom';
import { AuthProvider } from '@streaming/auth';
import { theme } from '@streaming/ui';
import { AppLayout } from '@streaming/ui';
import { ContentSearch } from './components/Search/ContentSearch';

function App() {
  return (
    <ChakraProvider theme={theme}>
      <AuthProvider>
        <Router>
          <AppLayout>
            <Routes>
              <Route path="/" element={<ContentSearch />} />
              <Route path="/search" element={<ContentSearch />} />
            </Routes>
          </AppLayout>
        </Router>
      </AuthProvider>
    </ChakraProvider>
  );
}

export default App;