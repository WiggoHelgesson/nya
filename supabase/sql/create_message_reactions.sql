-- ============================================
-- Message Reactions for Direct Messages
-- Run this in Supabase SQL Editor
-- ============================================

-- Create the reactions table
CREATE TABLE IF NOT EXISTS public.direct_message_reactions (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    message_id UUID NOT NULL REFERENCES public.direct_messages(id) ON DELETE CASCADE,
    user_id UUID NOT NULL REFERENCES auth.users(id) ON DELETE CASCADE,
    emoji TEXT NOT NULL,
    created_at TIMESTAMPTZ DEFAULT now(),
    
    -- One reaction per emoji per user per message
    UNIQUE(message_id, user_id, emoji)
);

-- Indexes for fast lookups
CREATE INDEX IF NOT EXISTS idx_msg_reactions_message ON public.direct_message_reactions(message_id);
CREATE INDEX IF NOT EXISTS idx_msg_reactions_user ON public.direct_message_reactions(user_id);

-- Enable RLS
ALTER TABLE public.direct_message_reactions ENABLE ROW LEVEL SECURITY;

-- Policy: Users can read reactions on messages in their conversations
CREATE POLICY "Users can read reactions in their conversations"
ON public.direct_message_reactions FOR SELECT
USING (
    EXISTS (
        SELECT 1 FROM public.direct_messages dm
        JOIN public.direct_conversation_participants dcp ON dcp.conversation_id = dm.conversation_id
        WHERE dm.id = direct_message_reactions.message_id
        AND dcp.user_id = auth.uid()
    )
);

-- Policy: Users can add reactions
CREATE POLICY "Users can add reactions"
ON public.direct_message_reactions FOR INSERT
WITH CHECK (auth.uid() = user_id);

-- Policy: Users can remove their own reactions
CREATE POLICY "Users can remove own reactions"
ON public.direct_message_reactions FOR DELETE
USING (auth.uid() = user_id);
