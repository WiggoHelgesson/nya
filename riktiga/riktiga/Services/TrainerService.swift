import Foundation
import Supabase

final class TrainerService {
    static let shared = TrainerService()
    private let supabase = SupabaseConfig.supabase
    
    private init() {}
    
    // MARK: - Fetch Trainers
    
    func fetchTrainers() async throws -> [GolfTrainer] {
        print("🏌️ Fetching golf trainers...")
        
        do {
            try await AuthSessionManager.shared.ensureValidSession()
            
            let result: [GolfTrainer] = try await supabase.database
                .from("trainer_profiles")
                .select()
                .eq("is_active", value: true)
                .order("created_at", ascending: false)
                .execute()
                .value
            
            print("✅ Fetched \(result.count) trainers")
            return result
        } catch {
            print("❌ Failed to fetch trainers: \(error)")
            throw error
        }
    }

    // MARK: - Fetch Pending Trainers (for admin)
    func fetchPendingTrainers() async throws -> [GolfTrainer] {
        print("📥 Fetching pending trainer profiles...")
        
        do {
            try await AuthSessionManager.shared.ensureValidSession()
            
            let result: [GolfTrainer] = try await supabase.database
                .from("trainer_profiles")
                .select()
                .eq("is_active", value: false)
                .order("created_at", ascending: false)
                .execute()
                .value
            
            print("✅ Fetched \(result.count) pending trainers")
            return result
        } catch {
            print("❌ Failed to fetch pending trainers: \(error)")
            throw error
        }
    }
    
    // MARK: - Create Trainer Profile
    
    func createTrainerProfile(
        name: String,
        description: String,
        hourlyRate: Int,
        handicap: Int,
        latitude: Double,
        longitude: Double,
        serviceRadiusKm: Double = 10.0,
        isActive: Bool = false
    ) async throws -> GolfTrainer {
        print("🏌️ Creating trainer profile...")
        
        guard let userId = try? await supabase.auth.session.user.id else {
            throw TrainerServiceError.notAuthenticated
        }
        
        try await AuthSessionManager.shared.ensureValidSession()
        
        // Check if user already has a trainer profile
        let existing: [GolfTrainer] = try await supabase.database
            .from("trainer_profiles")
            .select()
            .eq("user_id", value: userId)
            .execute()
            .value
        
        // Get user's avatar URL
        let profile = try? await supabase.database
            .from("profiles")
            .select("avatar_url")
            .eq("id", value: userId)
            .single()
            .execute()
            .value as [String: String]?
        
        let avatarUrl = profile?["avatar_url"]
        
        if let existingTrainer = existing.first {
            // Update existing profile instead of creating new
            print("📝 Updating existing trainer profile: \(existingTrainer.id)")
            
            let updateParams: [String: DynamicEncodable] = [
                "name": DynamicEncodable(name),
                "description": DynamicEncodable(description),
                "hourly_rate": DynamicEncodable(hourlyRate),
                "handicap": DynamicEncodable(handicap),
                "latitude": DynamicEncodable(latitude),
                "longitude": DynamicEncodable(longitude),
                "avatar_url": DynamicEncodable(avatarUrl),
                "is_active": DynamicEncodable(isActive),
                "service_radius_km": DynamicEncodable(serviceRadiusKm)
            ]
            
            let result: GolfTrainer = try await supabase.database
                .from("trainer_profiles")
                .update(updateParams)
                .eq("id", value: existingTrainer.id)
                .select()
                .single()
                .execute()
                .value
            
            print("✅ Updated trainer profile: \(result.id)")
            return result
        }
        
        // Create new profile
        let params: [String: DynamicEncodable] = [
            "user_id": DynamicEncodable(userId.uuidString),
            "name": DynamicEncodable(name),
            "description": DynamicEncodable(description),
            "hourly_rate": DynamicEncodable(hourlyRate),
            "handicap": DynamicEncodable(handicap),
            "latitude": DynamicEncodable(latitude),
            "longitude": DynamicEncodable(longitude),
            "avatar_url": DynamicEncodable(avatarUrl),
            "is_active": DynamicEncodable(isActive),
            "service_radius_km": DynamicEncodable(serviceRadiusKm)
        ]
        
        let result: GolfTrainer = try await supabase.database
            .from("trainer_profiles")
            .insert(params)
            .select()
            .single()
            .execute()
            .value
        
        print("✅ Created trainer profile: \(result.id)")
        return result
    }
    
