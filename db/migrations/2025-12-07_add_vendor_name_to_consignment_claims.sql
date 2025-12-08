-- Add vendor_name to consignment_claims for UI/queries that expect it
BEGIN;

ALTER TABLE consignment_claims
    ADD COLUMN IF NOT EXISTS vendor_name TEXT;

-- Backfill existing claims
UPDATE consignment_claims cc
SET vendor_name = v.name
FROM vendors v
WHERE v.id = cc.vendor_id
  AND (cc.vendor_name IS NULL OR cc.vendor_name = '');

-- Keep vendor_name in sync on inserts/updates
CREATE OR REPLACE FUNCTION set_claim_vendor_name()
RETURNS TRIGGER AS $$
BEGIN
    IF NEW.vendor_id IS NOT NULL THEN
        SELECT name INTO NEW.vendor_name FROM vendors WHERE id = NEW.vendor_id;
    END IF;
    RETURN NEW;
END;
$$ LANGUAGE plpgsql;

DROP TRIGGER IF EXISTS trigger_set_claim_vendor_name ON consignment_claims;
CREATE TRIGGER trigger_set_claim_vendor_name
    BEFORE INSERT OR UPDATE OF vendor_id ON consignment_claims
    FOR EACH ROW
    EXECUTE FUNCTION set_claim_vendor_name();

COMMIT;

