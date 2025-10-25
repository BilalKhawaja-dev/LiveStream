import { defineConfig } from 'vite';
import react from '@vitejs/plugin-react';
import { resolve } from 'path';

export default defineConfig({
  plugins: [react()],
  base: '/admin-portal/',
  resolve: {
    alias: {
      '@streaming-platform/shared': resolve(__dirname, '../../shared'),
      '@streaming/shared': resolve(__dirname, '../shared/src'),
      '@streaming/ui': resolve(__dirname, '../ui/src'),
      '@streaming/auth': resolve(__dirname, '../auth/src'),
    },
  },
  server: {
    port: 3000,
    host: true,
  },
  build: {
    outDir: 'dist',
    sourcemap: false,
  },
});
