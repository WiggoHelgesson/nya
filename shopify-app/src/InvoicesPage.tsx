import { useCallback, useEffect, useState, type ReactNode } from 'react'
import {
  Page,
  Layout,
  Card,
  Text,
  BlockStack,
  InlineGrid,
  Banner,
  Badge,
  DataTable,
  Spinner,
  Box,
} from '@shopify/polaris'
import { api, type CommissionStats, type CommissionPurchase, type CommissionStatus } from './api'
import { formatMoney, formatNumber, formatDate } from './format'

const STATUS_LABEL: Record<CommissionStatus, { label: string; tone: 'attention' | 'info' | 'success' }> = {
  pending: { label: 'Väntar', tone: 'attention' },
  invoiced: { label: 'Fakturerad', tone: 'info' },
  paid: { label: 'Betald', tone: 'success' },
}

function StatCard({ label, value }: { label: string; value: ReactNode }) {
  return (
    <Box background="bg-surface-secondary" padding="400" borderRadius="300">
      <BlockStack gap="100">
        <Text as="span" variant="bodySm" tone="subdued">
          {label}
        </Text>
        <Text as="span" variant="headingLg">
          {value}
        </Text>
      </BlockStack>
    </Box>
  )
}

export function InvoicesPage() {
  const [stats, setStats] = useState<CommissionStats | null>(null)
  const [purchases, setPurchases] = useState<CommissionPurchase[]>([])
  const [currency, setCurrency] = useState<string | null>(null)
  const [loading, setLoading] = useState(true)
  const [error, setError] = useState<string | null>(null)

  const load = useCallback(async () => {
    try {
      setLoading(true)
      // Auto-connect (token exchange) so the offline token is established/refreshed.
      try {
        await api.connect()
      } catch (e) {
        console.warn('auto-connect failed:', e)
      }
      const [s, p] = await Promise.all([api.getCommissionStats(), api.getCommissionPurchases()])
      setStats(s)
      setPurchases(p.purchases)
      setCurrency(p.currency ?? s.currency)
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

  const rows = purchases.map((p) => [
    formatDate(p.date),
    p.orderNumber ? `#${p.orderNumber}` : '-',
    p.rewardTitle ?? '-',
    formatMoney(p.orderValue, currency),
    formatMoney(p.commission, currency),
    (() => {
      const s = STATUS_LABEL[p.commissionStatus] ?? STATUS_LABEL.pending
      return <Badge tone={s.tone}>{s.label}</Badge>
    })(),
  ])

  return (
    <Page title="Provision" subtitle="Köp och provision från Up&Down">
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
                Sammanfattning
              </Text>
              <InlineGrid columns={{ xs: 1, sm: 2, md: 4 }} gap="400">
                <StatCard label="Köp" value={formatNumber(stats?.purchases ?? 0)} />
                <StatCard label="Total försäljning" value={formatMoney(stats?.totalSales ?? 0, currency)} />
                <StatCard label="Att betala (5%)" value={formatMoney(stats?.outstandingCommission ?? 0, currency)} />
                <StatCard label="Total provision" value={formatMoney(stats?.totalCommission ?? 0, currency)} />
              </InlineGrid>
              <Text as="p" tone="subdued" variant="bodySm">
                Up&Down tar 5% provision på köp som gjorts med en Up&Down-rabattkod.
              </Text>
            </BlockStack>
          </Card>
        </Layout.Section>

        <Layout.Section>
          <Card>
            <BlockStack gap="400">
              <Text as="h2" variant="headingMd">
                Köp
              </Text>
              {loading ? (
                <Box padding="400">
                  <BlockStack inlineAlign="center">
                    <Spinner size="small" />
                  </BlockStack>
                </Box>
              ) : rows.length === 0 ? (
                <Text as="p" tone="subdued">
                  Inga köp ännu. När en kund handlar med en Up&Down-rabattkod dyker köpet upp här.
                </Text>
              ) : (
                <DataTable
                  columnContentTypes={['text', 'text', 'text', 'numeric', 'numeric', 'text']}
                  headings={['Datum', 'Order', 'Belöning', 'Ordervärde', 'Provision (5%)', 'Status']}
                  rows={rows}
                />
              )}
            </BlockStack>
          </Card>
        </Layout.Section>
      </Layout>
    </Page>
  )
}
