# Apply record_production_batch Function Migration

## Problem
Error 400/404: `record_production_batch` RPC function not found or has issues.

**Error yang muncul:**
```
POST /rest/v1/rpc/record_production_batch 400 (Bad Request)
```

## Solution
Run the migration to create the function in Supabase database.

## Steps

1. **Open Supabase Dashboard**
   - Go to: https://supabase.com/dashboard
   - Select your project

2. **Go to SQL Editor**
   - Click "SQL Editor" in left sidebar
   - Click "New query"

3. **Copy & Paste Migration**
   - Open `db/migrations/create_record_production_batch_function.sql`
   - Copy ALL content
   - Paste into SQL Editor

4. **Run Migration**
   - Click "Run" button (or press Ctrl+Enter)
   - Wait for success message

5. **Verify**
   - Check for success message: "Success. No rows returned"
   - Function should now exist

## What This Does
- Creates `record_production_batch()` function
- Matches signature expected by `ProductionBatchInput.toJson()`
- Auto-deducts stock when recording production
- Uses new recipes structure (recipe_items → recipes → products)

## After Migration
- Production planning should work
- No more 404 errors
- Stock will auto-deduct on production

