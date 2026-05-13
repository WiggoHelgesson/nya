/**
 * MARKETPLACE HEALTHCHECK
 * =======================
 * Cron-driven (varje timme) skanning av tre kategorier av "fastnade"
 * ordrar:
 *
 *   1. Ship-by missade — `status='succeeded'`, `created_at < now()-7d`,
 *      `shipped_at IS NULL`. Dessa borde redan ha auto-cancellerats av
 *      `process-marketplace-deadlines`.
 *   2. Fastnade payouts — `is_held=true`, `released_at IS NULL`,
 *      `buyer_approved_at < now()-2d`. Stripe-transfer som inte gått.
 *   3. Långöppna tvister — `status='disputed'` öppna > 5 dagar.
 *
 * Om något fångas: posta en sammanfattning till `SLACK_HEALTHCHECK_URL`.
 *
 * Auth: kräver service-role bearer (samma mönster som
 * `process-marketplace-deadlines`).
 */

import { serve } from 'https://deno.land/std@0.168.0/http/server.ts';
import { createClient } from 'https://esm.sh/@supabase/supabase-js@2.45.0';

const corsHeaders = {
  'Access-Control-Allow-Origin': '*',
  'Access-Control-Allow-Headers': 'authorization, x-client-info, apikey, content-type',
};

serve(async (req) => {
  if (req.method === 'OPTIONS') return new Response('ok', { headers: corsHeaders });

  try {
    const supabaseAdmin = createClient(
      Deno.env.get('SUPABASE_URL') ?? '',
      Deno.env.get('SUPABASE_SERVICE_ROLE_KEY') ?? ''
    );

    const sevenDaysAgo = new Date(Date.now() - 7 * 24 * 60 * 60 * 1000).toISOString();
    const twoDaysAgo = new Date(Date.now() - 2 * 24 * 60 * 60 * 1000).toISOString();
    const fiveDaysAgo = new Date(Date.now() - 5 * 24 * 60 * 60 * 1000).toISOString();

    const { data: missedShip } = await supabaseAdmin
      .from('marketplace_orders')
      .select('id, seller_id, created_at')
      .eq('status', 'succeeded')
      .is('shipped_at', null)
      .is('auto_cancelled_at', null)
      .lt('created_at', sevenDaysAgo)
      .limit(50);

    const { data: stuckPayouts } = await supabaseAdmin
      .from('marketplace_orders')
      .select('id, seller_id, buyer_approved_at, payout_failure_reason')
      .eq('is_held', true)
      .is('released_at', null)
      .not('buyer_approved_at', 'is', null)
      .lt('buyer_approved_at', twoDaysAgo)
      .limit(50);

    const { data: longDisputes } = await supabaseAdmin
      .from('marketplace_orders')
      .select('id, dispute_opened_at')
      .eq('status', 'disputed')
      .is('dispute_resolved_at', null)
      .lt('dispute_opened_at', fiveDaysAgo)
      .limit(50);

    const summary = {
      missedShip: missedShip?.length ?? 0,
      stuckPayouts: stuckPayouts?.length ?? 0,
      longDisputes: longDisputes?.length ?? 0,
    };

    const totalIssues = summary.missedShip + summary.stuckPayouts + summary.longDisputes;

    const slackUrl = Deno.env.get('SLACK_HEALTHCHECK_URL');
    if (totalIssues > 0 && slackUrl) {
      const lines: string[] = [];
      if (summary.missedShip > 0) {
        lines.push(`• *${summary.missedShip}* ordrar > 7 dagar utan inlämning (borde vara auto-cancellerade)`);
        for (const o of (missedShip ?? []).slice(0, 5)) {
          lines.push(`    • ${o.id.slice(0, 8)} (säljare ${(o.seller_id as string).slice(0, 8)})`);
        }
      }
      if (summary.stuckPayouts > 0) {
        lines.push(`• *${summary.stuckPayouts}* payouts fastnat > 2 dagar efter buyer approval`);
        for (const o of (stuckPayouts ?? []).slice(0, 5)) {
          const reason = (o.payout_failure_reason as string | null) ?? 'okänt';
          lines.push(`    • ${o.id.slice(0, 8)}: ${reason.slice(0, 80)}`);
        }
      }
      if (summary.longDisputes > 0) {
        lines.push(`• *${summary.longDisputes}* tvister öppna > 5 dagar`);
        for (const o of (longDisputes ?? []).slice(0, 5)) {
          lines.push(`    • ${o.id.slice(0, 8)} (öppnad ${o.dispute_opened_at})`);
        }
      }
      const payload = {
        text: `:warning: *Marketplace healthcheck* — ${totalIssues} issue(s)\n${lines.join('\n')}`,
      };
      try {
        await fetch(slackUrl, {
          method: 'POST',
          headers: { 'Content-Type': 'application/json' },
          body: JSON.stringify(payload),
        });
      } catch (e) {
        console.warn('Slack post failed:', (e as Error).message);
      }
    }

    return new Response(
      JSON.stringify({ success: true, ...summary }),
      { status: 200, headers: { ...corsHeaders, 'Content-Type': 'application/json' } }
    );
  } catch (error) {
    console.error('marketplace-healthcheck error:', error);
    return new Response(
      JSON.stringify({ success: false, error: (error as Error).message }),
      { status: 400, headers: { ...corsHeaders, 'Content-Type': 'application/json' } }
    );
  }
});
