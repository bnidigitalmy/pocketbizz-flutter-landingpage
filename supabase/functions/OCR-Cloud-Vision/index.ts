// Supabase Edge Function: OCR Receipt using Google Cloud Vision
// Accepts base64 image and returns extracted text + parsed receipt data
// Also uploads image to Supabase Storage and returns storage path
// Optimized for Malaysian receipts (bakery, grocery, petrol, etc.)

import { serve } from "https://deno.land/std@0.168.0/http/server.ts";
import { createClient } from "https://esm.sh/@supabase/supabase-js@2.47.0";

const GOOGLE_CLOUD_API_KEY = Deno.env.get("GOOGLE_CLOUD_API_KEY");
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
        // Extract user ID from JWT token payload
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
    
    if (!userId && uploadImage) {
      console.warn("No user ID found - image upload will be skipped");
    }

    const { imageBase64, uploadImage = true } = await req.json();
    
    if (!imageBase64) {
      return new Response(
        JSON.stringify({ success: false, error: "Missing imageBase64" }),
        { status: 400, headers: { ...corsHeaders, "Content-Type": "application/json" } }
      );
    }

    // Remove data URL prefix if present
    const base64Data = imageBase64.replace(/^data:image\/\w+;base64,/, "");

    // Call Google Cloud Vision API
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

    // Parse the receipt text with improved Malaysian receipt patterns
    const parsed = parseReceiptText(rawText);

    // Upload image to storage if requested and user ID available
    let storagePath: string | null = null;
    if (uploadImage && userId) {
      try {
        const timestamp = Date.now();
        const now = new Date();
        const datePath = `${now.getFullYear()}/${String(now.getMonth() + 1).padStart(2, "0")}`;
        const fileName = `receipt-${timestamp}.jpg`;
        const storagePathFull = `${userId}/${datePath}/${fileName}`;
        
        // Convert base64 to Uint8Array
        const imageBytes = Uint8Array.from(atob(base64Data), c => c.charCodeAt(0));
        
        // Upload to Supabase Storage
        const { data: uploadData, error: uploadError } = await supabase.storage
          .from(RECEIPTS_BUCKET)
          .upload(storagePathFull, imageBytes, {
            contentType: "image/jpeg",
            upsert: false,
          });
        
        if (uploadError) {
          console.error("Storage upload error:", uploadError);
          // Don't fail OCR if upload fails - just log it
        } else {
          storagePath = `${RECEIPTS_BUCKET}/${storagePathFull}`;
          console.log("✅ Image uploaded to storage:", storagePath);
        }
      } catch (uploadErr) {
        console.error("Failed to upload image:", uploadErr);
        // Continue without storage path - OCR still succeeded
      }
    }

    return new Response(
      JSON.stringify({
        success: true,
        rawText,
        parsed,
        storagePath, // Return storage path if uploaded
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

function parseReceiptText(text: string): ParsedReceipt {
  const result: ParsedReceipt = {
    amount: null,
    date: null,
    merchant: null,
    items: [], // Keep empty - not extracting items anymore
    rawText: text,
    category: "lain",
  };

  const lines = text.split("\n").map(l => l.trim()).filter(l => l);
  const fullTextLower = text.toLowerCase();

  // ===== EXTRACT TOTAL AMOUNT =====
  // Priority order: NET TOTAL > TOTAL > JUMLAH > CASH (cash is payment, not expense amount)
  // We want the amount SPENT, not the amount PAID
  
  let totalAmount: number | null = null;
  
  // Priority 1: NET TOTAL / NETT (most accurate - amount after discounts/tax)
  const netTotalPattern = /(?:NET\s*TOTAL|NETT|NET)[:\s]*RM?\s*(\d+[.,]\d{2,4})/gi;
  let match = netTotalPattern.exec(text);
  if (match) {
    const numStr = match[1].replace(",", ".");
    const num = parseFloat(parseFloat(numStr).toFixed(2));
    if (!isNaN(num) && num > 0) {
      totalAmount = num;
    }
  }
  
  // Priority 2: TOTAL / GRAND TOTAL / JUMLAH BESAR (if net total not found)
  if (!totalAmount) {
    const totalPattern = /(?:TOTAL\s*SALE|GRAND\s*TOTAL|JUMLAH\s*BESAR|TOTAL|AMOUNT\s*DUE)[:\s]*RM?\s*(\d+[.,]\d{2,4})/gi;
    match = totalPattern.exec(text);
    if (match) {
      const numStr = match[1].replace(",", ".");
      const num = parseFloat(parseFloat(numStr).toFixed(2));
      if (!isNaN(num) && num > 0) {
        totalAmount = num;
      }
    }
  }
  
  // Priority 3: JUMLAH (if total not found)
  if (!totalAmount) {
    const jumlahPattern = /(?:JUMLAH)[:\s]*RM?\s*(\d+[.,]\d{2,4})/gi;
    match = jumlahPattern.exec(text);
    if (match) {
      const numStr = match[1].replace(",", ".");
      const num = parseFloat(parseFloat(numStr).toFixed(2));
      if (!isNaN(num) && num > 0) {
        totalAmount = num;
      }
    }
  }
  
  // Priority 4: SUBTOTAL (if nothing else found - less ideal but better than cash)
  if (!totalAmount) {
    const subtotalPattern = /(?:SUBTOTAL)[:\s]*RM?\s*(\d+[.,]\d{2,4})/gi;
    match = subtotalPattern.exec(text);
    if (match) {
      const numStr = match[1].replace(",", ".");
      const num = parseFloat(parseFloat(numStr).toFixed(2));
      if (!isNaN(num) && num > 0) {
        totalAmount = num;
      }
    }
  }
  
  // Last resort: Find largest amount (but exclude CASH/TUNAI amounts)
  // CASH/TUNAI is payment amount, not expense amount
  if (!totalAmount) {
    const allAmounts: Array<{ value: number; line: string }> = [];
    const amountPattern = /(\d+[.,]\d{2,4})/g;
    
    // Extract all amounts with their context
    for (let i = 0; i < lines.length; i++) {
      const line = lines[i];
      // Skip lines that contain CASH/TUNAI/BAYAR (these are payment amounts)
      if (/(?:TUNAI|CASH|BAYAR|CHANGE|BAKI)/i.test(line)) {
        continue;
      }
      
      let lineMatch;
      while ((lineMatch = amountPattern.exec(line)) !== null) {
        const num = parseFloat(lineMatch[1].replace(",", "."));
        if (!isNaN(num) && num > 0 && num < 100000) {
          allAmounts.push({ value: parseFloat(num.toFixed(2)), line });
        }
      }
    }
    
    if (allAmounts.length > 0) {
      // Get the largest amount (usually the total, excluding cash payments)
      totalAmount = Math.max(...allAmounts.map(a => a.value));
    }
  }
  
  result.amount = totalAmount;

  // ===== EXTRACT DATE =====
  const datePatterns = [
    /(\d{1,2})[\/\-.](\d{1,2})[\/\-.](\d{4})/,  // DD/MM/YYYY
    /(\d{4})[\/\-.](\d{1,2})[\/\-.](\d{1,2})/,  // YYYY/MM/DD
    /(\d{1,2})[\/\-.](\d{1,2})[\/\-.](\d{2})(?!\d)/,  // DD/MM/YY
  ];

  for (const pattern of datePatterns) {
    const match = text.match(pattern);
    if (match) {
      let dateStr = match[0];
      // Normalize to DD/MM/YYYY format
      const parts = dateStr.split(/[\/\-.]/);
      if (parts[0].length === 4) {
        // YYYY/MM/DD -> DD/MM/YYYY
        dateStr = `${parts[2]}/${parts[1]}/${parts[0]}`;
      } else if (parts[2].length === 2) {
        // DD/MM/YY -> DD/MM/20YY
        dateStr = `${parts[0]}/${parts[1]}/20${parts[2]}`;
      }
      result.date = dateStr;
      break;
    }
  }

  // ===== EXTRACT MERCHANT/VENDOR/SUPPLIER NAME =====
  // Enhanced patterns for Malaysian merchants/suppliers/kedai
  const merchantPatterns = [
    /(?:BAKERY|KEDAI|RESTORAN|RESTAURANT|CAFÉ|CAFE|MART|STORE|SHOP|SDN\.?\s*BHD|ENTERPRISE|SUPPLIER|VENDOR|PEMBEKAL)/i,
  ];
  
  // Look for merchant in first 15 lines (more lines for better detection)
  for (let i = 0; i < Math.min(lines.length, 15); i++) {
    const line = lines[i];
    
    // Skip lines that are clearly not merchant names
    if (
      /^\d+[\/\-.]/.test(line) ||  // Dates
      /^\d{1,2}:\d{2}/.test(line) ||  // Times
      /^RM\s*\d/.test(line) ||  // Amounts
      /^NO\.|^TEL|^FAX|^GST|^SST|^REG|^INVOICE\s*NO/i.test(line) ||  // Labels
      /^\d+$/.test(line) ||  // Pure numbers
      /^CASH\s*BILL|^TAX\s*INVOICE|^RECEIPT|^RESIT/i.test(line) ||  // Document types
      line.length < 3 ||
      line.length > 80
    ) {
      continue;
    }

    // Check if line contains merchant indicators
    for (const pattern of merchantPatterns) {
      if (pattern.test(line)) {
        result.merchant = line.replace(/\s+/g, ' ').trim();
        break;
      }
    }
    
    if (result.merchant) break;
    
    // If no pattern matched, use first reasonable line as merchant (more lenient)
    if (i < 5 && line.length > 4 && /[A-Za-z]/.test(line)) {
      // Check it's not a common header word
      if (!/^(CASH|BILL|RECEIPT|RESIT|TAX|INVOICE|TOTAL|JUMLAH|SUBTOTAL|DATE|TARIKH|TIME|MASA)/i.test(line)) {
        result.merchant = line.replace(/\s+/g, ' ').trim();
        break;
      }
    }
  }

  // ===== ITEMS EXTRACTION REMOVED =====
  // User only needs: merchant, date, category, amount
  // Items extraction removed for simplicity
  result.items = [];

  // ===== AUTO-DETECT CATEGORY =====
  result.category = detectCategory(fullTextLower, result.merchant || "");

  return result;
}

function isValidItemName(name: string): boolean {
  if (!name || name.trim().length < 2 || name.trim().length > 100) return false;
  
  const trimmed = name.trim();
  
  // Skip if it's a total/subtotal line
  if (/^(TOTAL|JUMLAH|SUBTOTAL|CASH|TUNAI|CHANGE|BAKI|ROUNDING|SST|GST|TAX|DISCOUNT|DISKAUN|BALANCE|BAYAR|PAYMENT)/i.test(trimmed)) {
    return false;
  }
  
  // Skip if it's mostly numbers (but allow numbers with text like "2x" or "500g")
  const withoutSpaces = trimmed.replace(/\s/g, '');
  if (/^\d+$/.test(withoutSpaces)) return false;
  
  // Skip common headers
  if (/^(QTY|ITEM|UNIT|PRICE|DESCRIPTION|CODE|TOTAL|NO\.|BIL|RECEIPT|RESIT)/i.test(trimmed)) return false;
  
  // Must contain at least one letter (not just numbers and symbols)
  if (!/[A-Za-z]/.test(trimmed)) return false;
  
  // Skip if it's a date/time pattern
  if (/^\d{1,2}[\/\-.]\d{1,2}[\/\-.]\d{2,4}$/.test(trimmed)) return false;
  if (/^\d{1,2}:\d{2}/.test(trimmed)) return false;
  
  return true;
}

function detectCategory(text: string, merchant: string): string {
  const combined = (text + " " + merchant).toLowerCase();

  // Petrol/Minyak
  if (/petrol|petronas|shell|caltex|bhp|petron|diesel|fuel|minyak\s*(?:kereta|petrol)/i.test(combined)) {
    return "minyak";
  }

  // Plastik/Packaging
  if (/plastik|plastic|packaging|pembungkus|kotak|box|container|beg\s*plastik/i.test(combined)) {
    return "plastik";
  }

  // Upah/Wages
  if (/gaji|upah|salary|wage|bayaran\s*pekerja|worker/i.test(combined)) {
    return "upah";
  }

  // Bahan Mentah (Raw Materials / Groceries / Bakery Supplies)
  if (/tepung|flour|gula|sugar|mentega|butter|telur|egg|susu|milk|bahan|ingredient/i.test(combined)) {
    return "bahan";
  }
  if (/bakery|baking|chocolate|cream|whip|vanilla|yeast|icing/i.test(combined)) {
    return "bahan";
  }
  if (/grocer|mydin|econsave|giant|tesco|aeon|jaya\s*grocer|lotus|99\s*speed/i.test(combined)) {
    return "bahan";
  }
  if (/supplies|pembekal|supplier/i.test(combined)) {
    return "bahan";
  }

  return "lain";
}
