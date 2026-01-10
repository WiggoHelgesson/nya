-- =====================================================
-- HITTA carlemilsanbergg@gmail.com
-- =====================================================
-- Denna användare fanns inte i första sökningen

-- 1️⃣ SÖK EXAKT STAVNING
SELECT id, email, created_at
FROM auth.users
WHERE email = 'carlemilsanbergg@gmail.com';

-- 2️⃣ SÖK CASE-INSENSITIVE
SELECT id, email, created_at
FROM auth.users
WHERE LOWER(email) = 'carlemilsanbergg@gmail.com';

-- 3️⃣ SÖK LIKNANDE STAVNINGAR (kanske stavfel?)
SELECT id, email, created_at
FROM auth.users
WHERE email ILIKE '%carlemil%'
   OR email ILIKE '%sandberg%'
   OR email ILIKE '%sanberg%'
ORDER BY email;

-- 4️⃣ SÖK I PROFILES PÅ USERNAME
SELECT p.id, p.username, au.email
FROM public.profiles p
LEFT JOIN auth.users au ON au.id = p.id
WHERE p.username ILIKE '%carlemil%'
   OR p.username ILIKE '%emil%'
   OR p.username ILIKE '%sandberg%';

-- =====================================================
-- Om du hittar rätt email, kör denna:
-- =====================================================
-- UPDATE public.profiles
-- SET is_pro_member = true
-- WHERE id = 'ANGE_RÄTT_ID_HÄR';