    // MARK: - Update Trainer Profile
    
    func updateTrainerProfile(
        trainerId: UUID,
        name: String? = nil,
        description: String? = nil,
        hourlyRate: Int? = nil,
        handicap: Int? = nil,
        latitude: Double? = nil,
        longitude: Double? = nil,
        isActive: Bool? = nil
    ) async throws {
        print("🏌️ Updating trainer profile...")
        
        try await AuthSessionManager.shared.ensureValidSession()
        
        var params: [String: DynamicEncodable] = [:]
        
        if let name = name { params["name"] = DynamicEncodable(name) }
        if let description = description { params["description"] = DynamicEncodable(description) }
        if let hourlyRate = hourlyRate { params["hourly_rate"] = DynamicEncodable(hourlyRate) }
        if let handicap = handicap { params["handicap"] = DynamicEncodable(handicap) }
        if let latitude = latitude { params["latitude"] = DynamicEncodable(latitude) }
        if let longitude = longitude { params["longitude"] = DynamicEncodable(longitude) }
        if let isActive = isActive { params["is_active"] = DynamicEncodable(isActive) }
        
        try await supabase.database
            .from("trainer_profiles")
            .update(params)
            .eq("id", value: trainerId)
            .execute()
        
        print("✅ Updated trainer profile")
    }
    
    // MARK: - Approve / Reject Trainer (admin)
    func approveTrainer(trainerId: UUID) async throws {
        try await updateTrainerProfile(trainerId: trainerId, isActive: true)
    }
    
    func rejectTrainer(trainerId: UUID) async throws {
        try await updateTrainerProfile(trainerId: trainerId, isActive: false)
    }

    // MARK: - Check if User is Trainer
    
    func isUserTrainer() async throws -> Bool {
        guard let userId = try? await supabase.auth.session.user.id else {
            return false
        }
        
        try await AuthSessionManager.shared.ensureValidSession()
        
        // Only return true if trainer profile exists AND is active
        let result: [GolfTrainer] = try await supabase.database
            .from("trainer_profiles")
            .select()
            .eq("user_id", value: userId)
            .eq("is_active", value: true)
            .execute()
            .value
        
        return !result.isEmpty
    }
    
    // MARK: - Get User's Trainer Profile
    
    func getUserTrainerProfile() async throws -> GolfTrainer? {
        guard let userId = try? await supabase.auth.session.user.id else {
            return nil
        }
        
        try await AuthSessionManager.shared.ensureValidSession()
        
        let result: [GolfTrainer] = try await supabase.database
            .from("trainer_profiles")
            .select()
            .eq("user_id", value: userId)
            .execute()
            .value
        
        return result.first
    }
    
    // MARK: - Booking Functions
    
    func createBooking(trainerId: UUID, message: String) async throws -> UUID {
        print("📅 Creating booking request...")
        
        try await AuthSessionManager.shared.ensureValidSession()
        
        guard let userId = try? await supabase.auth.session.user.id else {
            throw TrainerServiceError.notAuthenticated
        }
        
        // Insert directly into trainer_bookings table
        let bookingData: [String: String] = [
            "trainer_id": trainerId.uuidString,
            "student_id": userId.uuidString,
            "message": message
        ]
        
        let booking: TrainerBooking = try await supabase.database
            .from("trainer_bookings")
            .insert(bookingData)
            .select()
            .single()
            .execute()
            .value
        
        // Also insert first message
        let messageData: [String: String] = [
            "booking_id": booking.id.uuidString,
            "sender_id": userId.uuidString,
            "message": message
        ]
        
        try await supabase.database
            .from("booking_messages")
            .insert(messageData)
            .execute()
        
        print("✅ Booking created: \(booking.id)")
        
        // Send push notification to trainer
        await sendBookingNotificationToTrainer(trainerId: trainerId, studentUserId: userId)
        
        return booking.id
    }
    
