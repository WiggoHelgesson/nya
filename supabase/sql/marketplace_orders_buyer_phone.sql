-- Buyer mobile for Shipmondo receiver_mobile (e.g. DHL Freight hemleverans).
alter table public.marketplace_orders
  add column if not exists buyer_phone text;

comment on column public.marketplace_orders.buyer_phone is
  'E.164 mobile for delivery SMS; set at checkout from AddressFormView.';
