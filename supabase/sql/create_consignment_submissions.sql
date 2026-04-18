-- Consignment (AI sell) submissions + storage
--
-- Defines public.is_admin() here so this file runs even if fix_admin_permissions.sql
-- was never applied. Same email list as SettingsView.swift / fix_admin_permissions.sql.

CREATE OR REPLACE FUNCTION public.is_admin()
RETURNS BOOLEAN AS $$
DECLARE
  current_email TEXT;
BEGIN
  current_email := lower(auth.jwt() ->> 'email');

  IF current_email = 'admin@updown.app'
     OR current_email = 'wiggohelgesson@gmail.com'
     OR current_email = 'info@wiggio.se'
     OR current_email = 'info@bylito.se' THEN
    RETURN TRUE;
  ELSE
    RETURN FALSE;
  END IF;
END;
$$ LANGUAGE plpgsql SECURITY DEFINER;

BEGIN;

CREATE TABLE IF NOT EXISTS public.consignment_submissions (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    user_id UUID NOT NULL REFERENCES auth.users (id) ON DELETE CASCADE,
    image_urls TEXT[] NOT NULL DEFAULT '{}',
    category TEXT NOT NULL,
    ai_payload JSONB NOT NULL DEFAULT '{}',
    user_brand TEXT,
    user_condition TEXT,
    admin_status TEXT NOT NULL DEFAULT 'pending' CHECK (admin_status IN ('pending', 'accepted', 'rejected')),
    final_price_range TEXT,
    admin_notes TEXT,
    created_at TIMESTAMPTZ NOT NULL DEFAULT NOW(),
    updated_at TIMESTAMPTZ NOT NULL DEFAULT NOW()
);

CREATE INDEX IF NOT EXISTS idx_consignment_submissions_user_id ON public.consignment_submissions (user_id);
CREATE INDEX IF NOT EXISTS idx_consignment_submissions_status ON public.consignment_submissions (admin_status);
CREATE INDEX IF NOT EXISTS idx_consignment_submissions_created ON public.consignment_submissions (created_at DESC);

ALTER TABLE public.consignment_submissions ENABLE ROW LEVEL SECURITY;

DROP POLICY IF EXISTS consignment_select_own ON public.consignment_submissions;
CREATE POLICY consignment_select_own ON public.consignment_submissions
    FOR SELECT TO authenticated
    USING (auth.uid() = user_id OR public.is_admin());

DROP POLICY IF EXISTS consignment_insert_own ON public.consignment_submissions;
CREATE POLICY consignment_insert_own ON public.consignment_submissions
    FOR INSERT TO authenticated
    WITH CHECK (auth.uid() = user_id);

DROP POLICY IF EXISTS consignment_update_admin ON public.consignment_submissions;
CREATE POLICY consignment_update_admin ON public.consignment_submissions
    FOR UPDATE TO authenticated
    USING (public.is_admin())
    WITH CHECK (public.is_admin());

COMMIT;

-- Storage bucket (public read for app URLs; paths include user UUID)
INSERT INTO storage.buckets (id, name, public, file_size_limit, allowed_mime_types)
VALUES (
    'consignment-photos',
    'consignment-photos',
    true,
    10485760,
    ARRAY['image/jpeg', 'image/png', 'image/webp']::text[]
)
ON CONFLICT (id) DO UPDATE SET
    public = EXCLUDED.public,
    file_size_limit = EXCLUDED.file_size_limit,
    allowed_mime_types = EXCLUDED.allowed_mime_types;

DROP POLICY IF EXISTS consignment_photos_insert_own ON storage.objects;
CREATE POLICY consignment_photos_insert_own ON storage.objects
    FOR INSERT TO authenticated
    WITH CHECK (
        bucket_id = 'consignment-photos'
        AND (storage.foldername(name))[1] = auth.uid()::text
    );

DROP POLICY IF EXISTS consignment_photos_select ON storage.objects;
CREATE POLICY consignment_photos_select ON storage.objects
    FOR SELECT TO public
    USING (bucket_id = 'consignment-photos');

DROP POLICY IF EXISTS consignment_photos_delete_own ON storage.objects;
CREATE POLICY consignment_photos_delete_own ON storage.objects
    FOR DELETE TO authenticated
    USING (
        bucket_id = 'consignment-photos'
        AND (storage.foldername(name))[1] = auth.uid()::text
    );

DROP POLICY IF EXISTS consignment_photos_update_own ON storage.objects;
CREATE POLICY consignment_photos_update_own ON storage.objects
    FOR UPDATE TO authenticated
    USING (
        bucket_id = 'consignment-photos'
        AND (storage.foldername(name))[1] = auth.uid()::text
    )
    WITH CHECK (
        bucket_id = 'consignment-photos'
        AND (storage.foldername(name))[1] = auth.uid()::text
    );
