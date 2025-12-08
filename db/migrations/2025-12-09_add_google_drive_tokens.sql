-- Google Drive OAuth Tokens Storage
-- Stores encrypted OAuth tokens for each user to enable persistent Google Drive sync

BEGIN;

-- Create google_drive_tokens table
CREATE TABLE IF NOT EXISTS public.google_drive_tokens (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  business_owner_id UUID NOT NULL UNIQUE REFERENCES auth.users(id) ON DELETE CASCADE,
  
  -- OAuth tokens (encrypted at application level)
  access_token TEXT NOT NULL,
  refresh_token TEXT, -- May be null for some OAuth flows
  token_expiry TIMESTAMPTZ NOT NULL,
  
  -- Google account info
  google_email TEXT,
  google_user_id TEXT,
  
  -- Metadata
  created_at TIMESTAMPTZ NOT NULL DEFAULT NOW(),
  updated_at TIMESTAMPTZ NOT NULL DEFAULT NOW()
);

-- Add columns if table already exists (for migration safety)
DO $$ 
BEGIN
  IF NOT EXISTS (SELECT 1 FROM information_schema.columns 
                 WHERE table_schema = 'public' 
                 AND table_name = 'google_drive_tokens' 
                 AND column_name = 'refresh_token') THEN
    ALTER TABLE public.google_drive_tokens ADD COLUMN refresh_token TEXT;
  END IF;
  
  IF NOT EXISTS (SELECT 1 FROM information_schema.columns 
                 WHERE table_schema = 'public' 
                 AND table_name = 'google_drive_tokens' 
                 AND column_name = 'google_email') THEN
    ALTER TABLE public.google_drive_tokens ADD COLUMN google_email TEXT;
  END IF;
  
  IF NOT EXISTS (SELECT 1 FROM information_schema.columns 
                 WHERE table_schema = 'public' 
                 AND table_name = 'google_drive_tokens' 
                 AND column_name = 'google_user_id') THEN
    ALTER TABLE public.google_drive_tokens ADD COLUMN google_user_id TEXT;
  END IF;
END $$;

-- Create indexes
CREATE INDEX IF NOT EXISTS idx_google_drive_tokens_business_owner 
  ON public.google_drive_tokens(business_owner_id);

-- Enable RLS
ALTER TABLE public.google_drive_tokens ENABLE ROW LEVEL SECURITY;

-- RLS Policies
-- Users can only see their own tokens
CREATE POLICY "Users can view their own Google Drive tokens"
  ON public.google_drive_tokens
  FOR SELECT
  USING (business_owner_id = auth.uid());

-- Users can insert their own tokens
CREATE POLICY "Users can insert their own Google Drive tokens"
  ON public.google_drive_tokens
  FOR INSERT
  WITH CHECK (business_owner_id = auth.uid());

-- Users can update their own tokens
CREATE POLICY "Users can update their own Google Drive tokens"
  ON public.google_drive_tokens
  FOR UPDATE
  USING (business_owner_id = auth.uid());

-- Users can delete their own tokens
CREATE POLICY "Users can delete their own Google Drive tokens"
  ON public.google_drive_tokens
  FOR DELETE
  USING (business_owner_id = auth.uid());

-- Create updated_at trigger
CREATE OR REPLACE FUNCTION update_google_drive_tokens_updated_at()
RETURNS TRIGGER AS $$
BEGIN
  NEW.updated_at = NOW();
  RETURN NEW;
END;
$$ LANGUAGE plpgsql;

CREATE TRIGGER update_google_drive_tokens_updated_at
  BEFORE UPDATE ON public.google_drive_tokens
  FOR EACH ROW
  EXECUTE FUNCTION update_google_drive_tokens_updated_at();

COMMIT;


