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

async function createJWT(): Promise<string> {
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

  const header = {
    alg: 'ES256',
    kid: APNS_KEY_ID.trim(),
  }
  
  const now = Math.floor(Date.now() / 1000)
  const claims = {
    iss: APNS_TEAM_ID.trim(),
    iat: now,
  }
  
  // Import the private key - handle various formats
  let pemContents = APNS_PRIVATE_KEY
    .replace(/-----BEGIN PRIVATE KEY-----/g, '')
    .replace(/-----END PRIVATE KEY-----/g, '')
    .replace(/\\n/g, '')
    .replace(/[\r\n\s]/g, '')
  
  const binaryKey = Uint8Array.from(atob(pemContents), c => c.charCodeAt(0))
  
  const key = await crypto.subtle.importKey(
    'pkcs8',
    binaryKey,
    { name: 'ECDSA', namedCurve: 'P-256' },
    false,
    ['sign']
  )
  
  const headerB64 = btoa(JSON.stringify(header)).replace(/=/g, '').replace(/\+/g, '-').replace(/\//g, '_')
  const claimsB64 = btoa(JSON.stringify(claims)).replace(/=/g, '').replace(/\+/g, '-').replace(/\//g, '_')
  const message = `${headerB64}.${claimsB64}`
  
  const signature = await crypto.subtle.sign(
    { name: 'ECDSA', hash: 'SHA-256' },
    key,
    new TextEncoder().encode(message)
  )
  
  const signatureB64 = btoa(String.fromCharCode(...new Uint8Array(signature)))
    .replace(/=/g, '').replace(/\+/g, '-').replace(/\//g, '_')
  
  return `${message}.${signatureB64}`
}

async function sendAPNS(deviceToken: string, title: string, body: string, data?: Record<string, string>): Promise<boolean> {
  try {
    const jwt = await createJWT()
    
    const hasAvatar = data?.actor_avatar && data.actor_avatar.length > 0
    
    const payload = {
      aps: {
        alert: {
          title,
          body,
        },
        sound: 'default',
        badge: 1,
        ...(hasAvatar && { 'mutable-content': 1 }),
      },
      ...data,
    }
    
    const productionUrl = `https://api.push.apple.com/3/device/${deviceToken}`
    const sandboxUrl = `https://api.sandbox.push.apple.com/3/device/${deviceToken}`
    
    const headers = {
      'Authorization': `bearer ${jwt}`,
      'apns-topic': BUNDLE_ID,
      'apns-push-type': 'alert',
      'apns-priority': '10',
    }
    
    // Try production first
    let response = await fetch(productionUrl, {
      method: 'POST',
      headers,
      body: JSON.stringify(payload),
    })
    
    if (!response.ok) {
      const prodError = await response.text()
      console.log('Production APNs failed, trying sandbox...', prodError)
      
      response = await fetch(sandboxUrl, {
        method: 'POST',
        headers,
        body: JSON.stringify(payload),
      })
      
      if (!response.ok) {
        const sandboxError = await response.text()
        console.error('Both APNs endpoints failed. Sandbox error:', sandboxError)
        return false
      }
    }
    
    return true
  } catch (error) {
    console.error('Failed to send APNS:', error)
    return false
  }
}

serve(async (req) => {
  console.log('🚀 send-push-notification v103 WIGGO CODE RUNNING')
  
  if (req.method === 'OPTIONS') {
    return new Response('ok', { headers: corsHeaders })
  }

  try {
    // Check APNs secrets availability
    const keyId = Deno.env.get('APNS_KEY_ID')
    const teamId = Deno.env.get('APNS_TEAM_ID')
    const p8Key = Deno.env.get('APNS_P8_KEY')
    console.log(`🔑 APNs secrets: KEY_ID=${keyId ? 'SET' : 'MISSING'}, TEAM_ID=${teamId ? 'SET' : 'MISSING'}, P8_KEY=${p8Key ? 'SET' : 'MISSING'}`)
    
    const supabaseClient = createClient(
      Deno.env.get('SUPABASE_URL') ?? '',
      Deno.env.get('SUPABASE_SERVICE_ROLE_KEY') ?? ''
    )

    const { user_id, title, body, data } = await req.json() as PushPayload

    // Validate user_id is a real UUID
    if (!user_id || user_id === 'undefined' || user_id === 'null' || user_id.length < 10) {
      console.error('Invalid user_id:', user_id)
      return new Response(
        JSON.stringify({ success: false, error: `Invalid user_id: "${user_id}". Must be a valid UUID.` }),
        { status: 400, headers: { ...corsHeaders, 'Content-Type': 'application/json' } }
      )
    }

    console.log(`📱 Push to user: ${user_id}, title: ${title}`)
    
    // Get device tokens for the user
    const { data: tokens, error } = await supabaseClient
      .from('device_tokens')
      .select('token')
      .eq('user_id', user_id)
      .eq('is_active', true)

    if (error) {
      console.error('Database error:', error)
      throw error
    }

    if (!tokens || tokens.length === 0) {
      return new Response(
        JSON.stringify({ success: false, message: 'No device tokens found' }),
        { headers: { ...corsHeaders, 'Content-Type': 'application/json' } }
      )
    }

    // Send to all user's devices
    const results = await Promise.all(
      tokens.map(t => sendAPNS(t.token, title, body, data))
    )

    const successCount = results.filter(r => r).length
    console.log(`✅ Push sent: ${successCount}/${tokens.length}`)

    return new Response(
      JSON.stringify({ 
        success: true, 
        sent: successCount,
        total: tokens.length 
      }),
      { headers: { ...corsHeaders, 'Content-Type': 'application/json' } }
    )

  } catch (error) {
    console.error('Edge function error:', error)
    return new Response(
      JSON.stringify({ 
        success: false, 
        error: error.message 
      }),
      { 
        status: 500,
        headers: { ...corsHeaders, 'Content-Type': 'application/json' } 
      }
    )
  }
})
