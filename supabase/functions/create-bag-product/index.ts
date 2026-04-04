import { serve } from "https://deno.land/std@0.168.0/http/server.ts"

const corsHeaders = {
  'Access-Control-Allow-Origin': '*',
  'Access-Control-Allow-Headers': 'authorization, x-client-info, apikey, content-type',
}

const SHOPIFY_STORE = 'up-down-gear-1b0k2'
const BAG_HANDLE = 'up-down-pasen'
const ADMIN_API = `https://${SHOPIFY_STORE}.myshopify.com/admin/api/2025-07`

async function getAdminToken(): Promise<string> {
  const clientId = Deno.env.get('SHOPIFY_CLIENT_ID') ?? ''
  const clientSecret = Deno.env.get('SHOPIFY_CLIENT_SECRET') ?? ''

  const res = await fetch(
    `https://${SHOPIFY_STORE}.myshopify.com/admin/oauth/access_token`,
    {
      method: 'POST',
      headers: { 'Content-Type': 'application/x-www-form-urlencoded' },
      body: new URLSearchParams({
        grant_type: 'client_credentials',
        client_id: clientId,
        client_secret: clientSecret,
      }),
    }
  )

  if (!res.ok) {
    const err = await res.text()
    throw new Error(`Auth failed: ${err}`)
  }

  const { access_token } = await res.json()
  return access_token
}

async function adminRest(token: string, path: string, options?: RequestInit) {
  return fetch(`${ADMIN_API}${path}`, {
    ...options,
    headers: {
      'Content-Type': 'application/json',
      'X-Shopify-Access-Token': token,
      ...(options?.headers || {}),
    },
  })
}

async function adminGraphQL(token: string, query: string, variables?: Record<string, unknown>) {
  const res = await fetch(
    `https://${SHOPIFY_STORE}.myshopify.com/admin/api/2025-07/graphql.json`,
    {
      method: 'POST',
      headers: {
        'Content-Type': 'application/json',
        'X-Shopify-Access-Token': token,
      },
      body: JSON.stringify({ query, variables }),
    }
  )
  return res.json()
}

serve(async (req) => {
  if (req.method === 'OPTIONS') {
    return new Response('ok', { headers: corsHeaders })
  }

  try {
    const token = await getAdminToken()

    // 1. Check for existing products with our handle (and clean up duplicates)
    const searchRes = await adminRest(token, `/products.json?handle=${BAG_HANDLE}&fields=id,handle,title,variants`)
    const searchData = await searchRes.json()
    const existing = searchData.products ?? []

    // Also look for duplicates with suffixed handles
    for (let i = 1; i <= 5; i++) {
      const dupeRes = await adminRest(token, `/products.json?handle=${BAG_HANDLE}-${i}&fields=id,handle`)
      const dupeData = await dupeRes.json()
      for (const dupe of (dupeData.products ?? [])) {
        console.log(`Deleting duplicate product ${dupe.id} (${dupe.handle})`)
        await adminRest(token, `/products/${dupe.id}.json`, { method: 'DELETE' })
      }
    }

    let product: any

    if (existing.length > 0) {
      product = existing[0]
      console.log(`Found existing product: ${product.id} (${product.handle})`)
    } else {
      const createRes = await adminRest(token, '/products.json', {
        method: 'POST',
        body: JSON.stringify({
          product: {
            title: 'Up&Down-påsen',
            handle: BAG_HANDLE,
            body_html: '<p>Sälj dina tränings- och livsstilsprodukter second hand med Up&Down-påsen. Fyll påsen med kläder och prylar du inte längre använder, skicka in den till oss och vi tar hand om resten.</p><p>19 kr per påse. Den första är gratis!</p>',
            vendor: 'Up&Down',
            product_type: 'Sell Bag',
            tags: 'sell-bag, second-hand, up-down-pasen',
            status: 'active',
            variants: [
              {
                title: 'Default',
                price: '19.00',
                sku: 'UD-BAG-001',
                inventory_management: null,
                requires_shipping: true,
                taxable: true,
              }
            ],
          }
        }),
      })

      if (!createRes.ok) {
        const err = await createRes.text()
        return new Response(
          JSON.stringify({ error: 'Failed to create product', details: err }),
          { status: 500, headers: { ...corsHeaders, 'Content-Type': 'application/json' } }
        )
      }

      const createData = await createRes.json()
      product = createData.product
      console.log(`Created product: ${product.id}`)
    }

    const productGid = `gid://shopify/Product/${product.id}`

    // 2. Discover all sales channels / publications
    const pubGraphQL = await adminGraphQL(token, `{
      publications(first: 20) {
        edges { node { id name } }
      }
    }`)

    let publications = pubGraphQL?.data?.publications?.edges ?? []
    let debugInfo: any = { graphql_publications: publications }

    // Fallback: try REST API for publications if GraphQL returned nothing
    if (publications.length === 0) {
      const pubRestRes = await adminRest(token, '/publications.json')
      const pubRestData = await pubRestRes.json()
      debugInfo.rest_publications_raw = pubRestData

      const restPubs = pubRestData?.publications ?? []
      publications = restPubs.map((p: any) => ({
        node: { id: `gid://shopify/Publication/${p.id}`, name: p.name }
      }))
      debugInfo.rest_publications = publications
    }

    // 3. Publish to all discovered channels
    let publishResult: any = null
    if (publications.length > 0) {
      const publicationInputs = publications.map((e: any) => ({
        publicationId: e.node.id,
      }))

      const result = await adminGraphQL(token, `
        mutation publishProduct($id: ID!, $input: [PublicationInput!]!) {
          publishablePublish(id: $id, input: $input) {
            publishable {
              availablePublicationsCount { count }
            }
            userErrors { field message }
          }
        }
      `, { id: productGid, input: publicationInputs })

      publishResult = result?.data?.publishablePublish
      debugInfo.publish_result = publishResult
    }

    // 4. Also try REST publish (set published_at) as additional fallback
    await adminRest(token, `/products/${product.id}.json`, {
      method: 'PUT',
      body: JSON.stringify({
        product: {
          id: product.id,
          published: true,
          published_at: new Date().toISOString(),
          published_scope: 'global',
        }
      }),
    })

    // 5. Verify: check what the product looks like now via GraphQL
    const verifyResult = await adminGraphQL(token, `{
      product(id: "${productGid}") {
        id
        title
        handle
        status
        publishedOnCurrentPublication
        resourcePublicationsV2(first: 10) {
          edges {
            node {
              publication { id name }
              isPublished
            }
          }
        }
      }
    }`)
    debugInfo.verify = verifyResult?.data?.product

    return new Response(
      JSON.stringify({
        success: true,
        product: {
          id: product.id,
          title: product.title,
          handle: product.handle,
          variant_id: product.variants?.[0]?.id,
          variant_price: product.variants?.[0]?.price,
        },
        debug: debugInfo,
      }),
      { status: 200, headers: { ...corsHeaders, 'Content-Type': 'application/json' } }
    )
  } catch (error) {
    console.error('Error:', error)
    return new Response(
      JSON.stringify({ error: error.message }),
      { status: 500, headers: { ...corsHeaders, 'Content-Type': 'application/json' } }
    )
  }
})
