import SwiftUI
import MapKit

struct ActiveFriendsMapView: View {
    @EnvironmentObject var authViewModel: AuthViewModel
    @State private var activeFriends: [ActiveFriendSession] = []
    @State private var isLoading = true
    @State private var errorMessage: String?
    @State private var mapRegion = MKCoordinateRegion(
        center: CLLocationCoordinate2D(latitude: 59.3293, longitude: 18.0686), // Stockholm default
        span: MKCoordinateSpan(latitudeDelta: 0.5, longitudeDelta: 0.5)
    )
    @State private var selectedFriend: ActiveFriendSession?
    
    var body: some View {
        ZStack {
            // Map
            Map(coordinateRegion: $mapRegion, annotationItems: activeFriends.filter { $0.coordinate != nil }) { friend in
                MapAnnotation(coordinate: friend.coordinate!) {
                    ActiveFriendAnnotation(friend: friend, isSelected: selectedFriend?.id == friend.id)
                        .onTapGesture {
                            withAnimation(.spring(response: 0.3, dampingFraction: 0.7)) {
                                selectedFriend = friend
                                // Center map on selected friend
                                if let coord = friend.coordinate {
                                    mapRegion.center = coord
                                }
                            }
                        }
                }
            }
            .ignoresSafeArea(edges: .bottom)
            
            // Overlay content
            VStack {
                // Top info bar
                if !activeFriends.isEmpty {
                    HStack {
                        Image(systemName: "figure.run")
                            .font(.system(size: 14, weight: .semibold))
                        Text("\(activeFriends.count) vän\(activeFriends.count == 1 ? "" : "ner") tränar just nu")
                            .font(.system(size: 14, weight: .semibold))
                    }
                    .foregroundColor(.white)
                    .padding(.horizontal, 16)
                    .padding(.vertical, 10)
                    .background(Color.black.opacity(0.8))
                    .cornerRadius(20)
                    .padding(.top, 12)
                }
                
                Spacer()
                
                // Selected friend card
                if let friend = selectedFriend {
                    ActiveFriendCard(friend: friend)
                        .transition(.move(edge: .bottom).combined(with: .opacity))
                        .padding(.horizontal, 16)
                        .padding(.bottom, 20)
                }
            }
            
            // Loading state
            if isLoading {
                VStack(spacing: 16) {
                    ProgressView()
                        .scaleEffect(1.2)
                    Text("Laddar aktiva vänner...")
                        .font(.system(size: 15, weight: .medium))
                        .foregroundColor(.gray)
                }
                .frame(maxWidth: .infinity, maxHeight: .infinity)
                .background(Color(.systemBackground).opacity(0.9))
            }
            
            // Empty state
            if !isLoading && activeFriends.isEmpty {
                VStack(spacing: 20) {
                    ZStack {
                        Circle()
                            .fill(Color(.systemGray6))
                            .frame(width: 100, height: 100)
                        
                        Image(systemName: "figure.run.circle")
                            .font(.system(size: 48))
                            .foregroundColor(.gray)
                    }
                    
                    Text("Inga aktiva vänner")
                        .font(.system(size: 20, weight: .bold))
                        .foregroundColor(.primary)
                    
                    Text("När dina vänner startar ett pass\nser du dem här på kartan")
                        .font(.system(size: 15))
                        .foregroundColor(.gray)
                        .multilineTextAlignment(.center)
                    
                    Button(action: {
                        Task { await loadActiveFriends() }
                    }) {
                        HStack(spacing: 8) {
                            Image(systemName: "arrow.clockwise")
                            Text("Uppdatera")
                        }
                        .font(.system(size: 15, weight: .semibold))
                        .foregroundColor(.primary)
                        .padding(.horizontal, 24)
                        .padding(.vertical, 12)
                        .background(Color(.systemGray6))
                        .cornerRadius(25)
                    }
                    .padding(.top, 8)
                }
                .frame(maxWidth: .infinity, maxHeight: .infinity)
                .background(Color(.systemBackground).opacity(0.95))
            }
        }
        .task {
            await loadActiveFriends()
        }
        .refreshable {
            await loadActiveFriends()
        }
    }
    
    private func loadActiveFriends() async {
        guard let userId = authViewModel.currentUser?.id else { return }
        
        await MainActor.run { isLoading = true }
        
        do {
            let friends = try await ActiveSessionService.shared.fetchActiveFriends(userId: userId)
            
            await MainActor.run {
                activeFriends = friends
                isLoading = false
                
                // If we have friends with locations, center map on first one
                if let firstWithLocation = friends.first(where: { $0.coordinate != nil }),
                   let coord = firstWithLocation.coordinate {
                    mapRegion = MKCoordinateRegion(
                        center: coord,
                        span: MKCoordinateSpan(latitudeDelta: 0.1, longitudeDelta: 0.1)
                    )
                }
            }
        } catch {
            await MainActor.run {
                isLoading = false
                errorMessage = error.localizedDescription
            }
            print("❌ Error loading active friends: \(error)")
        }
    }
}

