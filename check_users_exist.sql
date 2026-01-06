-- =====================================================
-- KOLLA OM ANVÄNDARNA FINNS I DATABASEN
-- =====================================================

-- 1️⃣ KOLLA OM EMAIL-KOLUMN FINNS I PROFILES
SELECT column_name, data_type 
FROM information_schema.columns 
WHERE table_name = 'profiles' 
AND table_schema = 'public'
ORDER BY ordinal_position;

-- 2️⃣ SE ALLA KOLUMNER OCH 5 EXEMPEL-RADER
SELECT * FROM public.profiles LIMIT 5;

-- 3️⃣ SÖK I AUTH.USERS ISTÄLLET (här finns alltid email)
SELECT 
    id,
    email,
    created_at
FROM auth.users
WHERE email IN (
    'carlemilsanbergg@gmail.com',
    'gurraglind460@gmail.com',
    'landebladwilliam11@gmail.com',
    'jordieliss@gmail.com',
    'victoredstrom08@icloud.com',
    'fredriksonjohan67@gmail.com',
    'gabbetrulsson9@gmail.com'
)
ORDER BY email;

-- 4️⃣ KOLLA CASE-INSENSITIVE (ibland är det stora/små bokstäver)
SELECT 
    id,
    email,
    created_at
FROM auth.users
WHERE LOWER(email) IN (
    'carlemilsanbergg@gmail.com',
    'gurraglind460@gmail.com',
    'landebladwilliam11@gmail.com',
    'jordieliss@gmail.com',
    'victoredstrom08@icloud.com',
    'fredriksonjohan67@gmail.com',
    'gabbetrulsson9@gmail.com'
)
ORDER BY email;

-- 5️⃣ SE ALLA ANVÄNDARE I PROFILES (för att se strukturen)
SELECT 
    id,
    username,
    is_pro_member,
    created_at
FROM public.profiles
ORDER BY created_at DESC
LIMIT 10;

-- 6️⃣ RÄKNA TOTALT ANTAL PRO-MEDLEMMAR
SELECT 
    COUNT(*) as total_pro,
    COUNT(*) FILTER (WHERE is_pro_member = true) as currently_pro
FROM public.profiles;








