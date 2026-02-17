-- ============================================
-- RPC function to delete own messages
-- Run this in Supabase SQL Editor
-- ============================================

-- Also ensure the RLS policy exists
DO $$
BEGIN
    IF NOT EXISTS (
        SELECT 1 FROM pg_policies 
        WHERE tablename = 'direct_messages' 
        AND policyname = 'Users can delete own messages'
    ) THEN
        CREATE POLICY "Users can delete own messages" ON public.direct_messages
            FOR DELETE USING (auth.uid() = sender_id);
    END IF;
END
$$;

-- Create an RPC function for reliable message deletion
-- Uses SECURITY DEFINER so it runs with full privileges
-- But checks ownership internally for safety
CREATE OR REPLACE FUNCTION public.delete_own_message(p_message_id UUID)
RETURNS BOOLEAN
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public
AS $$
DECLARE
    v_sender_id UUID;
    v_deleted BOOLEAN := false;
BEGIN
    -- Verify the caller owns this message
    SELECT sender_id INTO v_sender_id
    FROM public.direct_messages
    WHERE id = p_message_id;
    
    IF v_sender_id IS NULL THEN
        -- Message not found
        RETURN false;
    END IF;
    
    IF v_sender_id != auth.uid() THEN
        -- Not the sender - deny
        RAISE EXCEPTION 'You can only delete your own messages';
    END IF;
    
    -- Delete the message
    DELETE FROM public.direct_messages WHERE id = p_message_id;
    
    RETURN true;
END;
$$;

-- Grant execute permission
GRANT EXECUTE ON FUNCTION public.delete_own_message(UUID) TO authenticated;
