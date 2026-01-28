// Supabase Edge Function: OCR Receipt using Google Cloud Vision + Gemini Flash
// 1. Vision API extracts raw text from image
// 2. Gemini Flash intelligently extracts: amount, date, merchant, category
// Optimized for Malaysian receipts (bakery, grocery, petrol, etc.)

import { serve } from "https://deno.land/std@0.168.0/http/server.ts";
import { createClient } from "https://esm.sh/@supabase/supabase-js@2.47.0";

const GOOGLE_CLOUD_API_KEY = Deno.env.get("GOOGLE_CLOUD_API_KEY");
const GEMINI_API_KEY = Deno.env.get("GEMINI_API_KEY"); // From Google AI Studio
const SUPABASE_URL = Deno.env.get("SUPABASE_URL")!;
const SUPABASE_SERVICE_ROLE_KEY = Deno.env.get("SUPABASE_SERVICE_ROLE_KEY")!;

// Initialize Supabase client with service role for storage upload
const supabase = createClient(SUPABASE_URL, SUPABASE_SERVICE_ROLE_KEY);
const RECEIPTS_BUCKET = "receipts";

const corsHeaders = {
  "Access-Control-Allow-Origin": "*",
  "Access-Control-Allow-Headers": "authorization, x-client-info, apikey, content-type",
};

interface VisionResponse {
  responses: Array<{
    textAnnotations?: Array<{
      description: string;
      boundingPoly: {
        vertices: Array<{ x: number; y: number }>;
      };
    }>;
    fullTextAnnotation?: {
      text: string;
    };
    error?: {
      code: number;
      message: string;
    };
  }>;
}

interface ParsedReceipt {
  amount: number | null;
  date: string | null;
  merchant: string | null;
  items: Array<{ name: string; price: number }>;
  rawText: string;
  category: string;
  confidence?: number;
}

interface GeminiResponse {
  candidates?: Array<{
    content: {
      parts: Array<{
        text: string;
      }>;
    };
  }>;
  error?: {
    message: string;
  };
}

