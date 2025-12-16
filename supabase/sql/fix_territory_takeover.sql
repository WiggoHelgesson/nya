-- Fix territory takeover to only affect OTHER users' territories
-- and add takeover events for tracking

-- Drop and recreate claim_territory function with improved takeover logic
drop function if exists public.claim_territory(uuid, text, double precision[][], double precision, integer, text) cascade;

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
    poly_geom geometry;
    multi_geom geometry(MultiPolygon, 4326);
    inserted_row public.territories;
    affected_territory record;
    old_area double precision;
    new_area double precision;
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

    -- Create polygon
    poly_geom := ST_MakePolygon(ST_MakeLine(pts));
    poly_geom := ST_Buffer(poly_geom, 0);
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

    multi_geom := ST_Multi(poly_geom)::geometry(MultiPolygon, 4326);

    -- IMPROVED: Only remove overlapping geometry from OTHER users' territories
    -- Loop through affected territories to create takeover events
    for affected_territory in 
        select t.id, t.owner_id, ST_Area(t.geom::geography) as current_area
        from public.territories t
        where ST_Intersects(t.geom, multi_geom) 
        and t.owner_id != p_owner  -- Only affect OTHER users' territories
    loop
        old_area := affected_territory.current_area;
        
        -- Calculate new area after subtraction
        select ST_Area(ST_Difference(geom, multi_geom)::geography) into new_area
        from public.territories
        where id = affected_territory.id;
        
        -- Log takeover event if significant area was taken
        if old_area - coalesce(new_area, 0) > 1 then  -- More than 1 m² taken
            insert into public.territory_events(territory_id, actor_id, event_type, metadata)
            values (
                affected_territory.id, 
                p_owner, 
                'takeover', 
                jsonb_build_object(
                    'taken_from', affected_territory.owner_id,
                    'area_taken_m2', old_area - coalesce(new_area, 0),
                    'activity', p_activity
                )
            );
        end if;
    end loop;

    -- Update OTHER users' territories by subtracting the new area
    update public.territories
    set geom = ST_Multi(ST_Difference(geom, multi_geom))::geometry(MultiPolygon, 4326),
        updated_at = now()
    where ST_Intersects(geom, multi_geom)
    and owner_id != p_owner;  -- IMPORTANT: Only affect OTHER users

    -- Delete territories that became empty or too small
    delete from public.territories
    where (ST_IsEmpty(geom) or ST_Area(geom::geography) < 1)
    and owner_id != p_owner;

    -- Insert the new territory
    insert into public.territories(owner_id, activity_type, geom, session_distance_km, session_duration_sec, session_pace)
    values (p_owner, p_activity, multi_geom, p_distance_km, p_duration_sec, p_pace)
    returning * into inserted_row;

    -- Log claim event
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

-- Grant permissions
grant execute on function public.claim_territory(uuid, text, double precision[][], double precision, integer, text) to authenticated;

-- Verify the function exists
select 'Territory takeover function updated successfully!' as status;

