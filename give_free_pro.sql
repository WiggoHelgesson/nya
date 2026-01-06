-- =====================================================
-- GE GRATIS PRO TILL KREATÖRER (UTAN REVENUECAT)
-- =====================================================

-- ✅ SYSTEMET ÄR REDAN UPPSATT!
-- Pro status = RevenueCat PRO OR Database PRO
-- Du kan ge folk Pro via databasen utan att det påverkar RevenueCat

-- =====================================================
-- 1️⃣ GE EN PERSON PRO (VIA EMAIL)
-- =====================================================

UPDATE public.profiles
SET is_pro_member = true
WHERE email = 'ANGE_EMAIL_HÄR';

-- Exempel:
-- UPDATE public.profiles
-- SET is_pro_member = true
-- WHERE email = 'kreator@example.com';


-- =====================================================
-- 2️⃣ GE EN PERSON PRO (VIA USERNAME)
-- =====================================================

UPDATE public.profiles
SET is_pro_member = true
WHERE username = 'ANGE_USERNAME_HÄR';

-- Exempel:
-- UPDATE public.profiles
-- SET is_pro_member = true
-- WHERE username = 'coolkreator123';


-- =====================================================
-- 3️⃣ GE EN PERSON PRO (VIA USER ID)
-- =====================================================

UPDATE public.profiles
SET is_pro_member = true
WHERE id = 'ANGE_USER_ID_HÄR';


-- =====================================================
-- 4️⃣ TA BORT PRO FRÅN EN PERSON
-- =====================================================

UPDATE public.profiles
SET is_pro_member = false
WHERE email = 'ANGE_EMAIL_HÄR';


-- =====================================================
-- 5️⃣ GE FLERA PERSONER PRO SAMTIDIGT
-- =====================================================

UPDATE public.profiles
SET is_pro_member = true
WHERE email IN (
    'kreator1@example.com',
    'kreator2@example.com',
    'kreator3@example.com'
);


-- =====================================================
-- 6️⃣ SE ALLA SOM HAR PRO (VIA DATABAS ELLER REVENUECAT)
-- =====================================================

SELECT 
    id,
    username,
    email,
    is_pro_member,
    created_at
FROM public.profiles
WHERE is_pro_member = true
ORDER BY created_at DESC;


-- =====================================================
-- 7️⃣ KOLLA OM EN SPECIFIK PERSON HAR PRO
-- =====================================================

SELECT 
    username,
    email,
    is_pro_member,
    CASE 
        WHEN is_pro_member THEN '✅ PRO'
        ELSE '❌ INTE PRO'
    END as pro_status
FROM public.profiles
WHERE email = 'ANGE_EMAIL_HÄR';


-- =====================================================
-- EXEMPEL: GE EMIL PRO
-- =====================================================

UPDATE public.profiles
SET is_pro_member = true
WHERE email = 'carlemilsandbergg@gmail.com';

-- Kolla att det funkade:
SELECT username, email, is_pro_member 
FROM public.profiles 
WHERE email = 'carlemilsandbergg@gmail.com';








