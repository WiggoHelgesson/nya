import SwiftUI

struct RecoveryZoneView: View {
    let userId: String
    @State private var needsRecovery: [MuscleRecoveryStatus] = []
    @State private var readyToTrain: [String] = []
    @State private var isLoading = true
    @State private var isExpanded = false
    @State private var overallStatus: (status: String, message: String) = ("Redo", "")
    
    private let service = RecoveryZoneService.shared
    
    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            // Header
            HStack {
                Text("Återhämtning")
                    .font(.system(size: 18, weight: .bold))
                    .foregroundColor(.white)
                
                Button {
                    withAnimation(.spring(response: 0.3, dampingFraction: 0.8)) {
                        isExpanded.toggle()
                    }
                } label: {
                    Image(systemName: "chevron.up")
                        .font(.system(size: 14, weight: .semibold))
                        .foregroundColor(.white.opacity(0.6))
                        .rotationEffect(.degrees(isExpanded ? 0 : 180))
                }
                
                Spacer()
                
                // Status badge
                HStack(spacing: 6) {
                    Circle()
                        .fill(statusColor)
                        .frame(width: 8, height: 8)
                    Text(overallStatus.status)
                        .font(.system(size: 14, weight: .medium))
                        .foregroundColor(statusColor)
                }
                .padding(.horizontal, 12)
                .padding(.vertical, 6)
                .background(statusColor.opacity(0.15))
                .clipShape(Capsule())
            }
            
            if isExpanded {
                if isLoading {
                    HStack {
                        Spacer()
                        ProgressView()
                            .tint(.white)
                        Spacer()
                    }
                    .padding(.vertical, 20)
                } else {
                    // Message card
                    HStack(spacing: 12) {
                        Image(systemName: "bolt.fill")
                            .font(.system(size: 20))
                            .foregroundColor(Color(red: 0.2, green: 0.8, blue: 0.4))
                        
                        Text(overallStatus.message)
                            .font(.system(size: 15, weight: .medium))
                            .foregroundColor(.white.opacity(0.9))
                    }
                    .padding(16)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .background(Color(red: 0.15, green: 0.3, blue: 0.2))
                    .cornerRadius(12)
                    
                    // Needs Recovery Section
                    if !needsRecovery.isEmpty {
                        VStack(alignment: .leading, spacing: 10) {
                            HStack(spacing: 8) {
                                Circle()
                                    .fill(Color.red.opacity(0.8))
                                    .frame(width: 10, height: 10)
                                Text("Behöver vila")
                                    .font(.system(size: 16, weight: .semibold))
                                    .foregroundColor(.white.opacity(0.9))
                            }
                            
                            RecoveryFlowLayout(spacing: 8) {
                                ForEach(needsRecovery) { status in
                                    RecoveryMuscleChip(
                                        name: status.muscleGroup,
                                        timeRemaining: status.timeRemainingText,
                                        isRecovered: false
                                    )
                                }
                            }
                        }
                    }
                    
                    // Ready to Train Section
                    if !readyToTrain.isEmpty {
                        VStack(alignment: .leading, spacing: 10) {
                            HStack(spacing: 8) {
                                Circle()
                                    .fill(Color(red: 0.2, green: 0.8, blue: 0.4))
                                    .frame(width: 10, height: 10)
                                Text("Redo att träna")
                                    .font(.system(size: 16, weight: .semibold))
                                    .foregroundColor(.white.opacity(0.9))
                            }
                            
                            RecoveryFlowLayout(spacing: 8) {
                                ForEach(readyToTrain, id: \.self) { muscle in
                                    RecoveryMuscleChip(
                                        name: muscle,
                                        timeRemaining: nil,
                                        isRecovered: true
                                    )
                                }
                            }
                        }
                    }
                }
            }
        }
        .padding(20)
        .background(
            RoundedRectangle(cornerRadius: 20)
                .fill(Color(red: 0.1, green: 0.15, blue: 0.12))
        )
        .task {
            await loadRecoveryData()
        }
        .onReceive(NotificationCenter.default.publisher(for: NSNotification.Name("GymWorkoutCompleted"))) { notification in
            // Refresh recovery data when a gym workout is completed
            print("🏋️ RecoveryZone: Received GymWorkoutCompleted notification!")
            Task {
                // Small delay to ensure database is updated
                try? await Task.sleep(nanoseconds: 500_000_000) // 0.5 seconds
                await loadRecoveryData(forceRefresh: true)
            }
        }
        .onReceive(NotificationCenter.default.publisher(for: NSNotification.Name("WorkoutSaved"))) { _ in
            // Also refresh when any workout is saved (backup listener)
            print("🏋️ RecoveryZone: Received WorkoutSaved notification!")
            Task {
                try? await Task.sleep(nanoseconds: 500_000_000)
                await loadRecoveryData(forceRefresh: true)
            }
        }
    }
    
    private var statusColor: Color {
        switch overallStatus.status {
        case "Redo":
            return Color(red: 0.2, green: 0.8, blue: 0.4)
        case "Nästan redo":
            return Color(red: 0.6, green: 0.8, blue: 0.3)
        case "Delvis vilad":
            return Color.orange
        default:
            return Color.red.opacity(0.8)
        }
    }
    
    private func loadRecoveryData(forceRefresh: Bool = false) async {
        do {
            let posts = try await WorkoutService.shared.getUserWorkoutPosts(userId: userId, forceRefresh: forceRefresh)
            let (needs, ready) = service.analyzeRecoveryStatus(from: posts)
            let status = service.getOverallStatus(
                needsRecoveryCount: needs.count,
                totalMuscles: service.allMuscleGroups.count
            )
            
            await MainActor.run {
                self.needsRecovery = needs
                self.readyToTrain = ready
                self.overallStatus = status
                self.isLoading = false
            }
        } catch {
            print("❌ Error loading recovery data: \(error)")
            await MainActor.run {
                self.isLoading = false
                // Show all as ready if we can't load data
                self.readyToTrain = service.allMuscleGroups
                self.overallStatus = ("Redo", "Kunde inte ladda träningshistorik.")
            }
        }
    }
}

