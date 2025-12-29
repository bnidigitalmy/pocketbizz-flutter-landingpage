BEGIN;

-- Add attachments support to feedback requests (image/video/file metadata)
ALTER TABLE feedback_requests
  ADD COLUMN IF NOT EXISTS attachments JSONB NOT NULL DEFAULT '[]'::jsonb;

-- Optional index for querying/filtering by attachment content
CREATE INDEX IF NOT EXISTS idx_feedback_requests_attachments_gin
  ON feedback_requests USING GIN (attachments);

COMMIT;


