-- get_territory_owners_in_bounds_v2
-- Returns ONE (simplified) MultiPolygon per owner within the viewport bounds.
-- This avoids sending tens of thousands of tiles to the client.
--
-- Key properties:
-- - No overlaps: ownership is tile-based, so dissolving by owner produces disjoint areas.
-- - Fast rendering: few overlays (owners) vs many overlays (tiles).
-- - Simplification: done in meters (EPSG:3857) to keep vertex counts low and MapKit stable.

DROP FUNCTION IF EXISTS public.get_territory_owners_in_bounds_v2(
    double precision,
    double precision,
    double precision,
    double precision
);

CREATE OR REPLACE FUNCTION public.get_territory_owners_in_bounds_v2(
    min_lat double precision,
    max_lat double precision,
    min_lon double precision,
    max_lon double precision
)
RETURNS TABLE (
    owner_id text,
    area_m2 double precision,
    geom jsonb,
    last_claim text
) AS $$
DECLARE
    env_4326 geometry;
    env_3857 geometry;
    diag_m double precision;
    tol_m double precision;
BEGIN
    env_4326 := ST_MakeEnvelope(min_lon, min_lat, max_lon, max_lat, 4326);
    env_3857 := ST_Transform(env_4326, 3857);

    -- viewport diagonal in meters
    diag_m := sqrt(
        pow(ST_XMax(env_3857) - ST_XMin(env_3857), 2) +
        pow(ST_YMax(env_3857) - ST_YMin(env_3857), 2)
    );

    -- dynamic simplify tolerance:
    -- zoomed in => ~5m; zoomed out => up to 80m
    tol_m := greatest(5.0, least(80.0, diag_m / 500.0));

    RETURN QUERY
    WITH candidate_tiles AS (
        SELECT
            t.owner_id,
            t.geom,
            t.last_updated_at
        FROM public.territory_tiles t
        WHERE t.geom && env_4326
          AND t.owner_id IS NOT NULL
    ),
    per_owner AS (
        SELECT
            owner_id,
            max(last_updated_at) AS last_claim_ts,
            -- dissolve tiles for this owner (in meters)
            ST_UnaryUnion(
                ST_Collect(
                    ST_Transform(geom, 3857)
                )
            ) AS geom_3857
        FROM candidate_tiles
        GROUP BY owner_id
    ),
    clipped AS (
        SELECT
            owner_id,
            last_claim_ts,
            -- clip to viewport to keep geometry small
            ST_Intersection(geom_3857, env_3857) AS geom_clip_3857
        FROM per_owner
        WHERE geom_3857 IS NOT NULL AND NOT ST_IsEmpty(geom_3857)
    ),
    simplified AS (
        SELECT
            owner_id,
            last_claim_ts,
            ST_SimplifyPreserveTopology(geom_clip_3857, tol_m) AS geom_simpl_3857
        FROM clipped
        WHERE geom_clip_3857 IS NOT NULL AND NOT ST_IsEmpty(geom_clip_3857)
    )
    SELECT
        s.owner_id::text,
        ST_Area(ST_Transform(s.geom_simpl_3857, 4326)::geography)::double precision AS area_m2,
        ST_AsGeoJSON(ST_Transform(s.geom_simpl_3857, 4326))::jsonb AS geom,
        s.last_claim_ts::text AS last_claim
    FROM simplified s
    WHERE s.geom_simpl_3857 IS NOT NULL AND NOT ST_IsEmpty(s.geom_simpl_3857);
END;
$$ LANGUAGE plpgsql STABLE SECURITY DEFINER
SET search_path = public;

GRANT EXECUTE ON FUNCTION public.get_territory_owners_in_bounds_v2(
    double precision,
    double precision,
    double precision,
    double precision
) TO authenticated;


