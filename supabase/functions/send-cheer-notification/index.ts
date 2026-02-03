import { serve } from "https://deno.land/std@0.168.0/http/server.ts";
import { createClient } from "https://esm.sh/@supabase/supabase-js@2";

const corsHeaders = {
  "Access-Control-Allow-Origin": "*",
  "Access-Control-Allow-Headers":
    "authorization, x-client-info, apikey, content-type",
};

interface CheerNotificationRequest {
  toUserId: string;
  fromUserName: string;
  emoji: string;
}

serve(async (req) => {
  // Handle CORS preflight requests
  if (req.method === "OPTIONS") {
    return new Response("ok", { headers: corsHeaders });
  }

  try {
    const supabase = createClient(
      Deno.env.get("SUPABASE_URL") ?? "",
      Deno.env.get("SUPABASE_SERVICE_ROLE_KEY") ?? ""
    );

    const { toUserId, fromUserName, emoji }: CheerNotificationRequest =
      await req.json();

    console.log(
      `📣 Sending cheer notification: ${fromUserName} -> ${toUserId} (${emoji})`
    );

    // Get the recipient's push token from their profile
    interface ProfileWithToken {
      push_token: string | null;
      name: string | null;
    }

    const { data: profile, error: profileError } = await supabase
      .from("profiles")
      .select("push_token, name")
      .eq("id", toUserId)
      .single<ProfileWithToken>();

    if (profileError) {
      console.error("Error fetching profile:", profileError);
      return new Response(
        JSON.stringify({ error: "Failed to fetch profile" }),
        {
          status: 500,
          headers: { ...corsHeaders, "Content-Type": "application/json" },
        }
      );
    }

    if (!profile?.push_token) {
      console.log("No push token found for user, skipping notification");
      return new Response(
        JSON.stringify({ message: "No push token, notification skipped" }),
        {
          status: 200,
          headers: { ...corsHeaders, "Content-Type": "application/json" },
        }
      );
    }

    // Send push notification via Expo
    const pushMessage = {
      to: profile.push_token,
      sound: "default",
      title: `${fromUserName} hejar på dig! ${emoji}`,
      body: "Du är grym, fortsätt kämpa!",
      data: {
        type: "cheer",
        fromUserName: fromUserName,
        emoji: emoji,
      },
    };

    const expoPushResponse = await fetch("https://exp.host/--/api/v2/push/send", {
      method: "POST",
      headers: {
        Accept: "application/json",
        "Accept-encoding": "gzip, deflate",
        "Content-Type": "application/json",
      },
      body: JSON.stringify(pushMessage),
    });

    const expoPushResult = await expoPushResponse.json();
    console.log("Expo push result:", expoPushResult);

    return new Response(
      JSON.stringify({
        success: true,
        message: "Cheer notification sent",
        pushResult: expoPushResult,
      }),
      {
        status: 200,
        headers: { ...corsHeaders, "Content-Type": "application/json" },
      }
    );
  } catch (error) {
    console.error("Error in send-cheer-notification:", error);
    return new Response(
      JSON.stringify({ error: error.message || "Unknown error" }),
      {
        status: 500,
        headers: { ...corsHeaders, "Content-Type": "application/json" },
      }
    );
  }
});
