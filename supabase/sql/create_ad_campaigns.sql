-- ============================================
-- AD CAMPAIGNS TABLE + STORAGE
-- Kör hela detta script i Supabase SQL Editor
-- ============================================

-- 1. Skapa tabellen
CREATE TABLE IF NOT EXISTS public.ad_campaigns (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  user_id UUID NOT NULL REFERENCES auth.users(id) ON DELETE CASCADE,
  format TEXT NOT NULL CHECK (format IN ('feed', 'banner', 'popup')),
  status TEXT NOT NULL DEFAULT 'active' CHECK (status IN ('active', 'paused', 'ended')),
  title TEXT NOT NULL,
  description TEXT,
  image_url TEXT,
  profile_image_url TEXT,
  cta_text TEXT DEFAULT 'Läs mer',
  cta_url TEXT NOT NULL,
  start_date TIMESTAMPTZ DEFAULT now(),
  end_date TIMESTAMPTZ,
  views_count INTEGER DEFAULT 0,
  clicks_count INTEGER DEFAULT 0,
  daily_bid NUMERIC(10,2) NOT NULL DEFAULT 0,
  created_at TIMESTAMPTZ DEFAULT now()
);

-- 2. Aktivera RLS
ALTER TABLE public.ad_campaigns ENABLE ROW LEVEL SECURITY;

-- 3. RLS policies
DROP POLICY IF EXISTS "Users can create own campaigns" ON public.ad_campaigns;
DROP POLICY IF EXISTS "Anyone can read campaigns" ON public.ad_campaigns;
DROP POLICY IF EXISTS "Users can update own campaigns" ON public.ad_campaigns;
DROP POLICY IF EXISTS "Users can delete own campaigns" ON public.ad_campaigns;

CREATE POLICY "Users can create own campaigns"
  ON public.ad_campaigns FOR INSERT
  WITH CHECK (auth.uid() = user_id);

CREATE POLICY "Anyone can read campaigns"
  ON public.ad_campaigns FOR SELECT
  USING (true);

CREATE POLICY "Users can update own campaigns"
  ON public.ad_campaigns FOR UPDATE
  USING (auth.uid() = user_id);

CREATE POLICY "Users can delete own campaigns"
  ON public.ad_campaigns FOR DELETE
  USING (auth.uid() = user_id);

-- 4. Storage bucket för annonsbilder
INSERT INTO storage.buckets (id, name, public)
VALUES ('ad-assets', 'ad-assets', true)
ON CONFLICT (id) DO NOTHING;

DROP POLICY IF EXISTS "Anyone can read ad assets" ON storage.objects;
DROP POLICY IF EXISTS "Authenticated users can upload ad assets" ON storage.objects;
DROP POLICY IF EXISTS "Users can update own ad assets" ON storage.objects;
DROP POLICY IF EXISTS "Users can delete own ad assets" ON storage.objects;

CREATE POLICY "Anyone can read ad assets"
  ON storage.objects FOR SELECT
  USING (bucket_id = 'ad-assets');

CREATE POLICY "Authenticated users can upload ad assets"
  ON storage.objects FOR INSERT
  WITH CHECK (bucket_id = 'ad-assets' AND auth.role() = 'authenticated');

CREATE POLICY "Users can update own ad assets"
  ON storage.objects FOR UPDATE
  USING (bucket_id = 'ad-assets' AND auth.uid()::text = (storage.foldername(name))[1]);

CREATE POLICY "Users can delete own ad assets"
  ON storage.objects FOR DELETE
  USING (bucket_id = 'ad-assets' AND auth.uid()::text = (storage.foldername(name))[1]);

-- 5. Index för snabba queries från iOS-appen
CREATE INDEX IF NOT EXISTS idx_ad_campaigns_active
  ON public.ad_campaigns (format, status, start_date, end_date)
  WHERE status = 'active';

-- 6. RPC för att öka views_count (anropas av edge function)
CREATE OR REPLACE FUNCTION public.increment_ad_views(campaign_ids UUID[])
RETURNS void AS $$
BEGIN
  UPDATE public.ad_campaigns
  SET views_count = views_count + 1
  WHERE id = ANY(campaign_ids);
END;
$$ LANGUAGE plpgsql SECURITY DEFINER;

-- 7. RPC för att öka clicks_count (anropas av edge function)
CREATE OR REPLACE FUNCTION public.increment_ad_click(campaign_id UUID)
RETURNS void AS $$
BEGIN
  UPDATE public.ad_campaigns
  SET clicks_count = clicks_count + 1
  WHERE id = campaign_id;
END;
$$ LANGUAGE plpgsql SECURITY DEFINER;
