-- ============================================================================
-- BUSINESS PROFILE TABLE
-- Stores business information for invoices and statements
-- ============================================================================

BEGIN;

-- Create business_profile table
CREATE TABLE IF NOT EXISTS business_profile (
    id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
    business_owner_id UUID NOT NULL REFERENCES users (id) ON DELETE CASCADE UNIQUE,
    business_name TEXT NOT NULL,
    tagline TEXT,
    registration_number TEXT,
    address TEXT,
    phone TEXT,
    email TEXT,
    bank_name TEXT,
    account_number TEXT,
    account_name TEXT,
    payment_qr_code TEXT,
    created_at TIMESTAMPTZ NOT NULL DEFAULT NOW(),
    updated_at TIMESTAMPTZ NOT NULL DEFAULT NOW()
);

CREATE INDEX IF NOT EXISTS idx_business_profile_owner ON business_profile (business_owner_id);

-- Enable RLS
ALTER TABLE business_profile ENABLE ROW LEVEL SECURITY;

-- RLS Policies
CREATE POLICY business_profile_select_own ON business_profile
    FOR SELECT
    USING (business_owner_id = auth.uid());

CREATE POLICY business_profile_insert_own ON business_profile
    FOR INSERT
    WITH CHECK (business_owner_id = auth.uid());

CREATE POLICY business_profile_update_own ON business_profile
    FOR UPDATE
    USING (business_owner_id = auth.uid())
    WITH CHECK (business_owner_id = auth.uid());

CREATE POLICY business_profile_delete_own ON business_profile
    FOR DELETE
    USING (business_owner_id = auth.uid());

-- Trigger to update updated_at
CREATE OR REPLACE FUNCTION update_business_profile_updated_at()
RETURNS TRIGGER AS $$
BEGIN
    NEW.updated_at = NOW();
    RETURN NEW;
END;
$$ LANGUAGE plpgsql;

CREATE TRIGGER update_business_profile_updated_at
    BEFORE UPDATE ON business_profile
    FOR EACH ROW
    EXECUTE FUNCTION update_business_profile_updated_at();

COMMIT;

