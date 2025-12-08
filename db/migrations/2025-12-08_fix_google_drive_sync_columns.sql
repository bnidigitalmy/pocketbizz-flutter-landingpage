-- Fix: Add missing columns to google_drive_sync_logs if they don't exist
-- This migration ensures all required columns are present

BEGIN;

-- Add error_message column if missing
DO $$ 
BEGIN
  IF NOT EXISTS (SELECT 1 FROM information_schema.columns 
                 WHERE table_schema = 'public' 
                 AND table_name = 'google_drive_sync_logs' 
                 AND column_name = 'error_message') THEN
    ALTER TABLE public.google_drive_sync_logs ADD COLUMN error_message TEXT;
    RAISE NOTICE 'Added error_message column';
  END IF;
END $$;

-- Add file_size_bytes column if missing
DO $$ 
BEGIN
  IF NOT EXISTS (SELECT 1 FROM information_schema.columns 
                 WHERE table_schema = 'public' 
                 AND table_name = 'google_drive_sync_logs' 
                 AND column_name = 'file_size_bytes') THEN
    ALTER TABLE public.google_drive_sync_logs ADD COLUMN file_size_bytes BIGINT;
    RAISE NOTICE 'Added file_size_bytes column';
  END IF;
END $$;

-- Add mime_type column if missing
DO $$ 
BEGIN
  IF NOT EXISTS (SELECT 1 FROM information_schema.columns 
                 WHERE table_schema = 'public' 
                 AND table_name = 'google_drive_sync_logs' 
                 AND column_name = 'mime_type') THEN
    ALTER TABLE public.google_drive_sync_logs ADD COLUMN mime_type TEXT;
    RAISE NOTICE 'Added mime_type column';
  END IF;
END $$;

-- Add sync_status column if missing
DO $$ 
BEGIN
  IF NOT EXISTS (SELECT 1 FROM information_schema.columns 
                 WHERE table_schema = 'public' 
                 AND table_name = 'google_drive_sync_logs' 
                 AND column_name = 'sync_status') THEN
    ALTER TABLE public.google_drive_sync_logs ADD COLUMN sync_status TEXT NOT NULL DEFAULT 'success';
    RAISE NOTICE 'Added sync_status column';
  END IF;
END $$;

COMMIT;

