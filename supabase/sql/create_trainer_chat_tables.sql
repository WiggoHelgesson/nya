-- ============================================
-- Trainer Chat System - CLEAN INSTALL
-- Run this entire script in one go in Supabase SQL Editor
-- ============================================

-- STEP 0: Clean up any previous partial install
DROP VIEW IF EXISTS public.trainer_conversations_with_info CASCADE;
DROP FUNCTION IF EXISTS public.update_conversation_last_message() CASCADE;
DROP TABLE IF EXISTS public.trainer_chat_messages CASCADE;
DROP TABLE IF EXISTS public.trainer_conversations CASCADE;

-- ============================================
-- STEP 1: Create tables
-- ============================================

CREATE TABLE public.trainer_conversations (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    trainer_id UUID NOT NULL REFERENCES public.trainer_profiles(id) ON DELETE CASCADE,
    user_id UUID NOT NULL REFERENCES auth.users(id) ON DELETE CASCADE,
    last_message_at TIMESTAMPTZ DEFAULT now(),
    created_at TIMESTAMPTZ DEFAULT now(),
    UNIQUE(trainer_id, user_id)
);

CREATE TABLE public.trainer_chat_messages (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    conversation_id UUID NOT NULL REFERENCES public.trainer_conversations(id) ON DELETE CASCADE,
    sender_id UUID NOT NULL REFERENCES auth.users(id) ON DELETE CASCADE,
    message TEXT NOT NULL,
    is_read BOOLEAN DEFAULT false,
    created_at TIMESTAMPTZ DEFAULT now()
);

-- ============================================
-- STEP 2: Indexes
-- ============================================

CREATE INDEX idx_trainer_conversations_trainer ON public.trainer_conversations(trainer_id);
CREATE INDEX idx_trainer_conversations_user ON public.trainer_conversations(user_id);
CREATE INDEX idx_trainer_conversations_last_message ON public.trainer_conversations(last_message_at DESC);
CREATE INDEX idx_trainer_chat_messages_conversation ON public.trainer_chat_messages(conversation_id, created_at ASC);
CREATE INDEX idx_trainer_chat_messages_sender ON public.trainer_chat_messages(sender_id);
CREATE INDEX idx_trainer_chat_messages_unread ON public.trainer_chat_messages(conversation_id, is_read) WHERE is_read = false;

-- ============================================
-- STEP 3: Enable RLS
-- ============================================

ALTER TABLE public.trainer_conversations ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.trainer_chat_messages ENABLE ROW LEVEL SECURITY;

-- ============================================
-- STEP 4: RLS Policies for trainer_conversations
-- ============================================

CREATE POLICY "Users can view own conversations" ON public.trainer_conversations
    FOR SELECT USING (auth.uid() = user_id);

CREATE POLICY "Trainers can view their conversations" ON public.trainer_conversations
    FOR SELECT USING (
        trainer_id IN (
            SELECT id FROM public.trainer_profiles WHERE user_id = auth.uid()
        )
    );

CREATE POLICY "Users can create conversations" ON public.trainer_conversations
    FOR INSERT WITH CHECK (auth.uid() = user_id);

CREATE POLICY "Participants can update conversations" ON public.trainer_conversations
    FOR UPDATE USING (
        auth.uid() = user_id OR
        trainer_id IN (
            SELECT id FROM public.trainer_profiles WHERE user_id = auth.uid()
        )
    );

-- ============================================
-- STEP 5: RLS Policies for trainer_chat_messages
-- ============================================

CREATE POLICY "Participants can view messages" ON public.trainer_chat_messages
    FOR SELECT USING (
        conversation_id IN (
            SELECT id FROM public.trainer_conversations
            WHERE user_id = auth.uid()
            OR trainer_id IN (
                SELECT id FROM public.trainer_profiles WHERE user_id = auth.uid()
            )
        )
    );

CREATE POLICY "Participants can send messages" ON public.trainer_chat_messages
    FOR INSERT WITH CHECK (
        auth.uid() = sender_id AND
        conversation_id IN (
            SELECT id FROM public.trainer_conversations
            WHERE user_id = auth.uid()
            OR trainer_id IN (
                SELECT id FROM public.trainer_profiles WHERE user_id = auth.uid()
            )
        )
    );

CREATE POLICY "Participants can mark messages read" ON public.trainer_chat_messages
    FOR UPDATE USING (
        conversation_id IN (
            SELECT id FROM public.trainer_conversations
            WHERE user_id = auth.uid()
            OR trainer_id IN (
                SELECT id FROM public.trainer_profiles WHERE user_id = auth.uid()
            )
        )
    );

-- ============================================
-- STEP 6: Enable Realtime
-- ============================================

ALTER PUBLICATION supabase_realtime ADD TABLE public.trainer_chat_messages;

-- ============================================
-- STEP 7: Trigger to auto-update last_message_at
-- ============================================

CREATE OR REPLACE FUNCTION public.update_conversation_last_message()
RETURNS TRIGGER LANGUAGE plpgsql SECURITY DEFINER AS $$
BEGIN
    UPDATE public.trainer_conversations
    SET last_message_at = NEW.created_at
    WHERE id = NEW.conversation_id;
    RETURN NEW;
END;
$$;

CREATE TRIGGER on_new_chat_message
    AFTER INSERT ON public.trainer_chat_messages
    FOR EACH ROW
    EXECUTE FUNCTION public.update_conversation_last_message();

-- ============================================
-- STEP 8: Convenience view with metadata
-- ============================================

CREATE OR REPLACE VIEW public.trainer_conversations_with_info AS
SELECT
    c.id,
    c.trainer_id,
    c.user_id,
    c.last_message_at,
    c.created_at,
    t.name AS trainer_name,
    t.avatar_url AS trainer_avatar_url,
    t.user_id AS trainer_user_id,
    p.username AS user_username,
    p.avatar_url AS user_avatar_url,
    (
        SELECT message FROM public.trainer_chat_messages m
        WHERE m.conversation_id = c.id
        ORDER BY m.created_at DESC LIMIT 1
    ) AS last_message,
    (
        SELECT COUNT(*) FROM public.trainer_chat_messages m
        WHERE m.conversation_id = c.id
        AND m.sender_id != auth.uid()
        AND m.is_read = false
    )::int AS unread_count
FROM public.trainer_conversations c
JOIN public.trainer_profiles t ON t.id = c.trainer_id
JOIN public.profiles p ON p.id = c.user_id
WHERE c.user_id = auth.uid()
   OR t.user_id = auth.uid();