serve(async (req) => {
  // Handle CORS preflight
  if (req.method === "OPTIONS") {
    return new Response("ok", { headers: corsHeaders });
  }

  try {
    if (!GOOGLE_CLOUD_API_KEY) {
      throw new Error("GOOGLE_CLOUD_API_KEY not configured");
    }

    // Get user ID from Authorization header (JWT token)
    const authHeader = req.headers.get("Authorization");
    let userId: string | null = null;

    if (authHeader) {
      try {
        const token = authHeader.replace("Bearer ", "");
        const parts = token.split(".");
        if (parts.length === 3) {
          const payload = JSON.parse(atob(parts[1]));
          userId = payload.sub || payload.user_id || null;
          console.log("Extracted user ID from token:", userId);
        }
      } catch (e) {
        console.warn("Could not extract user ID from token:", e);
      }
    }

    const { imageBase64, uploadImage = true } = await req.json();

    // Check subscription before processing
    const nowIso = new Date().toISOString();
    if (userId) {
      const { data: subscription, error: subError } = await supabase
        .from("subscriptions")
        .select("status, expires_at, grace_until")
        .eq("user_id", userId)
        .in("status", ["active", "trial", "grace"])
        .or(`expires_at.gt.${nowIso},grace_until.gt.${nowIso}`)
        .order("created_at", { ascending: false })
        .limit(1)
        .maybeSingle();

      if (subError || !subscription) {
        return new Response(
          JSON.stringify({
            success: false,
            error: "Subscription required",
            message: "Langganan anda telah tamat. Sila aktifkan semula untuk guna OCR.",
          }),
          { status: 403, headers: { ...corsHeaders, "Content-Type": "application/json" } }
        );
      }
    }

    if (!userId && uploadImage) {
      console.warn("No user ID found - image upload will be skipped");
    }

    if (!imageBase64) {
      return new Response(
        JSON.stringify({ success: false, error: "Missing imageBase64" }),
        { status: 400, headers: { ...corsHeaders, "Content-Type": "application/json" } }
      );
    }

    // Remove data URL prefix if present
    const base64Data = imageBase64.replace(/^data:image\/\w+;base64,/, "");

    // ========== STEP 1: Google Vision API - Extract raw text ==========
    console.log("📷 Step 1: Calling Google Vision API...");
    const visionUrl = `https://vision.googleapis.com/v1/images:annotate?key=${GOOGLE_CLOUD_API_KEY}`;

    const visionRequest = {
      requests: [
        {
          image: { content: base64Data },
          features: [
            { type: "TEXT_DETECTION" },
            { type: "DOCUMENT_TEXT_DETECTION" }
          ],
        },
      ],
    };

    const visionResponse = await fetch(visionUrl, {
      method: "POST",
      headers: { "Content-Type": "application/json" },
      body: JSON.stringify(visionRequest),
    });

    if (!visionResponse.ok) {
      const errorText = await visionResponse.text();
      throw new Error(`Vision API error: ${visionResponse.status} - ${errorText}`);
    }

    const visionData: VisionResponse = await visionResponse.json();

    if (visionData.responses[0]?.error) {
      throw new Error(visionData.responses[0].error.message);
    }

    const rawText = visionData.responses[0]?.fullTextAnnotation?.text ||
                    visionData.responses[0]?.textAnnotations?.[0]?.description ||
                    "";

    console.log("✅ Vision API returned text:", rawText.substring(0, 200) + "...");

    // ========== STEP 2: Gemini Flash - Intelligent extraction ==========
    console.log("🤖 Step 2: Calling Gemini Flash for intelligent extraction...");
    const parsed = await extractWithGemini(rawText);
    console.log("✅ Gemini extracted:", JSON.stringify(parsed));

    // ========== STEP 3: Upload image to storage ==========
    let storagePath: string | null = null;
    if (uploadImage && userId) {
      try {
        const timestamp = Date.now();
        const now = new Date();
        const datePath = `${now.getFullYear()}/${String(now.getMonth() + 1).padStart(2, "0")}`;
        const fileName = `receipt-${timestamp}.jpg`;
        const storagePathFull = `${userId}/${datePath}/${fileName}`;

        const imageBytes = Uint8Array.from(atob(base64Data), c => c.charCodeAt(0));

        const { error: uploadError } = await supabase.storage
          .from(RECEIPTS_BUCKET)
          .upload(storagePathFull, imageBytes, {
            contentType: "image/jpeg",
            upsert: false,
          });

        if (uploadError) {
          console.error("Storage upload error:", uploadError);
        } else {
          storagePath = `${RECEIPTS_BUCKET}/${storagePathFull}`;
          console.log("✅ Image uploaded to storage:", storagePath);
        }
      } catch (uploadErr) {
        console.error("Failed to upload image:", uploadErr);
      }
    }

    return new Response(
      JSON.stringify({
        success: true,
        rawText,
        parsed,
        storagePath,
      }),
      { headers: { ...corsHeaders, "Content-Type": "application/json" } }
    );

  } catch (error) {
    console.error("OCR Error:", error);
    return new Response(
      JSON.stringify({
        success: false,
        error: error instanceof Error ? error.message : "Unknown error"
      }),
      { status: 500, headers: { ...corsHeaders, "Content-Type": "application/json" } }
    );
  }
});

/**
 * Use Gemini Flash to intelligently extract receipt data
 * Much more accurate than regex patterns!
 */
