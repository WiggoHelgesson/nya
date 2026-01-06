-- ⚡ SNABB ÖVERSIKT - RABATTKOD STATISTIK

-- Kör denna i Supabase SQL Editor för en snabb översikt:

WITH stats AS (
    SELECT 
        '📊 TOTALT' as kategori,
        COUNT(*)::text as antal,
        '' as detalj,
        1 as sort_order
    FROM purchases
    
    UNION ALL
    
    SELECT 
        '📅 SENASTE 7 DAGARNA' as kategori,
        COUNT(*)::text as antal,
        '' as detalj,
        2 as sort_order
    FROM purchases
    WHERE purchase_date >= NOW() - INTERVAL '7 days'
    
    UNION ALL
    
    SELECT 
        '📅 SENASTE 30 DAGARNA' as kategori,
        COUNT(*)::text as antal,
        '' as detalj,
        3 as sort_order
    FROM purchases
    WHERE purchase_date >= NOW() - INTERVAL '30 days'
    
    UNION ALL
    
    SELECT 
        '👥 UNIKA ANVÄNDARE' as kategori,
        COUNT(DISTINCT user_id)::text as antal,
        '' as detalj,
        4 as sort_order
    FROM purchases
),
top_brand AS (
    SELECT 
        '🏆 POPULÄRASTE VARUMÄRKE' as kategori,
        brand_name as antal,
        COUNT(*)::text || ' hämtningar' as detalj,
        5 as sort_order
    FROM purchases
    GROUP BY brand_name
    ORDER BY COUNT(*) DESC
    LIMIT 1
)
SELECT kategori, antal, detalj
FROM (
    SELECT * FROM stats
    UNION ALL
    SELECT * FROM top_brand
) combined
ORDER BY sort_order;

