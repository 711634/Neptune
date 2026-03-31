import { defineConfig } from 'vite'
import react from '@vitejs/plugin-react'

export default defineConfig({
  plugins: [react()],
  build: {
    target: ['es2021'],
    minify: 'terser',
    sourcemap: false,
  },
  server: {
    strictPort: true,
    port: 5173,
    host: '127.0.0.1',
  },
})