    /// Send push notification to trainer when a new booking is created
    private func sendBookingNotificationToTrainer(trainerId: UUID, studentUserId: UUID) async {
        do {
            // Get trainer's user_id
            struct TrainerUser: Decodable {
                let user_id: String
            }
            
            let trainerInfo: [TrainerUser] = try await supabase.database
                .from("trainer_profiles")
                .select("user_id")
                .eq("id", value: trainerId.uuidString)
                .execute()
                .value
            
            guard let trainerUserId = trainerInfo.first?.user_id else {
                print("⚠️ Could not find trainer user_id")
                return
            }
            
            // Get student's username
            struct UserProfile: Decodable {
                let username: String
            }
            
            let studentProfile: [UserProfile] = try await supabase.database
                .from("profiles")
                .select("username")
                .eq("id", value: studentUserId.uuidString)
                .execute()
                .value
            
            let studentName = studentProfile.first?.username ?? "Någon"
            
            // Send push notification
            await PushNotificationService.shared.sendRealPushNotification(
                toUserId: trainerUserId,
                title: "Ny bokning",
                body: "\(studentName) bokade ett pass med dig",
                data: ["type": "booking", "trainer_id": trainerId.uuidString]
            )
            
            print("✅ Booking notification sent to trainer")
        } catch {
            print("⚠️ Could not send booking notification: \(error)")
        }
    }
    
    func getBookingsForTrainer() async throws -> [TrainerBooking] {
        print("📅 Fetching bookings for trainer...")
        
        guard let trainerProfile = try await getUserTrainerProfile() else {
            return []
        }
        
        try await AuthSessionManager.shared.ensureValidSession()
        
        let result: [TrainerBooking] = try await supabase.database
            .from("trainer_bookings_with_users")
            .select()
            .eq("trainer_id", value: trainerProfile.id)
            .order("created_at", ascending: false)
            .execute()
            .value
        
        print("✅ Fetched \(result.count) bookings")
        return result
    }
    
    func getBookingsForStudent() async throws -> [TrainerBooking] {
        print("📅 Fetching bookings for student...")
        
        guard let userId = try? await supabase.auth.session.user.id else {
            return []
        }
        
        try await AuthSessionManager.shared.ensureValidSession()
        
        let result: [TrainerBooking] = try await supabase.database
            .from("trainer_bookings_with_users")
            .select()
            .eq("student_id", value: userId)
            .order("created_at", ascending: false)
            .execute()
            .value
        
        print("✅ Fetched \(result.count) bookings")
        return result
    }
    
    func updateBookingStatus(bookingId: UUID, status: BookingStatus, response: String? = nil) async throws {
        print("📅 Updating booking status to \(status.rawValue)...")
        
        try await AuthSessionManager.shared.ensureValidSession()
        
        var params: [String: DynamicEncodable] = [
            "status": DynamicEncodable(status.rawValue)
        ]
        
        if let response = response {
            params["trainer_response"] = DynamicEncodable(response)
        }
        
        try await supabase.database
            .from("trainer_bookings")
            .update(params)
            .eq("id", value: bookingId)
            .execute()
        
        print("✅ Booking status updated")
    }
    
    func getPendingBookingsCount() async throws -> Int {
        guard let trainerProfile = try await getUserTrainerProfile() else {
            return 0
        }
        
        try await AuthSessionManager.shared.ensureValidSession()
        
        let result: [TrainerBooking] = try await supabase.database
            .from("trainer_bookings")
            .select()
            .eq("trainer_id", value: trainerProfile.id)
            .eq("status", value: "pending")
            .execute()
            .value
        
        return result.count
    }
    
    // MARK: - Chat Functions
    
    func getMessagesForBooking(bookingId: UUID) async throws -> [BookingMessage] {
        print("💬 Fetching messages for booking \(bookingId)...")
        
        try await AuthSessionManager.shared.ensureValidSession()
        
        let result: [BookingMessage] = try await supabase.database
            .from("booking_messages_with_users")
            .select()
            .eq("booking_id", value: bookingId)
            .order("created_at", ascending: true)
            .execute()
            .value
        
        print("✅ Fetched \(result.count) messages")
        return result
    }
    
