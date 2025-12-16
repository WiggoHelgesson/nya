-- Return tiles within a bounding box (for map viewport)
-- Params (ordered): min_lat, min_lon, max_lat, max_lon
create or replace function public.get_tiles_in_bounds(
    min_lat double precision,
    min_lon double precision,
    max_lat double precision,
    max_lon double precision
)
returns table (
    tile_id bigint,
    owner_id uuid,
    geom jsonb,
    last_updated_at timestamptz
) as $$
begin
    return query
    select
        t.tile_id,
        t.owner_id,
        ST_AsGeoJSON(t.geom)::jsonb as geom,
        t.last_updated_at
    from public.territory_tiles t
    where t.geom && ST_MakeEnvelope(min_lon, min_lat, max_lon, max_lat, 4326);
end;
$$ language plpgsql stable security definer;

grant execute on function public.get_tiles_in_bounds(double precision, double precision, double precision, double precision) to authenticated;

