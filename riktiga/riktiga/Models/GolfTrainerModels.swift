import Foundation
import CoreLocation

// MARK: - Specialty

struct TrainerSpecialty: Codable, Identifiable, Hashable {
    let id: UUID
    let name: String
    let description: String?
    let icon: String?
    
    enum CodingKeys: String, CodingKey {
        case id, name, description, icon
    }
}

// MARK: - Certification

struct TrainerCertification: Codable, Identifiable {
    let id: UUID
    let trainerId: UUID
    let name: String
    let issuer: String?
    let yearObtained: Int?
    let certificateUrl: String?
    
    enum CodingKeys: String, CodingKey {
        case id
        case trainerId = "trainer_id"
        case name
        case issuer
        case yearObtained = "year_obtained"
        case certificateUrl = "certificate_url"
    }
}

// MARK: - Lesson Type

struct TrainerLessonType: Codable, Identifiable {
    let id: UUID
    let trainerId: UUID
    let name: String
    let description: String?
    let durationMinutes: Int
    let price: Int // in SEK (kronor)
    let isActive: Bool
    let sortOrder: Int
    
    enum CodingKeys: String, CodingKey {
        case id
        case trainerId = "trainer_id"
        case name
        case description
        case durationMinutes = "duration_minutes"
        case price
        case isActive = "is_active"
        case sortOrder = "sort_order"
    }
    
    var formattedPrice: String {
        return "\(price) kr"
    }
    
    var formattedDuration: String {
        if durationMinutes >= 60 {
            let hours = durationMinutes / 60
            let minutes = durationMinutes % 60
            if minutes > 0 {
                return "\(hours) h \(minutes) min"
            }
            return "\(hours) h"
        }
        return "\(durationMinutes) min"
    }
}

// MARK: - Availability

struct TrainerAvailability: Codable, Identifiable {
    let id: UUID
    let trainerId: UUID
    let dayOfWeek: Int // 0=Sunday, 6=Saturday
    let startTime: String // "HH:mm:ss"
    let endTime: String
    let isActive: Bool
    
    enum CodingKeys: String, CodingKey {
        case id
        case trainerId = "trainer_id"
        case dayOfWeek = "day_of_week"
        case startTime = "start_time"
        case endTime = "end_time"
        case isActive = "is_active"
    }
    
    var dayName: String {
        let days = ["Söndag", "Måndag", "Tisdag", "Onsdag", "Torsdag", "Fredag", "Lördag"]
        return days[dayOfWeek]
    }
}

// MARK: - Time Slot

struct TimeSlot: Identifiable, Hashable {
    let id = UUID()
    let startTime: Date
    let endTime: Date
    
    var formattedTime: String {
        let formatter = DateFormatter()
        formatter.dateFormat = "HH:mm"
        return formatter.string(from: startTime)
    }
}

// MARK: - Review

struct TrainerReview: Codable, Identifiable {
    let id: UUID
    let trainerId: UUID
    let reviewerId: UUID
    let bookingId: UUID?
    let rating: Int
    let title: String?
    let comment: String?
    let trainerResponse: String?
    let isVerified: Bool
    let createdAt: Date?
    
    // Joined data
    var reviewerName: String?
    var reviewerAvatarUrl: String?
    
    enum CodingKeys: String, CodingKey {
        case id
        case trainerId = "trainer_id"
        case reviewerId = "reviewer_id"
        case bookingId = "booking_id"
        case rating
        case title
        case comment
        case trainerResponse = "trainer_response"
        case isVerified = "is_verified"
        case createdAt = "created_at"
        case reviewerName = "reviewer_name"
        case reviewerAvatarUrl = "reviewer_avatar_url"
    }
}

// MARK: - Golf Course

struct GolfCourse: Codable, Identifiable {
    let id: UUID
    let name: String
    let address: String?
    let city: String?
    let latitude: Double?
    let longitude: Double?
    let website: String?
    let phone: String?
    
    var coordinate: CLLocationCoordinate2D? {
        guard let lat = latitude, let lon = longitude else { return nil }
        return CLLocationCoordinate2D(latitude: lat, longitude: lon)
    }
}

// MARK: - Trainer Media

struct TrainerMedia: Codable, Identifiable {
    let id: UUID
    let trainerId: UUID
    let mediaType: String // "image" or "video"
    let url: String
    let thumbnailUrl: String?
    let caption: String?
    let sortOrder: Int
    
    enum CodingKeys: String, CodingKey {
        case id
        case trainerId = "trainer_id"
        case mediaType = "media_type"
        case url
        case thumbnailUrl = "thumbnail_url"
        case caption
        case sortOrder = "sort_order"
    }
    
    var isVideo: Bool {
        mediaType == "video"
    }
}

// MARK: - Extended Trainer Profile

