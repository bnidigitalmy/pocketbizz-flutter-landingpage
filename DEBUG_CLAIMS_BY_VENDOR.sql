-- Check which vendor has the 19 claims
SELECT v.id, v.name, COUNT(c.id) as claim_count
FROM consignment_claims c
LEFT JOIN vendors v ON c.vendor_id = v.id
WHERE c.business_owner_id::text = '59099145-c65a-4108-bfb3-1ee6b18762f'
GROUP BY v.id, v.name
ORDER BY claim_count DESC;
