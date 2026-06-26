// Thin client for the Supabase `merchant-api` edge function.
//
// Every request carries a fresh Shopify App Bridge session token (idToken),
// which merchant-api verifies (HS256, app secret) to derive the shop.

const FUNCTIONS_BASE =
  (import.meta.env.VITE_SHOPIFY_FUNCTIONS_BASE as string) ??
  'https://xebatkodviqgkpsbyuiv.supabase.co/functions/v1'

// The global `shopify` object is provided by the App Bridge CDN script.
declare global {
  // eslint-disable-next-line no-var
  var shopify: { idToken: () => Promise<string> } | undefined
}

async function sessionToken(): Promise<string> {
  if (!window.shopify) throw new Error('App Bridge not loaded')
  return await window.shopify.idToken()
}

async function request<T>(path: string, init: RequestInit = {}): Promise<T> {
  const token = await sessionToken()
  const res = await fetch(`${FUNCTIONS_BASE}/merchant-api${path}`, {
    ...init,
    headers: {
      'Content-Type': 'application/json',
      Authorization: `Bearer ${token}`,
      ...(init.headers ?? {}),
    },
  })
  if (!res.ok) {
    throw new Error(`API error ${res.status}: ${await res.text()}`)
  }
  return (await res.json()) as T
}

export interface MerchantStatus {
  shop: string
  connected: boolean
  status: string
  productsSynced: number
  lastSync: { status: string; items_processed: number; finished_at: string | null; type: string } | null
  webhooksActive: boolean
  requiredWebhooks: string[]
  commissionRate: number
  discountModel: Record<string, unknown>
  installedAt: string | null
}

export interface ProductRow {
  id: string
  title: string
  vendor: string | null
  product_type: string | null
  min_price: number | null
  currency: string | null
  status: string
  synced_at: string
}

export interface MerchantReward {
  id: string
  shop_domain: string
  title: string
  description: string
  banner_image_url: string
  logo_url: string
  customer_discount_percent: number
  updown_commission_percent: number
  status: 'draft' | 'active' | 'inactive'
  created_at: string
  updated_at: string
}

export interface RewardInput {
  id?: string
  title: string
  description: string
  bannerImageUrl: string
  logoUrl: string
  customerDiscountPercent: number
}

export const api = {
  getStatus: () => request<MerchantStatus>('/status'),
  getProducts: () => request<{ products: ProductRow[] }>('/products'),
  saveSettings: (commissionRate: number, discountModel: Record<string, unknown>) =>
    request<{ ok: boolean }>('/settings', {
      method: 'POST',
      body: JSON.stringify({ commissionRate, discountModel }),
    }),
  triggerSync: () => request<{ ok: boolean }>('/sync', { method: 'POST' }),
  saveCampaign: (campaign: Record<string, unknown>) =>
    request<{ ok: boolean; id: string }>('/campaign', {
      method: 'POST',
      body: JSON.stringify(campaign),
    }),

  uploadImage: (kind: 'banner' | 'logo', dataUrl: string) =>
    request<{ url: string }>('/upload-image', {
      method: 'POST',
      body: JSON.stringify({ kind, dataUrl }),
    }),
  getRewards: () => request<{ rewards: MerchantReward[] }>('/merchant-rewards'),
  saveReward: (reward: RewardInput) =>
    request<{ ok: boolean; reward: MerchantReward }>('/merchant-reward', {
      method: 'POST',
      body: JSON.stringify(reward),
    }),
  unpublishReward: (id: string) =>
    request<{ ok: boolean }>('/merchant-reward/unpublish', {
      method: 'POST',
      body: JSON.stringify({ id }),
    }),
}
