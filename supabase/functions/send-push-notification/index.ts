import { serve } from "https://deno.land/std@0.168.0/http/server.ts"
import { createClient } from "https://esm.sh/@supabase/supabase-js@2"

const corsHeaders = {
  'Access-Control-Allow-Origin': '*',
  'Access-Control-Allow-Headers': 'authorization, x-client-info, apikey, content-type',
}

const BUNDLE_ID = 'roboreabapp.productions'

interface PushPayload {
  user_id: string
  title: string
  body: string
  data?: Record<string, string>
}

// Safe base64url encode that doesn't use spread operator (avoids stack overflow)
function uint8ArrayToBase64url(arr: Uint8Array): string {
  let binary = ''
  for (let i = 0; i < arr.length; i++) {
    binary += String.fromCharCode(arr[i])
  }
  return btoa(binary).replace(/=/g, '').replace(/\+/g, '-').replace(/\//g, '_')
}

function base64url(str: string): string {
  return btoa(str).replace(/=/g, '').replace(/\+/g, '-').replace(/\//g, '_')
}

// Cache the JWT (valid for ~55 min)
let cachedJWT: string | null = null
let cachedJWTTime = 0

async function createJWT(): Promise<string> {
  const now = Math.floor(Date.now() / 1000)
  if (cachedJWT && (now - cachedJWTTime) < 3300) {
    return cachedJWT
  }

  const APNS_KEY_ID = Deno.env.get('APNS_KEY_ID')
  const APNS_TEAM_ID = Deno.env.get('APNS_TEAM_ID')
  const APNS_PRIVATE_KEY = Deno.env.get('APNS_P8_KEY')

  if (!APNS_KEY_ID || !APNS_TEAM_ID || !APNS_PRIVATE_KEY) {
    const missing = []
    if (!APNS_KEY_ID) missing.push('APNS_KEY_ID')
    if (!APNS_TEAM_ID) missing.push('APNS_TEAM_ID')
    if (!APNS_PRIVATE_KEY) missing.push('APNS_P8_KEY')
    throw new Error(`Missing APNs secrets: ${missing.join(', ')}`)
  }

  const keyId = APNS_KEY_ID.trim()
  const teamId = APNS_TEAM_ID.trim()

  console.log(`🔑 KEY_ID=${keyId.substring(0, 4)}..., TEAM_ID=${teamId}`)

  // Clean the P8 key: remove PEM headers, escaped newlines, whitespace
  let pemContents = APNS_PRIVATE_KEY
  pemContents = pemContents.replace(/-----BEGIN PRIVATE KEY-----/g, '')
  pemContents = pemContents.replace(/-----END PRIVATE KEY-----/g, '')
  pemContents = pemContents.replace(/\\n/g, '')
  pemContents = pemContents.replace(/[\r\n\s]/g, '')

  console.log(`🔑 P8 base64 length: ${pemContents.length}`)

  // Decode base64 to binary
  let binaryStr: string
  try {
    binaryStr = atob(pemContents)
  } catch (e) {
    throw new Error(`P8 base64 decode failed: ${(e as Error).message}. Length: ${pemContents.length}, first 20 chars: ${pemContents.substring(0, 20)}`)
  }

  const binaryKey = new Uint8Array(binaryStr.length)
  for (let i = 0; i < binaryStr.length; i++) {
    binaryKey[i] = binaryStr.charCodeAt(i)
  }
  console.log(`🔑 P8 binary: ${binaryKey.length} bytes`)

  // Import the ECDSA P-256 private key
  let key: CryptoKey
  try {
    key = await crypto.subtle.importKey(
      'pkcs8',
      binaryKey,
      { name: 'ECDSA', namedCurve: 'P-256' },
      false,
      ['sign']
    )
  } catch (e) {
    throw new Error(`P8 import failed: ${(e as Error).message}. Binary length: ${binaryKey.length}`)
  }

  // Build JWT
  const headerB64 = base64url(JSON.stringify({ alg: 'ES256', kid: keyId }))
  const claimsB64 = base64url(JSON.stringify({ iss: teamId, iat: now }))
  const message = `${headerB64}.${claimsB64}`

  let signature: ArrayBuffer
  try {
    signature = await crypto.subtle.sign(
      { name: 'ECDSA', hash: 'SHA-256' },
      key,
      new TextEncoder().encode(message)
    )
  } catch (e) {
    throw new Error(`JWT signing failed: ${(e as Error).message}`)
  }

  // Use safe base64url encoding (no spread operator)
  const signatureB64 = uint8ArrayToBase64url(new Uint8Array(signature))

  const jwt = `${message}.${signatureB64}`
  cachedJWT = jwt
  cachedJWTTime = now
  console.log(`✅ JWT created (sig ${new Uint8Array(signature).length} bytes)`)

  return jwt
}

async function sendAPNS(deviceToken: string, title: string, body: string, data?: Record<string, string>): Promise<boolean> {
  try {
    const jwt = await createJWT()

    const hasAvatar = data?.actor_avatar && data.actor_avatar.length > 0

    const payload = {
      aps: {
        alert: { title, body },
        sound: 'default',
        badge: 1,
        ...(hasAvatar && { 'mutable-content': 1 }),
      },
      ...data,
    }

    const tokenPreview = deviceToken.substring(0, 8) + '...'
    console.log(`📤 APNs -> ${tokenPreview}`)

    const headers: Record<string, string> = {
      'Authorization': `bearer ${jwt}`,
      'apns-topic': BUNDLE_ID,
      'apns-push-type': 'alert',
      'apns-priority': '10',
    }

    // Try production first
    const prodUrl = `https://api.push.apple.com/3/device/${deviceToken}`
    let response = await fetch(prodUrl, {
      method: 'POST',
      headers,
      body: JSON.stringify(payload),
    })

    if (response.ok) {
      console.log(`✅ APNs prod OK for ${tokenPreview}`)
      return true
    }

    const prodStatus = response.status
    const prodError = await response.text()
    console.log(`⚠️ Prod failed (${prodStatus}): ${prodError}`)

    // Try sandbox
    const sandboxUrl = `https://api.sandbox.push.apple.com/3/device/${deviceToken}`
    response = await fetch(sandboxUrl, {
      method: 'POST',
      headers,
      body: JSON.stringify(payload),
    })

    if (response.ok) {
      console.log(`✅ APNs sandbox OK for ${tokenPreview}`)
      return true
    }

    const sbStatus = response.status
    const sbError = await response.text()
    console.error(`❌ Both failed. Prod=${prodStatus} ${prodError}, Sandbox=${sbStatus} ${sbError}`)
    return false
  } catch (error) {
    console.error('❌ sendAPNS error:', (error as Error).message || error)
    return false
  }
}

serve(async (req) => {
  console.log('🚀 send-push-notification v107')

  if (req.method === 'OPTIONS') {
    return new Response('ok', { headers: corsHeaders })
  }

  try {
    const supabaseClient = createClient(
      Deno.env.get('SUPABASE_URL') ?? '',
      Deno.env.get('SUPABASE_SERVICE_ROLE_KEY') ?? ''
    )

    let payload: PushPayload
    try {
      payload = await req.json() as PushPayload
    } catch (e) {
      console.error('Failed to parse request body:', (e as Error).message)
      return new Response(
        JSON.stringify({ success: false, error: 'Invalid JSON body' }),
        { status: 400, headers: { ...corsHeaders, 'Content-Type': 'application/json' } }
      )
    }

    const { user_id, title, body, data } = payload

    if (!user_id || user_id === 'undefined' || user_id === 'null' || user_id.length < 10) {
      console.error('Invalid user_id:', user_id)
      return new Response(
        JSON.stringify({ success: false, error: `Invalid user_id: "${user_id}"` }),
        { status: 400, headers: { ...corsHeaders, 'Content-Type': 'application/json' } }
      )
    }

    console.log(`📱 Push to ${user_id}: "${title}"`)

    const { data: tokens, error } = await supabaseClient
      .from('device_tokens')
      .select('token')
      .eq('user_id', user_id)
      .eq('is_active', true)

    if (error) {
      console.error('DB error:', error)
      throw new Error(`Database error: ${error.message}`)
    }

    if (!tokens || tokens.length === 0) {
      console.log('No device tokens found')
      return new Response(
        JSON.stringify({ success: false, message: 'No device tokens' }),
        { headers: { ...corsHeaders, 'Content-Type': 'application/json' } }
      )
    }

    console.log(`📱 Found ${tokens.length} token(s)`)

    const results = await Promise.all(
      tokens.map(t => sendAPNS(t.token, title, body, data))
    )

    const successCount = results.filter(r => r).length
    console.log(`✅ Sent: ${successCount}/${tokens.length}`)

    return new Response(
      JSON.stringify({ success: true, sent: successCount, total: tokens.length }),
      { headers: { ...corsHeaders, 'Content-Type': 'application/json' } }
    )
  } catch (error) {
    const msg = (error as Error).message || String(error)
    console.error('❌ Edge function error:', msg)
    return new Response(
      JSON.stringify({ success: false, error: msg }),
      { status: 500, headers: { ...corsHeaders, 'Content-Type': 'application/json' } }
    )
  }
})
