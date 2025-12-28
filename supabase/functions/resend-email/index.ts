/**
 * Resend Email Edge Function
 * 
 * Sends emails via Resend API
 * Used for: grace period reminders, subscription notifications, etc.
 * 
 * Environment Variables Required:
 * - RESEND_API_KEY: Your Resend API key
 * 
 * Request Body:
 * {
 *   to: string,           // recipient email
 *   subject: string,      // email subject
 *   html: string,         // HTML content
 *   from?: string,        // sender email (optional, defaults to noreply@pocketbizz.com)
 *   replyTo?: string      // reply-to email (optional)
 * }
 */

import { serve } from "https://deno.land/std@0.168.0/http/server.ts";

const RESEND_API_KEY = Deno.env.get("RESEND_API_KEY");
const DEFAULT_FROM = "PocketBizz <noreply@notifications.pocketbizz.my>";

interface EmailRequest {
  to: string;
  subject: string;
  html: string;
  from?: string;
  replyTo?: string;
}

serve(async (req: Request) => {
  // Handle CORS preflight
  if (req.method === "OPTIONS") {
    return new Response("ok", {
      headers: {
        "Access-Control-Allow-Origin": "*",
        "Access-Control-Allow-Methods": "POST, OPTIONS",
        "Access-Control-Allow-Headers": "Content-Type, Authorization",
      },
    });
  }

  try {
    // Only allow POST requests
    if (req.method !== "POST") {
      return new Response(
        JSON.stringify({ error: "Method not allowed" }),
        { 
          status: 405,
          headers: { "Content-Type": "application/json" }
        }
      );
    }

    // Check API key
    if (!RESEND_API_KEY) {
      console.error("RESEND_API_KEY not configured");
      return new Response(
        JSON.stringify({ error: "Email service not configured" }),
        { 
          status: 500,
          headers: { "Content-Type": "application/json" }
        }
      );
    }

    // Parse request body
    const body: EmailRequest = await req.json();
    const { to, subject, html, from, replyTo } = body;

    // Validate required fields
    if (!to || !subject || !html) {
      return new Response(
        JSON.stringify({ error: "Missing required fields: to, subject, html" }),
        { 
          status: 400,
          headers: { "Content-Type": "application/json" }
        }
      );
    }

    // Validate email format
    const emailRegex = /^[^\s@]+@[^\s@]+\.[^\s@]+$/;
    if (!emailRegex.test(to)) {
      return new Response(
        JSON.stringify({ error: "Invalid email address" }),
        { 
          status: 400,
          headers: { "Content-Type": "application/json" }
        }
      );
    }

    console.log(`Sending email to: ${to}, subject: ${subject}`);

    // Send email via Resend API
    const resendResponse = await fetch("https://api.resend.com/emails", {
      method: "POST",
      headers: {
        "Authorization": `Bearer ${RESEND_API_KEY}`,
        "Content-Type": "application/json",
      },
      body: JSON.stringify({
        from: from || DEFAULT_FROM,
        to: [to],
        subject: subject,
        html: html,
        reply_to: replyTo,
      }),
    });

    const resendResult = await resendResponse.json();

    if (!resendResponse.ok) {
      console.error("Resend API error:", resendResult);
      return new Response(
        JSON.stringify({ 
          error: "Failed to send email",
          details: resendResult 
        }),
        { 
          status: resendResponse.status,
          headers: { "Content-Type": "application/json" }
        }
      );
    }

    console.log(`Email sent successfully: ${resendResult.id}`);

    return new Response(
      JSON.stringify({ 
        success: true,
        messageId: resendResult.id 
      }),
      { 
        status: 200,
        headers: { 
          "Content-Type": "application/json",
          "Access-Control-Allow-Origin": "*",
        }
      }
    );

  } catch (error) {
    console.error("Error sending email:", error);
    return new Response(
      JSON.stringify({ 
        error: "Internal server error",
        message: error instanceof Error ? error.message : "Unknown error"
      }),
      { 
        status: 500,
        headers: { "Content-Type": "application/json" }
      }
    );
  }
});