// MARK: - Recovery Muscle Chip
struct RecoveryMuscleChip: View {
    let name: String
    let timeRemaining: String?
    let isRecovered: Bool
    
    var body: some View {
        HStack(spacing: 6) {
            Text(name)
                .font(.system(size: 14, weight: .medium))
                .foregroundColor(.white.opacity(0.9))
            
            if let time = timeRemaining {
                Text(time)
                    .font(.system(size: 12, weight: .regular))
                    .foregroundColor(.white.opacity(0.5))
            }
        }
        .padding(.horizontal, 14)
        .padding(.vertical, 10)
        .background(
            RoundedRectangle(cornerRadius: 20)
                .stroke(
                    isRecovered 
                        ? Color(red: 0.2, green: 0.5, blue: 0.3) 
                        : Color.red.opacity(0.4),
                    lineWidth: 1.5
                )
                .background(
                    RoundedRectangle(cornerRadius: 20)
                        .fill(
                            isRecovered 
                                ? Color(red: 0.15, green: 0.25, blue: 0.18) 
                                : Color.red.opacity(0.1)
                        )
                )
        )
    }
}

// MARK: - Recovery Flow Layout for flexible grid
struct RecoveryFlowLayout: Layout {
    var spacing: CGFloat = 8
    
    func sizeThatFits(proposal: ProposedViewSize, subviews: Subviews, cache: inout ()) -> CGSize {
        let result = calculateLayout(for: subviews, in: proposal.width ?? 0)
        return CGSize(width: proposal.width ?? 0, height: result.height)
    }
    
    func placeSubviews(in bounds: CGRect, proposal: ProposedViewSize, subviews: Subviews, cache: inout ()) {
        let layout = calculateLayout(for: subviews, in: bounds.width)
        
        for (index, position) in layout.positions.enumerated() {
            guard index < subviews.count else { break }
            subviews[index].place(
                at: CGPoint(x: bounds.minX + position.x, y: bounds.minY + position.y),
                proposal: ProposedViewSize(subviews[index].sizeThatFits(.unspecified))
            )
        }
    }
    
