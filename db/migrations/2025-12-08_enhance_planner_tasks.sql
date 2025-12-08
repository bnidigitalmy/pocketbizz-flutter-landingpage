-- Comprehensive Planner Tasks Enhancement
-- Adds: description, subtasks, recurring, categories, projects, time tracking, etc.

BEGIN;

-- ============================================================================
-- STEP 1: ADD NEW COLUMNS TO planner_tasks
-- ============================================================================

ALTER TABLE public.planner_tasks
  -- Task Details
  ADD COLUMN IF NOT EXISTS description TEXT,
  ADD COLUMN IF NOT EXISTS notes TEXT,
  
  -- Subtasks (stored as JSONB array)
  ADD COLUMN IF NOT EXISTS subtasks JSONB DEFAULT '[]'::jsonb,
  
  -- Recurring Tasks
  ADD COLUMN IF NOT EXISTS is_recurring BOOLEAN NOT NULL DEFAULT false,
  ADD COLUMN IF NOT EXISTS recurrence_pattern TEXT, -- daily, weekly, monthly, yearly, custom
  ADD COLUMN IF NOT EXISTS recurrence_interval INTEGER DEFAULT 1, -- every N days/weeks/months
  ADD COLUMN IF NOT EXISTS recurrence_days INTEGER[], -- for weekly: [1,3,5] = Mon,Wed,Fri
  ADD COLUMN IF NOT EXISTS recurrence_end_date DATE,
  ADD COLUMN IF NOT EXISTS recurrence_count INTEGER, -- max occurrences
  ADD COLUMN IF NOT EXISTS next_occurrence_at TIMESTAMPTZ,
  ADD COLUMN IF NOT EXISTS parent_task_id UUID REFERENCES public.planner_tasks(id) ON DELETE CASCADE,
  
  -- Organization
  ADD COLUMN IF NOT EXISTS category_id UUID,
  ADD COLUMN IF NOT EXISTS project_id UUID,
  ADD COLUMN IF NOT EXISTS tags TEXT[] DEFAULT '{}',
  
  -- Dependencies
  ADD COLUMN IF NOT EXISTS depends_on_task_ids UUID[] DEFAULT '{}',
  ADD COLUMN IF NOT EXISTS blocks_task_ids UUID[] DEFAULT '{}',
  
  -- Time Tracking
  ADD COLUMN IF NOT EXISTS estimated_hours NUMERIC(5,2),
  ADD COLUMN IF NOT EXISTS actual_hours NUMERIC(5,2),
  ADD COLUMN IF NOT EXISTS time_spent_minutes INTEGER DEFAULT 0,
  ADD COLUMN IF NOT EXISTS started_at TIMESTAMPTZ,
  
  -- Status Enhancement (add 'in_progress' to existing status)
  -- Note: We'll use CHECK constraint to validate status values
  
  -- Attachments & Comments
  ADD COLUMN IF NOT EXISTS attachment_urls TEXT[] DEFAULT '{}',
  ADD COLUMN IF NOT EXISTS comments JSONB DEFAULT '[]'::jsonb,
  
  -- Template & Sharing
  ADD COLUMN IF NOT EXISTS template_id UUID,
  ADD COLUMN IF NOT EXISTS is_template BOOLEAN NOT NULL DEFAULT false,
  ADD COLUMN IF NOT EXISTS shared_with_user_ids UUID[] DEFAULT '{}',
  
  -- Enhanced Metadata
  ADD COLUMN IF NOT EXISTS location TEXT,
  ADD COLUMN IF NOT EXISTS reminder_sent_at TIMESTAMPTZ;

-- ============================================================================
-- STEP 2: UPDATE STATUS CHECK CONSTRAINT
-- ============================================================================

-- Drop old constraint if exists
ALTER TABLE public.planner_tasks
  DROP CONSTRAINT IF EXISTS planner_tasks_status_check;

