-- Query to check for golf trainer applications
-- Filters for profiles that exist in trainer_profiles table
-- is_active = false usually indicates a pending or inactive application

SELECT 
    tp.user_id,
    p.username,
    tp.first_name, 
    tp.last_name, 
    tp.is_active,
    tp.created_at
FROM public.trainer_profiles tp
LEFT JOIN public.profiles p ON tp.user_id = p.id
ORDER BY tp.created_at DESC;

