-- Enable required extensions
create extension if not exists postgis;
create extension if not exists pgcrypto;

-- Territories table stores multipolygons claimed by users
create table if not exists public.territories (
    id uuid primary key default gen_random_uuid(),
    owner_id uuid not null references auth.users (id) on delete cascade,
    activity_type text not null check (char_length(activity_type) > 0),
    geom geometry(MultiPolygon, 4326) not null,
    area_m2 double precision generated always as (ST_Area(geom::geography)) stored,
    created_at timestamptz not null default now(),
    updated_at timestamptz not null default now()
);

create index if not exists territories_geom_idx on public.territories using gist (geom);
create index if not exists territories_owner_idx on public.territories(owner_id);

create or replace function public.set_territory_updated_at()
returns trigger
language plpgsql
as $$
begin
    new.updated_at := now();
    return new;
end;
$$;

drop trigger if exists trg_territories_updated on public.territories;
create trigger trg_territories_updated
before update on public.territories
for each row
execute procedure public.set_territory_updated_at();

-- Territory events keep an audit trail (claims, takeovers, etc.)
create table if not exists public.territory_events (
    id uuid primary key default gen_random_uuid(),
    territory_id uuid references public.territories(id) on delete cascade,
    actor_id uuid not null references auth.users(id) on delete cascade,
    event_type text not null,
    metadata jsonb default '{}'::jsonb,
    created_at timestamptz not null default now()
);

alter table public.territories enable row level security;
alter table public.territory_events enable row level security;

do $$
begin
    if not exists (
        select 1 from pg_policies where schemaname = 'public' and tablename = 'territories' and policyname = 'territories_select'
    ) then
        create policy territories_select on public.territories
            for select
            using (true);
    end if;

    if not exists (
        select 1 from pg_policies where schemaname = 'public' and tablename = 'territories' and policyname = 'territories_update'
    ) then
        create policy territories_update on public.territories
            for update
            using (auth.uid() = owner_id)
            with check (auth.uid() = owner_id);
    end if;

    if not exists (
        select 1 from pg_policies where schemaname = 'public' and tablename = 'territories' and policyname = 'territories_delete'
    ) then
        create policy territories_delete on public.territories
            for delete
            using (auth.uid() = owner_id);
    end if;

    if not exists (
        select 1 from pg_policies where schemaname = 'public' and tablename = 'territory_events' and policyname = 'territory_events_select'
    ) then
        create policy territory_events_select on public.territory_events
            for select
            using (true);
    end if;
end $$;

-- Read-friendly view that exposes GeoJSON polygons
create or replace view public.territory_geojson as
select
    id,
    owner_id,
    activity_type,
    area_m2,
    created_at,
    updated_at,
    ST_AsGeoJSON(geom)::jsonb as geojson
from public.territories;

grant select on public.territory_geojson to authenticated;

-- Claim territory RPC
create or replace function public.claim_territory(
    p_owner uuid,
    p_activity text,
    p_coordinates double precision[][]
)
returns table (
    id uuid,
    owner_id uuid,
    activity_type text,
    area_m2 double precision,
    geojson jsonb
)
language plpgsql
security definer
set search_path = public, extensions
as $$
declare
    pts geometry[];
    lat double precision;
    lon double precision;
    idx int;
    new_geom geometry(MultiPolygon, 4326);
    inserted_row public.territories;
begin
    if auth.uid() is null or auth.uid() <> p_owner then
        raise exception 'You can only claim territories for the authenticated user.';
    end if;

    if array_length(p_coordinates, 1) < 3 then
        raise exception 'At least three coordinates are required.';
    end if;

    pts := array[]::geometry[];
    for idx in 1..array_length(p_coordinates, 1) loop
        lat := p_coordinates[idx][1];
        lon := p_coordinates[idx][2];
        pts := array_append(pts, ST_SetSRID(ST_MakePoint(lon, lat), 4326));
    end loop;

    if not ST_Equals(pts[1], pts[array_length(pts, 1)]) then
        pts := array_append(pts, pts[1]);
    end if;

    new_geom := ST_MakePolygon(ST_MakeLine(pts));
    new_geom := ST_Buffer(new_geom, 0); -- fix self-intersections
    new_geom := ST_MakeValid(new_geom);
    new_geom := ST_SimplifyPreserveTopology(new_geom, 0.00001);
    new_geom := ST_ForceRHR(new_geom);
    new_geom := ST_Multi(new_geom);

    if ST_IsEmpty(new_geom) then
        raise exception 'Invalid polygon supplied.';
    end if;

    if ST_Area(new_geom::geography) < 10 then
        raise exception 'Territory is too small to capture.';
    end if;

    -- Remove overlapping geometry from existing territories
    update public.territories
    set geom = ST_Multi(ST_Difference(geom, new_geom)),
        updated_at = now()
    where ST_Intersects(geom, new_geom);

    delete from public.territories
    where ST_IsEmpty(geom);

    insert into public.territories(owner_id, activity_type, geom)
    values (p_owner, p_activity, new_geom)
    returning * into inserted_row;

    insert into public.territory_events(territory_id, actor_id, event_type, metadata)
    values (inserted_row.id, p_owner, 'claim', jsonb_build_object('activity', p_activity, 'area_m2', inserted_row.area_m2));

    return query
    select inserted_row.id,
           inserted_row.owner_id,
           inserted_row.activity_type,
           inserted_row.area_m2,
           ST_AsGeoJSON(inserted_row.geom)::jsonb as geojson;
end;
$$;

revoke all on function public.claim_territory(uuid, text, double precision[][]) from public;
grant execute on function public.claim_territory(uuid, text, double precision[][]) to authenticated;
