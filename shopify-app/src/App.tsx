import { useCallback, useEffect, useState } from 'react'
import {
  Page,
  Layout,
  Card,
  Badge,
  Text,
  BlockStack,
  InlineStack,
  Button,
  Banner,
  Select,
  TextField,
  DataTable,
  Spinner,
} from '@shopify/polaris'
import { api, type MerchantStatus, type ProductRow } from './api'

export function App() {
  const [status, setStatus] = useState<MerchantStatus | null>(null)
  const [products, setProducts] = useState<ProductRow[]>([])
  const [loading, setLoading] = useState(true)
  const [error, setError] = useState<string | null>(null)
  const [syncing, setSyncing] = useState(false)
  const [saving, setSaving] = useState(false)

  // Discount model form state
  const [discountType, setDiscountType] = useState('percentage')
  const [discountValue, setDiscountValue] = useState('15')
  const [commission, setCommission] = useState('5')

  const load = useCallback(async () => {
    try {
      setLoading(true)
      const s = await api.getStatus()
      setStatus(s)
      setCommission(String(Math.round((s.commissionRate ?? 0.05) * 100)))
      const dm = s.discountModel as { type?: string; value?: number }
      if (dm?.type) setDiscountType(dm.type)
      if (typeof dm?.value === 'number') setDiscountValue(String(dm.value))
      const p = await api.getProducts()
      setProducts(p.products)
      setError(null)
    } catch (e) {
      setError(String(e))
    } finally {
      setLoading(false)
    }
  }, [])

  useEffect(() => {
    load()
  }, [load])

  const onSync = useCallback(async () => {
    setSyncing(true)
    try {
      await api.triggerSync()
      setTimeout(load, 3000)
    } catch (e) {
      setError(String(e))
    } finally {
      setSyncing(false)
    }
  }, [load])

  const onSave = useCallback(async () => {
    setSaving(true)
    try {
      const rate = Number(commission) / 100
      const model = { type: discountType, value: Number(discountValue) }
      await api.saveSettings(rate, model)
      await api.saveCampaign({
        name: 'Up&Down default discount',
        type: discountType,
        value: Number(discountValue),
        scope: 'order',
        oncePerUser: true,
        usageLimit: 1,
        validityDays: 30,
        active: true,
      })
      await load()
    } catch (e) {
      setError(String(e))
    } finally {
      setSaving(false)
    }
  }, [commission, discountType, discountValue, load])

  if (loading && !status) {
    return (
      <Page title="Up&Down">
        <Spinner accessibilityLabel="Loading" size="large" />
      </Page>
    )
  }

  const productRows = products.map((p) => [
    p.title,
    p.vendor ?? '-',
    p.product_type ?? '-',
    p.min_price != null ? `${p.min_price} ${p.currency ?? ''}` : '-',
    p.status,
  ])

  return (
    <Page title="Up&Down" subtitle={status?.shop}>
      <Layout>
        {error && (
          <Layout.Section>
            <Banner tone="critical" title="Something went wrong">
              <p>{error}</p>
            </Banner>
          </Layout.Section>
        )}

        <Layout.Section>
          <Card>
            <BlockStack gap="400">
              <Text as="h2" variant="headingMd">
                Connection status
              </Text>
              <InlineStack gap="300">
                <Badge tone={status?.connected ? 'success' : 'critical'}>
                  {status?.connected ? 'Connected' : 'Not connected'}
                </Badge>
                <Badge tone={(status?.productsSynced ?? 0) > 0 ? 'success' : 'attention'}>
                  {`${status?.productsSynced ?? 0} products synced`}
                </Badge>
                <Badge tone={status?.webhooksActive ? 'success' : 'attention'}>
                  {status?.webhooksActive ? 'Webhooks active' : 'Webhooks pending'}
                </Badge>
              </InlineStack>
              {status?.lastSync && (
                <Text as="p" tone="subdued">
                  {`Last sync: ${status.lastSync.status} (${status.lastSync.items_processed} items)`}
                </Text>
              )}
              <InlineStack>
                <Button loading={syncing} onClick={onSync}>
                  Sync products now
                </Button>
              </InlineStack>
            </BlockStack>
          </Card>
        </Layout.Section>

        <Layout.Section>
          <Card>
            <BlockStack gap="400">
              <Text as="h2" variant="headingMd">
                Discount & commission model
              </Text>
              <Select
                label="Discount type"
                options={[
                  { label: 'Percentage off', value: 'percentage' },
                  { label: 'Fixed amount off', value: 'fixed_amount' },
                  { label: 'Free shipping', value: 'free_shipping' },
                ]}
                value={discountType}
                onChange={setDiscountType}
              />
              {discountType !== 'free_shipping' && (
                <TextField
                  label={discountType === 'percentage' ? 'Percent (%)' : 'Amount'}
                  type="number"
                  value={discountValue}
                  onChange={setDiscountValue}
                  autoComplete="off"
                />
              )}
              <TextField
                label="Up&Down commission (%)"
                type="number"
                value={commission}
                onChange={setCommission}
                autoComplete="off"
                helpText="Charged on orders placed with an Up&Down code."
              />
              <InlineStack>
                <Button variant="primary" loading={saving} onClick={onSave}>
                  Save
                </Button>
              </InlineStack>
            </BlockStack>
          </Card>
        </Layout.Section>

        <Layout.Section>
          <Card>
            <BlockStack gap="400">
              <Text as="h2" variant="headingMd">
                Synced products
              </Text>
              {productRows.length ? (
                <DataTable
                  columnContentTypes={['text', 'text', 'text', 'text', 'text']}
                  headings={['Title', 'Brand', 'Type', 'From', 'Status']}
                  rows={productRows}
                />
              ) : (
                <Text as="p" tone="subdued">
                  No products synced yet. Click "Sync products now".
                </Text>
              )}
            </BlockStack>
          </Card>
        </Layout.Section>
      </Layout>
    </Page>
  )
}
