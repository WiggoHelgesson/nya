/// <reference types="vite/client" />

interface ImportMetaEnv {
  readonly VITE_SHOPIFY_API_KEY: string
  readonly VITE_SHOPIFY_FUNCTIONS_BASE: string
}

interface ImportMeta {
  readonly env: ImportMetaEnv
}
