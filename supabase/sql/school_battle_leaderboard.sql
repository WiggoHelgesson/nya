-- =============================================
-- School Battle Leaderboard
-- Aggregates total gym volume per school/university for the month
-- Run this in the Supabase SQL Editor
-- =============================================

CREATE OR REPLACE FUNCTION get_school_volume_leaderboard(p_month TEXT)
RETURNS TABLE(school_domain TEXT, school_name TEXT, total_volume NUMERIC, student_count BIGINT)
LANGUAGE plpgsql
SECURITY DEFINER
AS $$
BEGIN
    RETURN QUERY
    WITH school_domains(domain, name) AS (
        VALUES
            ('elev.danderyd.se', 'Danderyds gymnasium'),
            ('uu.se', 'Uppsala universitet'),
            ('lu.se', 'Lunds universitet'),
            ('su.se', 'Stockholms universitet'),
            ('gu.se', 'Göteborgs universitet'),
            ('umu.se', 'Umeå universitet'),
            ('liu.se', 'Linköpings universitet'),
            ('ki.se', 'Karolinska Institutet'),
            ('kth.se', 'KTH'),
            ('chalmers.se', 'Chalmers'),
            ('ltu.se', 'Luleå tekniska universitet'),
            ('kau.se', 'Karlstads universitet'),
            ('lnu.se', 'Linnéuniversitetet'),
            ('miun.se', 'Mittuniversitetet'),
            ('mau.se', 'Malmö universitet'),
            ('slu.se', 'Sveriges lantbruksuniversitet'),
            ('oru.se', 'Örebro universitet'),
            ('bth.se', 'Blekinge tekniska högskola')
    ),
    user_schools AS (
        SELECT
            CAST(p.id AS TEXT) AS user_id,
            sd.domain AS school_domain,
            sd.name AS school_name
        FROM public.profiles p
        JOIN school_domains sd ON (
            LOWER(p.verified_school_email) LIKE '%' || sd.domain
        )
        WHERE p.verified_school_email IS NOT NULL

        UNION

        SELECT
            CAST(u.id AS TEXT) AS user_id,
            sd.domain AS school_domain,
            sd.name AS school_name
        FROM auth.users u
        JOIN school_domains sd ON (
            LOWER(u.email) LIKE '%' || sd.domain
        )
        WHERE NOT EXISTS (
            SELECT 1 FROM public.profiles p2
            WHERE CAST(p2.id AS TEXT) = CAST(u.id AS TEXT)
              AND p2.verified_school_email IS NOT NULL
        )
    ),
    volumes AS (
        SELECT
            us.school_domain,
            us.school_name,
            us.user_id,
            COALESCE(SUM(calculate_workout_volume(wp.exercises_data)), 0) AS user_volume
        FROM user_schools us
        JOIN workout_posts wp ON CAST(wp.user_id AS TEXT) = us.user_id
        WHERE to_char(wp.created_at::timestamptz, 'YYYY-MM') = p_month
          AND LOWER(wp.activity_type) IN ('gympass', 'gym', 'strength', 'walking')
          AND wp.exercises_data IS NOT NULL
        GROUP BY us.school_domain, us.school_name, us.user_id
    )
    SELECT
        v.school_domain,
        v.school_name,
        SUM(v.user_volume)::NUMERIC AS total_volume,
        COUNT(DISTINCT v.user_id)::BIGINT AS student_count
    FROM volumes v
    GROUP BY v.school_domain, v.school_name
    ORDER BY SUM(v.user_volume) DESC;
END;
$$;