    func sendMessage(bookingId: UUID, message: String) async throws -> UUID {
        print("💬 Sending message...")
        
        try await AuthSessionManager.shared.ensureValidSession()
        
        guard let userId = try? await supabase.auth.session.user.id else {
            throw TrainerServiceError.notAuthenticated
        }
        
        // Insert directly into booking_messages table
        let insertData: [String: String] = [
            "booking_id": bookingId.uuidString,
            "sender_id": userId.uuidString,
            "message": message
        ]
        
        let result: BookingMessage = try await supabase.database
            .from("booking_messages")
            .insert(insertData)
            .select()
            .single()
            .execute()
            .value
        
        print("✅ Message sent: \(result.id)")
        return result.id
    }
    
    func markMessagesAsRead(bookingId: UUID) async throws {
        guard let userId = try? await supabase.auth.session.user.id else {
            return
        }
        
        try await AuthSessionManager.shared.ensureValidSession()
        
        try await supabase.database
            .from("booking_messages")
            .update(["is_read": true])
            .eq("booking_id", value: bookingId)
            .neq("sender_id", value: userId)
            .execute()
        
        print("✅ Messages marked as read")
    }
}

enum TrainerServiceError: Error, LocalizedError {
    case notAuthenticated
    case profileAlreadyExists
    
    var errorDescription: String? {
        switch self {
        case .notAuthenticated:
            return "Du måste vara inloggad för att bli tränare"
        case .profileAlreadyExists:
            return "Du har redan en tränarprofil"
        }
    }
}

enum BookingStatus: String, Codable {
    case pending = "pending"
    case accepted = "accepted"
    case declined = "declined"
    case cancelled = "cancelled"
    
    var displayName: String {
        switch self {
        case .pending: return "Väntar"
        case .accepted: return "Godkänd"
        case .declined: return "Nekad"
        case .cancelled: return "Avbokad"
        }
    }
    
    var color: String {
        switch self {
        case .pending: return "orange"
        case .accepted: return "green"
        case .declined: return "red"
        case .cancelled: return "gray"
        }
    }
}

struct TrainerBooking: Identifiable, Codable {
    let id: UUID
    let trainerId: UUID
    let studentId: UUID
    let message: String
    let status: String
    let trainerResponse: String?
    let createdAt: Date?
    let updatedAt: Date?
    
    // Extended booking fields
    let lessonTypeId: UUID?
    let scheduledDate: String?
    let scheduledTime: String?
    let durationMinutes: Int?
    let price: Int?
    let locationType: String?
    let golfCourseId: UUID?
    let customLocationName: String?
    let customLocationLat: Double?
    let customLocationLng: Double?
    let paymentStatus: String?
    let stripePaymentId: String?
    
    // From view - Trainer info
    let trainerUserID: UUID?
    let trainerName: String?
    let trainerAvatarUrl: String?
    let hourlyRate: Int?
    let trainerCity: String?
    
    // From view - Student info
    let studentUsername: String?
    let studentAvatarUrl: String?
    let unreadCount: Int?
    
    var bookingStatus: BookingStatus {
        BookingStatus(rawValue: status) ?? .pending
    }
    
    var formattedDate: String? {
        guard let dateStr = scheduledDate else { return nil }
        let inputFormatter = DateFormatter()
        inputFormatter.dateFormat = "yyyy-MM-dd"
        guard let date = inputFormatter.date(from: dateStr) else { return nil }
        let outputFormatter = DateFormatter()
        outputFormatter.locale = Locale(identifier: "sv_SE")
        outputFormatter.dateFormat = "d MMMM yyyy"
        return outputFormatter.string(from: date)
    }
    
    var formattedTime: String? {
        guard let timeStr = scheduledTime else { return nil }
        // Time comes as HH:mm:ss, we want HH:mm
        let components = timeStr.split(separator: ":")
        if components.count >= 2 {
            return "\(components[0]):\(components[1])"
        }
        return timeStr
    }
    
