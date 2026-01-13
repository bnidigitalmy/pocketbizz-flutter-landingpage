-- Add announcement for Recipe Documents feature
-- This announcement will be shown to all users to introduce the new feature
-- Idempotent: Delete existing announcement with same title if exists, then insert new one

-- Delete existing announcement if it exists (by title to avoid duplicates)
DELETE FROM announcements 
WHERE title = 'Ciri Baru: Dokumen Resepi' 
  AND action_url = 'app://recipe-documents';

-- Insert new announcement
INSERT INTO announcements (
  title,
  message,
  type,
  priority,
  target_audience,
  is_active,
  show_until,
  action_url,
  action_label,
  created_at,
  updated_at
) VALUES (
  'Ciri Baru: Dokumen Resepi',
  'Kini anda boleh menyimpan dan menguruskan semua dokumen resepi anda di satu tempat! Simpan fail PDF, gambar, atau paste teks resepi dari mana-mana sumber. Susun mengikut kategori, tandakan sebagai kegemaran, dan cari dengan mudah. Semua dokumen anda adalah peribadi dan selamat.',
  'feature',
  'high',
  'all',
  true,
  NULL, -- Show indefinitely until manually disabled
  'app://recipe-documents',
  'Buka Dokumen Resepi',
  NOW(),
  NOW()
);
