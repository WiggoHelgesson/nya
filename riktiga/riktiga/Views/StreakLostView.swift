//
//  StreakLostView.swift
//  Up&Down
//
//  Created by Cursor on 2026-01-30.
//

import SwiftUI

struct StreakLostView: View {
    let lostStreakDays: Int
    let onContinue: () -> Void
    
    @State private var animateFlame = false
    @State private var animateText = false
    @State private var animateWeekdays = false
    @State private var animateButton = false
    
    // Get completed days this week from StreakManager
    private var completedWeekdays: [Int] {
        StreakManager.shared.getCurrentStreak().completedDaysThisWeek
    }
    
    // Current day of week (1 = Sunday, 2 = Monday, etc.)
    private var currentWeekday: Int {
        Calendar.current.component(.weekday, from: Date())
    }
    
    var body: some View {
        ZStack {
            // Dimmed background
            Color.black.opacity(0.4)
                .ignoresSafeArea()
                .onTapGesture { }
            
            // Modal card
            VStack(spacing: 0) {
                // Header with logo and streak count
                HStack {
                    // App logo and name
                    HStack(spacing: 8) {
                        Image("23")
                            .resizable()
                            .scaledToFit()
                            .frame(width: 24, height: 24)
                            .clipShape(Circle())
                        
                        Text("Up & Down")
                            .font(.system(size: 15, weight: .semibold))
                            .foregroundColor(.primary)
                    }
                    
                    Spacer()
                    
                    // Streak badge (showing 0 since lost)
                    HStack(spacing: 4) {
                        Image(systemName: "flame.fill")
                            .font(.system(size: 14))
                            .foregroundColor(.gray)
                        
                        Text("0")
                            .font(.system(size: 15, weight: .semibold))
                            .foregroundColor(.primary)
                    }
                    .padding(.horizontal, 12)
                    .padding(.vertical, 6)
                    .background(
                        Capsule()
                            .fill(Color(.systemGray6))
                    )
                }
                .padding(.horizontal, 24)
                .padding(.top, 24)
                
                Spacer().frame(height: 40)
                
                // Gray flame icon
                Image(systemName: "flame.fill")
                    .font(.system(size: 80))
                    .foregroundColor(Color(.systemGray4))
                    .scaleEffect(animateFlame ? 1.0 : 0.5)
                    .opacity(animateFlame ? 1.0 : 0)
                
                Spacer().frame(height: 32)
                
                // Dynamic streak lost message
                Text(streakLostTitle)
                    .font(.system(size: 28, weight: .bold))
                    .foregroundColor(.primary)
                    .multilineTextAlignment(.center)
                    .opacity(animateText ? 1.0 : 0)
                    .offset(y: animateText ? 0 : 20)
                
                Spacer().frame(height: 24)
                
                // Week day indicators
                HStack(spacing: 16) {
                    ForEach(weekdayData, id: \.letter) { day in
                        VStack(spacing: 8) {
                            Text(day.letter)
                                .font(.system(size: 14, weight: .medium))
                                .foregroundColor(day.isToday ? .orange : .secondary)
                            
                            Circle()
                                .fill(day.isCompleted ? Color.primary : Color(.systemGray5))
                                .frame(width: 28, height: 28)
                        }
                        .opacity(animateWeekdays ? 1.0 : 0)
                        .offset(y: animateWeekdays ? 0 : 10)
                    }
                }
                .padding(.horizontal, 24)
                
                Spacer().frame(height: 24)
                
                // Motivational message
                Text(motivationalMessage)
                    .font(.system(size: 15))
                    .foregroundColor(.secondary)
                    .multilineTextAlignment(.center)
                    .padding(.horizontal, 32)
                    .opacity(animateText ? 1.0 : 0)
                
                Spacer().frame(height: 32)
                
                // Continue button
                Button {
                    // Clear the lost streak flag and dismiss
                    StreakManager.shared.clearLostStreakFlag()
                    onContinue()
                } label: {
                    Text("Fortsätt")
                        .font(.system(size: 17, weight: .semibold))
                        .foregroundColor(.primary)
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 16)
                        .background(
                            RoundedRectangle(cornerRadius: 30)
                                .stroke(Color.primary, lineWidth: 2)
                        )
                }
                .padding(.horizontal, 24)
                .opacity(animateButton ? 1.0 : 0)
                .offset(y: animateButton ? 0 : 20)
                
                Spacer().frame(height: 24)
            }
            .background(
                RoundedRectangle(cornerRadius: 32)
                    .fill(Color(.systemBackground))
            )
            .padding(.horizontal, 24)
            .padding(.vertical, 60)
        }
        .onAppear {
            startAnimations()
        }
    }
    
    // MARK: - Dynamic Content
    
    private var streakLostTitle: String {
        if lostStreakDays == 1 {
            return "1 dag streak förlorad"
        } else {
            return "\(lostStreakDays) dagars streak förlorad"
        }
    }
    
    private var motivationalMessage: String {
        if lostStreakDays >= 30 {
            return "Imponerande streak! Men ge inte upp. Logga ett pass idag för att börja om."
        } else if lostStreakDays >= 14 {
            return "Du hade en bra streak! Börja om och slå ditt rekord."
        } else if lostStreakDays >= 7 {
            return "En vecka är en bra start. Låt oss göra det ännu bättre!"
        } else {
            return "Ge inte upp. Logga ett pass idag för att komma tillbaka på banan!"
        }
    }
    
    // Weekday data for the indicator row
    private var weekdayData: [WeekdayItem] {
        // Swedish weekday letters starting from Monday
        let letters = ["M", "T", "O", "T", "F", "L", "S"]
        // Map from our index (0=Monday) to Calendar weekday (2=Monday, 3=Tuesday, etc. 1=Sunday)
        let calendarWeekdays = [2, 3, 4, 5, 6, 7, 1] // Mon, Tue, Wed, Thu, Fri, Sat, Sun
        
        return letters.enumerated().map { index, letter in
            let calWeekday = calendarWeekdays[index]
            return WeekdayItem(
                letter: letter,
                isCompleted: completedWeekdays.contains(calWeekday),
                isToday: calWeekday == currentWeekday
            )
        }
    }
    
    private struct WeekdayItem {
        let letter: String
        let isCompleted: Bool
        let isToday: Bool
    }
    
    // MARK: - Animations
    
    private func startAnimations() {
        withAnimation(.spring(response: 0.6, dampingFraction: 0.7).delay(0.1)) {
            animateFlame = true
        }
        
        withAnimation(.easeOut(duration: 0.5).delay(0.3)) {
            animateText = true
        }
        
        withAnimation(.easeOut(duration: 0.4).delay(0.5)) {
            animateWeekdays = true
        }
        
        withAnimation(.easeOut(duration: 0.4).delay(0.7)) {
            animateButton = true
        }
    }
}

// MARK: - Preview

#Preview {
    StreakLostView(lostStreakDays: 7) {
        print("Continue tapped")
    }
}
