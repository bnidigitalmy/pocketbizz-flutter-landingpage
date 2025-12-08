-- Check a specific claim with full details
SELECT 
  c.claim_number,
  c.status,
  c.net_amount,
  c.paid_amount,
  c.balance_amount,
  COUNT(cci.id) as item_count,
  SUM(cci.net_amount) as items_total_net,
  SUM(cci.balance_amount) as items_total_balance
FROM consignment_claims c
LEFT JOIN consignment_claim_items cci ON c.id = cci.claim_id
WHERE c.business_owner_id::text = '59099145-c65a-4108-bfb3-1ee6b18762f'
AND c.vendor_id = (SELECT id FROM vendors WHERE name ILIKE '%Mum%Heritage%' LIMIT 1)
GROUP BY c.id, c.claim_number, c.status, c.net_amount, c.paid_amount, c.balance_amount
ORDER BY c.created_at DESC
LIMIT 5;