-- Add new constraint with 'in_progress' status
ALTER TABLE public.planner_tasks
  ADD CONSTRAINT planner_tasks_status_check 
  CHECK (status IN ('open', 'in_progress', 'done', 'snoozed', 'dismissed', 'cancelled'));

-- ============================================================================
-- STEP 3: CREATE CATEGORIES TABLE
-- ============================================================================

CREATE TABLE IF NOT EXISTS public.planner_categories (
  id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
  business_owner_id UUID NOT NULL REFERENCES auth.users(id) ON DELETE CASCADE,
  name TEXT NOT NULL,
  color TEXT, -- hex color code
  icon TEXT, -- icon name
  created_at TIMESTAMPTZ NOT NULL DEFAULT NOW(),
  updated_at TIMESTAMPTZ NOT NULL DEFAULT NOW(),
  
  UNIQUE(business_owner_id, name)
);

CREATE INDEX IF NOT EXISTS idx_planner_categories_owner 
  ON public.planner_categories(business_owner_id);

ALTER TABLE public.planner_categories ENABLE ROW LEVEL SECURITY;

CREATE POLICY planner_categories_select_own ON public.planner_categories
  FOR SELECT USING (business_owner_id = auth.uid());

CREATE POLICY planner_categories_insert_own ON public.planner_categories
  FOR INSERT WITH CHECK (business_owner_id = auth.uid());

CREATE POLICY planner_categories_update_own ON public.planner_categories
  FOR UPDATE USING (business_owner_id = auth.uid());

CREATE POLICY planner_categories_delete_own ON public.planner_categories
  FOR DELETE USING (business_owner_id = auth.uid());

-- Add foreign key to planner_tasks
ALTER TABLE public.planner_tasks
  ADD CONSTRAINT planner_tasks_category_fk 
  FOREIGN KEY (category_id) REFERENCES public.planner_categories(id) ON DELETE SET NULL;

-- ============================================================================
-- STEP 4: CREATE PROJECTS TABLE
-- ============================================================================

CREATE TABLE IF NOT EXISTS public.planner_projects (
  id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
  business_owner_id UUID NOT NULL REFERENCES auth.users(id) ON DELETE CASCADE,
  name TEXT NOT NULL,
  description TEXT,
  color TEXT,
  icon TEXT,
  is_archived BOOLEAN NOT NULL DEFAULT false,
  created_at TIMESTAMPTZ NOT NULL DEFAULT NOW(),
  updated_at TIMESTAMPTZ NOT NULL DEFAULT NOW(),
  
  UNIQUE(business_owner_id, name)
);

CREATE INDEX IF NOT EXISTS idx_planner_projects_owner 
  ON public.planner_projects(business_owner_id);

ALTER TABLE public.planner_projects ENABLE ROW LEVEL SECURITY;

CREATE POLICY planner_projects_select_own ON public.planner_projects
  FOR SELECT USING (business_owner_id = auth.uid());

CREATE POLICY planner_projects_insert_own ON public.planner_projects
  FOR INSERT WITH CHECK (business_owner_id = auth.uid());

CREATE POLICY planner_projects_update_own ON public.planner_projects
  FOR UPDATE USING (business_owner_id = auth.uid());

CREATE POLICY planner_projects_delete_own ON public.planner_projects
  FOR DELETE USING (business_owner_id = auth.uid());

-- Add foreign key to planner_tasks
ALTER TABLE public.planner_tasks
  ADD CONSTRAINT planner_tasks_project_fk 
  FOREIGN KEY (project_id) REFERENCES public.planner_projects(id) ON DELETE SET NULL;

-- ============================================================================
-- STEP 5: CREATE TASK TEMPLATES TABLE
-- ============================================================================

