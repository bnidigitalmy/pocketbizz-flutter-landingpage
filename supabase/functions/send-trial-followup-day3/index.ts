/**
 * Send Trial Follow-up Day 3: Jualan & Laporan
 * 
 * Email focus: Sales recording & real-time reports
 * Pain point: Tak tahu prestasi bisnes, kira manual hujung bulan
 * Solution: Rekod jualan sekejap, laporan auto generate
 * Benefit: Lihat untung/rugi real-time, trend analysis
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
      : 4;

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
    <div style="background: linear-gradient(135deg, #2E7D32 0%, #66BB6A 100%); padding: 30px; text-align: center;">
      <div style="font-size: 40px; margin-bottom: 10px;">📊</div>
      <h1 style="color: #ffffff; margin: 0; font-size: 24px;">Dashboard Bisnes Anda</h1>
      <p style="color: #E8F5E9; margin: 10px 0 0 0; font-size: 14px;">Lihat Prestasi Real-time!</p>
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
        Hari ini, kami nak tunjukkan bagaimana anda boleh 
        <strong>lihat prestasi bisnes dalam sekelip mata</strong> - dengan Dashboard & Laporan automatik!
      </p>
      
      <!-- Pain Point Box -->
      <div style="background: #FFEBEE; padding: 20px; border-radius: 12px; margin: 0 0 25px 0; border-left: 4px solid #EF5350;">
        <p style="margin: 0 0 10px 0; font-size: 15px; color: #C62828; font-weight: bold;">
          😫 Masalah Biasa:
        </p>
        <ul style="margin: 0; padding-left: 20px; color: #555; font-size: 14px; line-height: 1.8;">
          <li>Tak tahu berapa <strong>jualan hari ini</strong></li>
          <li>Kira untung/rugi <strong>manual hujung bulan</strong> - leceh!</li>
          <li>Tak nampak <strong>trend</strong> - produk mana paling laris?</li>
          <li>Susah nak buat keputusan bisnes tanpa data</li>
        </ul>
      </div>
      
      <!-- Solution Box -->
      <div style="background: #E8F5E9; padding: 20px; border-radius: 12px; margin: 0 0 25px 0; border-left: 4px solid #66BB6A;">
        <p style="margin: 0 0 10px 0; font-size: 15px; color: #2E7D32; font-weight: bold;">
          ✨ Dengan PocketBizz:
        </p>
        <ul style="margin: 0; padding-left: 20px; color: #555; font-size: 14px; line-height: 1.8;">
          <li>Rekod jualan dalam <strong>10 saat</strong></li>
          <li><strong>Dashboard</strong> tunjuk jualan hari ini, minggu ini, bulan ini</li>
          <li>Lihat <strong>produk paling laris</strong> automatik</li>
          <li><strong>Export laporan</strong> untuk akaun/cukai</li>
        </ul>
      </div>
      
      <!-- Dashboard Preview -->
      <div style="background: #F5F5F5; padding: 20px; border-radius: 12px; margin: 0 0 25px 0;">
        <p style="margin: 0 0 15px 0; font-size: 14px; color: #333; font-weight: bold;">📈 Apa Yang Anda Akan Nampak:</p>
        
        <div style="display: flex; gap: 10px; margin-bottom: 15px;">
          <div style="flex: 1; background: #E3F2FD; padding: 15px; border-radius: 8px; text-align: center;">
            <p style="margin: 0; font-size: 12px; color: #1565C0;">Jualan Hari Ini</p>
            <p style="margin: 5px 0 0 0; font-size: 20px; color: #0D47A1; font-weight: bold;">RM 450</p>
          </div>
          <div style="flex: 1; background: #E8F5E9; padding: 15px; border-radius: 8px; text-align: center;">
            <p style="margin: 0; font-size: 12px; color: #2E7D32;">Minggu Ini</p>
            <p style="margin: 5px 0 0 0; font-size: 20px; color: #1B5E20; font-weight: bold;">RM 2,800</p>
          </div>
        </div>
        
        <div style="background: #FFF8E1; padding: 12px; border-radius: 8px;">
          <p style="margin: 0; font-size: 13px; color: #333;">
            🏆 <strong>Produk Terlaris:</strong> Kek Coklat (45 unit bulan ini)
          </p>
        </div>
      </div>
      
      <!-- Benefit Highlight -->
      <div style="background: linear-gradient(135deg, #E8F5E9 0%, #C8E6C9 100%); padding: 25px; border-radius: 12px; margin: 0 0 25px 0; text-align: center;">
        <p style="margin: 0 0 5px 0; font-size: 14px; color: #2E7D32;">📊 HASIL YANG ANDA DAPAT:</p>
        <p style="margin: 0; font-size: 20px; color: #1B5E20; font-weight: bold;">
          Buat Keputusan Bisnes Berasaskan Data
        </p>
        <p style="margin: 10px 0 0 0; font-size: 13px; color: #555;">
          Tak perlu teka-teki lagi - semua ada dalam dashboard!
        </p>
      </div>
      
      <!-- How to Start -->
      <h3 style="color: #333; font-size: 16px; margin: 0 0 15px 0;">🚀 Cara Rekod Jualan:</h3>
      
      <ol style="font-size: 14px; color: #555; line-height: 1.8; margin: 0 0 25px 0; padding-left: 20px;">
        <li>Pergi ke <strong>Menu → Jualan → Rekod Jualan</strong></li>
        <li>Pilih produk yang dijual</li>
        <li>Masukkan kuantiti & pilih payment method</li>
        <li><strong>Siap!</strong> Dashboard auto update</li>
      </ol>
      
      <!-- CTA Button -->
      <div style="text-align: center; margin: 0 0 30px 0;">
        <a href="https://app.pocketbizz.my/#/dashboard" style="display: inline-block; background: linear-gradient(135deg, #2E7D32 0%, #66BB6A 100%); color: #ffffff; text-decoration: none; padding: 15px 40px; border-radius: 8px; font-size: 16px; font-weight: bold;">
          💰 Rekod Jualan Sekarang →
        </a>
      </div>
      
      <!-- Tip Box -->
      <div style="background: #FFF3E0; padding: 15px; border-radius: 8px; margin: 0 0 20px 0;">
        <p style="margin: 0; font-size: 13px; color: #E65100;">
          💡 <strong>Tip:</strong> Rekod jualan setiap hari supaya laporan lebih tepat. 
          Jadikan tabiat - ambil masa 2 minit je!
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

    console.log(`Sending Day 3 follow-up email to: ${email}`);

    const resendResponse = await fetch("https://api.resend.com/emails", {
      method: "POST",
      headers: {
        "Authorization": `Bearer ${RESEND_API_KEY}`,
        "Content-Type": "application/json",
      },
      body: JSON.stringify({
        from: DEFAULT_FROM,
        to: [email],
        subject: "📊 Dashboard Bisnes Anda - Lihat Prestasi Real-time!",
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

    console.log(`Day 3 follow-up email sent successfully: ${resendResult.id}`);

    return new Response(
      JSON.stringify({ success: true, messageId: resendResult.id }),
      { status: 200, headers: { ...corsHeaders, "Content-Type": "application/json" } }
    );

  } catch (error) {
    console.error("Error sending Day 3 follow-up email:", error);
    return new Response(
      JSON.stringify({ error: "Internal server error", message: error instanceof Error ? error.message : "Unknown error" }),
      { status: 500, headers: { ...corsHeaders, "Content-Type": "application/json" } }
    );
  }
});
