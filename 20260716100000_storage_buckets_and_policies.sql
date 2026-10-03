-- Migration: Create storage buckets and full RLS for kyc-documents and listing-images
-- Date: 2026-07-16

-- ============================================================
-- 1. Create buckets (safe: skipped if already exists)
-- ============================================================
INSERT INTO storage.buckets (id, name, public, file_size_limit, allowed_mime_types)
VALUES 
  ('kyc-documents', 'kyc-documents', false, 5242880, ARRAY['image/jpeg', 'image/png', 'image/webp'])
ON CONFLICT (id) DO UPDATE SET
  public = false,
  file_size_limit = 5242880,
  allowed_mime_types = ARRAY['image/jpeg', 'image/png', 'image/webp'];

INSERT INTO storage.buckets (id, name, public, file_size_limit, allowed_mime_types)
VALUES 
  ('listing-images', 'listing-images', true, 10485760, ARRAY['image/jpeg', 'image/png', 'image/webp'])
ON CONFLICT (id) DO UPDATE SET
  public = true,
  file_size_limit = 10485760,
  allowed_mime_types = ARRAY['image/jpeg', 'image/png', 'image/webp'];

-- ============================================================
-- 2. Enable RLS on storage.objects
-- ============================================================
ALTER TABLE storage.objects ENABLE ROW LEVEL SECURITY;

-- ============================================================
-- 3. KYC Documents bucket policies (PRIVATE)
-- Users can upload only to their own folder, admins can read all
-- ============================================================
DROP POLICY IF EXISTS "kyc_insert_own" ON storage.objects;
DROP POLICY IF EXISTS "kyc_select_own_or_admin" ON storage.objects;
DROP POLICY IF EXISTS "kyc_update_own" ON storage.objects;
DROP POLICY IF EXISTS "kyc_delete_own" ON storage.objects;
DROP POLICY IF EXISTS "Allow owner and admin select KYC documents" ON storage.objects;

-- INSERT: authenticated users can upload to their own userId/ folder
CREATE POLICY "kyc_insert_own" ON storage.objects
  FOR INSERT
  TO authenticated
  WITH CHECK (
    bucket_id = 'kyc-documents'
    AND (storage.foldername(name))[1] = auth.uid()::text
  );

-- SELECT: owner can see their own files; admins can see all
CREATE POLICY "kyc_select_own_or_admin" ON storage.objects
  FOR SELECT
  TO authenticated
  USING (
    bucket_id = 'kyc-documents' AND (
      (storage.foldername(name))[1] = auth.uid()::text
      OR EXISTS (
        SELECT 1 FROM public.profiles
        WHERE id = auth.uid() AND role = 'admin'
      )
    )
  );

-- UPDATE: owner can replace their own files (upsert)
CREATE POLICY "kyc_update_own" ON storage.objects
  FOR UPDATE
  TO authenticated
  USING (
    bucket_id = 'kyc-documents'
    AND (storage.foldername(name))[1] = auth.uid()::text
  )
  WITH CHECK (
    bucket_id = 'kyc-documents'
    AND (storage.foldername(name))[1] = auth.uid()::text
  );

-- DELETE: owner can delete their own files
CREATE POLICY "kyc_delete_own" ON storage.objects
  FOR DELETE
  TO authenticated
  USING (
    bucket_id = 'kyc-documents'
    AND (storage.foldername(name))[1] = auth.uid()::text
  );

-- ============================================================
-- 4. Listing Images bucket policies (PUBLIC bucket)
-- Authenticated users can upload; anyone can read (public)
-- ============================================================
DROP POLICY IF EXISTS "listing_images_insert" ON storage.objects;
DROP POLICY IF EXISTS "listing_images_select_public" ON storage.objects;
DROP POLICY IF EXISTS "listing_images_update_own" ON storage.objects;
DROP POLICY IF EXISTS "listing_images_delete_own" ON storage.objects;

CREATE POLICY "listing_images_insert" ON storage.objects
  FOR INSERT
  TO authenticated
  WITH CHECK (bucket_id = 'listing-images');

CREATE POLICY "listing_images_select_public" ON storage.objects
  FOR SELECT
  TO public
  USING (bucket_id = 'listing-images');

CREATE POLICY "listing_images_update_own" ON storage.objects
  FOR UPDATE
  TO authenticated
  USING (bucket_id = 'listing-images' AND owner::text = auth.uid()::text)
  WITH CHECK (bucket_id = 'listing-images');

CREATE POLICY "listing_images_delete_own" ON storage.objects
  FOR DELETE
  TO authenticated
  USING (bucket_id = 'listing-images' AND owner::text = auth.uid()::text);
