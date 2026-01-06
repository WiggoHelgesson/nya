-- 📊 RABATTKOD STATISTIK
-- Kör dessa queries i Supabase SQL Editor

-- 1️⃣ TOTALT ANTAL HÄMTADE RABATTKODER
SELECT COUNT(*) as total_purchases
FROM purchases;

-- 2️⃣ ANTAL HÄMTNINGAR PER VARUMÄRKE
SELECT 
    brand_name,
    COUNT(*) as purchase_count,
    discount
FROM purchases
GROUP BY brand_name, discount
ORDER BY purchase_count DESC;

-- 3️⃣ SENASTE 20 HÄMTNINGARNA
SELECT 
    brand_name,
    discount,
    discount_code,
    purchase_date,
    user_id
FROM purchases
ORDER BY purchase_date DESC
LIMIT 20;

-- 4️⃣ HÄMTNINGAR PER ANVÄNDARE (TOP 10)
SELECT 
    user_id,
    COUNT(*) as purchases,
    ARRAY_AGG(brand_name) as brands
FROM purchases
GROUP BY user_id
ORDER BY purchases DESC
LIMIT 10;

-- 5️⃣ HÄMTNINGAR PER DAG (SENASTE 30 DAGARNA)
SELECT 
    DATE(purchase_date) as date,
    COUNT(*) as purchases,
    ARRAY_AGG(DISTINCT brand_name) as brands
FROM purchases
WHERE purchase_date >= NOW() - INTERVAL '30 days'
GROUP BY DATE(purchase_date)
ORDER BY date DESC;

-- 6️⃣ MEST POPULÄRA RABATTKODER JUST NU
SELECT 
    brand_name,
    discount,
    COUNT(*) as total_redeemed,
    COUNT(CASE WHEN purchase_date >= NOW() - INTERVAL '7 days' THEN 1 END) as redeemed_last_7_days,
    COUNT(CASE WHEN purchase_date >= NOW() - INTERVAL '30 days' THEN 1 END) as redeemed_last_30_days,
    MAX(purchase_date) as last_redeemed
FROM purchases
GROUP BY brand_name, discount
ORDER BY redeemed_last_30_days DESC;

-- 7️⃣ GENOMSNITTLIGT ANTAL HÄMTNINGAR PER ANVÄNDARE
SELECT 
    AVG(user_purchases) as avg_purchases_per_user,
    MAX(user_purchases) as max_purchases_by_one_user
FROM (
    SELECT user_id, COUNT(*) as user_purchases
    FROM purchases
    GROUP BY user_id
) subquery;








