import { defineConfig } from 'vite'
import react from '@vitejs/plugin-react'

// Embedded Shopify app served at SHOPIFY_APP_URL. Builds a static SPA that
// talks to the Supabase `merchant-api` edge function using App Bridge session
// tokens.
export default defineConfig({
  plugins: [react()],
  server: { port: 5173 },
  build: { outDir: 'dist' },
})
