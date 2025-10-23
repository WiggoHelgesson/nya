import SwiftUI
import Combine

struct ActivitiesView: View {
    @StateObject private var workoutPosts: WorkoutPostsViewModel = WorkoutPostsViewModel()
    
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
                workoutPosts.fetchAllPosts()
            }
            .refreshable {
                await workoutPosts.refreshPosts()
            }
        }
    }
}

struct WorkoutPostCard: View {
    let post: WorkoutPost
    
    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                Image(systemName: getActivityIcon(post.activityType))
                    .font(.system(size: 20))
                    .foregroundColor(Color(red: 0.1, green: 0.6, blue: 0.8))
                
                VStack(alignment: .leading, spacing: 2) {
                    Text(post.title)
                        .font(.headline)
                    Text(post.activityType)
                        .font(.caption)
                        .foregroundColor(.gray)
                }
                
                Spacer()
                
                Text(formatDate(post.createdAt))
                    .font(.caption)
                    .foregroundColor(.gray)
            }
            
            if let imageData = post.imageData, let imageUIImage = decodeImage(imageData) {
                Image(uiImage: imageUIImage)
                    .resizable()
                    .scaledToFill()
                    .frame(height: 150)
                    .cornerRadius(8)
                    .clipped()
            }
            
            if !post.description.isEmpty {
                Text(post.description)
                    .font(.caption)
                    .lineLimit(3)
                    .foregroundColor(.gray)
            }
        }
        .padding(16)
        .background(Color(.systemGray6))
        .cornerRadius(12)
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
    
    func decodeImage(_ base64: String) -> UIImage? {
        if let data = Data(base64Encoded: base64) {
            return UIImage(data: data)
        }
        return nil
    }
}

class WorkoutPostsViewModel: ObservableObject {
    @Published var posts: [WorkoutPost] = []
    
    func fetchAllPosts() {
        Task {
            do {
                let fetchedPosts = try await WorkoutService.shared.fetchAllWorkoutPosts()
                DispatchQueue.main.async {
                    self.posts = fetchedPosts
                }
            } catch {
                print("Error fetching posts: \(error)")
            }
        }
    }
    
    func refreshPosts() async {
        do {
            let fetchedPosts = try await WorkoutService.shared.fetchAllWorkoutPosts()
            DispatchQueue.main.async {
                self.posts = fetchedPosts
            }
        } catch {
            print("Error refreshing posts: \(error)")
        }
    }
}

#Preview {
    ActivitiesView()
}
