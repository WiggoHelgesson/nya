-- Add shipping cost tracking to marketplace_orders.
-- Buyer total now = item + platform_fee + shipping. Seller still gets 100 % of
-- item price; platform keeps fee + shipping.

alter table public.marketplace_orders
    add column if not exists amount_shipping integer not null default 0;

comment on column public.marketplace_orders.amount_shipping is
    'Flat shipping fee paid by the buyer, in öre. Kept by the platform.';
