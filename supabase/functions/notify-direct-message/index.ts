import { serve } from "https://deno.land/std@0.168.0/http/server.ts"
import { createClient } from "https://esm.sh/@supabase/supabase-js@2"

const corsHeaders = {
  'Access-Control-Allow-Origin': '*',
  'Access-Control-Allow-Headers': 'authorization, x-client-info, apikey, content-type',
}

const BUNDLE_ID = 'roboreabapp.productions'

interface DirectMessageNotification {
  conversation_id: string
  sender_id: string
  message: string
  message_type: string  // 'text' or 'gym_invite'
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

// Activity type display names and verbs for notifications
function getActivityVerb(activityType: string | undefined): string {
  switch (activityType) {
    case 'running': return 'springa'
    case 'golf': return 'spela golf'
    case 'gym':
    default: return 'gymma'
  }
}

function getActivityDisplayName(activityType: string | undefined): string {
  switch (activityType) {
    case 'running': return 'Löppass'
    case 'golf': return 'Golfrunda'
    case 'gym':
    default: return 'Gympass'
  }
}

function getActivityPreposition(activityType: string | undefined): string {
  switch (activityType) {
    case 'running': return 'vid'
    case 'golf': return 'på'
    case 'gym':
    default: return 'på'
  }
}

// Format training invite date for notification body
function formatGymInviteBody(messageJson: string): string {
  try {
    const data = JSON.parse(messageJson)
    const date = data.date  // "2026-02-15"
    const time = data.time  // "18:00"
    const gym = data.gym
    const activityType = data.activity_type  // "gym", "running", "golf" or undefined

    // Parse the date
    const sessionDate = new Date(date + 'T00:00:00')
    const today = new Date()
    today.setHours(0, 0, 0, 0)
    const tomorrow = new Date(today)
    tomorrow.setDate(tomorrow.getDate() + 1)

    let dayStr: string
    if (sessionDate.getTime() === today.getTime()) {
      dayStr = 'idag'
    } else if (sessionDate.getTime() === tomorrow.getTime()) {
      dayStr = 'imorgon'
    } else {
      // Swedish day name
      const days = ['söndag', 'måndag', 'tisdag', 'onsdag', 'torsdag', 'fredag', 'lördag']
      const months = ['jan', 'feb', 'mar', 'apr', 'maj', 'jun', 'jul', 'aug', 'sep', 'okt', 'nov', 'dec']
      dayStr = `${days[sessionDate.getDay()]} ${sessionDate.getDate()} ${months[sessionDate.getMonth()]}`
    }

    const verb = getActivityVerb(activityType)
    const prep = getActivityPreposition(activityType)
    return `Kan du ${verb} ${dayStr} klockan ${time} ${prep} ${gym}?`
  } catch {
    return 'Nytt träningsförslag'
  }
}

// Extract activity type from the JSON message
function getActivityTypeFromMessage(messageJson: string): string | undefined {
  try {
    const data = JSON.parse(messageJson)
    return data.activity_type
  } catch {
    return undefined
  }
}

serve(async (req) => {
  console.log('🚀 notify-direct-message running')
  
  if (req.method === 'OPTIONS') {
    return new Response('ok', { headers: corsHeaders })
  }

  try {
    const supabase = createClient(
      Deno.env.get('SUPABASE_URL') ?? '',
      Deno.env.get('SUPABASE_SERVICE_ROLE_KEY') ?? ''
    )

    const { conversation_id, sender_id, message, message_type }: DirectMessageNotification = await req.json()

    console.log(`💬 DM notification: sender=${sender_id}, conversation=${conversation_id}, type=${message_type}`)

    // 1. Get sender profile
    const { data: senderProfile } = await supabase
      .from('profiles')
      .select('username, avatar_url')
      .eq('id', sender_id)
      .single()

    const senderName = senderProfile?.username || 'Någon'
    const senderAvatar = senderProfile?.avatar_url

    // 2. Get all other participants in the conversation (not the sender)
    const { data: participants, error: partError } = await supabase
      .from('direct_conversation_participants')
      .select('user_id, is_muted')
      .eq('conversation_id', conversation_id)
      .neq('user_id', sender_id)

    if (partError || !participants || participants.length === 0) {
      console.log('⚠️ No recipients found for conversation')
      return new Response(
        JSON.stringify({ success: false, message: 'No recipients found' }),
        { headers: { ...corsHeaders, 'Content-Type': 'application/json' } }
      )
    }

    // 3. Check if this is a group conversation
    const isGroup = participants.length > 1  // More than 1 other participant = group

    // 4. Build notification content based on message type
    let title: string
    let body: string

    if (message_type === 'gym_invite') {
      const activityType = getActivityTypeFromMessage(message)
      const activityName = getActivityDisplayName(activityType)
      title = isGroup ? `${senderName} föreslog ${activityName.toLowerCase()}` : `Nytt träningsförslag: ${activityName}`
      body = formatGymInviteBody(message)
    } else if (message_type === 'gym_invite_response') {
      // message contains "accepted" or "declined"
      const isAccepted = message === 'accepted'
      title = isAccepted ? `${senderName} kommer! 💪` : `${senderName} kan inte`
      body = isAccepted 
        ? `${senderName} har godkänt träningsförslaget`
        : `${senderName} har avböjt träningsförslaget`
    } else {
      title = `${senderName} skickade ett meddelande`
      // Show the actual message as subtitle
      body = message.length > 150 ? message.substring(0, 150) + '...' : message
    }

    // 5. Determine recipients
    // For gym_invite_response: notify ALL other participants (so everyone in the group sees who responded)
    // For all others: notify all participants except sender
    let recipientUserIds: string[] = []

    if (message_type === 'gym_invite_response') {
      // Notify all non-muted participants (excluding the responder)
      // In groups: everyone sees "X har godkänt/avböjt gympass-förslaget"
      for (const participant of participants) {
        if (!participant.is_muted) {
          recipientUserIds.push(participant.user_id)
        }
      }
    } else {
      for (const participant of participants) {
        if (!participant.is_muted) {
          recipientUserIds.push(participant.user_id)
        } else {
          console.log(`🔇 Skipping muted user ${participant.user_id}`)
        }
      }
    }

    let totalSent = 0
    let totalRecipients = recipientUserIds.length

    for (const userId of recipientUserIds) {
      // Get device tokens
      const { data: tokens } = await supabase
        .from('device_tokens')
        .select('token')
        .eq('user_id', userId)
        .eq('is_active', true)

      if (!tokens || tokens.length === 0) {
        console.log(`⚠️ No tokens for user ${userId}`)
        continue
      }

      const pushData: Record<string, string> = {
        type: message_type === 'gym_invite' ? 'gym_invite' : message_type === 'gym_invite_response' ? 'gym_invite' : 'direct_message',
        conversation_id: conversation_id,
        sender_id: sender_id,
      }

      if (senderAvatar) {
        pushData.actor_avatar = senderAvatar
      }

      const results = await Promise.all(
        tokens.map(t => sendAPNS(t.token, title, body, pushData))
      )

      totalSent += results.filter(r => r).length
      console.log(`📱 Sent to user ${userId}: ${results.filter(r => r).length}/${tokens.length}`)
    }

    console.log(`✅ DM push: ${totalSent} notifications sent to ${totalRecipients} recipients`)

    return new Response(
      JSON.stringify({
        success: true,
        sent: totalSent,
        recipients: totalRecipients,
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
