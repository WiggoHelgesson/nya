import { serve } from "https://deno.land/std@0.168.0/http/server.ts"
import { createClient } from "https://esm.sh/@supabase/supabase-js@2"

const corsHeaders = {
  'Access-Control-Allow-Origin': '*',
  'Access-Control-Allow-Headers': 'authorization, x-client-info, apikey, content-type',
}

const POSTNORD_API_URL = 'https://api2.postnord.com/rest/shipment/v3/edi/labels/pdf'

const RECEIVER_ADDRESS = {
  companyName: 'Up&Down',
  name: 'Up&Down Market',
  street: 'Klockargränd 14',
  postalCode: '18236',
  city: 'Danderyd',
  countryCode: 'SE',
  email: 'info@wiggio.se',
  phone: '+46732545402',
}

interface SenderInfo {
  name: string
  street: string
  postalCode: string
  city: string
  email: string
  phone?: string
  bagCount?: number
  userId?: string
}

serve(async (req) => {
  if (req.method === 'OPTIONS') {
    return new Response('ok', { headers: corsHeaders })
  }

  try {
    const apiKey = Deno.env.get('POSTNORD_API_KEY') ?? ''
    const customerNumber = Deno.env.get('POSTNORD_CUSTOMER_NUMBER') ?? ''

    if (!apiKey) {
      return new Response(
        JSON.stringify({ error: 'PostNord API key not configured' }),
        { status: 500, headers: { ...corsHeaders, 'Content-Type': 'application/json' } }
      )
    }

    const sender: SenderInfo = await req.json()

    if (!sender.name || !sender.street || !sender.postalCode || !sender.city || !sender.email) {
      return new Response(
        JSON.stringify({ error: 'Missing required sender fields: name, street, postalCode, city, email' }),
        { status: 400, headers: { ...corsHeaders, 'Content-Type': 'application/json' } }
      )
    }

    const bagCount = sender.bagCount ?? 1
    const messageId = `updown-${Date.now()}-${Math.random().toString(36).slice(2, 8)}`

    const shipmentInfo = {
      messageDate: new Date().toISOString(),
      messageFunction: "Instruction",
      messageId,
      application: {
        applicationId: 9999,
        name: "Up&Down Market",
        version: "1.0",
      },
      language: "SV",
      updateIndicator: "Original",
      testIndicator: false,
      shipment: [
        {
          shipmentIdentification: {
            shipmentId: messageId,
          },
          dateAndTimes: {
            loadingDate: new Date().toISOString(),
          },
          service: {
            basicServiceCode: "19",
            additionalServiceCode: ["C2"],
          },
          numberOfPackages: { value: bagCount },
          totalGrossWeight: { value: bagCount * 3, unit: "KGM" },
          parties: {
            consignor: {
              issuerCode: "Z12",
              ...(customerNumber ? {
                partyIdentification: {
                  partyId: customerNumber,
                  partyIdType: "160",
                },
              } : {}),
              party: {
                nameIdentification: {
                  name: sender.name,
                },
                address: {
                  streets: [sender.street],
                  postalCode: sender.postalCode,
                  city: sender.city,
                  countryCode: "SE",
                },
                contact: {
                  contactName: sender.name,
                  emailAddress: sender.email,
                  ...(sender.phone ? { smsNo: sender.phone } : {}),
                },
                legalEntity: { businessType: "P" },
              },
            },
            consignee: {
              issuerCode: "Z12",
              ...(customerNumber ? {
                partyIdentification: {
                  partyId: customerNumber,
                  partyIdType: "160",
                },
              } : {}),
              party: {
                nameIdentification: {
                  name: RECEIVER_ADDRESS.name,
                  companyName: RECEIVER_ADDRESS.companyName,
                },
                address: {
                  streets: [RECEIVER_ADDRESS.street],
                  postalCode: RECEIVER_ADDRESS.postalCode,
                  city: RECEIVER_ADDRESS.city,
                  countryCode: RECEIVER_ADDRESS.countryCode,
                },
                contact: {
                  contactName: RECEIVER_ADDRESS.name,
                  emailAddress: RECEIVER_ADDRESS.email,
                  phoneNo: RECEIVER_ADDRESS.phone,
                },
                legalEntity: { businessType: "B" },
              },
            },
          },
          goodsItem: [
            {
              goodsDescription: "Up&Down-påse med second hand kläder",
              packageTypeCode: "PC",
              numberOfPackageTypeCodeItems: { value: bagCount },
              items: [
                {
                  itemIdentification: {
                    itemId: `${messageId}-1`,
                  },
                  grossWeight: { value: bagCount * 3, unit: "KGM" },
                  dimensions: {
                    height: { value: 40, unit: "CMT" },
                    width: { value: 35, unit: "CMT" },
                    length: { value: 50, unit: "CMT" },
                  },
                },
              ],
            },
          ],
        },
      ],
    }

    const params = new URLSearchParams({
      apikey: apiKey,
      generateQrcodeImage: 'true',
      emailQRcode: 'true',
      smsQRcode: sender.phone ? 'true' : 'false',
      locale: 'sv',
      functionality: 'STANDARD',
      definePrintout: 'ALL',
      qrCodeScale: '9',
      qrCodeFormat: 'PNG',
    })

    const postnordUrl = `${POSTNORD_API_URL}?${params.toString()}`

    console.log('Calling PostNord API:', postnordUrl)
    console.log('Shipment info:', JSON.stringify(shipmentInfo, null, 2))

    const response = await fetch(postnordUrl, {
      method: 'POST',
      headers: { 'Content-Type': 'application/json' },
      body: JSON.stringify(shipmentInfo),
    })

    const responseText = await response.text()
    console.log('PostNord response status:', response.status)
    console.log('PostNord response:', responseText.slice(0, 1000))

    if (!response.ok) {
      return new Response(
        JSON.stringify({
          error: 'PostNord API error',
          status: response.status,
          details: responseText.slice(0, 500),
        }),
        { status: response.status, headers: { ...corsHeaders, 'Content-Type': 'application/json' } }
      )
    }

    const data = JSON.parse(responseText)

    const bookingId = data?.bookingResponse?.bookingId
    const idInfo = data?.bookingResponse?.idInformation?.[0]
    const trackingUrl = idInfo?.urls?.find((u: any) => u.type === 'TRACKING')?.url
    const itemId = idInfo?.ids?.[0]?.value

    const labelPrintout = data?.labelPrintout?.[0]?.printout
    const labelUrl = labelPrintout?.uriResource || labelPrintout?.uriStoreLabel
    const labelBase64 = labelPrintout?.dataValue || labelPrintout?.data

    let bagCode: string | null = null
    let bagId: string | null = null

    if (sender.userId) {
      try {
        const supabaseUrl = Deno.env.get('SUPABASE_URL') ?? ''
        const supabaseServiceKey = Deno.env.get('SUPABASE_SERVICE_ROLE_KEY') ?? ''
        const supabase = createClient(supabaseUrl, supabaseServiceKey)

        const { data: bagData, error: bagError } = await supabase
          .rpc('create_seller_bag', {
            p_user_id: sender.userId,
            p_quantity: bagCount,
            p_sender_name: sender.name,
            p_sender_email: sender.email,
            p_tracking_url: trackingUrl || null,
          })

        if (bagError) {
          console.error('Failed to create seller_bag:', bagError)
        } else if (bagData && bagData.length > 0) {
          bagCode = bagData[0].bag_code
          bagId = bagData[0].bag_id
          console.log(`Created seller_bag: ${bagCode} (${bagId})`)
        }
      } catch (bagErr) {
        console.error('Error creating seller_bag:', bagErr)
      }
    }

    return new Response(
      JSON.stringify({
        success: true,
        bookingId,
        itemId,
        trackingUrl,
        labelUrl,
        hasLabelData: !!labelBase64,
        bagCode,
        bagId,
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
