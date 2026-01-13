-- Migration: Add Recipe Documents System
-- Date: 2025-01-16
-- Description: Add tables for recipe documents library with file and text support

-- ============================================
-- TABLE: recipe_document_categories
-- ============================================
-- Custom categories that users can create themselves
CREATE TABLE IF NOT EXISTS recipe_document_categories (
    id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
    business_owner_id UUID NOT NULL REFERENCES users(id) ON DELETE CASCADE,
    name TEXT NOT NULL,
    icon TEXT, -- emoji or icon name (optional)
    color TEXT, -- hex color (optional, e.g., #FF5733)
    sort_order INTEGER DEFAULT 0,
    created_at TIMESTAMPTZ NOT NULL DEFAULT NOW(),
    updated_at TIMESTAMPTZ NOT NULL DEFAULT NOW(),
    
    -- Ensure unique category name per user
    CONSTRAINT unique_category_per_user UNIQUE(business_owner_id, name)
);

-- Indexes for recipe_document_categories
CREATE INDEX IF NOT EXISTS idx_recipe_doc_categories_owner 
    ON recipe_document_categories(business_owner_id);
CREATE INDEX IF NOT EXISTS idx_recipe_doc_categories_sort 
    ON recipe_document_categories(business_owner_id, sort_order);

-- RLS Policies for recipe_document_categories
ALTER TABLE recipe_document_categories ENABLE ROW LEVEL SECURITY;

-- Drop existing policies if they exist (to allow re-running migration)
DROP POLICY IF EXISTS "recipe_doc_categories_select_own" ON recipe_document_categories;
DROP POLICY IF EXISTS "recipe_doc_categories_insert_own" ON recipe_document_categories;
DROP POLICY IF EXISTS "recipe_doc_categories_update_own" ON recipe_document_categories;
DROP POLICY IF EXISTS "recipe_doc_categories_delete_own" ON recipe_document_categories;

CREATE POLICY "recipe_doc_categories_select_own" 
    ON recipe_document_categories
    FOR SELECT 
    USING (business_owner_id = auth.uid());

CREATE POLICY "recipe_doc_categories_insert_own" 
    ON recipe_document_categories
    FOR INSERT 
    WITH CHECK (business_owner_id = auth.uid());

CREATE POLICY "recipe_doc_categories_update_own" 
    ON recipe_document_categories
    FOR UPDATE 
    USING (business_owner_id = auth.uid());

CREATE POLICY "recipe_doc_categories_delete_own" 
    ON recipe_document_categories
    FOR DELETE 
    USING (business_owner_id = auth.uid());

-- ============================================
-- TABLE: recipe_documents
-- ============================================
-- Main table for storing recipe documents (files or text)
CREATE TABLE IF NOT EXISTS recipe_documents (
    id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
    business_owner_id UUID NOT NULL REFERENCES users(id) ON DELETE CASCADE,
    
    -- Basic Info
    title TEXT NOT NULL,
    description TEXT,
    category_id UUID REFERENCES recipe_document_categories(id) ON DELETE SET NULL,
    
    -- Content Type: 'file' or 'text'
    content_type TEXT NOT NULL CHECK (content_type IN ('file', 'text')),
    
    -- File Info (if content_type = 'file')
    file_name TEXT,
    file_path TEXT, -- Supabase Storage path
    file_type TEXT, -- pdf, jpg, jpeg, png
    file_size BIGINT, -- bytes
    
    -- Text Content (if content_type = 'text')
    text_content TEXT, -- Full recipe text from copy-paste
    
    -- Organization
    tags TEXT[], -- Array of tags (e.g., ['vegetarian', 'mudah', 'halal'])
    is_favourite BOOLEAN DEFAULT false,
    
    -- Integration (Optional)
    linked_recipe_id UUID REFERENCES recipes(id) ON DELETE SET NULL, -- Optional link to existing recipe
    
    -- Metadata
    uploaded_at TIMESTAMPTZ NOT NULL DEFAULT NOW(),
    last_viewed_at TIMESTAMPTZ,
    view_count INTEGER DEFAULT 0,
    source TEXT, -- e.g., "Facebook Group PJJ", "Website", "WhatsApp", etc
    
    created_at TIMESTAMPTZ NOT NULL DEFAULT NOW(),
    updated_at TIMESTAMPTZ NOT NULL DEFAULT NOW(),
    
    -- Constraints
    CONSTRAINT file_fields_required_when_file 
        CHECK (
            (content_type = 'file' AND file_name IS NOT NULL AND file_path IS NOT NULL) OR
            (content_type = 'text')
        ),
    CONSTRAINT text_content_required_when_text 
        CHECK (
            (content_type = 'text' AND text_content IS NOT NULL) OR
            (content_type = 'file')
        )
);

-- Indexes for recipe_documents
CREATE INDEX IF NOT EXISTS idx_recipe_documents_owner 
    ON recipe_documents(business_owner_id);
CREATE INDEX IF NOT EXISTS idx_recipe_documents_category 
    ON recipe_documents(category_id);
CREATE INDEX IF NOT EXISTS idx_recipe_documents_favourite 
    ON recipe_documents(business_owner_id, is_favourite) 
    WHERE is_favourite = true;
CREATE INDEX IF NOT EXISTS idx_recipe_documents_type 
    ON recipe_documents(business_owner_id, content_type);
CREATE INDEX IF NOT EXISTS idx_recipe_documents_uploaded 
    ON recipe_documents(business_owner_id, uploaded_at DESC);
CREATE INDEX IF NOT EXISTS idx_recipe_documents_title 
    ON recipe_documents(business_owner_id, title);

-- Full text search index for text_content and title
CREATE INDEX IF NOT EXISTS idx_recipe_documents_search 
    ON recipe_documents 
    USING gin(to_tsvector('english', coalesce(title, '') || ' ' || coalesce(text_content, '')));

-- RLS Policies for recipe_documents
ALTER TABLE recipe_documents ENABLE ROW LEVEL SECURITY;

-- Drop existing policies if they exist (to allow re-running migration)
DROP POLICY IF EXISTS "recipe_documents_select_own" ON recipe_documents;
DROP POLICY IF EXISTS "recipe_documents_insert_own" ON recipe_documents;
DROP POLICY IF EXISTS "recipe_documents_update_own" ON recipe_documents;
DROP POLICY IF EXISTS "recipe_documents_delete_own" ON recipe_documents;

CREATE POLICY "recipe_documents_select_own" 
    ON recipe_documents
    FOR SELECT 
    USING (business_owner_id = auth.uid());

CREATE POLICY "recipe_documents_insert_own" 
    ON recipe_documents
    FOR INSERT 
    WITH CHECK (business_owner_id = auth.uid());

CREATE POLICY "recipe_documents_update_own" 
    ON recipe_documents
    FOR UPDATE 
    USING (business_owner_id = auth.uid());

CREATE POLICY "recipe_documents_delete_own" 
    ON recipe_documents
    FOR DELETE 
    USING (business_owner_id = auth.uid());

-- ============================================
-- FUNCTION: Update updated_at timestamp
-- ============================================
CREATE OR REPLACE FUNCTION update_recipe_document_updated_at()
RETURNS TRIGGER AS $$
BEGIN
    NEW.updated_at = NOW();
    RETURN NEW;
END;
$$ LANGUAGE plpgsql;

-- Drop existing triggers if they exist (to allow re-running migration)
DROP TRIGGER IF EXISTS update_recipe_documents_updated_at ON recipe_documents;
DROP TRIGGER IF EXISTS update_recipe_doc_categories_updated_at ON recipe_document_categories;

-- Trigger for recipe_documents
CREATE TRIGGER update_recipe_documents_updated_at
    BEFORE UPDATE ON recipe_documents
    FOR EACH ROW
    EXECUTE FUNCTION update_recipe_document_updated_at();

-- Trigger for recipe_document_categories
CREATE TRIGGER update_recipe_doc_categories_updated_at
    BEFORE UPDATE ON recipe_document_categories
    FOR EACH ROW
    EXECUTE FUNCTION update_recipe_document_updated_at();

-- ============================================
-- FUNCTION: Update last_viewed_at and view_count
-- ============================================
CREATE OR REPLACE FUNCTION update_recipe_document_view_stats()
RETURNS TRIGGER AS $$
BEGIN
    NEW.last_viewed_at = NOW();
    NEW.view_count = COALESCE(OLD.view_count, 0) + 1;
    RETURN NEW;
END;
$$ LANGUAGE plpgsql;

-- Note: This trigger would be called manually from the app
-- when viewing a document, not automatically

-- ============================================
-- STORAGE POLICIES (Supabase Storage)
-- ============================================
-- Note: These policies are for the 'recipe-documents' bucket
-- Make sure to create the bucket first in Supabase Dashboard:
-- 1. Go to Storage > Create bucket
-- 2. Name: recipe-documents
-- 3. Public: false (private)
-- 4. File size limit: 10MB
-- 5. Allowed MIME types: application/pdf, image/jpeg, image/png

-- Drop existing policies if they exist (to allow re-running migration)
DROP POLICY IF EXISTS "recipe_documents_upload_own" ON storage.objects;
DROP POLICY IF EXISTS "recipe_documents_view_own" ON storage.objects;
DROP POLICY IF EXISTS "recipe_documents_delete_own" ON storage.objects;
DROP POLICY IF EXISTS "recipe_documents_update_own" ON storage.objects;

-- Allow users to upload their own files
CREATE POLICY "recipe_documents_upload_own"
ON storage.objects FOR INSERT
WITH CHECK (
  bucket_id = 'recipe-documents' AND
  (storage.foldername(name))[1] = auth.uid()::text
);

-- Allow users to view their own files
CREATE POLICY "recipe_documents_view_own"
ON storage.objects FOR SELECT
USING (
  bucket_id = 'recipe-documents' AND
  (storage.foldername(name))[1] = auth.uid()::text
);

-- Allow users to delete their own files
CREATE POLICY "recipe_documents_delete_own"
ON storage.objects FOR DELETE
USING (
  bucket_id = 'recipe-documents' AND
  (storage.foldername(name))[1] = auth.uid()::text
);

-- Allow users to update their own files (optional, for future use)
CREATE POLICY "recipe_documents_update_own"
ON storage.objects FOR UPDATE
USING (
  bucket_id = 'recipe-documents' AND
  (storage.foldername(name))[1] = auth.uid()::text
)
WITH CHECK (
  bucket_id = 'recipe-documents' AND
  (storage.foldername(name))[1] = auth.uid()::text
);

-- ============================================
-- COMMENTS
-- ============================================
COMMENT ON TABLE recipe_documents IS 'Stores recipe documents (files or text) for easy reference';
COMMENT ON TABLE recipe_document_categories IS 'Custom categories for organizing recipe documents';
COMMENT ON COLUMN recipe_documents.content_type IS 'Type of content: file (PDF/image) or text (copy-paste)';
COMMENT ON COLUMN recipe_documents.text_content IS 'Full recipe text when content_type is text';
COMMENT ON COLUMN recipe_documents.source IS 'Where the recipe came from (e.g., Facebook Group, WhatsApp)';
COMMENT ON COLUMN recipe_documents.linked_recipe_id IS 'Optional link to existing recipe in recipes table';
