-- ============================================
-- Direct Messaging System - User to User
-- Run this entire script in one go in Supabase SQL Editor
-- ============================================

-- STEP 0: Clean up any previous partial install
DROP VIEW IF EXISTS public.direct_conversations_with_info CASCADE;
DROP FUNCTION IF EXISTS public.update_direct_conversation_last_message() CASCADE;
DROP TABLE IF EXISTS public.direct_messages CASCADE;
DROP TABLE IF EXISTS public.direct_conversation_participants CASCADE;
DROP TABLE IF EXISTS public.direct_conversations CASCADE;

-- ============================================
-- STEP 1: Create tables
-- ============================================

CREATE TABLE public.direct_conversations (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    created_at TIMESTAMPTZ DEFAULT now(),
    last_message_at TIMESTAMPTZ DEFAULT now(),
    created_by UUID REFERENCES auth.users(id) ON DELETE SET NULL
);

CREATE TABLE public.direct_conversation_participants (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    conversation_id UUID NOT NULL REFERENCES public.direct_conversations(id) ON DELETE CASCADE,
    user_id UUID NOT NULL REFERENCES auth.users(id) ON DELETE CASCADE,
    is_muted BOOLEAN DEFAULT false,
    joined_at TIMESTAMPTZ DEFAULT now(),
    UNIQUE(conversation_id, user_id)
);

CREATE TABLE public.direct_messages (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    conversation_id UUID NOT NULL REFERENCES public.direct_conversations(id) ON DELETE CASCADE,
    sender_id UUID NOT NULL REFERENCES auth.users(id) ON DELETE CASCADE,
    message TEXT NOT NULL,
    is_read BOOLEAN DEFAULT false,
    created_at TIMESTAMPTZ DEFAULT now()
);

-- ============================================
-- STEP 2: Indexes
-- ============================================

CREATE INDEX idx_direct_conv_participants_conv ON public.direct_conversation_participants(conversation_id);
CREATE INDEX idx_direct_conv_participants_user ON public.direct_conversation_participants(user_id);
CREATE INDEX idx_direct_conversations_last_msg ON public.direct_conversations(last_message_at DESC);
CREATE INDEX idx_direct_messages_conv ON public.direct_messages(conversation_id, created_at ASC);
CREATE INDEX idx_direct_messages_sender ON public.direct_messages(sender_id);
CREATE INDEX idx_direct_messages_unread ON public.direct_messages(conversation_id, is_read) WHERE is_read = false;

-- ============================================
-- STEP 3: Enable RLS
-- ============================================

ALTER TABLE public.direct_conversations ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.direct_conversation_participants ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.direct_messages ENABLE ROW LEVEL SECURITY;

-- ============================================
-- STEP 4: RLS Policies for direct_conversations
-- ============================================

CREATE POLICY "Users can view own conversations" ON public.direct_conversations
    FOR SELECT USING (
        id IN (
            SELECT conversation_id FROM public.direct_conversation_participants
            WHERE user_id = auth.uid()
        )
    );

CREATE POLICY "Authenticated users can create conversations" ON public.direct_conversations
    FOR INSERT WITH CHECK (auth.uid() IS NOT NULL);

CREATE POLICY "Participants can update conversations" ON public.direct_conversations
    FOR UPDATE USING (
        id IN (
            SELECT conversation_id FROM public.direct_conversation_participants
            WHERE user_id = auth.uid()
        )
    );

CREATE POLICY "Participants can delete conversations" ON public.direct_conversations
    FOR DELETE USING (
        id IN (
            SELECT conversation_id FROM public.direct_conversation_participants
            WHERE user_id = auth.uid()
        )
    );

-- ============================================
-- STEP 5: RLS Policies for direct_conversation_participants
-- ============================================

CREATE POLICY "Users can view participants of own conversations" ON public.direct_conversation_participants
    FOR SELECT USING (
        conversation_id IN (
            SELECT conversation_id FROM public.direct_conversation_participants
            WHERE user_id = auth.uid()
        )
    );

CREATE POLICY "Authenticated users can add participants" ON public.direct_conversation_participants
    FOR INSERT WITH CHECK (auth.uid() IS NOT NULL);

