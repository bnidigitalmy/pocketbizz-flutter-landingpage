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
  amountSource?: "net" | "total" | "jumlah" | "subtotal" | "fallback" | null; // For debugging/UI display
  confidence?: number; // 0.0 - 1.0, for UX display (0.95 = high, 0.8 = medium, 0.6 = low)
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

    const { imageBase64, uploadImage = true } = await req.json();
    
    // PHASE: Subscriber Expired System - Backend Enforcement
    // Check subscription before processing OCR (OCR creates expense data)
    // NOTE: Grace users must be allowed based on grace_until (even if expires_at is past).
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

/**
 * Normalize amount string to number
 * Handles: 1,234.50 (comma as thousand separator) and 1234.50
 * Malaysian receipts typically use: comma = thousand separator, period = decimal
 */
function normalizeAmountString(amountStr: string): number {
  // Remove all commas (thousand separators), keep period as decimal
  const cleaned = amountStr.replace(/,/g, "");
  return parseFloat(cleaned);
}

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
  // Priority order: NET TOTAL > TOTAL > JUMLAH > SUBTOTAL > Fallback (largest non-payment)
  // We want the amount SPENT, not the amount PAID
  // CRITICAL: TOTAL is LOCKED - CASH cannot override even if larger
  
  let totalAmount: number | null = null;
  let amountSource: "net" | "total" | "jumlah" | "subtotal" | "fallback" | null = null;
  
  // Priority 1: NET TOTAL / NETT (most accurate - amount after discounts/tax)
  // IMPROVED: Handles 1,234.50 format (comma as thousand separator)
  // FIX: Use match() instead of exec() to avoid global flag issues
  // FIX: Now matches amounts WITH or WITHOUT decimals (e.g., "TOTAL 23" or "TOTAL 23.50")
  // FIX: Handles various spacing: "TOTAL:RM23", "TOTAL : RM 23", "TOTAL RM23.50"
  const netTotalPattern = /(?:NET\s*TOTAL|NETT\s*TOTAL|NET\s*AMOUNT)[:\s]*(?:RM\s*)?(\d{1,3}(?:[.,]\d{3})*(?:[.,]\d{1,2})?|\d+(?:[.,]\d{1,2})?)/i;
  let match = text.match(netTotalPattern);
  if (match && match[1]) {
    const num = normalizeAmountString(match[1]);
    const normalized = parseFloat(num.toFixed(2));
    if (!isNaN(normalized) && normalized > 0) {
      totalAmount = normalized;
      amountSource = "net";
      console.log(`✅ Found NET TOTAL: ${normalized}`);
    }
  }
  
  // Priority 2: TOTAL / GRAND TOTAL / JUMLAH BESAR (if net total not found)
  // IMPROVED: Handles 1,234.50 format
  // FIX: Use match() to get first match, not continue from previous
  // FIX: More flexible pattern - handles various spacing and formats
  // FIX: Now matches amounts WITH or WITHOUT decimals (e.g., "TOTAL 23" or "TOTAL 23.50")
  if (!totalAmount) {
    // Try multiple patterns for better matching
    // Pattern explanation: (\d{1,3}(?:[.,]\d{3})*(?:[.,]\d{1,2})?|\d+(?:[.,]\d{1,2})?)
    //   - \d{1,3}(?:[.,]\d{3})* = handles thousand separators (1,234 or 1.234)
    //   - (?:[.,]\d{1,2})? = OPTIONAL decimal (makes .50 or ,50 optional)
    //   - |\d+(?:[.,]\d{1,2})? = OR just digits with optional decimal
    const totalPatterns = [
      /(?:TOTAL\s*SALE|GRAND\s*TOTAL|JUMLAH\s*BESAR|AMOUNT\s*DUE)[:\s]*(?:RM\s*)?(\d{1,3}(?:[.,]\d{3})*(?:[.,]\d{1,2})?|\d+(?:[.,]\d{1,2})?)/i,
      /(?:TOTAL)[:\s]*(?:RM\s*)?(\d{1,3}(?:[.,]\d{3})*(?:[.,]\d{1,2})?|\d+(?:[.,]\d{1,2})?)/i,
    ];
    
    for (const totalPattern of totalPatterns) {
      match = text.match(totalPattern);
      if (match && match[1]) {
        const num = normalizeAmountString(match[1]);
        const normalized = parseFloat(num.toFixed(2));
        if (!isNaN(normalized) && normalized > 0) {
          totalAmount = normalized;
          amountSource = "total";
          console.log(`✅ Found TOTAL: ${normalized} (matched pattern: ${totalPattern})`);
          break;
        }
      }
    }
  }
  
  // Priority 3: JUMLAH (if total not found)
  // IMPROVED: Handles 1,234.50 format
  // FIX: Use match() to avoid regex state issues
  // FIX: Now matches amounts WITH or WITHOUT decimals
  if (!totalAmount) {
    const jumlahPattern = /(?:JUMLAH)[:\s]*(?:RM\s*)?(\d{1,3}(?:[.,]\d{3})*(?:[.,]\d{1,2})?|\d+(?:[.,]\d{1,2})?)/i;
    match = text.match(jumlahPattern);
    if (match && match[1]) {
      const num = normalizeAmountString(match[1]);
      const normalized = parseFloat(num.toFixed(2));
      if (!isNaN(normalized) && normalized > 0) {
        totalAmount = normalized;
        amountSource = "jumlah";
        console.log(`✅ Found JUMLAH: ${normalized}`);
      }
    }
  }
  
  // Priority 4: SUBTOTAL / SUB-TOTAL (if nothing else found - less ideal but better than cash)
  // IMPROVED: Handles 1,234.50 format
  // FIX: Use match() to avoid regex state issues
  // FIX: Now matches amounts WITH or WITHOUT decimals
  if (!totalAmount) {
    const subtotalPattern = /(?:SUB[\s-]*TOTAL)[:\s]*(?:RM\s*)?(\d{1,3}(?:[.,]\d{3})*(?:[.,]\d{1,2})?|\d+(?:[.,]\d{1,2})?)/i;
    match = text.match(subtotalPattern);
    if (match && match[1]) {
      const num = normalizeAmountString(match[1]);
      const normalized = parseFloat(num.toFixed(2));
      if (!isNaN(normalized) && normalized > 0) {
        totalAmount = normalized;
        amountSource = "subtotal";
        console.log(`✅ Found SUBTOTAL: ${normalized}`);
      }
    }
  }
  
  // Last resort: Find largest amount (but exclude CASH/TUNAI amounts)
  // CASH/TUNAI is payment amount, not expense amount
  // CRITICAL: Only fallback if NO explicit label found (NET TOTAL, TOTAL, JUMLAH, SUBTOTAL)
  // EXPLICIT LABELS ALWAYS WIN - even if largest amount is bigger
  // This check ensures fallback NEVER runs if we found an explicit label
  if (!totalAmount) {
    // SAFETY CHECK: Verify no explicit labels exist in text (double-check pattern matching)
    // IMPROVED: Pattern now matches amounts with or without decimals
    const hasExplicitLabel = /(?:NET\s*TOTAL|NETT\s*TOTAL|NET\s*AMOUNT|TOTAL\s*SALE|GRAND\s*TOTAL|JUMLAH\s*BESAR|TOTAL|AMOUNT\s*DUE|JUMLAH|SUB[\s-]*TOTAL)[:\s]*(?:RM\s*)?\d/i.test(text);
    if (hasExplicitLabel) {
      console.error("⚠️ WARNING: Explicit label detected in text but not matched by patterns!");
      console.error("   This suggests a pattern matching issue - patterns may need adjustment");
      console.error("   NOT using fallback to prevent override of explicit labels");
      // Don't use fallback if explicit label exists - this prevents override
      // Set to null to indicate pattern matching failed
      totalAmount = null;
      amountSource = null;
    } else {
      console.log("⚠️ No TOTAL/NET TOTAL/JUMLAH/SUBTOTAL found, using fallback (largest amount)");
    }
    
    // Only proceed with fallback if no explicit label was found
    if (!totalAmount && !hasExplicitLabel) {
      const allAmounts: Array<{ value: number; line: string }> = [];
    // IMPROVED: Handles 1,234.50 format (comma as thousand separator)
    // FIX: Now matches amounts WITH or WITHOUT decimals
    const amountPattern = /(\d{1,3}(?:[.,]\d{3})*(?:[.,]\d{1,2})?|\d+(?:[.,]\d{1,2})?)/g;
    
    // FIX #1: Payment Context Window - Skip lines after CASH/TUNAI keywords
    // OCR often puts CASH and amount on separate lines:
    //   "TOTAL 23.50"
    //   "CASH"
    //   "50.00"  ← This gets captured without context window
    let skipNextLines = 0;

    for (let i = 0; i < lines.length; i++) {
      const line = lines[i];

      // If payment keyword found, skip this line + next 2 lines (payment context window)
      // IMPROVED: Added more payment keywords - DIBAYAR, PAID, TENDER, RECEIVED, TERIMA, WANG MASUK
      if (/(?:TUNAI|CASH|BAYAR|DIBAYAR|PAYMENT|PAID|TENDER|CHANGE|BAKI|RECEIVED|TERIMA|WANG\s*MASUK|AMOUNT\s*RECEIVED|AMOUNT\s*TENDERED)/i.test(line)) {
        skipNextLines = 2; // Skip current line + next 2 lines
        continue;
      }
      
      // Skip lines in payment context window
      if (skipNextLines > 0) {
        skipNextLines--;
        continue;
      }
      
      // Extract amounts from non-payment lines
      let lineMatch;
      while ((lineMatch = amountPattern.exec(line)) !== null) {
        const num = normalizeAmountString(lineMatch[1]);
        const normalized = parseFloat(num.toFixed(2));
        if (!isNaN(normalized) && normalized > 0 && normalized < 100000) {
          allAmounts.push({ value: normalized, line });
        }
      }
    }
    
      if (allAmounts.length > 0) {
        // Get the largest amount (usually the total, excluding cash payments)
        totalAmount = Math.max(...allAmounts.map(a => a.value));
        amountSource = "fallback";
        console.log(`⚠️ Fallback: Using largest amount ${totalAmount} from ${allAmounts.length} candidates`);
        console.log(`   Candidates:`, allAmounts.map(a => `${a.value} (${a.line.substring(0, 30)})`).join(", "));
        console.log(`   ⚠️ Note: Fallback is used ONLY when no explicit labels (TOTAL/NET TOTAL/JUMLAH) are found`);
      } else {
        console.log("⚠️ Fallback: No amounts found in receipt");
      }
    }
  }
  
  // FIX #2: Final Safety Guard - Prevent CASH from overriding TOTAL
  // Even if fallback found an amount, if it matches CASH value, reject it
  // IMPROVED: Added more payment keywords and handles amounts with/without decimals
  if (totalAmount && amountSource === "fallback" && /(?:CASH|TUNAI|DIBAYAR|PAID|TENDER|RECEIVED|TERIMA)/i.test(text)) {
    const cashMatch = text.match(/(?:CASH|TUNAI|DIBAYAR|PAID|TENDER|RECEIVED|TERIMA)[^\d]*(\d+(?:[.,]\d{1,2})?)/i);
    if (cashMatch) {
      const cashValue = parseFloat(cashMatch[1].replace(",", "."));
      if (Math.abs(totalAmount - cashValue) < 0.01) { // Allow small floating point differences
        // This amount is likely CASH payment, not expense total
        totalAmount = null;
        amountSource = null;
        console.log("⚠️ Rejected amount matching CASH payment:", cashValue);
      }
    }
  }
  
  // FIX #3: Lock TOTAL - Never allow fallback to override explicit TOTAL
  // CRITICAL: If we found ANY explicit label (NET TOTAL, TOTAL, JUMLAH, SUBTOTAL), it's LOCKED
  // Fallback CANNOT override even if largest amount is bigger
  if (amountSource && ["net", "total", "jumlah", "subtotal"].includes(amountSource)) {
    // Amount is locked - EXPLICIT LABEL FOUND, NEVER USE FALLBACK
    console.log(`✅ Amount LOCKED from source: ${amountSource}, value: ${totalAmount}`);
    console.log(`   ⚠️ Fallback will NOT override this amount, even if larger amounts exist`);
    
    // DOUBLE-CHECK: Verify we didn't accidentally use fallback
    if (amountSource === "fallback") {
      console.error("❌ ERROR: Fallback should not be set when explicit label found!");
      // This should never happen, but just in case
    }
  } else if (!totalAmount) {
    console.log("❌ No amount found - all patterns failed to match");
  } else if (amountSource === "fallback") {
    console.log(`⚠️ Using fallback amount: ${totalAmount} (no explicit TOTAL/NET TOTAL/JUMLAH/SUBTOTAL found in receipt)`);
    console.log(`   ℹ️ Fallback is used ONLY when no explicit labels are found`);
  }
  
  // FINAL ENFORCEMENT: Triple-check that explicit labels always win
  // This is the ultimate safety net - if explicit label exists in text but fallback was used, something is wrong
  // IMPROVED: Pattern now matches amounts with or without decimals
  const explicitLabelExists = /(?:NET\s*TOTAL|NETT\s*TOTAL|NET\s*AMOUNT|TOTAL\s*SALE|GRAND\s*TOTAL|JUMLAH\s*BESAR|TOTAL|AMOUNT\s*DUE|JUMLAH|SUB[\s-]*TOTAL)[:\s]*(?:RM\s*)?\d/i.test(text);
  if (explicitLabelExists && amountSource === "fallback" && totalAmount) {
    console.error("❌ CRITICAL: Explicit label found in text but fallback was used!");
    console.error("   This indicates a pattern matching failure - patterns need to be fixed");
    console.error("   For safety, we should NOT use fallback amount when explicit label exists");
    // SAFETY: Reject fallback to prevent override of explicit labels
    // This ensures explicit labels ALWAYS win, even if pattern matching failed
    totalAmount = null;
    amountSource = null;
    console.error("   ⚠️ Amount set to null - pattern matching needs investigation");
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

  // Include amount source for debugging/UI display
  result.amountSource = amountSource;

  // Calculate confidence score based on source (UX booster)
  // High confidence: net, total (explicit labels)
  // Medium confidence: jumlah, subtotal (less explicit)
  // Low confidence: fallback (estimated)
  if (amountSource === "net" || amountSource === "total") {
    result.confidence = 0.95; // 🟢 High confidence
  } else if (amountSource === "jumlah" || amountSource === "subtotal") {
    result.confidence = 0.8; // 🟡 Medium confidence
  } else if (amountSource === "fallback") {
    result.confidence = 0.6; // 🔴 Low confidence (needs review)
  } else {
    result.confidence = 0.0; // No amount found
  }

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
