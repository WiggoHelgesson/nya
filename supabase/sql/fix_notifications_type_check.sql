ALTER TABLE notifications DROP CONSTRAINT IF EXISTS notifications_type_check;
ALTER TABLE notifications ADD CONSTRAINT notifications_type_check
  CHECK (type IN (
    'like', 'comment', 'follow', 'reply',
    'new_workout', 'new_story', 'new_pb',
    'progress_photo', 'profile_update',
    'coach_invitation', 'coach_program_assigned',
    'trainer_chat_message', 'coach_schedule_updated'
  ));
