import Foundation
import SwiftUI

// MARK: - Achievement Tier (for color progression)
enum AchievementTier: Int, Codable {
    case starter = 1
    case bronze = 2
    case silver = 3
    case gold = 4
    case platinum = 5
    case diamond = 6
    case legendary = 7
    
    var colors: [Color] {
        switch self {
        case .starter:
            return [Color(hex: "8B5CF6"), Color(hex: "7C3AED")] // Light purple
        case .bronze:
            return [Color(hex: "A855F7"), Color(hex: "9333EA")] // Purple
        case .silver:
            return [Color(hex: "C084FC"), Color(hex: "A855F7")] // Lighter purple
        case .gold:
            return [Color(hex: "E879F9"), Color(hex: "D946EF")] // Pink/Magenta
        case .platinum:
            return [Color(hex: "F472B6"), Color(hex: "EC4899")] // Hot pink
        case .diamond:
            return [Color(hex: "22D3EE"), Color(hex: "06B6D4")] // Cyan
        case .legendary:
            return [Color(hex: "FBBF24"), Color(hex: "F59E0B")] // Gold with shimmer
        }
    }
    
    var workoutColors: [Color] {
        switch self {
        case .starter:
            return [Color(hex: "FB923C"), Color(hex: "F97316")] // Orange
        case .bronze:
            return [Color(hex: "F97316"), Color(hex: "EA580C")] // Darker orange
        case .silver:
            return [Color(hex: "EF4444"), Color(hex: "DC2626")] // Red
        case .gold:
            return [Color(hex: "F59E0B"), Color(hex: "D97706")] // Amber/Gold
        case .platinum:
            return [Color(hex: "FBBF24"), Color(hex: "F59E0B")] // Gold
        case .diamond:
            return [Color(hex: "FCD34D"), Color(hex: "FBBF24")] // Bright gold
        case .legendary:
            return [Color(hex: "FEF08A"), Color(hex: "FDE047")] // Lightning gold
        }
    }
}

// MARK: - Achievement Model
struct Achievement: Identifiable, Codable, Equatable {
    let id: String
    let name: String
    let description: String
    let icon: String // SF Symbol name
    let category: AchievementCategory
    let requirement: Int
    let motivationalQuote: String
    let tier: AchievementTier
    var unlockedAt: Date?
    
    var isUnlocked: Bool {
        unlockedAt != nil
    }
    
    var gradientColors: [Color] {
        switch category {
        case .meals:
            return tier.colors
        case .workouts:
            return tier.workoutColors
        case .social:
            return [Color.blue, Color.cyan]
        case .streaks:
            return [Color.green, Color.mint]
        case .special:
            return [Color.pink, Color.purple]
        }
    }
    
    static func == (lhs: Achievement, rhs: Achievement) -> Bool {
        lhs.id == rhs.id
    }
}

// MARK: - Achievement Category
enum AchievementCategory: String, Codable, CaseIterable {
    case meals = "Matloggning"
    case workouts = "Träning"
    case social = "Socialt"
    case streaks = "Streaks"
    case special = "Speciella"
    
    var color: Color {
        switch self {
        case .meals: return Color.purple
        case .workouts: return Color.orange
        case .social: return Color.blue
        case .streaks: return Color.green
        case .special: return Color.pink
        }
    }
    
    var gradientColors: [Color] {
        switch self {
        case .meals: 
            return [Color(red: 0.6, green: 0.4, blue: 0.9), Color(red: 0.5, green: 0.3, blue: 0.8)]
        case .workouts: 
            return [Color.orange, Color.red]
        case .social: 
            return [Color.blue, Color.cyan]
        case .streaks: 
            return [Color.green, Color.mint]
        case .special: 
            return [Color.pink, Color.purple]
        }
    }
}

