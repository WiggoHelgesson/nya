import SwiftUI

// MARK: - Spectate Workout View
// View for watching a friend's workout in real-time

struct SpectateWorkoutView: View {
    let session: ActiveFriendSession
    @EnvironmentObject var authViewModel: AuthViewModel
    @Environment(\.dismiss) private var dismiss
    
    @StateObject private var realtimeService = RealtimeWorkoutService.shared
    @State private var showCheerSheet = false
    @State private var sentCheerEmoji: String?
    @State private var showCheerAnimation = false
    
    private let cheerEmojis = ["💪", "🔥", "⚡️", "🏆", "👏", "💯", "🎯", "🚀"]
    
    var body: some View {
        NavigationStack {
            ZStack {
                Color(.systemBackground)
                    .ignoresSafeArea()
                
                VStack(spacing: 0) {
                    // Header with user info
                    headerSection
                    
                    // Live indicator
                    liveIndicator
                    
                    // Exercises list
                    if realtimeService.spectatedExercises.isEmpty {
                        emptyStateView
                    } else {
                        exercisesList
                    }
                    
                    Spacer()
                    
                    // Cheer button
                    cheerButton
                }
                
                // Cheer animation overlay
                if showCheerAnimation, let emoji = sentCheerEmoji {
                    cheerAnimationOverlay(emoji: emoji)
                }
            }
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarLeading) {
                    Button {
                        stopSpectating()
                        dismiss()
                    } label: {
                        Image(systemName: "xmark")
                            .font(.system(size: 16, weight: .semibold))
                            .foregroundColor(.primary)
                    }
                }
            }
            .sheet(isPresented: $showCheerSheet) {
                cheerSelectionSheet
            }
        }
        .task {
            await startSpectating()
        }
        .onDisappear {
            stopSpectating()
        }
    }
    
    // MARK: - Header Section
    
    private var headerSection: some View {
        HStack(spacing: 16) {
            // Profile image
            ProfileImage(url: session.avatarUrl, size: 56)
                .overlay(
                    Circle()
                        .stroke(Color.green, lineWidth: 3)
                )
            
            VStack(alignment: .leading, spacing: 4) {
                Text(session.userName)
                    .font(.system(size: 20, weight: .bold))
                    .foregroundColor(.primary)
                
                HStack(spacing: 6) {
                    Image(systemName: "clock")
                        .font(.system(size: 12))
                    Text(session.formattedDuration)
                        .font(.system(size: 14, weight: .medium))
                }
                .foregroundColor(.secondary)
            }
            
            Spacer()
        }
        .padding(.horizontal, 20)
        .padding(.vertical, 16)
        .background(Color(.secondarySystemBackground))
    }
    
    // MARK: - Live Indicator
    
    private var liveIndicator: some View {
        HStack(spacing: 8) {
            Circle()
                .fill(Color.red)
                .frame(width: 8, height: 8)
                .overlay(
                    Circle()
                        .stroke(Color.red.opacity(0.5), lineWidth: 4)
                        .scaleEffect(1.5)
                )
            
            Text("LIVE")
                .font(.system(size: 12, weight: .bold))
                .foregroundColor(.red)
            
            Text("•")
                .foregroundColor(.gray)
            
            Text("\(realtimeService.spectatedExercises.count) övningar")
                .font(.system(size: 12, weight: .medium))
                .foregroundColor(.gray)
        }
        .padding(.vertical, 12)
    }
    
    // MARK: - Empty State
    
    private var emptyStateView: some View {
        VStack(spacing: 16) {
            Spacer()
            
            Image(systemName: "figure.strengthtraining.traditional")
                .font(.system(size: 60))
                .foregroundColor(.gray.opacity(0.5))
            
            Text("Väntar på övningar...")
                .font(.system(size: 18, weight: .semibold))
                .foregroundColor(.secondary)
            
            Text("\(session.userName) har inte lagt till några övningar än")
                .font(.system(size: 14))
                .foregroundColor(.gray)
                .multilineTextAlignment(.center)
                .padding(.horizontal, 40)
            
            Spacer()
        }
    }
    
    // MARK: - Exercises List
    
    private var exercisesList: some View {
        ScrollView {
            LazyVStack(spacing: 12) {
                ForEach(realtimeService.spectatedExercises) { exercise in
                    SpectateExerciseCard(exercise: exercise)
                }
            }
            .padding(.horizontal, 16)
            .padding(.vertical, 12)
        }
    }
    
    // MARK: - Cheer Button
    
    private var cheerButton: some View {
        Button {
            showCheerSheet = true
        } label: {
            HStack(spacing: 10) {
                Text("💪")
                    .font(.system(size: 24))
                Text("Heja på!")
                    .font(.system(size: 17, weight: .semibold))
            }
            .foregroundColor(.white)
            .frame(maxWidth: .infinity)
            .padding(.vertical, 16)
            .background(
                LinearGradient(
                    colors: [Color.orange, Color.red],
                    startPoint: .leading,
                    endPoint: .trailing
                )
            )
            .cornerRadius(16)
        }
        .padding(.horizontal, 20)
        .padding(.bottom, 30)
    }
    
    // MARK: - Cheer Selection Sheet
    
    private var cheerSelectionSheet: some View {
        NavigationStack {
            VStack(spacing: 24) {
                Text("Välj en emoji för att heja!")
                    .font(.system(size: 18, weight: .semibold))
                    .padding(.top, 20)
                
                LazyVGrid(columns: Array(repeating: GridItem(.flexible()), count: 4), spacing: 20) {
                    ForEach(cheerEmojis, id: \.self) { emoji in
                        Button {
                            sendCheer(emoji: emoji)
                        } label: {
                            Text(emoji)
                                .font(.system(size: 48))
                                .frame(width: 70, height: 70)
                                .background(Color(.systemGray6))
                                .cornerRadius(16)
                        }
                        .buttonStyle(.plain)
                    }
                }
                .padding(.horizontal, 20)
                
                Spacer()
            }
            .navigationTitle("Heja på")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button("Stäng") {
                        showCheerSheet = false
                    }
                }
            }
        }
        .presentationDetents([.medium])
    }
    
    // MARK: - Cheer Animation Overlay
    
    private func cheerAnimationOverlay(emoji: String) -> some View {
        ZStack {
            Color.black.opacity(0.3)
                .ignoresSafeArea()
            
            Text(emoji)
                .font(.system(size: 120))
                .scaleEffect(showCheerAnimation ? 1.2 : 0.5)
                .opacity(showCheerAnimation ? 1 : 0)
                .animation(.spring(response: 0.4, dampingFraction: 0.6), value: showCheerAnimation)
        }
        .allowsHitTesting(false)
    }
    
    // MARK: - Actions
    
    private func startSpectating() async {
        guard let spectatorId = authViewModel.currentUser?.id else { return }
        await realtimeService.startSpectating(sessionId: session.id, spectatorId: spectatorId)
    }
    
    private func stopSpectating() {
        guard let spectatorId = authViewModel.currentUser?.id else { return }
        Task {
            await realtimeService.stopSpectating(spectatorId: spectatorId)
        }
    }
    
    private func sendCheer(emoji: String) {
        showCheerSheet = false
        
        guard let fromUserId = authViewModel.currentUser?.id else { return }
        
        Task {
            let success = await realtimeService.sendCheer(
                sessionId: session.id,
                fromUserId: fromUserId,
                toUserId: session.userId,
                emoji: emoji
            )
            
            if success {
                await MainActor.run {
                    sentCheerEmoji = emoji
                    showCheerAnimation = true
                    
                    // Haptic feedback
                    let generator = UIImpactFeedbackGenerator(style: .heavy)
                    generator.impactOccurred()
                    
                    // Hide animation after delay
                    DispatchQueue.main.asyncAfter(deadline: .now() + 1.5) {
                        showCheerAnimation = false
                        sentCheerEmoji = nil
                    }
                }
            }
        }
    }
}

