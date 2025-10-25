import SwiftUI
import Combine

struct ActivitiesView: View {
    @StateObject private var workoutPosts: WorkoutPostsViewModel = WorkoutPostsViewModel()
    @EnvironmentObject var authViewModel: AuthViewModel
    
    // Alla belöningar i önskad ordning (PUMPLABS först, ZEN ENERGY som andra)
    let allRewards = [
        RewardCard(
            id: 1,
            brandName: "PUMPLABS",
            discount: "10% rabatt",
            points: "200 poäng",
            imageName: "12",
            category: "Gym",
            isBookmarked: false
        ),
        RewardCard(
            id: 2,
            brandName: "ZEN ENERGY",
            discount: "10% rabatt",
            points: "200 poäng",
            imageName: "13",
            category: "Gym",
            isBookmarked: false
        ),
        RewardCard(
            id: 3,
            brandName: "PLIKTGOLF",
            discount: "10% rabatt",
            points: "200 poäng",
            imageName: "4",
            category: "Golf",
            isBookmarked: false
        ),
        RewardCard(
            id: 4,
            brandName: "PEGMATE",
            discount: "5% rabatt",
            points: "200 poäng",
            imageName: "5",
            category: "Golf",
            isBookmarked: false
        ),
        RewardCard(
            id: 5,
            brandName: "LONEGOLF",
            discount: "10% rabatt",
            points: "200 poäng",
            imageName: "6",
            category: "Golf",
            isBookmarked: false
        ),
        RewardCard(
            id: 6,
            brandName: "WINWIZE",
            discount: "25% rabatt",
            points: "200 poäng",
            imageName: "7",
            category: "Golf",
            isBookmarked: false
        ),
        RewardCard(
            id: 7,
            brandName: "SCANDIGOLF",
            discount: "15% rabatt",
            points: "200 poäng",
            imageName: "8",
            category: "Golf",
            isBookmarked: false
        ),
        RewardCard(
            id: 8,
            brandName: "Exotic Golf",
            discount: "10% rabatt",
            points: "200 poäng",
            imageName: "9",
            category: "Golf",
            isBookmarked: false
        ),
        RewardCard(
            id: 9,
            brandName: "HAPPYALBA",
            discount: "10% rabatt",
            points: "200 poäng",
            imageName: "10",
            category: "Golf",
            isBookmarked: false
        ),
        RewardCard(
            id: 10,
            brandName: "RETROGOLF",
            discount: "10% rabatt",
            points: "200 poäng",
            imageName: "11",
            category: "Golf",
            isBookmarked: false
        )
    ]
    
    var body: some View {
        NavigationStack {
            ZStack {
                Color(.systemBackground).ignoresSafeArea()
                
                if workoutPosts.posts.isEmpty {
                    VStack(spacing: 16) {
                        Image(systemName: "figure.run")
                            .font(.system(size: 48))
                            .foregroundColor(.gray)
                        Text("Inga träningspass än")
                            .font(.headline)
                        Text("Starta ett pass för att se det här")
                            .font(.caption)
                            .foregroundColor(.gray)
                    }
                } else {
                    ScrollView {
                        VStack(spacing: 24) {
                            // MARK: - Alla belöningar sliderbar
                            VStack(alignment: .leading, spacing: 12) {
                                Text("Alla belöningar")
                                    .font(.headline)
                                    .foregroundColor(.black)
                                    .padding(.horizontal, 16)
                                
                                ScrollView(.horizontal, showsIndicators: false) {
                                    HStack(spacing: 12) {
                                        ForEach(allRewards, id: \.id) { reward in
                                            AllRewardsCard(reward: reward)
                                        }
                                    }
                                    .padding(.horizontal, 16)
                                }
                            }
                            
                            // MARK: - Aktiviteter
                            VStack(spacing: 16) {
                                ForEach(workoutPosts.posts) { post in
                                    WorkoutPostCard(post: post)
                                }
                            }
                            .padding(.horizontal, 16)
                        }
                        .padding(.vertical, 16)
                    }
                }
            }
            .navigationTitle("Aktiviteter")
            .navigationBarTitleDisplayMode(.inline)
            .onAppear {
                if let userId = authViewModel.currentUser?.id {
                    workoutPosts.fetchUserPosts(userId: userId)
                }
            }
            .refreshable {
                if let userId = authViewModel.currentUser?.id {
                    await workoutPosts.refreshUserPosts(userId: userId)
                }
            }
        }
    }
}

struct WorkoutPostCard: View {
    let post: WorkoutPost
    
    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            // Header with activity icon, title and date
            HStack {
                Image(systemName: getActivityIcon(post.activityType))
                    .font(.system(size: 20))
                    .foregroundColor(AppColors.brandBlue)
                
                VStack(alignment: .leading, spacing: 2) {
                    Text(post.title)
                        .font(.headline)
                        .foregroundColor(.black)
                    Text(post.activityType)
                        .font(.caption)
                        .foregroundColor(.gray)
                }
                
                Spacer()
                
                Text(formatDate(post.createdAt))
                    .font(.caption)
                    .foregroundColor(.gray)
            }
            
