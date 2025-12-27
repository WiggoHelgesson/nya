import Foundation
import CoreLocation
import Supabase

enum TerritoryServiceError: Error, LocalizedError {
    case emptyResponse
    case invalidOwnerId(String)
    
    var errorDescription: String? {
        switch self {
        case .emptyResponse:
            return "No territory returned from server"
        case .invalidOwnerId(let id):
            return "Invalid owner ID format: \(id)"
        }
    }
}

nonisolated(unsafe) struct TerritoryClaimParams: Encodable, Sendable {
    let p_owner: UUID
    let p_activity: String
    let p_coordinates: [[Double]]
    let p_distance_km: Double?
    let p_duration_sec: Int?
    let p_pace: String?
}

/// Tile-based claim params (no overlap)
nonisolated(unsafe) struct TileClaimParams: Encodable, Sendable {
    let p_owner: UUID
    let p_activity: UUID
    let p_coords: [[Double]]
    let p_distance_km: Double?
    let p_duration_sec: Int?
    let p_pace: String?
}

/// Params for fetching tiles in bounds
nonisolated(unsafe) struct TileBoundsParams: Encodable, Sendable {
    let p_min_lat: Double
    let p_min_lon: Double
    let p_max_lat: Double
    let p_max_lon: Double
    let p_limit: Int
}

    struct TileFeature: Decodable {
        let tile_id: Int64
        let owner_id: String?
        let activity_id: String?
        let distance_km: Double?
        let duration_sec: Int?
        let pace: String?
        let geom: GeoJSONPolygon
        let last_updated_at: String?
        
        // Custom decoder to handle UUID as string
        init(from decoder: Decoder) throws {
            let container = try decoder.container(keyedBy: CodingKeys.self)
            tile_id = try container.decode(Int64.self, forKey: .tile_id)
            
            // Handle owner_id as UUID or String
            if let uuid = try? container.decode(UUID.self, forKey: .owner_id) {
                owner_id = uuid.uuidString
            } else {
                owner_id = try? container.decode(String.self, forKey: .owner_id)
            }
            
            // Handle activity_id as UUID or String
            if let uuid = try? container.decode(UUID.self, forKey: .activity_id) {
                activity_id = uuid.uuidString
            } else {
                activity_id = try? container.decode(String.self, forKey: .activity_id)
            }
            
            distance_km = try? container.decode(Double.self, forKey: .distance_km)
            duration_sec = try? container.decode(Int.self, forKey: .duration_sec)
            pace = try? container.decode(String.self, forKey: .pace)
            geom = try container.decode(GeoJSONPolygon.self, forKey: .geom)
            last_updated_at = try? container.decode(String.self, forKey: .last_updated_at)
        }
        
        enum CodingKeys: String, CodingKey {
            case tile_id, owner_id, activity_id, distance_km, duration_sec, pace, geom, last_updated_at
        }
    }

    struct GeoJSONPolygon: Decodable {
        let type: String
        let coordinates: [[[Double]]] // Polygon -> Ring -> [lon, lat]
    }

final class TerritoryService {
    static let shared = TerritoryService()
    private let supabase = SupabaseConfig.supabase
    
    // MARK: - Models
    
    /// Legacy polygon feature (kept for backwards compatibility)
    struct TerritoryFeature: Decodable {
        let id: UUID
        let owner_id: String
        let activity_type: String
        let area_m2: Double
        let session_distance_km: Double?
        let session_duration_sec: Int?
        let session_pace: String?
        let geojson: GeoJSONMultiPolygon
        let created_at: String?
        let updated_at: String?
    }
    
    /// Tile-unioned owner feature (no overlap)
    struct OwnerTerritoryFeature: Decodable {
        let owner_id: String
        let area_m2: Double
        let geom: GeoJSONMultiPolygon
        let last_claim: String?
    }
    
    struct GeoJSONMultiPolygon: Decodable {
        let type: String
        let coordinates: [[[[Double]]]] // MultiPolygon -> Polygon -> Ring -> [lon, lat]
    }
    