// MARK: - Predefined Achievements
extension Achievement {
    static let allAchievements: [Achievement] = [
        
        // ==========================================
        // 🍽️ MATLOGGNING MED AI
        // ==========================================
        
        Achievement(
            id: "first_scan",
            name: "Kommer igång",
            description: "Din första AI-scan",
            icon: "sparkles",
            category: .meals,
            requirement: 1,
            motivationalQuote: "Första steget mot full kontroll! 🚀",
            tier: .starter
        ),
        Achievement(
            id: "scans_3",
            name: "På rätt spår",
            description: "3 AI-skanningar",
            icon: "arrow.right.circle.fill",
            category: .meals,
            requirement: 3,
            motivationalQuote: "Du börjar få koll på det här! 📈",
            tier: .bronze
        ),
        Achievement(
            id: "scans_10",
            name: "Dialed in",
            description: "10 AI-skanningar",
            icon: "target",
            category: .meals,
            requirement: 10,
            motivationalQuote: "Nu snackar vi precision! 🎯",
            tier: .silver
        ),
        Achievement(
            id: "scans_20",
            name: "Vanan sitter",
            description: "20 AI-skanningar",
            icon: "checkmark.seal.fill",
            category: .meals,
            requirement: 20,
            motivationalQuote: "Det har blivit en del av dig! 💪",
            tier: .gold
        ),
        Achievement(
            id: "scans_30",
            name: "Full kontroll",
            description: "30 AI-skanningar",
            icon: "slider.horizontal.3",
            category: .meals,
            requirement: 30,
            motivationalQuote: "Du har total överblick! 🎛️",
            tier: .platinum
        ),
        Achievement(
            id: "scans_50",
            name: "Locked in",
            description: "50 AI-skanningar",
            icon: "lock.fill",
            category: .meals,
            requirement: 50,
            motivationalQuote: "Ingenting stoppar dig nu! 🔒",
            tier: .diamond
        ),
        Achievement(
            id: "scans_100",
            name: "Mastery",
            description: "100 AI-skanningar",
            icon: "crown.fill",
            category: .meals,
            requirement: 100,
            motivationalQuote: "Du är en sann mästare! 👑",
            tier: .legendary
        ),
        
        // ==========================================
        // 🏋️ TRÄNINGSPASS
        // ==========================================
        
        Achievement(
            id: "first_workout",
            name: "Första steget",
            description: "Ditt första träningspass",
            icon: "figure.walk",
            category: .workouts,
            requirement: 1,
            motivationalQuote: "Varje resa börjar med ett steg! 👟",
            tier: .starter
        ),
        Achievement(
            id: "workouts_3",
            name: "Rullande rutin",
            description: "3 träningspass",
            icon: "arrow.triangle.2.circlepath",
            category: .workouts,
            requirement: 3,
            motivationalQuote: "Rutinen börjar ta form! 🔄",
            tier: .bronze
        ),
        Achievement(
            id: "workouts_10",
            name: "Bygger momentum",
            description: "10 träningspass",
            icon: "bolt.fill",
            category: .workouts,
            requirement: 10,
            motivationalQuote: "Du är på gång! ⚡",
            tier: .silver
        ),
        Achievement(
            id: "workouts_25",
            name: "Konsekvent",
            description: "25 träningspass",
            icon: "chart.line.uptrend.xyaxis",
            category: .workouts,
            requirement: 25,
            motivationalQuote: "Konsekvens slår allt! 📊",
            tier: .gold
        ),
        Achievement(
            id: "workouts_50",
            name: "All in",
            description: "50 träningspass",
            icon: "flame.fill",
            category: .workouts,
            requirement: 50,
            motivationalQuote: "Du är helt dedikerad! 🔥",
            tier: .platinum
        ),
        Achievement(
            id: "workouts_100",
            name: "Beast mode",
            description: "100 träningspass",
            icon: "bolt.heart.fill",
            category: .workouts,
            requirement: 100,
            motivationalQuote: "BEAST MODE ACTIVATED! 🦁",
            tier: .legendary
        ),
        
        // ==========================================
        // 👥 SOCIAL
        // ==========================================
        
        Achievement(
            id: "first_follower",
            name: "Social Fjäril",
            description: "Fått din första följare",
            icon: "person.badge.plus",
            category: .social,
            requirement: 1,
            motivationalQuote: "Gemenskapen växer!",
            tier: .starter
        ),
        Achievement(
            id: "first_story",
            name: "Storyteller",
            description: "Postat din första story",
            icon: "camera.fill",
            category: .social,
            requirement: 1,
            motivationalQuote: "Dela din resa med världen!",
            tier: .starter
        ),
        
        // ==========================================
        // 🔥 STREAKS
        // ==========================================
        
        Achievement(
            id: "streak_7",
            name: "Vecko-Warrior",
            description: "7 dagars streak",
            icon: "flame.fill",
            category: .streaks,
            requirement: 7,
            motivationalQuote: "En hel vecka! Imponerande!",
            tier: .bronze
        ),
        Achievement(
            id: "streak_30",
            name: "Månads-Mästare",
            description: "30 dagars streak",
            icon: "calendar",
            category: .streaks,
            requirement: 30,
            motivationalQuote: "Du är ostoppbar!",
            tier: .gold
        )
    ]
    
    static func getAchievement(id: String) -> Achievement? {
        allAchievements.first { $0.id == id }
    }
}
