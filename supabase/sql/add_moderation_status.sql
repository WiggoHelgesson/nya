-- Add moderation_status column to workout_posts
-- Values: 'approved' (default), 'pending_review' (flagged by AI)
ALTER TABLE workout_posts
ADD COLUMN IF NOT EXISTS moderation_status TEXT DEFAULT 'approved';
