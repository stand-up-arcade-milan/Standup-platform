import { defineConfig } from 'vite'
import react from '@vitejs/plugin-react'
import { tanstackRouter } from '@tanstack/router-plugin/vite'

export default defineConfig({
  plugins: [
    // Generate the typed route tree before React processes the route modules.
    tanstackRouter({
      target: 'react',
      autoCodeSplitting: true,
      routesDirectory: './src/routes',
      generatedRouteTree: './src/routeTree.gen.ts',
    }),
    react(),
  ],
  server: {
    // Containers must listen on all interfaces; Compose publishes port 5173.
    host: '0.0.0.0',
    port: 5173,
    strictPort: true,
    proxy: {
      // Browser requests remain same-origin while Vite forwards them over Compose DNS.
      '/api': { target: 'http://backend:8080' },
      '/actuator': { target: 'http://backend:8080' },
    },
  },
})
