import { serve } from "https://deno.land/std@0.168.0/http/server.ts"
import { createClient } from "https://esm.sh/@supabase/supabase-js@2"

const corsHeaders = {
  'Access-Control-Allow-Origin': '*',
  'Access-Control-Allow-Headers': 'authorization, x-client-info, apikey, content-type',
}

// APNs Configuration - Set these in Supabase Dashboard > Edge Functions > Secrets
const APNS_KEY_ID = Deno.env.get('APNS_KEY_ID')
const APNS_TEAM_ID = Deno.env.get('APNS_TEAM_ID')
const APNS_PRIVATE_KEY = Deno.env.get('APNS_P8_KEY')
const BUNDLE_ID = 'roboreabapp.productions'

interface PushPayload {
  user_id: string
  title: string
  body: string
  data?: Record<string, string>
}

async function createJWT(): Promise<string> {
  // Validate environment variables
  if (!APNS_KEY_ID) {
    throw new Error('APNS_KEY_ID is not set')
  }
  if (!APNS_TEAM_ID) {
    throw new Error('APNS_TEAM_ID is not set')
  }
  if (!APNS_PRIVATE_KEY) {
    throw new Error('APNS_P8_KEY is not set')
  }

  console.log('🔑 Creating JWT with Key ID:', APNS_KEY_ID, 'Team ID:', APNS_TEAM_ID)

  const header = {
    alg: 'ES256',
    kid: APNS_KEY_ID,
  }
  
  const now = Math.floor(Date.now() / 1000)
  const claims = {
    iss: APNS_TEAM_ID,
    iat: now,
  }
  
  // Import the private key - handle various formats
  let pemContents = APNS_PRIVATE_KEY
    // Remove PEM headers/footers
    .replace(/-----BEGIN PRIVATE KEY-----/g, '')
    .replace(/-----END PRIVATE KEY-----/g, '')
    // Handle literal \n characters (stored as string in env vars)
    .replace(/\\n/g, '')
    // Remove actual newlines and whitespace
    .replace(/[\r\n\s]/g, '')
  
  console.log('🔑 PEM contents length after cleanup:', pemContents.length)
  
  if (pemContents.length < 100) {
    throw new Error(`Private key seems too short (${pemContents.length} chars). Check APNS_P8_KEY format.`)
  }
  
  try {
    const binaryKey = Uint8Array.from(atob(pemContents), c => c.charCodeAt(0))
    console.log('🔑 Binary key length:', binaryKey.length)
    
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
    
    console.log('✅ JWT created successfully')
    return `${message}.${signatureB64}`
  } catch (keyError) {
    console.error('❌ Failed to import/sign with key:', keyError)
    throw new Error(`Key import failed: ${keyError.message}`)
  }
}

async function sendAPNS(deviceToken: string, title: string, body: string, data?: Record<string, string>): Promise<boolean> {
  try {
    console.log('📤 sendAPNS starting for token:', deviceToken.substring(0, 20) + '...')
    
    const jwt = await createJWT()
    console.log('✅ JWT created, length:', jwt.length)
    
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
    
    console.log('📦 Payload:', JSON.stringify(payload).substring(0, 200))
    
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
    
    console.log('🌐 Trying production APNs...')
    
    // Try production first
    let response = await fetch(productionUrl, {
      method: 'POST',
      headers,
      body: JSON.stringify(payload),
    })
    
    console.log('📡 Production response status:', response.status)
    
    if (!response.ok) {
      const prodError = await response.text()
      console.log('⚠️ Production APNs failed:', response.status, prodError)
      
      console.log('🌐 Trying sandbox APNs...')
      
      // Try sandbox as fallback (for development builds)
      response = await fetch(sandboxUrl, {
        method: 'POST',
        headers,
        body: JSON.stringify(payload),
      })
      
      console.log('📡 Sandbox response status:', response.status)
      
      if (!response.ok) {
        const sandboxError = await response.text()
        console.error('❌ Both APNs endpoints failed. Sandbox error:', response.status, sandboxError)
        return false
      }
      
      console.log('✅ Sandbox APNs succeeded!')
    } else {
      console.log('✅ Production APNs succeeded!')
    }
    
    return true
  } catch (error) {
    console.error('❌ Failed to send APNS:', error)
    console.error('❌ Error stack:', error.stack)
    return false
  }
}

serve(async (req) => {
  // Handle CORS
  if (req.method === 'OPTIONS') {
    return new Response('ok', { headers: corsHeaders })
  }

  // Early validation of APNs configuration
  const missingSecrets: string[] = []
  if (!APNS_KEY_ID) missingSecrets.push('APNS_KEY_ID')
  if (!APNS_TEAM_ID) missingSecrets.push('APNS_TEAM_ID')
  if (!APNS_PRIVATE_KEY) missingSecrets.push('APNS_P8_KEY')
  
  if (missingSecrets.length > 0) {
    console.error('❌ Missing APNs secrets:', missingSecrets.join(', '))
    console.log('Available env vars:', Object.keys(Deno.env.toObject()).filter(k => k.includes('APNS') || k.includes('P8')))
    return new Response(
      JSON.stringify({ 
        success: false, 
        error: `Missing APNs configuration: ${missingSecrets.join(', ')}` 
      }),
      { 
        status: 500,
        headers: { ...corsHeaders, 'Content-Type': 'application/json' } 
      }
    )
  }

  try {
    const supabaseClient = createClient(
      Deno.env.get('SUPABASE_URL') ?? '',
      Deno.env.get('SUPABASE_SERVICE_ROLE_KEY') ?? ''
    )

    const { user_id, title, body, data } = await req.json() as PushPayload

    console.log(`📱 Sending push to user: ${user_id}, title: ${title}`)
    console.log(`🔑 APNs config: KEY_ID=${APNS_KEY_ID?.substring(0,4)}..., TEAM_ID=${APNS_TEAM_ID?.substring(0,4)}..., KEY_LENGTH=${APNS_PRIVATE_KEY?.length}`)
    
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
    console.error('❌ Edge function error:', error)
    console.error('❌ Error stack:', error.stack)
    return new Response(
      JSON.stringify({ 
        success: false, 
        error: error.message,
        details: error.stack?.substring(0, 500) 
      }),
      { 
        status: 500,
        headers: { ...corsHeaders, 'Content-Type': 'application/json' } 
      }
    )
  }
})

