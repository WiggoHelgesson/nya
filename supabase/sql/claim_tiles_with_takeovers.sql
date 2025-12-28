-- claim_tiles_with_takeovers
-- Same as claim_tiles, but returns which owners were taken over during this claim.
-- Output is DISTINCT previous owners (not the current user), with how many tiles were taken from each.

DROP FUNCTION IF EXISTS public.claim_tiles_with_takeovers(
  uuid,
  uuid,
  double precision[][],
  double precision,
  integer,
  text
);

CREATE OR REPLACE FUNCTION public.claim_tiles_with_takeovers(
  p_owner uuid,
  p_activity uuid,
  p_coords double precision[][],   -- [lat, lon]
  p_distance_km double precision DEFAULT NULL,
  p_duration_sec integer DEFAULT NULL,
  p_pace text DEFAULT NULL
)
RETURNS TABLE (
  previous_owner_id uuid,
  username text,
  avatar_url text,
  tiles_taken integer
)
AS $$
DECLARE
  new_poly geometry;
  filled_poly geometry;
  -- Grid size in degrees (approx 25m)
  grid_size double precision := 0.000225;
  min_x double precision;
  min_y double precision;
  max_x double precision;
  max_y double precision;
  x_val double precision;
  y_val double precision;
  tile_geom geometry;
  tile_center geometry;
  coord_count integer;
  tile_id_val bigint;
  old_owner uuid;
  takeover_counts jsonb := '{}'::jsonb; -- key = owner uuid text, value = count
BEGIN
  coord_count := array_length(p_coords, 1);
  IF coord_count IS NULL OR coord_count < 3 THEN
    RETURN;
  END IF;

  -- Build polygon from coords (PostGIS expects (lon, lat))
  new_poly := ST_MakePolygon(ST_MakeLine(ARRAY(
      SELECT ST_SetSRID(ST_MakePoint(p_coords[i][2], p_coords[i][1]), 4326)
      FROM generate_subscripts(p_coords,1) i
  )));

  new_poly := ST_MakeValid(new_poly);
  IF ST_IsEmpty(new_poly) OR new_poly IS NULL THEN
    RETURN;
  END IF;

  -- Add a buffer around the edge to catch tiles along the path
  filled_poly := ST_Union(
    new_poly,
    ST_Buffer(ST_ExteriorRing(new_poly), 0.0001) -- ~10m buffer along the path
  );

  -- Bounds
  min_x := floor(ST_XMin(filled_poly) / grid_size) * grid_size;
  min_y := floor(ST_YMin(filled_poly) / grid_size) * grid_size;
  max_x := ceil(ST_XMax(filled_poly) / grid_size) * grid_size;
  max_y := ceil(ST_YMax(filled_poly) / grid_size) * grid_size;

  x_val := min_x;
  WHILE x_val <= max_x LOOP
    y_val := min_y;
    WHILE y_val <= max_y LOOP
      tile_geom := ST_SetSRID(ST_MakeEnvelope(
        x_val,
        y_val,
        x_val + grid_size,
        y_val + grid_size,
        4326
      ), 4326);

      tile_center := ST_Centroid(tile_geom);

      IF ST_Within(tile_center, new_poly) OR ST_Intersects(tile_geom, filled_poly) THEN
        -- Compute deterministic tile id (same as claim_tiles)
        tile_id_val := abs(hashtext(ST_AsText(ST_SnapToGrid(tile_center, grid_size))))::bigint;

        -- Read previous owner BEFORE upsert (this is what we "took over")
        SELECT t.owner_id INTO old_owner
        FROM public.territory_tiles t
        WHERE t.tile_id = tile_id_val
        LIMIT 1;

        IF old_owner IS NOT NULL AND old_owner <> p_owner THEN
          takeover_counts := jsonb_set(
            takeover_counts,
            ARRAY[old_owner::text],
            to_jsonb(COALESCE((takeover_counts ->> old_owner::text)::int, 0) + 1),
            true
          );
        END IF;

        -- Upsert tile ownership + metadata
        INSERT INTO public.territory_tiles (tile_id, geom, owner_id, activity_id, distance_km, duration_sec, pace, last_updated_at)
        VALUES (
          tile_id_val,
          tile_geom,
          p_owner,
          p_activity,
          p_distance_km,
          p_duration_sec,
          p_pace,
          now()
        )
        ON CONFLICT (tile_id) DO UPDATE
          SET owner_id = EXCLUDED.owner_id,
              activity_id = EXCLUDED.activity_id,
              distance_km = EXCLUDED.distance_km,
              duration_sec = EXCLUDED.duration_sec,
              pace = EXCLUDED.pace,
              last_updated_at = now();
      END IF;

      y_val := y_val + grid_size;
    END LOOP;
    x_val := x_val + grid_size;
  END LOOP;

  -- Return takeover users (distinct) with profile data if available
  RETURN QUERY
  SELECT
    (e.key)::uuid AS previous_owner_id,
    p.username::text,
    p.avatar_url::text,
    (e.value)::int AS tiles_taken
  FROM jsonb_each_text(takeover_counts) e
  LEFT JOIN public.profiles p
    ON p.id::text = e.key;
END;
$$ LANGUAGE plpgsql SECURITY DEFINER;

GRANT EXECUTE ON FUNCTION public.claim_tiles_with_takeovers(
  uuid,
  uuid,
  double precision[][],
  double precision,
  integer,
  text
) TO authenticated;


