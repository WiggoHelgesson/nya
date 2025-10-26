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
        VStack(alignment: .leading, spacing: 0) {
            // Large image
            if let imageUrl = post.imageUrl, !imageUrl.isEmpty {
                LocalAsyncImage(path: imageUrl)
            }
            
            // Content below image
            VStack(alignment: .leading, spacing: 12) {
                // Title
                Text(post.title)
                    .font(.system(size: 17, weight: .semibold))
                    .foregroundColor(.black)
                    .padding(.horizontal, 16)
                    .padding(.top, 12)
                
                // Stats row with white background
                HStack(spacing: 0) {
                    if let distance = post.distance {
                        VStack(spacing: 6) {
                            Text("Distans")
                                .font(.system(size: 11))
                                .foregroundColor(.gray)
                            Text(String(format: "%.2f km", distance))
                                .font(.system(size: 16, weight: .semibold))
                                .foregroundColor(.black)
                        }
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 12)
                    }
                    
                    if let duration = post.duration {
                        if post.distance != nil {
                            Divider()
                                .frame(height: 40)
                        }
                        
                        VStack(spacing: 6) {
                            Text("Tid")
                                .font(.system(size: 11))
                                .foregroundColor(.gray)
                            Text(formatDuration(duration))
                                .font(.system(size: 16, weight: .semibold))
                                .foregroundColor(.black)
                        }
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 12)
                    }
                }
                .background(Color.white)
                .cornerRadius(12)
                .padding(.horizontal, 16)
                .padding(.bottom, 16)
            }
        }
        .background(Color(.systemGray6))
        .cornerRadius(12)
        .shadow(color: Color.black.opacity(0.1), radius: 4, x: 0, y: 2)
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

// Helper view for loading local images
struct LocalAsyncImage: View {
    let path: String
    @State private var image: UIImage?
    @State private var loadError: String?
    
    var body: some View {
        Group {
            if path.hasPrefix("http") {
                AsyncImage(url: URL(string: path)) { image in
                    image
                        .resizable()
                        .scaledToFill()
                        .frame(maxWidth: .infinity, maxHeight: 400)
                        .clipped()
                } placeholder: {
                    Rectangle()
                        .fill(Color(.systemGray5))
                        .frame(height: 300)
                        .overlay(ProgressView())
                }
            } else if let image = image {
                Image(uiImage: image)
                    .resizable()
                    .scaledToFill()
                    .frame(maxWidth: .infinity, maxHeight: 400)
                    .clipped()
            } else {
                Rectangle()
                    .fill(Color(.systemGray5))
                    .frame(height: 300)
                    .overlay(
                        VStack(spacing: 8) {
                            Image(systemName: "photo")
                                .foregroundColor(.gray)
                                .font(.system(size: 24))
                            if let error = loadError {
                                Text(error)
                                    .font(.caption)
                                    .foregroundColor(.red)
                            }
                        }
                    )
            }
        }
        .onAppear {
            loadLocalImage()
        }
    }
    
    private func loadLocalImage() {
        guard !path.hasPrefix("http") else { return }
        
        Task {
            let fileURL = URL(fileURLWithPath: path)
            print("🖼️ Trying to load image from: \(path)")
            print("🖼️ Full URL: \(fileURL)")
            
            // Check if file exists
            let fileExists = FileManager.default.fileExists(atPath: path)
            print("🖼️ File exists: \(fileExists)")
            
            if fileExists {
                if let imageData = try? Data(contentsOf: fileURL),
                   let uiImage = UIImage(data: imageData) {
                    print("✅ Successfully loaded image, size: \(uiImage.size)")
                    await MainActor.run {
                        self.image = uiImage
                    }
                } else {
                    print("❌ Failed to create UIImage from data")
                    await MainActor.run {
                        self.loadError = "Could not decode image"
                    }
                }
            } else {
                print("❌ File does not exist at path: \(path)")
                await MainActor.run {
                    self.loadError = "File not found"
                }
            }
        }
    }
}

#Preview {
    ActivitiesView()
        .environmentObject(AuthViewModel())
}
