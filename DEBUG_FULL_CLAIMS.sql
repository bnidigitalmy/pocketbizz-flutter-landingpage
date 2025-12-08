-- Check ALL claims in the database (no WHERE clause)
SELECT COUNT(*) as total_claims FROM consignment_claims;

-- Show first 5 claims with their business_owner_id
SELECT c.claim_number, c.business_owner_id, v.name as vendor_name
FROM consignment_claims c
LEFT JOIN vendors v ON c.vendor_id = v.id
LIMIT 5;

-- Check the data type of business_owner_id
SELECT column_name, data_type 
FROM information_schema.columns 
WHERE table_name = 'consignment_claims' 
AND column_name = 'business_owner_id';
