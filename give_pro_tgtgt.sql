-- =====================================================
-- GE info@tgtgt.com PRO I ETT ÅR
-- =====================================================
-- Kör denna i Supabase SQL Editor

-- 1️⃣ GE PRO-STATUS
UPDATE public.profiles
SET is_pro_member = true
WHERE email = 'info@tgtgt.com';

-- 2️⃣ VERIFIERA ATT DET FUNKADE
SELECT 
    id,
    username,
    email,
    is_pro_member,
    current_xp,
    created_at,
    CASE 
        WHEN is_pro_member THEN '✅ PRO AKTIV'
        ELSE '❌ INTE PRO'
    END as pro_status
FROM public.profiles
WHERE email = 'info@tgtgt.com';

-- =====================================================
-- 📅 PÅMINNELSE: TA BORT PRO OM 1 ÅR (2027-01-02)
-- =====================================================
-- OBS: Database-granted Pro har inget automatiskt utgångsdatum.
-- Sätt en påminnelse att köra denna query 2027-01-02:

-- UPDATE public.profiles
-- SET is_pro_member = false
-- WHERE email = 'info@tgtgt.com';

-- =====================================================
-- 💡 ALTERNATIV: LÄGG TILL UTGÅNGSDATUM (VALFRITT)
-- =====================================================
-- Om du vill ha automatisk utgång, lägg till denna kolumn:

-- ALTER TABLE public.profiles 
-- ADD COLUMN IF NOT EXISTS pro_expires_at TIMESTAMPTZ;

-- UPDATE public.profiles
-- SET 
--     is_pro_member = true,
--     pro_expires_at = NOW() + INTERVAL '1 year'
-- WHERE email = 'info@tgtgt.com';

-- =====================================================
-- ✅ RESULTAT
-- =====================================================
-- info@tgtgt.com har nu Pro-status!
-- 
-- De får nu:
-- ✅ Månadens pris (full tillgång)
-- ✅ 2x poäng i Zonkriget
-- ✅ Obegränsade övningar i Progressiv Överbelastning
-- ✅ Obegränsad AI-chat med UPPY
-- ✅ Full veckostatistik
-- ✅ PRO-badge vid användarnamn
-- 
-- Användaren ser Pro-status vid nästa app-start! 🎉













