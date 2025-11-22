import SwiftUI
import Combine

struct FriendsRaceView: View {
    @EnvironmentObject var authViewModel: AuthViewModel
    @Environment(\.dismiss) private var dismiss
    @StateObject private var viewModel = FriendsRaceViewModel()
    @State private var currentDate = Date()
    private let countdownTimer = Timer.publish(every: 60, on: .main, in: .common).autoconnect()
    private let countdownFormatter: DateComponentsFormatter = {
        let formatter = DateComponentsFormatter()
        formatter.allowedUnits = [.day, .hour, .minute]
        formatter.unitsStyle = .short
        formatter.maximumUnitCount = 2
        return formatter
    }()
    
    private var monthCountdown: String {
        let calendar = Calendar.current
        let now = currentDate
        guard let startOfMonth = calendar.date(from: calendar.dateComponents([.year, .month], from: now)),
              let startOfNextMonth = calendar.date(byAdding: DateComponents(month: 1), to: startOfMonth) else {
            return "--"
        }
        let remaining = max(0, startOfNextMonth.timeIntervalSince(now))
        guard remaining > 0 else { return "0 dagar" }
        if let formatted = countdownFormatter.string(from: remaining) {
            return formatted
        }
        return "0 dagar"
    }
    
    var body: some View {
        ZStack {
            Color.black
                .ignoresSafeArea()
            
            VStack(spacing: 24) {
                Text("Tävla mot dina vänner")
                    .font(.system(size: 28, weight: .black))
                    .foregroundColor(.white)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .padding(.horizontal, 24)
                    .padding(.top, 16)
                
                Text("Tid kvar denna månad: \(monthCountdown)")
                    .font(.system(size: 14, weight: .semibold))
                    .foregroundColor(.white.opacity(0.85))
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .padding(.horizontal, 24)
                
                if viewModel.isLoading {
                    Spacer()
                    ProgressView()
                        .progressViewStyle(.circular)
                        .tint(.white)
                    Spacer()
                } else if let errorMessage = viewModel.errorMessage {
                    Spacer()
                    Text(errorMessage)
                        .font(.system(size: 16, weight: .semibold))
                        .foregroundColor(.white.opacity(0.9))
                        .multilineTextAlignment(.center)
                        .padding(.horizontal, 32)
                    Spacer()
                } else if viewModel.participants.isEmpty {
                    Spacer()
                    Text("Bjud in vänner för att börja tävla!")
                        .font(.system(size: 18, weight: .semibold))
                        .foregroundColor(.white)
                    Spacer()
                } else {
                    GeometryReader { geometry in
                        ZStack {
                            TrackBackgroundView(laneCount: 6, finishProgress: viewModel.finishLineProgress, finishLabel: viewModel.finishLabel)
                            ForEach(Array(viewModel.participants.enumerated()), id: \.offset) { index, participant in
                                let progress = viewModel.progress(for: participant)
                                TrackRunnerView(participant: participant, index: index, laneCount: 6, progress: progress, geometry: geometry)
                            }
                        }
                    }
                    .frame(height: 320)
                    .padding(.horizontal, 24)
                    
                    ScrollView {
                        VStack(spacing: 12) {
                            ForEach(Array(viewModel.participants.enumerated()), id: \.offset) { index, participant in
                                HStack(spacing: 16) {
                                    Text("#\(index + 1)")
                                        .font(.system(size: 16, weight: .bold))
                                        .foregroundColor(.white.opacity(0.7))
                                        .frame(width: 32)
                                    AvatarView(url: participant.avatarUrl)
                                        .frame(width: 44, height: 44)
                                    VStack(alignment: .leading, spacing: 4) {
                                        Text(participant.name)
                                            .font(.system(size: 16, weight: .semibold))
                                            .foregroundColor(.white)
                                        Text(String(format: "%.1f km • %d steg", participant.distance, participant.steps))
                                            .font(.system(size: 13, weight: .medium))
                                            .foregroundColor(.white.opacity(0.7))
                                    }
                                    Spacer()
                                }
                                .padding(.horizontal, 24)
                            }
                        }
                        .padding(.bottom, 32)
                    }
                }
            }
        }
        .task {
            guard let currentUser = authViewModel.currentUser else { return }
            await viewModel.load(for: currentUser)
        }
        .onReceive(countdownTimer) { date in
            currentDate = date
        }
        .navigationBarTitleDisplayMode(.inline)
        .navigationBarBackButtonHidden(true)
        .toolbar {
            ToolbarItem(placement: .navigationBarLeading) {
                Button(action: { dismiss() }) {
                    HStack(spacing: 6) {
                        Image(systemName: "chevron.left")
                        Text("Tillbaka")
                    }
                    .font(.system(size: 16, weight: .semibold))
                    .foregroundColor(.white)
                }
            }
        }
    }
}

