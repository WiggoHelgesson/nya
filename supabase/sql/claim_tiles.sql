-- Updated claim_tiles with workout metadata
-- Uses WHILE loops instead of generate_series for reliability
-- Claims ALL tiles inside the polygon + along the edge
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
  tiles_created integer := 0;
  coord_count integer;
BEGIN
  -- Debug logging
  coord_count := array_length(p_coords, 1);
  RAISE NOTICE 'claim_tiles called with % coordinates', coord_count;
  
  -- Validate minimum coordinates for polygon
  IF coord_count IS NULL OR coord_count < 3 THEN
    RAISE NOTICE 'Not enough coordinates for polygon (need at least 3)';
    RETURN;
  END IF;
  
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

  -- 3. Also add a buffer around the edge to catch tiles along the path
  filled_poly := ST_Union(
    new_poly,
    ST_Buffer(ST_ExteriorRing(new_poly), 0.0001) -- ~10m buffer along the path
  );

  RAISE NOTICE 'Polygon created, area: % m²', ST_Area(new_poly::geography);

  -- 4. Calculate bounds
  min_x := floor(ST_XMin(filled_poly) / grid_size) * grid_size;
  min_y := floor(ST_YMin(filled_poly) / grid_size) * grid_size;
  max_x := ceil(ST_XMax(filled_poly) / grid_size) * grid_size;
  max_y := ceil(ST_YMax(filled_poly) / grid_size) * grid_size;

  RAISE NOTICE 'Bounds: X[% to %], Y[% to %]', min_x, max_x, min_y, max_y;
  RAISE NOTICE 'Expected iterations: % x %', 
    ceil((max_x - min_x) / grid_size), 
    ceil((max_y - min_y) / grid_size);

  -- 5. Use WHILE loops instead of generate_series for reliability
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
      
      -- Claim if: center is inside polygon OR tile intersects with filled area
      IF ST_Within(tile_center, new_poly) OR ST_Intersects(tile_geom, filled_poly) THEN
        INSERT INTO territory_tiles (tile_id, geom, owner_id, activity_id, distance_km, duration_sec, pace, last_updated_at)
        VALUES (
          abs(hashtext(ST_AsText(ST_SnapToGrid(tile_center, grid_size))))::bigint,
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
      
      y_val := y_val + grid_size;
    END LOOP;
    x_val := x_val + grid_size;
  END LOOP;

  RAISE NOTICE 'Created/updated % tiles for owner %', tiles_created, p_owner;
END;
$$ LANGUAGE plpgsql SECURITY DEFINER;

GRANT EXECUTE ON FUNCTION claim_tiles(UUID, UUID, double precision[][], double precision, integer, text) TO authenticated;
