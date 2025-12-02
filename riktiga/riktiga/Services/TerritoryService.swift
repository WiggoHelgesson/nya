import Foundation
import CoreLocation
import Supabase

enum TerritoryServiceError: Error {
    case emptyResponse
}

nonisolated(unsafe) struct TerritoryClaimParams: Encodable, Sendable {
    let p_owner: String
    let p_activity: String
    let p_coordinates: [[Double]]
}

final class TerritoryService {
    static let shared = TerritoryService()
    private let supabase = SupabaseConfig.supabase
    
    struct TerritoryFeature: Decodable {
        let id: UUID
        let owner_id: String
        let activity_type: String
        let area_m2: Double
        let geojson: GeoJSONMultiPolygon
        let created_at: Date?
        let updated_at: Date?
    }
    
    struct GeoJSONMultiPolygon: Decodable {
        let type: String
        let coordinates: [[[[Double]]]] // MultiPolygon -> Polygon -> Ring -> [lon, lat]
    }
    
    func fetchTerritories() async throws -> [TerritoryFeature] {
        try await supabase.database
            .from("territory_geojson")
            .select()
            .order("updated_at", ascending: false)
            .execute()
            .value
    }
    
    func claimTerritory(ownerId: String,
                        activity: ActivityType,
                        coordinates: [CLLocationCoordinate2D]) async throws -> TerritoryFeature {
        let payload = TerritoryClaimParams(
            p_owner: ownerId,
            p_activity: activity.rawValue,
            p_coordinates: coordinates.map { [$0.latitude, $0.longitude] }
        )
        
        let response: [TerritoryFeature] = try await supabase.database
            .rpc("claim_territory", params: payload)
            .execute()
            .value
        
        guard let feature = response.first else {
            throw TerritoryServiceError.emptyResponse
        }
        return feature
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
        
        return Territory(
            id: id,
            ownerId: owner_id,
            activity: ActivityType(rawValue: activity_type),
            area: area_m2,
            polygons: polygons
        )
    }
}

