/**
 * Send Trial Follow-up Day 4: Tempahan (Booking)
 * 
 * Email focus: Booking management for customer orders
 * Pain point: Tempahan bertindih, lupa order, customer complaint
 * Solution: Sistem booking dengan deposit tracking
 * Benefit: Kalendar tersusun, reminder auto, track payment
 */

import { serve } from "https://deno.land/std@0.168.0/http/server.ts";

const RESEND_API_KEY = Deno.env.get("RESEND_API_KEY");
const DEFAULT_FROM = "PocketBizz <noreply@notifications.pocketbizz.my>";

const corsHeaders = {
  "Access-Control-Allow-Origin": "*",
  "Access-Control-Allow-Headers": "authorization, x-client-info, apikey, content-type",
};

interface EmailRequest {
  email: string;
  name?: string;
  trialEndsAt?: string;
}

serve(async (req: Request) => {
  if (req.method === "OPTIONS") {
    return new Response("ok", { headers: corsHeaders });
  }

  try {
    const { email, name, trialEndsAt }: EmailRequest = await req.json();

    if (!email) {
      return new Response(
        JSON.stringify({ error: "Email is required" }),
        { status: 400, headers: { ...corsHeaders, "Content-Type": "application/json" } }
      );
    }

    if (!RESEND_API_KEY) {
      return new Response(
        JSON.stringify({ error: "Email service not configured" }),
        { status: 500, headers: { ...corsHeaders, "Content-Type": "application/json" } }
      );
    }

    const userName = name || email.split('@')[0];
    const daysLeft = trialEndsAt 
      ? Math.ceil((new Date(trialEndsAt).getTime() - Date.now()) / (1000 * 60 * 60 * 24))
      : 3;

    const emailHtml = `
<!DOCTYPE html>
<html>
<head>
  <meta charset="utf-8">
  <meta name="viewport" content="width=device-width, initial-scale=1.0">
</head>
<body style="margin: 0; padding: 0; font-family: 'Segoe UI', Tahoma, Geneva, Verdana, sans-serif; background-color: #f5f5f5;">
  <div style="max-width: 600px; margin: 0 auto; background-color: #ffffff;">
    
    <!-- Header -->
    <div style="background: linear-gradient(135deg, #7B1FA2 0%, #AB47BC 100%); padding: 30px; text-align: center;">
      <div style="font-size: 40px; margin-bottom: 10px;">📅</div>
      <h1 style="color: #ffffff; margin: 0; font-size: 24px;">Urus Tempahan Pelanggan</h1>
      <p style="color: #F3E5F5; margin: 10px 0 0 0; font-size: 14px;">Tak Miss Order Lagi!</p>
    </div>
    
    <!-- Trial Badge -->
    <div style="background: #FFF8E1; padding: 12px; text-align: center; border-bottom: 1px solid #FFE082;">
      <span style="color: #F57C00; font-size: 13px;">⏰ <strong>${daysLeft} hari lagi</strong> dalam tempoh percubaan</span>
    </div>
    
    <!-- Content -->
    <div style="padding: 30px;">
      
      <p style="font-size: 16px; color: #333; margin: 0 0 20px 0;">
        Assalamualaikum <strong>${userName}</strong>! 👋
      </p>
      
      <p style="font-size: 15px; color: #555; line-height: 1.6; margin: 0 0 25px 0;">
        Terima tempahan dari customer tapi kadang-kadang <strong>lupa atau tercicir</strong>? 
        Jom tengok macam mana PocketBizz boleh bantu!
      </p>
      
      <!-- Pain Point Box -->
      <div style="background: #FFEBEE; padding: 20px; border-radius: 12px; margin: 0 0 25px 0; border-left: 4px solid #EF5350;">
        <p style="margin: 0 0 10px 0; font-size: 15px; color: #C62828; font-weight: bold;">
          😰 Pernah Alami Ini?
        </p>
        <ul style="margin: 0; padding-left: 20px; color: #555; font-size: 14px; line-height: 1.8;">
          <li>Tempahan <strong>bertindih</strong> - double booking pada tarikh sama</li>
          <li><strong>Lupa order</strong> customer - malu & reputasi terjejas</li>
          <li>Tak ingat siapa dah bayar <strong>deposit</strong>, siapa belum</li>
          <li>Customer <strong>complain</strong> sebab order tak siap</li>
        </ul>
      </div>
      
      <!-- Solution Box -->
      <div style="background: #F3E5F5; padding: 20px; border-radius: 12px; margin: 0 0 25px 0; border-left: 4px solid #AB47BC;">
        <p style="margin: 0 0 10px 0; font-size: 15px; color: #7B1FA2; font-weight: bold;">
          ✨ Dengan Feature Tempahan:
        </p>
        <ul style="margin: 0; padding-left: 20px; color: #555; font-size: 14px; line-height: 1.8;">
          <li><strong>Kalendar tempahan</strong> - nampak semua order dalam satu view</li>
          <li>Track <strong>deposit & baki</strong> - tahu siapa dah bayar</li>
          <li><strong>Details customer</strong> - nama, telefon, alamat delivery</li>
          <li><strong>Status order</strong> - pending, confirmed, completed</li>
        </ul>
      </div>
      
      <!-- Booking Example -->
      <div style="background: #F5F5F5; padding: 20px; border-radius: 12px; margin: 0 0 25px 0;">
        <p style="margin: 0 0 15px 0; font-size: 14px; color: #333; font-weight: bold;">📋 Contoh Tempahan:</p>
        
        <div style="background: #ffffff; padding: 15px; border-radius: 8px; border: 1px solid #E0E0E0;">
          <div style="display: flex; justify-content: space-between; margin-bottom: 10px;">
            <span style="font-size: 14px; color: #333; font-weight: bold;">🎂 Kek Birthday 3 Tier</span>
            <span style="font-size: 12px; background: #E8F5E9; color: #2E7D32; padding: 3px 8px; border-radius: 4px;">Confirmed</span>
          </div>
          <table style="width: 100%; font-size: 13px; color: #555;">
            <tr>
              <td style="padding: 3px 0;">📅 Tarikh Hantar:</td>
              <td style="text-align: right;"><strong>25 Jan 2026</strong></td>
            </tr>
            <tr>
              <td style="padding: 3px 0;">👤 Customer:</td>
              <td style="text-align: right;">Puan Aminah</td>
            </tr>
            <tr>
              <td style="padding: 3px 0;">📍 Lokasi:</td>
              <td style="text-align: right;">Shah Alam</td>
            </tr>
            <tr>
              <td style="padding: 3px 0;">💰 Jumlah:</td>
              <td style="text-align: right;">RM 350</td>
            </tr>
            <tr>
              <td style="padding: 3px 0;">✅ Deposit:</td>
              <td style="text-align: right; color: #2E7D32;"><strong>RM 150 (Paid)</strong></td>
            </tr>
          </table>
        </div>
      </div>
      
      <!-- Benefit Highlight -->
      <div style="background: linear-gradient(135deg, #F3E5F5 0%, #E1BEE7 100%); padding: 25px; border-radius: 12px; margin: 0 0 25px 0; text-align: center;">
        <p style="margin: 0 0 5px 0; font-size: 14px; color: #7B1FA2;">🎯 HASIL YANG ANDA DAPAT:</p>
        <p style="margin: 0; font-size: 20px; color: #4A148C; font-weight: bold;">
          Zero Miss Order, Customer Happy!
        </p>
        <p style="margin: 10px 0 0 0; font-size: 13px; color: #555;">
          Semua tempahan terurus dengan baik = Reputasi bisnes terjaga
        </p>
      </div>
      
      <!-- How to Start -->
      <h3 style="color: #333; font-size: 16px; margin: 0 0 15px 0;">🚀 Cara Tambah Tempahan:</h3>
      
      <ol style="font-size: 14px; color: #555; line-height: 1.8; margin: 0 0 25px 0; padding-left: 20px;">
        <li>Pergi ke <strong>Menu → Tempahan</strong></li>
        <li>Tekan <strong>"+ Tambah Tempahan"</strong></li>
        <li>Masukkan details customer & order</li>
        <li>Set tarikh hantar & deposit - <strong>Siap!</strong></li>
      </ol>
      
      <!-- CTA Button -->
      <div style="text-align: center; margin: 0 0 30px 0;">
        <a href="https://app.pocketbizz.my/#/bookings" style="display: inline-block; background: linear-gradient(135deg, #7B1FA2 0%, #AB47BC 100%); color: #ffffff; text-decoration: none; padding: 15px 40px; border-radius: 8px; font-size: 16px; font-weight: bold;">
          📅 Tambah Tempahan Sekarang →
        </a>
      </div>
      
      <!-- Tip Box -->
      <div style="background: #FFF3E0; padding: 15px; border-radius: 8px; margin: 0 0 20px 0;">
        <p style="margin: 0; font-size: 13px; color: #E65100;">
          💡 <strong>Tip:</strong> Minta deposit 30-50% untuk setiap tempahan. 
          Record dalam sistem supaya tak confuse!
        </p>
      </div>
      
      <!-- Support -->
      <div style="text-align: center; padding: 20px 0; border-top: 1px solid #eee;">
        <p style="margin: 0 0 10px 0; font-size: 14px; color: #666;">
          Ada soalan? Kami sedia membantu!
        </p>
        <p style="margin: 0; font-size: 13px; color: #999;">
          WhatsApp: <a href="https://wa.me/60107827802" style="color: #2E7D32;">+60 10-782 7802</a>
        </p>
      </div>
      
    </div>
    
    <!-- Footer -->
    <div style="background-color: #333; padding: 25px; text-align: center;">
      <p style="margin: 0 0 5px 0; color: #ffffff; font-size: 14px; font-weight: bold;">PocketBizz</p>
      <p style="margin: 0 0 10px 0; color: #999; font-size: 12px;">Pengurusan Bisnes Dalam Genggaman</p>
      <p style="margin: 0; color: #666; font-size: 11px;">© 2025 BNI Digital. Hak Cipta Terpelihara.</p>
    </div>
    
  </div>
</body>
</html>
    `;

    console.log(`Sending Day 4 follow-up email to: ${email}`);

    const resendResponse = await fetch("https://api.resend.com/emails", {
      method: "POST",
      headers: {
        "Authorization": `Bearer ${RESEND_API_KEY}`,
        "Content-Type": "application/json",
      },
      body: JSON.stringify({
        from: DEFAULT_FROM,
        to: [email],
        subject: "📅 Urus Tempahan Pelanggan - Tak Miss Order Lagi!",
        html: emailHtml,
      }),
    });

    const resendResult = await resendResponse.json();

    if (!resendResponse.ok) {
      console.error("Resend API error:", resendResult);
      return new Response(
        JSON.stringify({ error: "Failed to send email", details: resendResult }),
        { status: resendResponse.status, headers: { ...corsHeaders, "Content-Type": "application/json" } }
      );
    }

    console.log(`Day 4 follow-up email sent successfully: ${resendResult.id}`);

    return new Response(
      JSON.stringify({ success: true, messageId: resendResult.id }),
      { status: 200, headers: { ...corsHeaders, "Content-Type": "application/json" } }
    );

  } catch (error) {
    console.error("Error sending Day 4 follow-up email:", error);
    return new Response(
      JSON.stringify({ error: "Internal server error", message: error instanceof Error ? error.message : "Unknown error" }),
      { status: 500, headers: { ...corsHeaders, "Content-Type": "application/json" } }
    );
  }
});
