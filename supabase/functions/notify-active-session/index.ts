import { serve } from "https://deno.land/std@0.168.0/http/server.ts";
import { createClient } from "https://esm.sh/@supabase/supabase-js@2";

const corsHeaders = {
  "Access-Control-Allow-Origin": "*",
  "Access-Control-Allow-Headers": "authorization, x-client-info, apikey, content-type",
};

// APNs Configuration
const APNS_KEY_ID = Deno.env.get('APNS_KEY_ID')!;
const APNS_TEAM_ID = Deno.env.get('APNS_TEAM_ID')!;
const APNS_PRIVATE_KEY = Deno.env.get('APNS_P8_KEY')!;
const BUNDLE_ID = 'roboreabapp.productions';

interface NotificationPayload {
  userId: string;
  userName: string;
  activityType: string;
}

async function createJWT(): Promise<string> {
  const header = {
    alg: 'ES256',
    kid: APNS_KEY_ID,
  };
  
  const now = Math.floor(Date.now() / 1000);
  const claims = {
    iss: APNS_TEAM_ID,
    iat: now,
  };
  
  const pemContents = APNS_PRIVATE_KEY
    .replace('-----BEGIN PRIVATE KEY-----', '')
    .replace('-----END PRIVATE KEY-----', '')
    .replace(/\s/g, '');
  
  const binaryKey = Uint8Array.from(atob(pemContents), c => c.charCodeAt(0));
  
  const key = await crypto.subtle.importKey(
    'pkcs8',
    binaryKey,
    { name: 'ECDSA', namedCurve: 'P-256' },
    false,
    ['sign']
  );
  
  const headerB64 = btoa(JSON.stringify(header)).replace(/=/g, '').replace(/\+/g, '-').replace(/\//g, '_');
  const claimsB64 = btoa(JSON.stringify(claims)).replace(/=/g, '').replace(/\+/g, '-').replace(/\//g, '_');
  const message = `${headerB64}.${claimsB64}`;
  
  const signature = await crypto.subtle.sign(
    { name: 'ECDSA', hash: 'SHA-256' },
    key,
    new TextEncoder().encode(message)
  );
  
  const signatureB64 = btoa(String.fromCharCode(...new Uint8Array(signature)))
    .replace(/=/g, '').replace(/\+/g, '-').replace(/\//g, '_');
  
  return `${message}.${signatureB64}`;
}

async function sendAPNS(deviceToken: string, title: string, body: string, data?: Record<string, string>): Promise<boolean> {
  try {
    const jwt = await createJWT();
    
    const payload = {
      aps: {
        alert: {
          title,
          body,
        },
        sound: 'default',
        badge: 1,
      },
      ...data,
    };
    
    const productionUrl = `https://api.push.apple.com/3/device/${deviceToken}`;
    const sandboxUrl = `https://api.sandbox.push.apple.com/3/device/${deviceToken}`;
    
    const headers = {
      'Authorization': `bearer ${jwt}`,
      'apns-topic': BUNDLE_ID,
      'apns-push-type': 'alert',
      'apns-priority': '10',
    };
    
    let response = await fetch(productionUrl, {
      method: 'POST',
      headers,
      body: JSON.stringify(payload),
    });
    
    if (!response.ok) {
      console.log('Production APNs failed, trying sandbox...');
      response = await fetch(sandboxUrl, {
        method: 'POST',
        headers,
        body: JSON.stringify(payload),
      });
      
      if (!response.ok) {
        console.error('Both APNs endpoints failed');
        return false;
      }
    }
    
    return true;
  } catch (error) {
    console.error('Failed to send APNS:', error);
    return false;
  }
}

serve(async (req) => {
  if (req.method === "OPTIONS") {
    return new Response("ok", { headers: corsHeaders });
  }

  try {
    const supabaseUrl = Deno.env.get("SUPABASE_URL")!;
    const supabaseServiceKey = Deno.env.get("SUPABASE_SERVICE_ROLE_KEY")!;
    const supabase = createClient(supabaseUrl, supabaseServiceKey);

    const { userId, userName, activityType } = await req.json() as NotificationPayload;
    
    console.log(`🏋️ Starting session notification for ${userName} (${activityType})`);

    // Get all followers of this user
    const { data: followers, error: followersError } = await supabase
      .from("user_follows")
      .select("follower_id")
      .eq("following_id", userId);

    if (followersError) {
      throw followersError;
    }

    if (!followers || followers.length === 0) {
      console.log("No followers to notify");
      return new Response(
        JSON.stringify({ message: "No followers to notify" }),
        { headers: { ...corsHeaders, "Content-Type": "application/json" } }
      );
    }

    const followerIds = followers.map((f) => f.follower_id);
    console.log(`Found ${followerIds.length} followers to notify`);

    // Get device tokens for all followers
    const { data: tokens, error: tokensError } = await supabase
      .from("device_tokens")
      .select("token, user_id")
      .in("user_id", followerIds)
      .eq("is_active", true);

    if (tokensError) {
      throw tokensError;
    }

    if (!tokens || tokens.length === 0) {
      console.log("No device tokens found for followers");
      return new Response(
        JSON.stringify({ message: "No device tokens found" }),
        { headers: { ...corsHeaders, "Content-Type": "application/json" } }
      );
    }

    console.log(`Found ${tokens.length} device tokens`);

    // Get first name
    const firstName = userName.split(" ")[0] || userName;

    // Activity text - handle both raw values from app and legacy values
    const activityLower = activityType.toLowerCase();
    let activityText = "träningspass";
    let articleWord = "ett";
    
    if (activityLower === "gym" || activityLower === "walking" || activityLower === "gympass") {
      activityText = "gympass";
    } else if (activityLower === "running" || activityLower === "löppass") {
      activityText = "löppass";
    } else if (activityLower === "golf" || activityLower === "golfrunda") {
      activityText = "golfrunda";
      articleWord = "en";
    } else if (activityLower === "bestiga berg" || activityLower === "hiking") {
      activityText = "promenad";
      articleWord = "en";
    } else if (activityLower === "skidåkning" || activityLower === "skiing") {
      activityText = "skidpass";
    }

    const title = `${firstName} startade ${articleWord} ${activityText}`;
    const body = "Gå in och pusha på!! 💪";

    // Send push notifications to all followers
    const results = await Promise.all(
      tokens.map(async (tokenData) => {
        try {
          const success = await sendAPNS(
            tokenData.token,
            title,
            body,
            {
              type: "active_session",
              userId: userId,
              deepLink: "upanddown://active-friends",
            }
          );
          
          if (success) {
            console.log(`✅ Push sent to ${tokenData.user_id}`);
          }
          
          return { success, userId: tokenData.user_id };
        } catch (error) {
          console.error(`Failed to send to ${tokenData.user_id}:`, error);
          return { success: false, userId: tokenData.user_id };
        }
      })
    );

    const successCount = results.filter(r => r.success).length;
    console.log(`✅ Sent ${successCount}/${tokens.length} push notifications`);

    return new Response(
      JSON.stringify({ 
        message: "Notifications sent", 
        sent: successCount,
        total: tokens.length 
      }),
      { headers: { ...corsHeaders, "Content-Type": "application/json" } }
    );

  } catch (error) {
    console.error("Error:", error);
    return new Response(
      JSON.stringify({ error: error.message }),
      { status: 500, headers: { ...corsHeaders, "Content-Type": "application/json" } }
    );
  }
});
