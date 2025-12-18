-- RLS Policies for announcement-media Storage Bucket
-- 
-- This migration sets up Row Level Security (RLS) policies for the announcement-media bucket
-- to allow public viewing of announcement media while restricting uploads to authenticated users (admins).
--
-- Storage path structure: {type}/{announcementId}-{timestamp}.{extension}
-- Example: images/abc123-1234567890.jpg

BEGIN;

-- Note: RLS is already enabled on storage.objects by default in Supabase
-- We only need to create the policies

-- Drop existing policies if they exist (for idempotency)
DROP POLICY IF EXISTS "Authenticated users can upload announcement media" ON storage.objects;
DROP POLICY IF EXISTS "Public can view announcement media" ON storage.objects;
DROP POLICY IF EXISTS "Authenticated users can delete announcement media" ON storage.objects;
DROP POLICY IF EXISTS "Authenticated users can update announcement media" ON storage.objects;

-- Policy 1: Authenticated users can upload media
-- Only allows INSERT if bucket is announcement-media
CREATE POLICY "Authenticated users can upload announcement media"
ON storage.objects
FOR INSERT
TO authenticated
WITH CHECK (
  bucket_id = 'announcement-media'
);

-- Policy 2: Public can view announcement media
-- Allows SELECT for all users (including unauthenticated) for public viewing
CREATE POLICY "Public can view announcement media"
ON storage.objects
FOR SELECT
TO public
USING (
  bucket_id = 'announcement-media'
);

-- Policy 3: Authenticated users can delete media
-- Only allows DELETE if bucket is announcement-media
CREATE POLICY "Authenticated users can delete announcement media"
ON storage.objects
FOR DELETE
TO authenticated
USING (
  bucket_id = 'announcement-media'
);

-- Policy 4: Authenticated users can update media
-- Only allows UPDATE if bucket is announcement-media
CREATE POLICY "Authenticated users can update announcement media"
ON storage.objects
FOR UPDATE
TO authenticated
USING (
  bucket_id = 'announcement-media'
)
WITH CHECK (
  bucket_id = 'announcement-media'
);

COMMIT;

-- Notes:
-- 1. The bucket_id check ensures these policies only apply to the announcement-media bucket
-- 2. Public SELECT policy allows all users to view announcement media (since announcements are public)
-- 3. Only authenticated users can upload/delete/update (typically admins creating announcements)
-- 4. All policies are idempotent (DROP IF EXISTS before CREATE) so they can be run multiple times safely