    private func calculateLayout(for subviews: Subviews, in width: CGFloat) -> (positions: [CGPoint], height: CGFloat) {
        var positions: [CGPoint] = []
        var currentX: CGFloat = 0
        var currentY: CGFloat = 0
        var rowHeight: CGFloat = 0
        
        for subview in subviews {
            let size = subview.sizeThatFits(.unspecified)
            
            if currentX + size.width > width && currentX > 0 {
                // Move to next row
                currentX = 0
                currentY += rowHeight + spacing
                rowHeight = 0
            }
            
            positions.append(CGPoint(x: currentX, y: currentY))
            currentX += size.width + spacing
            rowHeight = max(rowHeight, size.height)
        }
        
        return (positions, currentY + rowHeight)
    }
}

// MARK: - Compact Recovery Zone (for smaller spaces)
struct CompactRecoveryZoneView: View {
    let userId: String
    @State private var needsRecoveryCount: Int = 0
    @State private var readyCount: Int = 0
    @State private var overallStatus: String = "Redo"
    @State private var isLoading = true
    
    private let service = RecoveryZoneService.shared
    
    var body: some View {
        HStack(spacing: 16) {
            // Status indicator
            ZStack {
                Circle()
                    .fill(statusColor.opacity(0.2))
                    .frame(width: 50, height: 50)
                
                Image(systemName: "figure.strengthtraining.traditional")
                    .font(.system(size: 22, weight: .medium))
                    .foregroundColor(statusColor)
            }
            
            VStack(alignment: .leading, spacing: 4) {
                Text("Återhämtning")
                    .font(.system(size: 16, weight: .semibold))
                    .foregroundColor(.primary)
                
                if isLoading {
                    Text("Laddar...")
                        .font(.system(size: 13))
                        .foregroundColor(.secondary)
                } else {
                    Text("\(readyCount)/\(service.allMuscleGroups.count) muskelgrupper redo")
                        .font(.system(size: 13))
                        .foregroundColor(.secondary)
                }
            }
            
            Spacer()
            
            // Status badge
            Text(overallStatus)
                .font(.system(size: 12, weight: .semibold))
                .foregroundColor(statusColor)
                .padding(.horizontal, 10)
                .padding(.vertical, 5)
                .background(statusColor.opacity(0.15))
                .clipShape(Capsule())
        }
        .padding(16)
        .background(Color(.systemGray6))
        .cornerRadius(16)
        .task {
            await loadData()
        }
        .onReceive(NotificationCenter.default.publisher(for: NSNotification.Name("GymWorkoutCompleted"))) { _ in
            Task {
                await loadData(forceRefresh: true)
            }
        }
    }
    
    private var statusColor: Color {
        switch overallStatus {
        case "Redo":
            return .green
        case "Nästan redo":
            return Color(red: 0.6, green: 0.8, blue: 0.3)
        case "Delvis vilad":
            return .orange
        default:
            return .red
        }
    }
    
    private func loadData(forceRefresh: Bool = false) async {
        do {
            let posts = try await WorkoutService.shared.getUserWorkoutPosts(userId: userId, forceRefresh: forceRefresh)
            let (needs, ready) = service.analyzeRecoveryStatus(from: posts)
            let status = service.getOverallStatus(
                needsRecoveryCount: needs.count,
                totalMuscles: service.allMuscleGroups.count
            )
            
            await MainActor.run {
                self.needsRecoveryCount = needs.count
                self.readyCount = ready.count
                self.overallStatus = status.status
                self.isLoading = false
            }
        } catch {
            await MainActor.run {
                self.isLoading = false
                self.readyCount = service.allMuscleGroups.count
                self.overallStatus = "Redo"
            }
        }
    }
}

#Preview {
    VStack(spacing: 20) {
        RecoveryZoneView(userId: "test-user")
        CompactRecoveryZoneView(userId: "test-user")
    }
    .padding()
    .background(Color.black)
}

