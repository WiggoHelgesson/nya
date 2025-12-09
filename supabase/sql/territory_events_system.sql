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
    session_distance_km double precision,  -- Distance in km from the session
    session_duration_sec integer,          -- Duration in seconds from the session
    session_pace text,                     -- Pace string (e.g., "5:30") from the session
    created_at timestamptz not null default now(),
    updated_at timestamptz not null default now()
);

-- Add columns if table already exists
DO $$
BEGIN
    IF NOT EXISTS (SELECT 1 FROM information_schema.columns WHERE table_name = 'territories' AND column_name = 'session_distance_km') THEN
        ALTER TABLE public.territories ADD COLUMN session_distance_km double precision;
    END IF;
    IF NOT EXISTS (SELECT 1 FROM information_schema.columns WHERE table_name = 'territories' AND column_name = 'session_duration_sec') THEN
        ALTER TABLE public.territories ADD COLUMN session_duration_sec integer;
    END IF;
    IF NOT EXISTS (SELECT 1 FROM information_schema.columns WHERE table_name = 'territories' AND column_name = 'session_pace') THEN
        ALTER TABLE public.territories ADD COLUMN session_pace text;
    END IF;
END $$;

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

-- Drop existing policies to recreate them cleanly
DROP POLICY IF EXISTS territories_select ON public.territories;
DROP POLICY IF EXISTS territories_insert ON public.territories;
DROP POLICY IF EXISTS territories_update ON public.territories;
DROP POLICY IF EXISTS territories_delete ON public.territories;
DROP POLICY IF EXISTS territory_events_select ON public.territory_events;
DROP POLICY IF EXISTS territory_events_insert ON public.territory_events;

