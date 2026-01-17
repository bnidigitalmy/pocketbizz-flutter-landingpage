/**
 * Send Trial Follow-up Day 5: Penghantaran ke Vendor (Konsainan)
 * 
 * Email focus: Consignment delivery tracking
 * Pain point: Manual track stok di kedai, susah claim payment
 * Solution: Rekod penghantaran, track jualan, auto generate tuntutan
 * Benefit: Tahu stok di setiap kedai, auto kira tuntutan
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
      : 2;

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
    <div style="background: linear-gradient(135deg, #00695C 0%, #26A69A 100%); padding: 30px; text-align: center;">
      <div style="font-size: 40px; margin-bottom: 10px;">🚚</div>
      <h1 style="color: #ffffff; margin: 0; font-size: 24px;">Hantar ke Kedai Vendor?</h1>
      <p style="color: #E0F2F1; margin: 10px 0 0 0; font-size: 14px;">Track Semua Dalam Satu App!</p>
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
        Jual produk di kedai-kedai lain (konsainan)? Feature ini <strong>wajib guna</strong>!
        Track semua penghantaran & tuntutan dalam satu tempat.
      </p>
      
      <!-- Pain Point Box -->
      <div style="background: #FFEBEE; padding: 20px; border-radius: 12px; margin: 0 0 25px 0; border-left: 4px solid #EF5350;">
        <p style="margin: 0 0 10px 0; font-size: 15px; color: #C62828; font-weight: bold;">
          😰 Masalah Biasa Konsainan:
        </p>
        <ul style="margin: 0; padding-left: 20px; color: #555; font-size: 14px; line-height: 1.8;">
          <li><strong>Tak ingat</strong> hantar berapa ke kedai mana</li>
          <li>Susah nak <strong>track berapa dah terjual</strong></li>
          <li>Pening nak <strong>kira jumlah tuntutan</strong> - manual!</li>
          <li>Kedai bayar <strong>lambat</strong> atau <strong>kurang</strong></li>
        </ul>
      </div>
      
      <!-- Solution Box -->
      <div style="background: #E0F2F1; padding: 20px; border-radius: 12px; margin: 0 0 25px 0; border-left: 4px solid #26A69A;">
        <p style="margin: 0 0 10px 0; font-size: 15px; color: #00695C; font-weight: bold;">
          ✨ Dengan Feature Konsainan:
        </p>
        <ul style="margin: 0; padding-left: 20px; color: #555; font-size: 14px; line-height: 1.8;">
          <li><strong>Rekod penghantaran</strong> - tahu hantar apa, bila, ke mana</li>
          <li><strong>Track jualan</strong> di setiap kedai</li>
          <li><strong>Auto generate tuntutan</strong> - tak perlu kira manual</li>
          <li><strong>PDF statement</strong> professional untuk kedai</li>
        </ul>
      </div>
      
      <!-- Flow Visual -->
      <div style="background: #F5F5F5; padding: 20px; border-radius: 12px; margin: 0 0 25px 0;">
        <p style="margin: 0 0 15px 0; font-size: 14px; color: #333; font-weight: bold;">📋 Flow Konsainan:</p>
        
        <div style="text-align: center;">
          <div style="display: inline-block; background: #E3F2FD; padding: 15px 20px; border-radius: 8px; margin: 5px;">
            <span style="font-size: 20px;">🏭</span>
            <p style="margin: 5px 0 0 0; font-size: 12px; color: #1565C0;">Buat Produk</p>
          </div>
          <span style="font-size: 20px; color: #999;">→</span>
          <div style="display: inline-block; background: #E0F2F1; padding: 15px 20px; border-radius: 8px; margin: 5px;">
            <span style="font-size: 20px;">🚚</span>
            <p style="margin: 5px 0 0 0; font-size: 12px; color: #00695C;">Hantar ke Kedai</p>
          </div>
          <span style="font-size: 20px; color: #999;">→</span>
          <div style="display: inline-block; background: #FFF8E1; padding: 15px 20px; border-radius: 8px; margin: 5px;">
            <span style="font-size: 20px;">📝</span>
            <p style="margin: 5px 0 0 0; font-size: 12px; color: #F57C00;">Rekod Jualan</p>
          </div>
          <span style="font-size: 20px; color: #999;">→</span>
          <div style="display: inline-block; background: #E8F5E9; padding: 15px 20px; border-radius: 8px; margin: 5px;">
            <span style="font-size: 20px;">💰</span>
            <p style="margin: 5px 0 0 0; font-size: 12px; color: #2E7D32;">Buat Tuntutan</p>
          </div>
        </div>
      </div>
      
      <!-- Example Statement -->
      <div style="background: #ffffff; padding: 15px; border-radius: 8px; border: 1px solid #E0E0E0; margin: 0 0 25px 0;">
        <p style="margin: 0 0 10px 0; font-size: 13px; color: #333; font-weight: bold;">📄 Contoh Statement Tuntutan:</p>
        <table style="width: 100%; font-size: 12px; color: #555; border-collapse: collapse;">
          <tr style="background: #F5F5F5;">
            <td style="padding: 8px; border: 1px solid #E0E0E0;">Kedai ABC</td>
            <td style="padding: 8px; border: 1px solid #E0E0E0; text-align: right;">Jan 2026</td>
          </tr>
          <tr>
            <td style="padding: 8px; border: 1px solid #E0E0E0;">Kek Coklat x 10</td>
            <td style="padding: 8px; border: 1px solid #E0E0E0; text-align: right;">RM 350</td>
          </tr>
          <tr>
            <td style="padding: 8px; border: 1px solid #E0E0E0;">Brownies x 20</td>
            <td style="padding: 8px; border: 1px solid #E0E0E0; text-align: right;">RM 200</td>
          </tr>
          <tr>
            <td style="padding: 8px; border: 1px solid #E0E0E0;">(-) Komisen 15%</td>
            <td style="padding: 8px; border: 1px solid #E0E0E0; text-align: right; color: #C62828;">- RM 82.50</td>
          </tr>
          <tr style="background: #E8F5E9;">
            <td style="padding: 8px; border: 1px solid #E0E0E0; font-weight: bold;">JUMLAH TUNTUTAN</td>
            <td style="padding: 8px; border: 1px solid #E0E0E0; text-align: right; font-weight: bold; color: #2E7D32;">RM 467.50</td>
          </tr>
        </table>
      </div>
      
      <!-- Benefit Highlight -->
      <div style="background: linear-gradient(135deg, #E0F2F1 0%, #B2DFDB 100%); padding: 25px; border-radius: 12px; margin: 0 0 25px 0; text-align: center;">
        <p style="margin: 0 0 5px 0; font-size: 14px; color: #00695C;">🎯 HASIL YANG ANDA DAPAT:</p>
        <p style="margin: 0; font-size: 20px; color: #004D40; font-weight: bold;">
          Tuntutan Tepat, Payment Cepat!
        </p>
        <p style="margin: 10px 0 0 0; font-size: 13px; color: #555;">
          Tak ada lagi "eh, macam kurang je bayaran ni..."
        </p>
      </div>
      
      <!-- How to Start -->
      <h3 style="color: #333; font-size: 16px; margin: 0 0 15px 0;">🚀 Cara Mula:</h3>
      
      <ol style="font-size: 14px; color: #555; line-height: 1.8; margin: 0 0 25px 0; padding-left: 20px;">
        <li>Tambah <strong>Vendor</strong> (kedai yang ambil produk anda)</li>
        <li>Rekod <strong>Penghantaran</strong> bila hantar barang</li>
        <li>Update <strong>Jualan</strong> bila dapat info dari kedai</li>
        <li>Generate <strong>Tuntutan</strong> untuk claim bayaran!</li>
      </ol>
      
      <!-- CTA Button -->
      <div style="text-align: center; margin: 0 0 30px 0;">
        <a href="https://app.pocketbizz.my/#/deliveries" style="display: inline-block; background: linear-gradient(135deg, #00695C 0%, #26A69A 100%); color: #ffffff; text-decoration: none; padding: 15px 40px; border-radius: 8px; font-size: 16px; font-weight: bold;">
          🚚 Mula Rekod Penghantaran →
        </a>
      </div>
      
      <!-- Tip Box -->
      <div style="background: #FFF3E0; padding: 15px; border-radius: 8px; margin: 0 0 20px 0;">
        <p style="margin: 0; font-size: 13px; color: #E65100;">
          💡 <strong>Tip:</strong> Set komisen rate untuk setiap vendor. 
          Sistem akan auto tolak bila generate tuntutan!
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

    console.log(`Sending Day 5 follow-up email to: ${email}`);

    const resendResponse = await fetch("https://api.resend.com/emails", {
      method: "POST",
      headers: {
        "Authorization": `Bearer ${RESEND_API_KEY}`,
        "Content-Type": "application/json",
      },
      body: JSON.stringify({
        from: DEFAULT_FROM,
        to: [email],
        subject: "🚚 Hantar ke Kedai? Track Semua Dalam Satu App!",
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

    console.log(`Day 5 follow-up email sent successfully: ${resendResult.id}`);

    return new Response(
      JSON.stringify({ success: true, messageId: resendResult.id }),
      { status: 200, headers: { ...corsHeaders, "Content-Type": "application/json" } }
    );

  } catch (error) {
    console.error("Error sending Day 5 follow-up email:", error);
    return new Response(
      JSON.stringify({ error: "Internal server error", message: error instanceof Error ? error.message : "Unknown error" }),
      { status: 500, headers: { ...corsHeaders, "Content-Type": "application/json" } }
    );
  }
});
