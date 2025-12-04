-- Check if carry_forward=TRUE was actually saved
SELECT id, claim_id, quantity_unsold, carry_forward, carry_forward_status, created_at
FROM consignment_claim_items
WHERE carry_forward = TRUE
ORDER BY created_at DESC
LIMIT 10;

-- Check if any C/F items were created by the trigger
SELECT COUNT(*) as cf_count FROM carry_forward_items;

-- Show all C/F items in database
SELECT id, product_name, quantity_available, status, created_at 
FROM carry_forward_items
LIMIT 10;

-- Check if there are any errors in database logs
SELECT * FROM pg_stat_statements WHERE query LIKE '%carry_forward%' LIMIT 5;
