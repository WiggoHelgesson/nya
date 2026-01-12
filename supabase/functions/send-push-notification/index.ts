import { serve } from "https://deno.land/std@0.168.0/http/server.ts"
import { createClient } from "https://esm.sh/@supabase/supabase-js@2"

const corsHeaders = {
  'Access-Control-Allow-Origin': '*',
  'Access-Control-Allow-Headers': 'authorization, x-client-info, apikey, content-type',
}

// APNs Configuration - Set these in Supabase Dashboard > Edge Functions > Secrets
const APNS_KEY_ID = Deno.env.get('APNS_KEY_ID')!
const APNS_TEAM_ID = Deno.env.get('APNS_TEAM_ID')!
const APNS_PRIVATE_KEY = Deno.env.get('APNS_P8_KEY')! // Your existing secret
const BUNDLE_ID = 'roboreabapp.productions'

interface PushPayload {
  user_id: string
  title: string
  body: string
  data?: Record<string, string>
}

async function createJWT(): Promise<string> {
  const header = {
    alg: 'ES256',
    kid: APNS_KEY_ID,
  }
  
  const now = Math.floor(Date.now() / 1000)
  const claims = {
    iss: APNS_TEAM_ID,
    iat: now,
  }
  
  // Import the private key
  const pemContents = APNS_PRIVATE_KEY
    .replace('-----BEGIN PRIVATE KEY-----', '')
    .replace('-----END PRIVATE KEY-----', '')
    .replace(/\s/g, '')
  
  const binaryKey = Uint8Array.from(atob(pemContents), c => c.charCodeAt(0))
  
  const key = await crypto.subtle.importKey(
    'pkcs8',
    binaryKey,
    { name: 'ECDSA', namedCurve: 'P-256' },
    false,
    ['sign']
  )
  
  // Create JWT
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
    
    // Check if we have an avatar to attach (triggers Notification Service Extension)
    const hasAvatar = data?.actor_avatar && data.actor_avatar.length > 0
    
    const payload = {
      aps: {
        alert: {
          title,
          body,
        },
        sound: 'default',
        badge: 1,
        // mutable-content: 1 allows the Notification Service Extension to modify the notification
        ...(hasAvatar && { 'mutable-content': 1 }),
      },
      // Include all data including actor_avatar for the extension to use
      ...data,
    }
    
    // Try production first, then sandbox if it fails
    // Production APNs URL (App Store builds)
    const productionUrl = `https://api.push.apple.com/3/device/${deviceToken}`
    // Sandbox APNs URL (Xcode development builds)
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
      
      // Try sandbox as fallback (for development builds)
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
      
      console.log('Sandbox APNs succeeded!')
    } else {
      console.log('Production APNs succeeded!')
    }
    
    return true
  } catch (error) {
    console.error('Failed to send APNS:', error)
    return false
  }
}

serve(async (req) => {
  // Handle CORS
  if (req.method === 'OPTIONS') {
    return new Response('ok', { headers: corsHeaders })
  }

  try {
    const supabaseClient = createClient(
      Deno.env.get('SUPABASE_URL') ?? '',
      Deno.env.get('SUPABASE_SERVICE_ROLE_KEY') ?? ''
    )

    const { user_id, title, body, data } = await req.json() as PushPayload

    console.log(`📱 Sending push to user: ${user_id}, title: ${title}`)
    
    // Get device tokens for the user
    const { data: tokens, error } = await supabaseClient
      .from('device_tokens')
      .select('token')
      .eq('user_id', user_id)
      .eq('is_active', true)

    if (error) {
      console.error('Database error fetching tokens:', error)
      throw error
    }

    console.log(`📱 Found ${tokens?.length || 0} device tokens for user`)

    if (!tokens || tokens.length === 0) {
      console.log(`⚠️ No active device tokens found for user ${user_id}`)
      return new Response(
        JSON.stringify({ success: false, message: 'No device tokens found' }),
        { headers: { ...corsHeaders, 'Content-Type': 'application/json' } }
      )
    }
    
    console.log(`📱 Device tokens: ${tokens.map(t => t.token.substring(0, 10) + '...').join(', ')}`)

    // Send to all user's devices
    console.log(`📱 Sending to ${tokens.length} devices...`)
    const results = await Promise.all(
      tokens.map(t => sendAPNS(t.token, title, body, data))
    )

    const successCount = results.filter(r => r).length
    console.log(`✅ Push notifications sent: ${successCount}/${tokens.length} succeeded`)

    return new Response(
      JSON.stringify({ 
        success: true, 
        sent: successCount,
        total: tokens.length 
      }),
      { headers: { ...corsHeaders, 'Content-Type': 'application/json' } }
    )

  } catch (error) {
    console.error('Error:', error)
    return new Response(
      JSON.stringify({ success: false, error: error.message }),
      { 
        status: 500,
        headers: { ...corsHeaders, 'Content-Type': 'application/json' } 
      }
    )
  }
})

