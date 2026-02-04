import Foundation
import Supabase

// MARK: - Models

/// Träningsprogram tilldelat från coach
struct CoachProgram: Identifiable, Codable {
    let id: String
    let coachId: String
    let title: String
    let note: String?
    let durationType: String // "unlimited" or "weeks"
    let durationWeeks: Int?
    let programData: ProgramData
    let createdAt: String
    
    enum CodingKeys: String, CodingKey {
        case id
        case coachId = "coach_id"
        case title
        case note
        case durationType = "duration_type"
        case durationWeeks = "duration_weeks"
        case programData = "program_data"
        case createdAt = "created_at"
    }
}

/// Programdata med rutiner och övningar
struct ProgramData: Codable {
    let routines: [ProgramRoutine]?
    
    // Flexibel decoding för olika format från webben
    init(from decoder: Decoder) throws {
        // Försök först som container med "routines" nyckel
        if let container = try? decoder.container(keyedBy: CodingKeys.self) {
            if let routinesArray = try? container.decode([ProgramRoutine].self, forKey: .routines) {
                routines = routinesArray
                print("📋 ProgramData: Decoded \(routinesArray.count) routines from 'routines' key")
                return
            }
        }
        
        // Försök som direkt array (om program_data ÄR en array av routines)
        if let routinesArray = try? decoder.singleValueContainer().decode([ProgramRoutine].self) {
            routines = routinesArray
            print("📋 ProgramData: Decoded \(routinesArray.count) routines as direct array")
            return
        }
        
        // Fallback - tom array
        print("⚠️ ProgramData: Could not decode routines, setting to empty")
        routines = []
    }
    
    enum CodingKeys: String, CodingKey {
        case routines
    }
    
    init(routines: [ProgramRoutine]?) {
        self.routines = routines
    }
}

/// En rutin i programmet
struct ProgramRoutine: Identifiable, Codable {
    let id: String
    let name: String
    let note: String?
    let exercises: [ProgramExercise]
    
    private enum CodingKeys: String, CodingKey {
        case id, name, title, note, exercises
    }
    
    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        id = try container.decodeIfPresent(String.self, forKey: .id) ?? UUID().uuidString
        
        // Hantera både "name" och "title" från Lovable
        if let title = try container.decodeIfPresent(String.self, forKey: .title) {
            name = title
        } else {
            name = try container.decodeIfPresent(String.self, forKey: .name) ?? "Pass"
        }
        
        note = try container.decodeIfPresent(String.self, forKey: .note)
        
        // Försök hämta exercises
        if let exercisesArray = try? container.decode([ProgramExercise].self, forKey: .exercises) {
            exercises = exercisesArray
            print("   📋 Routine '\(name)': Decoded \(exercisesArray.count) exercises")
        } else {
            exercises = []
            print("   ⚠️ Routine '\(name)': No exercises found or failed to decode")
        }
    }
    
    func encode(to encoder: Encoder) throws {
        var container = encoder.container(keyedBy: CodingKeys.self)
        try container.encode(id, forKey: .id)
        try container.encode(name, forKey: .name)
        try container.encodeIfPresent(note, forKey: .note)
        try container.encode(exercises, forKey: .exercises)
    }
}

/// En övning i programmet
struct ProgramExercise: Identifiable, Codable {
    let id: String
    let exerciseId: String?
    let name: String
    let exerciseImage: String?
    let muscleGroup: String?
    let sets: Int
    let reps: String // Kan vara "8-12" eller "10"
    let notes: String?
    let setsData: [ExerciseSetData]? // Lovables format med array av set-objekt
    
    private enum CodingKeys: String, CodingKey {
        case id
        case exerciseId = "exercise_id"
        case exerciseName = "exercise_name"
        case name
        case exerciseImage = "exercise_image"
        case muscleGroup = "muscle_group"
        case sets
        case reps
        case notes
        case note
    }
    
    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        id = try container.decodeIfPresent(String.self, forKey: .id) ?? UUID().uuidString
        exerciseId = try container.decodeIfPresent(String.self, forKey: .exerciseId)
        
        // Hantera både "name" och "exercise_name" från Lovable
        if let exerciseName = try container.decodeIfPresent(String.self, forKey: .exerciseName) {
            name = exerciseName
        } else {
            name = try container.decodeIfPresent(String.self, forKey: .name) ?? "Övning"
        }
        
        exerciseImage = try container.decodeIfPresent(String.self, forKey: .exerciseImage)
        muscleGroup = try container.decodeIfPresent(String.self, forKey: .muscleGroup)
        
