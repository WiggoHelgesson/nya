import Foundation
import CoreLocation
import Supabase

/// Model for an active friend's session
struct ActiveFriendSession: Identifiable, Codable {
    let id: String
    let oderId: String
    let userName: String
    let avatarUrl: String?
    let activityType: String
    let startedAt: Date
    let latitude: Double?
    let longitude: Double?
    
    var userId: String { oderId }
    
    var coordinate: CLLocationCoordinate2D? {
        guard let lat = latitude, let lon = longitude else { return nil }
        return CLLocationCoordinate2D(latitude: lat, longitude: lon)
    }
    
    var duration: TimeInterval {
        Date().timeIntervalSince(startedAt)
    }
    
    var formattedDuration: String {
        let minutes = Int(duration) / 60
        let hours = minutes / 60
        let mins = minutes % 60
        if hours > 0 {
            return "\(hours)h \(mins)m"
        }
        return "\(mins) min"
    }
}

/// Service to manage active sessions and share location with friends
final class ActiveSessionService {
    static let shared = ActiveSessionService()
    
    private let supabase = SupabaseConfig.supabase
    
    private init() {}
    
    // MARK: - Start Active Session
    
    /// Called when user starts a workout session
    /// Returns the session ID for real-time syncing
    @discardableResult
    func startSession(userId: String, activityType: String, location: CLLocation?, userName: String? = nil) async throws -> String? {
        print("🏋️ Starting active session for user: \(userId), name: \(userName ?? "unknown"), type: \(activityType)")
        
        let sessionData = ActiveSessionInsert(
            userId: userId,
            activityType: activityType,
            startedAt: ISO8601DateFormatter().string(from: Date()),
            latitude: location?.coordinate.latitude,
            longitude: location?.coordinate.longitude,
            isActive: true
        )
        
        do {
            print("📤 Upserting session data for user: \(userId)")
            try await supabase
                .from("active_sessions")
                .upsert(sessionData, onConflict: "user_id")
                .execute()
            
            print("✅ Successfully saved active session to database for user \(userId)")
            
            // Fetch the session ID
            let sessionId = try await getSessionId(userId: userId)
            return sessionId
        } catch {
            print("❌ Failed to save active session: \(error)")
            print("❌ Error details: \(String(describing: error))")
            throw error
        }
        
        // Note: Notification is handled below after returning
    }
    
    /// Get the current session ID for a user
    func getSessionId(userId: String) async throws -> String? {
        let response = try await supabase
            .from("active_sessions")
            .select("id")
            .eq("user_id", value: userId)
            .eq("is_active", value: true)
            .single()
            .execute()
        
        struct SessionIdResponse: Codable {
            let id: String
        }
        
        let session = try JSONDecoder().decode(SessionIdResponse.self, from: response.data)
        return session.id
    }
    
    /// Notify followers about the session (call separately after startSession)
    func notifyFollowers(userId: String, userName: String, activityType: String) async {
        await notifyFollowersAboutSession(userId: userId, userName: userName, activityType: activityType)
    }
    
    /// Send push notifications to followers when a session starts
    private func notifyFollowersAboutSession(userId: String, userName: String, activityType: String) async {
        do {
            try await supabase.functions.invoke(
                "notify-active-session",
                options: FunctionInvokeOptions(
                    body: [
                        "userId": userId,
                        "userName": userName,
                        "activityType": activityType
                    ]
                )
            )
            print("✅ Notified followers about active session")
        } catch {
            print("⚠️ Failed to notify followers: \(error)")
        }
    }
    
    // MARK: - Update Session Location
    
    /// Update the current session's location
    func updateLocation(userId: String, location: CLLocation) async throws {
        let updateData = LocationUpdate(
            latitude: location.coordinate.latitude,
            longitude: location.coordinate.longitude,
            updatedAt: ISO8601DateFormatter().string(from: Date())
        )
        
        try await supabase
            .from("active_sessions")
            .update(updateData)
            .eq("user_id", value: userId)
            .execute()
    }
    
    private struct LocationUpdate: Encodable {
        let latitude: Double
        let longitude: Double
        let updatedAt: String
        
        enum CodingKeys: String, CodingKey {
            case latitude
            case longitude
            case updatedAt = "updated_at"
        }
    }
    
    // MARK: - End Active Session
    
    /// Called when user ends a workout session
    func endSession(userId: String) async throws {
        try await supabase
            .from("active_sessions")
            .delete()
            .eq("user_id", value: userId)
            .execute()
        
        print("✅ Ended active session for user \(userId)")
    }
    
    // MARK: - Find Friends You Trained With
    
    /// Model for a friend you potentially trained with
    struct TrainedWithFriend: Identifiable {
        let id: String
        let username: String
        let avatarUrl: String?
        let overlapMinutes: Int
    }
    
