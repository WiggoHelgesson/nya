-- Updated claim_tiles with workout metadata
-- Now claims ALL tiles inside the polygon (not just along the edge)
-- This makes the Zonkriget map show the exact same area as during the workout
DROP FUNCTION IF EXISTS claim_tiles(UUID, UUID, double precision[][], double precision, integer, text);

CREATE OR REPLACE FUNCTION claim_tiles(
  p_owner UUID,
  p_activity UUID,
  p_coords double precision[][],   -- [lat, lon]
  p_distance_km double precision DEFAULT NULL,
  p_duration_sec integer DEFAULT NULL,
  p_pace text DEFAULT NULL
) RETURNS VOID AS $$
DECLARE
  new_poly geometry;
  filled_poly geometry;
  -- Grid size in degrees (approx 25m for better resolution)
  grid_size numeric := 0.000225; 
  tile RECORD;
  min_x numeric;
  min_y numeric;
  max_x numeric;
  max_y numeric;
  x_val numeric;
  y_val numeric;
  tile_geom geometry;
  tile_center geometry;
  tiles_created integer := 0;
BEGIN
  -- Debug logging
  RAISE NOTICE 'claim_tiles called with % coordinates', array_length(p_coords, 1);
  
  -- 1. Build polygon from coordinates
  -- PostGIS expects (lon, lat)
  new_poly := ST_MakePolygon(ST_MakeLine(ARRAY(
      SELECT ST_SetSRID(ST_MakePoint(p_coords[i][2], p_coords[i][1]), 4326)
      FROM generate_subscripts(p_coords,1) i
  )));

  -- 2. Make valid - this fills the entire polygon interior
  new_poly := ST_MakeValid(new_poly);

  IF ST_IsEmpty(new_poly) OR new_poly IS NULL THEN
    RAISE NOTICE 'Polygon is empty after MakeValid';
    RETURN;
  END IF;

  -- 3. Also add a small buffer around the edge to catch tiles along the path
  -- This ensures we get tiles both INSIDE and along the EDGE of the route
  filled_poly := ST_Union(
    new_poly,
    ST_Buffer(ST_ExteriorRing(new_poly), 0.0001) -- ~10m buffer along the path
  );

  RAISE NOTICE 'Polygon created, area: % m²', ST_Area(new_poly::geography);

  -- 4. Calculate bounds with margin
  min_x := floor(ST_XMin(filled_poly)::numeric / grid_size) * grid_size;
  min_y := floor(ST_YMin(filled_poly)::numeric / grid_size) * grid_size;
  max_x := ceil(ST_XMax(filled_poly)::numeric / grid_size) * grid_size;
  max_y := ceil(ST_YMax(filled_poly)::numeric / grid_size) * grid_size;

  RAISE NOTICE 'Bounds: % to %, % to %', min_x, max_x, min_y, max_y;

  -- 5. Iterate over grid cells
  -- Claim tiles that are either:
  --   a) Completely inside the polygon (center point is inside)
  --   b) Intersect with the buffered edge
  FOR x_val IN SELECT generate_series(min_x, max_x, grid_size)
  LOOP
    FOR y_val IN SELECT generate_series(min_y, max_y, grid_size)
    LOOP
      tile_geom := ST_SetSRID(ST_MakeEnvelope(
        x_val::double precision, 
        y_val::double precision, 
        (x_val + grid_size)::double precision, 
        (y_val + grid_size)::double precision, 
        4326
      ), 4326);
      
      tile_center := ST_Centroid(tile_geom);
      
      -- Claim if: center is inside polygon OR tile intersects with filled area
      IF ST_Within(tile_center, new_poly) OR ST_Intersects(tile_geom, filled_poly) THEN
        INSERT INTO territory_tiles (tile_id, geom, owner_id, activity_id, distance_km, duration_sec, pace, last_updated_at)
        VALUES (
          abs(hashtext(ST_AsText(ST_SnapToGrid(tile_center, grid_size::double precision))))::bigint,
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
        
        tiles_created := tiles_created + 1;
      END IF;
    END LOOP;
  END LOOP;

  RAISE NOTICE 'Created/updated % tiles', tiles_created;
END;
$$ LANGUAGE plpgsql SECURITY DEFINER;

GRANT EXECUTE ON FUNCTION claim_tiles(UUID, UUID, double precision[][], double precision, integer, text) TO authenticated;
