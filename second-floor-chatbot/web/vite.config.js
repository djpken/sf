import { defineConfig } from 'vite';
import react from '@vitejs/plugin-react';

export default defineConfig({
  plugins: [react()],
  // 菜色圖沿用 sf-menu(與 prototype 相同)
  publicDir: '../../sf-menu',
  server: {
    host: '127.0.0.1',
    port: 5173,
    // 開發期把 /api 轉給後端 FastAPI,前端就能用相對路徑 fetch('/api/chat')
    proxy: {
      '/api': {
        target: 'http://127.0.0.1:8000',
        changeOrigin: true,
      },
    },
  },
});
