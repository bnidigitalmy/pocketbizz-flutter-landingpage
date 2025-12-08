-- Check balance and status of all claims for this user
SELECT 
  c.claim_number,
  c.status,
  COALESCE(SUM(cci.balance_amount), 0) as total_balance,
  c.created_at
FROM consignment_claims c
LEFT JOIN consignment_claim_items cci ON c.id = cci.claim_id
WHERE c.business_owner_id::text = '59099145-c65a-4108-bfb3-1ee6b18762f'
AND c.vendor_id = (SELECT id FROM vendors WHERE name ILIKE '%Mum%Heritage%' LIMIT 1)
GROUP BY c.id, c.claim_number, c.status, c.created_at
ORDER BY c.created_at DESC;
