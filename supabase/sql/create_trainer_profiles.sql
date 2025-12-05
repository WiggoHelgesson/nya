-- Drop dependent function first
DROP FUNCTION IF EXISTS public.create_trainer_profile(text,text,text,double precision,double precision,double precision,text) CASCADE;

-- Drop existing policies if they exist
DROP POLICY IF EXISTS trainer_profiles_select ON public.trainer_profiles;
DROP POLICY IF EXISTS trainer_profiles_insert ON public.trainer_profiles;
DROP POLICY IF EXISTS trainer_profiles_update ON public.trainer_profiles;
DROP POLICY IF EXISTS trainer_profiles_delete ON public.trainer_profiles;

-- Drop existing view if it exists
DROP VIEW IF EXISTS public.trainer_profiles_with_user CASCADE;

-- Drop trainer_bookings table if it depends on trainer_profiles
DROP TABLE IF EXISTS public.trainer_bookings CASCADE;

-- Drop existing table with CASCADE to remove all dependencies
DROP TABLE IF EXISTS public.trainer_profiles CASCADE;

-- Create trainer_profiles table for golf trainers
CREATE TABLE public.trainer_profiles (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    user_id UUID NOT NULL REFERENCES auth.users(id) ON DELETE CASCADE,
    name TEXT NOT NULL,
    description TEXT NOT NULL,
    hourly_rate INTEGER NOT NULL CHECK (hourly_rate > 0),
    handicap INTEGER NOT NULL CHECK (handicap >= 0 AND handicap <= 54),
    latitude DOUBLE PRECISION NOT NULL,
    longitude DOUBLE PRECISION NOT NULL,
    avatar_url TEXT,
    is_active BOOLEAN NOT NULL DEFAULT true,
    created_at TIMESTAMPTZ NOT NULL DEFAULT now(),
    updated_at TIMESTAMPTZ NOT NULL DEFAULT now(),
    
    -- Ensure one profile per user
    CONSTRAINT trainer_profiles_user_unique UNIQUE (user_id)
);

-- Create indexes for efficient queries
CREATE INDEX trainer_profiles_user_id_idx ON public.trainer_profiles(user_id);
CREATE INDEX trainer_profiles_is_active_idx ON public.trainer_profiles(is_active);
CREATE INDEX trainer_profiles_location_idx ON public.trainer_profiles(latitude, longitude);

-- Updated_at trigger
CREATE OR REPLACE FUNCTION public.set_trainer_updated_at()
RETURNS TRIGGER
LANGUAGE plpgsql
AS $$
BEGIN
    NEW.updated_at := now();
    RETURN NEW;
END;
$$;

DROP TRIGGER IF EXISTS trg_trainer_profiles_updated ON public.trainer_profiles;
CREATE TRIGGER trg_trainer_profiles_updated
BEFORE UPDATE ON public.trainer_profiles
FOR EACH ROW
EXECUTE PROCEDURE public.set_trainer_updated_at();

-- Enable Row Level Security
ALTER TABLE public.trainer_profiles ENABLE ROW LEVEL SECURITY;

-- RLS Policies

-- Everyone can view active trainer profiles
CREATE POLICY trainer_profiles_select ON public.trainer_profiles
    FOR SELECT
    USING (is_active = true OR auth.uid() = user_id);

-- Users can insert their own trainer profile
CREATE POLICY trainer_profiles_insert ON public.trainer_profiles
    FOR INSERT
    WITH CHECK (auth.uid() = user_id);

-- Users can update their own trainer profile
CREATE POLICY trainer_profiles_update ON public.trainer_profiles
    FOR UPDATE
    USING (auth.uid() = user_id)
    WITH CHECK (auth.uid() = user_id);

-- Users can delete their own trainer profile
CREATE POLICY trainer_profiles_delete ON public.trainer_profiles
    FOR DELETE
    USING (auth.uid() = user_id);

-- Grant access to authenticated users
GRANT SELECT, INSERT, UPDATE, DELETE ON public.trainer_profiles TO authenticated;

-- Optional: Create a view for easier querying with user info
CREATE OR REPLACE VIEW public.trainer_profiles_with_user AS
SELECT 
    tp.*,
    p.username,
    COALESCE(tp.avatar_url, p.avatar_url) as profile_avatar_url
FROM public.trainer_profiles tp
LEFT JOIN public.profiles p ON tp.user_id = p.id
WHERE tp.is_active = true;

GRANT SELECT ON public.trainer_profiles_with_user TO authenticated;
