-- =====================================================
-- HITTA DITT USER_ID
-- =====================================================

-- Sök efter ditt username eller email
SELECT 
    id as user_id,
    username,
    email
FROM public.profiles p
LEFT JOIN auth.users au ON au.id = p.id
WHERE 
    username ILIKE '%wiggo%'  -- Byt ut mot ditt användarnamn
    OR au.email ILIKE '%wiggo%'  -- Byt ut mot din email
LIMIT 10;

-- =====================================================
-- ANVÄND user_id i DEBUG_lottery_mismatch.sql
-- =====================================================