        // Hantera notes/note
        if let noteValue = try container.decodeIfPresent(String.self, forKey: .note) {
            notes = noteValue
        } else {
            notes = try container.decodeIfPresent(String.self, forKey: .notes)
        }
        
        // Hantera sets - kan vara int (antal) eller array (Lovables format)
        // Försök först tolka som array av ExerciseSetData
        if let setsArray = try? container.decode([ExerciseSetData].self, forKey: .sets) {
            setsData = setsArray
            sets = setsArray.count
            // Extrahera reps från första setet
            if let firstSet = setsArray.first {
                reps = "\(firstSet.reps)"
            } else {
                reps = "10"
            }
        } else if let setsInt = try? container.decode(Int.self, forKey: .sets) {
            sets = setsInt
            setsData = nil
            // Reps kan vara int eller string
            if let repsInt = try? container.decode(Int.self, forKey: .reps) {
                reps = "\(repsInt)"
            } else {
                reps = try container.decodeIfPresent(String.self, forKey: .reps) ?? "10"
            }
        } else {
            sets = 3
            setsData = nil
            reps = "10"
        }
    }
    
    func encode(to encoder: Encoder) throws {
        var container = encoder.container(keyedBy: CodingKeys.self)
        try container.encode(id, forKey: .id)
        try container.encodeIfPresent(exerciseId, forKey: .exerciseId)
        try container.encode(name, forKey: .name)
        try container.encodeIfPresent(exerciseImage, forKey: .exerciseImage)
        try container.encodeIfPresent(muscleGroup, forKey: .muscleGroup)
        try container.encode(sets, forKey: .sets)
        try container.encode(reps, forKey: .reps)
        try container.encodeIfPresent(notes, forKey: .notes)
    }
}

/// Ett set i en övning (Lovables format)
struct ExerciseSetData: Identifiable, Codable {
    let id: String
    let reps: Int
    let weight: Double?
    let rpe: Int?
    
    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        id = try container.decodeIfPresent(String.self, forKey: .id) ?? UUID().uuidString
        reps = try container.decodeIfPresent(Int.self, forKey: .reps) ?? 10
        weight = try container.decodeIfPresent(Double.self, forKey: .weight)
        rpe = try container.decodeIfPresent(Int.self, forKey: .rpe)
    }
    
    enum CodingKeys: String, CodingKey {
        case id, reps, weight, rpe
    }
}

/// Tilldelning av program till klient
struct CoachProgramAssignment: Identifiable, Codable {
    let id: String
    let coachId: String
    let clientId: String
    let programId: String
    let status: String // "active", "paused", "completed"
    let assignedAt: String
    let startDate: String?
    let program: CoachProgram?
    let coach: CoachProfile?
    
    enum CodingKeys: String, CodingKey {
        case id
        case coachId = "coach_id"
        case clientId = "client_id"
        case programId = "program_id"
        case status
        case assignedAt = "assigned_at"
        case startDate = "start_date"
        case program = "coach_programs"
        case coach = "coach"
    }
}

/// Coach-profil (förenklad)
struct CoachProfile: Codable {
    let id: String
    let username: String?
    let avatarUrl: String?
    
    enum CodingKeys: String, CodingKey {
        case id
        case username
        case avatarUrl = "avatar_url"
    }
}

/// Coach-klient relation
struct CoachClientRelation: Codable {
    let id: String
    let coachId: String
    let clientId: String
    let status: String
    let coach: CoachProfile?
    
    enum CodingKeys: String, CodingKey {
        case id
        case coachId = "coach_id"
        case clientId = "client_id"
        case status
        case coach
    }
}

// MARK: - Service

final class CoachService {
    static let shared = CoachService()
    private let supabase = SupabaseConfig.supabase
    
    private init() {}
    
    // MARK: - Hämta tilldelade program
    
    /// Hämta alla aktiva program tilldelade till användaren
    func fetchAssignedPrograms(for userId: String) async throws -> [CoachProgramAssignment] {
        print("📋 Fetching assigned programs for user: \(userId)")
        
        // Hämta raw data först för debugging
        let response = try await supabase
            .from("coach_program_assignments")
            .select("""
                id,
                coach_id,
                client_id,
                program_id,
                status,
                assigned_at,
                start_date,
                coach_programs (
                    id,
                    coach_id,
                    title,
                    note,
                    duration_type,
                    duration_weeks,
                    program_data,
                    created_at
                ),
                coach:profiles!coach_id (
                    id,
                    username,
                    avatar_url
                )
            """)
            .eq("client_id", value: userId)
            .eq("status", value: "active")
            .order("assigned_at", ascending: false)
            .execute()
        
        // Debug: Logga raw JSON
        if let jsonString = String(data: response.data, encoding: .utf8) {
            print("📦 Raw JSON response:\n\(jsonString.prefix(2000))...")
        }
        
        // Decoda
        let assignments: [CoachProgramAssignment] = try JSONDecoder().decode([CoachProgramAssignment].self, from: response.data)
        
        print("✅ Fetched \(assignments.count) assigned programs")
        return assignments
    }
    
