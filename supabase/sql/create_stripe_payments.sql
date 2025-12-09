-- =====================================================
-- STRIPE PAYMENTS SYSTEM
-- =====================================================

-- Store Stripe customer IDs
CREATE TABLE IF NOT EXISTS public.stripe_customers (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    user_id UUID NOT NULL REFERENCES auth.users(id) ON DELETE CASCADE,
    stripe_customer_id TEXT NOT NULL UNIQUE,
    created_at TIMESTAMPTZ DEFAULT now(),
    UNIQUE(user_id)
);

-- Store lesson payments
CREATE TABLE IF NOT EXISTS public.lesson_payments (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    student_id UUID NOT NULL REFERENCES auth.users(id) ON DELETE CASCADE,
    trainer_id UUID NOT NULL REFERENCES public.trainer_profiles(id) ON DELETE CASCADE,
    booking_id UUID REFERENCES public.trainer_bookings(id) ON DELETE SET NULL,
    amount INTEGER NOT NULL, -- in öre (cents)
    currency TEXT NOT NULL DEFAULT 'sek',
    stripe_payment_intent_id TEXT,
    stripe_charge_id TEXT,
    status TEXT NOT NULL DEFAULT 'pending' CHECK (status IN ('pending', 'succeeded', 'failed', 'refunded')),
    created_at TIMESTAMPTZ DEFAULT now(),
    updated_at TIMESTAMPTZ DEFAULT now()
);

-- Indexes
CREATE INDEX IF NOT EXISTS lesson_payments_student_idx ON public.lesson_payments(student_id);
CREATE INDEX IF NOT EXISTS lesson_payments_trainer_idx ON public.lesson_payments(trainer_id);
CREATE INDEX IF NOT EXISTS lesson_payments_status_idx ON public.lesson_payments(status);
CREATE INDEX IF NOT EXISTS lesson_payments_stripe_pi_idx ON public.lesson_payments(stripe_payment_intent_id);

-- Enable RLS
ALTER TABLE public.stripe_customers ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.lesson_payments ENABLE ROW LEVEL SECURITY;

-- Policies for stripe_customers
CREATE POLICY stripe_customers_select ON public.stripe_customers
    FOR SELECT USING (auth.uid() = user_id);

CREATE POLICY stripe_customers_insert ON public.stripe_customers
    FOR INSERT WITH CHECK (auth.uid() = user_id);

-- Policies for lesson_payments
CREATE POLICY lesson_payments_select ON public.lesson_payments
    FOR SELECT USING (
        auth.uid() = student_id OR 
        auth.uid() IN (SELECT user_id FROM public.trainer_profiles WHERE id = trainer_id)
    );

CREATE POLICY lesson_payments_insert ON public.lesson_payments
    FOR INSERT WITH CHECK (auth.uid() = student_id);

CREATE POLICY lesson_payments_update ON public.lesson_payments
    FOR UPDATE USING (
        auth.uid() = student_id OR 
        auth.uid() IN (SELECT user_id FROM public.trainer_profiles WHERE id = trainer_id)
    );

-- Grants
GRANT SELECT, INSERT ON public.stripe_customers TO authenticated;
GRANT SELECT, INSERT, UPDATE ON public.lesson_payments TO authenticated;

-- Function to check if user has paid for trainer
CREATE OR REPLACE FUNCTION public.has_paid_for_trainer(p_trainer_id UUID)
RETURNS BOOLEAN
LANGUAGE plpgsql
SECURITY DEFINER
AS $$
BEGIN
    RETURN EXISTS (
        SELECT 1 FROM public.lesson_payments
        WHERE student_id = auth.uid()
        AND trainer_id = p_trainer_id
        AND status = 'succeeded'
    );
END;
$$;

GRANT EXECUTE ON FUNCTION public.has_paid_for_trainer(UUID) TO authenticated;

-- View: payments with user info
CREATE OR REPLACE VIEW public.lesson_payments_with_users AS
SELECT 
    lp.*,
    tp.name as trainer_name,
    tp.avatar_url as trainer_avatar_url,
    p.username as student_username,
    p.avatar_url as student_avatar_url
FROM public.lesson_payments lp
JOIN public.trainer_profiles tp ON lp.trainer_id = tp.id
LEFT JOIN public.profiles p ON lp.student_id = p.id
WHERE auth.uid() = lp.student_id OR auth.uid() = tp.user_id;

GRANT SELECT ON public.lesson_payments_with_users TO authenticated;