// MARK: - Active Friend Annotation
struct ActiveFriendAnnotation: View {
    let friend: ActiveFriendSession
    let isSelected: Bool
    
    var body: some View {
        VStack(spacing: 0) {
            // Avatar bubble
            ZStack {
                Circle()
                    .fill(Color.white)
                    .frame(width: isSelected ? 56 : 44, height: isSelected ? 56 : 44)
                    .shadow(color: Color.black.opacity(0.2), radius: 4, x: 0, y: 2)
                
                // Pulsing ring for active session
                Circle()
                    .stroke(activityColor, lineWidth: 3)
                    .frame(width: isSelected ? 56 : 44, height: isSelected ? 56 : 44)
                
                // Avatar
                if let avatarUrl = friend.avatarUrl, !avatarUrl.isEmpty {
                    LocalAsyncImage(path: avatarUrl)
                        .frame(width: isSelected ? 48 : 36, height: isSelected ? 48 : 36)
                        .clipShape(Circle())
                } else {
                    Image(systemName: "person.fill")
                        .font(.system(size: isSelected ? 24 : 18))
                        .foregroundColor(.gray)
                }
                
                // Activity badge
                ZStack {
                    Circle()
                        .fill(activityColor)
                        .frame(width: 20, height: 20)
                    
                    Image(systemName: activityIcon)
                        .font(.system(size: 10, weight: .bold))
                        .foregroundColor(.white)
                }
                .offset(x: isSelected ? 20 : 15, y: isSelected ? 20 : 15)
            }
            
            // Name label (shown when selected)
            if isSelected {
                Text(friend.userName.components(separatedBy: " ").first ?? friend.userName)
                    .font(.system(size: 12, weight: .semibold))
                    .foregroundColor(.primary)
                    .padding(.horizontal, 8)
                    .padding(.vertical, 4)
                    .background(Color.white)
                    .cornerRadius(8)
                    .shadow(color: Color.black.opacity(0.1), radius: 2)
                    .offset(y: 4)
            }
        }
        .animation(.spring(response: 0.3, dampingFraction: 0.7), value: isSelected)
    }
    
    private var activityColor: Color {
        switch friend.activityType.lowercased() {
        case "walking", "gym": return .black
        case "running": return .orange
        case "cycling": return .blue
        default: return .green
        }
    }
    
    private var activityIcon: String {
        switch friend.activityType.lowercased() {
        case "walking", "gym": return "dumbbell.fill"
        case "running": return "figure.run"
        case "cycling": return "bicycle"
        default: return "figure.walk"
        }
    }
}

// MARK: - Active Friend Card
struct ActiveFriendCard: View {
    let friend: ActiveFriendSession
    
    var body: some View {
        HStack(spacing: 14) {
            // Avatar
            ZStack {
                if let avatarUrl = friend.avatarUrl, !avatarUrl.isEmpty {
                    LocalAsyncImage(path: avatarUrl)
                        .frame(width: 50, height: 50)
                        .clipShape(Circle())
                } else {
                    Circle()
                        .fill(Color(.systemGray5))
                        .frame(width: 50, height: 50)
                        .overlay(
                            Image(systemName: "person.fill")
                                .font(.system(size: 22))
                                .foregroundColor(.gray)
                        )
                }
                
                // Activity indicator
                Circle()
                    .fill(Color.green)
                    .frame(width: 14, height: 14)
                    .overlay(Circle().stroke(Color.white, lineWidth: 2))
                    .offset(x: 18, y: 18)
            }
            
            VStack(alignment: .leading, spacing: 4) {
                Text(friend.userName)
                    .font(.system(size: 16, weight: .semibold))
                    .foregroundColor(.primary)
                
                HStack(spacing: 6) {
                    Image(systemName: activityIcon)
                        .font(.system(size: 12, weight: .semibold))
                    Text(activityText)
                        .font(.system(size: 14, weight: .medium))
                }
                .foregroundColor(.gray)
            }
            
            Spacer()
            
            // Duration
            VStack(alignment: .trailing, spacing: 2) {
                Text(friend.formattedDuration)
                    .font(.system(size: 18, weight: .bold, design: .rounded))
                    .foregroundColor(.primary)
                Text("aktiv")
                    .font(.system(size: 12))
                    .foregroundColor(.gray)
            }
        }
        .padding(16)
        .background(
            RoundedRectangle(cornerRadius: 16)
                .fill(Color(.systemBackground))
                .shadow(color: Color.black.opacity(0.15), radius: 12, x: 0, y: 4)
        )
    }
    
    private var activityIcon: String {
        switch friend.activityType.lowercased() {
        case "walking", "gym": return "dumbbell.fill"
        case "running": return "figure.run"
        case "cycling": return "bicycle"
        default: return "figure.walk"
        }
    }
    
    private var activityText: String {
        switch friend.activityType.lowercased() {
        case "walking", "gym": return "Kör gympass"
        case "running": return "Springer"
        case "cycling": return "Cyklar"
        default: return "Tränar"
        }
    }
}

#Preview {
    ActiveFriendsMapView()
        .environmentObject(AuthViewModel())
}
