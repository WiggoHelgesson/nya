import { serve } from "https://deno.land/std@0.168.0/http/server.ts"
import { createClient } from "https://esm.sh/@supabase/supabase-js@2"

const corsHeaders = {
  'Access-Control-Allow-Origin': '*',
  'Access-Control-Allow-Headers': 'authorization, x-client-info, apikey, content-type',
}

interface AcceptInvitationRequest {
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
    const { invitationId }: AcceptInvitationRequest = await req.json()
    console.log(`🎯 Accepting invitation: ${invitationId} for user: ${user.id}`)

    // 1. Fetch invitation (without .single() to get better error info)
    const { data: invitations, error: inviteError } = await supabaseAdmin
      .from('coach_client_invitations')
      .select('id, coach_id, client_id, client_email, status')
      .eq('id', invitationId)

    if (inviteError) {
      console.error('Database error fetching invitation:', inviteError)
      return new Response(
        JSON.stringify({ 
          success: false, 
          message: 'Databasfel vid hämtning av inbjudan',
          error: inviteError.message
        }),
        { status: 500, headers: { ...corsHeaders, 'Content-Type': 'application/json' } }
      )
    }

    if (!invitations || invitations.length === 0) {
      console.error('Invitation not found in database')
      return new Response(
        JSON.stringify({ 
          success: false, 
          message: 'Inbjudan hittades inte',
          error: 'Invitation not found'
        }),
        { status: 404, headers: { ...corsHeaders, 'Content-Type': 'application/json' } }
      )
    }

    const invitation = invitations[0]
    console.log(`Found invitation: status=${invitation.status}, client_id=${invitation.client_id}`)

    // Verify invitation belongs to this user
    if (invitation.client_id !== user.id) {
      console.error(`Invitation ${invitationId} does not belong to user ${user.id}`)
      return new Response(
        JSON.stringify({ 
          success: false, 
          message: 'Denna inbjudan tillhör inte dig',
          error: 'Unauthorized'
        }),
        { status: 403, headers: { ...corsHeaders, 'Content-Type': 'application/json' } }
      )
    }

    // Check if already accepted
    if (invitation.status === 'accepted') {
      console.log('Invitation already accepted')
      return new Response(
        JSON.stringify({ 
          success: false, 
          message: 'Inbjudan är redan accepterad'
        }),
        { status: 400, headers: { ...corsHeaders, 'Content-Type': 'application/json' } }
      )
    }

    console.log(`✅ Invitation verified: coach=${invitation.coach_id}, client=${invitation.client_id}`)

    // 2. Update invitation status to accepted
    const { error: updateError } = await supabaseAdmin
      .from('coach_client_invitations')
      .update({ status: 'accepted' })
      .eq('id', invitationId)

    if (updateError) {
      console.error('Failed to update invitation:', updateError)
      throw updateError
    }

    console.log('✅ Invitation status updated to accepted')

    // 3. Create coach-client relation
    const { error: relationError } = await supabaseAdmin
      .from('coach_clients')
      .insert({
        coach_id: invitation.coach_id,
        client_id: invitation.client_id,
        status: 'active'
      })

    if (relationError) {
      // Check if relation already exists
      if (relationError.code === '23505') { // Unique constraint violation
        console.log('Relation already exists, updating to active...')
        await supabaseAdmin
          .from('coach_clients')
          .update({ status: 'active' })
          .eq('coach_id', invitation.coach_id)
          .eq('client_id', invitation.client_id)
      } else {
        console.error('Failed to create coach-client relation:', relationError)
        throw relationError
      }
    }

    console.log('✅ Coach-client relation created')

    // 4. Delete notification
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

    // 5. Get coach name for response
    const { data: coach } = await supabaseAdmin
      .from('profiles')
      .select('username')
      .eq('id', invitation.coach_id)
      .single()

    const coachName = coach?.username || 'Din tränare'

    console.log(`🎉 Successfully accepted invitation! Coach: ${coachName}`)

    return new Response(
      JSON.stringify({ 
        success: true, 
        message: `Du är nu kopplad till ${coachName}`,
        coachName: coachName
      }),
      { headers: { ...corsHeaders, 'Content-Type': 'application/json' } }
    )

  } catch (error) {
    console.error('Error accepting invitation:', error)
    return new Response(
      JSON.stringify({ 
        success: false, 
        message: 'Något gick fel när inbjudan skulle accepteras',
        error: error.message 
      }),
      { 
        status: 500,
        headers: { ...corsHeaders, 'Content-Type': 'application/json' } 
      }
    )
  }
})
