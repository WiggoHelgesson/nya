import { serve } from "https://deno.land/std@0.168.0/http/server.ts"
import { createClient } from "https://esm.sh/@supabase/supabase-js@2"

const corsHeaders = {
  'Access-Control-Allow-Origin': '*',
  'Access-Control-Allow-Headers': 'authorization, x-client-info, apikey, content-type',
}

const BUNDLE_ID = 'roboreabapp.productions'

interface CoachInvitationRequest {
  invitation_id: string
  coach_id: string
  client_id: string
  coach_name: string // username from profiles
  coach_avatar_url?: string
}

async function createJWT(): Promise<string> {
  const APNS_KEY_ID = Deno.env.get('APNS_KEY_ID')
  const APNS_TEAM_ID = Deno.env.get('APNS_TEAM_ID')
  const APNS_PRIVATE_KEY = Deno.env.get('APNS_P8_KEY')

  if (!APNS_KEY_ID || !APNS_TEAM_ID || !APNS_PRIVATE_KEY) {
    throw new Error('Missing APNs secrets')
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
  
  const pemContents = APNS_PRIVATE_KEY
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
      
      // Try sandbox as fallback
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
  if (req.method === 'OPTIONS') {
    return new Response('ok', { headers: corsHeaders })
  }

  try {
    const supabase = createClient(
      Deno.env.get('SUPABASE_URL') ?? '',
      Deno.env.get('SUPABASE_SERVICE_ROLE_KEY') ?? ''
    )

    const { invitation_id, coach_id, client_id, coach_name, coach_avatar_url }: CoachInvitationRequest = await req.json()

    console.log(`📨 Sending coach invitation notification: ${coach_name} -> ${client_id}`)

    // 1. Get the client's device tokens
    const { data: tokens, error: tokensError } = await supabase
      .from('device_tokens')
      .select('token')
      .eq('user_id', client_id)
      .eq('is_active', true)

    if (tokensError) {
      console.error('Error fetching device tokens:', tokensError)
      throw tokensError
    }

    if (!tokens || tokens.length === 0) {
      console.log(`⚠️ No active device tokens found for client ${client_id}`)
      return new Response(
        JSON.stringify({ success: false, message: 'No device tokens found' }),
        { headers: { ...corsHeaders, 'Content-Type': 'application/json' } }
      )
    }

    console.log(`📱 Found ${tokens.length} device tokens for client`)

    // 2. Create a notification record in the notifications table
    const { error: notifError } = await supabase
      .from('notifications')
      .insert({
        user_id: client_id,
        type: 'coach_invitation',
        actor_id: coach_id,
        actor_username: coach_name,
        actor_avatar_url: coach_avatar_url,
        post_id: invitation_id, // Store invitation_id in post_id for navigation
        is_read: false
      })

    if (notifError) {
      console.error('Error creating notification record:', notifError)
      // Don't throw - still try to send push notification
    } else {
      console.log('✅ Notification record created')
    }

    // 3. Send push notifications to all devices
    const title = 'Coach-inbjudan'
    const body = `${coach_name} vill coacha dig! Tryck för att svara.`
    
    const data: Record<string, string> = {
      type: 'coach_invitation',
      invitation_id: invitation_id,
      coach_id: coach_id,
      coach_name: coach_name,
    }
    
    if (coach_avatar_url) {
      data.actor_avatar = coach_avatar_url
    }

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
