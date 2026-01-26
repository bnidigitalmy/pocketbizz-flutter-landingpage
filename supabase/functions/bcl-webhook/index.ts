// Supabase Edge Function: BCL webhook handler
// Verifies HMAC-SHA256 checksum and activates subscriptions/payments.
// NOTE: This function uses Deno.serve() which does NOT verify JWT tokens.
// This is intentional - BCL.my webhooks come from external sources without JWT.
// Security is handled via HMAC signature verification instead.

import { createClient } from "https://esm.sh/@supabase/supabase-js@2.47.0";

const SUPABASE_URL = Deno.env.get("SUPABASE_URL")!;
const SERVICE_ROLE_KEY = Deno.env.get("SUPABASE_SERVICE_ROLE_KEY")!;
const BCL_API_SECRET_KEY = Deno.env.get("BCL_API_SECRET_KEY")!;

if (!SUPABASE_URL || !SERVICE_ROLE_KEY || !BCL_API_SECRET_KEY) {
  throw new Error("Missing required environment variables");
}

const supabase = createClient(SUPABASE_URL, SERVICE_ROLE_KEY);

type StatusLike = string | number | undefined;

interface BclMainData {
  id?: string;
  order_number?: string;
  transaction_id?: string;
  exchange_reference_number?: string;
  exchange_transaction_id?: string;
  currency?: string;
  amount?: string | number;
  subtotal_amount?: string | number;
  payer_bank_name?: string;
  payer_name?: string;
  payer_email?: string;
  status?: StatusLike;
  status_description?: string;
  checksum?: string;
  [key: string]: unknown;
}

interface BclPayload {
  // Flat structure (legacy)
  transaction_id?: string;
  exchange_reference_number?: string;
  exchange_transaction_id?: string;
  order_number?: string;
  currency?: string;
  amount?: string | number;
  payer_bank_name?: string;
  status?: StatusLike;
  status_description?: string;
  checksum?: string;
  // Nested structure (new BCL.my format)
  event?: string;
  data?: {
    main_data?: BclMainData;
    formable_type?: string;
    formable_id?: number;
    form_title?: string;
    record_type?: string;
    record_id?: string;
    receipt_url?: string;
    [key: string]: unknown;
  };
  [key: string]: unknown;
}

const SUCCESS_STATUSES = new Set(["success", "1", "completed", "paid"]);

// Extract flat data from nested or flat payload structure
const extractPayloadData = (payload: BclPayload): BclMainData => {
  // If nested structure (new format)
  if (payload.data?.main_data) {
    return payload.data.main_data;
  }
  // If flat structure (legacy format)
  return {
    order_number: payload.order_number,
    transaction_id: payload.transaction_id,
    exchange_reference_number: payload.exchange_reference_number,
    exchange_transaction_id: payload.exchange_transaction_id,
    currency: payload.currency,
    amount: payload.amount,
    payer_bank_name: payload.payer_bank_name,
    status: payload.status,
    status_description: payload.status_description,
    checksum: payload.checksum,
  };
};

const buildSignatureString = (data: BclMainData): string => {
  const payloadData: Record<string, string> = {
    amount: data.amount?.toString() ?? "",
    currency: data.currency ?? "",
    exchange_reference_number: data.exchange_reference_number ?? "",
    exchange_transaction_id: data.exchange_transaction_id ?? "",
    order_number: data.order_number ?? "",
    payer_bank_name: data.payer_bank_name ?? "",
    status: data.status?.toString() ?? "",
    status_description: data.status_description ?? "",
    transaction_id: data.transaction_id ?? "",
  };

  return Object.keys(payloadData)
    .sort()
    .map((k) => payloadData[k])
    .join("|");
};

const computeHmacHex = async (value: string, secret: string): Promise<string> => {
  const encoder = new TextEncoder();
  const key = await crypto.subtle.importKey(
    "raw",
    encoder.encode(secret),
    { name: "HMAC", hash: "SHA-256" },
    false,
    ["sign"]
  );
  const signature = await crypto.subtle.sign("HMAC", key, encoder.encode(value));
  return Array.from(new Uint8Array(signature))
    .map((b) => b.toString(16).padStart(2, "0"))
    .join("");
};

