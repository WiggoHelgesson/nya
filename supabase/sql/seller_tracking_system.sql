-- ============================================
-- SELLER TRACKING SYSTEM
-- Tables for tracking bags sent in by sellers
-- and items listed/sold from those bags
-- ============================================

-- 1. seller_bags: one row per bag shipment
CREATE TABLE IF NOT EXISTS seller_bags (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    user_id TEXT NOT NULL,
    bag_code TEXT UNIQUE NOT NULL,
    status TEXT NOT NULL DEFAULT 'shipped'
        CHECK (status IN ('ordered', 'shipped', 'received', 'processing', 'listed', 'completed')),
    quantity INT NOT NULL DEFAULT 1,
    created_at TIMESTAMPTZ NOT NULL DEFAULT now(),
    shipped_at TIMESTAMPTZ DEFAULT now(),
    received_at TIMESTAMPTZ,
    tracking_url TEXT,
    sender_name TEXT,
    sender_email TEXT
);

CREATE INDEX IF NOT EXISTS idx_seller_bags_user_id ON seller_bags(user_id);
CREATE INDEX IF NOT EXISTS idx_seller_bags_bag_code ON seller_bags(bag_code);

-- 2. seller_items: one row per product from a bag
CREATE TABLE IF NOT EXISTS seller_items (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    bag_id UUID NOT NULL REFERENCES seller_bags(id) ON DELETE CASCADE,
    user_id TEXT NOT NULL,
    shopify_product_id TEXT,
    shopify_handle TEXT,
    title TEXT,
    image_url TEXT,
    price NUMERIC DEFAULT 0,
    status TEXT NOT NULL DEFAULT 'listed'
        CHECK (status IN ('listed', 'sold', 'unsold', 'donated')),
    sold_at TIMESTAMPTZ,
    seller_share NUMERIC DEFAULT 0,
    ad_cost NUMERIC DEFAULT 12,
    created_at TIMESTAMPTZ NOT NULL DEFAULT now()
);

CREATE INDEX IF NOT EXISTS idx_seller_items_bag_id ON seller_items(bag_id);
CREATE INDEX IF NOT EXISTS idx_seller_items_user_id ON seller_items(user_id);
CREATE INDEX IF NOT EXISTS idx_seller_items_shopify_product_id ON seller_items(shopify_product_id);

-- 3. RLS policies
ALTER TABLE seller_bags ENABLE ROW LEVEL SECURITY;
ALTER TABLE seller_items ENABLE ROW LEVEL SECURITY;

-- Users can read their own bags
CREATE POLICY "Users can read own bags"
    ON seller_bags FOR SELECT
    USING (user_id = auth.uid()::text);

-- Users can insert their own bags (via edge function with service role, but also direct)
CREATE POLICY "Users can insert own bags"
    ON seller_bags FOR INSERT
    WITH CHECK (user_id = auth.uid()::text);

-- Service role can do everything (for edge functions / webhooks)
CREATE POLICY "Service role full access bags"
    ON seller_bags FOR ALL
    USING (auth.role() = 'service_role');

-- Users can read their own items
CREATE POLICY "Users can read own items"
    ON seller_items FOR SELECT
    USING (user_id = auth.uid()::text);

-- Service role can do everything on items
CREATE POLICY "Service role full access items"
    ON seller_items FOR ALL
    USING (auth.role() = 'service_role');

-- 4. Helper function: generate unique bag code
CREATE OR REPLACE FUNCTION generate_bag_code()
RETURNS TEXT
LANGUAGE plpgsql
AS $$
DECLARE
    chars TEXT := 'ABCDEFGHJKLMNPQRSTUVWXYZ23456789';
    code TEXT;
    exists_already BOOLEAN;
BEGIN
    LOOP
        code := 'UD-';
        FOR i IN 1..4 LOOP
            code := code || substr(chars, floor(random() * length(chars) + 1)::int, 1);
        END LOOP;
        SELECT EXISTS(SELECT 1 FROM seller_bags WHERE bag_code = code) INTO exists_already;
        IF NOT exists_already THEN
            RETURN code;
        END IF;
    END LOOP;
END;
$$;

-- 5. RPC to create a bag and return the code
CREATE OR REPLACE FUNCTION create_seller_bag(
    p_user_id TEXT,
    p_quantity INT DEFAULT 1,
    p_sender_name TEXT DEFAULT NULL,
    p_sender_email TEXT DEFAULT NULL,
    p_tracking_url TEXT DEFAULT NULL
)
RETURNS TABLE(bag_id UUID, bag_code TEXT)
LANGUAGE plpgsql
SECURITY DEFINER
AS $$
DECLARE
    v_code TEXT;
    v_id UUID;
BEGIN
    v_code := generate_bag_code();
    INSERT INTO seller_bags (user_id, bag_code, status, quantity, sender_name, sender_email, tracking_url)
    VALUES (p_user_id, v_code, 'shipped', p_quantity, p_sender_name, p_sender_email, p_tracking_url)
    RETURNING id INTO v_id;

    RETURN QUERY SELECT v_id, v_code;
END;
$$;

-- 6. RPC to get seller summary stats
CREATE OR REPLACE FUNCTION get_seller_summary(p_user_id TEXT)
RETURNS TABLE(
    total_bags BIGINT,
    total_items BIGINT,
    items_listed BIGINT,
    items_sold BIGINT,
    total_earned NUMERIC,
    total_ad_costs NUMERIC
)
LANGUAGE plpgsql
SECURITY DEFINER
AS $$
BEGIN
    RETURN QUERY
    SELECT
        (SELECT COUNT(*) FROM seller_bags WHERE user_id = p_user_id)::BIGINT,
        (SELECT COUNT(*) FROM seller_items WHERE user_id = p_user_id)::BIGINT,
        (SELECT COUNT(*) FROM seller_items WHERE user_id = p_user_id AND status = 'listed')::BIGINT,
        (SELECT COUNT(*) FROM seller_items WHERE user_id = p_user_id AND status = 'sold')::BIGINT,
        COALESCE((SELECT SUM(seller_share) FROM seller_items WHERE user_id = p_user_id AND status = 'sold'), 0)::NUMERIC,
        COALESCE((SELECT SUM(ad_cost) FROM seller_items WHERE user_id = p_user_id), 0)::NUMERIC;
END;
$$;
