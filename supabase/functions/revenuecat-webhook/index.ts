import { serve } from "https://deno.land/std@0.168.0/http/server.ts";
import { createClient } from "https://esm.sh/@supabase/supabase-js@2";
const corsHeaders = {
  'Access-Control-Allow-Origin': '*',
  'Access-Control-Allow-Headers': 'authorization, x-client-info, apikey, content-type'
};
serve(async (req)=>{
  // Handle CORS preflight requests
  if (req.method === 'OPTIONS') {
    return new Response(null, {
      headers: corsHeaders
    });
  }
  try {
    const payload = await req.json();
    console.log('RevenueCat webhook received:', JSON.stringify(payload, null, 2));
    const event = payload.event;
    const productId = event.product_id;
    const appUserId = event.app_user_id;
    const expirationDate = event.expiration_at_ms ? new Date(event.expiration_at_ms) : null;
    const eventType = event.type;
    console.log('Processing event:', {
      type: eventType,
      userId: appUserId,
      productId,
      expirationDate
    });
    // Initialize Supabase client
    const supabaseUrl = Deno.env.get('SUPABASE_URL');
    const supabaseServiceKey = Deno.env.get('SUPABASE_SERVICE_ROLE_KEY');
    const supabase = createClient(supabaseUrl, supabaseServiceKey);
    // Determine if subscription is active
    let isProMember = false;
    let expiresAt = null;
    switch(eventType){
      case 'INITIAL_PURCHASE':
      case 'RENEWAL':
      case 'PRODUCT_CHANGE':
        isProMember = true;
        expiresAt = expirationDate;
        console.log('Activating PRO membership');
        break;
      case 'CANCELLATION':
        // Keep PRO active until expiration
        isProMember = true;
        expiresAt = expirationDate;
        console.log('Subscription cancelled but still active until:', expirationDate);
        break;
      case 'EXPIRATION':
      case 'BILLING_ISSUE':
        isProMember = false;
        expiresAt = null;
        console.log('Deactivating PRO membership');
        break;
      default:
        console.log('Unhandled event type:', eventType);
    }
    // Update user profile in Supabase
    const { data, error } = await supabase.from('profiles').update({
      is_pro_member: isProMember,
      pro_membership_expires_at: expiresAt,
      revenuecat_subscriber_id: appUserId,
      updated_at: new Date().toISOString()
    }).eq('id', appUserId).select();
    if (error) {
      console.error('Error updating profile:', error);
      throw error;
    }
    console.log('Profile updated successfully:', data);
    return new Response(JSON.stringify({
      success: true,
      message: 'Webhook processed successfully',
      userId: appUserId,
      isProMember,
      expiresAt
    }), {
      headers: {
        ...corsHeaders,
        'Content-Type': 'application/json'
      },
      status: 200
    });
  } catch (error) {
    console.error('Error processing webhook:', error);
    return new Response(JSON.stringify({
      success: false,
      error: error.message
    }), {
      headers: {
        ...corsHeaders,
        'Content-Type': 'application/json'
      },
      status: 500
    });
  }
});
