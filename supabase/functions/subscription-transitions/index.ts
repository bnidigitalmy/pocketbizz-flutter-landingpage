// Supabase Edge Function to handle subscription grace/expiry transitions
// Should be called via cron job (hourly or daily)
// 
// Handles:
// - trial → expired (when trial_ends_at passes)
// - pending_payment → active (when payment completed and start date reached)
// - active → grace (when expires_at passes)
// - grace → expired (when grace_until passes)

import { serve } from "https://deno.land/std@0.168.0/http/server.ts";
import { createClient } from "https://esm.sh/@supabase/supabase-js@2";

const corsHeaders = {
  "Access-Control-Allow-Origin": "*",
  "Access-Control-Allow-Headers":
    "authorization, x-client-info, apikey, content-type",
};

serve(async (req) => {
  // Handle CORS preflight
  if (req.method === "OPTIONS") {
    return new Response("ok", { headers: corsHeaders });
  }

  try {
    // Get Supabase client with service role key (bypasses RLS)
    const supabaseUrl = Deno.env.get("SUPABASE_URL") ?? "";
    const supabaseServiceKey = Deno.env.get("SUPABASE_SERVICE_ROLE_KEY") ?? "";

    if (!supabaseUrl || !supabaseServiceKey) {
      throw new Error("Missing Supabase environment variables");
    }

    const supabase = createClient(supabaseUrl, supabaseServiceKey, {
      auth: {
        autoRefreshToken: false,
        persistSession: false,
      },
    });

    const now = new Date();
    const nowIso = now.toISOString();

    // Get all subscriptions that need transitions (including trial)
    const { data: subscriptions, error: fetchError } = await supabase
      .from("subscriptions")
      .select("*")
      .in("status", ["trial", "active", "grace", "pending_payment"]);

    if (fetchError) {
      throw new Error(`Failed to fetch subscriptions: ${fetchError.message}`);
    }

    if (!subscriptions || subscriptions.length === 0) {
      return new Response(
        JSON.stringify({ message: "No subscriptions to process", processed: 0 }),
        {
          headers: { ...corsHeaders, "Content-Type": "application/json" },
          status: 200,
        }
      );
    }

    let processed = 0;
    let activated = 0;
    let movedToGrace = 0;
    let expired = 0;
    let trialExpired = 0;

    for (const sub of subscriptions) {
      const status = (sub.status as string).toLowerCase();
      const expiresAt = new Date(sub.expires_at as string);
      const trialEndsAt = sub.trial_ends_at ? new Date(sub.trial_ends_at as string) : null;
      const startedAt = sub.started_at ? new Date(sub.started_at as string) : null;
      const graceUntil = sub.grace_until ? new Date(sub.grace_until as string) : null;
      const paymentStatus = sub.payment_status as string | null;

      // 1. Expire trial if past trial_ends_at (or expires_at as fallback)
      if (status === "trial") {
        const trialEnd = trialEndsAt || expiresAt;
        if (now > trialEnd) {
          await supabase
            .from("subscriptions")
            .update({
              status: "expired",
              updated_at: nowIso,
            })
            .eq("id", sub.id);

          trialExpired++;
          processed++;
          continue;
        }
      }

      // 2. Activate pending_payment if payment completed and start date reached
      if (
        status === "pending_payment" &&
        paymentStatus === "completed" &&
        startedAt &&
        now >= startedAt
      ) {
        // Get plan to calculate expiry
        const { data: plan } = await supabase
          .from("subscription_plans")
          .select("duration_months")
          .eq("id", sub.plan_id)
          .single();

        if (plan) {
          const durationMonths = plan.duration_months as number;
          // Calculate expiry: add duration months to started_at
          const newExpires = new Date(startedAt);
          newExpires.setMonth(newExpires.getMonth() + durationMonths);
          const newGrace = new Date(newExpires);
          newGrace.setDate(newGrace.getDate() + 7);

          await supabase
            .from("subscriptions")
            .update({
              status: "active",
              started_at: startedAt.toISOString(),
              expires_at: newExpires.toISOString(),
              grace_until: newGrace.toISOString(),
              updated_at: nowIso,
            })
            .eq("id", sub.id);

          activated++;
          processed++;
        }
        continue;
      }

      // 3. Move active to grace if past expiry
      if (status === "active" && now > expiresAt) {
        const newGraceUntil = graceUntil || new Date(expiresAt);
        newGraceUntil.setDate(newGraceUntil.getDate() + 7);

        await supabase
          .from("subscriptions")
          .update({
            status: "grace",
            grace_until: newGraceUntil.toISOString(),
            updated_at: nowIso,
          })
          .eq("id", sub.id);

        // Send grace email (if not sent)
        if (!sub.grace_email_sent) {
          // Get user email
          const { data: userData } = await supabase.auth.admin.getUserById(sub.user_id as string);
          const userEmail = userData?.user?.email;
          
          if (userEmail) {
            // Send grace reminder email via resend-email Edge Function
            try {
              const graceEndFormatted = newGraceUntil.toLocaleDateString('ms-MY', {
                day: 'numeric',
                month: 'long',
                year: 'numeric',
              });
              
              await supabase.functions.invoke('resend-email', {
                body: {
                  to: userEmail,
                  subject: '⚠️ Langganan PocketBizz Dalam Tempoh Tangguh',
                  html: `
                    <div style="font-family: sans-serif; max-width: 600px; margin: 0 auto;">
                      <h2 style="color: #f59e0b;">⚠️ Tempoh Tangguh Bermula</h2>
                      <p>Assalamualaikum,</p>
                      <p>Langganan PocketBizz anda telah memasuki <strong>tempoh tangguh (grace period)</strong>.</p>
                      <p>Anda masih boleh menggunakan semua ciri PocketBizz sehingga <strong>${graceEndFormatted}</strong>.</p>
                      <p>Selepas tarikh tersebut, akaun anda akan dihadkan kepada mod baca sahaja.</p>
                      <div style="margin: 24px 0; padding: 16px; background: #fef3c7; border-radius: 8px;">
                        <p style="margin: 0; font-weight: bold;">Untuk terus menggunakan PocketBizz:</p>
                        <p style="margin: 8px 0 0 0;">Sila lengkapkan pembayaran melalui aplikasi PocketBizz.</p>
                      </div>
                      <p>Terima kasih kerana menggunakan PocketBizz!</p>
                      <p style="color: #666; font-size: 12px;">— Pasukan PocketBizz</p>
                    </div>
                  `,
                },
              });
              console.log(`[${nowIso}] Grace email sent to ${userEmail}`);
            } catch (emailError) {
              console.error(`[${nowIso}] Failed to send grace email:`, emailError);
              // Don't fail the transition if email fails
            }
          }
          
          // Mark email as sent (even if send failed, to prevent spam)
          await supabase
            .from("subscriptions")
            .update({
              grace_email_sent: true,
              updated_at: nowIso,
            })
            .eq("id", sub.id);
        }

        movedToGrace++;
        processed++;
        continue;
      }

      // 4. Move grace to expired if past grace_until
      if (status === "grace" && graceUntil && now > graceUntil) {
        await supabase
          .from("subscriptions")
          .update({
            status: "expired",
            updated_at: nowIso,
          })
          .eq("id", sub.id);

        expired++;
        processed++;
      }
    }

    return new Response(
      JSON.stringify({
        message: "Subscription transitions processed",
        processed,
        activated,
        movedToGrace,
        expired,
        trialExpired,
      }),
      {
        headers: { ...corsHeaders, "Content-Type": "application/json" },
        status: 200,
      }
    );
  } catch (error) {
    console.error("Error processing subscription transitions:", error);
    return new Response(
      JSON.stringify({ error: error.message }),
      {
        headers: { ...corsHeaders, "Content-Type": "application/json" },
        status: 500,
      }
    );
  }
});