-- All users can SELECT all territories (this is key for seeing everyone's areas!)
CREATE POLICY territories_select ON public.territories
    FOR SELECT
    USING (true);

-- Users can INSERT their own territories
CREATE POLICY territories_insert ON public.territories
    FOR INSERT
    WITH CHECK (auth.uid() = owner_id);

-- Users can UPDATE their own territories
CREATE POLICY territories_update ON public.territories
    FOR UPDATE
    USING (auth.uid() = owner_id)
    WITH CHECK (auth.uid() = owner_id);

-- Users can DELETE their own territories
CREATE POLICY territories_delete ON public.territories
    FOR DELETE
    USING (auth.uid() = owner_id);

-- Territory events policies
CREATE POLICY territory_events_select ON public.territory_events
    FOR SELECT
    USING (true);

CREATE POLICY territory_events_insert ON public.territory_events
    FOR INSERT
    WITH CHECK (auth.uid() = actor_id);

-- Grant permissions
GRANT SELECT, INSERT, UPDATE, DELETE ON public.territories TO authenticated;
GRANT SELECT, INSERT ON public.territory_events TO authenticated;

-- Read-friendly view that exposes GeoJSON polygons
create or replace view public.territory_geojson as
select
    id,
    owner_id,
    activity_type,
    area_m2,
    session_distance_km,
    session_duration_sec,
    session_pace,
    created_at,
    updated_at,
    ST_AsGeoJSON(geom)::jsonb as geojson
from public.territories;

grant select on public.territory_geojson to authenticated;

-- Drop ALL existing versions of claim_territory before creating
drop function if exists public.claim_territory(uuid, text, double precision[][]) cascade;
drop function if exists public.claim_territory(uuid, text, double precision[][], double precision, integer, text) cascade;
drop function if exists public.claim_territory(uuid, text, double precision[]) cascade;
drop function if exists public.claim_territory(uuid, text, double precision[], double precision, integer, text) cascade;

-- Claim territory RPC
create or replace function public.claim_territory(
    p_owner uuid,
    p_activity text,
    p_coordinates double precision[][],
    p_distance_km double precision default null,
    p_duration_sec integer default null,
    p_pace text default null
)
returns table (
    id uuid,
    owner_id uuid,
    activity_type text,
    area_m2 double precision,
    session_distance_km double precision,
    session_duration_sec integer,
    session_pace text,
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
    poly_geom geometry;  -- No type constraint for intermediate processing
    multi_geom geometry(MultiPolygon, 4326);
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

    -- Create polygon first (no type constraint)
    poly_geom := ST_MakePolygon(ST_MakeLine(pts));
    poly_geom := ST_Buffer(poly_geom, 0); -- fix self-intersections
    poly_geom := ST_MakeValid(poly_geom);
    poly_geom := ST_SimplifyPreserveTopology(poly_geom, 0.00001);
    poly_geom := ST_ForceRHR(poly_geom);
    poly_geom := ST_SetSRID(poly_geom, 4326);

    if ST_IsEmpty(poly_geom) or poly_geom is null then
        raise exception 'Invalid polygon supplied.';
    end if;

    if ST_Area(poly_geom::geography) < 10 then
        raise exception 'Territory is too small to capture.';
    end if;

    -- Convert to MultiPolygon using explicit cast
    multi_geom := ST_Multi(poly_geom)::geometry(MultiPolygon, 4326);

    -- Remove overlapping geometry from existing territories
    update public.territories
    set geom = ST_Multi(ST_Difference(geom, multi_geom))::geometry(MultiPolygon, 4326),
        updated_at = now()
    where ST_Intersects(geom, multi_geom);

    delete from public.territories
    where ST_IsEmpty(geom);

    insert into public.territories(owner_id, activity_type, geom, session_distance_km, session_duration_sec, session_pace)
    values (p_owner, p_activity, multi_geom, p_distance_km, p_duration_sec, p_pace)
    returning * into inserted_row;

    insert into public.territory_events(territory_id, actor_id, event_type, metadata)
    values (inserted_row.id, p_owner, 'claim', jsonb_build_object('activity', p_activity, 'area_m2', inserted_row.area_m2));

    return query
    select inserted_row.id,
           inserted_row.owner_id,
           inserted_row.activity_type,
           inserted_row.area_m2,
           inserted_row.session_distance_km,
           inserted_row.session_duration_sec,
           inserted_row.session_pace,
           ST_AsGeoJSON(inserted_row.geom)::jsonb as geojson;
end;
$$;

-- Grant permissions on the claim_territory function
grant execute on function public.claim_territory(uuid, text, double precision[][], double precision, integer, text) to authenticated;

-- ============================================
-- VIEWPORT-BASED TERRITORY LOADING (PERFORMANCE)
-- ============================================

-- Function to get territories within a bounding box
drop function if exists public.get_territories_in_bounds(double precision, double precision, double precision, double precision);

create or replace function public.get_territories_in_bounds(
    min_lat double precision,
    max_lat double precision,
    min_lon double precision,
    max_lon double precision
)
returns table (
    id uuid,
    owner_id uuid,
    activity_type text,
    area_m2 double precision,
    session_distance_km double precision,
    session_duration_sec integer,
    session_pace text,
    geojson jsonb,
    created_at timestamptz,
    updated_at timestamptz
)
language sql
stable
security definer
set search_path = public
as $$
    select
        t.id,
        t.owner_id,
        t.activity_type,
        t.area_m2,
        t.session_distance_km,
        t.session_duration_sec,
        t.session_pace,
        ST_AsGeoJSON(t.geom)::jsonb as geojson,
        t.created_at,
        t.updated_at
    from public.territories t
    where ST_Intersects(
        t.geom,
        ST_MakeEnvelope(min_lon, min_lat, max_lon, max_lat, 4326)
    )
    order by t.area_m2 desc
    limit 100;  -- Limit to prevent loading too many territories
$$;

-- Grant execute to authenticated users
grant execute on function public.get_territories_in_bounds(double precision, double precision, double precision, double precision) to authenticated;
grant execute on function public.get_territories_in_bounds(double precision, double precision, double precision, double precision) to anon;
