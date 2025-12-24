-- Create news table for admin announcements
-- Only info@bylito.se can create news posts

CREATE TABLE IF NOT EXISTS public.news (
    id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
    content TEXT NOT NULL,
    author_id UUID NOT NULL REFERENCES auth.users(id) ON DELETE CASCADE,
    author_name TEXT NOT NULL DEFAULT 'Up&Down',
    author_avatar_url TEXT,
    image_url TEXT,
    created_at TIMESTAMPTZ NOT NULL DEFAULT NOW(),
    updated_at TIMESTAMPTZ NOT NULL DEFAULT NOW()
);

-- Create index for faster queries
CREATE INDEX IF NOT EXISTS idx_news_created_at ON public.news(created_at DESC);

-- Enable RLS
ALTER TABLE public.news ENABLE ROW LEVEL SECURITY;

-- Everyone can read news
CREATE POLICY "Anyone can read news"
    ON public.news FOR SELECT
    USING (true);

-- Only admin (info@bylito.se) can insert news
CREATE POLICY "Only admin can insert news"
    ON public.news FOR INSERT
    WITH CHECK (
        auth.jwt() ->> 'email' = 'info@bylito.se'
    );

-- Only admin can update news
CREATE POLICY "Only admin can update news"
    ON public.news FOR UPDATE
    USING (
        auth.jwt() ->> 'email' = 'info@bylito.se'
    );

-- Only admin can delete news
CREATE POLICY "Only admin can delete news"
    ON public.news FOR DELETE
    USING (
        auth.jwt() ->> 'email' = 'info@bylito.se'
    );

-- Grant access to authenticated users
GRANT SELECT ON public.news TO authenticated;
GRANT INSERT, UPDATE, DELETE ON public.news TO authenticated;

-- Comment on table
COMMENT ON TABLE public.news IS 'News/announcements from Up&Down admin (info@bylito.se only)';

-- Create news_settings table for storing news profile settings
CREATE TABLE IF NOT EXISTS public.news_settings (
    id TEXT PRIMARY KEY DEFAULT 'default',
    avatar_url TEXT,
    created_at TIMESTAMPTZ NOT NULL DEFAULT NOW(),
    updated_at TIMESTAMPTZ NOT NULL DEFAULT NOW()
);

-- Enable RLS on news_settings
ALTER TABLE public.news_settings ENABLE ROW LEVEL SECURITY;

-- Everyone can read news_settings
CREATE POLICY "Anyone can read news_settings"
    ON public.news_settings FOR SELECT
    USING (true);

-- Only admin can modify news_settings
CREATE POLICY "Only admin can insert news_settings"
    ON public.news_settings FOR INSERT
    WITH CHECK (auth.jwt() ->> 'email' = 'info@bylito.se');

CREATE POLICY "Only admin can update news_settings"
    ON public.news_settings FOR UPDATE
    USING (auth.jwt() ->> 'email' = 'info@bylito.se');

-- Grant access
GRANT SELECT ON public.news_settings TO authenticated;
GRANT INSERT, UPDATE ON public.news_settings TO authenticated;

