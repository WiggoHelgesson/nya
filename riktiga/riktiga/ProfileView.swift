import SwiftUI

struct ProfileView: View {
    @EnvironmentObject var authViewModel: AuthViewModel
    @State private var showImagePicker = false
    @State private var profileImage: UIImage?
    @State private var showSettings = false
    @State private var showStatistics = false
    
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
                                if let profileImage = profileImage {
                                    Image(uiImage: profileImage)
                                        .resizable()
                                        .scaledToFill()
                                        .frame(width: 80, height: 80)
                                        .clipShape(Circle())
                                } else {
                                    Image(systemName: "person.crop.circle.fill")
                                        .font(.system(size: 80))
                                        .foregroundColor(.gray)
                                }
                            }
                            
                            VStack(alignment: .leading, spacing: 12) {
                                HStack {
                                    Text(authViewModel.currentUser?.name ?? "User")
                                        .font(.system(size: 20, weight: .bold))
                                    
                                    Spacer()
                                    
                                    Button(action: {}) {
                                        Image(systemName: "pencil.square")
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
                                        Text("12")
                                            .font(.system(size: 16, weight: .bold))
                                        Text("Följare")
                                            .font(.caption2)
                                            .foregroundColor(.gray)
                                    }
                                    
                                    VStack(spacing: 4) {
                                        Text("18")
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
                    
                    // MARK: - Action Buttons (2x1)
                    HStack(spacing: 12) {
                        ActionButton(
                            icon: "cart.fill",
                            label: "Mina köp",
                            action: {}
                        )
                        
                        ActionButton(
                            icon: "chart.bar.fill",
                            label: "Statistik",
                            action: {
                                showStatistics = true
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
                ImagePicker(image: $profileImage)
            }
            .sheet(isPresented: $showSettings) {
                SettingsView()
            }
            .sheet(isPresented: $showStatistics) {
                StatisticsView()
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
