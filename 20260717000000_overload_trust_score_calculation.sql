-- Overload calculate_user_trust_score to accept parameters directly for BEFORE UPDATE triggers
CREATE OR REPLACE FUNCTION calculate_user_trust_score(
  profile_id UUID,
  p_phone TEXT,
  p_kyc_status TEXT,
  p_selfie_url TEXT
)
RETURNS INTEGER AS $$
DECLARE
  score INTEGER := 0;
  email_confirmed BOOLEAN := FALSE;
  phone_confirmed BOOLEAN := FALSE;
  rentals_count INTEGER := 0;
  avg_rating NUMERIC := 0.0;
  reviews_count INTEGER := 0;
BEGIN
  -- A. Email verified (+10)
  SELECT (email_confirmed_at IS NOT NULL) INTO email_confirmed
  FROM auth.users WHERE id = profile_id;
  IF email_confirmed THEN
    score := score + 10;
  END IF;

  -- B. Phone verified (+20)
  SELECT (phone_confirmed_at IS NOT NULL OR phone IS NOT NULL) INTO phone_confirmed
  FROM auth.users WHERE id = profile_id;
  IF NOT phone_confirmed THEN
    phone_confirmed := (p_phone IS NOT NULL AND p_phone <> '');
  END IF;
  IF phone_confirmed THEN
    score := score + 20;
  END IF;

  -- C. Government ID approved (+30)
  IF p_kyc_status = 'approved' THEN
    score := score + 30;
  END IF;

  -- D. Face Verification (+15)
  IF p_kyc_status = 'approved' AND p_selfie_url IS NOT NULL AND p_selfie_url <> '' THEN
    score := score + 15;
  END IF;

  -- E. Completed rentals (+15)
  SELECT COUNT(*) INTO rentals_count
  FROM public.bookings
  WHERE (renter_id = profile_id OR owner_id = profile_id)
    AND status = 'completed';
  IF rentals_count > 0 THEN
    score := score + 15;
  END IF;

  -- F. Positive reviews (+10)
  SELECT COALESCE(AVG(rating), 0), COUNT(*) INTO avg_rating, reviews_count
  FROM public.reviews
  WHERE reviewee_id = profile_id;
  IF reviews_count > 0 AND avg_rating >= 4.0 THEN
    score := score + 10;
  END IF;

  RETURN LEAST(score, 100);
END;
$$ LANGUAGE plpgsql SECURITY DEFINER;

-- Re-implement 1-parameter version to call the overloaded version
CREATE OR REPLACE FUNCTION calculate_user_trust_score(profile_id UUID)
RETURNS INTEGER AS $$
DECLARE
  p_phone TEXT;
  p_kyc_status TEXT;
  p_selfie_url TEXT;
BEGIN
  SELECT phone, kyc_status, kyc_selfie_url INTO p_phone, p_kyc_status, p_selfie_url
  FROM public.profiles WHERE id = profile_id;

  RETURN calculate_user_trust_score(profile_id, p_phone, p_kyc_status, p_selfie_url);
END;
$$ LANGUAGE plpgsql SECURITY DEFINER;

-- Update profiles trigger to use the new overloaded function
CREATE OR REPLACE FUNCTION update_profile_trust_score()
RETURNS TRIGGER AS $$
BEGIN
  NEW.trust_score := calculate_user_trust_score(NEW.id, NEW.phone, NEW.kyc_status, NEW.kyc_selfie_url);
  RETURN NEW;
END;
$$ LANGUAGE plpgsql SECURITY DEFINER;
