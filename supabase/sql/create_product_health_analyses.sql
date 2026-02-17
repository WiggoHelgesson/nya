-- Cache table for product health analyses (GPT results)
-- Keyed by barcode so the same product doesn't need re-analysis

CREATE TABLE IF NOT EXISTS product_health_analyses (
    id uuid DEFAULT gen_random_uuid() PRIMARY KEY,
    barcode text NOT NULL UNIQUE,
    product_name text NOT NULL,
    brand text,
    analysis_json jsonb NOT NULL,
    created_at timestamptz DEFAULT now(),
    updated_at timestamptz DEFAULT now()
);

-- Index for barcode lookups
CREATE INDEX IF NOT EXISTS idx_product_health_barcode ON product_health_analyses(barcode);

-- RLS policies
ALTER TABLE product_health_analyses ENABLE ROW LEVEL SECURITY;

-- Anyone can read analyses (they are product-level, not user-level)
CREATE POLICY "Anyone can read product analyses"
    ON product_health_analyses FOR SELECT
    USING (true);

-- Authenticated users can insert analyses
CREATE POLICY "Authenticated users can insert analyses"
    ON product_health_analyses FOR INSERT
    WITH CHECK (auth.role() = 'authenticated');

-- Allow updates (for refreshing stale analyses)
CREATE POLICY "Authenticated users can update analyses"
    ON product_health_analyses FOR UPDATE
    USING (auth.role() = 'authenticated');