    enum CodingKeys: String, CodingKey {
        case id
        case trainerId = "trainer_id"
        case studentId = "student_id"
        case message
        case status
        case trainerResponse = "trainer_response"
        case createdAt = "created_at"
        case updatedAt = "updated_at"
        case lessonTypeId = "lesson_type_id"
        case scheduledDate = "scheduled_date"
        case scheduledTime = "scheduled_time"
        case durationMinutes = "duration_minutes"
        case price
        case locationType = "location_type"
        case golfCourseId = "golf_course_id"
        case customLocationName = "custom_location_name"
        case customLocationLat = "custom_location_lat"
        case customLocationLng = "custom_location_lng"
        case paymentStatus = "payment_status"
        case stripePaymentId = "stripe_payment_id"
        case trainerUserID = "trainer_user_id"
        case trainerName = "trainer_name"
        case trainerAvatarUrl = "trainer_avatar_url"
        case hourlyRate = "hourly_rate"
        case trainerCity = "trainer_city"
        case studentUsername = "student_username"
        case studentAvatarUrl = "student_avatar_url"
        case unreadCount = "unread_count"
    }
}

struct BookingMessage: Identifiable, Codable {
    let id: UUID
    let bookingId: UUID
    let senderId: UUID
    let message: String
    let isRead: Bool
    let createdAt: Date?
    
    // From view
    let senderUsername: String?
    let senderAvatarUrl: String?
    
    enum CodingKeys: String, CodingKey {
        case id
        case bookingId = "booking_id"
        case senderId = "sender_id"
        case message
        case isRead = "is_read"
        case createdAt = "created_at"
        case senderUsername = "sender_username"
        case senderAvatarUrl = "sender_avatar_url"
    }
}

// MARK: - Extended Trainer Service

extension TrainerService {
    
    // MARK: - Fetch Specialties Catalog
    
    func fetchSpecialtiesCatalog() async throws -> [TrainerSpecialty] {
        print("🏌️ Fetching specialties catalog...")
        
        try await AuthSessionManager.shared.ensureValidSession()
        
        let result: [TrainerSpecialty] = try await supabase
            .from("trainer_specialties_catalog")
            .select()
            .execute()
            .value
        
        print("✅ Fetched \(result.count) specialties")
        return result
    }
    
    // MARK: - Fetch Trainer's Specialties
    
    func fetchTrainerSpecialties(trainerId: UUID) async throws -> [TrainerSpecialty] {
        try await AuthSessionManager.shared.ensureValidSession()
        
        struct SpecialtyJoin: Decodable {
            let specialty_id: UUID
            let trainer_specialties_catalog: TrainerSpecialty
        }
        
        let result: [SpecialtyJoin] = try await supabase
            .from("trainer_specialties")
            .select("specialty_id, trainer_specialties_catalog(*)")
            .eq("trainer_id", value: trainerId)
            .execute()
            .value
        
        return result.map { $0.trainer_specialties_catalog }
    }
    
    // MARK: - Save Trainer Specialties
    
    func saveTrainerSpecialties(trainerId: UUID, specialtyIds: [UUID]) async throws {
        try await AuthSessionManager.shared.ensureValidSession()
        
        // Delete existing
        try await supabase
            .from("trainer_specialties")
            .delete()
            .eq("trainer_id", value: trainerId)
            .execute()
        
        // Insert new
        for specialtyId in specialtyIds {
            let data: [String: String] = [
                "trainer_id": trainerId.uuidString,
                "specialty_id": specialtyId.uuidString
            ]
            try await supabase
                .from("trainer_specialties")
                .insert(data)
                .execute()
        }
        
        print("✅ Saved \(specialtyIds.count) specialties")
    }
    
    // MARK: - Fetch Lesson Types
    
    func fetchLessonTypes(trainerId: UUID) async throws -> [TrainerLessonType] {
        try await AuthSessionManager.shared.ensureValidSession()
        
        let result: [TrainerLessonType] = try await supabase
            .from("trainer_lesson_types")
            .select()
            .eq("trainer_id", value: trainerId)
            .eq("is_active", value: true)
            .order("sort_order", ascending: true)
            .execute()
            .value
        
        return result
    }
    
    // MARK: - Save Lesson Type
    