    /// Find friends who trained at the same location within the time window
    /// - Parameters:
    ///   - userId: Current user's ID
    ///   - myStartTime: When the user started their session
    ///   - myEndTime: When the user ended their session
    ///   - myLatitude: User's gym location latitude
    ///   - myLongitude: User's gym location longitude
    /// - Returns: Array of friends who trained with the user (within 100m, 10+ min overlap)
    func findFriendsTrainedWith(
        userId: String,
        myStartTime: Date,
        myEndTime: Date,
        myLatitude: Double,
        myLongitude: Double
    ) async throws -> [TrainedWithFriend] {
        print("🏋️ Finding friends who trained with user at (\(myLatitude), \(myLongitude))")
        
        // Get list of users this person follows (mutual friends would be better, but follows works)
        let followingResponse = try await supabase
            .from("follows")
            .select("following_id")
            .eq("follower_id", value: userId)
            .execute()
        
        let followingData = try JSONDecoder().decode([FollowingRecord].self, from: followingResponse.data)
        let followingIds = followingData.map { $0.followingId }
        
        guard !followingIds.isEmpty else {
            print("⚠️ User doesn't follow anyone")
            return []
        }
        
        // Calculate time window: sessions that started up to 3 hours before or after
        let windowStart = myStartTime.addingTimeInterval(-3 * 60 * 60) // 3 hours before
        let windowEnd = myEndTime.addingTimeInterval(3 * 60 * 60) // 3 hours after
        
        let formatter = ISO8601DateFormatter()
        
        // Fetch active/recent sessions from friends within time window
        let sessionsResponse = try await supabase
            .from("active_sessions")
            .select("id, user_id, activity_type, started_at, latitude, longitude, is_active, updated_at")
            .in("user_id", values: followingIds)
            .gte("started_at", value: formatter.string(from: windowStart))
            .execute()
        
        let sessions = try JSONDecoder().decode([ActiveSessionWithUpdate].self, from: sessionsResponse.data)
        print("📋 Found \(sessions.count) friend sessions in time window")
        
        // Filter by gym activity, location (100m), and time overlap (10+ min)
        var matchingUserIds: [(String, Int)] = [] // (userId, overlapMinutes)
        
        for session in sessions {
            // Only gym sessions
            guard session.activityType.lowercased().contains("gym") else { continue }
            
            // Check distance
            guard let friendLat = session.latitude, let friendLon = session.longitude else { continue }
            let distance = calculateDistance(lat1: myLatitude, lon1: myLongitude, lat2: friendLat, lon2: friendLon)
            
            guard distance <= 100 else {
                print("  ❌ Friend \(session.userId) too far: \(Int(distance))m")
                continue
            }
            
            // Check time overlap
            let friendStart = formatter.date(from: session.startedAt) ?? Date()
            let friendEnd: Date
            if session.isActive == true {
                // Friend is still training - use current time or our end time
                friendEnd = max(myEndTime, Date())
            } else if let updated = session.updatedAt {
                friendEnd = formatter.date(from: updated) ?? myEndTime
            } else {
                friendEnd = myEndTime
            }
            
            let overlapMinutes = calculateOverlapMinutes(
                start1: myStartTime, end1: myEndTime,
                start2: friendStart, end2: friendEnd
            )
            
            guard overlapMinutes >= 10 else {
                print("  ❌ Friend \(session.userId) not enough overlap: \(overlapMinutes) min")
                continue
            }
            
            print("  ✅ Friend \(session.userId) matched: \(Int(distance))m away, \(overlapMinutes) min overlap")
            matchingUserIds.append((session.userId, overlapMinutes))
        }
        
        guard !matchingUserIds.isEmpty else {
            print("⚠️ No friends matched criteria")
            return []
        }
        
        // Fetch profile info for matching users
        let profilesResponse = try await supabase
            .from("profiles")
            .select("id, username, avatar_url")
            .in("id", values: matchingUserIds.map { $0.0 })
            .execute()
        
        let profiles = try JSONDecoder().decode([ActiveSessionProfileInfo].self, from: profilesResponse.data)
        let profileMap: [String: ActiveSessionProfileInfo] = Dictionary(uniqueKeysWithValues: profiles.map { ($0.id, $0) })
        
        return matchingUserIds.compactMap { (userId, overlap) -> TrainedWithFriend? in
            guard let profile = profileMap[userId] else { return nil }
            return TrainedWithFriend(
                id: userId,
                username: profile.username ?? "Användare",
                avatarUrl: profile.avatarUrl,
                overlapMinutes: overlap
            )
        }.sorted { $0.overlapMinutes > $1.overlapMinutes } // Most overlap first
    }
    
    /// Calculate distance between two coordinates in meters (Haversine formula)
    private func calculateDistance(lat1: Double, lon1: Double, lat2: Double, lon2: Double) -> Double {
        let earthRadius = 6371000.0 // meters
        
        let dLat = (lat2 - lat1) * .pi / 180
        let dLon = (lon2 - lon1) * .pi / 180
        
        let a = sin(dLat/2) * sin(dLat/2) +
                cos(lat1 * .pi / 180) * cos(lat2 * .pi / 180) *
                sin(dLon/2) * sin(dLon/2)
        let c = 2 * atan2(sqrt(a), sqrt(1-a))
        
        return earthRadius * c
    }
    
