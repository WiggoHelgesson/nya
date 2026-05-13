-- =====================================================
-- notifications.type: allow all marketplace_* types used by Edge Functions
-- =====================================================
-- Run in Supabase SQL Editor after prior migrations.
--
-- Om konversation per annons saknas (purchase_completed-DM skrivs inte), kör också:
--   supabase/sql/direct_conversations_listing_id.sql
-- Full sökväg i repot: riktiga/supabase/sql/direct_conversations_listing_id.sql
-- (adds listing_id + 3-arg find_direct_conversation used by marketplaceListingConversation.ts)
-- =====================================================

BEGIN;

ALTER TABLE public.notifications DROP CONSTRAINT IF EXISTS notifications_type_check;

ALTER TABLE public.notifications ADD CONSTRAINT notifications_type_check
  CHECK (type IN (
    'like', 'comment', 'follow', 'reply',
    'new_workout', 'new_story', 'new_pb',
    'progress_photo', 'profile_update',
    'coach_invitation', 'coach_program_assigned',
    'trainer_chat_message', 'coach_schedule_updated',
    'consignment_approved', 'consignment_rejected', 'consignment_label_ready',
    -- Used by stripe-webhook (lesson payments) and book-marketplace-shipping (manual fallback)
    'payment_received', 'admin_shipping_manual',
    'marketplace_sale', 'marketplace_purchase',
    'marketplace_offer', 'marketplace_offer_accepted', 'marketplace_offer_declined',
    'marketplace_shipping_label', 'marketplace_shipping_started',
    'marketplace_picked_up', 'marketplace_in_transit', 'marketplace_delivered',
    'marketplace_buyer_approved', 'marketplace_payout_released',
    'marketplace_payout_auto_released', 'marketplace_approved_pending_payout',
    'marketplace_ship_reminder', 'marketplace_auto_cancelled', 'marketplace_auto_refund',
    'marketplace_dispute_opened', 'marketplace_dispute_received',
    'marketplace_dispute_refunded', 'marketplace_dispute_released',
    'marketplace_dispute_partial_refunded', 'marketplace_payout_failed_admin',
    'marketplace_cancelled', 'marketplace_direct_message',
    'admin_marketplace_dispute'
  ));

COMMIT;
