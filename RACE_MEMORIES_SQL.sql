-- Lägg till completed_races kolumn i profiles tabell
ALTER TABLE profiles ADD COLUMN IF NOT EXISTS completed_races text[] DEFAULT '{}';

-- Skapa race_memories tabell för att lagra bilder från tävlingar
CREATE TABLE IF NOT EXISTS race_memories (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    user_id UUID NOT NULL REFERENCES profiles(id) ON DELETE CASCADE,
    race_id TEXT NOT NULL,
    image_url TEXT NOT NULL,
    created_at TIMESTAMPTZ DEFAULT NOW(),
    CONSTRAINT unique_race_memory UNIQUE (user_id, race_id, image_url)
);

-- Skapa index för snabbare queries
CREATE INDEX IF NOT EXISTS idx_race_memories_user_id ON race_memories(user_id);
CREATE INDEX IF NOT EXISTS idx_race_memories_race_id ON race_memories(race_id);
CREATE INDEX IF NOT EXISTS idx_race_memories_user_race ON race_memories(user_id, race_id);

-- Aktivera Row Level Security (RLS)
ALTER TABLE race_memories ENABLE ROW LEVEL SECURITY;

-- Policy: Alla kan se alla minnen
CREATE POLICY "Anyone can view race memories"
ON race_memories FOR SELECT
USING (true);

-- Policy: Användare kan bara lägga till sina egna minnen
CREATE POLICY "Users can insert their own race memories"
ON race_memories FOR INSERT
WITH CHECK (auth.uid() = user_id);

-- Policy: Användare kan bara ta bort sina egna minnen
CREATE POLICY "Users can delete their own race memories"
ON race_memories FOR DELETE
USING (auth.uid() = user_id);

-- Kommentar
COMMENT ON TABLE race_memories IS 'Lagrar bilder/minnen från användares tävlingar';