    func saveLessonType(trainerId: UUID, name: String, description: String?, durationMinutes: Int, price: Int) async throws -> TrainerLessonType {
        try await AuthSessionManager.shared.ensureValidSession()
        
        let data: [String: DynamicEncodable] = [
            "trainer_id": DynamicEncodable(trainerId.uuidString),
            "name": DynamicEncodable(name),
            "description": DynamicEncodable(description ?? ""),
            "duration_minutes": DynamicEncodable(durationMinutes),
            "price": DynamicEncodable(price),
            "is_active": DynamicEncodable(true)
        ]
        
        let result: TrainerLessonType = try await supabase
            .from("trainer_lesson_types")
            .insert(data)
            .select()
            .single()
            .execute()
            .value
        
        return result
    }
    
    // MARK: - Delete Lesson Type
    
    func deleteLessonType(lessonTypeId: UUID) async throws {
        try await AuthSessionManager.shared.ensureValidSession()
        
        try await supabase
            .from("trainer_lesson_types")
            .delete()
            .eq("id", value: lessonTypeId)
            .execute()
    }
    
    // MARK: - Delete All Lesson Types for Trainer
    
    func deleteAllLessonTypes(trainerId: UUID) async throws {
        try await AuthSessionManager.shared.ensureValidSession()
        
        try await supabase
            .from("trainer_lesson_types")
            .delete()
            .eq("trainer_id", value: trainerId)
            .execute()
        
        print("✅ Deleted all lesson types for trainer \(trainerId)")
    }
    
    // MARK: - Fetch Certifications
    
    func fetchCertifications(trainerId: UUID) async throws -> [TrainerCertification] {
        try await AuthSessionManager.shared.ensureValidSession()
        
        let result: [TrainerCertification] = try await supabase
            .from("trainer_certifications")
            .select()
            .eq("trainer_id", value: trainerId)
            .execute()
            .value
        
        return result
    }
    
    // MARK: - Save Certification
    
    func saveCertification(trainerId: UUID, name: String, issuer: String?, yearObtained: Int?) async throws -> TrainerCertification {
        try await AuthSessionManager.shared.ensureValidSession()
        
        var data: [String: DynamicEncodable] = [
            "trainer_id": DynamicEncodable(trainerId.uuidString),
            "name": DynamicEncodable(name)
        ]
        
        if let issuer = issuer {
            data["issuer"] = DynamicEncodable(issuer)
        }
        if let year = yearObtained {
            data["year_obtained"] = DynamicEncodable(year)
        }
        
        let result: TrainerCertification = try await supabase
            .from("trainer_certifications")
            .insert(data)
            .select()
            .single()
            .execute()
            .value
        
        return result
    }
    
    // MARK: - Delete Certification
    
    func deleteCertification(certificationId: UUID) async throws {
        try await AuthSessionManager.shared.ensureValidSession()
        
        try await supabase
            .from("trainer_certifications")
            .delete()
            .eq("id", value: certificationId)
            .execute()
    }
    
    // MARK: - Fetch Reviews
    
    func fetchReviews(trainerId: UUID) async throws -> [TrainerReview] {
        try await AuthSessionManager.shared.ensureValidSession()
        
        let result: [TrainerReview] = try await supabase
            .from("trainer_reviews")
            .select("*, profiles!reviewer_id(username, avatar_url)")
            .eq("trainer_id", value: trainerId)
            .order("created_at", ascending: false)
            .execute()
            .value
        
        return result
    }
    
    // MARK: - Submit Review
    
    func submitReview(trainerId: UUID, bookingId: UUID?, rating: Int, title: String?, comment: String?) async throws {
        guard let userId = try? await supabase.auth.session.user.id else {
            throw TrainerServiceError.notAuthenticated
        }
        
        try await AuthSessionManager.shared.ensureValidSession()
        
        var data: [String: DynamicEncodable] = [
            "trainer_id": DynamicEncodable(trainerId.uuidString),
            "reviewer_id": DynamicEncodable(userId.uuidString),
            "rating": DynamicEncodable(rating),
            "is_verified": DynamicEncodable(bookingId != nil)
        ]
        
        if let bookingId = bookingId {
            data["booking_id"] = DynamicEncodable(bookingId.uuidString)
        }
        if let title = title {
            data["title"] = DynamicEncodable(title)
        }
        if let comment = comment {
            data["comment"] = DynamicEncodable(comment)
        }
        
        try await supabase
            .from("trainer_reviews")
            .insert(data)
            .execute()
        
        print("✅ Review submitted")
    }
    
