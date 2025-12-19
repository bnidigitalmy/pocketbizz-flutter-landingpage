-- ============================================================================
-- ENTERPRISE-GRADE HARDENING MEASURES
-- ============================================================================
-- This migration adds additional security layers beyond RLS:
-- 1. Database constraints (data integrity)
-- 2. Audit logging (compliance & tracking)
-- 3. Soft delete support (data recovery)
-- ============================================================================

-- ============================================================================
-- 1. DATABASE CONSTRAINTS (WAJIB - Defense in Depth)
-- ============================================================================
-- Even if UI has bugs, database enforces integrity

-- Products table
ALTER TABLE products
ADD CONSTRAINT products_owner_check
CHECK (business_owner_id IS NOT NULL);

-- Sales table
ALTER TABLE sales
ADD CONSTRAINT sales_owner_check
CHECK (business_owner_id IS NOT NULL);

-- Expenses table
ALTER TABLE expenses
ADD CONSTRAINT expenses_owner_check
CHECK (business_owner_id IS NOT NULL);

-- Bookings table
ALTER TABLE bookings
ADD CONSTRAINT bookings_owner_check
CHECK (business_owner_id IS NOT NULL);

-- Stock items table
ALTER TABLE stock_items
ADD CONSTRAINT stock_items_owner_check
CHECK (business_owner_id IS NOT NULL);

-- Categories table
ALTER TABLE categories
ADD CONSTRAINT categories_owner_check
CHECK (business_owner_id IS NOT NULL);

-- Suppliers table (if exists)
DO $$
BEGIN
  IF EXISTS (SELECT 1 FROM information_schema.tables WHERE table_name = 'suppliers') THEN
    ALTER TABLE suppliers
    ADD CONSTRAINT suppliers_owner_check
    CHECK (business_owner_id IS NOT NULL);
  END IF;
END $$;

-- Purchase orders table (if exists)
DO $$
BEGIN
  IF EXISTS (SELECT 1 FROM information_schema.tables WHERE table_name = 'purchase_orders') THEN
    ALTER TABLE purchase_orders
    ADD CONSTRAINT purchase_orders_owner_check
    CHECK (business_owner_id IS NOT NULL);
  END IF;
END $$;

-- Claims table (if exists)
DO $$
BEGIN
  IF EXISTS (SELECT 1 FROM information_schema.tables WHERE table_name = 'consignment_claims') THEN
    ALTER TABLE consignment_claims
    ADD CONSTRAINT consignment_claims_owner_check
    CHECK (business_owner_id IS NOT NULL);
  END IF;
END $$;

-- ============================================================================
-- 2. AUDIT LOGS TABLE (Compliance & Tracking)
-- ============================================================================
-- Tracks important actions for security and compliance

CREATE TABLE IF NOT EXISTS audit_logs (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  user_id UUID NOT NULL REFERENCES auth.users(id) ON DELETE CASCADE,
  business_owner_id UUID NOT NULL REFERENCES auth.users(id) ON DELETE CASCADE,
  action TEXT NOT NULL, -- 'login', 'delete', 'export', 'payment', 'create', 'update'
  entity_type TEXT NOT NULL, -- 'product', 'sale', 'expense', 'booking', etc.
  entity_id UUID, -- ID of the affected entity (nullable)
  details JSONB, -- Additional context (user IP, changes made, etc.)
  ip_address TEXT, -- User's IP address (for security tracking)
  user_agent TEXT, -- Browser/client info
  created_at TIMESTAMP WITH TIME ZONE NOT NULL DEFAULT NOW(),
  
  -- Indexes for performance
  CONSTRAINT audit_logs_action_check 
    CHECK (action IN ('login', 'logout', 'create', 'update', 'delete', 'export', 
                      'payment', 'password_reset', 'email_verification', 'export_data'))
);

-- Indexes for audit logs
CREATE INDEX IF NOT EXISTS idx_audit_logs_user_id ON audit_logs(user_id);
CREATE INDEX IF NOT EXISTS idx_audit_logs_business_owner_id ON audit_logs(business_owner_id);
CREATE INDEX IF NOT EXISTS idx_audit_logs_action ON audit_logs(action);
CREATE INDEX IF NOT EXISTS idx_audit_logs_entity_type ON audit_logs(entity_type);
CREATE INDEX IF NOT EXISTS idx_audit_logs_created_at ON audit_logs(created_at DESC);
CREATE INDEX IF NOT EXISTS idx_audit_logs_entity ON audit_logs(entity_type, entity_id) 
  WHERE entity_id IS NOT NULL;

-- ============================================================================
-- RLS POLICIES FOR AUDIT LOGS
-- ============================================================================

ALTER TABLE audit_logs ENABLE ROW LEVEL SECURITY;

-- Users can view their own audit logs
CREATE POLICY "Users can view their own audit logs"
  ON audit_logs
  FOR SELECT
  USING (business_owner_id = auth.uid());

-- System can insert audit logs (via service role or function)
-- Note: This should be done via database function with SECURITY DEFINER
-- For now, allow authenticated users to insert (will be restricted by application logic)

-- ============================================================================
-- AUDIT LOG FUNCTION (Secure Insert)
-- ============================================================================
-- This function allows secure insertion of audit logs
-- Uses SECURITY DEFINER to bypass RLS (only for insert, not read)

