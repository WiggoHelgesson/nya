import React from 'react'
import ReactDOM from 'react-dom/client'
import { AppProvider } from '@shopify/polaris'
import svTranslations from '@shopify/polaris/locales/sv.json'
import '@shopify/polaris/build/esm/styles.css'
import { App } from './App'

ReactDOM.createRoot(document.getElementById('root')!).render(
  <React.StrictMode>
    <AppProvider i18n={svTranslations}>
      <App />
    </AppProvider>
  </React.StrictMode>,
)
