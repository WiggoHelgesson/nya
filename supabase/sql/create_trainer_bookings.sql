-- =====================================================
-- TRAINER BOOKINGS SYSTEM
-- =====================================================

-- Drop existing objects to recreate cleanly
DROP VIEW IF EXISTS public.trainer_bookings_with_users CASCADE;
DROP TABLE IF EXISTS public.booking_messages CASCADE;
DROP TABLE IF EXISTS public.trainer_bookings CASCADE;

-- Create trainer_bookings table for lesson booking requests
CREATE TABLE public.trainer_bookings (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    trainer_id UUID NOT NULL REFERENCES public.trainer_profiles(id) ON DELETE CASCADE,
    student_id UUID NOT NULL REFERENCES auth.users(id) ON DELETE CASCADE,
    message TEXT NOT NULL,
    status TEXT NOT NULL DEFAULT 'pending' CHECK (status IN ('pending', 'accepted', 'declined', 'cancelled')),
    trainer_response TEXT,
    created_at TIMESTAMPTZ NOT NULL DEFAULT now(),
    updated_at TIMESTAMPTZ NOT NULL DEFAULT now()
);

-- Create indexes
CREATE INDEX trainer_bookings_trainer_id_idx ON public.trainer_bookings(trainer_id);
CREATE INDEX trainer_bookings_student_id_idx ON public.trainer_bookings(student_id);
CREATE INDEX trainer_bookings_status_idx ON public.trainer_bookings(status);

-- Create booking_messages table for chat
CREATE TABLE public.booking_messages (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    booking_id UUID NOT NULL REFERENCES public.trainer_bookings(id) ON DELETE CASCADE,
    sender_id UUID NOT NULL REFERENCES auth.users(id) ON DELETE CASCADE,
    message TEXT NOT NULL,
    is_read BOOLEAN NOT NULL DEFAULT false,
    created_at TIMESTAMPTZ NOT NULL DEFAULT now()
);

CREATE INDEX booking_messages_booking_id_idx ON public.booking_messages(booking_id);
CREATE INDEX booking_messages_sender_id_idx ON public.booking_messages(sender_id);

-- Updated_at trigger for bookings
CREATE OR REPLACE FUNCTION public.set_booking_updated_at()
RETURNS TRIGGER
LANGUAGE plpgsql
AS $$
BEGIN
    NEW.updated_at := now();
    RETURN NEW;
END;
$$;

DROP TRIGGER IF EXISTS trg_trainer_bookings_updated ON public.trainer_bookings;
CREATE TRIGGER trg_trainer_bookings_updated
BEFORE UPDATE ON public.trainer_bookings
FOR EACH ROW
EXECUTE PROCEDURE public.set_booking_updated_at();

-- Enable Row Level Security
ALTER TABLE public.trainer_bookings ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.booking_messages ENABLE ROW LEVEL SECURITY;

-- =====================================================
-- RLS POLICIES FOR trainer_bookings
-- =====================================================

-- Trainers can see bookings for their profile, students can see their own bookings
CREATE POLICY trainer_bookings_select ON public.trainer_bookings
    FOR SELECT
    USING (
        auth.uid() = student_id 
        OR 
        auth.uid() IN (SELECT user_id FROM public.trainer_profiles WHERE id = trainer_id)
    );

-- Anyone can create a booking request
CREATE POLICY trainer_bookings_insert ON public.trainer_bookings
    FOR INSERT
    WITH CHECK (auth.uid() = student_id);

-- Trainers can update (accept/decline) their bookings, students can cancel their own
CREATE POLICY trainer_bookings_update ON public.trainer_bookings
    FOR UPDATE
    USING (
        auth.uid() = student_id 
        OR 
        auth.uid() IN (SELECT user_id FROM public.trainer_profiles WHERE id = trainer_id)
    );

-- =====================================================
-- RLS POLICIES FOR booking_messages
-- =====================================================

-- Only booking participants can see messages
CREATE POLICY booking_messages_select ON public.booking_messages
    FOR SELECT
    USING (
        EXISTS (
            SELECT 1 FROM public.trainer_bookings tb
            WHERE tb.id = booking_id
            AND (
                auth.uid() = tb.student_id 
                OR 
                auth.uid() IN (SELECT user_id FROM public.trainer_profiles WHERE id = tb.trainer_id)
            )
        )
    );

-- Only booking participants can send messages
CREATE POLICY booking_messages_insert ON public.booking_messages
    FOR INSERT
    WITH CHECK (
        auth.uid() = sender_id
        AND EXISTS (
            SELECT 1 FROM public.trainer_bookings tb
            WHERE tb.id = booking_id
            AND (
                auth.uid() = tb.student_id 
                OR 
                auth.uid() IN (SELECT user_id FROM public.trainer_profiles WHERE id = tb.trainer_id)
            )
        )
    );

