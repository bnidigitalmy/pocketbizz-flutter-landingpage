-- RLS Policies for landing-page Storage Bucket
-- 
-- This migration sets up Row Level Security (RLS) policies for the landing-page bucket
-- to allow public viewing of landing page images while restricting uploads to authenticated users (admins).
--
-- Storage path structure: {category}/{filename}
-- Example: screenshots/dashboard_baru.png
-- Example: logos/logo.png

BEGIN;

-- Note: RLS is already enabled on storage.objects by default in Supabase
-- We only need to create the policies

-- Drop existing policies if they exist (for idempotency)
DROP POLICY IF EXISTS "Authenticated users can upload landing page images" ON storage.objects;
DROP POLICY IF EXISTS "Public can view landing page images" ON storage.objects;
DROP POLICY IF EXISTS "Authenticated users can delete landing page images" ON storage.objects;
DROP POLICY IF EXISTS "Authenticated users can update landing page images" ON storage.objects;

-- Policy 1: Authenticated users can upload images
-- Only allows INSERT if bucket is landing-page
CREATE POLICY "Authenticated users can upload landing page images"
ON storage.objects
FOR INSERT
TO authenticated
WITH CHECK (
  bucket_id = 'landing-page'
);

-- Policy 2: Public can view landing page images
-- Allows SELECT for all users (including unauthenticated) for public viewing
-- This is essential for landing page images to be accessible to everyone
CREATE POLICY "Public can view landing page images"
ON storage.objects
FOR SELECT
TO public
USING (
  bucket_id = 'landing-page'
);

-- Policy 3: Authenticated users can delete images
-- Only allows DELETE if bucket is landing-page
CREATE POLICY "Authenticated users can delete landing page images"
ON storage.objects
FOR DELETE
TO authenticated
USING (
  bucket_id = 'landing-page'
);

-- Policy 4: Authenticated users can update images
-- Only allows UPDATE if bucket is landing-page
CREATE POLICY "Authenticated users can update landing page images"
ON storage.objects
FOR UPDATE
TO authenticated
USING (
  bucket_id = 'landing-page'
)
WITH CHECK (
  bucket_id = 'landing-page'
);

COMMIT;

-- Notes:
-- 1. The bucket_id check ensures these policies only apply to the landing-page bucket
-- 2. Public SELECT policy allows all users to view landing page images (required for public website)
-- 3. Only authenticated users can upload/delete/update (typically admins managing landing page)
-- 4. All policies are idempotent (DROP IF EXISTS before CREATE) so they can be run multiple times safely
-- 5. Even though bucket is marked as "public", RLS policies provide explicit security control

