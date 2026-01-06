-- Hitta användarnamnet för Apple-kontot
-- ID: 1c754d07-1438-4441-902d-8125b6eb1f46
-- Email: s4w5jxym5b@privaterelay.appleid.com

-- HITTA ANVÄNDARNAMNET (name) FÖR DETTA KONTO:
SELECT 
    id,
    name as username,
    profile_image_url,
    total_workouts,
    created_at
FROM user_profiles
WHERE id = '1c754d07-1438-4441-902d-8125b6eb1f46';

-- Om inget resultat ovan, kolla om användaren finns i auth.users men inte i user_profiles:
SELECT 
    id,
    email,
    raw_user_meta_data->>'name' as name_from_metadata,
    raw_user_meta_data->>'full_name' as full_name_from_metadata,
    created_at
FROM auth.users
WHERE id = '1c754d07-1438-4441-902d-8125b6eb1f46';

