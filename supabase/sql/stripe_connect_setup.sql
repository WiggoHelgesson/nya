-- =====================================================
-- STRIPE CONNECT SETUP FOR TRAINER PAYOUTS
-- =====================================================
-- This script adds Stripe Connect fields to trainer_profiles
-- to enable payouts to trainers when students book lessons.
--
-- Platform fee: 15%
-- Account type: Express (via controller properties)
-- =====================================================

-- Add Stripe Connect columns to trainer_profiles
ALTER TABLE public.trainer_profiles 
ADD COLUMN IF NOT EXISTS stripe_account_id TEXT,
ADD COLUMN IF NOT EXISTS stripe_onboarding_complete BOOLEAN DEFAULT FALSE,
ADD COLUMN IF NOT EXISTS stripe_payouts_enabled BOOLEAN DEFAULT FALSE,
ADD COLUMN IF NOT EXISTS stripe_charges_enabled BOOLEAN DEFAULT FALSE;

-- Add index for faster lookups
CREATE INDEX IF NOT EXISTS idx_trainer_profiles_stripe_account_id 
ON public.trainer_profiles(stripe_account_id);

-- Comment on columns for documentation
COMMENT ON COLUMN public.trainer_profiles.stripe_account_id IS 'Stripe Connect account ID (acct_xxx)';
COMMENT ON COLUMN public.trainer_profiles.stripe_onboarding_complete IS 'Whether trainer has completed Stripe onboarding';
COMMENT ON COLUMN public.trainer_profiles.stripe_payouts_enabled IS 'Whether payouts are enabled for this account';
COMMENT ON COLUMN public.trainer_profiles.stripe_charges_enabled IS 'Whether charges can be processed for this account';

-- =====================================================
-- BOOKING PAYMENTS TABLE
-- =====================================================
-- Track all payments for bookings

CREATE TABLE IF NOT EXISTS public.booking_payments (
    id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
    booking_id UUID REFERENCES public.trainer_bookings(id) ON DELETE CASCADE,
    trainer_id UUID REFERENCES public.trainer_profiles(id),
    student_id UUID REFERENCES public.profiles(id),
    
    -- Stripe payment info
    stripe_payment_intent_id TEXT,
    stripe_checkout_session_id TEXT,
    stripe_transfer_id TEXT,
    
    -- Amounts (all in öre/cents)
    amount_total INTEGER NOT NULL,           -- Total amount charged to student
    amount_platform_fee INTEGER NOT NULL,    -- Platform fee (15%)
    amount_trainer INTEGER NOT NULL,         -- Amount going to trainer
    amount_stripe_fee INTEGER,               -- Stripe's processing fee (estimate)
    
    currency TEXT DEFAULT 'sek',
    status TEXT DEFAULT 'pending',           -- pending, succeeded, failed, refunded
    
    created_at TIMESTAMP WITH TIME ZONE DEFAULT NOW(),
    updated_at TIMESTAMP WITH TIME ZONE DEFAULT NOW()
);

-- Add RLS policies
ALTER TABLE public.booking_payments ENABLE ROW LEVEL SECURITY;

-- Trainers can view their own payments
CREATE POLICY "Trainers can view own payments"
ON public.booking_payments FOR SELECT
USING (trainer_id IN (
    SELECT id FROM public.trainer_profiles WHERE user_id = auth.uid()
));

-- Students can view their own payments
CREATE POLICY "Students can view own payments"
ON public.booking_payments FOR SELECT
USING (student_id = auth.uid());

-- Service role can do everything
CREATE POLICY "Service role full access"
ON public.booking_payments FOR ALL
USING (auth.role() = 'service_role');

-- Index for faster queries
CREATE INDEX IF NOT EXISTS idx_booking_payments_booking_id ON public.booking_payments(booking_id);
CREATE INDEX IF NOT EXISTS idx_booking_payments_trainer_id ON public.booking_payments(trainer_id);
CREATE INDEX IF NOT EXISTS idx_booking_payments_student_id ON public.booking_payments(student_id);
CREATE INDEX IF NOT EXISTS idx_booking_payments_status ON public.booking_payments(status);

COMMENT ON TABLE public.booking_payments IS 'Tracks all payments for trainer bookings via Stripe Connect';




