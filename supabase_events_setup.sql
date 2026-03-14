-- =============================================
-- Händelser (Events) Feature - Database Setup
-- Run this in the Supabase SQL Editor
-- =============================================

-- 1. Create events table
CREATE TABLE IF NOT EXISTS events (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    user_id UUID NOT NULL REFERENCES auth.users(id) ON DELETE CASCADE,
    title TEXT NOT NULL,
    description TEXT NOT NULL,
    cover_image_url TEXT NOT NULL,
    created_at TIMESTAMPTZ NOT NULL DEFAULT now()
);

-- 2. Create event_images table
CREATE TABLE IF NOT EXISTS event_images (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    event_id UUID NOT NULL REFERENCES events(id) ON DELETE CASCADE,
    image_url TEXT NOT NULL,
    sort_order INT NOT NULL DEFAULT 0,
    created_at TIMESTAMPTZ NOT NULL DEFAULT now()
);

-- 3. Create indexes
CREATE INDEX IF NOT EXISTS idx_events_user_id ON events(user_id);
CREATE INDEX IF NOT EXISTS idx_events_created_at ON events(created_at DESC);
CREATE INDEX IF NOT EXISTS idx_event_images_event_id ON event_images(event_id);
CREATE INDEX IF NOT EXISTS idx_event_images_sort_order ON event_images(event_id, sort_order);

-- 4. Enable RLS
ALTER TABLE events ENABLE ROW LEVEL SECURITY;
ALTER TABLE event_images ENABLE ROW LEVEL SECURITY;

-- 5. RLS Policies for events
CREATE POLICY "Anyone can view events"
    ON events FOR SELECT
    USING (true);

CREATE POLICY "Users can insert own events"
    ON events FOR INSERT
    WITH CHECK (auth.uid() = user_id);

CREATE POLICY "Users can update own events"
    ON events FOR UPDATE
    USING (auth.uid() = user_id);

CREATE POLICY "Users can delete own events"
    ON events FOR DELETE
    USING (auth.uid() = user_id);

-- 6. RLS Policies for event_images
CREATE POLICY "Anyone can view event images"
    ON event_images FOR SELECT
    USING (true);

CREATE POLICY "Users can insert images for own events"
    ON event_images FOR INSERT
    WITH CHECK (
        EXISTS (
            SELECT 1 FROM events WHERE events.id = event_id AND events.user_id = auth.uid()
        )
    );

CREATE POLICY "Users can delete images for own events"
    ON event_images FOR DELETE
    USING (
        EXISTS (
            SELECT 1 FROM events WHERE events.id = event_id AND events.user_id = auth.uid()
        )
    );

-- 7. Create storage bucket (run separately if needed)
INSERT INTO storage.buckets (id, name, public)
VALUES ('event-images', 'event-images', true)
ON CONFLICT (id) DO NOTHING;

-- 8. Storage policies
CREATE POLICY "Anyone can view event images storage"
    ON storage.objects FOR SELECT
    USING (bucket_id = 'event-images');

CREATE POLICY "Authenticated users can upload event images"
    ON storage.objects FOR INSERT
    WITH CHECK (bucket_id = 'event-images' AND auth.role() = 'authenticated');

CREATE POLICY "Users can delete own event images"
    ON storage.objects FOR DELETE
    USING (bucket_id = 'event-images' AND auth.role() = 'authenticated');
