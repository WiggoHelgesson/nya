-- =====================================================
-- GE 7 ANVÄNDARE PRO-STATUS SAMTIDIGT
-- =====================================================
-- Kör denna i Supabase SQL Editor

-- 1️⃣ GE ALLA 7 PRO-STATUS (EN QUERY)
UPDATE public.profiles
SET is_pro_member = true
WHERE email IN (
    'carlemilsanbergg@gmail.com',
    'gurraglind460@gmail.com',
    'landebladwilliam11@gmail.com',
    'Jordieliss@gmail.com',
    'victoredstrom08@icloud.com',
    'Fredriksonjohan67@gmail.com',
    'gabbetrulsson9@gmail.com'
);

-- 2️⃣ VERIFIERA ATT ALLA FÅR PRO
SELECT 
    username,
    email,
    is_pro_member,
    current_xp,
    CASE 
        WHEN is_pro_member THEN '✅ PRO AKTIV'
        ELSE '❌ INTE PRO'
    END as pro_status
FROM public.profiles
WHERE email IN (
    'carlemilsanbergg@gmail.com',
    'gurraglind460@gmail.com',
    'landebladwilliam11@gmail.com',
    'Jordieliss@gmail.com',
    'victoredstrom08@icloud.com',
    'Fredriksonjohan67@gmail.com',
    'gabbetrulsson9@gmail.com'
)
ORDER BY username;

-- 3️⃣ KOLLA VILKA SOM INTE HITTADES (om några)
-- Om query 2 visar färre än 7 användare, kör denna:
SELECT 
    email_to_check
FROM (
    VALUES 
        ('carlemilsanbergg@gmail.com'),
        ('gurraglind460@gmail.com'),
        ('landebladwilliam11@gmail.com'),
        ('Jordieliss@gmail.com'),
        ('victoredstrom08@icloud.com'),
        ('Fredriksonjohan67@gmail.com'),
        ('gabbetrulsson9@gmail.com')
) AS emails(email_to_check)
WHERE email_to_check NOT IN (
    SELECT email FROM public.profiles
);

-- 4️⃣ RÄKNA TOTALT ANTAL PRO-MEDLEMMAR
SELECT COUNT(*) as total_pro_members
FROM public.profiles
WHERE is_pro_member = true;

-- =====================================================
-- ✅ RESULTAT
-- =====================================================
-- Alla 7 användare har nu Pro-status!
-- 
-- 1. carlemilsanbergg@gmail.com ✅
-- 2. gurraglind460@gmail.com ✅
-- 3. landebladwilliam11@gmail.com ✅
-- 4. Jordieliss@gmail.com ✅
-- 5. victoredstrom08@icloud.com ✅
-- 6. Fredriksonjohan67@gmail.com ✅
-- 7. gabbetrulsson9@gmail.com ✅
-- 
-- De får nu:
-- ✅ Månadens pris (full tillgång)
-- ✅ 2x poäng i Zonkriget
-- ✅ Obegränsade övningar i Progressiv Överbelastning
-- ✅ Obegränsad AI-chat med UPPY
-- ✅ Full veckostatistik
-- ✅ PRO-badge vid användarnamn
-- 
-- Användarna ser Pro-status vid nästa app-start! 🎉