    /// Calculate overlap in minutes between two time ranges
    private func calculateOverlapMinutes(start1: Date, end1: Date, start2: Date, end2: Date) -> Int {
        let overlapStart = max(start1, start2)
        let overlapEnd = min(end1, end2)
        
        let overlapSeconds = overlapEnd.timeIntervalSince(overlapStart)
        return max(0, Int(overlapSeconds / 60))
    }
    
    // MARK: - Fetch Active Friends
    
    /// Fetch active sessions from friends
    func fetchActiveFriends(userId: String) async throws -> [ActiveFriendSession] {
        print("🔍 [ActiveFriends] Fetching active friends for user: \(userId)")
        
        // First get the list of users this person follows
        let followingResponse = try await supabase
            .from("follows")
            .select("following_id")
            .eq("follower_id", value: userId)
            .execute()
        
        let followingData = try JSONDecoder().decode([FollowingRecord].self, from: followingResponse.data)
        let followingIds = followingData.map { $0.followingId }
        
        print("📋 [ActiveFriends] User \(userId) follows \(followingIds.count) people")
        if !followingIds.isEmpty {
            print("📋 [ActiveFriends] Following IDs: \(followingIds.prefix(5).joined(separator: ", "))\(followingIds.count > 5 ? "..." : "")")
        }
        
        guard !followingIds.isEmpty else {
            print("⚠️ [ActiveFriends] User doesn't follow anyone - showing empty")
            return []
        }
        
        // Then fetch active sessions for those users
        print("🔍 [ActiveFriends] Checking for active sessions from \(followingIds.count) followed users...")
        
        let sessionsResponse = try await supabase
            .from("active_sessions")
            .select("id, user_id, activity_type, started_at, latitude, longitude, is_active")
            .in("user_id", values: followingIds)
            .eq("is_active", value: true)
            .execute()
        
        let rawJson = String(data: sessionsResponse.data, encoding: .utf8) ?? "nil"
        print("📄 [ActiveFriends] Raw sessions response: \(rawJson)")
        
        let sessions = try JSONDecoder().decode([ActiveSessionBasic].self, from: sessionsResponse.data)
        print("✅ [ActiveFriends] Found \(sessions.count) active sessions from friends")
        
        for session in sessions {
            print("  👤 Session: user=\(session.userId), type=\(session.activityType), started=\(session.startedAt)")
        }
        
        // Now fetch the profile info for each user
        let userIds = sessions.map { $0.userId }
        guard !userIds.isEmpty else { return [] }
        
        let profilesResponse = try await supabase
            .from("profiles")
            .select("id, username, avatar_url")
            .in("id", values: userIds)
            .execute()
        
        let profiles = try JSONDecoder().decode([ActiveSessionProfileInfo].self, from: profilesResponse.data)
        let profileMap: [String: ActiveSessionProfileInfo] = Dictionary(uniqueKeysWithValues: profiles.map { ($0.id, $0) })
        
        return sessions.compactMap { session -> ActiveFriendSession? in
            guard let profile = profileMap[session.userId] else { return nil }
            return ActiveFriendSession(
                id: session.id,
                oderId: session.userId,
                userName: profile.username ?? "Användare",
                avatarUrl: profile.avatarUrl,
                activityType: session.activityType,
                startedAt: ISO8601DateFormatter().date(from: session.startedAt) ?? Date(),
                latitude: session.latitude,
                longitude: session.longitude
            )
        }
    }
}

// MARK: - Helper Models

private struct ActiveSessionInsert: Encodable {
    let userId: String
    let activityType: String
    let startedAt: String
    let latitude: Double?
    let longitude: Double?
    let isActive: Bool
    
    enum CodingKeys: String, CodingKey {
        case userId = "user_id"
        case activityType = "activity_type"
        case startedAt = "started_at"
        case latitude
        case longitude
        case isActive = "is_active"
    }
}

private struct FollowingRecord: Codable {
    let followingId: String
    
    enum CodingKeys: String, CodingKey {
        case followingId = "following_id"
    }
}

private struct ActiveSessionBasic: Codable {
    let id: String
    let userId: String
    let activityType: String
    let startedAt: String
    let latitude: Double?
    let longitude: Double?
    let isActive: Bool?
    
    enum CodingKeys: String, CodingKey {
        case id
        case userId = "user_id"
        case activityType = "activity_type"
        case startedAt = "started_at"
        case latitude
        case longitude
        case isActive = "is_active"
    }
}

private struct ActiveSessionWithUpdate: Codable {
    let id: String
    let userId: String
    let activityType: String
    let startedAt: String
    let updatedAt: String?
    let latitude: Double?
    let longitude: Double?
    let isActive: Bool?
    
    enum CodingKeys: String, CodingKey {
        case id
        case userId = "user_id"
        case activityType = "activity_type"
        case startedAt = "started_at"
        case updatedAt = "updated_at"
        case latitude
        case longitude
        case isActive = "is_active"
    }
}

private struct ActiveSessionProfileInfo: Codable {
    let id: String
    let username: String?
    let avatarUrl: String?
    
    enum CodingKeys: String, CodingKey {
        case id
        case username
        case avatarUrl = "avatar_url"
    }
}