-- Mark messages as read
CREATE POLICY booking_messages_update ON public.booking_messages
    FOR UPDATE
    USING (
        EXISTS (
            SELECT 1 FROM public.trainer_bookings tb
            WHERE tb.id = booking_id
            AND (
                auth.uid() = tb.student_id 
                OR 
                auth.uid() IN (SELECT user_id FROM public.trainer_profiles WHERE id = tb.trainer_id)
            )
        )
    );

-- Grant access
GRANT SELECT, INSERT, UPDATE ON public.trainer_bookings TO authenticated;
GRANT SELECT, INSERT, UPDATE ON public.booking_messages TO authenticated;

-- =====================================================
-- VIEW: trainer_bookings_with_users
-- =====================================================

CREATE OR REPLACE VIEW public.trainer_bookings_with_users AS
SELECT 
    tb.id,
    tb.trainer_id,
    tb.student_id,
    tb.message,
    tb.status,
    tb.trainer_response,
    tb.created_at,
    tb.updated_at,
    -- Extended booking fields
    tb.lesson_type_id,
    tb.scheduled_date,
    tb.scheduled_time,
    tb.duration_minutes,
    tb.price,
    tb.location_type,
    tb.golf_course_id,
    tb.custom_location_name,
    tb.custom_location_lat,
    tb.custom_location_lng,
    tb.payment_status,
    tb.stripe_payment_id,
    -- Trainer info
    tp.user_id as trainer_user_id,
    tp.name as trainer_name,
    tp.avatar_url as trainer_avatar_url,
    tp.hourly_rate,
    tp.city as trainer_city,
    -- Student info
    p.username as student_username,
    p.avatar_url as student_avatar_url,
    -- Unread count
    (
        SELECT COUNT(*) 
        FROM public.booking_messages bm 
        WHERE bm.booking_id = tb.id 
        AND bm.is_read = false 
        AND bm.sender_id != auth.uid()
    ) as unread_count
FROM public.trainer_bookings tb
JOIN public.trainer_profiles tp ON tb.trainer_id = tp.id
LEFT JOIN public.profiles p ON tb.student_id = p.id
WHERE 
    auth.uid() = tb.student_id 
    OR 
    auth.uid() = tp.user_id;

GRANT SELECT ON public.trainer_bookings_with_users TO authenticated;

-- =====================================================
-- VIEW: booking_messages_with_users
-- =====================================================

CREATE OR REPLACE VIEW public.booking_messages_with_users AS
SELECT 
    bm.*,
    p.username as sender_username,
    p.avatar_url as sender_avatar_url
FROM public.booking_messages bm
LEFT JOIN public.profiles p ON bm.sender_id = p.id;

GRANT SELECT ON public.booking_messages_with_users TO authenticated;

-- =====================================================
-- FUNCTION: create_booking_with_notification
-- =====================================================

DROP FUNCTION IF EXISTS public.create_booking_with_notification(UUID, TEXT);

CREATE OR REPLACE FUNCTION public.create_booking_with_notification(
    p_trainer_id UUID,
    p_message TEXT
)
RETURNS UUID
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public
AS $$
DECLARE
    v_booking_id UUID;
    v_trainer_user_id UUID;
    v_student_name TEXT;
BEGIN
    -- Get trainer's user_id
    SELECT user_id INTO v_trainer_user_id
    FROM trainer_profiles
    WHERE id = p_trainer_id;
    
    IF v_trainer_user_id IS NULL THEN
        RAISE EXCEPTION 'Trainer not found';
    END IF;
    
    -- Get student's name
    SELECT COALESCE(username, 'Någon') INTO v_student_name
    FROM profiles
    WHERE id = auth.uid();
    
    -- Create the booking
    INSERT INTO trainer_bookings (trainer_id, student_id, message)
    VALUES (p_trainer_id, auth.uid(), p_message)
    RETURNING id INTO v_booking_id;
    
    -- Also create first message
    INSERT INTO booking_messages (booking_id, sender_id, message)
    VALUES (v_booking_id, auth.uid(), p_message);
    
    -- Try to create notification (if table exists)
    BEGIN
        INSERT INTO notifications (user_id, actor_id, type, reference_id, message)
        VALUES (
            v_trainer_user_id,
            auth.uid(),
            'booking_request',
            v_booking_id::text,
            v_student_name || ' vill boka en lektion med dig!'
        );
    EXCEPTION WHEN undefined_table THEN
        -- Notifications table doesn't exist, skip
        NULL;
    END;
    
    RETURN v_booking_id;
END;
$$;

