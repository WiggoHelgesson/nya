-- Schools table: populated from Skolverket API + hardcoded universities
CREATE TABLE IF NOT EXISTS schools (
    id TEXT PRIMARY KEY,
    name TEXT NOT NULL,
    type TEXT NOT NULL DEFAULT 'gymnasium',
    status TEXT NOT NULL DEFAULT 'AKTIV',
    municipality TEXT
);

ALTER TABLE schools ENABLE ROW LEVEL SECURITY;

CREATE POLICY "Anyone can read schools"
    ON schools FOR SELECT
    USING (true);

-- Seed universities (these are not in Skolverket's register)
INSERT INTO schools (id, name, type, status) VALUES
    ('uu.se', 'Uppsala universitet', 'universitet', 'AKTIV'),
    ('lu.se', 'Lunds universitet', 'universitet', 'AKTIV'),
    ('su.se', 'Stockholms universitet', 'universitet', 'AKTIV'),
    ('gu.se', 'Göteborgs universitet', 'universitet', 'AKTIV'),
    ('umu.se', 'Umeå universitet', 'universitet', 'AKTIV'),
    ('liu.se', 'Linköpings universitet', 'universitet', 'AKTIV'),
    ('ki.se', 'Karolinska Institutet', 'universitet', 'AKTIV'),
    ('kth.se', 'KTH', 'universitet', 'AKTIV'),
    ('chalmers.se', 'Chalmers', 'universitet', 'AKTIV'),
    ('ltu.se', 'Luleå tekniska universitet', 'universitet', 'AKTIV'),
    ('kau.se', 'Karlstads universitet', 'universitet', 'AKTIV'),
    ('lnu.se', 'Linnéuniversitetet', 'universitet', 'AKTIV'),
    ('miun.se', 'Mittuniversitetet', 'universitet', 'AKTIV'),
    ('mau.se', 'Malmö universitet', 'universitet', 'AKTIV'),
    ('slu.se', 'Sveriges lantbruksuniversitet', 'universitet', 'AKTIV'),
    ('oru.se', 'Örebro universitet', 'universitet', 'AKTIV'),
    ('bth.se', 'Blekinge tekniska högskola', 'universitet', 'AKTIV'),
    ('elev.danderyd.se', 'Danderyds gymnasium', 'universitet', 'AKTIV')
ON CONFLICT (id) DO NOTHING;

-- Gymnasium schools are populated via the fetch-schools Edge Function
-- Run: SELECT net.http_post('https://<project>.supabase.co/functions/v1/fetch-schools', ...);
