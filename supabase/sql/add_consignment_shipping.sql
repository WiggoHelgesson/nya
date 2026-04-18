-- Adds shipping flow columns + storage bucket + policies for consignment submissions.
-- Run in Supabase SQL editor. Relies on public.is_admin() from create_consignment_submissions.sql.

BEGIN;

-- 1. Columns ------------------------------------------------------------------
ALTER TABLE public.consignment_submissions
    ADD COLUMN IF NOT EXISTS shipping_status TEXT NOT NULL DEFAULT 'none',
    ADD COLUMN IF NOT EXISTS shipping_address JSONB,
    ADD COLUMN IF NOT EXISTS shipping_label_url TEXT,
    ADD COLUMN IF NOT EXISTS shipping_carrier TEXT,
    ADD COLUMN IF NOT EXISTS shipping_tracking_number TEXT,
    ADD COLUMN IF NOT EXISTS shipped_at TIMESTAMPTZ,
    ADD COLUMN IF NOT EXISTS received_at TIMESTAMPTZ;

ALTER TABLE public.consignment_submissions
    DROP CONSTRAINT IF EXISTS consignment_shipping_status_check;
ALTER TABLE public.consignment_submissions
    ADD CONSTRAINT consignment_shipping_status_check
    CHECK (shipping_status IN (
        'none',
        'awaiting_address',
        'awaiting_label',
        'label_ready',
        'shipped',
        'received'
    ));

CREATE INDEX IF NOT EXISTS idx_consignment_submissions_shipping_status
    ON public.consignment_submissions (shipping_status);

-- 2. Trigger: when admin sets accepted, move shipping_status -> awaiting_address
CREATE OR REPLACE FUNCTION public.consignment_shipping_after_accept()
RETURNS TRIGGER AS $$
BEGIN
    IF NEW.admin_status = 'accepted'
       AND (OLD.admin_status IS DISTINCT FROM 'accepted')
       AND COALESCE(NEW.shipping_status, 'none') = 'none' THEN
        NEW.shipping_status := 'awaiting_address';
    END IF;
    RETURN NEW;
END;
$$ LANGUAGE plpgsql;

DROP TRIGGER IF EXISTS trg_consignment_shipping_after_accept
    ON public.consignment_submissions;
CREATE TRIGGER trg_consignment_shipping_after_accept
    BEFORE UPDATE ON public.consignment_submissions
    FOR EACH ROW
    EXECUTE FUNCTION public.consignment_shipping_after_accept();

-- 3. Seller UPDATE policy (only shipping-related fields) ----------------------
-- Guard: a BEFORE UPDATE trigger that rejects non-shipping field changes when
-- the caller is not an admin. Admins bypass via existing consignment_update_admin.
CREATE OR REPLACE FUNCTION public.consignment_guard_seller_update()
RETURNS TRIGGER AS $$
BEGIN
    -- Admins can change anything.
    IF public.is_admin() THEN
        RETURN NEW;
    END IF;

    -- Sellers must not change anything outside the shipping subset.
    IF NEW.user_id            IS DISTINCT FROM OLD.user_id
       OR NEW.image_urls      IS DISTINCT FROM OLD.image_urls
       OR NEW.category        IS DISTINCT FROM OLD.category
       OR NEW.ai_payload      IS DISTINCT FROM OLD.ai_payload
       OR NEW.user_brand      IS DISTINCT FROM OLD.user_brand
       OR NEW.user_condition  IS DISTINCT FROM OLD.user_condition
       OR NEW.admin_status    IS DISTINCT FROM OLD.admin_status
       OR NEW.final_price_range IS DISTINCT FROM OLD.final_price_range
       OR NEW.admin_notes     IS DISTINCT FROM OLD.admin_notes
       OR NEW.shipping_label_url IS DISTINCT FROM OLD.shipping_label_url
       OR NEW.shipping_carrier   IS DISTINCT FROM OLD.shipping_carrier
       OR NEW.shipping_tracking_number IS DISTINCT FROM OLD.shipping_tracking_number
       OR NEW.received_at     IS DISTINCT FROM OLD.received_at
       OR NEW.created_at      IS DISTINCT FROM OLD.created_at THEN
        RAISE EXCEPTION 'Sellers may only edit shipping_address, shipping_status or shipped_at';
    END IF;

    -- Only allow these shipping_status transitions for sellers.
    IF NEW.shipping_status IS DISTINCT FROM OLD.shipping_status THEN
        IF NOT (
            (OLD.shipping_status = 'awaiting_address' AND NEW.shipping_status = 'awaiting_label')
            OR (OLD.shipping_status = 'label_ready' AND NEW.shipping_status = 'shipped')
        ) THEN
            RAISE EXCEPTION 'Illegal seller shipping_status transition: % -> %',
                OLD.shipping_status, NEW.shipping_status;
        END IF;
    END IF;

    RETURN NEW;
END;
$$ LANGUAGE plpgsql SECURITY DEFINER;

DROP TRIGGER IF EXISTS trg_consignment_guard_seller_update
    ON public.consignment_submissions;
CREATE TRIGGER trg_consignment_guard_seller_update
    BEFORE UPDATE ON public.consignment_submissions
    FOR EACH ROW
    EXECUTE FUNCTION public.consignment_guard_seller_update();

DROP POLICY IF EXISTS consignment_update_own_shipping ON public.consignment_submissions;
CREATE POLICY consignment_update_own_shipping ON public.consignment_submissions
    FOR UPDATE TO authenticated
    USING (auth.uid() = user_id)
    WITH CHECK (auth.uid() = user_id);

COMMIT;

-- 4. Storage bucket for PDF labels (private) ---------------------------------
INSERT INTO storage.buckets (id, name, public, file_size_limit, allowed_mime_types)
VALUES (
    'shipping-labels',
    'shipping-labels',
    false,
    20971520,
    ARRAY['application/pdf']::text[]
)
ON CONFLICT (id) DO UPDATE SET
    public = EXCLUDED.public,
    file_size_limit = EXCLUDED.file_size_limit,
    allowed_mime_types = EXCLUDED.allowed_mime_types;

-- Admin can write; sellers and admins can read their own file.
DROP POLICY IF EXISTS shipping_labels_admin_write ON storage.objects;
CREATE POLICY shipping_labels_admin_write ON storage.objects
    FOR INSERT TO authenticated
    WITH CHECK (
        bucket_id = 'shipping-labels'
        AND public.is_admin()
    );

DROP POLICY IF EXISTS shipping_labels_admin_update ON storage.objects;
CREATE POLICY shipping_labels_admin_update ON storage.objects
    FOR UPDATE TO authenticated
    USING (bucket_id = 'shipping-labels' AND public.is_admin())
    WITH CHECK (bucket_id = 'shipping-labels' AND public.is_admin());

DROP POLICY IF EXISTS shipping_labels_admin_delete ON storage.objects;
CREATE POLICY shipping_labels_admin_delete ON storage.objects
    FOR DELETE TO authenticated
    USING (bucket_id = 'shipping-labels' AND public.is_admin());

-- Layout: shipping-labels/{user_id}/{submission_id}.pdf
DROP POLICY IF EXISTS shipping_labels_select_own_or_admin ON storage.objects;
CREATE POLICY shipping_labels_select_own_or_admin ON storage.objects
    FOR SELECT TO authenticated
    USING (
        bucket_id = 'shipping-labels'
        AND (
            public.is_admin()
            OR (storage.foldername(name))[1] = auth.uid()::text
        )
    );
