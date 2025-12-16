-- ============================================
-- FIX: Lottery Stats Function
-- Fungerar även om lottery_tickets tabellen inte finns
-- ============================================

-- Drop and recreate the function
DROP FUNCTION IF EXISTS get_lottery_stats(UUID);

CREATE OR REPLACE FUNCTION get_lottery_stats(p_user_id UUID)
RETURNS TABLE (
    my_tickets INTEGER,
    total_tickets INTEGER,
    my_percentage NUMERIC
) AS $$
DECLARE
    is_pro BOOLEAN;
    pro_multiplier NUMERIC;
    user_territory_tickets INTEGER;
    all_territory_tickets INTEGER;
BEGIN
    -- Check if user is Pro
    SELECT COALESCE(is_pro_member, false) INTO is_pro
    FROM public.profiles
    WHERE id = p_user_id;
    
    pro_multiplier := CASE WHEN is_pro THEN 1.5 ELSE 1.0 END;
    
    -- User's territory tickets (1 km² = 1 ticket, Pro gets 1.5x)
    SELECT FLOOR(COALESCE(SUM(area_m2) / 1000000, 0) * pro_multiplier)::INTEGER
    INTO user_territory_tickets
    FROM territories
    WHERE owner_id = p_user_id;
    
    -- Total territory tickets from ALL users (with their respective Pro multipliers)
    SELECT COALESCE(SUM(
        FLOOR(t.area_m2 / 1000000) * 
        CASE WHEN COALESCE(p.is_pro_member, false) THEN 1.5 ELSE 1.0 END
    ), 0)::INTEGER
    INTO all_territory_tickets
    FROM territories t
    LEFT JOIN profiles p ON t.owner_id = p.id;
    
    -- Return the stats
    RETURN QUERY SELECT 
        user_territory_tickets,
        all_territory_tickets,
        CASE WHEN all_territory_tickets > 0 
            THEN ROUND((user_territory_tickets::NUMERIC / all_territory_tickets) * 100, 2)
            ELSE 0::NUMERIC
        END;
END;
$$ LANGUAGE plpgsql SECURITY DEFINER;

-- Grant access
GRANT EXECUTE ON FUNCTION get_lottery_stats(UUID) TO authenticated;

-- Test the function (replace with your user ID)
-- SELECT * FROM get_lottery_stats('your-user-id-here');

