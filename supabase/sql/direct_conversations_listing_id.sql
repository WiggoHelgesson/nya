-- =====================================================
-- DIRECT CONVERSATIONS: LISTING_ID
-- =====================================================
-- Ties a direct conversation to a specific marketplace
-- listing (`consignment_submissions`). Existing trådar
-- without a listing (coach / trainer / general DMs)
-- keep `listing_id = NULL` and behave like before.
--
-- With this column we can:
--   - Create one chat thread per (buyer, seller, listing)
--     triplet instead of one per user pair.
--   - Group the Meddelanden-tab by listing (Bild 1 -> 2 -> 3).
-- =====================================================

BEGIN;

-- 1. Column + index ---------------------------------------------

ALTER TABLE public.direct_conversations
    ADD COLUMN IF NOT EXISTS listing_id UUID
    REFERENCES public.consignment_submissions (id) ON DELETE CASCADE;

CREATE INDEX IF NOT EXISTS idx_direct_conversations_listing_id
    ON public.direct_conversations (listing_id);

-- 2. find_direct_conversation (3 args now, listing NULL-safe) ----
--
-- `IS NOT DISTINCT FROM` treats NULL = NULL, so passing NULL
-- finds the "generic" 1:1 thread (back-compat with coach/trainer
-- flows), and passing a listing UUID matches *that* listing's
-- thread only.

DROP FUNCTION IF EXISTS public.find_direct_conversation(UUID, UUID) CASCADE;
DROP FUNCTION IF EXISTS public.find_direct_conversation(UUID, UUID, UUID) CASCADE;

CREATE OR REPLACE FUNCTION public.find_direct_conversation(
    p_user1 UUID,
    p_user2 UUID,
    p_listing UUID DEFAULT NULL
)
RETURNS UUID
LANGUAGE plpgsql
SECURITY DEFINER
STABLE
AS $$
DECLARE
    v_conversation_id UUID;
BEGIN
    SELECT c.id INTO v_conversation_id
    FROM public.direct_conversations c
    JOIN public.direct_conversation_participants p1
        ON p1.conversation_id = c.id AND p1.user_id = p_user1
    JOIN public.direct_conversation_participants p2
        ON p2.conversation_id = c.id AND p2.user_id = p_user2
    WHERE COALESCE(c.is_group, false) = false
      AND c.listing_id IS NOT DISTINCT FROM p_listing
    LIMIT 1;

    RETURN v_conversation_id;
END;
$$;

-- 3. Recreate the helper view to expose listing_id ---------------
--
-- Mirrors the original view in create_direct_messages.sql but
-- adds `c.listing_id` so the Meddelanden-inbox can group by ad.

DROP VIEW IF EXISTS public.direct_conversations_with_info CASCADE;

CREATE VIEW public.direct_conversations_with_info AS
SELECT
    c.id,
    c.created_at,
    c.last_message_at,
    c.created_by,
    c.is_group,
    c.group_name,
    c.group_image_url,
    c.listing_id,
    (
        SELECT op.user_id FROM public.direct_conversation_participants op
        WHERE op.conversation_id = c.id AND op.user_id != auth.uid()
        LIMIT 1
    ) AS other_user_id,
    (
        SELECT p.username FROM public.direct_conversation_participants op
        JOIN public.profiles p ON p.id = op.user_id
        WHERE op.conversation_id = c.id AND op.user_id != auth.uid()
        LIMIT 1
    ) AS other_username,
    (
        SELECT p.avatar_url FROM public.direct_conversation_participants op
        JOIN public.profiles p ON p.id = op.user_id
        WHERE op.conversation_id = c.id AND op.user_id != auth.uid()
        LIMIT 1
    ) AS other_avatar_url,
    (
        SELECT string_agg(p.username, ', ' ORDER BY p.username)
        FROM public.direct_conversation_participants op
        JOIN public.profiles p ON p.id = op.user_id
        WHERE op.conversation_id = c.id AND op.user_id != auth.uid()
    ) AS group_participant_names,
    (
        SELECT COUNT(*) FROM public.direct_conversation_participants op
        WHERE op.conversation_id = c.id
    )::int AS member_count,
    my_p.is_muted,
    (
        SELECT message FROM public.direct_messages m
        WHERE m.conversation_id = c.id
        ORDER BY m.created_at DESC LIMIT 1
    ) AS last_message,
    (
        SELECT sender_id FROM public.direct_messages m
        WHERE m.conversation_id = c.id
        ORDER BY m.created_at DESC LIMIT 1
    ) AS last_message_sender_id,
    (
        SELECT p.username FROM public.direct_messages m
        JOIN public.profiles p ON p.id = m.sender_id
        WHERE m.conversation_id = c.id
        ORDER BY m.created_at DESC LIMIT 1
    ) AS last_message_sender_name,
    (
        SELECT COUNT(*) FROM public.direct_messages m
        WHERE m.conversation_id = c.id
          AND m.sender_id != auth.uid()
          AND m.is_read = false
    )::int AS unread_count
FROM public.direct_conversations c
JOIN public.direct_conversation_participants my_p
    ON my_p.conversation_id = c.id AND my_p.user_id = auth.uid();

COMMIT;