private struct TrackBackgroundView: View {
    let laneCount: Int
    let finishProgress: CGFloat
    let finishLabel: String
    
    var body: some View {
        GeometryReader { geometry in
            let size = geometry.size
            let trackWidth = size.width * 0.98
            let trackHeight = min(size.height * 0.92, trackWidth * 0.65)
            let origin = CGPoint(x: (size.width - trackWidth) / 2, y: (size.height - trackHeight) / 2)
            let trackRect = CGRect(origin: origin, size: CGSize(width: trackWidth, height: trackHeight))
            let maxInset = CGFloat(laneCount - 1) * laneSpacing(for: trackRect)
            
            ZStack {
                RoundedRectangle(cornerRadius: trackRect.height / 2)
                    .fill(Color.white.opacity(0.12))
                    .frame(width: trackRect.width, height: trackRect.height)
                    .position(x: trackRect.midX, y: trackRect.midY)
                
                ForEach(0..<laneCount, id: \.self) { lane in
                    let inset = CGFloat(lane) * laneSpacing(for: trackRect)
                    let laneRect = trackRect.insetBy(dx: inset, dy: inset)
                    if laneRect.height > 0 && laneRect.width > laneRect.height {
                        RoundedRectangle(cornerRadius: laneRect.height / 2)
                            .stroke(Color.white.opacity(0.5), lineWidth: lane == laneCount - 1 ? 2.5 : 1.5)
                            .frame(width: laneRect.width, height: laneRect.height)
                            .position(x: laneRect.midX, y: laneRect.midY)
                    }
                }
                
                // Start marker
                Capsule()
                    .fill(Color.white.opacity(0.35))
                    .frame(width: 10, height: trackRect.height * 0.7)
                    .position(x: trackRect.maxX - maxInset / 2, y: trackRect.midY)
                
                if finishProgress > 0 {
                    let clampedProgress = min(max(finishProgress, 0), 1)
                    let outerPoint = trackPoint(progress: clampedProgress, in: trackRect)
                    let innerInset = CGFloat(laneCount - 1) * laneSpacing(for: trackRect)
                    let innerRect = trackRect.insetBy(dx: innerInset, dy: innerInset)
                    if innerRect.width > 0 && innerRect.height > 0 {
                        let innerPoint = trackPoint(progress: clampedProgress, in: innerRect)
                        Path { path in
                            path.move(to: outerPoint)
                            path.addLine(to: innerPoint)
                        }
                        .stroke(Color.white, style: StrokeStyle(lineWidth: 6, lineCap: .round))
                        
                    let labelPoint = CGPoint(x: innerPoint.x - 14, y: innerPoint.y - 18)
                        VStack(spacing: 4) {
                            Text(finishLabel)
                                .font(.system(size: 11, weight: .bold))
                                .foregroundColor(.black)
                                .padding(.horizontal, 8)
                                .padding(.vertical, 4)
                                .background(Color.white)
                                .clipShape(Capsule())
                        }
                        .position(labelPoint)
                    }
                }
            }
        }
    }
    
    private func laneSpacing(for rect: CGRect) -> CGFloat {
        let count = CGFloat(laneCount)
        return max(min(rect.height / (count * 2.3), 28), 9)
    }
}

