/// <reference types="vite/client" />

interface ImportMetaEnv {
  readonly VITE_SHOPIFY_API_KEY: string
  readonly VITE_SHOPIFY_FUNCTIONS_BASE: string
}

interface ImportMeta {
  readonly env: ImportMetaEnv
}

// App Bridge web component for the Shopify Admin left-hand navigation.
declare namespace JSX {
  interface IntrinsicElements {
    'ui-nav-menu': React.DetailedHTMLProps<React.HTMLAttributes<HTMLElement>, HTMLElement>
  }
}
