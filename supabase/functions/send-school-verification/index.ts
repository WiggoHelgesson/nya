import { serve } from "https://deno.land/std@0.168.0/http/server.ts"
import { createClient } from "https://esm.sh/@supabase/supabase-js@2"

const corsHeaders = {
  'Access-Control-Allow-Origin': '*',
  'Access-Control-Allow-Headers': 'authorization, x-client-info, apikey, content-type',
}

interface VerificationRequest {
  user_id: string
  email: string
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

    const { user_id, email }: VerificationRequest = await req.json()

    if (!user_id || !email) {
      throw new Error('Missing user_id or email')
    }

    const normalizedEmail = email.toLowerCase().trim()

    if (!normalizedEmail.endsWith('@elev.danderyd.se')) {
      return new Response(
        JSON.stringify({ success: false, error: 'Email must end with @elev.danderyd.se' }),
        { status: 400, headers: { ...corsHeaders, 'Content-Type': 'application/json' } }
      )
    }

    // Generate 6-digit code
    const code = String(Math.floor(100000 + Math.random() * 900000))
    const expiresAt = new Date(Date.now() + 10 * 60 * 1000).toISOString() // 10 minutes

    // Invalidate previous unused codes for this user
    await supabase
      .from('school_email_verifications')
      .update({ used: true })
      .eq('user_id', user_id)
      .eq('used', false)

    // Store the new code
    const { error: insertError } = await supabase
      .from('school_email_verifications')
      .insert({
        user_id,
        email: normalizedEmail,
        code,
        expires_at: expiresAt,
        used: false,
      })

    if (insertError) {
      console.error('Failed to store verification code:', insertError)
      throw new Error('Failed to create verification')
    }

    // Send email via Resend
    const RESEND_API_KEY = Deno.env.get('RESEND_API_KEY')
    if (!RESEND_API_KEY) {
      throw new Error('RESEND_API_KEY not configured')
    }

    const emailResponse = await fetch('https://api.resend.com/emails', {
      method: 'POST',
      headers: {
        'Authorization': `Bearer ${RESEND_API_KEY}`,
        'Content-Type': 'application/json',
      },
      body: JSON.stringify({
        from: 'Up & Down <noreply@upanddownapp.com>',
        to: [normalizedEmail],
        subject: 'Din verifieringskod för Up & Down',
        html: `
          <div style="font-family: -apple-system, BlinkMacSystemFont, 'Segoe UI', Roboto, sans-serif; max-width: 400px; margin: 0 auto; padding: 32px 24px; text-align: center;">
            <h1 style="font-size: 24px; font-weight: 700; margin-bottom: 8px;">Up & Down</h1>
            <p style="color: #666; font-size: 15px; margin-bottom: 32px;">Verifiera din skolmail</p>
            <div style="background: #f5f5f5; border-radius: 12px; padding: 24px; margin-bottom: 24px;">
              <p style="font-size: 14px; color: #666; margin-bottom: 8px;">Din verifieringskod:</p>
              <p style="font-size: 36px; font-weight: 800; letter-spacing: 6px; margin: 0;">${code}</p>
            </div>
            <p style="color: #999; font-size: 13px;">Koden är giltig i 10 minuter.</p>
          </div>
        `,
      }),
    })

    if (!emailResponse.ok) {
      const errorBody = await emailResponse.text()
      console.error('Resend API error:', errorBody)
      throw new Error('Failed to send verification email')
    }

    console.log(`✅ Verification code sent to ${normalizedEmail} for user ${user_id}`)

    return new Response(
      JSON.stringify({ success: true }),
      { headers: { ...corsHeaders, 'Content-Type': 'application/json' } }
    )

  } catch (error) {
    console.error('Error:', error.message)
    return new Response(
      JSON.stringify({ success: false, error: error.message }),
      { status: 500, headers: { ...corsHeaders, 'Content-Type': 'application/json' } }
    )
  }
})
