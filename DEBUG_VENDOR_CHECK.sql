-- First, get the correct vendor_id
SELECT id, name FROM vendors WHERE name ILIKE '%Mum%Heritage%';

-- Then check if there are ANY claims at all for this user
SELECT c.claim_number, c.status, v.name as vendor_name
FROM consignment_claims c
LEFT JOIN vendors v ON c.vendor_id = v.id
WHERE c.business_owner_id::text = '59099145-c65a-4108-bfb3-1ee6b18762f'
LIMIT 20;
