-- Fix Storage Policies for product-images bucket
-- This fixes policies that might be too restrictive
-- 
-- Run this in Supabase SQL Editor

BEGIN;

-- Drop existing restrictive policies (if they have the suffix pattern)
DROP POLICY IF EXISTS "Allow authenticated uploads 16wiy3a_0" ON storage.objects;
DROP POLICY IF EXISTS "Allow authenticated reads 16wiy3a_0" ON storage.objects;
DROP POLICY IF EXISTS "Allow authenticated deletes 16wiy3a_0" ON storage.objects;
DROP POLICY IF EXISTS "Allow public reads 16wiy3a_0" ON storage.objects;

-- Also drop any other variations
DROP POLICY IF EXISTS "Allow authenticated uploads" ON storage.objects;
DROP POLICY IF EXISTS "Allow authenticated reads" ON storage.objects;
DROP POLICY IF EXISTS "Allow authenticated deletes" ON storage.objects;
DROP POLICY IF EXISTS "Allow public reads" ON storage.objects;

-- Policy 1: Allow authenticated users to INSERT (upload) files
-- This allows upload to ANY path in product-images bucket
CREATE POLICY "Allow authenticated uploads"
ON storage.objects
FOR INSERT
TO authenticated
WITH CHECK (
  bucket_id = 'product-images'
);

-- Policy 2: Allow authenticated users to SELECT (read) files
-- This allows read from ANY path in product-images bucket
CREATE POLICY "Allow authenticated reads"
ON storage.objects
FOR SELECT
TO authenticated
USING (
  bucket_id = 'product-images'
);

-- Policy 3: Allow authenticated users to DELETE files
-- This allows delete from ANY path in product-images bucket
CREATE POLICY "Allow authenticated deletes"
ON storage.objects
FOR DELETE
TO authenticated
USING (
  bucket_id = 'product-images'
);

-- Policy 4: Allow public SELECT (read) for public bucket
-- This is CRITICAL - allows anyone to view product images
-- This allows read from ANY path in product-images bucket
CREATE POLICY "Allow public reads"
ON storage.objects
FOR SELECT
TO public
USING (
  bucket_id = 'product-images'
);

COMMIT;

-- Verify policies were created correctly
-- Run this query to check:
-- SELECT 
--   policyname,
--   cmd,
--   roles,
--   qual,
--   with_check
-- FROM pg_policies 
-- WHERE schemaname = 'storage' 
--   AND tablename = 'objects'
--   AND policyname LIKE '%product-images%' OR policyname LIKE '%product%';
