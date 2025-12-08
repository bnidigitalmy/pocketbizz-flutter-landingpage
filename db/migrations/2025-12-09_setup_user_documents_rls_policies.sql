-- RLS Policies for user-documents Storage Bucket
-- 
-- This migration sets up Row Level Security (RLS) policies for the user-documents bucket
-- to ensure users can only access their own documents.
--
-- Storage path structure: {userId}/{documentType}/{year}/{month}/{fileName}
-- Example: abc123/invoice/2025/12/Invois_DEL-2512-0020-792453_20251209.pdf

BEGIN;

-- Note: RLS is already enabled on storage.objects by default in Supabase
-- We only need to create the policies

-- Drop existing policies if they exist (for idempotency)
DROP POLICY IF EXISTS "Users can upload their own documents" ON storage.objects;
DROP POLICY IF EXISTS "Users can view their own documents" ON storage.objects;
DROP POLICY IF EXISTS "Users can delete their own documents" ON storage.objects;
DROP POLICY IF EXISTS "Users can update their own documents" ON storage.objects;

-- Policy 1: Users can upload their own documents
-- Only allows INSERT if the first folder in the path matches the user's ID
CREATE POLICY "Users can upload their own documents"
ON storage.objects
FOR INSERT
WITH CHECK (
  bucket_id = 'user-documents' AND
  (storage.foldername(name))[1] = auth.uid()::text
);

-- Policy 2: Users can view their own documents
-- Only allows SELECT if the first folder in the path matches the user's ID
CREATE POLICY "Users can view their own documents"
ON storage.objects
FOR SELECT
USING (
  bucket_id = 'user-documents' AND
  (storage.foldername(name))[1] = auth.uid()::text
);

-- Policy 3: Users can delete their own documents
-- Only allows DELETE if the first folder in the path matches the user's ID
CREATE POLICY "Users can delete their own documents"
ON storage.objects
FOR DELETE
USING (
  bucket_id = 'user-documents' AND
  (storage.foldername(name))[1] = auth.uid()::text
);

-- Policy 4: Users can update their own documents
-- Only allows UPDATE if the first folder in the path matches the user's ID
CREATE POLICY "Users can update their own documents"
ON storage.objects
FOR UPDATE
USING (
  bucket_id = 'user-documents' AND
  (storage.foldername(name))[1] = auth.uid()::text
);

COMMIT;

-- Notes:
-- 1. These policies use storage.foldername(name)[1] to get the first folder in the path
--    which should be the user's ID (auth.uid())
-- 2. The bucket_id check ensures these policies only apply to the user-documents bucket
-- 3. All policies are idempotent (DROP IF EXISTS before CREATE) so they can be run multiple times safely
-- 4. Users can only access documents where the path starts with their own user ID

