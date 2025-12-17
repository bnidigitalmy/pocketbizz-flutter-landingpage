-- Create announcements table for broadcast messages to all users
CREATE TABLE IF NOT EXISTS announcements (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  
  -- Announcement details
  title VARCHAR(255) NOT NULL,
  message TEXT NOT NULL,
  type VARCHAR(20) DEFAULT 'info' CHECK (type IN ('info', 'success', 'warning', 'error', 'feature', 'maintenance')),
  priority VARCHAR(20) DEFAULT 'normal' CHECK (priority IN ('low', 'normal', 'high', 'urgent')),
  
  -- Targeting
  target_audience VARCHAR(20) DEFAULT 'all' CHECK (target_audience IN ('all', 'trial', 'active', 'expired', 'grace')),
  
  -- Display settings
  is_active BOOLEAN DEFAULT true,
  show_until TIMESTAMPTZ, -- Auto-hide after this date
  action_url TEXT, -- Optional link/action
  action_label VARCHAR(100), -- Button text
  
  -- Metadata
  created_by UUID REFERENCES auth.users(id) ON DELETE SET NULL,
  created_at TIMESTAMPTZ NOT NULL DEFAULT NOW(),
  updated_at TIMESTAMPTZ NOT NULL DEFAULT NOW()
);

-- Create index for faster queries
CREATE INDEX IF NOT EXISTS idx_announcements_active ON announcements(is_active, created_at DESC);
CREATE INDEX IF NOT EXISTS idx_announcements_type ON announcements(type);
CREATE INDEX IF NOT EXISTS idx_announcements_target ON announcements(target_audience);
CREATE INDEX IF NOT EXISTS idx_announcements_show_until ON announcements(show_until) WHERE show_until IS NOT NULL;

-- Create user announcement views table (track who has seen what)
CREATE TABLE IF NOT EXISTS announcement_views (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  announcement_id UUID NOT NULL REFERENCES announcements(id) ON DELETE CASCADE,
  user_id UUID NOT NULL REFERENCES auth.users(id) ON DELETE CASCADE,
  viewed_at TIMESTAMPTZ NOT NULL DEFAULT NOW(),
  
  UNIQUE(announcement_id, user_id)
);

-- Create index for faster queries
CREATE INDEX IF NOT EXISTS idx_announcement_views_user ON announcement_views(user_id);
CREATE INDEX IF NOT EXISTS idx_announcement_views_announcement ON announcement_views(announcement_id);

-- Enable RLS
ALTER TABLE announcements ENABLE ROW LEVEL SECURITY;
ALTER TABLE announcement_views ENABLE ROW LEVEL SECURITY;

-- RLS Policies for announcements
-- All authenticated users can view active announcements
CREATE POLICY "Users can view active announcements"
  ON announcements
  FOR SELECT
  USING (is_active = true AND auth.uid() IS NOT NULL);

-- Only admins can manage announcements
CREATE POLICY "Admins can manage announcements"
  ON announcements
  FOR ALL
  USING (auth.uid() IS NOT NULL); -- Admin check done at app level

-- RLS Policies for announcement_views
-- Users can view their own views
CREATE POLICY "Users can view own announcement views"
  ON announcement_views
  FOR SELECT
  USING (auth.uid() = user_id);

-- Users can insert their own views
CREATE POLICY "Users can insert own announcement views"
  ON announcement_views
  FOR INSERT
  WITH CHECK (auth.uid() = user_id);

-- Create trigger to update updated_at
CREATE TRIGGER trigger_update_announcements_updated_at
  BEFORE UPDATE ON announcements
  FOR EACH ROW
  EXECUTE FUNCTION update_feedback_updated_at();

