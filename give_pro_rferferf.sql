-- =====================================================
-- GE RFERFERF PRO-STATUS
-- =====================================================
-- User ID: 18d278f8-7f96-4847-a360-660ff21ff3b4
-- Kör denna i Supabase SQL Editor

-- 1️⃣ GE PRO-STATUS
UPDATE public.profiles
SET is_pro_member = true
WHERE id = '18d278f8-7f96-4847-a360-660ff21ff3b4';

-- 2️⃣ VERIFIERA ATT DET FUNKADE
SELECT 
    id,
    username,
    email,
    is_pro_member,
    current_xp,
    current_level,
    created_at,
    CASE 
        WHEN is_pro_member THEN '✅ PRO AKTIV'
        ELSE '❌ INTE PRO'
    END as pro_status
FROM public.profiles
WHERE id = '18d278f8-7f96-4847-a360-660ff21ff3b4';

-- =====================================================
-- ✅ RESULTAT
-- =====================================================
-- Användaren "Rferferf" har nu Pro-status!
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