    // MARK: - Hämta användarens coach
    
    /// Hämta aktiv coach-relation för användaren
    func fetchMyCoach(for userId: String) async throws -> CoachClientRelation? {
        print("👤 Fetching coach for user: \(userId)")
        
        let relations: [CoachClientRelation] = try await supabase
            .from("coach_clients")
            .select("""
                id,
                coach_id,
                client_id,
                status,
                coach:profiles!coach_id (
                    id,
                    username,
                    avatar_url
                )
            """)
            .eq("client_id", value: userId)
            .eq("status", value: "active")
            .limit(1)
            .execute()
            .value
        
        if let coach = relations.first {
            print("✅ Found coach: \(coach.coach?.username ?? "Unknown")")
        } else {
            print("ℹ️ No coach found for user")
        }
        
        return relations.first
    }
    
    // MARK: - Coach-inbjudan (coach_client_invitations table)
    
    /// Acceptera en coach-inbjudan via Edge Function
    func acceptCoachInvitation(invitationId: String) async throws {
        print("🎯 Accepting coach invitation via edge function: \(invitationId)")
        
        struct AcceptRequest: Encodable {
            let invitationId: String
        }
        
        struct AcceptResponse: Decodable {
            let success: Bool
            let message: String
            let coachName: String?
            let error: String?
        }
        
        let request = AcceptRequest(invitationId: invitationId)
        
        do {
            let result: AcceptResponse = try await supabase.functions.invoke(
                "accept-coach-invitation",
                options: FunctionInvokeOptions(body: request)
            )
            
            if result.success {
                print("✅ Coach invitation accepted successfully!")
                if let coachName = result.coachName {
                    print("   🎉 Now connected to coach: \(coachName)")
                }
            } else {
                let errorMsg = result.error ?? result.message
                print("❌ Failed to accept invitation: \(errorMsg)")
                throw NSError(domain: "CoachService", code: 400, userInfo: [NSLocalizedDescriptionKey: errorMsg])
            }
        } catch {
            print("❌ Edge function failed, trying direct database approach...")
            print("   Error: \(error)")
            
            // Fallback: Använd direkta databasoperationer
            try await acceptCoachInvitationDirect(invitationId: invitationId)
        }
    }
    
