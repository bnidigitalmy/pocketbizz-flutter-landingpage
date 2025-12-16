// Supabase Edge Function: OCR Receipt using Google Cloud Vision
// Accepts base64 image and returns extracted text + parsed receipt data
// Optimized for Malaysian receipts (bakery, grocery, petrol, etc.)

import { serve } from "https://deno.land/std@0.168.0/http/server.ts";

const GOOGLE_CLOUD_API_KEY = Deno.env.get("GOOGLE_CLOUD_API_KEY");

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

    const { imageBase64 } = await req.json();
    
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

    return new Response(
      JSON.stringify({
        success: true,
        rawText,
        parsed,
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
    items: [],
    rawText: text,
    category: "lain",
  };

  const lines = text.split("\n").map(l => l.trim()).filter(l => l);
  const fullTextLower = text.toLowerCase();

  // ===== EXTRACT TOTAL AMOUNT =====
  // Look for specific total keywords first (Malaysian receipt patterns)
  const totalKeywords = [
    /(?:TOTAL\s*SALE|GRAND\s*TOTAL|JUMLAH\s*BESAR|JUMLAH|TOTAL|AMOUNT\s*DUE)[:\s]*RM?\s*(\d+[.,]\d{2,4})/gi,
    /(?:TUNAI|CASH|BAYAR)[:\s]*RM?\s*(\d+[.,]\d{2,4})/gi,
    /(?:NETT|NET)[:\s]*RM?\s*(\d+[.,]\d{2,4})/gi,
  ];

  let totalAmount: number | null = null;
  
  for (const pattern of totalKeywords) {
    const match = pattern.exec(text);
    if (match) {
      const numStr = match[1].replace(",", ".");
      // Handle 4 decimal places (e.g., 25.0000 -> 25.00)
      const num = parseFloat(parseFloat(numStr).toFixed(2));
      if (!isNaN(num) && num > 0) {
        totalAmount = num;
        break;
      }
    }
  }

  // If no total found, look for the largest amount in the text
  if (!totalAmount) {
    const allAmounts: number[] = [];
    const amountPattern = /(\d+[.,]\d{2,4})/g;
    let match;
    while ((match = amountPattern.exec(text)) !== null) {
      const num = parseFloat(match[1].replace(",", "."));
      if (!isNaN(num) && num > 0 && num < 100000) {
        allAmounts.push(parseFloat(num.toFixed(2)));
      }
    }
    if (allAmounts.length > 0) {
      // Get the largest amount (usually the total)
      totalAmount = Math.max(...allAmounts);
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

  // ===== EXTRACT MERCHANT NAME =====
  // Common Malaysian merchant patterns
  const merchantPatterns = [
    /(?:BAKERY|KEDAI|RESTORAN|RESTAURANT|CAFÉ|CAFE|MART|STORE|SHOP|SDN\.?\s*BHD|ENTERPRISE)/i,
  ];
  
  // Look for merchant in first 10 lines
  for (let i = 0; i < Math.min(lines.length, 10); i++) {
    const line = lines[i];
    
    // Skip lines that are clearly not merchant names
    if (
      /^\d+[\/\-.]/.test(line) ||  // Dates
      /^\d{1,2}:\d{2}/.test(line) ||  // Times
      /^RM\s*\d/.test(line) ||  // Amounts
      /^NO\.|^TEL|^FAX|^GST|^SST|^REG/i.test(line) ||  // Labels
      /^\d+$/.test(line) ||  // Pure numbers
      /^CASH\s*BILL|^TAX\s*INVOICE/i.test(line) ||  // Document types
      line.length < 3 ||
      line.length > 60
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
    
    // If no pattern matched, use first reasonable line as merchant
    if (i < 3 && line.length > 5 && /[A-Za-z]/.test(line)) {
      // Check it's not a common header word
      if (!/^(CASH|BILL|RECEIPT|RESIT|TAX|INVOICE)/i.test(line)) {
        result.merchant = line.replace(/\s+/g, ' ').trim();
        break;
      }
    }
  }

  // ===== EXTRACT ITEMS =====
  // Look for patterns: ITEM_NAME followed by PRICE
  const itemsFound: Array<{ name: string; price: number }> = [];
  
  for (let i = 0; i < lines.length; i++) {
    const line = lines[i];
    
    // Pattern 1: Item and price on same line (ITEM NAME    XX.XX)
    const sameLineMatch = line.match(/^(.+?)\s{2,}(\d+[.,]\d{2,4})$/);
    if (sameLineMatch) {
      const name = sameLineMatch[1].trim();
      const price = parseFloat(parseFloat(sameLineMatch[2].replace(",", ".")).toFixed(2));
      
      if (isValidItemName(name) && price > 0 && price < 10000) {
        itemsFound.push({ name, price });
        continue;
      }
    }

    // Pattern 2: Item name on current line, price on next line
    if (isValidItemName(line) && i + 1 < lines.length) {
      const nextLine = lines[i + 1];
      const priceMatch = nextLine.match(/^(\d+[.,]\d{2,4})$/);
      if (priceMatch) {
        const price = parseFloat(parseFloat(priceMatch[1].replace(",", ".")).toFixed(2));
        if (price > 0 && price < 10000) {
          itemsFound.push({ name: line, price });
        }
      }
    }

    // Pattern 3: Product code + name + price (e.g., "123456 PRODUCT NAME  25.00")
    const codeItemMatch = line.match(/^\d+\s+(.+?)\s{2,}(\d+[.,]\d{2,4})$/);
    if (codeItemMatch) {
      const name = codeItemMatch[1].trim();
      const price = parseFloat(parseFloat(codeItemMatch[2].replace(",", ".")).toFixed(2));
      
      if (isValidItemName(name) && price > 0 && price < 10000) {
        itemsFound.push({ name, price });
      }
    }
  }

  result.items = itemsFound;

  // ===== AUTO-DETECT CATEGORY =====
  result.category = detectCategory(fullTextLower, result.merchant || "");

  return result;
}

function isValidItemName(name: string): boolean {
  if (!name || name.length < 2 || name.length > 60) return false;
  
  // Skip if it's a total/subtotal line
  if (/TOTAL|JUMLAH|SUBTOTAL|CASH|TUNAI|CHANGE|BAKI|ROUNDING|SST|GST|TAX|DISCOUNT|DISKAUN/i.test(name)) {
    return false;
  }
  
  // Skip if it's mostly numbers
  if (/^\d+$/.test(name.replace(/\s/g, ''))) return false;
  
  // Skip common headers
  if (/^(QTY|ITEM|UNIT|PRICE|DESCRIPTION|CODE|TOTAL)/i.test(name)) return false;
  
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
