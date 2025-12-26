-- ============================================================================
-- ADD EMAIL COLUMN TO SUPPLIERS TABLE
-- ============================================================================
-- Suppliers table needs email column to match Vendor structure
-- Both Vendor and Supplier share same basic contact info structure

-- Add email column to suppliers table
ALTER TABLE suppliers
ADD COLUMN IF NOT EXISTS email TEXT;

-- Add index for email (optional, for faster lookups)
CREATE INDEX IF NOT EXISTS idx_suppliers_email ON suppliers (email) WHERE email IS NOT NULL;

-- Update comment
COMMENT ON COLUMN suppliers.email IS 'Supplier email address (optional)';