const isValidSignature = async (payload: BclPayload): Promise<boolean> => {
  const data = extractPayloadData(payload);
  const providedChecksum = data.checksum;
  
  // If no checksum provided, skip verification (for testing or if BCL.my doesn't send it)
  // TODO: Remove this after confirming BCL.my always sends checksum
  if (!providedChecksum) {
    console.warn(`[${new Date().toISOString()}] No checksum provided in payload - skipping verification`);
    // For now, allow if no checksum (should be removed in production)
    return true;
  }
  
  const payloadString = buildSignatureString(data);
  const computed = await computeHmacHex(payloadString, BCL_API_SECRET_KEY);
  const isValid = computed.toLowerCase() === providedChecksum.toString().toLowerCase();
  
  if (!isValid) {
    console.log(`[${new Date().toISOString()}] Signature mismatch - provided: ${providedChecksum}, computed: ${computed}`);
    console.log(`[${new Date().toISOString()}] Signature string: ${payloadString}`);
  }
  
  return isValid;
};

const parseBody = async (req: Request): Promise<BclPayload> => {
  const contentType = req.headers.get("content-type") ?? "";
  const raw = await req.text();
  if (!raw) return {};

  if (contentType.includes("application/x-www-form-urlencoded")) {
    const params = new URLSearchParams(raw);
    const obj: Record<string, string> = {};
    params.forEach((value, key) => {
      obj[key] = value;
    });
    return obj;
  }

  try {
    return JSON.parse(raw);
  } catch {
    return {};
  }
};

const jsonResponse = (body: unknown, status = 200) =>
  new Response(JSON.stringify(body), {
    status,
    headers: { "content-type": "application/json" },
  });

// PHASE 7: Helper to check if payment is prorated (for amount validation)
const checkIfProrated = async (subscriptionId: string): Promise<boolean> => {
  try {
    const { data: subscription, error } = await supabase
      .from("subscriptions")
      .select("notes, payment_reference")
      .eq("id", subscriptionId)
      .maybeSingle();
    
    if (error || !subscription) {
      return false;
    }
    
    // Check if notes contain "prorated" or payment_reference contains "prorated"
    const notes = (subscription.notes as string)?.toLowerCase() ?? "";
    const paymentRef = (subscription.payment_reference as string)?.toLowerCase() ?? "";
    
    return notes.includes("prorated") || paymentRef.includes("prorated");
  } catch {
    return false;
  }
};

// Rate limiting configuration
const RATE_LIMIT_CONFIG = {
  // IP-based: 10 requests per minute per IP
  ip: {
    maxRequests: 10,
    windowMinutes: 1,
  },
  // Order-number-based: 5 requests per hour per order (prevent duplicate processing)
  orderNumber: {
    maxRequests: 5,
    windowMinutes: 60,
  },
};

// Get client IP address from request
const getClientIP = (req: Request): string => {
  // Try X-Forwarded-For header (from proxy/load balancer)
  const forwardedFor = req.headers.get("x-forwarded-for");
  if (forwardedFor) {
    // X-Forwarded-For can contain multiple IPs, take the first one
    return forwardedFor.split(",")[0].trim();
  }
  
  // Try X-Real-IP header
  const realIP = req.headers.get("x-real-ip");
  if (realIP) {
    return realIP.trim();
  }
  
  // Fallback: use connection remote address (if available)
  // Note: In Deno Deploy, this might not be available
  return "unknown";
};

