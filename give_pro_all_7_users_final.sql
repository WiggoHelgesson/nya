-- =====================================================
-- GE ALLA 7 ANVÄNDARE PRO-STATUS (KOMPLETT LISTA)
-- =====================================================

-- 1️⃣ GE ALLA 7 PRO VIA DERAS ID:N
UPDATE public.profiles
SET is_pro_member = true
WHERE id IN (
    'c4420100-6171-414f-89c5-e1fea19b8a12',  -- carlemilsandbergg@gmail.com ✅ TILLAGD
    'e9692525-b360-41b9-a5e5-d06d25a3045a',  -- fredriksonjohan67@gmail.com
    '2b867a52-8f63-4653-8105-9bb8bae42081',  -- gabbetrulsson9@gmail.com
    '4b5387d6-134c-46ca-aac0-e5a50a48ea88',  -- gurraglind460@gmail.com
    'b4feb087-7e65-4449-adf4-55e13f17c869',  -- jordieliss@gmail.com
    '1ca87ea0-4fd3-41ce-93ed-cbe9590c22c2',  -- landebladwilliam11@gmail.com
    'e9ceea42-d1cf-4fac-860b-6c17a7fa5827'   -- victoredstrom08@icloud.com
);

-- 2️⃣ VERIFIERA ALLA 7 MED EMAIL OCH PRO-STATUS
SELECT 
    p.id,
    p.username,
    au.email,
    p.is_pro_member,
    CASE 
        WHEN p.is_pro_member THEN '✅ PRO AKTIV'
        ELSE '❌ INTE PRO'
    END as pro_status
FROM public.profiles p
JOIN auth.users au ON au.id = p.id
WHERE p.id IN (
    'c4420100-6171-414f-89c5-e1fea19b8a12',
    'e9692525-b360-41b9-a5e5-d06d25a3045a',
    '2b867a52-8f63-4653-8105-9bb8bae42081',
    '4b5387d6-134c-46ca-aac0-e5a50a48ea88',
    'b4feb087-7e65-4449-adf4-55e13f17c869',
    '1ca87ea0-4fd3-41ce-93ed-cbe9590c22c2',
    'e9ceea42-d1cf-4fac-860b-6c17a7fa5827'
)
ORDER BY au.email;

-- 3️⃣ RÄKNA UPPDATERADE RADER (ska visa 7)
SELECT COUNT(*) as antal_pro_medlemmar
FROM public.profiles
WHERE id IN (
    'c4420100-6171-414f-89c5-e1fea19b8a12',
    'e9692525-b360-41b9-a5e5-d06d25a3045a',
    '2b867a52-8f63-4653-8105-9bb8bae42081',
    '4b5387d6-134c-46ca-aac0-e5a50a48ea88',
    'b4feb087-7e65-4449-adf4-55e13f17c869',
    '1ca87ea0-4fd3-41ce-93ed-cbe9590c22c2',
    'e9ceea42-d1cf-4fac-860b-6c17a7fa5827'
)
AND is_pro_member = true;

-- =====================================================
-- ✅ ALLA 7 ANVÄNDARE HAR NU PRO-STATUS
-- =====================================================
-- 1. ✅ carlemilsandbergg@gmail.com (hittad med dubbel-g!)
-- 2. ✅ fredriksonjohan67@gmail.com
-- 3. ✅ gabbetrulsson9@gmail.com
-- 4. ✅ gurraglind460@gmail.com
-- 5. ✅ jordieliss@gmail.com
-- 6. ✅ landebladwilliam11@gmail.com
-- 7. ✅ victoredstrom08@icloud.com
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