struct ExtendedTrainerProfile: Codable, Identifiable {
    let id: UUID
    let userId: UUID
    let name: String
    let description: String?
    let hourlyRate: Int
    let handicap: Int?
    let latitude: Double
    let longitude: Double
    let avatarUrl: String?
    let isActive: Bool
    let city: String?
    let bio: String?
    let experienceYears: Int?
    let clubAffiliation: String?
    let averageRating: Double?
    let totalReviews: Int?
    let totalLessons: Int?
    let responseTimeHours: Int?
    let createdAt: Date?
    
    // Related data (loaded separately)
    var specialties: [TrainerSpecialty]?
    var certifications: [TrainerCertification]?
    var lessonTypes: [TrainerLessonType]?
    var reviews: [TrainerReview]?
    var media: [TrainerMedia]?
    
    enum CodingKeys: String, CodingKey {
        case id
        case userId = "user_id"
        case name
        case description
        case hourlyRate = "hourly_rate"
        case handicap
        case latitude
        case longitude
        case avatarUrl = "avatar_url"
        case isActive = "is_active"
        case city
        case bio
        case experienceYears = "experience_years"
        case clubAffiliation = "club_affiliation"
        case averageRating = "average_rating"
        case totalReviews = "total_reviews"
        case totalLessons = "total_lessons"
        case responseTimeHours = "response_time_hours"
        case createdAt = "created_at"
    }
    
    var coordinate: CLLocationCoordinate2D {
        CLLocationCoordinate2D(latitude: latitude, longitude: longitude)
    }
    
    var formattedRating: String {
        guard let rating = averageRating, rating > 0 else { return "Ny" }
        return String(format: "%.1f", rating)
    }
    
    var formattedHourlyRate: String {
        return "\(hourlyRate) kr/h"
    }
}

// MARK: - Booking Location Type

enum BookingLocationType: String, Codable, CaseIterable {
    case course = "course"
    case custom = "custom"
    case trainerLocation = "trainer_location"
    
    var displayName: String {
        switch self {
        case .course: return "Golfbana"
        case .custom: return "Egen plats"
        case .trainerLocation: return "Tränarens plats"
        }
    }
}

// MARK: - Extended Booking

struct ExtendedBooking: Codable, Identifiable {
    let id: UUID
    let trainerId: UUID
    let studentId: UUID
    let lessonTypeId: UUID?
    let scheduledDate: Date?
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
    let bookingStatus: String
    let message: String?
    let createdAt: Date?
    
    // Joined data
    var trainerName: String?
    var trainerAvatarUrl: String?
    var studentName: String?
    var studentAvatarUrl: String?
    var lessonTypeName: String?
    var golfCourseName: String?
    
    enum CodingKeys: String, CodingKey {
        case id
        case trainerId = "trainer_id"
        case studentId = "student_id"
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
        case bookingStatus = "booking_status"
        case message
        case createdAt = "created_at"
        case trainerName = "trainer_name"
        case trainerAvatarUrl = "trainer_avatar_url"
        case studentName = "student_name"
        case studentAvatarUrl = "student_avatar_url"
        case lessonTypeName = "lesson_type_name"
        case golfCourseName = "golf_course_name"
    }
}

// MARK: - Search Filter

struct TrainerSearchFilter {
    var searchText: String = ""
    var minPrice: Int?
    var maxPrice: Int?
    var minRating: Double?
    var selectedSpecialties: Set<UUID> = []
    var city: String?
    var sortBy: TrainerSortOption = .rating
    
    var isEmpty: Bool {
        searchText.isEmpty &&
        minPrice == nil &&
        maxPrice == nil &&
        minRating == nil &&
        selectedSpecialties.isEmpty &&
        city == nil
    }
}

enum TrainerSortOption: String, CaseIterable {
    case rating = "rating"
    case price = "price"
    case reviews = "reviews"
    case nearest = "nearest"
    
    var displayName: String {
        switch self {
        case .rating: return "Bäst betyg"
        case .price: return "Lägst pris"
        case .reviews: return "Flest omdömen"
        case .nearest: return "Närmast"
        }
    }
}

// MARK: - Default Lesson Types

struct DefaultLessonTypes {
    static let types: [(name: String, description: String, duration: Int, priceMultiplier: Double)] = [
        ("60 min lektion", "Individuell lektion med fokus på din teknik", 60, 1.0),
        ("90 min lektion", "Längre session för djupare genomgång", 90, 1.4),
        ("30 min teknikgenomgång", "Snabb genomgång av specifik teknik", 30, 0.6),
        ("Spela 9 hål", "Träning på banan med coachning", 120, 2.0),
        ("Spela 18 hål", "Helrunda med löpande coachning", 240, 3.5),
        ("Videoanalys", "Inspelning och analys av din swing", 45, 0.8)
    ]
}


