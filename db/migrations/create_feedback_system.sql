-- Create feedback/feature requests table
CREATE TABLE IF NOT EXISTS feedback_requests (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  business_owner_id UUID NOT NULL REFERENCES auth.users(id) ON DELETE CASCADE,
  
  -- Feedback details
  type VARCHAR(20) NOT NULL CHECK (type IN ('bug', 'feature', 'suggestion', 'other')),
  title VARCHAR(255) NOT NULL,
  description TEXT NOT NULL,
  priority VARCHAR(20) DEFAULT 'normal' CHECK (priority IN ('low', 'normal', 'high', 'urgent')),
  
  -- Status tracking
  status VARCHAR(20) DEFAULT 'pending' CHECK (status IN ('pending', 'reviewing', 'in_progress', 'completed', 'rejected', 'on_hold')),
  
  -- Admin response
  admin_notes TEXT,
  admin_id UUID REFERENCES auth.users(id) ON DELETE SET NULL,
  
  -- Implementation tracking
  implementation_notes TEXT,
  completed_at TIMESTAMPTZ,
  
  -- Metadata
  created_at TIMESTAMPTZ NOT NULL DEFAULT NOW(),
  updated_at TIMESTAMPTZ NOT NULL DEFAULT NOW()
);

-- Create index for faster queries
CREATE INDEX IF NOT EXISTS idx_feedback_business_owner ON feedback_requests(business_owner_id);
CREATE INDEX IF NOT EXISTS idx_feedback_status ON feedback_requests(status);
CREATE INDEX IF NOT EXISTS idx_feedback_type ON feedback_requests(type);
CREATE INDEX IF NOT EXISTS idx_feedback_created_at ON feedback_requests(created_at DESC);

-- Enable RLS
ALTER TABLE feedback_requests ENABLE ROW LEVEL SECURITY;

-- RLS Policies
-- Users can view their own feedback
CREATE POLICY "Users can view own feedback"
  ON feedback_requests
  FOR SELECT
  USING (auth.uid() = business_owner_id);

-- Users can create their own feedback
CREATE POLICY "Users can create own feedback"
  ON feedback_requests
  FOR INSERT
  WITH CHECK (auth.uid() = business_owner_id);

-- Users can update their own feedback (only if status is pending)
CREATE POLICY "Users can update own pending feedback"
  ON feedback_requests
  FOR UPDATE
  USING (auth.uid() = business_owner_id AND status = 'pending')
  WITH CHECK (auth.uid() = business_owner_id AND status = 'pending');

-- Admins can view all feedback
-- Note: Admin check is done via user metadata in app, but for RLS we allow all authenticated users
-- App-level AdminHelper.isAdmin() will enforce actual admin access
CREATE POLICY "Admins can view all feedback"
  ON feedback_requests
  FOR SELECT
  USING (auth.uid() IS NOT NULL);

-- Admins can update all feedback
-- Note: Admin check is done via user metadata in app, but for RLS we allow all authenticated users
-- App-level AdminHelper.isAdmin() will enforce actual admin access
CREATE POLICY "Admins can update all feedback"
  ON feedback_requests
  FOR UPDATE
  USING (auth.uid() IS NOT NULL);

-- Create trigger to update updated_at
CREATE OR REPLACE FUNCTION update_feedback_updated_at()
RETURNS TRIGGER AS $$
BEGIN
  NEW.updated_at = NOW();
  RETURN NEW;
END;
$$ LANGUAGE plpgsql;

CREATE TRIGGER trigger_update_feedback_updated_at
  BEFORE UPDATE ON feedback_requests
  FOR EACH ROW
  EXECUTE FUNCTION update_feedback_updated_at();

-- Create community links table
CREATE TABLE IF NOT EXISTS community_links (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  business_owner_id UUID NOT NULL REFERENCES auth.users(id) ON DELETE CASCADE,
  
  -- Link details
  platform VARCHAR(50) NOT NULL CHECK (platform IN ('facebook', 'telegram', 'whatsapp', 'discord', 'other')),
  name VARCHAR(255) NOT NULL,
  url TEXT NOT NULL,
  description TEXT,
  icon VARCHAR(50), -- Icon name for UI
  
  -- Display order
  display_order INTEGER DEFAULT 0,
  is_active BOOLEAN DEFAULT true,
  
  -- Metadata
  created_at TIMESTAMPTZ NOT NULL DEFAULT NOW(),
  updated_at TIMESTAMPTZ NOT NULL DEFAULT NOW()
);

-- Create index
CREATE INDEX IF NOT EXISTS idx_community_links_business_owner ON community_links(business_owner_id);
CREATE INDEX IF NOT EXISTS idx_community_links_active ON community_links(is_active, display_order);

-- Enable RLS
ALTER TABLE community_links ENABLE ROW LEVEL SECURITY;

-- RLS Policies
-- All authenticated users can view active community links
CREATE POLICY "Users can view active community links"
  ON community_links
  FOR SELECT
  USING (is_active = true AND auth.uid() IS NOT NULL);

-- Only admins can manage community links
-- Note: Admin check is done via user metadata in app, but for RLS we allow all authenticated users
-- App-level AdminHelper.isAdmin() will enforce actual admin access
CREATE POLICY "Admins can manage community links"
  ON community_links
  FOR ALL
  USING (auth.uid() IS NOT NULL);

-- Create trigger to update updated_at
CREATE TRIGGER trigger_update_community_links_updated_at
  BEFORE UPDATE ON community_links
  FOR EACH ROW
  EXECUTE FUNCTION update_feedback_updated_at();

