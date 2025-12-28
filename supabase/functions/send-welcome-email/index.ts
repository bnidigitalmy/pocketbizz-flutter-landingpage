/**
 * Send Welcome Email Edge Function
 * 
 * Sends a welcome email to new trial users
 * Called after user registration
 */

import { serve } from "https://deno.land/std@0.168.0/http/server.ts";

const RESEND_API_KEY = Deno.env.get("RESEND_API_KEY");
const DEFAULT_FROM = "PocketBizz <noreply@notifications.pocketbizz.my>";

const corsHeaders = {
  "Access-Control-Allow-Origin": "*",
  "Access-Control-Allow-Headers": "authorization, x-client-info, apikey, content-type",
};

serve(async (req: Request) => {
  if (req.method === "OPTIONS") {
    return new Response("ok", { headers: corsHeaders });
  }

  try {
    const { email, name } = await req.json();

    if (!email) {
      return new Response(
        JSON.stringify({ error: "Email is required" }),
        { status: 400, headers: { ...corsHeaders, "Content-Type": "application/json" } }
      );
    }

    if (!RESEND_API_KEY) {
      console.error("RESEND_API_KEY not configured");
      return new Response(
        JSON.stringify({ error: "Email service not configured" }),
        { status: 500, headers: { ...corsHeaders, "Content-Type": "application/json" } }
      );
    }

    const userName = name || email.split('@')[0];
    const trialEndDate = new Date();
    trialEndDate.setDate(trialEndDate.getDate() + 7);
    const formattedDate = trialEndDate.toLocaleDateString('ms-MY', {
      day: 'numeric',
      month: 'long',
      year: 'numeric',
    });

    const welcomeHtml = `
<!DOCTYPE html>
<html>
<head>
  <meta charset="utf-8">
  <meta name="viewport" content="width=device-width, initial-scale=1.0">
</head>
<body style="margin: 0; padding: 0; font-family: 'Segoe UI', Tahoma, Geneva, Verdana, sans-serif; background-color: #f5f5f5;">
  <div style="max-width: 600px; margin: 0 auto; background-color: #ffffff;">
    
    <!-- Header -->
    <div style="background: linear-gradient(135deg, #2E7D32 0%, #43A047 100%); padding: 40px 30px; text-align: center;">
      <h1 style="color: #ffffff; margin: 0; font-size: 28px;">🎉 Selamat Datang ke PocketBizz!</h1>
      <p style="color: #E8F5E9; margin: 10px 0 0 0; font-size: 16px;">Pengurusan Bisnes Anda, Dalam Satu App</p>
    </div>
    
    <!-- Content -->
    <div style="padding: 40px 30px;">
      
      <p style="font-size: 18px; color: #333; margin: 0 0 20px 0;">
        Assalamualaikum <strong>${userName}</strong>! 👋
      </p>
      
      <p style="font-size: 16px; color: #555; line-height: 1.6; margin: 0 0 25px 0;">
        Terima kasih kerana mendaftar dengan PocketBizz. Anda kini mempunyai akses <strong>percubaan percuma selama 7 hari</strong> untuk meneroka semua ciri-ciri kami!
      </p>
      
      <!-- Trial Info Box -->
      <div style="background-color: #E8F5E9; border-left: 4px solid #2E7D32; padding: 20px; margin: 0 0 30px 0; border-radius: 0 8px 8px 0;">
        <p style="margin: 0; color: #2E7D32; font-weight: bold; font-size: 16px;">⏰ Tempoh Percubaan Anda</p>
        <p style="margin: 10px 0 0 0; color: #333; font-size: 15px;">Sah sehingga: <strong>${formattedDate}</strong></p>
      </div>
      
      <!-- What is PocketBizz -->
      <h2 style="color: #2E7D32; font-size: 20px; margin: 0 0 15px 0;">📱 Apa itu PocketBizz?</h2>
      
      <p style="font-size: 15px; color: #555; line-height: 1.6; margin: 0 0 20px 0;">
        PocketBizz adalah aplikasi pengurusan bisnes all-in-one yang direka khas untuk usahawan Malaysia. 
        Urus inventori, jualan, pengeluaran, dan kewangan bisnes anda dengan mudah - semua dalam satu tempat!
      </p>
      
      <!-- Features -->
      <h2 style="color: #2E7D32; font-size: 20px; margin: 0 0 15px 0;">✨ Ciri-ciri Utama</h2>
      
      <table style="width: 100%; border-collapse: collapse; margin: 0 0 30px 0;">
        <tr>
          <td style="padding: 10px; vertical-align: top; width: 50%;">
            <div style="background: #f8f9fa; padding: 15px; border-radius: 8px;">
              <strong style="color: #2E7D32;">📦 Inventori & Stok</strong>
              <p style="margin: 8px 0 0 0; font-size: 14px; color: #666;">Pantau stok secara real-time</p>
            </div>
          </td>
          <td style="padding: 10px; vertical-align: top; width: 50%;">
            <div style="background: #f8f9fa; padding: 15px; border-radius: 8px;">
              <strong style="color: #2E7D32;">💰 Jualan & Tempahan</strong>
              <p style="margin: 8px 0 0 0; font-size: 14px; color: #666;">Rekod jualan dengan mudah</p>
            </div>
          </td>
        </tr>
        <tr>
          <td style="padding: 10px; vertical-align: top;">
            <div style="background: #f8f9fa; padding: 15px; border-radius: 8px;">
              <strong style="color: #2E7D32;">🏭 Pengeluaran</strong>
              <p style="margin: 8px 0 0 0; font-size: 14px; color: #666;">Rancang pengeluaran produk</p>
            </div>
          </td>
          <td style="padding: 10px; vertical-align: top;">
            <div style="background: #f8f9fa; padding: 15px; border-radius: 8px;">
              <strong style="color: #2E7D32;">📊 Laporan</strong>
              <p style="margin: 8px 0 0 0; font-size: 14px; color: #666;">Analisis prestasi bisnes</p>
            </div>
          </td>
        </tr>
      </table>
      
      <!-- How to Subscribe -->
      <h2 style="color: #2E7D32; font-size: 20px; margin: 0 0 15px 0;">🚀 Cara Untuk Teruskan</h2>
      
      <p style="font-size: 15px; color: #555; line-height: 1.6; margin: 0 0 15px 0;">
        Selepas tempoh percubaan tamat, langgan PocketBizz untuk terus menikmati semua ciri:
      </p>
      
      <ol style="font-size: 15px; color: #555; line-height: 1.8; margin: 0 0 25px 0; padding-left: 20px;">
        <li>Buka aplikasi PocketBizz</li>
        <li>Pergi ke <strong>Menu → Langganan</strong></li>
        <li>Pilih pakej yang sesuai</li>
        <li>Lengkapkan pembayaran</li>
        <li>Terus gunakan tanpa gangguan! ✅</li>
      </ol>
      
      <!-- Pricing -->
      <div style="background: linear-gradient(135deg, #FFF8E1 0%, #FFECB3 100%); padding: 25px; border-radius: 12px; margin: 0 0 30px 0; text-align: center;">
        <p style="margin: 0 0 10px 0; font-size: 14px; color: #F57C00;">💎 TAWARAN ISTIMEWA</p>
        <p style="margin: 0 0 5px 0; font-size: 24px; color: #E65100; font-weight: bold;">Serendah RM29/bulan</p>
        <p style="margin: 0; font-size: 14px; color: #666;">untuk 100 pelanggan terawal!</p>
      </div>
      
      <!-- CTA Button -->
      <div style="text-align: center; margin: 0 0 30px 0;">
        <a href="https://app.pocketbizz.my" style="display: inline-block; background: linear-gradient(135deg, #2E7D32 0%, #43A047 100%); color: #ffffff; text-decoration: none; padding: 15px 40px; border-radius: 8px; font-size: 16px; font-weight: bold;">
          Mula Gunakan PocketBizz →
        </a>
      </div>
      
      <!-- Support -->
      <div style="background-color: #f8f9fa; padding: 20px; border-radius: 8px; text-align: center;">
        <p style="margin: 0 0 10px 0; font-size: 15px; color: #333;"><strong>Perlukan Bantuan?</strong></p>
        <p style="margin: 0; font-size: 14px; color: #666;">
          WhatsApp: <a href="https://wa.me/60123456789" style="color: #2E7D32;">+60 12-345 6789</a><br>
          Email: <a href="mailto:support@pocketbizz.my" style="color: #2E7D32;">support@pocketbizz.my</a>
        </p>
      </div>
      
    </div>
    
    <!-- Footer -->
    <div style="background-color: #333; padding: 30px; text-align: center;">
      <p style="margin: 0 0 10px 0; color: #ffffff; font-size: 16px; font-weight: bold;">PocketBizz</p>
      <p style="margin: 0 0 15px 0; color: #999; font-size: 13px;">Pengurusan Bisnes Dalam Genggaman</p>
      <p style="margin: 0; color: #666; font-size: 12px;">© 2025 BNI Digital. Hak Cipta Terpelihara.</p>
    </div>
    
  </div>
</body>
</html>
    `;

    console.log(`Sending welcome email to: ${email}`);

    const resendResponse = await fetch("https://api.resend.com/emails", {
      method: "POST",
      headers: {
        "Authorization": `Bearer ${RESEND_API_KEY}`,
        "Content-Type": "application/json",
      },
      body: JSON.stringify({
        from: DEFAULT_FROM,
        to: [email],
        subject: "🎉 Selamat Datang ke PocketBizz! Tempoh Percubaan Anda Bermula",
        html: welcomeHtml,
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

    console.log(`Welcome email sent successfully: ${resendResult.id}`);

    return new Response(
      JSON.stringify({ success: true, messageId: resendResult.id }),
      { status: 200, headers: { ...corsHeaders, "Content-Type": "application/json" } }
    );

  } catch (error) {
    console.error("Error sending welcome email:", error);
    return new Response(
      JSON.stringify({ error: "Internal server error", message: error instanceof Error ? error.message : "Unknown error" }),
      { status: 500, headers: { ...corsHeaders, "Content-Type": "application/json" } }
    );
  }
});

