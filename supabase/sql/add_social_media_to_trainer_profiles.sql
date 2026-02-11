-- Add social media and contact columns to trainer_profiles
ALTER TABLE public.trainer_profiles
ADD COLUMN IF NOT EXISTS instagram_url TEXT,
ADD COLUMN IF NOT EXISTS facebook_url TEXT,
ADD COLUMN IF NOT EXISTS website_url TEXT,
ADD COLUMN IF NOT EXISTS phone_number TEXT,
ADD COLUMN IF NOT EXISTS contact_email TEXT;

COMMENT ON COLUMN public.trainer_profiles.instagram_url IS 'Instagram profile URL';
COMMENT ON COLUMN public.trainer_profiles.facebook_url IS 'Facebook profile URL';
COMMENT ON COLUMN public.trainer_profiles.website_url IS 'Personal website URL';
COMMENT ON COLUMN public.trainer_profiles.phone_number IS 'Contact phone number';
COMMENT ON COLUMN public.trainer_profiles.contact_email IS 'Contact email address';
