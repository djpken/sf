import { defineConfig } from 'vite';
import react from '@vitejs/plugin-react';

export default defineConfig({
  plugins: [react()],
  publicDir: '../sf-menu',
  // Bind IPv4 so `npm run qa` (which targets 127.0.0.1:5173) can reach the
  // dev/preview server without an IPv6/IPv4 mismatch.
  server: { host: '127.0.0.1', port: 5173 },
  preview: { host: '127.0.0.1', port: 5173 },
});