    // MARK: - Fetch unioned territories (preferred)
    func fetchTerritories() async throws -> [OwnerTerritoryFeature] {
        try await AuthSessionManager.shared.ensureValidSession()
        
        // View: territory_owners (owner_id, area_m2, geom, last_claim)
        let result: [OwnerTerritoryFeature] = try await supabase.database
            .from("territory_owners")
            .select("""
                owner_id,
                area_m2,
                geom,
                last_claim
            """)
            .execute()
            .value
        
        return result
    }
    
    /// Fetch territories within a bounding box (viewport-based loading)
    func fetchTerritoriesInBounds(
        minLat: Double,
        maxLat: Double,
        minLon: Double,
        maxLon: Double
    ) async throws -> [OwnerTerritoryFeature] {
        try await AuthSessionManager.shared.ensureValidSession()
        
        let params: [String: Double] = [
            "min_lat": minLat,
            "max_lat": maxLat,
            "min_lon": minLon,
            "max_lon": maxLon
        ]
        
        do {
            let result: [OwnerTerritoryFeature] = try await supabase.database
                .rpc("get_territory_owners_in_bounds", params: params)
                .execute()
                .value
            
            return result
        } catch {
            // Fallback to full fetch if RPC doesn't exist
            return try await fetchTerritories()
        }
    }

    /// Fetch tiles in bounds (for grid rendering)
    func fetchTilesInBounds(
        minLat: Double,
        maxLat: Double,
        minLon: Double,
        maxLon: Double
    ) async throws -> [TileFeature] {
        try await AuthSessionManager.shared.ensureValidSession()
        let params: [String: Double] = [
            "p_min_lat": minLat,
            "p_min_lon": minLon,
            "p_max_lat": maxLat,
            "p_max_lon": maxLon
        ]
        
        print("🔍 [TILES RPC] Fetching tiles with bounds: lat(\(minLat)-\(maxLat)), lon(\(minLon)-\(maxLon))")
        
        do {
            let tiles: [TileFeature] = try await supabase.database
                .rpc("get_tiles_in_bounds", params: params)
                .execute()
                .value
            
            print("🔍 [TILES RPC] Decoded \(tiles.count) tiles successfully")
            return tiles
        } catch {
            print("❌ [TILES RPC] Decoding error: \(error)")
            throw error
        }
    }
    
    /// Legacy polygon claim (still available if needed)
    func claimTerritory(ownerId: String,
                        activity: ActivityType,
                        coordinates: [CLLocationCoordinate2D],
                        distance: Double? = nil,
                        duration: Int? = nil,
                        pace: String? = nil) async throws -> TerritoryFeature {
        guard let ownerUUID = UUID(uuidString: ownerId) else {
            throw TerritoryServiceError.invalidOwnerId(ownerId)
        }
        
        try await AuthSessionManager.shared.ensureValidSession()
        
        let payload = TerritoryClaimParams(
            p_owner: ownerUUID,
            p_activity: activity.rawValue,
            p_coordinates: coordinates.map { [$0.latitude, $0.longitude] },
            p_distance_km: distance,
            p_duration_sec: duration,
            p_pace: pace
        )
        
        do {
            let response: [TerritoryFeature] = try await supabase.database
                .rpc("claim_territory", params: payload)
                .execute()
                .value
            
            print("✅ RPC response received: \(response.count) features")
            
            guard let feature = response.first else {
                print("❌ RPC returned empty array")
                throw TerritoryServiceError.emptyResponse
            }
            
            print("✅ Territory claimed successfully! ID: \(feature.id)")
            return feature
        } catch {
            print("❌ RPC FAILED with error: \(error)")
            print("   - Error type: \(type(of: error))")
            if let localizedError = error as? LocalizedError {
                print("   - Description: \(localizedError.errorDescription ?? "none")")
            }
            throw error
        }
    }