GRANT EXECUTE ON FUNCTION public.create_booking_with_notification(UUID, TEXT) TO authenticated;

-- =====================================================
-- FUNCTION: send_booking_message
-- =====================================================

DROP FUNCTION IF EXISTS public.send_booking_message(UUID, TEXT);

CREATE OR REPLACE FUNCTION public.send_booking_message(
    p_booking_id UUID,
    p_message TEXT
)
RETURNS UUID
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public
AS $$
DECLARE
    v_message_id UUID;
    v_recipient_id UUID;
    v_sender_name TEXT;
    v_booking RECORD;
BEGIN
    -- Get booking info
    SELECT tb.*, tp.user_id as trainer_user_id 
    INTO v_booking
    FROM trainer_bookings tb
    JOIN trainer_profiles tp ON tb.trainer_id = tp.id
    WHERE tb.id = p_booking_id;
    
    IF v_booking IS NULL THEN
        RAISE EXCEPTION 'Booking not found';
    END IF;
    
    -- Check user is participant
    IF auth.uid() != v_booking.student_id AND auth.uid() != v_booking.trainer_user_id THEN
        RAISE EXCEPTION 'Not authorized';
    END IF;
    
    -- Create message
    INSERT INTO booking_messages (booking_id, sender_id, message)
    VALUES (p_booking_id, auth.uid(), p_message)
    RETURNING id INTO v_message_id;
    
    -- Determine recipient
    IF auth.uid() = v_booking.student_id THEN
        v_recipient_id := v_booking.trainer_user_id;
    ELSE
        v_recipient_id := v_booking.student_id;
    END IF;
    
    -- Get sender name
    SELECT COALESCE(username, 'Någon') INTO v_sender_name
    FROM profiles
    WHERE id = auth.uid();
    
    -- Try to create notification
    BEGIN
        INSERT INTO notifications (user_id, actor_id, type, reference_id, message)
        VALUES (
            v_recipient_id,
            auth.uid(),
            'booking_message',
            p_booking_id::text,
            v_sender_name || ' skickade ett meddelande'
        );
    EXCEPTION WHEN undefined_table THEN
        NULL;
    END;
    
    RETURN v_message_id;
END;
$$;

GRANT EXECUTE ON FUNCTION public.send_booking_message(UUID, TEXT) TO authenticated;

-- =====================================================
-- FUNCTION: update_booking_status
-- =====================================================

DROP FUNCTION IF EXISTS public.update_booking_status(UUID, TEXT, TEXT);

CREATE OR REPLACE FUNCTION public.update_booking_status(
    p_booking_id UUID,
    p_status TEXT,
    p_response TEXT DEFAULT NULL
)
RETURNS BOOLEAN
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public
AS $$
DECLARE
    v_booking RECORD;
    v_student_name TEXT;
    v_trainer_name TEXT;
BEGIN
    -- Get booking and trainer info
    SELECT tb.*, tp.user_id as trainer_user_id, tp.name as trainer_name
    INTO v_booking
    FROM trainer_bookings tb
    JOIN trainer_profiles tp ON tb.trainer_id = tp.id
    WHERE tb.id = p_booking_id;
    
    IF v_booking IS NULL THEN
        RAISE EXCEPTION 'Booking not found';
    END IF;
    
    -- Check authorization
    IF auth.uid() != v_booking.trainer_user_id AND auth.uid() != v_booking.student_id THEN
        RAISE EXCEPTION 'Not authorized';
    END IF;
    
    -- Update booking
    UPDATE trainer_bookings
    SET status = p_status,
        trainer_response = COALESCE(p_response, trainer_response)
    WHERE id = p_booking_id;
    
    -- Get names
    SELECT COALESCE(username, 'Tränaren') INTO v_trainer_name
    FROM profiles WHERE id = v_booking.trainer_user_id;
    
    -- Notify student about status change
    IF auth.uid() = v_booking.trainer_user_id THEN
        BEGIN
            INSERT INTO notifications (user_id, actor_id, type, reference_id, message)
            VALUES (
                v_booking.student_id,
                auth.uid(),
                'booking_' || p_status,
                p_booking_id::text,
                CASE p_status
                    WHEN 'accepted' THEN v_trainer_name || ' har godkänt din bokningsförfrågan!'
                    WHEN 'declined' THEN v_trainer_name || ' kunde tyvärr inte ta din bokning.'
                    ELSE v_trainer_name || ' har uppdaterat din bokning.'
                END
            );
        EXCEPTION WHEN undefined_table THEN
            NULL;
        END;
    END IF;
    
    RETURN TRUE;
END;
$$;

GRANT EXECUTE ON FUNCTION public.update_booking_status(UUID, TEXT, TEXT) TO authenticated;
