-- =====================================================
-- HITTA EMAIL FÖR ANVÄNDARE "Rferferf"
-- =====================================================

-- 1️⃣ SÖK PÅ EXAKT USERNAME
SELECT 
    id,
    username,
    email,
    is_pro_member,
    current_xp,
    current_level,
    created_at
FROM public.profiles
WHERE username = 'Rferferf';

-- 2️⃣ SÖK PÅ LIKNANDE USERNAME (case-insensitive)
SELECT 
    id,
    username,
    email,
    is_pro_member,
    current_xp,
    current_level,
    created_at
FROM public.profiles
WHERE username ILIKE '%Rferferf%';

-- 3️⃣ SÖK PÅ ALLA ANVÄNDARE MED LIKNANDE NAMN
SELECT 
    id,
    username,
    email,
    is_pro_member,
    current_xp,
    current_level,
    created_at
FROM public.profiles
WHERE username ILIKE '%rferf%'
ORDER BY created_at DESC;

-- 4️⃣ HITTA SENAST SKAPADE KONTON (om det är nytt)
SELECT 
    id,
    username,
    email,
    is_pro_member,
    created_at
FROM public.profiles
ORDER BY created_at DESC
LIMIT 20;











