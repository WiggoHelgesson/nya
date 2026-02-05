import { serve } from "https://deno.land/std@0.168.0/http/server.ts"
import { createClient } from "https://esm.sh/@supabase/supabase-js@2"

const corsHeaders = {
  'Access-Control-Allow-Origin': '*',
  'Access-Control-Allow-Headers': 'authorization, x-client-info, apikey, content-type',
}

interface DeclineInvitationRequest {
  invitationId: string
}

serve(async (req) => {
  // Handle CORS preflight
  if (req.method === 'OPTIONS') {
    return new Response('ok', { headers: corsHeaders })
  }

  try {
    // Get auth header
    const authHeader = req.headers.get('Authorization')
    if (!authHeader) {
      throw new Error('No authorization header')
    }

    // Create Supabase client with service role (bypasses RLS)
    const supabaseAdmin = createClient(
      Deno.env.get('SUPABASE_URL') ?? '',
      Deno.env.get('SUPABASE_SERVICE_ROLE_KEY') ?? ''
    )

    // Create client with user's JWT to verify auth
    const supabaseUser = createClient(
      Deno.env.get('SUPABASE_URL') ?? '',
      Deno.env.get('SUPABASE_ANON_KEY') ?? '',
      {
        global: {
          headers: { Authorization: authHeader }
        }
      }
    )

    // Verify user is authenticated
    const { data: { user }, error: userError } = await supabaseUser.auth.getUser()
    if (userError || !user) {
      console.error('Auth error:', userError)
      return new Response(
        JSON.stringify({ success: false, message: 'Unauthorized' }),
        { status: 401, headers: { ...corsHeaders, 'Content-Type': 'application/json' } }
      )
    }

    console.log(`✅ User authenticated: ${user.id}`)

    // Parse request body
    const { invitationId }: DeclineInvitationRequest = await req.json()
    console.log(`❌ Declining invitation: ${invitationId} for user: ${user.id}`)

    // 1. Fetch invitation
    const { data: invitation, error: inviteError } = await supabaseAdmin
      .from('coach_client_invitations')
      .select('id, coach_id, client_id, client_email, status')
      .eq('id', invitationId)
      .single()

    if (inviteError || !invitation) {
      console.error('Invitation not found:', inviteError)
      return new Response(
        JSON.stringify({ 
          success: false, 
          message: 'Inbjudan hittades inte'
        }),
        { status: 404, headers: { ...corsHeaders, 'Content-Type': 'application/json' } }
      )
    }

    // Verify invitation belongs to this user
    if (invitation.client_id !== user.id) {
      console.error(`Invitation ${invitationId} does not belong to user ${user.id}`)
      return new Response(
        JSON.stringify({ 
          success: false, 
          message: 'Denna inbjudan tillhör inte dig'
        }),
        { status: 403, headers: { ...corsHeaders, 'Content-Type': 'application/json' } }
      )
    }

    console.log(`✅ Invitation verified: coach=${invitation.coach_id}, client=${invitation.client_id}`)

    // 2. Update invitation status to declined
    const { error: updateError } = await supabaseAdmin
      .from('coach_client_invitations')
      .update({ status: 'declined' })
      .eq('id', invitationId)

    if (updateError) {
      console.error('Failed to update invitation:', updateError)
      throw updateError
    }

    console.log('✅ Invitation status updated to declined')

    // 3. Delete notification
    const { error: notifError } = await supabaseAdmin
      .from('notifications')
      .delete()
      .eq('user_id', invitation.client_id)
      .eq('type', 'coach_invitation')
      .eq('actor_id', invitation.coach_id)

    if (notifError) {
      console.error('Failed to delete notification:', notifError)
      // Don't throw - notification deletion is not critical
    } else {
      console.log('✅ Notification deleted')
    }

    console.log('✅ Invitation successfully declined')

    return new Response(
      JSON.stringify({ 
        success: true, 
        message: 'Inbjudan avböjd'
      }),
      { headers: { ...corsHeaders, 'Content-Type': 'application/json' } }
    )

  } catch (error) {
    console.error('Error declining invitation:', error)
    return new Response(
      JSON.stringify({ 
        success: false, 
        message: 'Något gick fel när inbjudan skulle avböjas',
        error: error.message 
      }),
      { 
        status: 500,
        headers: { ...corsHeaders, 'Content-Type': 'application/json' } 
      }
    )
  }
})
