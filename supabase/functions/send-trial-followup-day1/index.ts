/**
 * Send Trial Follow-up Day 1: Stok & Inventori
 * 
 * Email focus: Show value of inventory management
 * Pain point: Manual tracking tedious, lupa update, rugi stok expired
 * Solution: Auto-update bila rekod jualan/pengeluaran
 * Benefit: Jimat 2-3 jam seminggu, tak rugi stok expired
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
      console.error("RESEND_API_KEY not configured");
      return new Response(
        JSON.stringify({ error: "Email service not configured" }),
        { status: 500, headers: { ...corsHeaders, "Content-Type": "application/json" } }
      );
    }

    const userName = name || email.split('@')[0];
    const daysLeft = trialEndsAt 
      ? Math.ceil((new Date(trialEndsAt).getTime() - Date.now()) / (1000 * 60 * 60 * 24))
      : 6;

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
    <div style="background: linear-gradient(135deg, #1565C0 0%, #42A5F5 100%); padding: 30px; text-align: center;">
      <div style="font-size: 40px; margin-bottom: 10px;">📦</div>
      <h1 style="color: #ffffff; margin: 0; font-size: 24px;">Rahsia Urus Stok Tanpa Stress</h1>
      <p style="color: #E3F2FD; margin: 10px 0 0 0; font-size: 14px;">3 Minit Setup, Jimat Berjam-jam!</p>
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
        Hari ini, kami nak tunjukkan satu feature yang paling ramai usahawan suka - 
        <strong>Pengurusan Stok Automatik</strong>!
      </p>
      
      <!-- Pain Point Box -->
      <div style="background: #FFEBEE; padding: 20px; border-radius: 12px; margin: 0 0 25px 0; border-left: 4px solid #EF5350;">
        <p style="margin: 0 0 10px 0; font-size: 15px; color: #C62828; font-weight: bold;">
          😫 Masalah Yang Sering Dihadapi:
        </p>
        <ul style="margin: 0; padding-left: 20px; color: #555; font-size: 14px; line-height: 1.8;">
          <li>Track stok secara manual dalam Excel/buku - <strong>leceh & mudah silap</strong></li>
          <li>Lupa update stok lepas jual - <strong>tak tahu stok sebenar</strong></li>
          <li>Bahan expired sebab tak perasan - <strong>rugi besar!</strong></li>
          <li>Kehabisan stok masa customer nak beli - <strong>hilang jualan</strong></li>
        </ul>
      </div>
      
      <!-- Solution Box -->
      <div style="background: #E8F5E9; padding: 20px; border-radius: 12px; margin: 0 0 25px 0; border-left: 4px solid #66BB6A;">
        <p style="margin: 0 0 10px 0; font-size: 15px; color: #2E7D32; font-weight: bold;">
          ✨ Dengan PocketBizz:
        </p>
        <ul style="margin: 0; padding-left: 20px; color: #555; font-size: 14px; line-height: 1.8;">
          <li>Stok <strong>AUTO UPDATE</strong> bila rekod jualan atau pengeluaran</li>
          <li>Alert <strong>LOW STOCK</strong> - tak akan kehabisan lagi</li>
          <li>Track <strong>EXPIRY DATE</strong> - guna yang hampir tamat dulu</li>
          <li>Lihat nilai stok <strong>REAL-TIME</strong> dalam dashboard</li>
        </ul>
      </div>
      
      <!-- Benefit Highlight -->
      <div style="background: linear-gradient(135deg, #E3F2FD 0%, #BBDEFB 100%); padding: 25px; border-radius: 12px; margin: 0 0 25px 0; text-align: center;">
        <p style="margin: 0 0 5px 0; font-size: 14px; color: #1565C0;">💡 HASIL YANG ANDA DAPAT:</p>
        <p style="margin: 0; font-size: 20px; color: #0D47A1; font-weight: bold;">
          Jimat 2-3 Jam Seminggu
        </p>
        <p style="margin: 10px 0 0 0; font-size: 13px; color: #555;">
          Masa yang boleh anda guna untuk kembangkan bisnes!
        </p>
      </div>
      
      <!-- How to Start -->
      <h3 style="color: #333; font-size: 16px; margin: 0 0 15px 0;">🚀 Cara Mula (3 Langkah Mudah):</h3>
      
      <ol style="font-size: 14px; color: #555; line-height: 1.8; margin: 0 0 25px 0; padding-left: 20px;">
        <li>Buka <strong>Menu → Stok</strong></li>
        <li>Tekan <strong>"+ Tambah Bahan"</strong></li>
        <li>Masukkan nama, kuantiti & harga - <strong>Siap!</strong></li>
      </ol>
      
      <!-- CTA Button -->
      <div style="text-align: center; margin: 0 0 30px 0;">
        <a href="https://app.pocketbizz.my/#/stock" style="display: inline-block; background: linear-gradient(135deg, #1565C0 0%, #42A5F5 100%); color: #ffffff; text-decoration: none; padding: 15px 40px; border-radius: 8px; font-size: 16px; font-weight: bold;">
          📦 Tambah Stok Sekarang →
        </a>
      </div>
      
      <!-- Tip Box -->
      <div style="background: #FFF3E0; padding: 15px; border-radius: 8px; margin: 0 0 20px 0;">
        <p style="margin: 0; font-size: 13px; color: #E65100;">
          💡 <strong>Tip:</strong> Mula dengan 3-5 bahan utama yang anda selalu guna. 
          Tambah yang lain secara perlahan-lahan!
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

    console.log(`Sending Day 1 follow-up email to: ${email}`);

    const resendResponse = await fetch("https://api.resend.com/emails", {
      method: "POST",
      headers: {
        "Authorization": `Bearer ${RESEND_API_KEY}`,
        "Content-Type": "application/json",
      },
      body: JSON.stringify({
        from: DEFAULT_FROM,
        to: [email],
        subject: "📦 Rahsia Urus Stok Tanpa Stress - 3 Minit Setup!",
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

    console.log(`Day 1 follow-up email sent successfully: ${resendResult.id}`);

    return new Response(
      JSON.stringify({ success: true, messageId: resendResult.id }),
      { status: 200, headers: { ...corsHeaders, "Content-Type": "application/json" } }
    );

  } catch (error) {
    console.error("Error sending Day 1 follow-up email:", error);
    return new Response(
      JSON.stringify({ error: "Internal server error", message: error instanceof Error ? error.message : "Unknown error" }),
      { status: 500, headers: { ...corsHeaders, "Content-Type": "application/json" } }
    );
  }
});
