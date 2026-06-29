import { useCallback, useEffect, useState, type MouseEvent } from 'react'
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
  DataTable,
  Spinner,
} from '@shopify/polaris'
import { api, type MerchantStatus, type ProductRow } from './api'
import { RewardsPage } from './RewardsPage'
import { InvoicesPage } from './InvoicesPage'
import { formatMoney, formatNumber } from './format'

const SYNC_STATUS_LABEL: Record<string, string> = {
  success: 'Lyckades',
  completed: 'Klar',
  failed: 'Misslyckades',
  running: 'Pågår',
  partial: 'Delvis',
  pending: 'Väntar',
}

const PRODUCT_STATUS_LABEL: Record<string, string> = {
  active: 'Aktiv',
  draft: 'Utkast',
  archived: 'Arkiverad',
}

function translateStatus(map: Record<string, string>, value: string | null | undefined): string {
  if (!value) return '-'
  return map[value] ?? value
}

function OverviewPage() {
  const [status, setStatus] = useState<MerchantStatus | null>(null)
  const [products, setProducts] = useState<ProductRow[]>([])
  const [loading, setLoading] = useState(true)
  const [error, setError] = useState<string | null>(null)
  const [syncing, setSyncing] = useState(false)

  const load = useCallback(async () => {
    try {
      setLoading(true)
      // Auto-connect (token exchange) so opening the app establishes/refreshes
      // the offline token without an OAuth redirect. Best-effort.
      try {
        await api.connect()
      } catch (e) {
        console.warn('auto-connect failed:', e)
      }
      const s = await api.getStatus()
      setStatus(s)
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

  if (loading && !status) {
    return (
      <Page title="Översikt">
        <BlockStack inlineAlign="center">
          <Spinner accessibilityLabel="Laddar" size="large" />
        </BlockStack>
      </Page>
    )
  }

  const productRows = products.map((p) => [
    p.title,
    p.vendor ?? '-',
    p.product_type ?? '-',
    p.min_price != null ? formatMoney(p.min_price, p.currency) : '-',
    translateStatus(PRODUCT_STATUS_LABEL, p.status),
  ])

  return (
    <Page title="Översikt" subtitle={status?.shop}>
      <Layout>
        {error && (
          <Layout.Section>
            <Banner tone="critical" title="Något gick fel" onDismiss={() => setError(null)}>
              <p>{error}</p>
            </Banner>
          </Layout.Section>
        )}

        <Layout.Section>
          <Card>
            <BlockStack gap="400">
              <Text as="h2" variant="headingMd">
                Anslutningsstatus
              </Text>
              <InlineStack gap="300" wrap>
                <Badge tone={status?.connected ? 'success' : 'critical'}>
                  {status?.connected ? 'Ansluten' : 'Ej ansluten'}
                </Badge>
                <Badge tone={(status?.productsSynced ?? 0) > 0 ? 'success' : 'attention'}>
                  {`${formatNumber(status?.productsSynced ?? 0)} produkter synkade`}
                </Badge>
                <Badge tone={status?.webhooksActive ? 'success' : 'attention'}>
                  {status?.webhooksActive ? 'Webhooks aktiva' : 'Webhooks väntar'}
                </Badge>
              </InlineStack>
              {status?.lastSync && (
                <Text as="p" tone="subdued">
                  {`Senaste synk: ${translateStatus(SYNC_STATUS_LABEL, status.lastSync.status)} (${status.lastSync.items_processed} objekt)`}
                </Text>
              )}
              <InlineStack>
                <Button loading={syncing} onClick={onSync}>
                  Synka produkter nu
                </Button>
              </InlineStack>
            </BlockStack>
          </Card>
        </Layout.Section>

        <Layout.Section>
          <Card>
            <BlockStack gap="400">
              <Text as="h2" variant="headingMd">
                Synkade produkter
              </Text>
              {productRows.length ? (
                <DataTable
                  columnContentTypes={['text', 'text', 'text', 'numeric', 'text']}
                  headings={['Titel', 'Varumärke', 'Typ', 'Från', 'Status']}
                  rows={productRows}
                />
              ) : (
                <Text as="p" tone="subdued">
                  Inga produkter synkade ännu. Klicka på ”Synka produkter nu”.
                </Text>
              )}
            </BlockStack>
          </Card>
        </Layout.Section>
      </Layout>
    </Page>
  )
}

export function App() {
  const [path, setPath] = useState(window.location.pathname)

  useEffect(() => {
    const onPop = () => setPath(window.location.pathname)
    window.addEventListener('popstate', onPop)
    return () => window.removeEventListener('popstate', onPop)
  }, [])

  const navigate = useCallback((to: string) => {
    return (e: MouseEvent) => {
      e.preventDefault()
      window.history.pushState({}, '', to)
      setPath(to)
    }
  }, [])

  let CurrentPage = OverviewPage
  if (path.startsWith('/rewards')) CurrentPage = RewardsPage
  else if (path.startsWith('/invoices')) CurrentPage = InvoicesPage

  return (
    <>
      <ui-nav-menu>
        <a href="/" onClick={navigate('/')} rel="home">
          Översikt
        </a>
        <a href="/rewards" onClick={navigate('/rewards')}>
          Belöningar
        </a>
        <a href="/invoices" onClick={navigate('/invoices')}>
          Provision
        </a>
      </ui-nav-menu>
      <CurrentPage />
    </>
  )
}
