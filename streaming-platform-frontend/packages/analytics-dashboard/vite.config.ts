import { defineConfig } from 'vite';
import react from '@vitejs/plugin-react';
import { resolve } from 'path';

export default defineConfig({
  plugins: [react()],
  resolve: {
    alias: {
      '@streaming/shared': resolve(__dirname, '../shared/src'),
      '@streaming/ui': resolve(__dirname, '../ui/src'),
      '@streaming/auth': resolve(__dirname, '../auth/src'),
    },
  },
  server: {
    port: 3005,
    host: true,
  },
  build: {
    outDir: 'dist',
    sourcemap: true,
  },
});