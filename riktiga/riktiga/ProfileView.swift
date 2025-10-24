import SwiftUI
import Combine

extension Notification.Name {
    static let profileStatsUpdated = Notification.Name("profileStatsUpdated")
}

struct ProfileView: View {
    @EnvironmentObject var authViewModel: AuthViewModel
    @State private var showImagePicker = false
    @State private var profileImage: UIImage?
    @State private var showSettings = false
    @State private var showStatistics = false
    @State private var showMyPurchases = false
    @State private var showFindFriends = false
    @State private var followersCount = 0
    @State private var followingCount = 0
    
    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(spacing: 16) {
                    // MARK: - Profile Header Card
                    VStack(spacing: 16) {
                        HStack(spacing: 16) {
                            // Profilbild - Tappable
                            Button(action: {
                                showImagePicker = true
                            }) {
                                AsyncImage(url: URL(string: authViewModel.currentUser?.avatarUrl ?? "")) { image in
                                    image
                                        .resizable()
                                        .aspectRatio(contentMode: .fill)
                                } placeholder: {
                                    Image(systemName: "person.crop.circle.fill")
                                        .font(.system(size: 80))
                                        .foregroundColor(.gray)
                                }
                                .frame(width: 80, height: 80)
                                .clipShape(Circle())
                            }
                            
                            VStack(alignment: .leading, spacing: 12) {
                                HStack {
                                    Text(authViewModel.currentUser?.name ?? "User")
                                        .font(.system(size: 20, weight: .bold))
                                    
                                    Spacer()
                                    
                                    Button(action: {}) {
                                        Image(systemName: "pencil")
                                            .font(.title3)
                                            .foregroundColor(.black)
                                    }
                                }
                                
                                HStack(spacing: 20) {
                                    VStack(spacing: 4) {
                                        Text("1")
                                            .font(.system(size: 16, weight: .bold))
                                        Text("Träningspass")
                                            .font(.caption2)
                                            .foregroundColor(.gray)
                                    }
                                    
                                    VStack(spacing: 4) {
                                        Text("\(followersCount)")
                                            .font(.system(size: 16, weight: .bold))
                                        Text("Följare")
                                            .font(.caption2)
                                            .foregroundColor(.gray)
                                    }
                                    
                                    VStack(spacing: 4) {
                                        Text("\(followingCount)")
                                            .font(.system(size: 16, weight: .bold))
                                        Text("Följer")
                                            .font(.caption2)
                                            .foregroundColor(.gray)
                                    }
                                    
                                    Spacer()
                                }
                                
                            }
                        }
                    }
                    .padding(20)
                    .background(Color(.systemGray6))
                    .cornerRadius(16)
                    
                    // MARK: - XP Box
                    HStack(spacing: 16) {
                        // Logo/Icon
                        Text("U")
                            .font(.system(size: 32, weight: .bold))
                            .foregroundColor(.white)
                            .frame(width: 56, height: 56)
                            .background(Color.black)
                            .cornerRadius(10)
                        
                        // XP Text
                        VStack(alignment: .leading, spacing: 4) {
                            Text("\(formatNumber(authViewModel.currentUser?.currentXP ?? 0)) Poäng")
                                .font(.system(size: 18, weight: .bold))
                        }
                        
                        Spacer()
                    }
                    .padding(16)
                    .background(Color.white)
                    .cornerRadius(12)
                    .border(Color.black, width: 2)
                    
                    // MARK: - Action Buttons (3x1)
                    HStack(spacing: 12) {
                        ActionButton(
                            icon: "cart.fill",
                            label: "Mina köp",
                            action: {
                                showMyPurchases = true
                            }
                        )
                        
                        ActionButton(
                            icon: "chart.bar.fill",
                            label: "Statistik",
                            action: {
                                showStatistics = true
                            }
                        )
                        
                        ActionButton(
                            icon: "person.badge.plus.fill",
                            label: "Hitta vänner",
                            action: {
                                showFindFriends = true
                            }
                        )
                    }
                    
                    Spacer()
                }
                .padding(16)
            }
            .navigationTitle("Inställningar")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button(action: {
                        showSettings = true
                    }) {
                        Image(systemName: "gearshape.fill")
                            .font(.title3)
                            .foregroundColor(.black)
                    }
                }
            }
            .sheet(isPresented: $showImagePicker) {
                ImagePicker(image: $profileImage, authViewModel: authViewModel)
            }
            .sheet(isPresented: $showSettings) {
                SettingsView()
            }
            .sheet(isPresented: $showStatistics) {
                StatisticsView()
            }
            .sheet(isPresented: $showMyPurchases) {
                MyPurchasesView()
            }
            .sheet(isPresented: $showFindFriends) {
                FindFriendsView()
            }
            .onAppear {
                loadProfileStats()
            }
            .onReceive(NotificationCenter.default.publisher(for: .profileStatsUpdated)) { _ in
                loadProfileStats()
            }
            .onAppear {
                // Lyssna på profilbild uppdateringar
                NotificationCenter.default.addObserver(
                    forName: .profileImageUpdated,
                    object: nil,
                    queue: .main
                ) { notification in
                    if let newImageUrl = notification.object as? String {
                        print("🔄 Profile image updated in UI: \(newImageUrl)")
                        // Trigga UI-uppdatering genom att uppdatera authViewModel
                        authViewModel.objectWillChange.send()
                    }
                }
            }
            .onDisappear {
                NotificationCenter.default.removeObserver(self, name: .profileImageUpdated, object: nil)
            }
        }
    }
    
    private func loadProfileStats() {
        guard let currentUserId = authViewModel.currentUser?.id else { return }
        
        Task {
            do {
                let followers = try await SocialService.shared.getFollowers(userId: currentUserId)
                let following = try await SocialService.shared.getFollowing(userId: currentUserId)
                
                await MainActor.run {
                    self.followersCount = followers.count
                    self.followingCount = following.count
                }
            } catch {
                print("❌ Error loading profile stats: \(error)")
            }
        }
    }
}

