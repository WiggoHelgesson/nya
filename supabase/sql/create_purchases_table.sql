-- =====================================================
-- PURCHASES TABLE - RABATTKOD HISTORIK
-- =====================================================
-- Denna tabell sparar alla rabattkoder som användare löser in

CREATE TABLE IF NOT EXISTS public.purchases (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    user_id UUID NOT NULL REFERENCES auth.users(id) ON DELETE CASCADE,
    brand_name TEXT NOT NULL,
    discount TEXT NOT NULL,
    discount_code TEXT NOT NULL,
    purchase_date TIMESTAMPTZ NOT NULL DEFAULT now(),
    created_at TIMESTAMPTZ DEFAULT now(),
    updated_at TIMESTAMPTZ DEFAULT now()
);

-- Index för snabbare queries
CREATE INDEX IF NOT EXISTS purchases_user_id_idx ON public.purchases(user_id);
CREATE INDEX IF NOT EXISTS purchases_brand_name_idx ON public.purchases(brand_name);
CREATE INDEX IF NOT EXISTS purchases_purchase_date_idx ON public.purchases(purchase_date DESC);
CREATE INDEX IF NOT EXISTS purchases_created_at_idx ON public.purchases(created_at DESC);

-- Enable RLS (Row Level Security)
ALTER TABLE public.purchases ENABLE ROW LEVEL SECURITY;

-- Policies: Användare kan se sina egna köp
CREATE POLICY purchases_select_own ON public.purchases
    FOR SELECT USING (auth.uid() = user_id);

-- Policies: Användare kan skapa sina egna köp
CREATE POLICY purchases_insert_own ON public.purchases
    FOR INSERT WITH CHECK (auth.uid() = user_id);

-- Policies: Användare kan inte uppdatera eller radera köp
-- (köp är permanenta för att bevara historik)

-- Admin kan se alla köp (lägg till admin check om du vill)
-- CREATE POLICY purchases_select_admin ON public.purchases
--     FOR SELECT USING (
--         EXISTS (
--             SELECT 1 FROM public.profiles
--             WHERE id = auth.uid() AND is_admin = true
--         )
--     );

COMMENT ON TABLE public.purchases IS 'Historik över alla rabattkoder som användare har löst in';
COMMENT ON COLUMN public.purchases.id IS 'Unikt ID för köpet';
COMMENT ON COLUMN public.purchases.user_id IS 'Användare som löste in rabattkoden';
COMMENT ON COLUMN public.purchases.brand_name IS 'Varumärke (t.ex. "Nocco", "SATS")';
COMMENT ON COLUMN public.purchases.discount IS 'Rabatt (t.ex. "20% rabatt")';
COMMENT ON COLUMN public.purchases.discount_code IS 'Den faktiska rabattkoden';
COMMENT ON COLUMN public.purchases.purchase_date IS 'När rabattkoden löstes in';








