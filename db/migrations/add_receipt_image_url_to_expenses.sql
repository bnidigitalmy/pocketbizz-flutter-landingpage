-- Migration: Add receipt_image_url column to expenses table
-- This allows storing the URL of the scanned receipt image in Supabase Storage

-- Add the new column
ALTER TABLE expenses
ADD COLUMN IF NOT EXISTS receipt_image_url TEXT;

-- Add comment for documentation
COMMENT ON COLUMN expenses.receipt_image_url IS 'URL to the scanned receipt image stored in Supabase Storage (bucket: receipts)';

-- Create index for faster lookups of expenses with receipts
CREATE INDEX IF NOT EXISTS idx_expenses_receipt_image_url 
ON expenses (receipt_image_url) 
WHERE receipt_image_url IS NOT NULL;

