-- Check all columns in consignment_claim_items table
SELECT column_name, data_type, is_nullable
FROM information_schema.columns
WHERE table_name = 'consignment_claim_items'
ORDER BY ordinal_position;