    /// Fallback-metod: Acceptera inbjudan med direkta databasoperationer
    private func acceptCoachInvitationDirect(invitationId: String) async throws {
        print("🔄 Using direct database approach...")
        
        // 1. Hämta inbjudan
        struct InvitationData: Decodable {
            let coachId: String
            let clientId: String?
            let status: String
            
            enum CodingKeys: String, CodingKey {
                case coachId = "coach_id"
                case clientId = "client_id"
                case status
            }
        }
        
        print("1️⃣ Fetching invitation...")
        let invitations: [InvitationData] = try await supabase
            .from("coach_client_invitations")
            .select("coach_id, client_id, status")
            .eq("id", value: invitationId)
            .execute()
            .value
        
        guard let invitation = invitations.first else {
            print("❌ Invitation not found in database")
            throw NSError(domain: "CoachService", code: 404, userInfo: [NSLocalizedDescriptionKey: "Inbjudan hittades inte"])
        }
        
        guard let clientId = invitation.clientId else {
            print("❌ Client ID is missing from invitation")
            throw NSError(domain: "CoachService", code: 400, userInfo: [NSLocalizedDescriptionKey: "Klient-ID saknas"])
        }
        
        print("   ✅ Found invitation: coach=\(invitation.coachId), client=\(clientId), status=\(invitation.status)")
        
        // 2. Uppdatera inbjudan
        print("2️⃣ Updating invitation status...")
        try await supabase
            .from("coach_client_invitations")
            .update(["status": "accepted"])
            .eq("id", value: invitationId)
            .execute()
        print("   ✅ Invitation status updated to accepted")
        
        // 3. Skapa eller uppdatera coach-client relation
        print("3️⃣ Creating/updating coach-client relation...")
        
        // Först, kolla om en relation redan finns
        let existingRelations: [CoachClientRelation] = try await supabase
            .from("coach_clients")
            .select("id, coach_id, client_id, status")
            .eq("coach_id", value: invitation.coachId)
            .eq("client_id", value: clientId)
            .execute()
            .value
        
        if let existingRelation = existingRelations.first {
            print("   ℹ️ Found existing relation: \(existingRelation.id), status: \(existingRelation.status)")
            
            // Uppdatera befintlig relation till active
            try await supabase
                .from("coach_clients")
                .update(["status": "active"])
                .eq("id", value: existingRelation.id)
                .execute()
            print("   ✅ Updated relation to active")
        } else {
            print("   ℹ️ No existing relation found, creating new one...")
            
            // Försök skapa ny relation (kan fortfarande faila pga RLS)
            do {
                try await supabase
                    .from("coach_clients")
                    .insert([
                        "coach_id": invitation.coachId,
                        "client_id": clientId,
                        "status": "active"
                    ])
                    .execute()
                print("   ✅ New relation created!")
            } catch let insertError {
                print("   ❌ Insert failed due to RLS: \(insertError)")
                print("   ⚠️ RLS policy is blocking insert - check Supabase dashboard")
                throw NSError(domain: "CoachService", code: 403, userInfo: [
                    NSLocalizedDescriptionKey: "Kunde inte skapa coach-relation. Kontakta support."
                ])
            }
        }
        
        // 4. Verifiera att relationen skapades och har status "active"
        print("4️⃣ Verifying coach-client relation...")
        let relations: [CoachClientRelation] = try await supabase
            .from("coach_clients")
            .select("""
                id,
                coach_id,
                client_id,
                status
            """)
            .eq("coach_id", value: invitation.coachId)
            .eq("client_id", value: clientId)
            .eq("status", value: "active")
            .execute()
            .value
        
        if relations.isEmpty {
            print("   ❌ No active relation found after update!")
            print("   🔍 Checking all relations for this coach-client pair...")
            
            let allRelations: [CoachClientRelation] = try await supabase
                .from("coach_clients")
                .select("id, coach_id, client_id, status")
                .eq("coach_id", value: invitation.coachId)
                .eq("client_id", value: clientId)
                .execute()
                .value
            
            for relation in allRelations {
                print("      - Relation \(relation.id): status=\(relation.status)")
            }
            
            throw NSError(domain: "CoachService", code: 500, userInfo: [NSLocalizedDescriptionKey: "Coach-relationen kunde inte aktiveras. Status är inte 'active'."])
        } else {
            print("   ✅ Active relation verified: \(relations.first!.id)")
        }
        
        // 5. Markera notifikation som läst
        print("5️⃣ Marking notification as read...")
        try await supabase
            .from("notifications")
            .update(["is_read": true])
            .eq("user_id", value: clientId)
            .eq("type", value: "coach_invitation")
            .eq("actor_id", value: invitation.coachId)
            .execute()
        print("   ✅ Notification marked as read")
        
        print("🎉 Coach invitation accepted via direct database!")
    }
    
    /// Neka en coach-inbjudan via Edge Function
    func declineCoachInvitation(invitationId: String) async throws {
        print("❌ Declining coach invitation via edge function: \(invitationId)")
        
        struct DeclineRequest: Encodable {
            let invitationId: String
        }
        
        struct DeclineResponse: Decodable {
            let success: Bool
            let message: String
        }
        
        let request = DeclineRequest(invitationId: invitationId)
        
        do {
            let result: DeclineResponse = try await supabase.functions.invoke(
                "decline-coach-invitation",
                options: FunctionInvokeOptions(body: request)
            )
            
            if result.success {
                print("✅ Coach invitation declined successfully!")
            } else {
                print("❌ Failed to decline invitation: \(result.message)")
                throw NSError(domain: "CoachService", code: 400, userInfo: [NSLocalizedDescriptionKey: result.message])
            }
        } catch {
            print("❌ Edge function failed, trying direct database approach...")
            
            // Fallback: Använd direkta databasoperationer
            try await declineCoachInvitationDirect(invitationId: invitationId)
        }
    }
    
    /// Fallback-metod: Neka inbjudan med direkta databasoperationer
    private func declineCoachInvitationDirect(invitationId: String) async throws {
        print("🔄 Using direct database approach for decline...")
        
        // 1. Uppdatera inbjudan till rejected
        try await supabase
            .from("coach_client_invitations")
            .update(["status": "rejected"])
            .eq("id", value: invitationId)
            .execute()
        
        // 2. Hämta inbjudan för att få client_id och coach_id
        struct InvitationData: Decodable {
            let coachId: String
            let clientId: String?
            
            enum CodingKeys: String, CodingKey {
                case coachId = "coach_id"
                case clientId = "client_id"
            }
        }
        
        let invitations: [InvitationData] = try await supabase
            .from("coach_client_invitations")
            .select("coach_id, client_id")
            .eq("id", value: invitationId)
            .execute()
            .value
        
        if let invitation = invitations.first, let clientId = invitation.clientId {
            // 3. Radera notifikation
            try await supabase
                .from("notifications")
                .delete()
                .eq("user_id", value: clientId)
                .eq("type", value: "coach_invitation")
                .eq("actor_id", value: invitation.coachId)
                .execute()
        }
        
        print("✅ Coach invitation declined via direct database!")
    }
    
