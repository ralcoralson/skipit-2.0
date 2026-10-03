-- Migration: Overhaul reviews, ratings, and dynamic trust scores

-- 1. Reset profiles default rating and add total_reviews
ALTER TABLE public.profiles ALTER COLUMN rating SET DEFAULT NULL;
ALTER TABLE public.profiles ADD COLUMN IF NOT EXISTS total_reviews INTEGER DEFAULT 0;

-- 2. Drop unique constraint on reviews.booking_id and replace with composite unique
ALTER TABLE public.reviews DROP CONSTRAINT IF EXISTS reviews_booking_id_key;
ALTER TABLE public.reviews ADD CONSTRAINT reviews_booking_id_reviewer_id_key UNIQUE (booking_id, reviewer_id);

-- 3. Dynamic Trust Score Calculation Engine
CREATE OR REPLACE FUNCTION calculate_user_trust_score(profile_id UUID)
RETURNS INTEGER AS $$
DECLARE
  score INTEGER := 0;
  email_confirmed BOOLEAN := FALSE;
  phone_confirmed BOOLEAN := FALSE;
  kyc_status_val TEXT;
  selfie_url TEXT;
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
    SELECT (phone IS NOT NULL) INTO phone_confirmed
    FROM public.profiles WHERE id = profile_id;
  END IF;
  IF phone_confirmed THEN
    score := score + 20;
  END IF;

  -- Get profile fields
  SELECT kyc_status, kyc_selfie_url INTO kyc_status_val, selfie_url
  FROM public.profiles WHERE id = profile_id;

  -- C. Government ID approved (+30)
  IF kyc_status_val = 'approved' THEN
    score := score + 30;
  END IF;

  -- D. Face Verification (+15)
  IF kyc_status_val = 'approved' AND selfie_url IS NOT NULL THEN
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

-- 4. Trigger to update profile stats and trust score when reviews change
CREATE OR REPLACE FUNCTION update_profile_stats_on_review()
RETURNS TRIGGER AS $$
DECLARE
  target_user_id UUID;
BEGIN
  IF TG_OP = 'DELETE' THEN
    target_user_id := OLD.reviewee_id;
  ELSE
    target_user_id := NEW.reviewee_id;
  END IF;

  -- Update rating and total_reviews
  UPDATE public.profiles
  SET 
    rating = (
      SELECT COALESCE(ROUND(AVG(rating)::numeric, 1), NULL) 
      FROM public.reviews 
      WHERE reviewee_id = target_user_id
    ),
    total_reviews = (
      SELECT COUNT(*) 
      FROM public.reviews 
      WHERE reviewee_id = target_user_id
    )
  WHERE id = target_user_id;

  -- Update trust score
  UPDATE public.profiles
  SET trust_score = calculate_user_trust_score(target_user_id)
  WHERE id = target_user_id;

  RETURN NULL;
END;
$$ LANGUAGE plpgsql SECURITY DEFINER;

DROP TRIGGER IF EXISTS trigger_update_profile_stats_on_review ON public.reviews;
CREATE TRIGGER trigger_update_profile_stats_on_review
  AFTER INSERT OR UPDATE OR DELETE ON public.reviews
  FOR EACH ROW
  EXECUTE FUNCTION update_profile_stats_on_review();

-- 5. Trigger to update profile stats and trust score when bookings complete
CREATE OR REPLACE FUNCTION update_profile_stats_on_booking()
RETURNS TRIGGER AS $$
BEGIN
  -- Update total_rentals for renter
  UPDATE public.profiles
  SET 
    total_rentals = (
      SELECT COUNT(*) 
      FROM public.bookings 
      WHERE renter_id = NEW.renter_id AND status = 'completed'
    ),
    trust_score = calculate_user_trust_score(NEW.renter_id)
  WHERE id = NEW.renter_id;

  -- Update total_rentals for owner
  UPDATE public.profiles
  SET 
    total_rentals = (
      SELECT COUNT(*) 
      FROM public.bookings 
      WHERE owner_id = NEW.owner_id AND status = 'completed'
    ),
    trust_score = calculate_user_trust_score(NEW.owner_id)
  WHERE id = NEW.owner_id;

  RETURN NULL;
END;
$$ LANGUAGE plpgsql SECURITY DEFINER;

DROP TRIGGER IF EXISTS trigger_update_profile_stats_on_booking ON public.bookings;
CREATE TRIGGER trigger_update_profile_stats_on_booking
  AFTER UPDATE OF status ON public.bookings
  FOR EACH ROW
  WHEN (NEW.status = 'completed')
  EXECUTE FUNCTION update_profile_stats_on_booking();

-- 6. Trigger to update trust score when profiles are changed
CREATE OR REPLACE FUNCTION update_profile_trust_score()
RETURNS TRIGGER AS $$
BEGIN
  NEW.trust_score := calculate_user_trust_score(NEW.id);
  RETURN NEW;
END;
$$ LANGUAGE plpgsql SECURITY DEFINER;

DROP TRIGGER IF EXISTS trigger_update_profile_trust_score ON public.profiles;
CREATE TRIGGER trigger_update_profile_trust_score
  BEFORE UPDATE OF phone, kyc_status, kyc_selfie_url ON public.profiles
  FOR EACH ROW
  EXECUTE FUNCTION update_profile_trust_score();