            // Stats row (distance, time)
            HStack(spacing: 20) {
                if let distance = post.distance {
                    HStack(spacing: 4) {
                        Image(systemName: "location.fill")
                            .font(.caption)
                            .foregroundColor(AppColors.brandGreen)
                        Text(String(format: "%.2f km", distance))
                            .font(.caption)
                            .foregroundColor(.black)
                    }
                }
                
                if let duration = post.duration {
                    HStack(spacing: 4) {
                        Image(systemName: "clock.fill")
                            .font(.caption)
                            .foregroundColor(AppColors.brandBlue)
                        Text(formatDuration(duration))
                            .font(.caption)
                            .foregroundColor(.black)
                    }
                }
                
                Spacer()
            }
            
            // Description
            if let description = post.description, !description.isEmpty {
                Text(description)
                    .font(.caption)
                    .lineLimit(3)
                    .foregroundColor(.gray)
            }
            
            // Image if available
            if let imageUrl = post.imageUrl, !imageUrl.isEmpty {
                GeometryReader { geometry in
                    OptimizedAsyncImage(
                        url: imageUrl,
                        width: geometry.size.width,
                        height: 150,
                        cornerRadius: 8
                    )
                }
                .frame(height: 150)
            }
        }
        .padding(16)
        .background(Color.white)
        .cornerRadius(12)
        .shadow(color: Color.black.opacity(0.1), radius: 2, x: 0, y: 1)
    }
    
    func getActivityIcon(_ activity: String) -> String {
        switch activity {
        case "Löppass":
            return "figure.run"
        case "Golfrunda":
            return "flag.fill"
        case "Promenad":
            return "figure.walk"
        case "Bestiga berg":
            return "mountain.2.fill"
        default:
            return "figure.walk"
        }
    }
    
    func formatDate(_ dateString: String) -> String {
        let formatter = ISO8601DateFormatter()
        if let date = formatter.date(from: dateString) {
            let calendar = Calendar.current
            if calendar.isDateInToday(date) {
                let timeFormatter = DateFormatter()
                timeFormatter.timeStyle = .short
                return timeFormatter.string(from: date)
            }
            let dateFormatter = DateFormatter()
            dateFormatter.dateStyle = .short
            return dateFormatter.string(from: date)
        }
        return dateString
    }
    
    func formatDuration(_ seconds: Int) -> String {
        let hours = seconds / 3600
        let minutes = (seconds % 3600) / 60
        let secs = seconds % 60
        if hours > 0 {
            return String(format: "%d:%02d:%02d", hours, minutes, secs)
        } else {
            return String(format: "%02d:%02d", minutes, secs)
        }
    }
}

class WorkoutPostsViewModel: ObservableObject {
    @Published var posts: [WorkoutPost] = []
    
    func fetchUserPosts(userId: String) {
        Task {
            do {
                let fetchedPosts = try await WorkoutService.shared.fetchUserWorkoutPosts(userId: userId)
                DispatchQueue.main.async {
                    self.posts = fetchedPosts
                }
            } catch {
                print("Error fetching user posts: \(error)")
            }
        }
    }
    
    func refreshUserPosts(userId: String) async {
        do {
            let fetchedPosts = try await WorkoutService.shared.fetchUserWorkoutPosts(userId: userId)
            DispatchQueue.main.async {
                self.posts = fetchedPosts
            }
        } catch {
            print("Error refreshing user posts: \(error)")
        }
    }
}

struct AllRewardsCard: View {
    let reward: RewardCard
    
    var body: some View {
        VStack(spacing: 8) {
            // Brand logo
            Image(getBrandLogo(for: reward.imageName))
                .resizable()
                .scaledToFit()
                .frame(width: 30, height: 30)
                .clipShape(Circle())
            
            VStack(spacing: 2) {
                Text(reward.discount)
                    .font(.system(size: 12, weight: .bold))
                    .foregroundColor(.black)
                    .multilineTextAlignment(.center)
                
                Text(reward.brandName)
                    .font(.system(size: 10, weight: .medium))
                    .foregroundColor(.gray)
                    .multilineTextAlignment(.center)
                    .lineLimit(2)
            }
        }
        .frame(width: 80, height: 80)
        .padding(8)
        .background(Color.white)
        .cornerRadius(12)
        .shadow(color: Color.black.opacity(0.1), radius: 2, x: 0, y: 1)
    }
    
    private func getBrandLogo(for imageName: String) -> String {
        switch imageName {
        case "4": return "15" // PLIKTGOLF
        case "5": return "5"  // PEGMATE
        case "6": return "14" // LONEGOLF
        case "7": return "17" // WINWIZE
        case "8": return "18" // SCANDIGOLF
        case "9": return "19" // Exotic Golf
        case "10": return "16" // HAPPYALBA (Alba)
        case "11": return "20" // RETROGOLF
        case "12": return "21" // PUMPLABS
        case "13": return "22" // ZEN ENERGY
        default: return "5" // Default to PEGMATE
        }
    }
}

#Preview {
    ActivitiesView()
        .environmentObject(AuthViewModel())
}
