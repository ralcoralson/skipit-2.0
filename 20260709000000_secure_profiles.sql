-- Migration: Secure Profiles Table & Create public view
-- Date: 2026-07-09

-- 1. Drop public viewable policy
DROP POLICY IF EXISTS "Public profiles are viewable by everyone" ON profiles;

-- 2. Add restrictive policy so a user can only select their own full profile row
CREATE POLICY "Users can select own profile" ON profiles
  FOR SELECT USING (auth.uid() = id);

-- 3. Create public view profiles_public that filters out PII/sensitive columns
ALTER TABLE profiles ADD COLUMN IF NOT EXISTS created_at TIMESTAMP WITH TIME ZONE DEFAULT NOW();

CREATE OR REPLACE VIEW profiles_public AS
SELECT 
  id, 
  full_name, 
  avatar_url, 
  rating, 
  is_verified, 
  bio, 
  location, 
  total_rentals, 
  total_listings, 
  created_at
FROM profiles;

-- 4. Grant read permissions on the public view to anon and authenticated roles
GRANT SELECT ON profiles_public TO anon, authenticated;
