/**
 * Process Trial Follow-up Emails (Cron Job)
 * 
 * This function runs on a schedule (e.g., every hour or daily) to:
 * 1. Find trial users who need to receive follow-up emails
 * 2. Send the appropriate email based on days since trial started
 * 3. Update tracking to prevent duplicate emails
 * 
 * Schedule: Run daily at 9:00 AM Malaysia time (1:00 AM UTC)
 * Cron: 0 1 * * *
 * 
 * To set up cron in Supabase:
 * 1. Go to Database → Extensions → Enable pg_cron
 * 2. Run: SELECT cron.schedule('process-trial-emails', '0 1 * * *', $$
 *    SELECT net.http_post(
 *      'https://YOUR_PROJECT_REF.supabase.co/functions/v1/process-trial-followup-emails',
 *      '{}',
 *      '{"Content-Type": "application/json", "Authorization": "Bearer YOUR_SERVICE_KEY"}'
 *    );
 * $$);
 */

import { serve } from "https://deno.land/std@0.168.0/http/server.ts";
import { createClient } from "https://esm.sh/@supabase/supabase-js@2";

const SUPABASE_URL = Deno.env.get("SUPABASE_URL")!;
const SUPABASE_SERVICE_KEY = Deno.env.get("SUPABASE_SERVICE_ROLE_KEY")!;

const corsHeaders = {
  "Access-Control-Allow-Origin": "*",
  "Access-Control-Allow-Headers": "authorization, x-client-info, apikey, content-type",
};

interface TrackingRecord {
  id: string;
  user_id: string;
  user_email: string;
  user_name: string | null;
  trial_started_at: string;
  trial_ends_at: string;
  day1_email_sent: boolean;
  day2_email_sent: boolean;
  day3_email_sent: boolean;
  day4_email_sent: boolean;
  day5_email_sent: boolean;
  day6_email_sent: boolean;
  converted_to_paid: boolean;
}

async function sendEmail(functionName: string, email: string, name: string | null, trialEndsAt: string): Promise<boolean> {
  try {
    const response = await fetch(`${SUPABASE_URL}/functions/v1/${functionName}`, {
      method: "POST",
      headers: {
        "Content-Type": "application/json",
        "Authorization": `Bearer ${SUPABASE_SERVICE_KEY}`,
      },
      body: JSON.stringify({
        email,
        name: name || email.split('@')[0],
        trialEndsAt,
      }),
    });

    if (!response.ok) {
      const error = await response.text();
      console.error(`Failed to send ${functionName} to ${email}:`, error);
      return false;
    }

    console.log(`Successfully sent ${functionName} to ${email}`);
    return true;
  } catch (error) {
    console.error(`Error sending ${functionName} to ${email}:`, error);
    return false;
  }
}