struct ActionButton: View {
    let icon: String
    let label: String
    let action: () -> Void
    
    var body: some View {
        Button(action: action) {
            VStack(spacing: 8) {
                Image(systemName: icon)
                    .font(.title2)
                    .foregroundColor(.black)
                
                Text(label)
                    .font(.system(size: 14, weight: .medium))
                    .foregroundColor(.black)
                    .lineLimit(1)
            }
            .frame(maxWidth: .infinity)
            .padding(16)
            .background(Color(.systemGray6))
            .cornerRadius(10)
        }
    }
}

struct ImagePicker: UIViewControllerRepresentable {
    @Binding var image: UIImage?
    let authViewModel: AuthViewModel
    @Environment(\.presentationMode) var presentationMode
    
    func makeUIViewController(context: Context) -> UIImagePickerController {
        let picker = UIImagePickerController()
        picker.delegate = context.coordinator
        picker.sourceType = .photoLibrary
        return picker
    }
    
    func updateUIViewController(_ uiViewController: UIImagePickerController, context: Context) {}
    
    func makeCoordinator() -> Coordinator {
        Coordinator(self)
    }
    
    class Coordinator: NSObject, UIImagePickerControllerDelegate, UINavigationControllerDelegate {
        let parent: ImagePicker
        
        init(_ parent: ImagePicker) {
            self.parent = parent
        }
        
        func imagePickerController(_ picker: UIImagePickerController, didFinishPickingMediaWithInfo info: [UIImagePickerController.InfoKey: Any]) {
            if let uiImage = info[.originalImage] as? UIImage {
                parent.image = uiImage
                // Spara profilbilden via AuthViewModel
                parent.authViewModel.updateProfileImage(image: uiImage)
                
                // Visa en bekräftelse att bilden sparas
                DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) {
                    print("🔄 Profile image update initiated")
                }
            }
            parent.presentationMode.wrappedValue.dismiss()
        }
    }
}

#Preview {
    ProfileView()
        .environmentObject(AuthViewModel())
}

// MARK: - Helper Functions
func formatNumber(_ number: Int) -> String {
    let formatter = NumberFormatter()
    formatter.numberStyle = .decimal
    formatter.groupingSeparator = ","
    return formatter.string(from: NSNumber(value: number)) ?? "\(number)"
}
