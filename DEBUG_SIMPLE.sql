-- SIMPLE DEBUG - Run each query separately

-- Query 1: Check if carry_forward_items table exists
SELECT table_name FROM information_schema.tables 
WHERE table_name = 'carry_forward_items';

-- Query 2: Check if carry_forward_status column exists
SELECT column_name, data_type FROM information_schema.columns 
WHERE table_name = 'consignment_claim_items' AND column_name = 'carry_forward_status';

-- Query 3: Check if any C/F items exist in database
SELECT COUNT(*) as cf_items_count FROM carry_forward_items;

-- Query 4: Check recent claim items with carry_forward_status
SELECT id, quantity_unsold, carry_forward_status, created_at 
FROM consignment_claim_items
WHERE quantity_unsold > 0
ORDER BY created_at DESC
LIMIT 10;

-- Query 5: Show any existing C/F items
SELECT id, product_name, status, quantity_available 
FROM carry_forward_items LIMIT 5;
