-- ============================================================
-- Pro Free Product Reward
-- PRO-medlemmar tjänar en gratisprodukt från Vår shop var 3:e
-- sammanhängande månad som aktiv PRO-medlem.
--
-- Kör i Supabase SQL Editor. Idempotent.
-- ============================================================

-- Kostnadstak för gratisprodukter (kr, jämförs mot produktens pris i shoppen)
ALTER TABLE public.app_config
    ADD COLUMN IF NOT EXISTS max_reward_cost integer DEFAULT 500;

-- ------------------------------------------------------------
-- Tabell: pro_reward_progress
-- En rad per användare; period_start = när nuvarande
-- 3-månadersperiod började. NULL = ingen aktiv intjäning.
-- ------------------------------------------------------------
CREATE TABLE IF NOT EXISTS public.pro_reward_progress (
    user_id uuid PRIMARY KEY REFERENCES auth.users(id) ON DELETE CASCADE,
    period_start timestamptz,
    updated_at timestamptz NOT NULL DEFAULT now()
);

ALTER TABLE public.pro_reward_progress ENABLE ROW LEVEL SECURITY;

DROP POLICY IF EXISTS "Users can read own reward progress" ON public.pro_reward_progress;
CREATE POLICY "Users can read own reward progress"
    ON public.pro_reward_progress FOR SELECT
    USING (auth.uid() = user_id);

-- Skrivningar sker endast via SECURITY DEFINER-funktionerna nedan.

-- ------------------------------------------------------------
-- Tabell: free_product_rewards
-- En rad per intjänad reward. UNIQUE (user_id, period_start)
-- gör att samma period aldrig kan ge två rewards.
-- ------------------------------------------------------------
CREATE TABLE IF NOT EXISTS public.free_product_rewards (
    id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
    user_id uuid NOT NULL REFERENCES auth.users(id) ON DELETE CASCADE,
    status text NOT NULL DEFAULT 'earned' CHECK (status IN ('earned', 'redeemed')),
    period_start timestamptz NOT NULL,
    earned_at timestamptz NOT NULL DEFAULT now(),
    redeemed_at timestamptz,
    product_id text,
    product_title text,
    discount_code text,
    order_id text,
    UNIQUE (user_id, period_start)
);

CREATE INDEX IF NOT EXISTS idx_free_product_rewards_user
    ON public.free_product_rewards (user_id, status);

ALTER TABLE public.free_product_rewards ENABLE ROW LEVEL SECURITY;

DROP POLICY IF EXISTS "Users can read own rewards" ON public.free_product_rewards;
CREATE POLICY "Users can read own rewards"
    ON public.free_product_rewards FOR SELECT
    USING (auth.uid() = user_id);

-- Skrivningar sker endast via SECURITY DEFINER-funktionerna nedan.

-- ------------------------------------------------------------
-- RPC: sync_free_reward_progress()
-- Anropas av appen (t.ex. när shoppen öppnas). Uppdaterar
-- progress utifrån nuvarande Pro-status och skapar earned-
-- rewards när 3 månader uppnåtts. Returnerar aktuell status.
--
-- Regler:
--  * Aktiv Pro utan period_start         -> starta ny period nu
--  * Aktiv Pro och 3 mån passerade       -> skapa reward, rulla perioden
--  * Ej Pro men betald period kvar       -> progress fortsätter (pausas ej)
--  * Ej Pro och utgånget                 -> progress nollställs
-- ------------------------------------------------------------
CREATE OR REPLACE FUNCTION public.sync_free_reward_progress()
RETURNS TABLE (
    is_pro boolean,
    period_start timestamptz,
    days_remaining integer,
    earned_count integer
)
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public
AS $$
DECLARE
    v_user_id uuid := auth.uid();
    v_is_pro boolean := false;
    v_expires_at timestamptz;
    v_period_start timestamptz;
    v_effective_pro boolean;
