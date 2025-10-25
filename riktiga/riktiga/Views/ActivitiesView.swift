import SwiftUI
import Combine

struct ActivitiesView: View {
    @StateObject private var workoutPosts: WorkoutPostsViewModel = WorkoutPostsViewModel()
    @EnvironmentObject var authViewModel: AuthViewModel
    
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
                        VStack(spacing: 16) {
                            ForEach(workoutPosts.posts) { post in
                                WorkoutPostCard(post: post)
                            }
                        }
                        .padding(16)
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

#Preview {
    ActivitiesView()
        .environmentObject(AuthViewModel())
}
