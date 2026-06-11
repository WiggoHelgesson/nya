-- =============================================================
-- Product favorites (hjärtan) för Vår shop
-- Lagrar vilka Shopify-produkter (via handle) användare har gillat.
-- Alla inloggade kan läsa raderna så att antal likes per produkt
-- kan visas på produktkorten (social proof, Sellpy-style).
-- =============================================================

create table if not exists public.product_favorites (
    id uuid primary key default gen_random_uuid(),
    user_id uuid not null references auth.users(id) on delete cascade,
    product_handle text not null,
    created_at timestamptz not null default now(),
    unique (user_id, product_handle)
);

create index if not exists idx_product_favorites_handle
    on public.product_favorites (product_handle);

create index if not exists idx_product_favorites_user
    on public.product_favorites (user_id);

alter table public.product_favorites enable row level security;

-- Läsning: alla inloggade (krävs för like-räknare per produkt)
drop policy if exists "product_favorites_select" on public.product_favorites;
create policy "product_favorites_select"
    on public.product_favorites
    for select
    to authenticated
    using (true);

-- Insert: bara egna rader
drop policy if exists "product_favorites_insert_own" on public.product_favorites;
create policy "product_favorites_insert_own"
    on public.product_favorites
    for insert
    to authenticated
    with check (auth.uid() = user_id);

-- Delete: bara egna rader
drop policy if exists "product_favorites_delete_own" on public.product_favorites;
create policy "product_favorites_delete_own"
    on public.product_favorites
    for delete
    to authenticated
    using (auth.uid() = user_id);
