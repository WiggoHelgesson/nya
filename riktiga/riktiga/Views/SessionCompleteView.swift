import SwiftUI
import PhotosUI

struct SessionCompleteView: View {
    let activity: ActivityType
    let distance: Double
    let duration: Int
    let earnedPoints: Int
    let routeImage: UIImage?
    let elevationGain: Double?
    let maxSpeed: Double?
    let completedSplits: [WorkoutSplit]
    @Binding var isPresented: Bool
    let onComplete: () -> Void
    let onDelete: () -> Void
    @Environment(\.dismiss) var dismiss
    @EnvironmentObject var authViewModel: AuthViewModel
    @ObservedObject private var revenueCatManager = RevenueCatManager.shared
    
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
                        Task {
                            await MainActor.run {
                                showDeleteConfirmation = true
                            }
                        }
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
                            isPro: revenueCatManager.isPremium,
                            elevationGain: elevationGain,
                            maxSpeed: maxSpeed
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
                        
                        // Show route image if available
                        if let routeImage = routeImage {
                            VStack(alignment: .leading, spacing: 8) {
                                Text("Din rutt")
                                    .font(.headline)
                                
                                ZStack(alignment: .topTrailing) {
                                    Image(uiImage: routeImage)
                                        .resizable()
                                        .scaledToFill()
                                        .frame(height: 200)
                                        .cornerRadius(8)
                                        .clipped()
                                }
                            }
                            .padding(.horizontal, 16)
                        }
                        
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
                                Task {
                                    await MainActor.run {
                                        self.sessionImage = nil
                                        self.selectedItem = nil
                                    }
                                }
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
                            if routeImage == nil {
                                ProgressView()
                                    .tint(.white)
                            } else {
                                Text("Spara pass")
                            }
                            }
                        }
                        .frame(maxWidth: .infinity)
                        .padding(14)
                        .background(Color.black)
                        .foregroundColor(.white)
                        .cornerRadius(25)
                        .font(.headline)
                        .disabled(isSaving || title.isEmpty || routeImage == nil)
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
                                Task {
                                    await MainActor.run {
                                        showDeleteConfirmation = false
                                    }
                                }
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
                                Task {
                                    await MainActor.run {
                                        showDeleteConfirmation = false
                                        isPresented = false
                                        onDelete()
                                    }
                                }
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
        // Session finalization is handled explicitly by onComplete/onDelete callbacks
        .onChange(of: selectedItem) { oldValue, newValue in
            Task {
                if let data = try? await newValue?.loadTransferable(type: Data.self) {
                    if let uiImage = UIImage(data: data) {
                        await MainActor.run {
                            sessionImage = uiImage
                        }
                    }
                }
            }
        }
    }
    
    func saveWorkout() {
        Task {
            await MainActor.run {
                isSaving = true
            }
            
            let splits = computeSplits()
            let post = WorkoutPost(
                userId: authViewModel.currentUser?.id ?? "",
                activityType: activity.rawValue,
                title: title,
                description: description,
                distance: distance,
                duration: duration,
                imageUrl: nil,
                userImageUrl: nil,
                elevationGain: elevationGain,
                maxSpeed: maxSpeed,
                splits: splits.isEmpty ? nil : splits
            )
            
            do {
                // Pass both route image and user image
                try await WorkoutService.shared.saveWorkoutPost(post, routeImage: routeImage, userImage: sessionImage, earnedPoints: earnedPoints)
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
                print("✅ Workout saved, closing sheet and calling onComplete")
                
                await MainActor.run {
                    isSaving = false
                    isPresented = false
                    print("📤 isPresented set to false")
                    onComplete()
                    print("📤 onComplete() called")
                }
            } catch {
                print("❌ Error saving workout: \(error)")
                await MainActor.run {
                    isSaving = false
                }
            }
        }
    }
    
    private func computeSplits() -> [WorkoutSplit] {
        var splits = completedSplits
        guard distance > 0, duration > 0 else { return splits }
        let totalDistanceKm = distance
        let totalDurationSeconds = Double(duration)
        let recordedDistance = splits.reduce(0) { $0 + $1.distanceKm }
        let recordedDuration = splits.reduce(0) { $0 + $1.durationSeconds }
        let remainingDistance = totalDistanceKm - recordedDistance
        let remainingDuration = totalDurationSeconds - recordedDuration
        if remainingDistance > 0.05, remainingDuration > 1 {
            let nextIndex = splits.count + 1
            splits.append(WorkoutSplit(kilometerIndex: nextIndex,
                                       distanceKm: remainingDistance,
                                       durationSeconds: remainingDuration))
        }
        return splits
    }
}

struct ActivitySummaryCard: View {
    let activity: ActivityType
    let distance: Double
    let duration: Int
    let earnedPoints: Int
    let proPoints: Int
    let isPro: Bool
    let elevationGain: Double?
    let maxSpeed: Double?
    
    var body: some View {
        VStack(spacing: 0) {
            VStack(spacing: 12) {
                HStack {
                    Image(systemName: activity.icon)
                        .font(.system(size: 24))
                        .foregroundColor(AppColors.brandBlue)
                    
                    VStack(alignment: .leading, spacing: 4) {
                        Text(activity.rawValue)
                            .font(.headline)
                        Text(String(format: "%.2f km", distance))
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
                                    .foregroundColor(.black)
                            }
                            
                            Spacer()
                            
                            VStack(alignment: .trailing, spacing: 2) {
                                Text("Med PRO")
                                    .font(.caption)
                                    .foregroundColor(.gray)
                                Text("\(proPoints) poäng")
                                    .font(.system(size: 16, weight: .semibold))
                                    .foregroundColor(.black)
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
                                    .foregroundColor(.black)
                            }
                            
                            Spacer()
                            
                            VStack(alignment: .trailing, spacing: 2) {
                                Text("Såhär mycket skulle du fått med PRO")
                                    .font(.caption)
                                    .foregroundColor(.gray)
                                    .multilineTextAlignment(.trailing)
                                Text("\(proPoints) poäng")
                                    .font(.system(size: 16, weight: .semibold))
                                    .foregroundColor(.black)
                            }
                        }
                    }
                }
                .padding(12)
                .background(Color(.systemGray6))
                .cornerRadius(8)
            }
            .padding(12)
            .background(Color.white)
            .cornerRadius(12)
            
        }
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
        routeImage: nil,
        elevationGain: nil,
        maxSpeed: nil,
        completedSplits: [],
        isPresented: .constant(true),
        onComplete: {},
        onDelete: {}
    )
    .environmentObject(AuthViewModel())
}
