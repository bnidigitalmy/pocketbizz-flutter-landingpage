/**
 * Send Trial Follow-up Day 6: Scan Perbelanjaan + Trial Reminder
 * 
 * Email focus: OCR expense scanning + URGENCY (trial ends tomorrow!)
 * Pain point: Simpan resit manual, rekod perbelanjaan leceh
 * Solution: Snap gambar, AI extract details automatik
 * Benefit: Scan & save dalam 5 saat
 * URGENCY: Trial tamat esok - langgan sekarang!
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
    const trialEndDate = trialEndsAt 
      ? new Date(trialEndsAt).toLocaleDateString('ms-MY', { day: 'numeric', month: 'long', year: 'numeric' })
      : 'esok';

    const emailHtml = `
<!DOCTYPE html>
<html>
<head>
  <meta charset="utf-8">
  <meta name="viewport" content="width=device-width, initial-scale=1.0">
</head>
<body style="margin: 0; padding: 0; font-family: 'Segoe UI', Tahoma, Geneva, Verdana, sans-serif; background-color: #f5f5f5;">
  <div style="max-width: 600px; margin: 0 auto; background-color: #ffffff;">
    
    <!-- URGENT Header -->
    <div style="background: linear-gradient(135deg, #D32F2F 0%, #F44336 100%); padding: 20px; text-align: center;">
      <p style="color: #ffffff; margin: 0; font-size: 18px; font-weight: bold;">
        ⏰ TEMPOH PERCUBAAN TAMAT ESOK!
      </p>
    </div>
    
    <!-- Main Header -->
    <div style="background: linear-gradient(135deg, #F57C00 0%, #FFB74D 100%); padding: 30px; text-align: center;">
      <div style="font-size: 40px; margin-bottom: 10px;">📸</div>
      <h1 style="color: #ffffff; margin: 0; font-size: 24px;">Bonus Tip: Scan Resit Automatik!</h1>
      <p style="color: #FFF3E0; margin: 10px 0 0 0; font-size: 14px;">+ Peringatan Penting</p>
    </div>
    
    <!-- Content -->
    <div style="padding: 30px;">
      
      <p style="font-size: 16px; color: #333; margin: 0 0 20px 0;">
        Assalamualaikum <strong>${userName}</strong>! 👋
      </p>
      
      <p style="font-size: 15px; color: #555; line-height: 1.6; margin: 0 0 25px 0;">
        Ini email <strong>terakhir</strong> dalam siri follow-up kami. 
        Sebelum trial tamat, jom tengok satu lagi feature power - <strong>Scan Resit dengan AI!</strong>
      </p>
      
      <!-- OCR Feature Section -->
      <div style="background: #FFF3E0; padding: 20px; border-radius: 12px; margin: 0 0 25px 0; border-left: 4px solid #F57C00;">
        <p style="margin: 0 0 10px 0; font-size: 15px; color: #E65100; font-weight: bold;">
          📸 Feature: Scan Perbelanjaan
        </p>
        <p style="margin: 0; font-size: 14px; color: #555; line-height: 1.6;">
          Tak perlu taip manual lagi! Snap gambar resit, AI akan <strong>auto-extract</strong>:
        </p>
        <ul style="margin: 10px 0 0 0; padding-left: 20px; color: #555; font-size: 14px; line-height: 1.8;">
          <li>Nama kedai</li>
          <li>Tarikh pembelian</li>
          <li>Jumlah bayaran</li>
          <li>Item-item yang dibeli</li>
        </ul>
      </div>
      
      <!-- How It Works -->
      <div style="background: #F5F5F5; padding: 20px; border-radius: 12px; margin: 0 0 25px 0; text-align: center;">
        <p style="margin: 0 0 15px 0; font-size: 14px; color: #333; font-weight: bold;">📱 3 Langkah Mudah:</p>
        <div style="display: flex; justify-content: center; gap: 10px; flex-wrap: wrap;">
          <div style="background: #E3F2FD; padding: 15px; border-radius: 8px; width: 100px;">
            <span style="font-size: 24px;">📷</span>
            <p style="margin: 5px 0 0 0; font-size: 11px; color: #1565C0;">1. Snap Resit</p>
          </div>
          <div style="background: #E8F5E9; padding: 15px; border-radius: 8px; width: 100px;">
            <span style="font-size: 24px;">🤖</span>
            <p style="margin: 5px 0 0 0; font-size: 11px; color: #2E7D32;">2. AI Extract</p>
          </div>
          <div style="background: #FFF3E0; padding: 15px; border-radius: 8px; width: 100px;">
            <span style="font-size: 24px;">✅</span>
            <p style="margin: 5px 0 0 0; font-size: 11px; color: #F57C00;">3. Siap!</p>
          </div>
        </div>
      </div>
      
      <!-- URGENCY Section -->
      <div style="background: linear-gradient(135deg, #FFEBEE 0%, #FFCDD2 100%); padding: 25px; border-radius: 12px; margin: 0 0 25px 0; border: 2px solid #EF5350;">
        <div style="text-align: center;">
          <p style="margin: 0 0 5px 0; font-size: 14px; color: #C62828;">⚠️ PERINGATAN PENTING</p>
          <p style="margin: 0 0 10px 0; font-size: 22px; color: #B71C1C; font-weight: bold;">
            Tempoh Percubaan Tamat ${trialEndDate}
          </p>
          <p style="margin: 0 0 15px 0; font-size: 14px; color: #555;">
            Selepas ini, anda tidak dapat akses semua features yang dah cuba.
          </p>
        </div>
        
        <div style="background: #ffffff; padding: 15px; border-radius: 8px;">
          <p style="margin: 0 0 10px 0; font-size: 14px; color: #333; font-weight: bold;">
            💎 Apa Yang Anda Akan Kehilangan:
          </p>
          <ul style="margin: 0; padding-left: 20px; color: #555; font-size: 13px; line-height: 1.8;">
            <li>Track stok & inventori automatik</li>
            <li>Auto kira kos produk</li>
            <li>Dashboard & laporan real-time</li>
            <li>Sistem tempahan pelanggan</li>
            <li>Track penghantaran konsainan</li>
            <li>Scan resit dengan AI</li>
          </ul>
        </div>
      </div>
      
      <!-- Pricing Section -->
      <div style="background: linear-gradient(135deg, #E8F5E9 0%, #C8E6C9 100%); padding: 25px; border-radius: 12px; margin: 0 0 25px 0; text-align: center; border: 2px solid #4CAF50;">
        <p style="margin: 0 0 5px 0; font-size: 14px; color: #2E7D32;">💰 HARGA ISTIMEWA EARLY ADOPTER</p>
        <p style="margin: 0 0 10px 0; font-size: 32px; color: #1B5E20; font-weight: bold;">
          RM 29<span style="font-size: 16px; font-weight: normal;">/bulan</span>
        </p>
        <p style="margin: 0 0 5px 0; font-size: 14px; color: #555;">
          <s style="color: #999;">Harga biasa: RM 49/bulan</s>
        </p>
        <p style="margin: 0; font-size: 12px; color: #666;">
          🎁 Untuk 100 pelanggan terawal sahaja!
        </p>
      </div>
      
      <!-- What You Get -->
      <div style="margin: 0 0 25px 0;">
        <p style="margin: 0 0 15px 0; font-size: 15px; color: #333; font-weight: bold;">✅ Apa Yang Anda Dapat:</p>
        <table style="width: 100%; font-size: 14px; color: #555;">
          <tr>
            <td style="padding: 8px 0;">📦 Pengurusan Stok & Inventori</td>
            <td style="text-align: right; color: #2E7D32;">✓</td>
          </tr>
          <tr>
            <td style="padding: 8px 0;">🍰 Produk & Resepi (Auto Kira Kos)</td>
            <td style="text-align: right; color: #2E7D32;">✓</td>
          </tr>
          <tr>
            <td style="padding: 8px 0;">🏭 Rekod Pengeluaran</td>
            <td style="text-align: right; color: #2E7D32;">✓</td>
          </tr>
          <tr>
            <td style="padding: 8px 0;">💰 Rekod Jualan & Laporan</td>
            <td style="text-align: right; color: #2E7D32;">✓</td>
          </tr>
          <tr>
            <td style="padding: 8px 0;">📅 Sistem Tempahan</td>
            <td style="text-align: right; color: #2E7D32;">✓</td>
          </tr>
          <tr>
            <td style="padding: 8px 0;">🚚 Penghantaran & Konsainan</td>
            <td style="text-align: right; color: #2E7D32;">✓</td>
          </tr>
          <tr>
            <td style="padding: 8px 0;">📸 Scan Resit AI</td>
            <td style="text-align: right; color: #2E7D32;">✓</td>
          </tr>
          <tr>
            <td style="padding: 8px 0;">💬 WhatsApp Support</td>
            <td style="text-align: right; color: #2E7D32;">✓</td>
          </tr>
        </table>
      </div>
      
      <!-- CTA Buttons -->
      <div style="text-align: center; margin: 0 0 30px 0;">
        <a href="https://app.pocketbizz.my/#/subscription" style="display: inline-block; background: linear-gradient(135deg, #2E7D32 0%, #4CAF50 100%); color: #ffffff; text-decoration: none; padding: 18px 50px; border-radius: 8px; font-size: 18px; font-weight: bold; box-shadow: 0 4px 15px rgba(46,125,50,0.3);">
          🎉 Langgan Sekarang RM29/bulan →
        </a>
        <p style="margin: 15px 0 0 0; font-size: 12px; color: #666;">
          Boleh cancel bila-bila. Tiada hidden charges.
        </p>
      </div>
      
      <!-- Testimonial -->
      <div style="background: #F5F5F5; padding: 20px; border-radius: 12px; margin: 0 0 25px 0;">
        <p style="margin: 0 0 10px 0; font-size: 14px; color: #555; font-style: italic;">
          "Sebelum ni kira stok & untung guna Excel, pening kepala. Lepas guna PocketBizz, 
          semua auto - jimat banyak masa! Sekarang boleh fokus buat kek je."
        </p>
        <p style="margin: 0; font-size: 13px; color: #333; font-weight: bold;">
          - Kak Zura, Kek Homemade Shah Alam
        </p>
      </div>
      
      <!-- Final Message -->
      <div style="text-align: center; padding: 20px 0; border-top: 1px solid #eee;">
        <p style="margin: 0 0 10px 0; font-size: 15px; color: #333;">
          🙏 Terima kasih kerana mencuba PocketBizz!
        </p>
        <p style="margin: 0 0 15px 0; font-size: 14px; color: #666;">
          Kami harap features yang kami tunjukkan dapat membantu bisnes anda berkembang.
        </p>
        <p style="margin: 0; font-size: 13px; color: #999;">
          Ada soalan? WhatsApp: <a href="https://wa.me/60107827802" style="color: #2E7D32;">+60 10-782 7802</a>
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

    console.log(`Sending Day 6 follow-up email to: ${email}`);

    const resendResponse = await fetch("https://api.resend.com/emails", {
      method: "POST",
      headers: {
        "Authorization": `Bearer ${RESEND_API_KEY}`,
        "Content-Type": "application/json",
      },
      body: JSON.stringify({
        from: DEFAULT_FROM,
        to: [email],
        subject: "⏰ 24 JAM LAGI! + Tip Bonus: Scan Resit Automatik",
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

    console.log(`Day 6 follow-up email sent successfully: ${resendResult.id}`);

    return new Response(
      JSON.stringify({ success: true, messageId: resendResult.id }),
      { status: 200, headers: { ...corsHeaders, "Content-Type": "application/json" } }
    );

  } catch (error) {
    console.error("Error sending Day 6 follow-up email:", error);
    return new Response(
      JSON.stringify({ error: "Internal server error", message: error instanceof Error ? error.message : "Unknown error" }),
      { status: 500, headers: { ...corsHeaders, "Content-Type": "application/json" } }
    );
  }
});