    // MARK: - Fetch Golf Courses
    
    func fetchGolfCourses(nearLatitude: Double? = nil, nearLongitude: Double? = nil, limit: Int = 20) async throws -> [GolfCourse] {
        try await AuthSessionManager.shared.ensureValidSession()
        
        var query = supabase
            .from("golf_courses")
            .select()
            .limit(limit)
        
        // TODO: Add distance sorting if coordinates provided
        
        let result: [GolfCourse] = try await query
            .execute()
            .value
        
        return result
    }
    
    // MARK: - Search Trainers
    
    func searchTrainers(filter: TrainerSearchFilter) async throws -> [GolfTrainer] {
        print("🔍 Searching trainers with filter...")
        
        try await AuthSessionManager.shared.ensureValidSession()
        
        // Build filter query
        var query = supabase
            .from("trainer_profiles")
            .select()
            .eq("is_active", value: true)
        
        // Apply filters
        if !filter.searchText.isEmpty {
            query = query.or("name.ilike.%\(filter.searchText)%,city.ilike.%\(filter.searchText)%,club_affiliation.ilike.%\(filter.searchText)%")
        }
        
        if let minPrice = filter.minPrice {
            query = query.gte("hourly_rate", value: minPrice)
        }
        
        if let maxPrice = filter.maxPrice {
            query = query.lte("hourly_rate", value: maxPrice)
        }
        
        if let minRating = filter.minRating {
            query = query.gte("average_rating", value: minRating)
        }
        
        if let city = filter.city, !city.isEmpty {
            query = query.ilike("city", pattern: "%\(city)%")
        }
        
        // Fetch all matching trainers
        let allTrainers: [GolfTrainer] = try await query
            .limit(100)
            .execute()
            .value
        
        // Sort in memory based on sortBy
        var sortedTrainers = allTrainers
        switch filter.sortBy {
        case .rating:
            sortedTrainers.sort { ($0.averageRating ?? 0) > ($1.averageRating ?? 0) }
        case .price:
            sortedTrainers.sort { $0.hourlyRate < $1.hourlyRate }
        case .reviews:
            sortedTrainers.sort { ($0.totalReviews ?? 0) > ($1.totalReviews ?? 0) }
        case .nearest:
            // Keep original order for now
            break
        }
        
        print("✅ Found \(sortedTrainers.count) trainers")
        return Array(sortedTrainers.prefix(50))
    }
    
    // MARK: - Fetch Availability
    
    func fetchAvailability(trainerId: UUID) async throws -> [TrainerAvailability] {
        try await AuthSessionManager.shared.ensureValidSession()
        
        let result: [TrainerAvailability] = try await supabase
            .from("trainer_availability")
            .select()
            .eq("trainer_id", value: trainerId)
            .eq("is_active", value: true)
            .order("day_of_week", ascending: true)
            .execute()
            .value
        
        return result
    }
    
    // MARK: - Save Availability
    
    func saveAvailability(trainerId: UUID, dayOfWeek: Int, startTime: String, endTime: String) async throws {
        try await AuthSessionManager.shared.ensureValidSession()
        
        let data: [String: DynamicEncodable] = [
            "trainer_id": DynamicEncodable(trainerId.uuidString),
            "day_of_week": DynamicEncodable(dayOfWeek),
            "start_time": DynamicEncodable(startTime),
            "end_time": DynamicEncodable(endTime),
            "is_active": DynamicEncodable(true)
        ]
        
        try await supabase
            .from("trainer_availability")
            .insert(data)
            .execute()
    }
    
    // MARK: - Delete Availability
    
    func deleteAvailability(availabilityId: UUID) async throws {
        try await AuthSessionManager.shared.ensureValidSession()
        
        try await supabase
            .from("trainer_availability")
            .delete()
            .eq("id", value: availabilityId)
            .execute()
    }
    
    // MARK: - Delete All Availability for Trainer
    
