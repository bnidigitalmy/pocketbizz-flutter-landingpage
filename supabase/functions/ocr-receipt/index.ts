// Supabase Edge Function: OCR Receipt using Google Cloud Vision
// Accepts base64 image and returns extracted text + parsed receipt data

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

    // Parse the receipt text
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
  };

  const lines = text.split("\n").map(l => l.trim()).filter(l => l);

  // Extract total amount (look for patterns like RM XX.XX, TOTAL, JUMLAH)
  const amountPatterns = [
    /(?:TOTAL|JUMLAH|GRAND\s*TOTAL|AMOUNT|BAYAR|TUNAI|CASH)[:\s]*RM?\s*(\d+[.,]\d{2})/gi,
    /RM\s*(\d+[.,]\d{2})/gi,
    /(\d+[.,]\d{2})\s*(?:RM|MYR)/gi,
  ];

  const amounts: number[] = [];
  for (const pattern of amountPatterns) {
    let match;
    while ((match = pattern.exec(text)) !== null) {
      const numStr = match[1] || match[0].replace(/[^\d.,]/g, "");
      const num = parseFloat(numStr.replace(",", "."));
      if (!isNaN(num) && num > 0) {
        amounts.push(num);
      }
    }
  }
  
  // Get the largest amount (usually the total)
  if (amounts.length > 0) {
    result.amount = Math.max(...amounts);
  }

  // Extract date (DD/MM/YYYY, DD-MM-YYYY, DD.MM.YYYY, etc.)
  const datePatterns = [
    /(\d{1,2})[\/\-.](\d{1,2})[\/\-.](\d{2,4})/,
    /(\d{4})[\/\-.](\d{1,2})[\/\-.](\d{1,2})/,
  ];

  for (const pattern of datePatterns) {
    const match = text.match(pattern);
    if (match) {
      result.date = match[0];
      break;
    }
  }

  // Extract merchant name (usually first few non-numeric lines)
  for (const line of lines.slice(0, 5)) {
    // Skip lines that look like dates, times, addresses, or numbers
    if (
      line.length > 3 &&
      !/^\d+[\/\-.]/.test(line) &&
      !/^\d{1,2}:\d{2}/.test(line) &&
      !/^RM\s*\d/.test(line) &&
      !/^NO\.|^TEL|^FAX|^GST/i.test(line) &&
      !/^\d+[\s,]/.test(line)
    ) {
      result.merchant = line.toUpperCase();
      break;
    }
  }

  // Extract line items (patterns like "ITEM NAME  XX.XX" or "ITEM NAME RM XX.XX")
  const itemPatterns = [
    /^(.+?)\s{2,}RM?\s*(\d+[.,]\d{2})$/,
    /^(.+?)\s+(\d+[.,]\d{2})\s*$/,
  ];

  for (const line of lines) {
    for (const pattern of itemPatterns) {
      const match = line.match(pattern);
      if (match && match[1].length > 2 && match[1].length < 50) {
        const name = match[1].trim();
        const price = parseFloat(match[2].replace(",", "."));
        
        // Skip if name looks like total/subtotal
        if (!/TOTAL|JUMLAH|SUBTOTAL|CASH|TUNAI|CHANGE|BAKI/i.test(name)) {
          result.items.push({ name, price });
        }
        break;
      }
    }
  }

  return result;
}

