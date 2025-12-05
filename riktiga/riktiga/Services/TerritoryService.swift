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
        let created_at: String?  // Changed from Date? to avoid decoding issues
        let updated_at: String?  // Changed from Date? to avoid decoding issues
    }
    
    struct GeoJSONMultiPolygon: Decodable {
        let type: String
        let coordinates: [[[[Double]]]] // MultiPolygon -> Polygon -> Ring -> [lon, lat]
    }
    
    func fetchTerritories() async throws -> [TerritoryFeature] {
        print("🌍 TerritoryService.fetchTerritories called")
        
        do {
            try await AuthSessionManager.shared.ensureValidSession()
            print("✅ Auth session valid for fetch")
            
            // Fetch ALL territories - no filter on owner
            let result: [TerritoryFeature] = try await supabase.database
                .from("territory_geojson")
                .select()
                .order("updated_at", ascending: false)
                .execute()
                .value
            
            print("✅ Fetched \(result.count) territories from database")
            
            // Log details about each territory
            let uniqueOwners = Set(result.map { $0.owner_id })
            print("📊 Unique territory owners: \(uniqueOwners.count)")
            for owner in uniqueOwners {
                let count = result.filter { $0.owner_id == owner }.count
                print("   - Owner \(owner.prefix(8))...: \(count) territories")
            }
            
            return result
        } catch {
            print("❌ fetchTerritories FAILED: \(error)")
            print("❌ Error details: \(String(describing: error))")
            throw error
        }
    }
    
    func claimTerritory(ownerId: String,
                        activity: ActivityType,
                        coordinates: [CLLocationCoordinate2D]) async throws -> TerritoryFeature {
        print("🚀 TerritoryService.claimTerritory called")
        print("   - ownerId: \(ownerId)")
        print("   - activity: \(activity.rawValue)")
        print("   - coordinates count: \(coordinates.count)")
        
        guard let ownerUUID = UUID(uuidString: ownerId) else {
            print("❌ Invalid owner ID format: \(ownerId)")
            throw TerritoryServiceError.invalidOwnerId(ownerId)
        }
        print("✅ Owner UUID parsed: \(ownerUUID)")
        
        try await AuthSessionManager.shared.ensureValidSession()
        print("✅ Auth session valid")
        
        let payload = TerritoryClaimParams(
            p_owner: ownerUUID,
            p_activity: activity.rawValue,
            p_coordinates: coordinates.map { [$0.latitude, $0.longitude] }
        )
        print("📦 Payload created, sending to Supabase RPC...")
        
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

