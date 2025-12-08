-- Fix planner_tasks unique constraint for ON CONFLICT support
-- PostgREST requires a proper unique constraint (not partial index) for ON CONFLICT
-- Solution: Create a unique constraint on (business_owner_id, auto_hash)
-- This ensures deduplication per user while allowing NULL auto_hash for manual tasks

BEGIN;

-- Drop the partial unique index if it exists
DROP INDEX IF EXISTS public.planner_tasks_auto_hash_idx;

-- Drop existing constraint if it exists
ALTER TABLE public.planner_tasks
  DROP CONSTRAINT IF EXISTS planner_tasks_auto_hash_unique;

-- Create unique constraint on (business_owner_id, auto_hash)
-- PostgreSQL allows multiple NULLs in unique constraints, so manual tasks (NULL auto_hash) won't conflict
-- Auto tasks will be deduplicated per user by auto_hash
ALTER TABLE public.planner_tasks
  ADD CONSTRAINT planner_tasks_auto_hash_unique UNIQUE (business_owner_id, auto_hash);

COMMIT;

