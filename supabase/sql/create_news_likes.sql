-- Create news_likes table for liking announcements
-- Everyone can like news posts

CREATE TABLE IF NOT EXISTS public.news_likes (
    id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
    news_id TEXT NOT NULL,
    user_id UUID NOT NULL REFERENCES auth.users(id) ON DELETE CASCADE,
    created_at TIMESTAMPTZ NOT NULL DEFAULT NOW(),
    UNIQUE(news_id, user_id)
);

-- Create indexes for faster queries
CREATE INDEX IF NOT EXISTS idx_news_likes_news_id ON public.news_likes(news_id);
CREATE INDEX IF NOT EXISTS idx_news_likes_user_id ON public.news_likes(user_id);

-- Enable RLS
ALTER TABLE public.news_likes ENABLE ROW LEVEL SECURITY;

-- Everyone can read news likes
CREATE POLICY "Anyone can read news likes"
    ON public.news_likes FOR SELECT
    USING (true);

-- Authenticated users can like news (insert their own likes)
CREATE POLICY "Users can like news"
    ON public.news_likes FOR INSERT
    WITH CHECK (auth.uid() = user_id);

-- Users can remove their own likes
CREATE POLICY "Users can unlike news"
    ON public.news_likes FOR DELETE
    USING (auth.uid() = user_id);

-- Grant permissions
GRANT SELECT, INSERT, DELETE ON public.news_likes TO authenticated;

-- Add like_count column to news table if not exists
DO $$ 
BEGIN
    IF NOT EXISTS (SELECT 1 FROM information_schema.columns 
                   WHERE table_name = 'news' AND column_name = 'like_count') THEN
        ALTER TABLE public.news ADD COLUMN like_count INTEGER DEFAULT 0;
    END IF;
END $$;

-- Create function to update news like count
CREATE OR REPLACE FUNCTION update_news_like_count()
RETURNS TRIGGER AS $$
BEGIN
    IF TG_OP = 'INSERT' THEN
        UPDATE public.news 
        SET like_count = COALESCE(like_count, 0) + 1 
        WHERE id = NEW.news_id;
        RETURN NEW;
    ELSIF TG_OP = 'DELETE' THEN
        UPDATE public.news 
        SET like_count = GREATEST(COALESCE(like_count, 0) - 1, 0) 
        WHERE id = OLD.news_id;
        RETURN OLD;
    END IF;
    RETURN NULL;
END;
$$ LANGUAGE plpgsql;

-- Drop trigger if exists and recreate
DROP TRIGGER IF EXISTS news_likes_count_trigger ON public.news_likes;
CREATE TRIGGER news_likes_count_trigger
    AFTER INSERT OR DELETE ON public.news_likes
    FOR EACH ROW
    EXECUTE FUNCTION update_news_like_count();

-- Comment
COMMENT ON TABLE public.news_likes IS 'Likes for news/announcements posts';