BEGIN
    IF v_user_id IS NULL THEN
        RAISE EXCEPTION 'Not authenticated';
    END IF;

    SELECT COALESCE(p.is_pro_member, false), p.pro_membership_expires_at
    INTO v_is_pro, v_expires_at
    FROM profiles p
    WHERE p.id = v_user_id;

    -- Uppsagd men fortfarande inom betald period räknas som aktiv
    v_effective_pro := v_is_pro OR (v_expires_at IS NOT NULL AND v_expires_at > now());

    INSERT INTO pro_reward_progress (user_id, period_start, updated_at)
    VALUES (v_user_id, NULL, now())
    ON CONFLICT (user_id) DO NOTHING;

    SELECT prp.period_start INTO v_period_start
    FROM pro_reward_progress prp
    WHERE prp.user_id = v_user_id
    FOR UPDATE;

    IF v_effective_pro THEN
        IF v_period_start IS NULL THEN
            v_period_start := now();
        END IF;

        -- Skapa rewards för varje fullbordad 3-månadersperiod
        WHILE now() >= v_period_start + interval '3 months' LOOP
            INSERT INTO free_product_rewards (user_id, status, period_start)
            VALUES (v_user_id, 'earned', v_period_start)
            ON CONFLICT (user_id, period_start) DO NOTHING;

            v_period_start := v_period_start + interval '3 months';
        END LOOP;
    ELSE
        -- Prenumeration utgången: nollställ progress
        v_period_start := NULL;
    END IF;

    UPDATE pro_reward_progress prp
    SET period_start = v_period_start,
        updated_at = now()
    WHERE prp.user_id = v_user_id;

    RETURN QUERY
    SELECT
        v_effective_pro,
        v_period_start,
        CASE
            WHEN v_period_start IS NULL THEN NULL::integer
            ELSE GREATEST(
                0,
                CEIL(EXTRACT(EPOCH FROM (v_period_start + interval '3 months' - now())) / 86400.0)::integer
            )
        END,
        (
            SELECT COUNT(*)::integer
            FROM free_product_rewards fpr
            WHERE fpr.user_id = v_user_id AND fpr.status = 'earned'
        );
END;
$$;

GRANT EXECUTE ON FUNCTION public.sync_free_reward_progress() TO authenticated;

-- ------------------------------------------------------------
-- RPC: redeem_free_reward(...)
-- Markerar en earned-reward som redeemed atomiskt. Returnerar
-- true om inlösen lyckades, false om rewarden inte fanns/redan
-- var inlöst (kan därför aldrig lösas in två gånger).
-- Anropas av edge-funktionen redeem-free-reward (service role)
-- med explicit user-id, eller direkt av klienten (auth.uid()).
-- ------------------------------------------------------------
CREATE OR REPLACE FUNCTION public.redeem_free_reward(
    p_reward_id uuid,
    p_user_id uuid,
    p_product_id text,
    p_product_title text,
    p_discount_code text,
    p_order_id text DEFAULT NULL
)
RETURNS boolean
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public
AS $$
DECLARE
    v_caller uuid := auth.uid();
    v_updated integer;
BEGIN
    -- Klient-anrop får bara lösa in sina egna rewards;
    -- service role (v_caller IS NULL) får ange användare.
    IF v_caller IS NOT NULL AND v_caller <> p_user_id THEN
        RAISE EXCEPTION 'Cannot redeem rewards for another user';
    END IF;

    UPDATE free_product_rewards
    SET status = 'redeemed',
        redeemed_at = now(),
        product_id = p_product_id,
        product_title = p_product_title,
        discount_code = p_discount_code,
        order_id = p_order_id
    WHERE id = p_reward_id
      AND user_id = p_user_id
      AND status = 'earned';

    GET DIAGNOSTICS v_updated = ROW_COUNT;
    RETURN v_updated > 0;
END;
$$;

GRANT EXECUTE ON FUNCTION public.redeem_free_reward(uuid, uuid, text, text, text, text) TO authenticated;
GRANT EXECUTE ON FUNCTION public.redeem_free_reward(uuid, uuid, text, text, text, text) TO service_role;
