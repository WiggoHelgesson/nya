import Foundation
import SwiftUI
import UIKit
import Combine
import ConfettiSwiftUI

/// CelebrationManager - Hanterar alla konfetti-animationer i appen
/// Inspirerat av Duolingo's belöningssystem för att göra gym-actions roliga och engagerande
class CelebrationManager: ObservableObject {
    static let shared = CelebrationManager()
    
    // MARK: - Published Properties
    @Published var confettiCounter = 0
    @Published private(set) var celebrationType: CelebrationType = .small
    
    // MARK: - Celebration Types
    enum CelebrationType {
        case small      // Övning tillagd - subtil från toppen
        case medium     // Pass startat - explosion från mitten
        case big        // Pass avslutat - full-screen fireworks
        case milestone  // Special achievements (3 Uppys, PR, etc)
        
        var confettiCount: Int {
            switch self {
            case .small: return 8
            case .medium: return 35
            case .big: return 60
            case .milestone: return 50
            }
        }
        
        var confettiSize: CGFloat {
            switch self {
            case .small: return 7.0
            case .medium: return 10.0
            case .big: return 12.0
            case .milestone: return 11.0
            }
        }
        
        var radius: CGFloat {
            switch self {
            case .small: return 200
            case .medium: return 500
            case .big: return 700
            case .milestone: return 600
            }
        }
        
        var rainHeight: CGFloat {
            switch self {
            case .small: return 300
            case .medium: return 600
            case .big: return 800
            case .milestone: return 700
            }
        }
        
        var repetitions: Int {
            switch self {
            case .small: return 1
            case .medium: return 2
            case .big: return 3
            case .milestone: return 2
            }
        }
        
        var repetitionInterval: Double {
            switch self {
            case .small: return 0.3
            case .medium: return 0.5
            case .big: return 0.7
            case .milestone: return 0.6
            }
        }
        
        var confettiColors: [Color] {
            switch self {
            case .small:
                // Blå/grön palette - subtil och calm
                return [
                    Color(red: 0.2, green: 0.6, blue: 0.9),  // Ljusblå
                    Color(red: 0.3, green: 0.8, blue: 0.7),  // Turkos
                    Color(red: 0.4, green: 0.7, blue: 0.5),  // Grön
                ]
            case .medium:
                // Multicolor - energisk
                return [
                    Color(red: 1.0, green: 0.3, blue: 0.3),  // Röd
                    Color(red: 0.3, green: 0.6, blue: 1.0),  // Blå
                    Color(red: 1.0, green: 0.8, blue: 0.2),  // Gul
                    Color(red: 0.9, green: 0.4, blue: 0.9),  // Lila
                    Color(red: 0.3, green: 0.9, blue: 0.5),  // Grön
                ]
            case .big:
                // Guld/celebration theme - triumf
                return [
                    Color(red: 1.0, green: 0.84, blue: 0.0),  // Guld
                    Color(red: 1.0, green: 0.65, blue: 0.0),  // Orange-guld
                    Color(red: 1.0, green: 0.95, blue: 0.6),  // Ljusgul
                    Color(red: 1.0, green: 0.5, blue: 0.0),   // Orange
                    Color.white,                              // Vit
                ]
            case .milestone:
                // Special achievements - unik lila/rosa palette
                return [
                    Color(red: 0.8, green: 0.2, blue: 0.9),  // Lila
                    Color(red: 1.0, green: 0.4, blue: 0.8),  // Rosa
                    Color(red: 0.5, green: 0.2, blue: 1.0),  // Djupblå-lila
                    Color(red: 1.0, green: 0.6, blue: 0.9),  // Ljusrosa
                    Color.white,                              // Vit
                ]
            }
        }
        
        var hapticStyle: UIImpactFeedbackGenerator.FeedbackStyle {
            switch self {
            case .small: return .light
            case .medium: return .medium
            case .big: return .heavy
            case .milestone: return .heavy
            }
        }
    }
    
    // MARK: - Private Properties
    private var lastCelebrationTime: Date?
    private let minimumTimeBetweenCelebrations: TimeInterval = 0.3 // Prevent spam
    
    private init() {}
    
    // MARK: - Public Methods
    
    /// Trigga en konfetti-celebration
    /// - Parameters:
    ///   - type: Typ av celebration
    ///   - haptic: Om haptic feedback ska spelas (default: true)
    func celebrate(_ type: CelebrationType, withHaptic: Bool = true) {
        // Check if we should throttle celebrations
        if let lastTime = lastCelebrationTime,
           Date().timeIntervalSince(lastTime) < minimumTimeBetweenCelebrations {
            print("⚠️ Throttling celebration - too soon after last one")
            return
        }
        
        // Check reduced motion accessibility setting
        if UIAccessibility.isReduceMotionEnabled {
            print("♿️ Reduced motion enabled - skipping confetti animation")
            // Still provide haptic feedback if requested
            if withHaptic {
                triggerHaptic(type.hapticStyle)
            }
            return
        }
        
        // Update state on main thread
        DispatchQueue.main.async { [weak self] in
            guard let self = self else { return }
            
            self.celebrationType = type
            self.confettiCounter += 1
            self.lastCelebrationTime = Date()
            
            print("🎉 Celebration triggered: \(type) (counter: \(self.confettiCounter))")
            
            // Trigger haptic feedback
            if withHaptic {
                self.triggerHaptic(type.hapticStyle)
            }
        }
    }
    
    /// Reset konfetti-räknaren (används vid behov för debugging)
    func reset() {
        DispatchQueue.main.async { [weak self] in
            self?.confettiCounter = 0
        }
    }
    
    // MARK: - Private Methods
    
    private func triggerHaptic(_ style: UIImpactFeedbackGenerator.FeedbackStyle) {
        let generator = UIImpactFeedbackGenerator(style: style)
        generator.prepare()
        generator.impactOccurred()
    }
}

// MARK: - Convenience Extensions
extension CelebrationManager {
    /// Konfetti för när övning läggs till
    func celebrateExerciseAdded() {
        celebrate(.small)
    }
    
    /// Konfetti för när gympass startas
    func celebrateSessionStarted() {
        celebrate(.medium)
    }
    
    /// Konfetti för när pass avslutas
    func celebrateSessionCompleted() {
        celebrate(.big)
    }
    
    /// Konfetti för milestones (3 Uppys, PR, etc)
    func celebrateMilestone() {
        celebrate(.milestone)
    }
}

// MARK: - Computed Properties for ConfettiCannon
extension CelebrationManager {
    var confettiCount: Int {
        celebrationType.confettiCount
    }
    
    var confettiSize: CGFloat {
        celebrationType.confettiSize
    }
    
    var radius: CGFloat {
        celebrationType.radius
    }
    
    var rainHeight: CGFloat {
        celebrationType.rainHeight
    }
    
    var repetitions: Int {
        celebrationType.repetitions
    }
    
    var repetitionInterval: Double {
        celebrationType.repetitionInterval
    }
    
    var confettiColors: [Color] {
        celebrationType.confettiColors
    }
}
