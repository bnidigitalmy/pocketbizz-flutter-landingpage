-- TEST: Manually insert test C/F items to verify Step 2 displays them correctly
-- This separates the database trigger from the UI display logic

INSERT INTO carry_forward_items (
    business_owner_id,
    vendor_id,
    product_name,
    quantity_available,
    unit_price,
    status
) 
VALUES 
(
    '00000000-0000-0000-0000-000000000001', -- Replace with actual business_owner_id
    '00000000-0000-0000-0000-000000000001', -- Replace with actual vendor_id
    'Test Product A',
    5.000,
    50.00,
    'available'
),
(
    '00000000-0000-0000-0000-000000000001',
    '00000000-0000-0000-0000-000000000001',
    'Test Product B',
    10.000,
    25.00,
    'available'
);

-- Verify insertion
SELECT id, product_name, quantity_available, status 
FROM carry_forward_items 
WHERE status = 'available'
ORDER BY created_at DESC;
