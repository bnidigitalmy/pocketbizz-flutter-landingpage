/**
 * Send Trial Follow-up Day 2: Pengeluaran & Resepi
 * 
 * Email focus: Auto calculate product cost from recipes
 * Pain point: Tak tahu kos sebenar, agak-agak je harga jual
 * Solution: Masuk resepi sekali, sistem kira semua
 * Benefit: Tahu kos sebenar, set harga jual yang betul, stok auto tolak
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
      : 5;

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
    <div style="background: linear-gradient(135deg, #6D4C41 0%, #8D6E63 100%); padding: 30px; text-align: center;">
      <div style="font-size: 40px; margin-bottom: 10px;">🍰</div>
      <h1 style="color: #ffffff; margin: 0; font-size: 24px;">Auto Kira Kos Produk</h1>
      <p style="color: #EFEBE9; margin: 10px 0 0 0; font-size: 14px;">Tak Perlu Calculator Lagi!</p>
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
        Hari ini, kami nak share <strong>rahsia penting</strong> untuk pastikan anda 
        <strong>untung setiap kali jual</strong> - Kira Kos Produk Automatik!
      </p>
      
      <!-- Pain Point Box -->
      <div style="background: #FFEBEE; padding: 20px; border-radius: 12px; margin: 0 0 25px 0; border-left: 4px solid #EF5350;">
        <p style="margin: 0 0 10px 0; font-size: 15px; color: #C62828; font-weight: bold;">
          😰 Masalah Yang Ramai Usahawan Hadapi:
        </p>
        <ul style="margin: 0; padding-left: 20px; color: #555; font-size: 14px; line-height: 1.8;">
          <li>Tak tahu <strong>kos sebenar</strong> setiap produk</li>
          <li>Agak-agak je letak harga - <strong>mungkin rugi tanpa sedar!</strong></li>
          <li>Kira manual setiap kali harga bahan naik - <strong>leceh</strong></li>
          <li>Lupa tolak stok bahan lepas buat produk</li>
        </ul>
      </div>
      
      <!-- Solution Box -->
      <div style="background: #E8F5E9; padding: 20px; border-radius: 12px; margin: 0 0 25px 0; border-left: 4px solid #66BB6A;">
        <p style="margin: 0 0 10px 0; font-size: 15px; color: #2E7D32; font-weight: bold;">
          ✨ Dengan PocketBizz:
        </p>
        <ul style="margin: 0; padding-left: 20px; color: #555; font-size: 14px; line-height: 1.8;">
          <li>Masuk resepi <strong>SEKALI</strong> - sistem kira kos untuk anda</li>
          <li>Kos <strong>AUTO UPDATE</strong> bila harga bahan berubah</li>
          <li>Stok bahan <strong>AUTO TOLAK</strong> bila rekod pengeluaran</li>
          <li>Tahu <strong>MARGIN UNTUNG</strong> sebenar setiap produk</li>
        </ul>
      </div>
      
      <!-- Example Visual -->
      <div style="background: #F5F5F5; padding: 20px; border-radius: 12px; margin: 0 0 25px 0;">
        <p style="margin: 0 0 15px 0; font-size: 14px; color: #333; font-weight: bold;">📋 Contoh: Kek Coklat 7"</p>
        <table style="width: 100%; font-size: 13px; color: #555;">
          <tr>
            <td style="padding: 5px 0;">Tepung 500g</td>
            <td style="text-align: right;">RM 2.50</td>
          </tr>
          <tr>
            <td style="padding: 5px 0;">Gula 300g</td>
            <td style="text-align: right;">RM 1.80</td>
          </tr>
          <tr>
            <td style="padding: 5px 0;">Telur 4 biji</td>
            <td style="text-align: right;">RM 2.40</td>
          </tr>
          <tr>
            <td style="padding: 5px 0;">Koko 100g</td>
            <td style="text-align: right;">RM 3.00</td>
          </tr>
          <tr>
            <td style="padding: 5px 0;">Mentega 200g</td>
            <td style="text-align: right;">RM 4.50</td>
          </tr>
          <tr style="border-top: 2px solid #ddd;">
            <td style="padding: 10px 0; font-weight: bold; color: #333;">JUMLAH KOS:</td>
            <td style="text-align: right; font-weight: bold; color: #E65100; font-size: 16px;">RM 14.20</td>
          </tr>
        </table>
        <div style="margin-top: 15px; padding: 10px; background: #E8F5E9; border-radius: 8px; text-align: center;">
          <span style="font-size: 13px; color: #2E7D32;">
            Harga Jual: <strong>RM 45</strong> → Margin: <strong style="color: #4CAF50;">RM 30.80 (68%)</strong>
          </span>
        </div>
      </div>
      
      <!-- Benefit Highlight -->
      <div style="background: linear-gradient(135deg, #EFEBE9 0%, #D7CCC8 100%); padding: 25px; border-radius: 12px; margin: 0 0 25px 0; text-align: center;">
        <p style="margin: 0 0 5px 0; font-size: 14px; color: #5D4037;">💰 HASIL YANG ANDA DAPAT:</p>
        <p style="margin: 0; font-size: 20px; color: #3E2723; font-weight: bold;">
          Tahu Untung Sebenar Setiap Produk
        </p>
        <p style="margin: 10px 0 0 0; font-size: 13px; color: #555;">
          Tak ada lagi "agak-agak" - semua berdasarkan data!
        </p>
      </div>
      
      <!-- How to Start -->
      <h3 style="color: #333; font-size: 16px; margin: 0 0 15px 0;">🚀 Cara Mula:</h3>
      
      <ol style="font-size: 14px; color: #555; line-height: 1.8; margin: 0 0 25px 0; padding-left: 20px;">
        <li>Pastikan bahan dah ada dalam <strong>Stok</strong></li>
        <li>Pergi ke <strong>Menu → Produk → Tambah Produk</strong></li>
        <li>Masukkan nama produk & harga jual</li>
        <li>Tambah bahan dari stok - <strong>sistem auto kira kos!</strong></li>
      </ol>
      
      <!-- CTA Button -->
      <div style="text-align: center; margin: 0 0 30px 0;">
        <a href="https://app.pocketbizz.my/#/recipes" style="display: inline-block; background: linear-gradient(135deg, #6D4C41 0%, #8D6E63 100%); color: #ffffff; text-decoration: none; padding: 15px 40px; border-radius: 8px; font-size: 16px; font-weight: bold;">
          🍰 Cipta Produk Sekarang →
        </a>
      </div>
      
      <!-- Tip Box -->
      <div style="background: #FFF3E0; padding: 15px; border-radius: 8px; margin: 0 0 20px 0;">
        <p style="margin: 0; font-size: 13px; color: #E65100;">
          💡 <strong>Tip:</strong> Bila rekod pengeluaran, pilih produk & kuantiti - 
          bahan akan AUTO TOLAK dari stok!
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

    console.log(`Sending Day 2 follow-up email to: ${email}`);

    const resendResponse = await fetch("https://api.resend.com/emails", {
      method: "POST",
      headers: {
        "Authorization": `Bearer ${RESEND_API_KEY}`,
        "Content-Type": "application/json",
      },
      body: JSON.stringify({
        from: DEFAULT_FROM,
        to: [email],
        subject: "🍰 Auto Kira Kos Produk - Tak Perlu Calculator Lagi!",
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

    console.log(`Day 2 follow-up email sent successfully: ${resendResult.id}`);

    return new Response(
      JSON.stringify({ success: true, messageId: resendResult.id }),
      { status: 200, headers: { ...corsHeaders, "Content-Type": "application/json" } }
    );

  } catch (error) {
    console.error("Error sending Day 2 follow-up email:", error);
    return new Response(
      JSON.stringify({ error: "Internal server error", message: error instanceof Error ? error.message : "Unknown error" }),
      { status: 500, headers: { ...corsHeaders, "Content-Type": "application/json" } }
    );
  }
});