private struct TrackRunnerView: View {
    let participant: RaceParticipant
    let index: Int
    let laneCount: Int
    let progress: CGFloat
    let geometry: GeometryProxy
    
    var body: some View {
        let size = geometry.size
        let trackWidth = size.width * 0.98
        let trackHeight = min(size.height * 0.92, trackWidth * 0.65)
        let origin = CGPoint(x: (size.width - trackWidth) / 2, y: (size.height - trackHeight) / 2)
        let trackRect = CGRect(origin: origin, size: CGSize(width: trackWidth, height: trackHeight))
        let count = CGFloat(laneCount)
        let laneSpacing = max(min(trackRect.height / (count * 2.3), 28), 9)
        let laneIndex = min(index, laneCount - 1)
        let laneOffset = CGFloat(laneIndex) * laneSpacing + laneSpacing / 1.5
        let laneRect = trackRect.insetBy(dx: laneOffset,
                                         dy: laneOffset)
        let adjustedProgress = max(progress, 0.08)
        let point = trackPoint(progress: adjustedProgress, in: laneRect)
        
        VStack(spacing: 4) {
            AvatarView(url: participant.avatarUrl)
                .frame(width: 48, height: 48)
                .overlay(Circle().stroke(Color.white, lineWidth: 2.5))
            Text(String(format: "%.1f km", participant.distance))
                .font(.system(size: 12, weight: .bold))
                .foregroundColor(.white)
                .padding(.horizontal, 8)
                .padding(.vertical, 4)
                .background(Color.white.opacity(0.18))
                .clipShape(Capsule())
        }
        .position(point)
        .animation(.spring(response: 0.6, dampingFraction: 0.8), value: progress)
    }
    
}

private struct AvatarView: View {
    let url: String?
    
    var body: some View {
        Group {
            if let url, let imageURL = URL(string: url) {
                AsyncImage(url: imageURL) { phase in
                    switch phase {
                    case .success(let image):
                        image.resizable().scaledToFill()
                    case .failure(_):
                        placeholder
                    case .empty:
                        ProgressView().tint(.white)
                    @unknown default:
                        placeholder
                    }
                }
            } else {
                placeholder
            }
        }
        .clipShape(Circle())
        .background(Circle().fill(Color.white.opacity(0.2)))
    }
    
    private var placeholder: some View {
        Circle()
            .fill(Color.white.opacity(0.2))
            .overlay(
                Image(systemName: "person.fill")
                    .font(.system(size: 20))
                    .foregroundColor(.white.opacity(0.7))
            )
    }
}

struct RaceParticipant: Identifiable {
    let id: String
    let name: String
    let avatarUrl: String?
    let steps: Int
    let distance: Double
    
    var progressLabel: String {
        String(format: "%.1f km", distance)
    }
}

@MainActor
final class FriendsRaceViewModel: ObservableObject {
    @Published private(set) var participants: [RaceParticipant] = []
    @Published var isLoading = false
    @Published var errorMessage: String?
    
    private let finishDistance: Double = 100.0
    private let rewardPoints: Int = 50
    private let rewardDefaultsKeyPrefix = "friendsRaceFinishRewarded"
    
