-- Google Drive Sync Logs
-- Tracks documents synced to Google Drive for backup

BEGIN;

-- Create google_drive_sync_logs table
CREATE TABLE IF NOT EXISTS public.google_drive_sync_logs (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  business_owner_id UUID NOT NULL REFERENCES auth.users(id) ON DELETE CASCADE,
  
  -- Document info
  file_name TEXT NOT NULL,
  file_type TEXT NOT NULL, -- 'invoice', 'thermal_invoice', 'claim_statement', 'thermal_claim', 'receipt_a5', etc.
  file_size_bytes BIGINT,
  mime_type TEXT, -- 'application/pdf', 'image/png', etc.
  
  -- Google Drive info
  drive_file_id TEXT NOT NULL UNIQUE,
  drive_web_view_link TEXT NOT NULL,
  drive_folder_id TEXT, -- Optional: folder where file is stored
  
  -- Related entity info (optional)
  related_entity_type TEXT, -- 'sale', 'claim', 'booking', etc.
  related_entity_id UUID, -- ID of the related entity
  
  -- Vendor info (for claims)
  vendor_name TEXT,
  
  -- Sync metadata
  synced_at TIMESTAMPTZ NOT NULL DEFAULT NOW(),
  sync_status TEXT NOT NULL DEFAULT 'success', -- 'success', 'failed', 'pending'
  error_message TEXT,
  
  -- Timestamps
  created_at TIMESTAMPTZ NOT NULL DEFAULT NOW(),
  updated_at TIMESTAMPTZ NOT NULL DEFAULT NOW()
);

-- Add columns if table already exists (for migration safety)
DO $$ 
BEGIN
  -- Add columns that might be missing if table was created before
  IF NOT EXISTS (SELECT 1 FROM information_schema.columns 
                 WHERE table_schema = 'public' 
                 AND table_name = 'google_drive_sync_logs' 
                 AND column_name = 'related_entity_type') THEN
    ALTER TABLE public.google_drive_sync_logs ADD COLUMN related_entity_type TEXT;
  END IF;
  
  IF NOT EXISTS (SELECT 1 FROM information_schema.columns 
                 WHERE table_schema = 'public' 
                 AND table_name = 'google_drive_sync_logs' 
                 AND column_name = 'related_entity_id') THEN
    ALTER TABLE public.google_drive_sync_logs ADD COLUMN related_entity_id UUID;
  END IF;
  
  IF NOT EXISTS (SELECT 1 FROM information_schema.columns 
                 WHERE table_schema = 'public' 
                 AND table_name = 'google_drive_sync_logs' 
                 AND column_name = 'drive_folder_id') THEN
    ALTER TABLE public.google_drive_sync_logs ADD COLUMN drive_folder_id TEXT;
  END IF;
  
  IF NOT EXISTS (SELECT 1 FROM information_schema.columns 
                 WHERE table_schema = 'public' 
                 AND table_name = 'google_drive_sync_logs' 
                 AND column_name = 'vendor_name') THEN
    ALTER TABLE public.google_drive_sync_logs ADD COLUMN vendor_name TEXT;
  END IF;
  
  IF NOT EXISTS (SELECT 1 FROM information_schema.columns 
                 WHERE table_schema = 'public' 
                 AND table_name = 'google_drive_sync_logs' 
                 AND column_name = 'error_message') THEN
    ALTER TABLE public.google_drive_sync_logs ADD COLUMN error_message TEXT;
  END IF;
  
  IF NOT EXISTS (SELECT 1 FROM information_schema.columns 
                 WHERE table_schema = 'public' 
                 AND table_name = 'google_drive_sync_logs' 
                 AND column_name = 'file_size_bytes') THEN
    ALTER TABLE public.google_drive_sync_logs ADD COLUMN file_size_bytes BIGINT;
  END IF;
  
  IF NOT EXISTS (SELECT 1 FROM information_schema.columns 
                 WHERE table_schema = 'public' 
                 AND table_name = 'google_drive_sync_logs' 
                 AND column_name = 'mime_type') THEN
    ALTER TABLE public.google_drive_sync_logs ADD COLUMN mime_type TEXT;
  END IF;
END $$;

-- Create indexes (only if columns exist)
CREATE INDEX IF NOT EXISTS idx_google_drive_sync_logs_business_owner ON public.google_drive_sync_logs(business_owner_id);
CREATE INDEX IF NOT EXISTS idx_google_drive_sync_logs_file_type ON public.google_drive_sync_logs(file_type);
CREATE INDEX IF NOT EXISTS idx_google_drive_sync_logs_synced_at ON public.google_drive_sync_logs(synced_at DESC);
CREATE INDEX IF NOT EXISTS idx_google_drive_sync_logs_drive_file_id ON public.google_drive_sync_logs(drive_file_id);

-- Create composite index for related entity (only if both columns exist)
DO $$
BEGIN
  IF EXISTS (SELECT 1 FROM information_schema.columns 
             WHERE table_schema = 'public' 
             AND table_name = 'google_drive_sync_logs' 
             AND column_name = 'related_entity_type')
     AND EXISTS (SELECT 1 FROM information_schema.columns 
                 WHERE table_schema = 'public' 
                 AND table_name = 'google_drive_sync_logs' 
                 AND column_name = 'related_entity_id') THEN
    CREATE INDEX IF NOT EXISTS idx_google_drive_sync_logs_related_entity 
      ON public.google_drive_sync_logs(related_entity_type, related_entity_id);
  END IF;
END $$;

-- Enable RLS
ALTER TABLE public.google_drive_sync_logs ENABLE ROW LEVEL SECURITY;

-- RLS Policies
-- Users can only see their own sync logs
CREATE POLICY "Users can view their own sync logs"
  ON public.google_drive_sync_logs
  FOR SELECT
  USING (business_owner_id = auth.uid());

-- Users can insert their own sync logs
CREATE POLICY "Users can insert their own sync logs"
  ON public.google_drive_sync_logs
  FOR INSERT
  WITH CHECK (business_owner_id = auth.uid());

-- Users can update their own sync logs
CREATE POLICY "Users can update their own sync logs"
  ON public.google_drive_sync_logs
  FOR UPDATE
  USING (business_owner_id = auth.uid());

-- Users can delete their own sync logs
CREATE POLICY "Users can delete their own sync logs"
  ON public.google_drive_sync_logs
  FOR DELETE
  USING (business_owner_id = auth.uid());

-- Create updated_at trigger
CREATE OR REPLACE FUNCTION update_google_drive_sync_logs_updated_at()
RETURNS TRIGGER AS $$
BEGIN
  NEW.updated_at = NOW();
  RETURN NEW;
END;
$$ LANGUAGE plpgsql;

CREATE TRIGGER update_google_drive_sync_logs_updated_at
  BEFORE UPDATE ON public.google_drive_sync_logs
  FOR EACH ROW
  EXECUTE FUNCTION update_google_drive_sync_logs_updated_at();

COMMIT;

