CREATE OR REPLACE FUNCTION claim_tiles(
  p_owner UUID,
  p_activity UUID,
  p_coords double precision[][]   -- [lat, lon]
) RETURNS VOID AS $$
DECLARE
  new_poly geometry;
  -- Grid size in degrees (approx 50m)
  grid_size double precision := 0.00045; 
  tile RECORD;
BEGIN
  -- 1. Build polygon from coordinates
  -- PostGIS expects (lon, lat)
  new_poly := ST_MakePolygon(ST_MakeLine(ARRAY(
      SELECT ST_SetSRID(ST_MakePoint(p_coords[i][2], p_coords[i][1]), 4326)
      FROM generate_subscripts(p_coords,1) i
  )));

  -- 2. Make valid and buffer
  -- Buffer by ~5m (0.00005 deg) to give "thickness" to the path
  -- This ensures that even a thin line (out and back) covers area and intersects tiles.
  -- It also fixes self-intersections or collapsed polygons.
  new_poly := ST_Buffer(ST_MakeValid(new_poly), 0.00005);

  IF ST_IsEmpty(new_poly) OR new_poly IS NULL THEN
    -- Should not happen with buffer, but good to check
    RETURN;
  END IF;

  -- 3. Snap to grid and iterate
  -- We identify all grid cells that intersect with our buffered polygon.
  FOR tile IN
    WITH bounds AS (
       SELECT 
         floor(ST_XMin(new_poly) / grid_size) * grid_size as min_x,
         floor(ST_YMin(new_poly) / grid_size) * grid_size as min_y,
         ceil(ST_XMax(new_poly) / grid_size) * grid_size as max_x,
         ceil(ST_YMax(new_poly) / grid_size) * grid_size as max_y
    ),
    grid_cells AS (
       SELECT 
         ST_SetSRID(ST_MakeEnvelope(x, y, x + grid_size, y + grid_size, 4326), 4326) as geom
       FROM bounds,
            generate_series(min_x, max_x, grid_size) as x,
            generate_series(min_y, max_y, grid_size) as y
    )
    SELECT geom FROM grid_cells
    WHERE ST_Intersects(geom, new_poly) 
    -- Removed strict area check to allow capturing any tile touched by the path/buffer
  LOOP
    INSERT INTO territory_tiles (tile_id, geom, owner_id, activity_id, last_updated_at)
    SELECT
      abs(hashtext(ST_AsText(ST_SnapToGrid(ST_Centroid(tile.geom), grid_size))))::bigint,
      tile.geom,
      p_owner,
      p_activity,
      now()
    ON CONFLICT (tile_id) DO UPDATE
      SET owner_id = EXCLUDED.owner_id,
          activity_id = EXCLUDED.activity_id,
          last_updated_at = now();
  END LOOP;
END;
$$ LANGUAGE plpgsql SECURITY DEFINER;
