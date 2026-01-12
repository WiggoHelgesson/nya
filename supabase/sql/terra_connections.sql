-- Create Terra connections table
CREATE TABLE IF NOT EXISTS terra_connections (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    user_id UUID NOT NULL REFERENCES profiles(id) ON DELETE CASCADE,
    terra_user_id TEXT NOT NULL,
    provider TEXT NOT NULL,
    connected_at TIMESTAMPTZ DEFAULT NOW(),
    is_active BOOLEAN DEFAULT TRUE,
    created_at TIMESTAMPTZ DEFAULT NOW(),
    updated_at TIMESTAMPTZ DEFAULT NOW(),
    
    -- Unique constraint: one connection per user per provider
    UNIQUE(user_id, provider)
);

-- Create index for faster lookups
CREATE INDEX IF NOT EXISTS idx_terra_connections_user_id ON terra_connections(user_id);
CREATE INDEX IF NOT EXISTS idx_terra_connections_terra_user_id ON terra_connections(terra_user_id);

-- Enable RLS
ALTER TABLE terra_connections ENABLE ROW LEVEL SECURITY;

-- RLS Policies
CREATE POLICY "Users can view their own connections"
ON terra_connections FOR SELECT
USING (auth.uid() = user_id);

CREATE POLICY "Users can insert their own connections"
ON terra_connections FOR INSERT
WITH CHECK (auth.uid() = user_id);

CREATE POLICY "Users can update their own connections"
ON terra_connections FOR UPDATE
USING (auth.uid() = user_id);

-- Service role can do anything (for webhooks)
CREATE POLICY "Service role full access"
ON terra_connections FOR ALL
USING (auth.role() = 'service_role');

-- Add external_id and source columns to workout_posts if they don't exist
DO $$
BEGIN
    IF NOT EXISTS (
        SELECT 1 FROM information_schema.columns 
        WHERE table_name = 'workout_posts' AND column_name = 'external_id'
    ) THEN
        ALTER TABLE workout_posts ADD COLUMN external_id TEXT;
    END IF;
    
    IF NOT EXISTS (
        SELECT 1 FROM information_schema.columns 
        WHERE table_name = 'workout_posts' AND column_name = 'source'
    ) THEN
        ALTER TABLE workout_posts ADD COLUMN source TEXT DEFAULT 'app';
    END IF;
END $$;

-- Create index on external_id for duplicate checking
CREATE INDEX IF NOT EXISTS idx_workout_posts_external_id ON workout_posts(external_id);

-- Function to update updated_at timestamp
CREATE OR REPLACE FUNCTION update_terra_connections_updated_at()
RETURNS TRIGGER AS $$
BEGIN
    NEW.updated_at = NOW();
    RETURN NEW;
END;
$$ LANGUAGE plpgsql;

-- Trigger to auto-update updated_at
DROP TRIGGER IF EXISTS update_terra_connections_updated_at ON terra_connections;
CREATE TRIGGER update_terra_connections_updated_at
    BEFORE UPDATE ON terra_connections
    FOR EACH ROW
    EXECUTE FUNCTION update_terra_connections_updated_at();