CREATE OR REPLACE FUNCTION insert_audit_log(
  p_user_id UUID,
  p_action TEXT,
  p_entity_type TEXT,
  p_entity_id UUID DEFAULT NULL,
  p_details JSONB DEFAULT NULL,
  p_ip_address TEXT DEFAULT NULL,
  p_user_agent TEXT DEFAULT NULL
)
RETURNS UUID
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public
AS $$
DECLARE
  v_business_owner_id UUID;
  v_audit_log_id UUID;
BEGIN
  -- Get business owner ID from user
  SELECT id INTO v_business_owner_id
  FROM auth.users
  WHERE id = p_user_id;
  
  IF v_business_owner_id IS NULL THEN
    RAISE EXCEPTION 'User not found: %', p_user_id;
  END IF;
  
  -- Insert audit log
  INSERT INTO audit_logs (
    user_id,
    business_owner_id,
    action,
    entity_type,
    entity_id,
    details,
    ip_address,
    user_agent
  ) VALUES (
    p_user_id,
    v_business_owner_id,
    p_action,
    p_entity_type,
    p_entity_id,
    p_details,
    p_ip_address,
    p_user_agent
  )
  RETURNING id INTO v_audit_log_id;
  
  RETURN v_audit_log_id;
END;
$$;

-- Grant execute permission to authenticated users
GRANT EXECUTE ON FUNCTION insert_audit_log TO authenticated;

-- ============================================================================
-- 3. SOFT DELETE SUPPORT (Data Recovery)
-- ============================================================================
-- Add deleted_at column to critical tables for soft delete

-- Products
ALTER TABLE products
ADD COLUMN IF NOT EXISTS deleted_at TIMESTAMP WITH TIME ZONE;

CREATE INDEX IF NOT EXISTS idx_products_deleted_at ON products(deleted_at) 
  WHERE deleted_at IS NOT NULL;

-- Sales
ALTER TABLE sales
ADD COLUMN IF NOT EXISTS deleted_at TIMESTAMP WITH TIME ZONE;

CREATE INDEX IF NOT EXISTS idx_sales_deleted_at ON sales(deleted_at) 
  WHERE deleted_at IS NOT NULL;

-- Expenses
ALTER TABLE expenses
ADD COLUMN IF NOT EXISTS deleted_at TIMESTAMP WITH TIME ZONE;

CREATE INDEX IF NOT EXISTS idx_expenses_deleted_at ON expenses(deleted_at) 
  WHERE deleted_at IS NOT NULL;

-- Bookings
ALTER TABLE bookings
ADD COLUMN IF NOT EXISTS deleted_at TIMESTAMP WITH TIME ZONE;

CREATE INDEX IF NOT EXISTS idx_bookings_deleted_at ON bookings(deleted_at) 
  WHERE deleted_at IS NOT NULL;

-- Stock items (already has is_archived, but add deleted_at for consistency)
ALTER TABLE stock_items
ADD COLUMN IF NOT EXISTS deleted_at TIMESTAMP WITH TIME ZONE;

CREATE INDEX IF NOT EXISTS idx_stock_items_deleted_at ON stock_items(deleted_at) 
  WHERE deleted_at IS NOT NULL;

-- Categories
ALTER TABLE categories
ADD COLUMN IF NOT EXISTS deleted_at TIMESTAMP WITH TIME ZONE;

CREATE INDEX IF NOT EXISTS idx_categories_deleted_at ON categories(deleted_at) 
  WHERE deleted_at IS NOT NULL;

-- ============================================================================
-- UPDATE RLS POLICIES FOR SOFT DELETE
-- ============================================================================
-- Existing RLS policies should exclude deleted records
-- Most queries already use WHERE deleted_at IS NULL implicitly
-- But we should update critical policies to be explicit

-- Example: Products (if needed, adjust based on existing policies)
-- The existing RLS policies should already handle this if queries filter deleted_at
-- But for safety, we can add a view or update queries to exclude deleted records

-- ============================================================================
-- COMMENTS
-- ============================================================================

COMMENT ON TABLE audit_logs IS 'Audit trail for compliance and security tracking';
COMMENT ON COLUMN audit_logs.action IS 'Type of action: login, logout, create, update, delete, export, payment, etc.';
COMMENT ON COLUMN audit_logs.entity_type IS 'Type of entity affected: product, sale, expense, booking, etc.';
COMMENT ON COLUMN audit_logs.details IS 'Additional context as JSON (IP, changes, etc.)';
COMMENT ON COLUMN audit_logs.ip_address IS 'User IP address for security tracking';
COMMENT ON COLUMN audit_logs.user_agent IS 'Browser/client information';

COMMENT ON COLUMN products.deleted_at IS 'Soft delete timestamp. NULL = active, NOT NULL = deleted';
COMMENT ON COLUMN sales.deleted_at IS 'Soft delete timestamp. NULL = active, NOT NULL = deleted';
COMMENT ON COLUMN expenses.deleted_at IS 'Soft delete timestamp. NULL = active, NOT NULL = deleted';
COMMENT ON COLUMN bookings.deleted_at IS 'Soft delete timestamp. NULL = active, NOT NULL = deleted';

