-- Update existing app_config table with missing columns
-- Run this in Supabase SQL Editor

-- Add missing columns if they don't exist
ALTER TABLE public.app_config 
ADD COLUMN IF NOT EXISTS min_version TEXT NOT NULL DEFAULT '1.0';

ALTER TABLE public.app_config 
ADD COLUMN IF NOT EXISTS recommended_version TEXT;

ALTER TABLE public.app_config 
ADD COLUMN IF NOT EXISTS update_message_sv TEXT DEFAULT 'En ny version av appen finns tillgänglig. Vänligen uppdatera för att fortsätta använda appen.';

ALTER TABLE public.app_config 
ADD COLUMN IF NOT EXISTS update_message_en TEXT DEFAULT 'A new version of the app is available. Please update to continue using the app.';

ALTER TABLE public.app_config 
ADD COLUMN IF NOT EXISTS force_update BOOLEAN DEFAULT false;

ALTER TABLE public.app_config 
ADD COLUMN IF NOT EXISTS app_store_url TEXT DEFAULT 'https://apps.apple.com/app/id6744919845';

ALTER TABLE public.app_config 
ADD COLUMN IF NOT EXISTS updated_at TIMESTAMPTZ DEFAULT NOW();

-- Update the existing row with defaults
UPDATE public.app_config 
SET 
    min_version = COALESCE(min_version, '1.0'),
    force_update = COALESCE(force_update, false),
    update_message_sv = COALESCE(update_message_sv, 'En ny version av appen finns tillgänglig.'),
    app_store_url = COALESCE(app_store_url, 'https://apps.apple.com/app/id6744919845')
WHERE id = 1;

-- If no row exists, insert one
INSERT INTO public.app_config (id, min_version, force_update)
VALUES (1, '1.0', false)
ON CONFLICT (id) DO NOTHING;

-- Enable RLS if not already
ALTER TABLE public.app_config ENABLE ROW LEVEL SECURITY;

-- Drop and recreate policies
DROP POLICY IF EXISTS "Anyone can read app config" ON public.app_config;
CREATE POLICY "Anyone can read app config" ON public.app_config
    FOR SELECT USING (true);

-- Grant access
GRANT SELECT ON public.app_config TO anon;
GRANT SELECT ON public.app_config TO authenticated;




