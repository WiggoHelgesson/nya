import Foundation
import Supabase
import PostgREST

final class SharedWorkoutService {
    static let shared = SharedWorkoutService()
    private let supabase = SupabaseConfig.supabase
    
    private let isoFormatter: ISO8601DateFormatter = {
        let formatter = ISO8601DateFormatter()
        formatter.formatOptions = [.withInternetDateTime, .withFractionalSeconds]
        return formatter
    }()
    
    private let isoFormatterNoMs: ISO8601DateFormatter = {
        let formatter = ISO8601DateFormatter()
        formatter.formatOptions = [.withInternetDateTime]
        return formatter
    }()
    
    private init() {}
    
    // MARK: - Share a workout with a friend
    func shareWorkout(
        senderId: String,
        senderName: String,
        receiverId: String,
        workoutName: String,
        exercises: [GymExercisePost],
        message: String? = nil
    ) async throws {
        try await AuthSessionManager.shared.ensureValidSession()
        
        struct InsertPayload: Encodable {
            let id: String
            let senderId: String
            let receiverId: String
            let workoutName: String
            let exercises: [GymExercisePost]
            let message: String?
            
            enum CodingKeys: String, CodingKey {
                case id
                case senderId = "sender_id"
                case receiverId = "receiver_id"
                case workoutName = "workout_name"
                case exercises = "exercises_data"
                case message
            }
        }
        
        let id = UUID().uuidString
        let payload = InsertPayload(
            id: id,
            senderId: senderId,
            receiverId: receiverId,
            workoutName: workoutName,
            exercises: exercises,
            message: message
        )
        
        do {
            _ = try await supabase
                .from("shared_workouts")
                .insert(payload)
                .execute()
            print("✅ Workout shared successfully")
            
            // Send push notification to the receiver
            await PushNotificationService.shared.notifyUserAboutSharedWorkout(
                receiverId: receiverId,
                senderName: senderName,
                workoutName: workoutName
            )
        } catch let error as PostgrestError where error.code == "42P01" {
            print("ℹ️ shared_workouts table is missing. Create it before sharing workouts.")
            throw error
        }
    }
    
    // MARK: - Fetch workouts shared with the user ("Delas med mig")
    func fetchReceivedWorkouts(for userId: String) async throws -> [SharedWorkout] {
        try await AuthSessionManager.shared.ensureValidSession()
        
        struct SharedWorkoutRecord: Decodable {
            let id: String
            let senderId: String
            let receiverId: String
            let workoutName: String
            let exercises: [GymExercisePost]?
            let message: String?
            let createdAt: String
            let isRead: Bool
            
            enum CodingKeys: String, CodingKey {
                case id
                case senderId = "sender_id"
                case receiverId = "receiver_id"
                case workoutName = "workout_name"
                case exercises = "exercises_data"
                case message
                case createdAt = "created_at"
                case isRead = "is_read"
            }
        }
        
        do {
            let records: [SharedWorkoutRecord] = try await supabase
                .from("shared_workouts")
                .select("*")
                .eq("receiver_id", value: userId)
                .order("created_at", ascending: false)
                .execute()
                .value
            
            // Fetch sender profiles
            let senderIds = Array(Set(records.map { $0.senderId }))
            var senderProfiles: [String: (username: String, avatarUrl: String?)] = [:]
            
            if !senderIds.isEmpty {
                struct ProfileRecord: Decodable {
                    let id: String
                    let username: String?
                    let avatarUrl: String?
                    
                    enum CodingKeys: String, CodingKey {
                        case id
                        case username
                        case avatarUrl = "avatar_url"
                    }
                }
                
                let profiles: [ProfileRecord] = try await supabase
                    .from("profiles")
                    .select("id, username, avatar_url")
                    .in("id", values: senderIds)
                    .execute()
                    .value
                
                for profile in profiles {
                    senderProfiles[profile.id] = (profile.username ?? "Okänd", profile.avatarUrl)
                }
            }
            
            return records.compactMap { record in
                guard let exercises = record.exercises else { return nil }
                let date = isoFormatter.date(from: record.createdAt) ?? isoFormatterNoMs.date(from: record.createdAt) ?? Date()
                let senderInfo = senderProfiles[record.senderId]
                
                return SharedWorkout(
                    id: record.id,
                    senderId: record.senderId,
                    receiverId: record.receiverId,
                    workoutName: record.workoutName,
                    exercises: exercises,
                    message: record.message,
                    createdAt: date,
                    isRead: record.isRead,
                    senderUsername: senderInfo?.username,
                    senderAvatarUrl: senderInfo?.avatarUrl
                )
            }
        } catch let error as PostgrestError where error.code == "42P01" {
            print("ℹ️ shared_workouts table is missing.")
            return []
        }
    }
    
