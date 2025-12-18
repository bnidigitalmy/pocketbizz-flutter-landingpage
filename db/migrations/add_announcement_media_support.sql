-- Add media support to announcements table
-- Supports multiple media files (images, videos, documents) as JSONB array

ALTER TABLE announcements 
ADD COLUMN IF NOT EXISTS media JSONB DEFAULT '[]'::jsonb;

-- Add index for media queries
CREATE INDEX IF NOT EXISTS idx_announcements_media ON announcements USING GIN (media);

-- Media structure:
-- [
--   {
--     "type": "image" | "video" | "file",
--     "url": "https://...",
--     "thumbnail_url": "https://..." (optional, for videos),
--     "filename": "example.jpg",
--     "size": 123456 (bytes),
--     "mime_type": "image/jpeg"
--   }
-- ]

COMMENT ON COLUMN announcements.media IS 'Array of media files (images, videos, documents) attached to this announcement';