    /// Tile-based claim (no overlap)
    func claimTiles(ownerId: String,
                    activityId: UUID,
                    coordinates: [CLLocationCoordinate2D],
                    distanceKm: Double? = nil,
                    durationSec: Int? = nil,
                    pace: String? = nil) async throws {
        print("🎯 [CLAIM_TILES] Starting claim for owner: \(ownerId)")
        print("🎯 [CLAIM_TILES] Coordinates count: \(coordinates.count)")
        
        guard let ownerUUID = UUID(uuidString: ownerId) else {
            print("❌ [CLAIM_TILES] Invalid owner ID: \(ownerId)")
            throw TerritoryServiceError.invalidOwnerId(ownerId)
        }
        
        guard coordinates.count >= 3 else {
            print("❌ [CLAIM_TILES] Not enough coordinates: \(coordinates.count) (need at least 3)")
            return
        }
        
        // Log first and last coordinates for debugging
        if let first = coordinates.first, let last = coordinates.last {
            print("🎯 [CLAIM_TILES] First coord: (\(first.latitude), \(first.longitude))")
            print("🎯 [CLAIM_TILES] Last coord: (\(last.latitude), \(last.longitude))")
        }
        
        try await AuthSessionManager.shared.ensureValidSession()
        print("🎯 [CLAIM_TILES] Session valid, preparing payload...")
        
        let payload = TileClaimParams(
            p_owner: ownerUUID,
            p_activity: activityId,
            p_coords: coordinates.map { [$0.latitude, $0.longitude] },
            p_distance_km: distanceKm,
            p_duration_sec: durationSec,
            p_pace: pace
        )
        
        print("🎯 [CLAIM_TILES] Payload prepared, calling RPC...")
        
        do {
            _ = try await supabase.database
                .rpc("claim_tiles", params: payload)
                .execute()
            print("✅ [CLAIM_TILES] Tiles claimed successfully for owner: \(ownerId)")
        } catch {
            print("❌ [CLAIM_TILES] RPC failed with error: \(error)")
            print("❌ [CLAIM_TILES] Error type: \(type(of: error))")
            throw error
        }
    }
}

extension TerritoryService.TerritoryFeature {
    func asTerritory() -> Territory? {
        let polygons = geojson.coordinates.compactMap { polygon -> [CLLocationCoordinate2D]? in
            guard let exteriorRing = polygon.first else { return nil }
            let coords = exteriorRing.compactMap { pair -> CLLocationCoordinate2D? in
                guard pair.count == 2 else { return nil }
                return CLLocationCoordinate2D(latitude: pair[1], longitude: pair[0])
            }
            return coords.isEmpty ? nil : coords
        }
        
        guard !polygons.isEmpty else { return nil }
        
        // Parse created_at date
        var createdDate: Date? = nil
        if let dateString = created_at {
            let formatter = ISO8601DateFormatter()
            formatter.formatOptions = [.withInternetDateTime, .withFractionalSeconds]
            createdDate = formatter.date(from: dateString)
            if createdDate == nil {
                formatter.formatOptions = [.withInternetDateTime]
                createdDate = formatter.date(from: dateString)
            }
        }
        
        return Territory(
            id: id,
            ownerId: owner_id,
            activity: ActivityType(rawValue: activity_type),
            area: area_m2,
            polygons: polygons,
            sessionDistance: session_distance_km,
            sessionDuration: session_duration_sec,
            sessionPace: session_pace,
            createdAt: createdDate
        )
    }
}

extension TerritoryService.OwnerTerritoryFeature {
    func asTerritory() -> Territory? {
        let polygons = geom.coordinates.compactMap { polygon -> [CLLocationCoordinate2D]? in
            guard let exteriorRing = polygon.first else { return nil }
            let coords = exteriorRing.compactMap { pair -> CLLocationCoordinate2D? in
                guard pair.count == 2 else { return nil }
                return CLLocationCoordinate2D(latitude: pair[1], longitude: pair[0])
            }
            return coords.isEmpty ? nil : coords
        }
        
        guard !polygons.isEmpty else { return nil }
        
        // Parse last_claim date if present
        var createdDate: Date? = nil
        if let dateString = last_claim {
            let formatter = ISO8601DateFormatter()
            formatter.formatOptions = [.withInternetDateTime, .withFractionalSeconds]
            createdDate = formatter.date(from: dateString)
            if createdDate == nil {
                formatter.formatOptions = [.withInternetDateTime]
                createdDate = formatter.date(from: dateString)
            }
        }
        
        return Territory(
            id: UUID(), // union has no stable id; use ephemeral
            ownerId: owner_id,
            activity: nil,
            area: area_m2,
            polygons: polygons,
            sessionDistance: nil,
            sessionDuration: nil,
            sessionPace: nil,
            createdAt: createdDate
        )
    }
}

