-- Extend consignment_submissions with the manual listing fields used by the
-- new "Ny annons" flow (replaces the AI-driven flow). Existing ai_payload
-- column is left intact for backwards compatibility with older rows but is no
-- longer populated by the client on new submissions.

alter table public.consignment_submissions
  add column if not exists title text,
  add column if not exists description text,
  add column if not exists price_sek integer,
  add column if not exists colors text[] default '{}',
  add column if not exists material text,
  add column if not exists package_size text;

-- Optional sanity check: price should never be negative.
do $$
begin
  if not exists (
    select 1 from pg_constraint where conname = 'consignment_submissions_price_non_negative'
  ) then
    alter table public.consignment_submissions
      add constraint consignment_submissions_price_non_negative
      check (price_sek is null or price_sek >= 0);
  end if;
end $$;

-- Helpful index if we start filtering published listings by price.
create index if not exists consignment_submissions_price_idx
  on public.consignment_submissions (price_sek);