async function extractWithGemini(rawText: string): Promise<ParsedReceipt> {
  const result: ParsedReceipt = {
    amount: null,
    date: null,
    merchant: null,
    items: [],
    rawText: rawText,
    category: "lain",
    confidence: 0,
  };

  if (!rawText || rawText.trim().length < 10) {
    console.log("⚠️ Raw text too short, skipping Gemini extraction");
    return result;
  }

  if (!GEMINI_API_KEY) {
    console.log("⚠️ GEMINI_API_KEY not configured, using fallback extraction");
    return fallbackExtraction(rawText);
  }

  try {
    const geminiUrl = `https://generativelanguage.googleapis.com/v1beta/models/gemini-2.5-flash-lite:generateContent?key=${GEMINI_API_KEY}`;

    const prompt = `Kamu adalah AI yang pakar dalam membaca resit/invois Malaysia.

Dari teks OCR resit di bawah, ekstrak maklumat berikut:
1. **amount**: Jumlah TOTAL yang perlu dibayar (bukan CASH/TUNAI yang dibayar). Cari label seperti: TOTAL, JUMLAH, NET TOTAL, AMOUNT DUE, SUBTOTAL. Jangan ambil nilai CASH/TUNAI/BAYAR/CHANGE/BAKI.
2. **date**: Tarikh resit dalam format DD/MM/YYYY
3. **merchant**: Nama kedai/syarikat (biasanya di bahagian atas resit)
4. **category**: Kategori perbelanjaan, pilih SATU dari: "bahan" (bahan mentah/groceries), "minyak" (petrol/diesel), "upah" (gaji/upah), "plastik" (packaging), "lain" (lain-lain)

PENTING:
- Untuk amount, WAJIB ambil nilai TOTAL/JUMLAH, BUKAN nilai CASH/TUNAI yang lebih besar
- Contoh: jika TOTAL=23.50 dan CASH=50.00, jawapan amount=23.50
- Jika tak jumpa, set null

Teks OCR:
"""
${rawText.substring(0, 2000)}
"""

Balas dalam format JSON sahaja, tanpa markdown:
{"amount": 123.45, "date": "28/01/2026", "merchant": "Nama Kedai", "category": "bahan", "confidence": 0.95}

Jika tak pasti, set confidence rendah (0.5-0.7). Jika yakin, set tinggi (0.9-1.0).`;

    const geminiRequest = {
      contents: [
        {
          parts: [{ text: prompt }]
        }
      ],
      generationConfig: {
        temperature: 0.1, // Low temperature for consistent extraction
        maxOutputTokens: 200,
      }
    };

    const geminiResponse = await fetch(geminiUrl, {
      method: "POST",
      headers: { "Content-Type": "application/json" },
      body: JSON.stringify(geminiRequest),
    });

    if (!geminiResponse.ok) {
      const errorText = await geminiResponse.text();
      console.error("Gemini API error:", geminiResponse.status, errorText);
      // Fallback to basic extraction if Gemini fails
      return fallbackExtraction(rawText);
    }

    const geminiData: GeminiResponse = await geminiResponse.json();

    if (geminiData.error) {
      console.error("Gemini error:", geminiData.error.message);
      return fallbackExtraction(rawText);
    }

    const responseText = geminiData.candidates?.[0]?.content?.parts?.[0]?.text || "";
    console.log("Gemini raw response:", responseText);

    // Parse JSON response from Gemini
    // Handle potential markdown code blocks
    let jsonStr = responseText.trim();
    if (jsonStr.startsWith("```")) {
      jsonStr = jsonStr.replace(/```json?\n?/g, "").replace(/```/g, "").trim();
    }

    const extracted = JSON.parse(jsonStr);

    result.amount = typeof extracted.amount === "number" ? extracted.amount : null;
    result.date = extracted.date || null;
    result.merchant = extracted.merchant || null;
    result.category = ["bahan", "minyak", "upah", "plastik", "lain"].includes(extracted.category)
      ? extracted.category
      : "lain";
    result.confidence = typeof extracted.confidence === "number" ? extracted.confidence : 0.8;

    console.log("✅ Gemini extraction successful:", result);
    return result;

  } catch (error) {
    console.error("Gemini extraction error:", error);
    // Fallback to basic regex extraction
    return fallbackExtraction(rawText);
  }
}

/**
 * Fallback extraction using simple patterns (if Gemini fails)
 */
function fallbackExtraction(text: string): ParsedReceipt {
  console.log("⚠️ Using fallback regex extraction");

  const result: ParsedReceipt = {
    amount: null,
    date: null,
    merchant: null,
    items: [],
    rawText: text,
    category: "lain",
    confidence: 0.5, // Low confidence for fallback
  };

  const lines = text.split("\n").map(l => l.trim()).filter(l => l);

  // Simple TOTAL extraction
  const totalMatch = text.match(/(?:TOTAL|JUMLAH)[:\s]*(?:RM\s*)?(\d+(?:[.,]\d{1,2})?)/i);
  if (totalMatch) {
    result.amount = parseFloat(totalMatch[1].replace(",", "."));
  }

  // Simple date extraction
  const dateMatch = text.match(/(\d{1,2})[\/\-.](\d{1,2})[\/\-.](\d{2,4})/);
  if (dateMatch) {
    let [_, d, m, y] = dateMatch;
    if (y.length === 2) y = "20" + y;
    result.date = `${d}/${m}/${y}`;
  }

  // Simple merchant extraction (first reasonable line)
  for (let i = 0; i < Math.min(lines.length, 5); i++) {
    const line = lines[i];
    if (line.length > 4 && line.length < 50 && /[A-Za-z]/.test(line)) {
      if (!/^(CASH|RECEIPT|RESIT|TAX|INVOICE|TOTAL)/i.test(line)) {
        result.merchant = line;
        break;
      }
    }
  }

  // Simple category detection
  const lowerText = text.toLowerCase();
  if (/petrol|petronas|shell|caltex|bhp|diesel/i.test(lowerText)) {
    result.category = "minyak";
  } else if (/plastik|packaging|beg/i.test(lowerText)) {
    result.category = "plastik";
  } else if (/gaji|upah|salary/i.test(lowerText)) {
    result.category = "upah";
  } else if (/grocer|mydin|econsave|giant|tesco|aeon|tepung|gula|telur/i.test(lowerText)) {
    result.category = "bahan";
  }

  return result;
}