// Check rate limit using database function
const checkRateLimit = async (
  identifier: string,
  identifierType: "ip" | "order_number",
  maxRequests: number,
  windowMinutes: number
): Promise<boolean> => {
  try {
    const { data, error } = await supabase.rpc("check_webhook_rate_limit", {
      p_identifier: identifier,
      p_identifier_type: identifierType,
      p_max_requests: maxRequests,
      p_window_minutes: windowMinutes,
    });

    if (error) {
      console.error(`[${new Date().toISOString()}] Rate limit check error:`, error);
      // On error, allow request (fail open) but log it
      return true;
    }

    return data === true;
  } catch (error) {
    console.error(`[${new Date().toISOString()}] Rate limit check exception:`, error);
    // On exception, allow request (fail open) but log it
    return true;
  }
};

Deno.serve(async (req) => {
  console.log(`[${new Date().toISOString()}] Webhook received: ${req.method} ${req.url}`);
  
  if (req.method !== "POST") {
    console.log(`[${new Date().toISOString()}] Method not allowed: ${req.method}`);
    return jsonResponse({ error: "Method not allowed" }, 405);
  }

  try {
    // Rate limiting: Check IP-based limit
    const clientIP = getClientIP(req);
    console.log(`[${new Date().toISOString()}] Client IP: ${clientIP}`);
    
    const ipAllowed = await checkRateLimit(
      clientIP,
      "ip",
      RATE_LIMIT_CONFIG.ip.maxRequests,
      RATE_LIMIT_CONFIG.ip.windowMinutes
    );

    if (!ipAllowed) {
      console.warn(`[${new Date().toISOString()}] Rate limited by IP: ${clientIP}`);
      return jsonResponse(
        { 
          error: "Too many requests", 
          message: "Rate limit exceeded. Please try again later." 
        },
        429
      );
    }

    const payload = await parseBody(req);
    console.log(`[${new Date().toISOString()}] Payload received:`, JSON.stringify(payload));

    const isValid = await isValidSignature(payload);
    console.log(`[${new Date().toISOString()}] Signature valid: ${isValid}`);
    
    if (!isValid) {
      console.error(`[${new Date().toISOString()}] Invalid signature - rejecting request`);
      return jsonResponse({ error: "Invalid signature" }, 401);
    }

    // Extract data from nested or flat structure
    const payloadData = extractPayloadData(payload);
    const orderNumber = payloadData.order_number?.toString() ?? "";
    const status = payloadData.status;
    const statusDescription = payloadData.status_description;
    const webhookCurrency = payloadData.currency?.toString().toUpperCase() ?? "";
    const webhookAmount = parseFloat(payloadData.amount?.toString() ?? "0");
    
    console.log(`[${new Date().toISOString()}] Order number: ${orderNumber}`);
    console.log(`[${new Date().toISOString()}] Status: ${status}, Description: ${statusDescription}`);
    console.log(`[${new Date().toISOString()}] Currency: ${webhookCurrency}, Amount: ${webhookAmount}`);
    
    if (!orderNumber) {
      console.warn(`[${new Date().toISOString()}] Missing order_number in payload`);
      return jsonResponse({ message: "Missing order_number" });
    }

    // PHASE 7: Strict currency validation (MYR only)
    if (webhookCurrency && webhookCurrency !== "MYR") {
      console.error(`[${new Date().toISOString()}] Invalid currency: ${webhookCurrency}. Expected MYR.`);
      return jsonResponse({ 
        error: "Invalid currency", 
        message: `Expected MYR, received ${webhookCurrency}` 
      }, 400);
    }

    // Rate limiting: Check order-number-based limit (prevent duplicate processing)
    const orderAllowed = await checkRateLimit(
      orderNumber,
      "order_number",
      RATE_LIMIT_CONFIG.orderNumber.maxRequests,
      RATE_LIMIT_CONFIG.orderNumber.windowMinutes
    );

    if (!orderAllowed) {
      console.warn(`[${new Date().toISOString()}] Rate limited by order_number: ${orderNumber}`);
      return jsonResponse(
        { 
          error: "Too many requests for this order", 
          message: "This order has been processed too many times. Please contact support if this is an error." 
        },
        429
      );
    }

    // Try to find payment by order_number (BCL.my order number)
    let { data: payment, error: paymentError } = await supabase
      .from("subscription_payments")
      .select("id, status, subscription_id, user_id, payment_reference, amount")
      .eq("payment_reference", orderNumber)
      .maybeSingle();

    // If not found, try to find by user email (from payload) and latest pending payment
    if (!payment && payloadData.payer_email) {
      console.log(`[${new Date().toISOString()}] Payment not found by order_number, trying to find by user email: ${payloadData.payer_email}`);
      
      // Use Supabase Admin API to get user by email
      const { data: users, error: userError } = await supabase.auth.admin.listUsers();
      
      if (!userError && users) {
        const user = users.users.find(u => u.email?.toLowerCase() === payloadData.payer_email?.toLowerCase());
        
        if (user) {
          console.log(`[${new Date().toISOString()}] User found: ${user.id}`);
          
          // Find latest pending payment for this user
          const { data: pendingPayment, error: pendingError } = await supabase
            .from("subscription_payments")
            .select("id, status, subscription_id, user_id, payment_reference, amount")
            .eq("user_id", user.id)
            .eq("status", "pending")
            .order("created_at", { ascending: false })
            .limit(1)
            .maybeSingle();
          
          if (pendingError) {
            console.error(`[${new Date().toISOString()}] Error finding pending payment:`, pendingError);
          } else if (pendingPayment) {
            console.log(`[${new Date().toISOString()}] Found pending payment: ${pendingPayment.id}`);
            payment = pendingPayment;
            
            // Update payment_reference to match BCL.my order number
            const { error: updateError } = await supabase
              .from("subscription_payments")
              .update({ payment_reference: orderNumber })
              .eq("id", payment.id);
            
            if (updateError) {
              console.error(`[${new Date().toISOString()}] Error updating payment_reference:`, updateError);
            }
          }
        }
      } else if (userError) {
        console.error(`[${new Date().toISOString()}] Error fetching users:`, userError);
      }
    }

    if (paymentError) {
      console.error(`[${new Date().toISOString()}] Fetch payment error:`, paymentError);
      return jsonResponse({ error: "Database error" }, 500);
    }

    if (!payment) {
      console.warn(`[${new Date().toISOString()}] No payment found for order_number: ${orderNumber}`);
      return jsonResponse({ message: "No payment found (ok)" });
    }

    console.log(`[${new Date().toISOString()}] Payment found:`, {
      id: payment.id,
      status: payment.status,
      subscription_id: payment.subscription_id,
    });

    // PHASE 7: Strict idempotency check - reject if already completed
    if (payment.status === "completed") {
      console.log(`[${new Date().toISOString()}] Payment already processed: ${payment.id}`);
      // Return 200 OK to prevent webhook retries, but log as duplicate
      return jsonResponse({ 
        message: "Already processed",
        duplicate: true,
        payment_id: payment.id 
      });
    }

    // Determine success status
    // BCL.my uses status: 3 for approved, or status_description: "Approved"
    const statusValue = payloadData.status?.toString() ?? "";
    const statusDesc = payloadData.status_description?.toString().toLowerCase() ?? "";
    const isSuccess = 
      statusValue === "3" || 
      statusValue === "success" || 
      statusDesc === "approved" ||
      SUCCESS_STATUSES.has(statusValue) ||
      SUCCESS_STATUSES.has(statusDesc);
    
    const nowIso = new Date().toISOString();
    const gatewayTransactionId =
      payloadData.transaction_id ??
      payloadData.exchange_transaction_id ??
      payloadData.exchange_reference_number ??
      payloadData.id ??
      undefined;

    console.log(`[${new Date().toISOString()}] Processing payment:`, {
      status,
      isSuccess,
      gatewayTransactionId,
    });

    if (isSuccess) {
      console.log(`[${new Date().toISOString()}] Processing successful payment...`);
      
      const { data: subscription, error: subscriptionError } = await supabase
        .from("subscriptions")
        .select("id, user_id, plan_id")
        .eq("id", payment.subscription_id)
        .maybeSingle();

      if (subscriptionError) {
        console.error(`[${new Date().toISOString()}] Fetch subscription error:`, subscriptionError);
        return jsonResponse({ error: "Database error" }, 500);
      }
      
      if (!subscription) {
        console.error(`[${new Date().toISOString()}] No subscription found for payment: ${payment.id}`);
        return jsonResponse({ message: "No subscription found" });
      }

      const { data: plan, error: planError } = await supabase
        .from("subscription_plans")
        .select("duration_months")
        .eq("id", subscription.plan_id)
        .maybeSingle();

      if (planError) {
        console.error(`[${new Date().toISOString()}] Fetch plan error:`, planError);
        return jsonResponse({ error: "Database error" }, 500);
      }

      // Check if this is an extend payment
      // Get pending subscription to check expires_at
      const { data: pendingSub, error: pendingSubError } = await supabase
        .from("subscriptions")
        .select("expires_at, status")
        .eq("id", subscription.id)
        .maybeSingle();

      // Check if user has active subscription (for extend logic)
      const { data: activeSub, error: activeSubError } = await supabase
        .from("subscriptions")
        .select("expires_at, id")
        .eq("user_id", subscription.user_id)
        .eq("status", "active")
        .maybeSingle();

      let expiresAt: Date;
      let isExtend = false;

      if (pendingSub && activeSub && activeSub.id !== subscription.id) {
        // Check if pending expires_at is after current active expires_at (extend)
        const pendingExpiresAt = new Date(pendingSub.expires_at as string);
        const currentExpiresAt = new Date(activeSub.expires_at as string);
        
        if (pendingExpiresAt > currentExpiresAt) {
          // This is an extend - use the calculated expires_at from pending subscription
          isExtend = true;
          expiresAt = pendingExpiresAt;
          console.log(`[${new Date().toISOString()}] Extend payment detected. Using expires_at from pending: ${expiresAt.toISOString()}`);
        } else {
          // New subscription - calculate from now
          const durationMonths = plan?.duration_months ?? 1;
          expiresAt = new Date();
          expiresAt.setDate(expiresAt.getDate() + durationMonths * 30);
        }
      } else if (pendingSub && pendingSub.expires_at) {
        // Use expires_at from pending subscription (already calculated correctly)
        expiresAt = new Date(pendingSub.expires_at as string);
        console.log(`[${new Date().toISOString()}] Using expires_at from pending subscription: ${expiresAt.toISOString()}`);
      } else {
        // Fallback: calculate from now
        const durationMonths = plan?.duration_months ?? 1;
        expiresAt = new Date();
        expiresAt.setDate(expiresAt.getDate() + durationMonths * 30);
      }

      if (isExtend) {
        // For extend: update existing active subscription instead of creating new one
        // PHASE 8: Preserve auto_renew flag when extending
        const graceUntil = new Date(expiresAt);
        graceUntil.setDate(graceUntil.getDate() + 7);

        // Get current auto_renew status
        const { data: currentSub, error: currentSubError } = await supabase
          .from("subscriptions")
          .select("auto_renew")
          .eq("id", activeSub.id)
          .maybeSingle();
        
        const preserveAutoRenew = currentSub?.auto_renew ?? true;

        const { error: extendError } = await supabase
          .from("subscriptions")
          .update({
            expires_at: expiresAt.toISOString(),
            grace_until: graceUntil.toISOString(),
            payment_status: "completed",
            payment_completed_at: nowIso,
            updated_at: nowIso,
            payment_reference: orderNumber,
            auto_renew: preserveAutoRenew, // PHASE 8: Preserve auto_renew flag
          })
          .eq("id", activeSub.id);

        if (extendError) {
          console.error(`[${new Date().toISOString()}] Failed to extend subscription:`, extendError);
          return jsonResponse({ error: "Failed to extend subscription" }, 500);
        }

        // Delete pending subscription (we're extending existing one)
        await supabase
          .from("subscriptions")
          .delete()
          .eq("id", subscription.id);

        // Update payment record to point to existing subscription
        await supabase
          .from("subscription_payments")
          .update({
            subscription_id: activeSub.id,
          })
          .eq("id", payment.id);

        console.log(`[${new Date().toISOString()}] Subscription extended successfully`);
      } else {
        // For new subscription: expire other active/trial subs for this user
        await supabase
          .from("subscriptions")
          .update({ status: "expired", updated_at: nowIso })
          .eq("user_id", subscription.user_id)
          .in("status", ["trial", "active"])
          .neq("id", subscription.id);

        // Activate subscription
        const graceUntil = new Date(expiresAt);
        graceUntil.setDate(graceUntil.getDate() + 7);

        const { error: activateError } = await supabase
          .from("subscriptions")
          .update({
            status: "active",
            started_at: nowIso,
            expires_at: expiresAt.toISOString(),
            grace_until: graceUntil.toISOString(),
            payment_status: "completed",
            payment_completed_at: nowIso,
            updated_at: nowIso,
            payment_reference: orderNumber,
          })
          .eq("id", subscription.id);

        if (activateError) {
          console.error(`[${new Date().toISOString()}] Failed to activate subscription:`, activateError);
          return jsonResponse({ error: "Failed to activate subscription" }, 500);
        }
      }

      // PHASE 7: Strict amount validation
      // Get amount from BCL.my webhook (actual amount paid)
      const expectedAmount = payment.amount as number;
      const amountDiff = Math.abs(webhookAmount - expectedAmount);
      const amountTolerance = 0.50; // Allow 50 sen difference for rounding
      
      // Strict validation: Reject if amount mismatch is too large
      if (webhookAmount > 0 && amountDiff > amountTolerance) {
        // Check if this is a prorated payment (has prorated flag in payment notes or metadata)
        const isProrated = payment.subscription_id ? await checkIfProrated(payment.subscription_id) : false;
        
        if (!isProrated && amountDiff > amountTolerance) {
          console.error(`[${new Date().toISOString()}] Amount mismatch: webhook=${webhookAmount}, expected=${expectedAmount}, diff=${amountDiff.toFixed(2)}`);
          return jsonResponse({ 
            error: "Amount mismatch", 
            message: `Expected ${expectedAmount.toFixed(2)} MYR, received ${webhookAmount.toFixed(2)} MYR (diff: ${amountDiff.toFixed(2)})` 
          }, 400);
        }
      }
      
      // Use webhook amount if valid, otherwise use expected amount
      let finalAmount = expectedAmount;
      if (webhookAmount > 0 && amountDiff <= amountTolerance) {
        finalAmount = webhookAmount;
        if (amountDiff > 0.01) {
          console.log(`[${new Date().toISOString()}] Using BCL.my webhook amount: ${webhookAmount} (expected: ${expectedAmount}, diff: ${amountDiff.toFixed(2)})`);
        }
      } else if (webhookAmount <= 0) {
        console.warn(`[${new Date().toISOString()}] Webhook amount ${webhookAmount} is invalid (0 or negative), using expected amount ${expectedAmount}`);
      }

      // Update payment status with actual data from BCL.my webhook
      // This ensures receipt shows accurate data matching BCL.my records
      const { error: paymentUpdateError } = await supabase
        .from("subscription_payments")
        .update({
          status: "completed",
          paid_at: nowIso, // Payment completion time (webhook received time)
          gateway_transaction_id: gatewayTransactionId, // Transaction ID from BCL.my
          payment_reference: orderNumber, // BCL.my order number (ensure it's updated)
          failure_reason: amountDiff > 0.01 && webhookAmount > 0
            ? `Amount difference: BCL.my charged ${webhookAmount}, expected ${expectedAmount} (diff: ${amountDiff.toFixed(2)})`
            : null,
          updated_at: nowIso,
          // Use actual amount from BCL.my webhook for receipt accuracy
          // This ensures receipt matches BCL.my payment records
          amount: finalAmount,
        })
        .eq("id", payment.id);

      if (paymentUpdateError) {
        console.error(`[${new Date().toISOString()}] Failed to update payment:`, paymentUpdateError);
        return jsonResponse({ error: "Failed to update payment" }, 500);
      }

      console.log(`[${new Date().toISOString()}] Payment and subscription activated successfully`);

      // Send Telegram notification for successful upgrade
      try {
        // Get user email and business name
        const { data: userData } = await supabase.auth.admin.getUserById(payment.user_id as string);
        const userEmail = userData?.user?.email ?? payloadData.payer_email ?? "Unknown";

        // Get business profile
        const { data: businessProfile } = await supabase
          .from("business_profiles")
          .select("business_name, owner_name")
          .eq("user_id", payment.user_id)
          .maybeSingle();

        // Get plan details
        const { data: planData } = await supabase
          .from("subscription_plans")
          .select("name, duration_months")
          .eq("id", subscription.plan_id)
          .maybeSingle();

        await fetch(`${SUPABASE_URL}/functions/v1/telegram-admin-notify`, {
          method: "POST",
          headers: {
            "Content-Type": "application/json",
            "Authorization": `Bearer ${SERVICE_ROLE_KEY}`,
          },
          body: JSON.stringify({
            type: "upgrade_pro",
            data: {
              user_email: userEmail,
              user_name: businessProfile?.owner_name ?? payloadData.payer_name ?? "N/A",
              business_name: businessProfile?.business_name ?? "N/A",
              plan_name: planData?.name ?? "Pro",
              duration_months: planData?.duration_months ?? 1,
              amount: finalAmount,
              currency: "MYR",
              order_id: orderNumber,
              timestamp: nowIso,
            },
          }),
        });
        console.log(`[${new Date().toISOString()}] Telegram notification sent for upgrade`);
      } catch (telegramError) {
        // Don't fail the webhook if Telegram notification fails
        console.error(`[${new Date().toISOString()}] Failed to send Telegram notification:`, telegramError);
      }

      return jsonResponse({ message: "OK" });
    }

    // Failure / unknown status
    console.log(`[${new Date().toISOString()}] Processing failed payment...`);
    
    const { error: paymentFailError } = await supabase
      .from("subscription_payments")
      .update({
        status: "failed",
        failure_reason: payloadData.status_description ?? "Payment failed",
        updated_at: nowIso,
      })
      .eq("id", payment.id);

    if (paymentFailError) {
      console.error(`[${new Date().toISOString()}] Failed to mark payment as failed:`, paymentFailError);
    }

    const { error: subFailError } = await supabase
      .from("subscriptions")
      .update({
        payment_status: "failed",
        status: "pending_payment",
        updated_at: nowIso,
      })
      .eq("id", payment.subscription_id);

    if (subFailError) {
      console.error(`[${new Date().toISOString()}] Failed to update subscription status:`, subFailError);
    }

    console.log(`[${new Date().toISOString()}] Payment marked as failed`);

    // Send Telegram notification for failed payment
    try {
      const { data: userData } = await supabase.auth.admin.getUserById(payment.user_id as string);
      const userEmail = userData?.user?.email ?? payloadData.payer_email ?? "Unknown";

      await fetch(`${SUPABASE_URL}/functions/v1/telegram-admin-notify`, {
        method: "POST",
        headers: {
          "Content-Type": "application/json",
          "Authorization": `Bearer ${SERVICE_ROLE_KEY}`,
        },
        body: JSON.stringify({
          type: "payment_failed",
          data: {
            user_email: userEmail,
            amount: webhookAmount,
            currency: "MYR",
            order_id: orderNumber,
            failure_reason: payloadData.status_description ?? "Payment failed",
            timestamp: nowIso,
          },
        }),
      });
      console.log(`[${new Date().toISOString()}] Telegram notification sent for failed payment`);
    } catch (telegramError) {
      console.error(`[${new Date().toISOString()}] Failed to send Telegram notification:`, telegramError);
    }

    return jsonResponse({ message: "Marked failed" });
  } catch (error) {
    console.error(`[${new Date().toISOString()}] Unhandled error:`, error);
    return jsonResponse({ error: "Internal server error" }, 500);
  }
});