CREATE TABLE IF NOT EXISTS public.planner_task_templates (
  id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
  business_owner_id UUID NOT NULL REFERENCES auth.users(id) ON DELETE CASCADE,
  name TEXT NOT NULL,
  title TEXT NOT NULL,
  description TEXT,
  category_id UUID REFERENCES public.planner_categories(id) ON DELETE SET NULL,
  project_id UUID REFERENCES public.planner_projects(id) ON DELETE SET NULL,
  priority TEXT NOT NULL DEFAULT 'normal',
  estimated_hours NUMERIC(5,2),
  subtasks JSONB DEFAULT '[]'::jsonb,
  tags TEXT[] DEFAULT '{}',
  created_at TIMESTAMPTZ NOT NULL DEFAULT NOW(),
  updated_at TIMESTAMPTZ NOT NULL DEFAULT NOW(),
  
  UNIQUE(business_owner_id, name)
);

CREATE INDEX IF NOT EXISTS idx_planner_templates_owner 
  ON public.planner_task_templates(business_owner_id);

ALTER TABLE public.planner_task_templates ENABLE ROW LEVEL SECURITY;

CREATE POLICY planner_templates_select_own ON public.planner_task_templates
  FOR SELECT USING (business_owner_id = auth.uid());

CREATE POLICY planner_templates_insert_own ON public.planner_task_templates
  FOR INSERT WITH CHECK (business_owner_id = auth.uid());

CREATE POLICY planner_templates_update_own ON public.planner_task_templates
  FOR UPDATE USING (business_owner_id = auth.uid());

CREATE POLICY planner_templates_delete_own ON public.planner_task_templates
  FOR DELETE USING (business_owner_id = auth.uid());

-- Add foreign key to planner_tasks
ALTER TABLE public.planner_tasks
  ADD CONSTRAINT planner_tasks_template_fk 
  FOREIGN KEY (template_id) REFERENCES public.planner_task_templates(id) ON DELETE SET NULL;

-- ============================================================================
-- STEP 6: CREATE INDEXES FOR NEW FIELDS
-- ============================================================================

CREATE INDEX IF NOT EXISTS idx_planner_tasks_category 
  ON public.planner_tasks(category_id) WHERE category_id IS NOT NULL;

CREATE INDEX IF NOT EXISTS idx_planner_tasks_project 
  ON public.planner_tasks(project_id) WHERE project_id IS NOT NULL;

CREATE INDEX IF NOT EXISTS idx_planner_tasks_recurring 
  ON public.planner_tasks(is_recurring, next_occurrence_at) 
  WHERE is_recurring = true;

CREATE INDEX IF NOT EXISTS idx_planner_tasks_parent 
  ON public.planner_tasks(parent_task_id) WHERE parent_task_id IS NOT NULL;

CREATE INDEX IF NOT EXISTS idx_planner_tasks_tags 
  ON public.planner_tasks USING GIN(tags);

CREATE INDEX IF NOT EXISTS idx_planner_tasks_status_priority 
  ON public.planner_tasks(status, priority, due_at);

-- ============================================================================
-- STEP 7: CREATE FUNCTION TO GENERATE RECURRING TASKS
-- ============================================================================

CREATE OR REPLACE FUNCTION generate_next_recurring_task()
RETURNS TRIGGER AS $$
DECLARE
  v_next_due TIMESTAMPTZ;
  v_pattern TEXT;
  v_interval INTEGER;
  v_days INTEGER[];
  v_end_date DATE;
  v_count INTEGER;
  v_occurrences INTEGER;
