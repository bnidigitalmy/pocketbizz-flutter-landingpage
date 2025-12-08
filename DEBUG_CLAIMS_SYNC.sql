-- Check all claims for Mum's Heritage Kangar vendor
SELECT 
  c.id,
  c.claim_number,
  c.status,
  c.business_owner_id,
  v.name as vendor_name,
  COUNT(cci.id) as item_count,
  SUM(cci.balance_amount) as total_balance,
  c.created_at
FROM consignment_claims c
LEFT JOIN vendors v ON c.vendor_id = v.id
LEFT JOIN consignment_claim_items cci ON c.id = cci.claim_id
WHERE v.name ILIKE '%Mum%Heritage%'
GROUP BY c.id, c.claim_number, c.status, c.business_owner_id, v.name, c.created_at
ORDER BY c.created_at DESC
LIMIT 20;

-- Check if there are RLS issues - show all users who have claims for this vendor
SELECT DISTINCT c.business_owner_id, COUNT(*) as claim_count
FROM consignment_claims c
LEFT JOIN vendors v ON c.vendor_id = v.id
WHERE v.name ILIKE '%Mum%Heritage%'
GROUP BY c.business_owner_id;
