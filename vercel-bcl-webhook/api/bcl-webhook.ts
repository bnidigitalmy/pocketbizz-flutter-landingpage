import { createClient } from "@supabase/supabase-js";
import type { VercelRequest, VercelResponse } from "@vercel/node";
import { createHmac } from "crypto";

const SUPABASE_URL = process.env.SUPABASE_URL ?? "";
const SUPABASE_SERVICE_ROLE_KEY = process.env.SUPABASE_SERVICE_ROLE_KEY ?? "";
const BCL_API_SECRET_KEY = process.env.BCL_API_SECRET_KEY!;

const supabase = createClient(SUPABASE_URL, SUPABASE_SERVICE_ROLE_KEY);
const SUCCESS_STATUSES = new Set(["success", "1", "completed", "paid"]);

type StatusLike = string | number | undefined;

interface BclPayload {
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
  [key: string]: unknown;
}

const buildSignatureString = (p: BclPayload): string => {
  const data: Record<string, string> = {
    amount: p.amount?.toString() ?? "",
    currency: p.currency ?? "",
    exchange_reference_number: p.exchange_reference_number ?? "",
    exchange_transaction_id: p.exchange_transaction_id ?? "",
    order_number: p.order_number ?? "",
    payer_bank_name: p.payer_bank_name ?? "",
    status: p.status?.toString() ?? "",
    status_description: p.status_description ?? "",
    transaction_id: p.transaction_id ?? "",
  };

  return Object.keys(data)
    .sort()
    .map((k) => data[k])
    .join("|");
};

const isValidSignature = (p: BclPayload): boolean => {
  const provided = p.checksum;
  if (!provided) return false;

  const payloadString = buildSignatureString(p);
  const computed = createHmac("sha256", BCL_API_SECRET_KEY)
    .update(payloadString)
    .digest("hex");

  return computed.toLowerCase() === provided.toString().toLowerCase();
};

export default async function handler(req: VercelRequest, res: VercelResponse) {
  if (req.method !== "POST") {
    return res.status(405).json({ error: "Method not allowed" });
  }

  // Accept JSON or x-www-form-urlencoded
  const payload: BclPayload =
    req.headers["content-type"]?.includes("application/x-www-form-urlencoded")
      ? (req.body as any)
      : (req.body as any);

  if (!isValidSignature(payload)) {
    return res.status(401).json({ error: "Invalid signature" });
  }

  const orderNumber = payload.order_number?.toString() ?? "";
  if (!orderNumber) return res.json({ message: "Missing order_number" });

  const { data: payment, error: payErr } = await supabase
    .from("subscription_payments")
    .select("id, status, subscription_id, user_id, payment_reference")
    .eq("payment_reference", orderNumber)
    .maybeSingle();

  if (payErr) return res.status(500).json({ error: "DB error payment" });
  if (!payment) return res.json({ message: "No payment found" });
  if (payment.status === "completed") return res.json({ message: "Already processed" });

  const status = payload.status?.toString().toLowerCase() ?? "";
  const isSuccess = SUCCESS_STATUSES.has(status);
  const nowIso = new Date().toISOString();
  const gatewayTransactionId =
    payload.transaction_id ??
    payload.exchange_transaction_id ??
    payload.exchange_reference_number ??
    undefined;

  if (isSuccess) {
    const { data: subscription, error: subErr } = await supabase
      .from("subscriptions")
      .select("id, user_id, plan_id")
      .eq("id", payment.subscription_id)
      .maybeSingle();

    if (subErr) return res.status(500).json({ error: "DB error subscription" });
    if (!subscription) return res.json({ message: "No subscription found" });

    const { data: plan, error: planErr } = await supabase
      .from("subscription_plans")
      .select("duration_months")
      .eq("id", subscription.plan_id)
      .maybeSingle();

    if (planErr) return res.status(500).json({ error: "DB error plan" });

    const durationMonths = plan?.duration_months ?? 1;
    const expiresAt = new Date();
    expiresAt.setDate(expiresAt.getDate() + durationMonths * 30);

    // Expire other active/trial subs
    await supabase
      .from("subscriptions")
      .update({ status: "expired", updated_at: nowIso })
      .eq("user_id", subscription.user_id)
      .in("status", ["trial", "active"])
      .neq("id", subscription.id);

    await supabase
      .from("subscriptions")
      .update({
        status: "active",
        started_at: nowIso,
        expires_at: expiresAt.toISOString(),
        payment_status: "completed",
        payment_completed_at: nowIso,
        updated_at: nowIso,
        payment_reference: orderNumber,
      })
      .eq("id", subscription.id);

    await supabase
      .from("subscription_payments")
      .update({
        status: "completed",
        paid_at: nowIso,
        gateway_transaction_id: gatewayTransactionId,
        failure_reason: null,
        updated_at: nowIso,
      })
      .eq("id", payment.id);

    return res.json({ message: "OK" });
  }

  // Failed/unknown
  await supabase
    .from("subscription_payments")
    .update({
      status: "failed",
      failure_reason: payload.status_description ?? "Payment failed",
      updated_at: nowIso,
    })
    .eq("id", payment.id);

  await supabase
    .from("subscriptions")
    .update({
      payment_status: "failed",
      status: "pending_payment",
      updated_at: nowIso,
    })
    .eq("id", payment.subscription_id);

  return res.json({ message: "Marked failed" });
}