    func deleteAllAvailability(trainerId: UUID) async throws {
        try await AuthSessionManager.shared.ensureValidSession()
        
        try await supabase
            .from("trainer_availability")
            .delete()
            .eq("trainer_id", value: trainerId)
            .execute()
        
        print("✅ Deleted all availability for trainer \(trainerId)")
    }
    
    // MARK: - Create Extended Booking
    
    func createExtendedBooking(
        trainerId: UUID,
        lessonTypeId: UUID,
        scheduledDate: Date,
        scheduledTime: String,
        durationMinutes: Int,
        price: Int,
        locationType: BookingLocationType,
        golfCourseId: UUID? = nil,
        customLocationName: String? = nil,
        customLocationLat: Double? = nil,
        customLocationLng: Double? = nil,
        message: String? = nil,
        stripePaymentId: String? = nil
    ) async throws -> UUID {
        guard let userId = try? await supabase.auth.session.user.id else {
            throw TrainerServiceError.notAuthenticated
        }
        
        try await AuthSessionManager.shared.ensureValidSession()
        
        let dateFormatter = DateFormatter()
        dateFormatter.dateFormat = "yyyy-MM-dd"
        
        // Build default message if not provided
        let bookingMessage = message ?? "Bokningsförfrågan för lektion"
        
        var data: [String: DynamicEncodable] = [
            "trainer_id": DynamicEncodable(trainerId.uuidString),
            "student_id": DynamicEncodable(userId.uuidString),
            "lesson_type_id": DynamicEncodable(lessonTypeId.uuidString),
            "scheduled_date": DynamicEncodable(dateFormatter.string(from: scheduledDate)),
            "scheduled_time": DynamicEncodable(scheduledTime),
            "duration_minutes": DynamicEncodable(durationMinutes),
            "price": DynamicEncodable(price),
            "location_type": DynamicEncodable(locationType.rawValue),
            "status": DynamicEncodable("pending"),
            "payment_status": DynamicEncodable(stripePaymentId != nil ? "paid" : "pending"),
            "message": DynamicEncodable(bookingMessage)
        ]
        
        if let golfCourseId = golfCourseId {
            data["golf_course_id"] = DynamicEncodable(golfCourseId.uuidString)
        }
        if let customLocationName = customLocationName {
            data["custom_location_name"] = DynamicEncodable(customLocationName)
        }
        if let lat = customLocationLat {
            data["custom_location_lat"] = DynamicEncodable(lat)
        }
        if let lng = customLocationLng {
            data["custom_location_lng"] = DynamicEncodable(lng)
        }
        if let stripePaymentId = stripePaymentId {
            data["stripe_payment_id"] = DynamicEncodable(stripePaymentId)
        }
        
        struct BookingResponse: Decodable {
            let id: UUID
        }
        
        let result: BookingResponse = try await supabase
            .from("trainer_bookings")
            .insert(data)
            .select("id")
            .single()
            .execute()
            .value
        
        print("✅ Extended booking created: \(result.id)")
        
        // Send push notification to trainer
        await sendBookingNotificationToTrainer(trainerId: trainerId, studentUserId: userId)
        
        return result.id
    }
    
    // MARK: - Update Trainer Extended Profile
    
    func updateTrainerExtendedProfile(
        trainerId: UUID,
        city: String? = nil,
        bio: String? = nil,
        experienceYears: Int? = nil,
        clubAffiliation: String? = nil
    ) async throws {
        try await AuthSessionManager.shared.ensureValidSession()
        
        var params: [String: DynamicEncodable] = [:]
        
        if let city = city { params["city"] = DynamicEncodable(city) }
        if let bio = bio { params["bio"] = DynamicEncodable(bio) }
        if let experienceYears = experienceYears { params["experience_years"] = DynamicEncodable(experienceYears) }
        if let clubAffiliation = clubAffiliation { params["club_affiliation"] = DynamicEncodable(clubAffiliation) }
        
        guard !params.isEmpty else { return }
        
        try await supabase
            .from("trainer_profiles")
            .update(params)
            .eq("id", value: trainerId)
            .execute()
        
        print("✅ Updated extended profile")
    }
}

