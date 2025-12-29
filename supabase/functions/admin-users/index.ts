import { serve } from "https://deno.land/std@0.168.0/http/server.ts";
import { createClient } from "https://esm.sh/@supabase/supabase-js@2";

const corsHeaders = {
  "Access-Control-Allow-Origin": "*",
  "Access-Control-Allow-Headers":
    "authorization, x-client-info, apikey, content-type",
};

serve(async (req) => {
  // Handle CORS preflight
  if (req.method === "OPTIONS") {
    return new Response("ok", { headers: corsHeaders });
  }

  try {
    // Create Supabase client with service role key
    const supabaseUrl = Deno.env.get("SUPABASE_URL")!;
    const supabaseServiceKey = Deno.env.get("SUPABASE_SERVICE_ROLE_KEY")!;
    const supabase = createClient(supabaseUrl, supabaseServiceKey);

    const { action, userId, email, suspended, page, perPage } = await req.json();

    switch (action) {
      case "list": {
        // Get users from auth.users (paginated)
        const safePage = typeof page === "number" && page > 0 ? page : 1;
        const safePerPage =
          typeof perPage === "number" && perPage > 0 && perPage <= 1000 ? perPage : 200;

        const { data: users, error } = await supabase.auth.admin.listUsers({
          page: safePage,
          perPage: safePerPage,
        });
        if (error) throw error;

        const authUsers = users.users ?? [];
        const userIds = authUsers.map((u) => u.id).filter(Boolean);

        // Batch fetch latest subscription per user (+ plan name) using service role key (bypasses RLS)
        const latestSubByUserId = new Map<string, any>();
        if (userIds.length > 0) {
          const { data: subs, error: subsErr } = await supabase
            .from("subscriptions")
            .select(
              "user_id,status,expires_at,created_at,subscription_plans:plan_id(name,duration_months)"
            )
            .in("user_id", userIds)
            .order("created_at", { ascending: false })
            // Fetch enough rows to cover "latest per user" even if some users have multiple rows
            .limit(Math.min(userIds.length * 5, 5000));
          if (subsErr) throw subsErr;

          for (const row of subs ?? []) {
            const uid = row.user_id as string | undefined;
            if (!uid) continue;
            if (!latestSubByUserId.has(uid)) {
              latestSubByUserId.set(uid, row);
            }
          }
        }

        // Batch fetch early adopter status (active only)
        const earlySet = new Set<string>();
        if (userIds.length > 0) {
          const { data: earlyRows, error: earlyErr } = await supabase
            .from("early_adopters")
            .select("user_id")
            .eq("is_active", true)
            .in("user_id", userIds);
          if (earlyErr) throw earlyErr;
          for (const r of earlyRows ?? []) {
            if (r.user_id) earlySet.add(r.user_id as string);
          }
        }

        // Return enriched users to avoid N+1 queries on client
        const enriched = authUsers.map((u) => {
          const latest = latestSubByUserId.get(u.id) ?? null;
          const isEarlyAdopter = earlySet.has(u.id);
          return {
            ...u,
            latest_subscription: latest,
            is_early_adopter: isEarlyAdopter,
          };
        });

        return new Response(
          JSON.stringify({
            users: enriched,
            page: safePage,
            perPage: safePerPage,
            count: enriched.length,
          }),
          {
            headers: { ...corsHeaders, "Content-Type": "application/json" },
            status: 200,
          }
        );
      }

      case "reset_password": {
        if (!userId && !email) {
          throw new Error("userId or email is required");
        }

        // Generate temporary password
        const tempPassword = `TEMP-${Math.random().toString(36).slice(-8).toUpperCase()}`;

        // Update user password
        const targetUserId = userId || (await supabase.auth.admin.listUsers()).data.users.find(
          (u) => u.email === email
        )?.id;

        if (!targetUserId) {
          throw new Error("User not found");
        }

        const { error } = await supabase.auth.admin.updateUserById(
          targetUserId,
          { password: tempPassword }
        );

        if (error) throw error;

        return new Response(
          JSON.stringify({ 
            success: true, 
            tempPassword,
            message: "Password reset successfully" 
          }),
          {
            headers: { ...corsHeaders, "Content-Type": "application/json" },
            status: 200,
          }
        );
      }

      case "suspend": {
        if (!userId && !email) {
          throw new Error("userId or email is required");
        }

        const targetUserId = userId || (await supabase.auth.admin.listUsers()).data.users.find(
          (u) => u.email === email
        )?.id;

        if (!targetUserId) {
          throw new Error("User not found");
        }

        // Ban user (suspend)
        const { error } = await supabase.auth.admin.updateUserById(
          targetUserId,
          { ban_duration: "876000h" } // ~100 years (effectively permanent)
        );

        if (error) throw error;

        return new Response(
          JSON.stringify({ 
            success: true, 
            message: "User suspended successfully" 
          }),
          {
            headers: { ...corsHeaders, "Content-Type": "application/json" },
            status: 200,
          }
        );
      }

      case "activate": {
        if (!userId && !email) {
          throw new Error("userId or email is required");
        }

        const targetUserId = userId || (await supabase.auth.admin.listUsers()).data.users.find(
          (u) => u.email === email
        )?.id;

        if (!targetUserId) {
          throw new Error("User not found");
        }

        // Remove ban (activate)
        const { error } = await supabase.auth.admin.updateUserById(
          targetUserId,
          { ban_duration: "0" }
        );

        if (error) throw error;

        return new Response(
          JSON.stringify({ 
            success: true, 
            message: "User activated successfully" 
          }),
          {
            headers: { ...corsHeaders, "Content-Type": "application/json" },
            status: 200,
          }
        );
      }

      case "delete": {
        if (!userId && !email) {
          throw new Error("userId or email is required");
        }

        const targetUserId = userId || (await supabase.auth.admin.listUsers()).data.users.find(
          (u) => u.email === email
        )?.id;

        if (!targetUserId) {
          throw new Error("User not found");
        }

        // Delete user
        const { error } = await supabase.auth.admin.deleteUser(targetUserId);

        if (error) throw error;

        return new Response(
          JSON.stringify({ 
            success: true, 
            message: "User deleted successfully" 
          }),
          {
            headers: { ...corsHeaders, "Content-Type": "application/json" },
            status: 200,
          }
        );
      }

      default:
        throw new Error(`Unknown action: ${action}`);
    }
  } catch (error) {
    return new Response(
      JSON.stringify({ 
        error: error.message || "Internal server error" 
      }),
      {
        headers: { ...corsHeaders, "Content-Type": "application/json" },
        status: 400,
      }
    );
  }
});

