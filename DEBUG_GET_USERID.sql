-- Get the correct business_owner_id first
SELECT DISTINCT c.business_owner_id
FROM consignment_claims c
LEFT JOIN vendors v ON c.vendor_id = v.id
WHERE v.name ILIKE '%Mum%Heritage%'
LIMIT 1;

-- Then check claims for that user with the correct ID
-- (We'll run this after getting the ID)
