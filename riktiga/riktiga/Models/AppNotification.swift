import Foundation

struct AppNotification: Identifiable, Codable {
    let id: String
    let userId: String // Mottagare
    let actorId: String // Den som utförde handlingen
    let actorUsername: String?
    let actorAvatarUrl: String?
    let type: NotificationType
    let postId: String?
    let commentText: String?
    let createdAt: String
    var isRead: Bool
    
    enum NotificationType: Equatable, Codable {
        case like
        case comment
        case follow
        case newWorkout
        case reply
        case coachInvitation
        case coachProgramAssigned
        case trainerChatMessage
        case coachScheduleUpdated
        case unknown(String)
        
        init(rawValue: String) {
            switch rawValue {
            case "like": self = .like
            case "comment": self = .comment
            case "follow": self = .follow
            case "new_workout": self = .newWorkout
            case "reply": self = .reply
            case "coach_invitation": self = .coachInvitation
            case "coach_program_assigned": self = .coachProgramAssigned
            case "trainer_chat_message": self = .trainerChatMessage
            case "coach_schedule_updated": self = .coachScheduleUpdated
            default: self = .unknown(rawValue)
            }
        }
        
        var rawValue: String {
            switch self {
            case .like: return "like"
            case .comment: return "comment"
            case .follow: return "follow"
            case .newWorkout: return "new_workout"
            case .reply: return "reply"
            case .coachInvitation: return "coach_invitation"
            case .coachProgramAssigned: return "coach_program_assigned"
            case .trainerChatMessage: return "trainer_chat_message"
            case .coachScheduleUpdated: return "coach_schedule_updated"
            case .unknown(let value): return value
            }
        }
        
        init(from decoder: Decoder) throws {
            let value = try decoder.singleValueContainer().decode(String.self)
            self = NotificationType(rawValue: value)
        }
        
        func encode(to encoder: Encoder) throws {
            var container = encoder.singleValueContainer()
            try container.encode(rawValue)
        }
    }
    
    enum CodingKeys: String, CodingKey {
        case id
        case userId = "user_id"
        case actorId = "actor_id"
        case actorUsername = "actor_username"
        case actorAvatarUrl = "actor_avatar_url"
        case type
        case postId = "post_id"
        case commentText = "comment_text"
        case createdAt = "created_at"
        case isRead = "is_read"
    }
    
    init(id: String,
         userId: String,
         actorId: String,
         actorUsername: String?,
         actorAvatarUrl: String?,
         type: NotificationType,
         postId: String?,
         commentText: String?,
         createdAt: String,
         isRead: Bool) {
        self.id = id
        self.userId = userId
        self.actorId = actorId
        self.actorUsername = actorUsername
        self.actorAvatarUrl = actorAvatarUrl
        self.type = type
        self.postId = postId
        self.commentText = commentText
        self.createdAt = createdAt
        self.isRead = isRead
    }
    
    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        self.id = try container.decodeIfPresent(String.self, forKey: .id) ?? UUID().uuidString
        self.userId = try container.decodeIfPresent(String.self, forKey: .userId) ?? ""
        self.actorId = try container.decodeIfPresent(String.self, forKey: .actorId) ?? ""
        self.actorUsername = try container.decodeIfPresent(String.self, forKey: .actorUsername)
        self.actorAvatarUrl = try container.decodeIfPresent(String.self, forKey: .actorAvatarUrl)
        
        let typeString = try container.decodeIfPresent(String.self, forKey: .type) ?? "unknown"
        self.type = NotificationType(rawValue: typeString)
        
        self.postId = try container.decodeIfPresent(String.self, forKey: .postId)
        self.commentText = try container.decodeIfPresent(String.self, forKey: .commentText)
        
        if let createdAtString = try container.decodeIfPresent(String.self, forKey: .createdAt) {
            self.createdAt = createdAtString
        } else if let dateValue = try container.decodeIfPresent(Date.self, forKey: .createdAt) {
            self.createdAt = ISO8601DateFormatter.cached.string(from: dateValue)
        } else {
            self.createdAt = ISO8601DateFormatter.cached.string(from: Date())
        }
        
        self.isRead = try container.decodeIfPresent(Bool.self, forKey: .isRead) ?? true
    }
    
    var displayText: String {
        switch type {
        case .like:
            return "\(actorUsername ?? "Någon") gillade ditt inlägg"
        case .comment:
            if let text = commentText, !text.isEmpty {
                return "\(actorUsername ?? "Någon") kommenterade: \"\(text)\""
            }
            return "\(actorUsername ?? "Någon") kommenterade på ditt inlägg"
        case .follow:
            return "\(actorUsername ?? "Någon") började följa dig"
        case .newWorkout:
            return "\(actorUsername ?? "Någon") har avslutat ett träningspass! 🏃"
        case .reply:
            if let text = commentText, !text.isEmpty {
                return "\(actorUsername ?? "Någon") svarade: \"\(text)\""
            }
            return "\(actorUsername ?? "Någon") svarade på din kommentar"
        case .coachInvitation:
            return "\(actorUsername ?? "En tränare") vill coacha dig!"
        case .coachProgramAssigned:
            return "\(actorUsername ?? "Din tränare") har tilldelat dig ett träningsprogram"
        case .trainerChatMessage:
            return "\(actorUsername ?? "Din tränare") skickade ett meddelande"
        case .coachScheduleUpdated:
            return "\(actorUsername ?? "Din tränare") uppdaterade ditt schema"
        case .unknown:
            return "\(actorUsername ?? "Någon") skickade en ny notis"
        }
    }
    
    var icon: String {
        switch type {
        case .like:
            return "heart.fill"
        case .comment:
            return "bubble.right.fill"
        case .follow:
            return "person.fill.badge.plus"
        case .newWorkout:
            return "figure.run"
        case .reply:
            return "arrowshape.turn.up.left.fill"
        case .coachInvitation:
            return "person.crop.circle.badge.plus"
        case .coachProgramAssigned:
            return "dumbbell.fill"
        case .trainerChatMessage:
            return "message.fill"
        case .coachScheduleUpdated:
            return "calendar.badge.clock"
        case .unknown:
            return "bell.fill"
        }
    }
    
    var iconColor: String {
        switch type {
        case .like:
            return "red"
        case .comment:
            return "blue"
        case .follow:
            return "green"
        case .newWorkout:
            return "orange"
        case .reply:
            return "purple"
        case .coachInvitation:
            return "purple"
        case .coachProgramAssigned:
            return "indigo"
        case .trainerChatMessage:
            return "blue"
        case .coachScheduleUpdated:
            return "orange"
        case .unknown:
            return "gray"
        }
    }
}

private extension ISO8601DateFormatter {
    static let cached: ISO8601DateFormatter = {
        let formatter = ISO8601DateFormatter()
        formatter.formatOptions = [.withInternetDateTime, .withFractionalSeconds]
        return formatter
    }()
}

