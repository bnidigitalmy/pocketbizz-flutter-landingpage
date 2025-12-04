-- Check if the view exists
SELECT table_name FROM information_schema.views 
WHERE table_name = 'available_carry_forward_items';

-- Also check all views that contain 'carry'
SELECT table_name FROM information_schema.views 
WHERE table_name ILIKE '%carry%';

-- If view doesn't exist, show raw carry_forward_items data
SELECT id, business_owner_id, vendor_id, product_name, quantity_available, status, created_at
FROM carry_forward_items
WHERE status = 'available'
ORDER BY created_at DESC
LIMIT 10;