serve(async (req: Request) => {
  if (req.method === "OPTIONS") {
    return new Response("ok", { headers: corsHeaders });
  }

  const supabase = createClient(SUPABASE_URL, SUPABASE_SERVICE_KEY);
  
  const results = {
    processed: 0,
    day1Sent: 0,
    day2Sent: 0,
    day3Sent: 0,
    day4Sent: 0,
    day5Sent: 0,
    day6Sent: 0,
    skipped: 0,
    errors: 0,
  };

  try {
    console.log("Starting trial follow-up email processing...");

    // Get all trial users who haven't received all emails yet
    // and haven't converted to paid
    const { data: trackingRecords, error } = await supabase
      .from("trial_email_tracking")
      .select("*")
      .eq("converted_to_paid", false)
      .or("day1_email_sent.eq.false,day2_email_sent.eq.false,day3_email_sent.eq.false,day4_email_sent.eq.false,day5_email_sent.eq.false,day6_email_sent.eq.false");

    if (error) {
      console.error("Error fetching tracking records:", error);
      return new Response(
        JSON.stringify({ error: "Failed to fetch tracking records", details: error }),
        { status: 500, headers: { ...corsHeaders, "Content-Type": "application/json" } }
      );
    }

    if (!trackingRecords || trackingRecords.length === 0) {
      console.log("No users need follow-up emails at this time");
      return new Response(
        JSON.stringify({ success: true, message: "No users need follow-up emails", results }),
        { status: 200, headers: { ...corsHeaders, "Content-Type": "application/json" } }
      );
    }

    console.log(`Found ${trackingRecords.length} users to process`);

    const now = new Date();

    for (const record of trackingRecords as TrackingRecord[]) {
      results.processed++;
      
      const trialStarted = new Date(record.trial_started_at);
      const trialEnds = new Date(record.trial_ends_at);
      const daysSinceStart = Math.floor((now.getTime() - trialStarted.getTime()) / (1000 * 60 * 60 * 24));
      
      // Skip if trial already ended
      if (now > trialEnds) {
        console.log(`Skipping ${record.user_email} - trial already ended`);
        results.skipped++;
        continue;
      }

      // Skip if no valid email
      if (!record.user_email || !record.user_email.includes('@')) {
        console.log(`Skipping invalid email: ${record.user_email}`);
        results.skipped++;
        continue;
      }

      let emailSent = false;
      let updateField = "";

      // Day 1 email (send on day 1 or later if not sent)
      if (daysSinceStart >= 1 && !record.day1_email_sent) {
        emailSent = await sendEmail("send-trial-followup-day1", record.user_email, record.user_name, record.trial_ends_at);
        if (emailSent) {
          updateField = "day1_email_sent";
          results.day1Sent++;
        }
      }
      // Day 2 email
      else if (daysSinceStart >= 2 && !record.day2_email_sent) {
        emailSent = await sendEmail("send-trial-followup-day2", record.user_email, record.user_name, record.trial_ends_at);
        if (emailSent) {
          updateField = "day2_email_sent";
          results.day2Sent++;
        }
      }
      // Day 3 email
      else if (daysSinceStart >= 3 && !record.day3_email_sent) {
        emailSent = await sendEmail("send-trial-followup-day3", record.user_email, record.user_name, record.trial_ends_at);
        if (emailSent) {
          updateField = "day3_email_sent";
          results.day3Sent++;
        }
      }
      // Day 4 email
      else if (daysSinceStart >= 4 && !record.day4_email_sent) {
        emailSent = await sendEmail("send-trial-followup-day4", record.user_email, record.user_name, record.trial_ends_at);
        if (emailSent) {
          updateField = "day4_email_sent";
          results.day4Sent++;
        }
      }
      // Day 5 email
      else if (daysSinceStart >= 5 && !record.day5_email_sent) {
        emailSent = await sendEmail("send-trial-followup-day5", record.user_email, record.user_name, record.trial_ends_at);
        if (emailSent) {
          updateField = "day5_email_sent";
          results.day5Sent++;
        }
      }
      // Day 6 email (last day before trial ends)
      else if (daysSinceStart >= 6 && !record.day6_email_sent) {
        emailSent = await sendEmail("send-trial-followup-day6", record.user_email, record.user_name, record.trial_ends_at);
        if (emailSent) {
          updateField = "day6_email_sent";
          results.day6Sent++;
        }
      }

      // Update tracking record if email was sent
      if (emailSent && updateField) {
        const { error: updateError } = await supabase
          .from("trial_email_tracking")
          .update({
            [updateField]: true,
            [`${updateField.replace('_sent', '_sent_at')}`]: now.toISOString(),
            updated_at: now.toISOString(),
          })
          .eq("id", record.id);

        if (updateError) {
          console.error(`Failed to update tracking for ${record.user_email}:`, updateError);
          results.errors++;
        }
      } else if (!emailSent && updateField) {
        results.errors++;
      }

      // Add small delay between emails to avoid rate limiting
      await new Promise(resolve => setTimeout(resolve, 200));
    }

    console.log("Processing complete:", results);

    return new Response(
      JSON.stringify({ 
        success: true, 
        message: "Trial follow-up emails processed",
        results 
      }),
      { status: 200, headers: { ...corsHeaders, "Content-Type": "application/json" } }
    );

  } catch (error) {
    console.error("Error processing trial follow-up emails:", error);
    return new Response(
      JSON.stringify({ 
        error: "Internal server error", 
        message: error instanceof Error ? error.message : "Unknown error",
        results
      }),
      { status: 500, headers: { ...corsHeaders, "Content-Type": "application/json" } }
    );
  }
});
