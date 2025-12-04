-- Simple check: Show recent claim items with carry_forward status
SELECT id, quantity_unsold, carry_forward, carry_forward_status
FROM consignment_claim_items
ORDER BY created_at DESC
LIMIT 10;

-- Count how many items have carry_forward = TRUE
SELECT COUNT(*) as cf_true_count 
FROM consignment_claim_items 
WHERE carry_forward = TRUE;

-- Count how many C/F items exist
SELECT COUNT(*) as total_cf_items 
FROM carry_forward_items;
