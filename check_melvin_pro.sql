-- =====================================================
-- KOLLA OM melvin.kernell@gmail.com ÄR PRO
-- =====================================================

-- 1️⃣ KOLLA I PROFILES (VIA JOIN MED AUTH.USERS)
SELECT 
    p.id,
    p.username,
    au.email,
    p.is_pro_member,
    p.current_xp,
    p.created_at,
    CASE 
        WHEN p.is_pro_member = true THEN '✅ ÄR PRO'
        ELSE '❌ INTE PRO'
    END as pro_status
FROM public.profiles p
JOIN auth.users au ON au.id = p.id
WHERE LOWER(au.email) = 'melvin.kernell@gmail.com';

-- 2️⃣ ALTERNATIV: KOLLA BARA I AUTH.USERS
SELECT 
    id,
    email,
    created_at,
    '🔍 Hittad i auth.users - kolla profiles för Pro status' as note
FROM auth.users
WHERE LOWER(email) = 'melvin.kernell@gmail.com';

-- =====================================================
-- OM DU VILL GE MELVIN PRO:
-- =====================================================
-- Avkommentera och kör denna om han inte är Pro:

-- UPDATE public.profiles
-- SET is_pro_member = true
-- WHERE id IN (
--     SELECT id 
--     FROM auth.users 
--     WHERE LOWER(email) = 'melvin.kernell@gmail.com'
-- );

-- -- Verifiera:
-- SELECT 
--     p.username,
--     au.email,
--     p.is_pro_member,
--     '✅ Nu är Melvin Pro!' as status
-- FROM public.profiles p
-- JOIN auth.users au ON au.id = p.id
-- WHERE LOWER(au.email) = 'melvin.kernell@gmail.com';












