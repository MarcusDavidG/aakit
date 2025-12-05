import { defineConfig } from 'vite'
import react from '@vitejs/plugin-react'
import path from 'path'

export default defineConfig({
  plugins: [react()],
  resolve: {
    alias: {
      '@aakit/sdk': path.resolve(__dirname, '../../sdk/dist/index.mjs'),
    },
    preserveSymlinks: true,
  },
  optimizeDeps: {
    include: ['viem', '@aakit/sdk'],
  },
})
