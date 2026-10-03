-- Migration: Secure KYC documents storage bucket via storage.objects RLS
-- Date: 2026-07-16

-- Enable RLS on storage.objects if not already enabled
ALTER TABLE storage.objects ENABLE ROW LEVEL SECURITY;

-- Drop policy if it exists to ensure idempotency
DROP POLICY IF EXISTS "Allow owner and admin select KYC documents" ON storage.objects;

-- Create restrictive SELECT policy for kyc-documents bucket
CREATE POLICY "Allow owner and admin select KYC documents" ON storage.objects
  FOR SELECT
  TO authenticated
  USING (
    bucket_id = 'kyc-documents' AND (
      owner::text = auth.uid()::text OR
      (storage.foldername(name))[1] = auth.uid()::text OR
      EXISTS (
        SELECT 1 FROM public.profiles
        WHERE id = auth.uid() AND role = 'admin'
      )
    )
  );