    /// Hämta pending coach-inbjudningar från coach_client_invitations
    func fetchPendingInvitations(for userId: String) async throws -> [CoachInvitation] {
        print("📨 Fetching pending invitations for user: \(userId)")
        
        let invitations: [CoachInvitation] = try await supabase
            .from("coach_client_invitations")
            .select("""
                id,
                coach_id,
                client_id,
                client_email,
                invite_code,
                status,
                created_at,
                expires_at,
                coach:profiles!coach_id (
                    id,
                    username,
                    avatar_url
                )
            """)
            .eq("client_id", value: userId)
            .eq("status", value: "pending")
            .order("created_at", ascending: false)
            .execute()
            .value
        
        print("✅ Found \(invitations.count) pending invitations")
        return invitations
    }
    
    // MARK: - Lämna coach
    
    /// Lämna sin nuvarande coach
    func leaveCoach(relationId: String) async throws {
        print("👋 Leaving coach, relation: \(relationId)")
        
        try await supabase
            .from("coach_clients")
            .update(["status": "ended"])
            .eq("id", value: relationId)
            .execute()
        
        print("✅ Left coach successfully")
    }
    
    // MARK: - Konvertera till SavedGymWorkout
    
    /// Konvertera en program-rutin till SavedGymWorkout för att använda i gympasset
    func convertRoutineToSavedWorkout(_ routine: ProgramRoutine, programTitle: String, coachName: String?) -> SavedGymWorkout {
        let exercises = routine.exercises.map { exercise -> GymExercisePost in
            let repsArray: [Int]
            let kgArray: [Double]
            
            // Om vi har setsData från Lovable, använd den
            if let setsData = exercise.setsData, !setsData.isEmpty {
                repsArray = setsData.map { $0.reps }
                kgArray = setsData.map { $0.weight ?? 0.0 }
            } else {
                // Parsa reps - kan vara "8-12" eller "10"
                if let singleRep = Int(exercise.reps) {
                    repsArray = Array(repeating: singleRep, count: exercise.sets)
                } else if exercise.reps.contains("-") {
                    // Ta genomsnitt av range
                    let parts = exercise.reps.split(separator: "-")
                    if let low = Int(parts.first ?? ""), let high = Int(parts.last ?? "") {
                        let avg = (low + high) / 2
                        repsArray = Array(repeating: avg, count: exercise.sets)
                    } else {
                        repsArray = Array(repeating: 10, count: exercise.sets)
                    }
                } else {
                    repsArray = Array(repeating: 10, count: exercise.sets)
                }
                kgArray = Array(repeating: 0.0, count: exercise.sets) // Användaren fyller i vikt
            }
            
            return GymExercisePost(
                id: exercise.exerciseId,
                name: exercise.name,
                category: exercise.muscleGroup,
                sets: exercise.sets,
                reps: repsArray,
                kg: kgArray,
                notes: exercise.notes
            )
        }
        
        return SavedGymWorkout(
            id: routine.id,
            userId: "coach", // Markera att det kommer från coach
            name: "\(routine.name) (från \(coachName ?? "tränare"))",
            exercises: exercises,
            createdAt: Date()
        )
    }
}

// MARK: - Coach Invitation Model (coach_client_invitations table)

struct CoachInvitation: Identifiable, Codable {
    let id: String
    let coachId: String
    let clientId: String?
    let clientEmail: String?
    let inviteCode: String?
    let status: String
    let createdAt: String
    let expiresAt: String?
    let coach: CoachProfileFull?
    
    enum CodingKeys: String, CodingKey {
        case id
        case coachId = "coach_id"
        case clientId = "client_id"
        case clientEmail = "client_email"
        case inviteCode = "invite_code"
        case status
        case createdAt = "created_at"
        case expiresAt = "expires_at"
        case coach
    }
}

/// Coach profil
struct CoachProfileFull: Codable {
    let id: String
    let username: String?
    let avatarUrl: String?
    
    enum CodingKeys: String, CodingKey {
        case id
        case username
        case avatarUrl = "avatar_url"
    }
    
    /// Display name
    var displayName: String {
        return username ?? "Tränare"
    }
}
