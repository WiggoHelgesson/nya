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
}

    struct TileFeature: Decodable {
        let tile_id: Int64
        let owner_id: String?
        let geom: GeoJSONPolygon
        let last_updated_at: String?
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
            "min_lat": minLat,
            "min_lon": minLon,
            "max_lat": maxLat,
            "max_lon": maxLon
        ]
        let tiles: [TileFeature] = try await supabase.database
            .rpc("get_tiles_in_bounds", params: params)
            .execute()
            .value
        return tiles
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
                    coordinates: [CLLocationCoordinate2D]) async throws {
        guard let ownerUUID = UUID(uuidString: ownerId) else {
            throw TerritoryServiceError.invalidOwnerId(ownerId)
        }
        
        try await AuthSessionManager.shared.ensureValidSession()
        
        let payload = TileClaimParams(
            p_owner: ownerUUID,
            p_activity: activityId,
            p_coords: coordinates.map { [$0.latitude, $0.longitude] }
        )
        
        do {
            _ = try await supabase.database
                .rpc("claim_tiles", params: payload)
                .execute()
            print("✅ Tiles claimed successfully for owner: \(ownerId)")
        } catch {
            print("❌ claim_tiles failed: \(error)")
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