    func load(for user: User) async {
        guard !user.id.isEmpty else {
            self.errorMessage = "Kunde inte hitta din profil."
            return
        }
        isLoading = true
        errorMessage = nil
        
        await MonthlyStatsService.shared.syncCurrentUserMonthlySteps()
        
        do {
            let followingUsers = try await SocialService.shared.getFollowingUsers(userId: user.id)
            var profiles: [UserSearchResult] = [UserSearchResult(id: user.id, name: user.name, avatarUrl: user.avatarUrl)]
            profiles.append(contentsOf: followingUsers)
            let uniqueProfiles = Dictionary(grouping: profiles, by: { $0.id }).compactMap { $0.value.first }
            
            let participants: [RaceParticipant] = try await withThrowingTaskGroup(of: RaceParticipant.self) { group in
                for profile in uniqueProfiles {
                    group.addTask {
                        let steps = await MonthlyStatsService.shared.fetchMonthlySteps(for: profile.id)
                        let distance = StepSyncService.convertStepsToKilometers(steps)
                        return RaceParticipant(id: profile.id, name: profile.name, avatarUrl: profile.avatarUrl, steps: steps, distance: distance)
                    }
                }
                var results: [RaceParticipant] = []
                for try await participant in group {
                    results.append(participant)
                }
                return results
            }
            let sorted = participants.sorted { $0.distance > $1.distance }
            self.participants = sorted
            if self.participants.isEmpty {
                self.errorMessage = "Bjud in vänner för att se deras framsteg."
            }
            if let currentParticipant = sorted.first(where: { $0.id == user.id }) {
                maybeAwardFinishReward(for: currentParticipant.id, distance: currentParticipant.distance)
            }
        } catch {
            print("❌ FriendsRaceViewModel load error: \(error)")
            self.errorMessage = "Kunde inte ladda dina vänner just nu. Försök igen senare."
        }
        isLoading = false
    }
    
    func progress(for participant: RaceParticipant) -> CGFloat {
        guard finishDistance > 0 else { return 0 }
        let fraction = participant.distance / finishDistance
        return CGFloat(min(max(fraction, 0), 1))
    }
    
    var finishLineProgress: CGFloat {
        guard finishDistance > 0 else { return 1 }
        let physicalProgress = 100.0 / finishDistance
        let visuallyOffsetProgress = max(physicalProgress - 0.12, 0)
        return CGFloat(min(max(visuallyOffsetProgress, 0), 1))
    }
    
    var finishLabel: String {
        "Mållinje 100 km"
    }
    
    private func maybeAwardFinishReward(for userId: String, distance: Double) {
        guard distance >= finishDistance else { return }
        let monthKey = MonthlyStatsService.currentMonthKey()
        let defaultsKey = "\(rewardDefaultsKeyPrefix)-\(userId)-\(monthKey)"
        if UserDefaults.standard.bool(forKey: defaultsKey) {
            return
        }
        UserDefaults.standard.set(true, forKey: defaultsKey)
        Task {
            do {
                try await ProfileService.shared.updateUserPoints(userId: userId, pointsToAdd: rewardPoints)
                print("🏁 Awarded \(rewardPoints) points for finishing 100 km this month")
            } catch {
                print("❌ Failed to award finish reward: \(error)")
            }
        }
    }
}

private func trackPoint(progress: CGFloat, in rect: CGRect) -> CGPoint {
    let clampedProgress = min(max(progress, 0), 1)
    let radius = rect.height / 2
    let straight = max(rect.width - radius * 2, 0)
    let arcLength = CGFloat.pi * radius
    let total = straight * 2 + arcLength * 2
    var remaining = clampedProgress * total
    
    if remaining <= straight {
        let x = rect.maxX - radius - remaining
        let y = rect.maxY
        return CGPoint(x: x, y: y)
    }
    remaining -= straight
    
    if remaining <= arcLength {
        let fraction = remaining / arcLength
        let angle = CGFloat.pi / 2 + fraction * CGFloat.pi
        let center = CGPoint(x: rect.minX + radius, y: rect.midY)
        let x = center.x + cos(angle) * radius
        let y = center.y + sin(angle) * radius
        return CGPoint(x: x, y: y)
    }
    remaining -= arcLength
    
    if remaining <= straight {
        let x = rect.minX + radius + remaining
        let y = rect.minY
        return CGPoint(x: x, y: y)
    }
    remaining -= straight
    
    let fraction = min(max(remaining / arcLength, 0), 1)
    let angle = 3 * CGFloat.pi / 2 + fraction * CGFloat.pi
    let center = CGPoint(x: rect.maxX - radius, y: rect.midY)
    let x = center.x + cos(angle) * radius
    let y = center.y + sin(angle) * radius
    return CGPoint(x: x, y: y)
}

#Preview {
    FriendsRaceView()
        .environmentObject(AuthViewModel())
}

