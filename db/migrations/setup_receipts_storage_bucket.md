# Setup Receipts Storage Bucket (PRIVATE)

> ⚠️ **IMPORTANT**: This bucket is PRIVATE for security. Receipts contain sensitive financial data.

## 1. Create Storage Bucket

Go to **Supabase Dashboard > Storage** and create a new bucket:

- **Name**: `receipts`
- **Public**: ❌ **NO** (Private bucket)
- **File size limit**: 5MB
- **Allowed MIME types**: `image/jpeg, image/png, image/webp`

## 2. Add RLS Policies

Run these SQL commands in the **Supabase SQL Editor**:

```sql
-- Policy: Users can upload their own receipts
CREATE POLICY "Users can upload own receipts"
ON storage.objects
FOR INSERT
TO authenticated
WITH CHECK (
    bucket_id = 'receipts' 
    AND (storage.foldername(name))[1] = auth.uid()::text
);

-- Policy: Users can view their own receipts (for signed URL generation)
CREATE POLICY "Users can view own receipts"
ON storage.objects
FOR SELECT
TO authenticated
USING (
    bucket_id = 'receipts' 
    AND (storage.foldername(name))[1] = auth.uid()::text
);

-- Policy: Users can delete their own receipts
CREATE POLICY "Users can delete own receipts"
ON storage.objects
FOR DELETE
TO authenticated
USING (
    bucket_id = 'receipts' 
    AND (storage.foldername(name))[1] = auth.uid()::text
);
```

## 3. File Structure

Receipts are organized in the following structure:

```
receipts/
  └── {user_id}/
      └── {year}/
          └── {month}/
              └── receipt-{timestamp}.jpg
```

Example:
```
receipts/
  └── abc123-user-uuid/
      └── 2024/
          └── 12/
              └── receipt-1734456789123.jpg
```

## 4. How Viewing Works (Signed URLs)

Since the bucket is **private**, the app uses **signed URLs** to view receipts:

1. User taps "Resit" button on expense
2. App generates a **signed URL** (valid for 1 hour)
3. Image is displayed using the temporary URL
4. URL expires after 1 hour - cannot be shared/reused

```
┌────────────────────────────────────────┐
│  Private Bucket + Signed URL Flow      │
│                                        │
│  User taps "View Receipt"              │
│         ↓                              │
│  App calls createSignedUrl()           │
│         ↓                              │
│  Supabase returns temporary URL        │
│  (expires in 1 hour)                   │
│         ↓                              │
│  Image displayed securely              │
│         ↓                              │
│  URL expires - no permanent access     │
└────────────────────────────────────────┘
```

## Summary

After setup:
- ✅ **PRIVATE** bucket - no public access
- ✅ Users can only upload to their own folder
- ✅ Users can only view their own receipts
- ✅ Signed URLs expire after 1 hour
- ✅ 5MB max file size
- ✅ Only image files allowed
- 🔒 Receipts are secure and cannot be shared via URL