// MARK: - Spectate Exercise Card

struct SpectateExerciseCard: View {
    let exercise: SpectateExercise
    
    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            // Exercise name and muscle group
            HStack {
                VStack(alignment: .leading, spacing: 4) {
                    Text(exercise.name)
                        .font(.system(size: 17, weight: .semibold))
                        .foregroundColor(.primary)
                    
                    if let muscleGroup = exercise.muscleGroup, !muscleGroup.isEmpty {
                        Text(muscleGroup)
                            .font(.system(size: 13))
                            .foregroundColor(.secondary)
                    }
                }
                
                Spacer()
                
                // Sets count badge
                Text("\(exercise.sets.count) sets")
                    .font(.system(size: 12, weight: .semibold))
                    .foregroundColor(.white)
                    .padding(.horizontal, 10)
                    .padding(.vertical, 5)
                    .background(Color.blue)
                    .cornerRadius(12)
            }
            
            // Sets grid
            if !exercise.sets.isEmpty {
                VStack(spacing: 6) {
                    // Header
                    HStack {
                        Text("SET")
                            .frame(width: 40)
                        Text("KG")
                            .frame(width: 60)
                        Text("REPS")
                            .frame(width: 60)
                        Spacer()
                    }
                    .font(.system(size: 11, weight: .semibold))
                    .foregroundColor(.gray)
                    
                    // Sets
                    ForEach(Array(exercise.sets.enumerated()), id: \.offset) { index, set in
                        HStack {
                            Text("\(index + 1)")
                                .frame(width: 40)
                                .foregroundColor(.secondary)
                            
                            Text(set.kg > 0 ? String(format: "%.1f", set.kg) : "-")
                                .frame(width: 60)
                                .foregroundColor(.primary)
                            
                            Text(set.reps > 0 ? "\(set.reps)" : "-")
                                .frame(width: 60)
                                .foregroundColor(.primary)
                            
                            Spacer()
                            
                            // Completion indicator
                            if set.isCompleted {
                                Image(systemName: "checkmark.circle.fill")
                                    .foregroundColor(.green)
                                    .font(.system(size: 18))
                            } else {
                                Circle()
                                    .stroke(Color.gray.opacity(0.3), lineWidth: 2)
                                    .frame(width: 18, height: 18)
                            }
                        }
                        .font(.system(size: 15, weight: .medium))
                        .padding(.vertical, 6)
                        .padding(.horizontal, 8)
                        .background(
                            RoundedRectangle(cornerRadius: 8)
                                .fill(set.isCompleted ? Color.green.opacity(0.1) : Color(.systemGray6))
                        )
                    }
                }
            }
        }
        .padding(16)
        .background(Color(.secondarySystemBackground))
        .cornerRadius(16)
    }
}

#Preview {
    SpectateWorkoutView(
        session: ActiveFriendSession(
            id: "1",
            oderId: "user1",
            userName: "TestUser",
            avatarUrl: nil,
            activityType: "gym",
            startedAt: Date().addingTimeInterval(-1800),
            latitude: nil,
            longitude: nil
        )
    )
    .environmentObject(AuthViewModel())
}
