// Supabase Edge Function: Telegram Admin Notification
// Sends notifications to admin Telegram group for:
// - New user registration
// - Subscription upgrade (Pro)
// - Payment success/failure

import { serve } from "https://deno.land/std@0.168.0/http/server.ts";

const TELEGRAM_BOT_TOKEN = Deno.env.get("TELEGRAM_BOT_TOKEN") ?? "";
const TELEGRAM_CHAT_ID = Deno.env.get("TELEGRAM_CHAT_ID") ?? "";

const corsHeaders = {
  "Access-Control-Allow-Origin": "*",
  "Access-Control-Allow-Headers":
    "authorization, x-client-info, apikey, content-type",
};

interface NotificationPayload {
  type: "new_user" | "upgrade_pro" | "payment_success" | "payment_failed" | "trial_started" | "subscription_expired";
  data: {
    user_email?: string;
    user_name?: string;
    business_name?: string;
    plan_name?: string;
    amount?: number;
    currency?: string;
    duration_months?: number;
    order_id?: string;
    failure_reason?: string;
    timestamp?: string;
  };
}

// Format currency
const formatCurrency = (amount: number, currency: string = "MYR"): string => {
  return `${currency} ${amount.toFixed(2)}`;
};

// Format timestamp
const formatTimestamp = (timestamp?: string): string => {
  const date = timestamp ? new Date(timestamp) : new Date();
  return date.toLocaleString("ms-MY", {
    timeZone: "Asia/Kuala_Lumpur",
    day: "2-digit",
    month: "short",
    year: "numeric",
    hour: "2-digit",
    minute: "2-digit",
  });
};

// Build notification message based on type
const buildMessage = (payload: NotificationPayload): string => {
  const { type, data } = payload;
  const timestamp = formatTimestamp(data.timestamp);

  switch (type) {
    case "new_user":
      return `🎉 *PENGGUNA BARU MENDAFTAR*

👤 *Email:* ${data.user_email || "N/A"}
🏪 *Bisnes:* ${data.business_name || "Belum diisi"}
📅 *Masa:* ${timestamp}

_Pengguna baru telah memulakan trial 7 hari._`;

    case "trial_started":
      return `🆓 *TRIAL DIMULAKAN*

👤 *Email:* ${data.user_email || "N/A"}
👤 *Nama:* ${data.user_name || "N/A"}
🏪 *Bisnes:* ${data.business_name || "Belum diisi"}
📅 *Masa:* ${timestamp}

_Trial 7 hari telah bermula._`;

    case "upgrade_pro":
      return `💎 *UPGRADE KE PRO!*

👤 *Email:* ${data.user_email || "N/A"}
👤 *Nama:* ${data.user_name || "N/A"}
🏪 *Bisnes:* ${data.business_name || "N/A"}
📦 *Pelan:* ${data.plan_name || "Pro"} (${data.duration_months || 1} bulan)
💰 *Jumlah:* ${formatCurrency(data.amount || 0, data.currency)}
🧾 *Order ID:* \`${data.order_id || "N/A"}\`
📅 *Masa:* ${timestamp}

_Tahniah! Pelanggan baru! 🚀_`;

    case "payment_success":
      return `✅ *PEMBAYARAN BERJAYA*

👤 *Email:* ${data.user_email || "N/A"}
📦 *Pelan:* ${data.plan_name || "Pro"} (${data.duration_months || 1} bulan)
💰 *Jumlah:* ${formatCurrency(data.amount || 0, data.currency)}
🧾 *Order ID:* \`${data.order_id || "N/A"}\`
📅 *Masa:* ${timestamp}`;

    case "payment_failed":
      return `❌ *PEMBAYARAN GAGAL*

👤 *Email:* ${data.user_email || "N/A"}
📦 *Pelan:* ${data.plan_name || "Pro"}
💰 *Jumlah:* ${formatCurrency(data.amount || 0, data.currency)}
🧾 *Order ID:* \`${data.order_id || "N/A"}\`
⚠️ *Sebab:* ${data.failure_reason || "Unknown"}
📅 *Masa:* ${timestamp}

_Sila follow up dengan pelanggan._`;

    case "subscription_expired":
      return `⏰ *LANGGANAN TAMAT*

👤 *Email:* ${data.user_email || "N/A"}
👤 *Nama:* ${data.user_name || "N/A"}
🏪 *Bisnes:* ${data.business_name || "N/A"}
📅 *Masa:* ${timestamp}

_Langganan telah tamat tempoh. Boleh follow up untuk renew._`;

    default:
      return `📢 *NOTIFIKASI*

${JSON.stringify(data, null, 2)}

📅 *Masa:* ${timestamp}`;
  }
};

// Send message to Telegram
const sendTelegramMessage = async (message: string): Promise<boolean> => {
  if (!TELEGRAM_BOT_TOKEN || !TELEGRAM_CHAT_ID) {
    console.error("Missing Telegram credentials");
    return false;
  }

  try {
    const url = `https://api.telegram.org/bot${TELEGRAM_BOT_TOKEN}/sendMessage`;

    const response = await fetch(url, {
      method: "POST",
      headers: {
        "Content-Type": "application/json",
      },
      body: JSON.stringify({
        chat_id: TELEGRAM_CHAT_ID,
        text: message,
        parse_mode: "Markdown",
        disable_web_page_preview: true,
      }),
    });

    const result = await response.json();

    if (!result.ok) {
      console.error("Telegram API error:", result);
      return false;
    }

    console.log("Telegram message sent successfully");
    return true;
  } catch (error) {
    console.error("Failed to send Telegram message:", error);
    return false;
  }
};

serve(async (req) => {
  // Handle CORS preflight
  if (req.method === "OPTIONS") {
    return new Response("ok", { headers: corsHeaders });
  }

  try {
    const payload: NotificationPayload = await req.json();

    console.log(`[${new Date().toISOString()}] Received notification:`, payload.type);

    // Build and send message
    const message = buildMessage(payload);
    const success = await sendTelegramMessage(message);

    if (success) {
      return new Response(
        JSON.stringify({ success: true, message: "Notification sent" }),
        {
          headers: { ...corsHeaders, "Content-Type": "application/json" },
          status: 200,
        }
      );
    } else {
      return new Response(
        JSON.stringify({ success: false, message: "Failed to send notification" }),
        {
          headers: { ...corsHeaders, "Content-Type": "application/json" },
          status: 500,
        }
      );
    }
  } catch (error) {
    console.error("Error processing notification:", error);
    return new Response(
      JSON.stringify({ error: error.message }),
      {
        headers: { ...corsHeaders, "Content-Type": "application/json" },
        status: 500,
      }
    );
  }
});
