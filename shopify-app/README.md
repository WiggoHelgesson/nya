# Up&Down – embedded Shopify dashboard

The merchant-facing UI for the Up&Down Shopify public app. It renders **inside
Shopify Admin** (App Bridge) and talks to the Supabase `merchant-api` edge
function using Shopify session tokens.

## Stack

- Vite + React + TypeScript
- Shopify App Bridge (CDN script in `index.html`, provides `shopify.idToken()`)
- Shopify Polaris (UI components)

## Setup

```bash
cd shopify-app
cp .env.example .env   # set VITE_SHOPIFY_API_KEY + VITE_SHOPIFY_FUNCTIONS_BASE
npm install
npm run dev            # local dev (use `shopify app dev` for the embedded tunnel)
```

## How it works

1. After OAuth (`shopify-auth-callback`), the merchant is redirected here with
   `?shop=...&host=...`.
2. App Bridge mints a short-lived **session token** (`shopify.idToken()`).
3. `src/api.ts` sends that token as `Authorization: Bearer ...` to
   `merchant-api`, which verifies it (HS256 with the app secret) and scopes all
   data to the merchant's shop.
4. The dashboard shows connection status, products synced, webhook state, and a
   form to choose the discount + commission model.

## Deploy

- Build a static bundle: `npm run build` (outputs `dist/`).
- Host it at the `application_url` in [`shopify.app.toml`](./shopify.app.toml)
  (e.g. Vercel/Cloudflare Pages/Netlify). The host must serve over HTTPS and
  allow embedding in Shopify Admin (App Bridge handles framing).
- Push app config + webhooks to Shopify: `npm run shopify:deploy`.

See [`../supabase/docs/shopify-public-app-setup.md`](../supabase/docs/shopify-public-app-setup.md)
for the full backend setup.
