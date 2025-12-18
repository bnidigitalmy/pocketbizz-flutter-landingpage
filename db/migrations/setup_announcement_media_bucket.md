# Supabase Storage Bucket Setup: announcement-media

## Manual Setup Required

Supabase Storage buckets need to be created manually through the Supabase Dashboard. Follow these steps:

## Steps to Create Bucket

1. **Open Supabase Dashboard**
   - Go to: https://supabase.com/dashboard
   - Select your project

2. **Navigate to Storage**
   - Click on "Storage" in the left sidebar
   - Click "New bucket"

3. **Create Bucket**
   - **Bucket name**: `announcement-media`
   - **Public bucket**: ✅ **CHECKED** (Public bucket - all users need to view announcement media)
   - **File size limit**: 50 MB (or as needed)
   - **Allowed MIME types**: 
     - Images: `image/jpeg`, `image/png`, `image/gif`, `image/webp`
     - Videos: `video/mp4`, `video/quicktime`, `video/x-msvideo`
     - Files: `application/pdf`, `application/msword`, `application/vnd.openxmlformats-officedocument.wordprocessingml.document`, `application/vnd.ms-excel`, `application/vnd.openxmlformats-officedocument.spreadsheetml.sheet`, `text/plain`

4. **Configure RLS Policies**

   After creating the bucket, run the SQL migration file:
   
   **Option 1: Via Supabase Dashboard (Recommended)**
   - Go to SQL Editor in Supabase Dashboard
   - Open file: `db/migrations/setup_announcement_media_rls_policies.sql`
   - Copy and paste the entire SQL script
   - Click "Run" to execute

   **Option 2: Via Supabase CLI**
   ```bash
   npx supabase migration up
   ```

   The SQL script will automatically create RLS policies:
   - Authenticated users can upload media (INSERT)
   - Public can view media (SELECT) - for viewing announcements
   - Authenticated users can delete media (DELETE)
   - Authenticated users can update media (UPDATE)

## Storage Path Structure

Media files are organized by:
```
{type}/{announcementId}-{timestamp}.{extension}
```

Examples:
```
images/abc123-1234567890.jpg
videos/abc123-1234567891.mp4
files/abc123-1234567892.pdf
```

## Notes

- Bucket is PUBLIC so all users can view announcement media
- Only authenticated users (admins) can upload/delete media
- Files are organized by type (images, videos, files) for easy management