BEGIN
  -- Only process if task is done and is recurring
  IF NEW.status != 'done' OR OLD.status = 'done' OR NOT NEW.is_recurring THEN
    RETURN NEW;
  END IF;

  v_pattern := NEW.recurrence_pattern;
  v_interval := COALESCE(NEW.recurrence_interval, 1);
  v_days := NEW.recurrence_days;
  v_end_date := NEW.recurrence_end_date;
  v_count := NEW.recurrence_count;

  -- Check if we should stop recurring
  IF v_end_date IS NOT NULL AND v_end_date < CURRENT_DATE THEN
    RETURN NEW; -- Stop recurring
  END IF;

  -- Count existing occurrences
  SELECT COUNT(*) INTO v_occurrences
  FROM public.planner_tasks
  WHERE parent_task_id = NEW.id OR id = NEW.id;

  IF v_count IS NOT NULL AND v_occurrences >= v_count THEN
    RETURN NEW; -- Max occurrences reached
  END IF;

  -- Calculate next occurrence
  v_next_due := NEW.due_at;
  
  CASE v_pattern
    WHEN 'daily' THEN
      v_next_due := NEW.due_at + (v_interval || ' days')::INTERVAL;
    WHEN 'weekly' THEN
      v_next_due := NEW.due_at + (v_interval || ' weeks')::INTERVAL;
    WHEN 'monthly' THEN
      v_next_due := NEW.due_at + (v_interval || ' months')::INTERVAL;
    WHEN 'yearly' THEN
      v_next_due := NEW.due_at + (v_interval || ' years')::INTERVAL;
    ELSE
      RETURN NEW; -- Unknown pattern
  END CASE;

  -- Create next task
  INSERT INTO public.planner_tasks (
    business_owner_id,
    title,
    type,
    status,
    priority,
    due_at,
    remind_at,
    description,
    notes,
    subtasks,
    is_recurring,
    recurrence_pattern,
    recurrence_interval,
    recurrence_days,
    recurrence_end_date,
    recurrence_count,
    next_occurrence_at,
    parent_task_id,
    category_id,
    project_id,
    tags,
    estimated_hours,
    is_auto
  ) VALUES (
    NEW.business_owner_id,
    NEW.title,
    NEW.type,
    'open',
    NEW.priority,
    v_next_due,
    v_next_due - INTERVAL '30 minutes',
    NEW.description,
    NEW.notes,
    NEW.subtasks,
    true,
    v_pattern,
    v_interval,
    v_days,
    v_end_date,
    v_count,
    v_next_due,
    COALESCE(NEW.parent_task_id, NEW.id),
    NEW.category_id,
    NEW.project_id,
    NEW.tags,
    NEW.estimated_hours,
    false
  );

  RETURN NEW;
END;
$$ LANGUAGE plpgsql;

CREATE TRIGGER trigger_generate_recurring_task
  AFTER UPDATE OF status ON public.planner_tasks
  FOR EACH ROW
  WHEN (NEW.status = 'done' AND OLD.status != 'done' AND NEW.is_recurring = true)
  EXECUTE FUNCTION generate_next_recurring_task();

-- ============================================================================
-- STEP 8: CREATE FUNCTION TO UPDATE UPDATED_AT
-- ============================================================================

CREATE OR REPLACE FUNCTION update_planner_updated_at()
RETURNS TRIGGER AS $$
BEGIN
  NEW.updated_at = NOW();
  RETURN NEW;
END;
$$ LANGUAGE plpgsql;

CREATE TRIGGER trigger_update_categories_updated_at
  BEFORE UPDATE ON public.planner_categories
  FOR EACH ROW
  EXECUTE FUNCTION update_planner_updated_at();

CREATE TRIGGER trigger_update_projects_updated_at
  BEFORE UPDATE ON public.planner_projects
  FOR EACH ROW
  EXECUTE FUNCTION update_planner_updated_at();

CREATE TRIGGER trigger_update_templates_updated_at
  BEFORE UPDATE ON public.planner_task_templates
  FOR EACH ROW
  EXECUTE FUNCTION update_planner_updated_at();

COMMIT;

-- ============================================================================
-- NOTES:
-- 1. Subtasks stored as JSONB: [{"id": "uuid", "title": "...", "done": false}]
-- 2. Comments stored as JSONB: [{"id": "uuid", "user_id": "...", "text": "...", "created_at": "..."}]
-- 3. Recurring tasks auto-generate when parent is marked done
-- 4. Tags use PostgreSQL array for efficient searching
-- 5. Dependencies stored as UUID arrays
-- ============================================================================

