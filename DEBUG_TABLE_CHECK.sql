-- Quick check: Does carry_forward_items table exist?
SELECT EXISTS (
  SELECT 1 FROM information_schema.tables 
  WHERE table_name = 'carry_forward_items'
) as table_exists;

-- If table exists, how many records?
SELECT COUNT(*) as total_cf_items FROM carry_forward_items;

-- Show sample C/F items if any exist
SELECT id, source_claim_id, quantity_available, status, created_at 
FROM carry_forward_items 
LIMIT 5;
