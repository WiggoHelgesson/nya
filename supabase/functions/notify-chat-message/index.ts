import { serve } from "https://deno.land/std@0.168.0/http/server.ts"
import { createClient } from "https://esm.sh/@supabase/supabase-js@2"

const corsHeaders = {
  'Access-Control-Allow-Origin': '*',
  'Access-Control-Allow-Headers': 'authorization, x-client-info, apikey, content-type',
}

const BUNDLE_ID = 'roboreabapp.productions'

interface ChatNotificationRequest {
  conversation_id: string
  sender_id: string
  message: string
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

    const { conversation_id, sender_id, message }: ChatNotificationRequest = await req.json()

    console.log(`💬 Chat notification: sender=${sender_id}, conversation=${conversation_id}`)

    // 1. Get conversation details to find the recipient
    const { data: conversation, error: convError } = await supabase
      .from('trainer_conversations')
      .select('trainer_id, user_id')
      .eq('id', conversation_id)
      .single()

    if (convError || !conversation) {
      console.error('Error fetching conversation:', convError)
      throw new Error('Conversation not found')
    }

    // 2. Get the trainer's user_id from trainer_profiles
    const { data: trainerProfile, error: trainerError } = await supabase
      .from('trainer_profiles')
      .select('user_id, name, avatar_url')
      .eq('id', conversation.trainer_id)
      .single()

    if (trainerError || !trainerProfile) {
      console.error('Error fetching trainer profile:', trainerError)
      throw new Error('Trainer profile not found')
    }

    // 3. Determine who is the recipient (the one who did NOT send the message)
    const trainerUserId = trainerProfile.user_id
    let recipientUserId: string
    let senderName: string
    let senderAvatar: string | null = null

    if (sender_id === trainerUserId) {
      // Trainer sent the message → notify the app user
      recipientUserId = conversation.user_id
      senderName = trainerProfile.name || 'Din tränare'
      senderAvatar = trainerProfile.avatar_url
      console.log(`📤 Trainer "${senderName}" sent message to user ${recipientUserId}`)
    } else {
      // App user sent the message → notify the trainer
      recipientUserId = trainerUserId
      
      // Get sender's username
      const { data: senderProfile } = await supabase
        .from('profiles')
        .select('username, avatar_url')
        .eq('id', sender_id)
        .single()
      
      senderName = senderProfile?.username || 'En användare'
      senderAvatar = senderProfile?.avatar_url
      console.log(`📤 User "${senderName}" sent message to trainer ${recipientUserId}`)
    }

    // 4. Get the recipient's device tokens
    const { data: tokens, error: tokensError } = await supabase
      .from('device_tokens')
      .select('token')
      .eq('user_id', recipientUserId)
      .eq('is_active', true)

    if (tokensError) {
      console.error('Error fetching device tokens:', tokensError)
      throw tokensError
    }

    if (!tokens || tokens.length === 0) {
      console.log(`⚠️ No active device tokens found for recipient ${recipientUserId}`)
      return new Response(
        JSON.stringify({ success: false, message: 'No device tokens found' }),
        { headers: { ...corsHeaders, 'Content-Type': 'application/json' } }
      )
    }

    console.log(`📱 Found ${tokens.length} device tokens for recipient`)

    // 5. Truncate message for notification preview
    const truncatedMessage = message.length > 100 ? message.substring(0, 100) + '...' : message

    // 6. Send push notifications to all devices
    const title = `${senderName}`
    const body = truncatedMessage

    const data: Record<string, string> = {
      type: 'trainer_chat_message',
      conversation_id: conversation_id,
      sender_id: sender_id,
    }

    if (senderAvatar) {
      data.actor_avatar = senderAvatar
    }

    const results = await Promise.all(
      tokens.map(t => sendAPNS(t.token, title, body, data))
    )

    const successCount = results.filter(r => r).length
    console.log(`✅ Chat push notifications sent: ${successCount}/${tokens.length} succeeded`)

    return new Response(
      JSON.stringify({
        success: true,
        sent: successCount,
        total: tokens.length,
      }),
      { headers: { ...corsHeaders, 'Content-Type': 'application/json' } }
    )

  } catch (error) {
    console.error('Error:', error)
    return new Response(
      JSON.stringify({ success: false, error: error.message }),
      {
        status: 500,
        headers: { ...corsHeaders, 'Content-Type': 'application/json' },
      }
    )
  }
})
