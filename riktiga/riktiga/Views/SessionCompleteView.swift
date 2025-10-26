import SwiftUI
import PhotosUI

struct SessionCompleteView: View {
    let activity: ActivityType
    let distance: Double
    let duration: Int
    let earnedPoints: Int
    @Binding var isPresented: Bool
    let onComplete: () -> Void
    @Environment(\.dismiss) var dismiss
    @EnvironmentObject var authViewModel: AuthViewModel
    @StateObject private var revenueCatManager = RevenueCatManager.shared
    
    @State private var title: String = ""
    @State private var description: String = ""
    @State private var sessionImage: UIImage?
    @State private var selectedItem: PhotosPickerItem?
    @State private var isSaving = false
    @State private var showDeleteConfirmation = false
    
    // Calculate PRO points (1.5x boost)
    private var proPoints: Int {
        return Int(Double(earnedPoints) * 1.5)
    }
    
    var body: some View {
        ZStack {
            Color(.systemBackground).ignoresSafeArea()
            
            VStack(spacing: 0) {
                HStack {
                    Spacer()
                    Text("Slutför pass")
                        .font(.headline)
                    Spacer()
                    Button(action: {
                        showDeleteConfirmation = true
                    }) {
                        Image(systemName: "xmark")
                            .foregroundColor(.black)
                    }
                }
                .padding(16)
                
                ScrollView {
                    VStack(spacing: 20) {
                        ActivitySummaryCard(
                            activity: activity, 
                            distance: distance, 
                            duration: duration, 
                            earnedPoints: earnedPoints,
                            proPoints: proPoints,
                            isPro: revenueCatManager.isPremium
                        )
                        
                        VStack(alignment: .leading, spacing: 8) {
                            Text("Rubrik")
                                .font(.headline)
                            TextField("Ge ditt pass en titel", text: $title)
                                .padding(12)
                                .background(Color(.systemGray6))
                                .cornerRadius(8)
                        }
                        .padding(.horizontal, 16)
                        
                        VStack(alignment: .leading, spacing: 8) {
                            Text("Beskrivning")
                                .font(.headline)
                            TextEditor(text: $description)
                                .frame(height: 100)
                                .padding(8)
                                .background(Color(.systemGray6))
                                .cornerRadius(8)
                        }
                        .padding(.horizontal, 16)
                        
                        VStack(alignment: .leading, spacing: 8) {
                            Text("Bild")
                                .font(.headline)
                            
                            if let sessionImage = sessionImage {
                                ZStack(alignment: .topTrailing) {
                                    Image(uiImage: sessionImage)
                                        .resizable()
                                        .scaledToFill()
                                        .frame(height: 200)
                                        .cornerRadius(8)
                                        .clipped()
                                    
                                    Button(action: {
                                        self.sessionImage = nil
                                        self.selectedItem = nil
                                    }) {
                                        Image(systemName: "xmark.circle.fill")
                                            .font(.system(size: 24))
                                            .foregroundColor(.white)
                                            .background(Color.black.opacity(0.6))
                                            .clipShape(Circle())
                                    }
                                    .padding(8)
                                }
                            } else {
                                PhotosPicker(selection: $selectedItem, matching: .images) {
                                    VStack(spacing: 12) {
                                        Image(systemName: "photo.on.rectangle")
                                            .font(.system(size: 32))
                                            .foregroundColor(.gray)
                                        Text("Lägg till bild")
                                            .foregroundColor(.gray)
                                    }
                                    .frame(maxWidth: .infinity)
                                    .frame(height: 150)
                                    .background(Color(.systemGray6))
                                    .cornerRadius(8)
                                }
                            }
                        }
                        .padding(.horizontal, 16)
                        
                        Button(action: saveWorkout) {
                            if isSaving {
                                ProgressView()
                                    .tint(.white)
                            } else {
                                Text("Spara pass")
                            }
                        }
                        .frame(maxWidth: .infinity)
                        .padding(14)
                        .background(Color.black)
                        .foregroundColor(.white)
                        .cornerRadius(25)
                        .font(.headline)
                        .disabled(isSaving || title.isEmpty)
                        .padding(16)
                    }
                }
            }
            
            // MARK: - Delete Confirmation Popup
            if showDeleteConfirmation {
                ZStack {
                    Color.black.opacity(0.4)
                        .ignoresSafeArea()
                    
                    VStack(spacing: 20) {
                        Text("Vill du verkligen radera passet?")
                            .font(.system(size: 18, weight: .bold))
                            .foregroundColor(.black)
                            .multilineTextAlignment(.center)
                        
                        Text("Alla data kommer att försvinna")
                            .font(.system(size: 14))
                            .foregroundColor(.gray)
                            .multilineTextAlignment(.center)
                        
                        HStack(spacing: 16) {
                            Button(action: {
                                showDeleteConfirmation = false
                            }) {
                                Text("Avbryt")
                                    .font(.system(size: 16, weight: .medium))
                                    .frame(maxWidth: .infinity)
                                    .padding(12)
                                    .background(Color(.systemGray5))
                                    .foregroundColor(.black)
                                    .cornerRadius(8)
                            }
                            
                            Button(action: {
                                showDeleteConfirmation = false
                                isPresented = false
                                // Clear session and complete flow when deleting
                                onComplete()
                            }) {
                                Text("Radera")
                                    .font(.system(size: 16, weight: .bold))
                                    .frame(maxWidth: .infinity)
                                    .padding(12)
                                    .background(Color.red)
                                    .foregroundColor(.white)
                                    .cornerRadius(8)
                            }
                        }
                    }
                    .padding(24)
                    .background(Color.white)
                    .cornerRadius(16)
                    .shadow(radius: 20)
                    .padding(40)
                }
            }
        }
        .onChange(of: isPresented) { oldValue, newValue in
            // Clear session when the view is dismissed
            if !newValue && oldValue {
                print("🗑️ SessionCompleteView dismissed, clearing session")
                // onComplete will be called by the dismiss, but we add extra safety here
            }
        }
        .onChange(of: selectedItem) { oldValue, newValue in
            Task {
                if let data = try? await newValue?.loadTransferable(type: Data.self) {
                    if let uiImage = UIImage(data: data) {
                        sessionImage = uiImage
                    }
                }
            }
        }
    }
    
