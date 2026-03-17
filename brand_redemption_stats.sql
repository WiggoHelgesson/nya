-- RABATTBELÖNINGAR PER VARUMÄRKE
-- Kör dessa queries i Supabase SQL Editor

-- 1. ÖVERSIKT PER VARUMÄRKE
SELECT
    brand_name,
    COUNT(*) AS total_redemptions,
    COUNT(DISTINCT user_id) AS unique_users,
    MIN(purchase_date) AS first_redemption,
    MAX(purchase_date) AS last_redemption
FROM purchases
GROUP BY brand_name
ORDER BY total_redemptions DESC;

-- 2. DETALJERAD PER VARUMÄRKE OCH RABATT
SELECT
    brand_name,
    discount,
    COUNT(*) AS total_redemptions,
    COUNT(DISTINCT user_id) AS unique_users
FROM purchases
GROUP BY brand_name, discount
ORDER BY brand_name, total_redemptions DESC;

-- 3. TRENDER SENASTE 30 DAGARNA PER VARUMÄRKE
SELECT
    brand_name,
    COUNT(*) AS total_redemptions,
    COUNT(DISTINCT user_id) AS unique_users,
    COUNT(CASE WHEN purchase_date >= NOW() - INTERVAL '7 days' THEN 1 END) AS last_7_days,
    COUNT(CASE WHEN purchase_date >= NOW() - INTERVAL '30 days' THEN 1 END) AS last_30_days
FROM purchases
WHERE purchase_date >= NOW() - INTERVAL '30 days'
GROUP BY brand_name
ORDER BY last_7_days DESC;

-- 4. GENOMSNITTLIGA INLÖSNINGAR PER ANVÄNDARE PER VARUMÄRKE
SELECT
    brand_name,
    COUNT(*) AS total_redemptions,
    COUNT(DISTINCT user_id) AS unique_users,
    ROUND(COUNT(*)::numeric / COUNT(DISTINCT user_id), 2) AS avg_per_user
FROM purchases
GROUP BY brand_name
ORDER BY avg_per_user DESC;
