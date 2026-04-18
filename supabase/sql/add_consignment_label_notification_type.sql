-- Extends notifications.type CHECK constraint with consignment_label_ready
-- and adds a generic related_id column used for deep-linking (e.g. submission id).
-- Run AFTER add_consignment_notification_types.sql.

ALTER TABLE notifications DROP CONSTRAINT IF EXISTS notifications_type_check;
ALTER TABLE notifications ADD CONSTRAINT notifications_type_check
  CHECK (type IN (
    'like', 'comment', 'follow', 'reply',
    'new_workout', 'new_story', 'new_pb',
    'progress_photo', 'profile_update',
    'coach_invitation', 'coach_program_assigned',
    'trainer_chat_message', 'coach_schedule_updated',
    'consignment_approved', 'consignment_rejected',
    'consignment_label_ready'
  ));

ALTER TABLE notifications
    ADD COLUMN IF NOT EXISTS related_id UUID;
CREATE INDEX IF NOT EXISTS idx_notifications_related_id
    ON notifications (related_id);
