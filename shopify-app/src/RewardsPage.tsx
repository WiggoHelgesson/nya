import { useCallback, useEffect, useState } from 'react'
import {
  Page,
  Layout,
  Card,
  Text,
  BlockStack,
  InlineStack,
  Button,
  Banner,
  Select,
  TextField,
  DropZone,
  Thumbnail,
  Badge,
  Spinner,
  Box,
} from '@shopify/polaris'
import { api, type MerchantReward } from './api'
import { formatDate } from './format'

const DISCOUNT_OPTIONS = [5, 10, 15, 20, 25].map((v) => ({
  label: `${v}%`,
  value: String(v),
}))

const STATUS_LABEL: Record<MerchantReward['status'], { label: string; tone: 'success' | 'attention' | 'critical' }> = {
  active: { label: 'Aktiv', tone: 'success' },
  inactive: { label: 'Inaktiv', tone: 'critical' },
  draft: { label: 'Utkast', tone: 'attention' },
}

function fileToDataUrl(file: File): Promise<string> {
  return new Promise((resolve, reject) => {
    const reader = new FileReader()
    reader.onload = () => resolve(reader.result as string)
    reader.onerror = reject
    reader.readAsDataURL(file)
  })
}

export function RewardsPage() {
  const [rewards, setRewards] = useState<MerchantReward[]>([])
  const [loading, setLoading] = useState(true)
  const [error, setError] = useState<string | null>(null)
  const [success, setSuccess] = useState<string | null>(null)

  // Form state
  const [editingId, setEditingId] = useState<string | null>(null)
  const [title, setTitle] = useState('')
  const [description, setDescription] = useState('')
  const [discount, setDiscount] = useState('15')
  const [bannerUrl, setBannerUrl] = useState('')
  const [logoUrl, setLogoUrl] = useState('')
  const [uploadingBanner, setUploadingBanner] = useState(false)
  const [uploadingLogo, setUploadingLogo] = useState(false)
  const [publishing, setPublishing] = useState(false)
  const [formError, setFormError] = useState<string | null>(null)

  const load = useCallback(async () => {
    try {
      setLoading(true)
      // Auto-connect (token exchange) so the offline token is established/refreshed.
      try {
        await api.connect()
      } catch (e) {
        console.warn('auto-connect failed:', e)
      }
      const res = await api.getRewards()
      setRewards(res.rewards)
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

  const resetForm = useCallback(() => {
    setEditingId(null)
    setTitle('')
    setDescription('')
    setDiscount('15')
    setBannerUrl('')
    setLogoUrl('')
    setFormError(null)
  }, [])

  const onDropBanner = useCallback(async (_d: File[], accepted: File[]) => {
    const file = accepted[0]
    if (!file) return
    setUploadingBanner(true)
    setFormError(null)
    try {
      const dataUrl = await fileToDataUrl(file)
      const { url } = await api.uploadImage('banner', dataUrl)
      setBannerUrl(url)
    } catch (e) {
      setFormError(`Uppladdning av banner misslyckades: ${e}`)
    } finally {
      setUploadingBanner(false)
    }
  }, [])

  const onDropLogo = useCallback(async (_d: File[], accepted: File[]) => {
    const file = accepted[0]
    if (!file) return
    setUploadingLogo(true)
    setFormError(null)
    try {
      const dataUrl = await fileToDataUrl(file)
      const { url } = await api.uploadImage('logo', dataUrl)
      setLogoUrl(url)
    } catch (e) {
      setFormError(`Uppladdning av logga misslyckades: ${e}`)
    } finally {
      setUploadingLogo(false)
    }
  }, [])

  const onPublish = useCallback(async () => {
    setFormError(null)
    if (!title.trim() || !description.trim() || !bannerUrl || !logoUrl) {
      setFormError('Fyll i alla fält och ladda upp både en banner och en logga.')
      return
    }
    setPublishing(true)
    try {
      await api.saveReward({
        id: editingId ?? undefined,
        title: title.trim(),
        description: description.trim(),
        bannerImageUrl: bannerUrl,
        logoUrl,
        customerDiscountPercent: Number(discount),
      })
      setSuccess('Belöningen är publicerad och syns nu i Up&Down.')
      resetForm()
      await load()
    } catch (e) {
      setFormError(String(e))
    } finally {
      setPublishing(false)
    }
  }, [title, description, bannerUrl, logoUrl, discount, editingId, resetForm, load])

  const onEdit = useCallback((r: MerchantReward) => {
    setEditingId(r.id)
    setTitle(r.title)
    setDescription(r.description)
    setDiscount(String(r.customer_discount_percent))
    setBannerUrl(r.banner_image_url)
    setLogoUrl(r.logo_url)
    setSuccess(null)
    window.scrollTo({ top: 0, behavior: 'smooth' })
  }, [])

  const onUnpublish = useCallback(
    async (id: string) => {
      try {
        await api.unpublishReward(id)
        await load()
      } catch (e) {
        setError(String(e))
      }
    },
    [load],
  )

  return (
    <Page title="Belöningar" subtitle="Skapa belöningar som visas i Up&Down-appen">
      <Layout>
        {error && (
          <Layout.Section>
            <Banner tone="critical" title="Något gick fel" onDismiss={() => setError(null)}>
              <p>{error}</p>
            </Banner>
          </Layout.Section>
        )}
        {success && (
          <Layout.Section>
            <Banner tone="success" onDismiss={() => setSuccess(null)}>
              <p>{success}</p>
            </Banner>
          </Layout.Section>
        )}

        {/* Create / edit form */}
        <Layout.Section>
          <Card>
            <BlockStack gap="400">
              <Text as="h2" variant="headingMd">
                {editingId ? 'Redigera belöning' : 'Skapa en belöning'}
              </Text>

              {formError && (
                <Banner tone="warning">
                  <p>{formError}</p>
                </Banner>
              )}

              <BlockStack gap="200">
                <Text as="span" variant="bodyMd">
                  Bannerbild
                </Text>
                {bannerUrl ? (
                  <InlineStack gap="300" blockAlign="center">
                    <Thumbnail source={bannerUrl} alt="Banner" size="large" />
                    <Button variant="plain" onClick={() => setBannerUrl('')}>
                      Byt ut
                    </Button>
                  </InlineStack>
                ) : (
                  <Box minHeight="120px">
                    <DropZone accept="image/*" type="image" allowMultiple={false} onDrop={onDropBanner}>
                      {uploadingBanner ? (
                        <Box padding="400">
                          <InlineStack align="center">
                            <Spinner size="small" />
                          </InlineStack>
                        </Box>
                      ) : (
                        <DropZone.FileUpload actionTitle="Lägg till banner" />
                      )}
                    </DropZone>
                  </Box>
                )}
              </BlockStack>

              <BlockStack gap="200">
                <Text as="span" variant="bodyMd">
                  Logga
                </Text>
                {logoUrl ? (
                  <InlineStack gap="300" blockAlign="center">
                    <Thumbnail source={logoUrl} alt="Logga" size="medium" />
                    <Button variant="plain" onClick={() => setLogoUrl('')}>
                      Byt ut
                    </Button>
                  </InlineStack>
                ) : (
                  <Box minHeight="120px">
                    <DropZone accept="image/*" type="image" allowMultiple={false} onDrop={onDropLogo}>
                      {uploadingLogo ? (
                        <Box padding="400">
                          <InlineStack align="center">
                            <Spinner size="small" />
                          </InlineStack>
                        </Box>
                      ) : (
                        <DropZone.FileUpload actionTitle="Lägg till logga" />
                      )}
                    </DropZone>
                  </Box>
                )}
              </BlockStack>

              <TextField
                label="Belöningens titel"
                value={title}
                onChange={setTitle}
                autoComplete="off"
                placeholder="t.ex. 15% rabatt på all golfutrustning"
              />

              <Select
                label="Kundrabatt"
                options={DISCOUNT_OPTIONS}
                value={discount}
                onChange={setDiscount}
              />

              <TextField
                label="Företagsbeskrivning"
                value={description}
                onChange={setDescription}
                autoComplete="off"
                multiline={4}
                placeholder="Berätta för Up&Down-användarna om ert varumärke"
              />

              <Text as="p" tone="subdued">
                Up&Down provision: 5%
              </Text>

              <InlineStack gap="300">
                <Button variant="primary" loading={publishing} onClick={onPublish}>
                  {editingId ? 'Spara ändringar' : 'Publicera'}
                </Button>
                {editingId && (
                  <Button onClick={resetForm} disabled={publishing}>
                    Avbryt
                  </Button>
                )}
              </InlineStack>
            </BlockStack>
          </Card>
        </Layout.Section>

        {/* My rewards list */}
        <Layout.Section>
          <Card>
            <BlockStack gap="400">
              <Text as="h2" variant="headingMd">
                Mina belöningar
              </Text>
              {loading ? (
                <InlineStack align="center">
                  <Spinner size="small" />
                </InlineStack>
              ) : rewards.length === 0 ? (
                <Text as="p" tone="subdued">
                  Inga belöningar ännu. Skapa din första belöning ovan.
                </Text>
              ) : (
                <BlockStack gap="300">
                  {rewards.map((r) => {
                    const s = STATUS_LABEL[r.status] ?? STATUS_LABEL.draft
                    return (
                      <Box key={r.id} padding="300" borderColor="border" borderWidth="025" borderRadius="200">
                        <InlineStack gap="400" blockAlign="center" align="space-between">
                          <InlineStack gap="300" blockAlign="center">
                            <Thumbnail source={r.banner_image_url} alt={r.title} size="large" />
                            <Thumbnail source={r.logo_url} alt="Logga" size="small" />
                            <BlockStack gap="100">
                              <Text as="span" variant="bodyMd" fontWeight="semibold">
                                {r.title}
                              </Text>
                              <InlineStack gap="200" blockAlign="center">
                                <Badge tone="info">{`${r.customer_discount_percent}% rabatt`}</Badge>
                                <Badge tone={s.tone}>{s.label}</Badge>
                                <Text as="span" tone="subdued" variant="bodySm">
                                  {formatDate(r.created_at)}
                                </Text>
                              </InlineStack>
                            </BlockStack>
                          </InlineStack>
                          <InlineStack gap="200">
                            <Button onClick={() => onEdit(r)}>Redigera</Button>
                            {r.status === 'active' && (
                              <Button tone="critical" variant="secondary" onClick={() => onUnpublish(r.id)}>
                                Avpublicera
                              </Button>
                            )}
                          </InlineStack>
                        </InlineStack>
                      </Box>
                    )
                  })}
                </BlockStack>
              )}
            </BlockStack>
          </Card>
        </Layout.Section>
      </Layout>
    </Page>
  )
}
