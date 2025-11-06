-- Skapa mountain_memories tabell för att lagra bilder från bergbestigningar
CREATE TABLE IF NOT EXISTS mountain_memories (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    user_id UUID NOT NULL REFERENCES profiles(id) ON DELETE CASCADE,
    mountain_id TEXT NOT NULL,
    image_url TEXT NOT NULL,
    created_at TIMESTAMPTZ DEFAULT NOW(),
    CONSTRAINT unique_memory UNIQUE (user_id, mountain_id, image_url)
);

-- Skapa index för snabbare queries
CREATE INDEX IF NOT EXISTS idx_mountain_memories_user_id ON mountain_memories(user_id);
CREATE INDEX IF NOT EXISTS idx_mountain_memories_mountain_id ON mountain_memories(mountain_id);
CREATE INDEX IF NOT EXISTS idx_mountain_memories_user_mountain ON mountain_memories(user_id, mountain_id);

-- Aktivera Row Level Security (RLS)
ALTER TABLE mountain_memories ENABLE ROW LEVEL SECURITY;

-- Policy: Alla kan se alla minnen
CREATE POLICY "Anyone can view mountain memories"
ON mountain_memories FOR SELECT
USING (true);

-- Policy: Användare kan bara lägga till sina egna minnen
CREATE POLICY "Users can insert their own memories"
ON mountain_memories FOR INSERT
WITH CHECK (auth.uid() = user_id);

-- Policy: Användare kan bara ta bort sina egna minnen
CREATE POLICY "Users can delete their own memories"
ON mountain_memories FOR DELETE
USING (auth.uid() = user_id);

-- Kommentar
COMMENT ON TABLE mountain_memories IS 'Lagrar bilder/minnen från användares bergbestigningar';
