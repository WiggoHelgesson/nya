-- App Configuration Table for Force Updates
-- Run this in Supabase SQL Editor

CREATE TABLE IF NOT EXISTS public.app_config (
    id INT PRIMARY KEY DEFAULT 1,
    min_version TEXT NOT NULL DEFAULT '1.0',
    recommended_version TEXT,
    update_message_sv TEXT DEFAULT 'En ny version av appen finns tillgänglig. Vänligen uppdatera för att fortsätta använda appen.',
    update_message_en TEXT DEFAULT 'A new version of the app is available. Please update to continue using the app.',
    force_update BOOLEAN DEFAULT false,
    app_store_url TEXT DEFAULT 'https://apps.apple.com/app/id6744919845',
    created_at TIMESTAMPTZ DEFAULT NOW(),
    updated_at TIMESTAMPTZ DEFAULT NOW(),
    
    -- Ensure only one row exists
    CONSTRAINT single_row CHECK (id = 1)
);

-- Insert default config
INSERT INTO public.app_config (id, min_version, force_update)
VALUES (1, '1.0', false)
ON CONFLICT (id) DO NOTHING;

-- Enable RLS
ALTER TABLE public.app_config ENABLE ROW LEVEL SECURITY;

-- Allow anyone to read (needed for version check before login)
CREATE POLICY "Anyone can read app config" ON public.app_config
    FOR SELECT USING (true);

-- Only service role can update (done via Supabase dashboard)
CREATE POLICY "Service role can update app config" ON public.app_config
    FOR UPDATE USING (auth.role() = 'service_role');

-- Grant read access to anon and authenticated
GRANT SELECT ON public.app_config TO anon;
GRANT SELECT ON public.app_config TO authenticated;

-- Function to update timestamp
CREATE OR REPLACE FUNCTION update_app_config_timestamp()
RETURNS TRIGGER AS $$
BEGIN
    NEW.updated_at = NOW();
    RETURN NEW;
END;
$$ LANGUAGE plpgsql;

-- Trigger for auto-updating timestamp
DROP TRIGGER IF EXISTS app_config_updated_at ON public.app_config;
CREATE TRIGGER app_config_updated_at
    BEFORE UPDATE ON public.app_config
    FOR EACH ROW
    EXECUTE FUNCTION update_app_config_timestamp();




