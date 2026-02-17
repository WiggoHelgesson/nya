-- Add image_url column to direct_messages for image and GIF support
ALTER TABLE public.direct_messages ADD COLUMN IF NOT EXISTS image_url TEXT;

-- Create storage bucket for chat images (run once)
INSERT INTO storage.buckets (id, name, public)
VALUES ('chat-images', 'chat-images', true)
ON CONFLICT (id) DO NOTHING;

-- Storage policy: authenticated users can upload to chat-images
CREATE POLICY "Authenticated users can upload chat images"
ON storage.objects FOR INSERT
TO authenticated
WITH CHECK (bucket_id = 'chat-images');

-- Storage policy: anyone can view chat images (public bucket)
CREATE POLICY "Anyone can view chat images"
ON storage.objects FOR SELECT
TO public
USING (bucket_id = 'chat-images');

-- Storage policy: users can delete their own chat images
CREATE POLICY "Users can delete own chat images"
ON storage.objects FOR DELETE
TO authenticated
USING (bucket_id = 'chat-images' AND (storage.foldername(name))[1] = auth.uid()::text);
