import SwiftUI

struct WorkoutDetailView: View {
    let post: SocialWorkoutPost
    
    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 24) {
                SwipeableImageView(routeImage: post.imageUrl, userImage: post.userImageUrl)
                    .frame(maxWidth: .infinity)
                    .cornerRadius(16)
                    .shadow(radius: 6)
                
                overviewSection
                splitsSection
            }
            .padding(20)
        }
        .navigationTitle(post.title)
        .navigationBarTitleDisplayMode(.inline)
        .background(Color(.systemGroupedBackground).ignoresSafeArea())
        .onAppear { NavigationDepthTracker.shared.setAtRoot(false) }
        .onDisappear { NavigationDepthTracker.shared.setAtRoot(true) }
    }
    
    private var overviewSection: some View {
        VStack(alignment: .leading, spacing: 16) {
            HStack {
                statBlock(title: "Distans", value: formattedDistance)
                Divider()
                statBlock(title: "Tid", value: formattedDuration)
            }
            .frame(maxWidth: .infinity)
            .padding()
            .background(Color.white)
            .cornerRadius(12)
            .shadow(color: Color.black.opacity(0.05), radius: 6, x: 0, y: 3)
        }
    }
    
    private var splitsSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Kilometersplittar")
                .font(.system(size: 20, weight: .bold))
                .foregroundColor(.black)
            
            if let splits = post.splits, !splits.isEmpty {
                VStack(spacing: 12) {
                    ForEach(splits) { split in
                        HStack {
                            VStack(alignment: .leading) {
                                Text("Km \(split.kilometerIndex)")
                                    .font(.system(size: 16, weight: .semibold))
                                Text(distanceString(for: split))
                                    .font(.system(size: 13))
                                    .foregroundColor(.gray)
                            }
                            Spacer()
                            VStack(alignment: .trailing) {
                                Text(paceString(for: split))
                                    .font(.system(size: 16, weight: .semibold))
                                Text(durationString(for: split))
                                    .font(.system(size: 13))
                                    .foregroundColor(.gray)
                            }
                        }
                        .padding(16)
                        .background(Color.white)
                        .cornerRadius(10)
                        .shadow(color: Color.black.opacity(0.03), radius: 4, x: 0, y: 2)
                    }
                }
            } else {
                Text("Inga splits tillgängliga för detta pass.")
                    .font(.system(size: 15))
                    .foregroundColor(.gray)
                    .padding()
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .background(Color.white)
                    .cornerRadius(10)
                    .shadow(color: Color.black.opacity(0.03), radius: 4, x: 0, y: 2)
            }
        }
    }
    
    private func statBlock(title: String, value: String) -> some View {
        VStack(alignment: .leading, spacing: 6) {
            Text(title.uppercased())
                .font(.system(size: 12, weight: .semibold))
                .foregroundColor(.gray)
            Text(value)
                .font(.system(size: 22, weight: .bold))
                .foregroundColor(.black)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }
    
    private var formattedDistance: String {
        if let distance = post.distance {
            return String(format: "%.2f km", distance)
        }
        return "-"
    }
    
    private var formattedDuration: String {
        guard let duration = post.duration else { return "-" }
        let hours = duration / 3600
        let minutes = (duration % 3600) / 60
        let seconds = duration % 60
        if hours > 0 {
            return String(format: "%d:%02d:%02d", hours, minutes, seconds)
        } else {
            return String(format: "%02d:%02d", minutes, seconds)
        }
    }
    
    private func paceString(for split: WorkoutSplit) -> String {
        let pace = max(split.paceSecondsPerKm, 0)
        let minutes = Int(pace) / 60
        let seconds = Int(pace) % 60
        return String(format: "%d:%02d /km", minutes, seconds)
    }
    
    private func durationString(for split: WorkoutSplit) -> String {
        let totalSeconds = max(split.durationSeconds, 0)
        let minutes = Int(totalSeconds) / 60
        let seconds = Int(totalSeconds) % 60
        if split.durationSeconds >= 3600 {
            let hours = Int(totalSeconds) / 3600
            return String(format: "%d:%02d:%02d", hours, minutes % 60, seconds)
        }
        return String(format: "%d:%02d", minutes, seconds)
    }
    
    private func distanceString(for split: WorkoutSplit) -> String {
        if abs(split.distanceKm - 1.0) < 0.01 {
            return "1.00 km"
        }
        return String(format: "%.2f km", split.distanceKm)
    }
}



