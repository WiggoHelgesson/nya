-- Manual reconcile when Köp nu succeeded in Stripe but stripe-webhook never ran.
-- 1. Replace ALL occurrences of PLACEHOLDER_ORDER_UUID below with your marketplace_orders.id.
-- 2. Run in Supabase SQL Editor.
-- 3. POST functions/v1/book-marketplace-shipping with {"orderId":"<same uuid>"} (service role JWT).
-- 4. If purchase_completed DM still missing, insert via stripe-webhook flow or contact support.

BEGIN;

UPDATE public.marketplace_orders
SET status = 'succeeded', updated_at = now()
WHERE id = 'PLACEHOLDER_ORDER_UUID'::uuid
  AND status IN ('pending', 'processing');

UPDATE public.consignment_submissions cs
SET sold_at = COALESCE(cs.sold_at, now()),
    sold_order_id = 'PLACEHOLDER_ORDER_UUID'::uuid
FROM public.marketplace_orders mo
WHERE mo.id = 'PLACEHOLDER_ORDER_UUID'::uuid
  AND cs.id = mo.listing_id;

INSERT INTO public.notifications (user_id, type, actor_id, related_id, message)
SELECT mo.seller_id,
       'marketplace_sale',
       mo.buyer_id,
       mo.listing_id,
       COALESCE(mo.buyer_username, 'Någon')
         || ' köpte din '
         || COALESCE(mo.listing_title, 'produkt')
         || ' för '
         || (mo.amount_item / 100)::int
         || ' kr'
FROM public.marketplace_orders mo
WHERE mo.id = 'PLACEHOLDER_ORDER_UUID'::uuid;

INSERT INTO public.notifications (user_id, type, actor_id, related_id, message)
SELECT mo.buyer_id,
       'marketplace_purchase',
       mo.seller_id,
       mo.listing_id,
       'Ditt köp av '
         || COALESCE(mo.listing_title, 'produkten')
         || ' är genomfört — totalt '
         || (mo.amount_buyer_total / 100)::int
         || ' kr.'
FROM public.marketplace_orders mo
WHERE mo.id = 'PLACEHOLDER_ORDER_UUID'::uuid;

COMMIT;
