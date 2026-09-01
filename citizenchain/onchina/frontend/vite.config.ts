import { defineConfig } from 'vite';
import react from '@vitejs/plugin-react';

export default defineConfig(({ command }) => {
  if (command === 'build' && !process.env.ONCHINA_FRONTEND_DIST && process.env.CI !== 'true') {
    throw new Error('本机编译必须由TataConsole提供ONCHINA_FRONTEND_DIST，禁止恢复产品目录dist');
  }
  return {
  // OnChina 后端同源托管 dist,base 用相对路径以适配任意内网挂载路径。
  base: './',
  plugins: [react()],
  build: {
    outDir: process.env.ONCHINA_FRONTEND_DIST || 'dist'
  },
  server: {
    port: 5179,
    host: 'localhost',
    strictPort: true,
    proxy: {
      '/api': {
        target: 'https://onchina.local:8964',
        changeOrigin: true,
        secure: false
      }
    }
  },
  preview: {
    port: 5179,
    host: 'localhost',
    strictPort: true,
    proxy: {
      '/api': {
        target: 'https://onchina.local:8964',
        changeOrigin: true,
        secure: false
      }
    }
  }
  };
});
