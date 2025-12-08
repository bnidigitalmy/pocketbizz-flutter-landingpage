-- Check claims for this user without UUID validation
SELECT 
  c.id,
  c.claim_number,
  c.status,
  c.business_owner_id,
  c.created_at
FROM consignment_claims c
WHERE c.business_owner_id::text = '59099145-c65a-4108-bfb3-1ee6b18762f'
ORDER BY c.created_at DESC
LIMIT 20;

-- Check what the current user ID is in auth
SELECT auth.uid() as current_user_id;
