-- =====================================================
-- GE 6 BEKRÄFTADE ANVÄNDARE PRO-STATUS
-- =====================================================
-- Användare hittade i auth.users

-- 1️⃣ GE ALLA 6 PRO VIA DERAS ID:N
UPDATE public.profiles
SET is_pro_member = true
WHERE id IN (
    'e9692525-b360-41b9-a5e5-d06d25a3045a',  -- fredriksonjohan67@gmail.com
    '2b867a52-8f63-4653-8105-9bb8bae42081',  -- gabbetrulsson9@gmail.com
    '4b5387d6-134c-46ca-aac0-e5a50a48ea88',  -- gurraglind460@gmail.com
    'b4feb087-7e65-4449-adf4-55e13f17c869',  -- jordieliss@gmail.com
    '1ca87ea0-4fd3-41ce-93ed-cbe9590c22c2',  -- landebladwilliam11@gmail.com
    'e9ceea42-d1cf-4fac-860b-6c17a7fa5827'   -- victoredstrom08@icloud.com
);

-- 2️⃣ VERIFIERA ALLA 6 MED EMAIL OCH PRO-STATUS
SELECT 
    p.id,
    p.username,
    au.email,
    p.is_pro_member,
    p.current_xp,
    CASE 
        WHEN p.is_pro_member THEN '✅ PRO AKTIV'
        ELSE '❌ INTE PRO'
    END as pro_status
FROM public.profiles p
JOIN auth.users au ON au.id = p.id
WHERE p.id IN (
    'e9692525-b360-41b9-a5e5-d06d25a3045a',
    '2b867a52-8f63-4653-8105-9bb8bae42081',
    '4b5387d6-134c-46ca-aac0-e5a50a48ea88',
    'b4feb087-7e65-4449-adf4-55e13f17c869',
    '1ca87ea0-4fd3-41ce-93ed-cbe9590c22c2',
    'e9ceea42-d1cf-4fac-860b-6c17a7fa5827'
)
ORDER BY au.email;

-- 3️⃣ RÄKNA UPPDATERADE RADER (ska visa 6)
SELECT COUNT(*) as antal_pro_uppdaterade
FROM public.profiles
WHERE id IN (
    'e9692525-b360-41b9-a5e5-d06d25a3045a',
    '2b867a52-8f63-4653-8105-9bb8bae42081',
    '4b5387d6-134c-46ca-aac0-e5a50a48ea88',
    'b4feb087-7e65-4449-adf4-55e13f17c869',
    '1ca87ea0-4fd3-41ce-93ed-cbe9590c22c2',
    'e9ceea42-d1cf-4fac-860b-6c17a7fa5827'
)
AND is_pro_member = true;

-- =====================================================
-- ✅ RESULTAT
-- =====================================================
-- Dessa 6 användare har nu Pro-status:
-- 
-- 1. ✅ fredriksonjohan67@gmail.com
-- 2. ✅ gabbetrulsson9@gmail.com
-- 3. ✅ gurraglind460@gmail.com
-- 4. ✅ jordieliss@gmail.com
-- 5. ✅ landebladwilliam11@gmail.com
-- 6. ✅ victoredstrom08@icloud.com
-- 
-- OBS: carlemilsanbergg@gmail.com hittades INTE i systemet
-- (stavning eller har inte skapat konto än)
-- 
-- De får nu:
-- ✅ Månadens pris (full tillgång)
-- ✅ 2x poäng i Zonkriget
-- ✅ Obegränsade övningar
-- ✅ Obegränsad AI-chat med UPPY
-- ✅ Full veckostatistik
-- ✅ PRO-badge vid användarnamn
-- 
-- Användarna ser Pro-status vid nästa app-start! 🎉