CREATE POLICY "Users can update own participation" ON public.direct_conversation_participants
    FOR UPDATE USING (user_id = auth.uid());

CREATE POLICY "Users can remove own participation" ON public.direct_conversation_participants
    FOR DELETE USING (user_id = auth.uid());

-- ============================================
-- STEP 6: RLS Policies for direct_messages
-- ============================================

CREATE POLICY "Participants can view messages" ON public.direct_messages
    FOR SELECT USING (
        conversation_id IN (
            SELECT conversation_id FROM public.direct_conversation_participants
            WHERE user_id = auth.uid()
        )
    );

CREATE POLICY "Participants can send messages" ON public.direct_messages
    FOR INSERT WITH CHECK (
        auth.uid() = sender_id AND
        conversation_id IN (
            SELECT conversation_id FROM public.direct_conversation_participants
            WHERE user_id = auth.uid()
        )
    );

CREATE POLICY "Participants can mark messages read" ON public.direct_messages
    FOR UPDATE USING (
        conversation_id IN (
            SELECT conversation_id FROM public.direct_conversation_participants
            WHERE user_id = auth.uid()
        )
    );

-- ============================================
-- STEP 7: Enable Realtime
-- ============================================

ALTER PUBLICATION supabase_realtime ADD TABLE public.direct_messages;

-- ============================================
-- STEP 8: Trigger to auto-update last_message_at
-- ============================================

CREATE OR REPLACE FUNCTION public.update_direct_conversation_last_message()
RETURNS TRIGGER LANGUAGE plpgsql SECURITY DEFINER AS $$
BEGIN
    UPDATE public.direct_conversations
    SET last_message_at = NEW.created_at
    WHERE id = NEW.conversation_id;
    RETURN NEW;
END;
$$;

CREATE TRIGGER on_new_direct_message
    AFTER INSERT ON public.direct_messages
    FOR EACH ROW
    EXECUTE FUNCTION public.update_direct_conversation_last_message();

-- ============================================
-- STEP 9: Convenience view with metadata
-- ============================================

CREATE OR REPLACE VIEW public.direct_conversations_with_info AS
SELECT
    c.id,
    c.created_at,
    c.last_message_at,
    c.created_by,
    -- Other participant info
    other_p.user_id AS other_user_id,
    other_profile.username AS other_username,
    other_profile.avatar_url AS other_avatar_url,
    -- Current user's mute status
    my_p.is_muted,
    -- Last message
    (
        SELECT message FROM public.direct_messages m
        WHERE m.conversation_id = c.id
        ORDER BY m.created_at DESC LIMIT 1
    ) AS last_message,
    -- Last message sender
    (
        SELECT sender_id FROM public.direct_messages m
        WHERE m.conversation_id = c.id
        ORDER BY m.created_at DESC LIMIT 1
    ) AS last_message_sender_id,
    -- Unread count
    (
        SELECT COUNT(*) FROM public.direct_messages m
        WHERE m.conversation_id = c.id
        AND m.sender_id != auth.uid()
        AND m.is_read = false
    )::int AS unread_count
FROM public.direct_conversations c
JOIN public.direct_conversation_participants my_p
    ON my_p.conversation_id = c.id AND my_p.user_id = auth.uid()
JOIN public.direct_conversation_participants other_p
    ON other_p.conversation_id = c.id AND other_p.user_id != auth.uid()
JOIN public.profiles other_profile
    ON other_profile.id = other_p.user_id;

-- ============================================
-- STEP 10: Function to find existing conversation between two users
-- ============================================

CREATE OR REPLACE FUNCTION public.find_direct_conversation(p_user1 UUID, p_user2 UUID)
RETURNS UUID AS $$
DECLARE
    v_conversation_id UUID;
BEGIN
    SELECT p1.conversation_id INTO v_conversation_id
    FROM public.direct_conversation_participants p1
    JOIN public.direct_conversation_participants p2
        ON p1.conversation_id = p2.conversation_id
    WHERE p1.user_id = p_user1 AND p2.user_id = p_user2
    LIMIT 1;
    
    RETURN v_conversation_id;
END;
$$ LANGUAGE plpgsql SECURITY DEFINER;
