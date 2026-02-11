-- ============================================
-- Enable Realtime on Coach Tables
-- ============================================
-- Run this in Supabase SQL Editor to enable 
-- real-time updates when a trainer modifies
-- programs, schedules, or tips.
-- ============================================

-- Enable realtime on coach_programs (for schedule/tip updates)
ALTER PUBLICATION supabase_realtime ADD TABLE public.coach_programs;

-- Enable realtime on coach_program_assignments (for new/removed programs)
ALTER PUBLICATION supabase_realtime ADD TABLE public.coach_program_assignments;

-- Verify
SELECT 
    schemaname, 
    tablename 
FROM pg_publication_tables 
WHERE pubname = 'supabase_realtime'
AND tablename IN ('coach_programs', 'coach_program_assignments', 'trainer_chat_messages')
ORDER BY tablename;

-- ============================================
-- EXPECTED OUTPUT:
-- coach_program_assignments | public
-- coach_programs | public
-- trainer_chat_messages | public
-- ============================================
