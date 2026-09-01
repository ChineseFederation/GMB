import { fileURLToPath, URL } from 'node:url'
import { defineConfig } from 'vite'
import react from '@vitejs/plugin-react'
import tailwindcss from '@tailwindcss/vite'

const workspaceRoot = fileURLToPath(new URL('..', import.meta.url))

export default defineConfig(({ command }) => {
  if (command === 'build' && !process.env.CITIZENWEB_DIST && process.env.CI !== 'true') {
    throw new Error('本机编译必须由TataConsole提供CITIZENWEB_DIST，禁止恢复产品目录dist')
  }
  return {
    plugins: [react(), tailwindcss()],
    build: {
      outDir: process.env.CITIZENWEB_DIST || 'dist',
    },
    server: {
      fs: {
        allow: [workspaceRoot],
      },
    },
  }
})