    // MARK: - Fetch workouts the user has shared ("Mina delade")
    func fetchSentWorkouts(for userId: String) async throws -> [SharedWorkout] {
        try await AuthSessionManager.shared.ensureValidSession()
        
        struct SharedWorkoutRecord: Decodable {
            let id: String
            let senderId: String
            let receiverId: String
            let workoutName: String
            let exercises: [GymExercisePost]?
            let message: String?
            let createdAt: String
            let isRead: Bool
            
            enum CodingKeys: String, CodingKey {
                case id
                case senderId = "sender_id"
                case receiverId = "receiver_id"
                case workoutName = "workout_name"
                case exercises = "exercises_data"
                case message
                case createdAt = "created_at"
                case isRead = "is_read"
            }
        }
        
        do {
            let records: [SharedWorkoutRecord] = try await supabase
                .from("shared_workouts")
                .select("*")
                .eq("sender_id", value: userId)
                .order("created_at", ascending: false)
                .execute()
                .value
            
            // Fetch receiver profiles
            let receiverIds = Array(Set(records.map { $0.receiverId }))
            var receiverProfiles: [String: (username: String, avatarUrl: String?)] = [:]
            
            if !receiverIds.isEmpty {
                struct ProfileRecord: Decodable {
                    let id: String
                    let username: String?
                    let avatarUrl: String?
                    
                    enum CodingKeys: String, CodingKey {
                        case id
                        case username
                        case avatarUrl = "avatar_url"
                    }
                }
                
                let profiles: [ProfileRecord] = try await supabase
                    .from("profiles")
                    .select("id, username, avatar_url")
                    .in("id", values: receiverIds)
                    .execute()
                    .value
                
                for profile in profiles {
                    receiverProfiles[profile.id] = (profile.username ?? "Okänd", profile.avatarUrl)
                }
            }
            
            return records.compactMap { record in
                guard let exercises = record.exercises else { return nil }
                let date = isoFormatter.date(from: record.createdAt) ?? isoFormatterNoMs.date(from: record.createdAt) ?? Date()
                
                return SharedWorkout(
                    id: record.id,
                    senderId: record.senderId,
                    receiverId: record.receiverId,
                    workoutName: record.workoutName,
                    exercises: exercises,
                    message: record.message,
                    createdAt: date,
                    isRead: record.isRead
                )
            }
        } catch let error as PostgrestError where error.code == "42P01" {
            print("ℹ️ shared_workouts table is missing.")
            return []
        }
    }
    
    // MARK: - Mark a shared workout as read
    func markAsRead(workoutId: String) async throws {
        try await AuthSessionManager.shared.ensureValidSession()
        
        do {
            _ = try await supabase
                .from("shared_workouts")
                .update(["is_read": true])
                .eq("id", value: workoutId)
                .execute()
        } catch let error as PostgrestError where error.code == "42P01" {
            print("ℹ️ shared_workouts table is missing.")
        }
    }
    
    // MARK: - Delete a shared workout
    func deleteSharedWorkout(workoutId: String, userId: String) async throws {
        try await AuthSessionManager.shared.ensureValidSession()
        
        do {
            _ = try await supabase
                .from("shared_workouts")
                .delete()
                .eq("id", value: workoutId)
                .or("sender_id.eq.\(userId),receiver_id.eq.\(userId)")
                .execute()
        } catch let error as PostgrestError where error.code == "42P01" {
            print("ℹ️ shared_workouts table is missing.")
        }
    }
    
    // MARK: - Get unread count
    func getUnreadCount(for userId: String) async throws -> Int {
        try await AuthSessionManager.shared.ensureValidSession()
        
        do {
            let records: [SharedWorkoutMinimal] = try await supabase
                .from("shared_workouts")
                .select("id")
                .eq("receiver_id", value: userId)
                .eq("is_read", value: false)
                .execute()
                .value
            return records.count
        } catch {
            return 0
        }
    }
    
    // MARK: - Fetch friends for sharing
    func fetchFriendsForSharing(userId: String) async throws -> [FriendForSharing] {
        let followingUsers = try await SocialService.shared.getFollowingUsers(userId: userId)
        return followingUsers.map { user in
            FriendForSharing(
                id: user.id,
                username: user.name,
                avatarUrl: user.avatarUrl
            )
        }
    }
}

// Helper struct for counting
private struct SharedWorkoutMinimal: Decodable {
    let id: String
}