    func saveWorkout() {
        isSaving = true
        
        let post = WorkoutPost(
            userId: authViewModel.currentUser?.id ?? "",
            activityType: activity.rawValue,
            title: title,
            description: description,
            distance: distance,
            duration: duration,
            imageUrl: nil
        )
        
        Task {
            do {
                try await WorkoutService.shared.saveWorkoutPost(post, image: sessionImage, earnedPoints: earnedPoints)
                print("✅ Workout saved successfully")
                
                // Reload user profile to update XP
                if let userId = authViewModel.currentUser?.id {
                    if let updatedProfile = try? await ProfileService.shared.fetchUserProfile(userId: userId) {
                        await MainActor.run {
                            authViewModel.currentUser = updatedProfile
                        }
                    }
                }
                
                // Notify that workout was saved to refresh stats
                NotificationCenter.default.post(name: NSNotification.Name("WorkoutSaved"), object: nil)
                
                DispatchQueue.main.async {
                    isSaving = false
                    isPresented = false
                    onComplete()
                }
            } catch {
                print("❌ Error saving workout: \(error)")
                DispatchQueue.main.async {
                    isSaving = false
                }
            }
        }
    }
}

struct ActivitySummaryCard: View {
    let activity: ActivityType
    let distance: Double
    let duration: Int
    let earnedPoints: Int
    let proPoints: Int
    let isPro: Bool
    
    var body: some View {
        VStack(spacing: 12) {
            HStack {
                Image(systemName: activity.icon)
                    .font(.system(size: 24))
                    .foregroundColor(AppColors.brandBlue)
                
                VStack(alignment: .leading, spacing: 4) {
                    Text(activity.rawValue)
                        .font(.headline)
                    Text(String(format: "%.2f km • %@", distance, formattedDuration(duration)))
                        .font(.caption)
                        .foregroundColor(.gray)
                }
                
                Spacer()
            }
            
            // Points section
            VStack(spacing: 8) {
                if isPro {
                    // PRO user - show both regular and PRO points
                    HStack {
                        VStack(alignment: .leading, spacing: 2) {
                            Text("Du fick")
                                .font(.caption)
                                .foregroundColor(.gray)
                            Text("\(earnedPoints) poäng")
                                .font(.system(size: 16, weight: .semibold))
                                .foregroundColor(AppColors.brandGreen)
                        }
                        
                        Spacer()
                        
                        VStack(alignment: .trailing, spacing: 2) {
                            Text("Med PRO")
                                .font(.caption)
                                .foregroundColor(.gray)
                            Text("\(proPoints) poäng")
                                .font(.system(size: 16, weight: .semibold))
                                .foregroundColor(.orange)
                        }
                    }
                } else {
                    // Non-PRO user - show regular points and PRO boost info
                    HStack {
                        VStack(alignment: .leading, spacing: 2) {
                            Text("Du fick")
                                .font(.caption)
                                .foregroundColor(.gray)
                            Text("\(earnedPoints) poäng")
                                .font(.system(size: 16, weight: .semibold))
                                .foregroundColor(AppColors.brandGreen)
                        }
                        
                        Spacer()
                        
                        VStack(alignment: .trailing, spacing: 2) {
                            Text("Såhär mycket skulle du fått med PRO")
                                .font(.caption)
                                .foregroundColor(.gray)
                                .multilineTextAlignment(.trailing)
                            Text("\(proPoints) poäng")
                                .font(.system(size: 16, weight: .semibold))
                                .foregroundColor(.orange)
                        }
                    }
                }
            }
            .padding(12)
            .background(Color(.systemGray6))
            .cornerRadius(8)
        }
        .padding(16)
        .background(Color(.systemGray6))
        .cornerRadius(12)
        .padding(.horizontal, 16)
    }
    
    func formattedDuration(_ seconds: Int) -> String {
        let hours = seconds / 3600
        let minutes = (seconds % 3600) / 60
        if hours > 0 {
            return String(format: "%dh %dm", hours, minutes)
        } else {
            return String(format: "%dm", minutes)
        }
    }
}

#Preview {
    SessionCompleteView(
        activity: .running, 
        distance: 5.2, 
        duration: 1800, 
        earnedPoints: 78,
        isPresented: .constant(true),
        onComplete: {}
    )
    .environmentObject(AuthViewModel())
}
