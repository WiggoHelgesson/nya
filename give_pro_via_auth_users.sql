-- =====================================================
-- GE PRO VIA AUTH.USERS → PROFILES (JOIN)
-- =====================================================
-- Om email inte finns i profiles, använd denna metod istället!

-- 1️⃣ GE PRO GENOM ATT MATCHA MED AUTH.USERS
UPDATE public.profiles
SET is_pro_member = true
WHERE id IN (
    SELECT id 
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
);

-- 2️⃣ VERIFIERA GENOM ATT JOINA AUTH.USERS OCH PROFILES
SELECT 
    p.id,
    p.username,
    au.email,
    p.is_pro_member,
    p.current_xp,
    CASE 
        WHEN p.is_pro_member THEN '✅ PRO AKTIV'
        ELSE '❌ INTE PRO'
    END as pro_status
FROM public.profiles p
JOIN auth.users au ON au.id = p.id
WHERE LOWER(au.email) IN (
    'carlemilsanbergg@gmail.com',
    'gurraglind460@gmail.com',
    'landebladwilliam11@gmail.com',
    'jordieliss@gmail.com',
    'victoredstrom08@icloud.com',
    'fredriksonjohan67@gmail.com',
    'gabbetrulsson9@gmail.com'
)
ORDER BY au.email;

-- 3️⃣ KOLLA VILKA EMAIL SOM INTE FINNS I SYSTEMET
SELECT 
    email_to_check,
    CASE 
        WHEN EXISTS (SELECT 1 FROM auth.users WHERE LOWER(email) = email_to_check) 
        THEN '✅ FINNS' 
        ELSE '❌ FINNS INTE'
    END as status
FROM (
    VALUES 
        ('carlemilsanbergg@gmail.com'),
        ('gurraglind460@gmail.com'),
        ('landebladwilliam11@gmail.com'),
        ('jordieliss@gmail.com'),
        ('victoredstrom08@icloud.com'),
        ('fredriksonjohan67@gmail.com'),
        ('gabbetrulsson9@gmail.com')
) AS emails(email_to_check);











