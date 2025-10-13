import React from 'react';
import { Box, Container } from '@chakra-ui/react';

interface AppLayoutProps {
  children: React.ReactNode;
}

export const AppLayout: React.FC<AppLayoutProps> = ({ children }) => {
  return (
    <Box minH="100vh" bg="gray.50">
      <Container maxW="container.xl" py={8}>
        {children}
      </Container>
    </Box>
  );
};