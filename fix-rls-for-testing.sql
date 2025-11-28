-- TEMPORARY FIX FOR TESTING
-- Run this in Supabase SQL Editor to allow anonymous testing

-- Drop existing strict RLS policies for products
DROP POLICY IF EXISTS products_select_own ON products;
DROP POLICY IF EXISTS products_insert_own ON products;
DROP POLICY IF EXISTS products_update_own ON products;
DROP POLICY IF EXISTS products_delete_own ON products;

-- Create RELAXED policies for testing (TEMPORARY!)
CREATE POLICY products_select_anon ON products
FOR SELECT USING (true);

CREATE POLICY products_insert_anon ON products
FOR INSERT WITH CHECK (true);

CREATE POLICY products_update_anon ON products
FOR UPDATE USING (true);

CREATE POLICY products_delete_anon ON products
FOR DELETE USING (true);

-- NOTE: This allows ANYONE to access products (for testing only!)
-- After testing, restore strict RLS policies with business_owner_id check

