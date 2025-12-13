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
    let gymExercises: [GymExercise]?  // New parameter for gym sessions
    @Binding var isPresented: Bool
    let onComplete: () -> Void
    let onDelete: () -> Void
    @Environment(\.dismiss) var dismiss
    @EnvironmentObject var authViewModel: AuthViewModel
    @State private var isPremium = RevenueCatManager.shared.isPremium
    
    @State private var title: String = ""
    @State private var description: String = ""
    @State private var sessionImage: UIImage?
    @State private var selectedItem: PhotosPickerItem?
    @State private var isSaving = false
    @State private var showDeleteConfirmation = false
    @State private var shouldSaveTemplate = false
    @State private var showSaveTemplateSheet = false
    @State private var templateName: String = ""
    @State private var showSaveSuccess = false
    @State private var successScale: CGFloat = 0.7
    @State private var successOpacity: Double = 0.0
    @State private var pendingSharePost: SocialWorkoutPost?
    @State private var showShareGallery = false
    
    // Calculate PRO points (1.5x boost)
    private var proPoints: Int {
        // If user is already PRO, earnedPoints already includes the boost.
        // To show what "regular" points would be, we divide by 1.5.
        // But for the comparison view (showing what you COULD get), 
        // if user is NOT PRO, we want to show (earned * 1.5).
        if isPremium {
             return earnedPoints 
        } else {
             return Int(Double(earnedPoints) * 1.5)
        }
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
                            isPro: isPremium,
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
                            
                            if let currentImage = sessionImage {
                                ZStack(alignment: .topTrailing) {
                                    Image(uiImage: currentImage)
                                        .resizable()
                                        .scaledToFill()
                                        .frame(height: 200)
                                        .cornerRadius(8)
                                        .clipped()
                                    
                                    Button(action: {
                                        sessionImage = nil
                                        selectedItem = nil
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
                        
                        if let gymExercises, !gymExercises.isEmpty {
                            Toggle(isOn: Binding(
                                get: { shouldSaveTemplate },
                                set: { newValue in
                                    if newValue {
                                        shouldSaveTemplate = true
                                        templateName = templateName.isEmpty ? title : templateName
                                        showSaveTemplateSheet = true
                                    } else {
                                        shouldSaveTemplate = false
                                        templateName = ""
                                    }
                                }
                            )) {
                                Text("Spara detta passet")
                                    .font(.system(size: 16, weight: .semibold))
                                    .foregroundColor(.black)
                            }
                            .padding(.horizontal, 16)
                            .padding(.top, 4)
                            .toggleStyle(SwitchToggleStyle(tint: .black))
                        }
                        
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
                                onDelete()
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
        .sheet(isPresented: $showSaveTemplateSheet, onDismiss: {
            if templateName.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
                shouldSaveTemplate = false
            } else {
                shouldSaveTemplate = true
            }
        }) {
            NavigationStack {
                VStack(spacing: 20) {
                    Text("Namn på passet")
                        .font(.headline)
                    TextField("Till exempel: Överkropp A", text: $templateName)
                        .textFieldStyle(.roundedBorder)
                        .padding(.horizontal)
                    Spacer()
                }
                .padding(.top, 32)
                .toolbar {
                    ToolbarItem(placement: .cancellationAction) {
                        Button("Avbryt") {
                            templateName = ""
                            shouldSaveTemplate = false
                            showSaveTemplateSheet = false
                        }
                    }
                    ToolbarItem(placement: .confirmationAction) {
                        Button("Spara") {
                            if templateName.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
                                return
                            }
                            shouldSaveTemplate = true
                            showSaveTemplateSheet = false
                        }
                    }
                }
                .presentationDetents([.medium])
            }
        }
        // Session finalization is handled explicitly by onComplete/onDelete callbacks
        .onChange(of: selectedItem) { _, newValue in
            guard let newValue else { return }
            Task(priority: .userInitiated) {
                if let data = try? await newValue.loadTransferable(type: Data.self),
                   let uiImage = UIImage(data: data) {
                    await MainActor.run {
                        sessionImage = uiImage
                    }
                }
            }
        }
        .onReceive(RevenueCatManager.shared.$isPremium) { newValue in
            isPremium = newValue
        }
        .fullScreenCover(isPresented: $showShareGallery, onDismiss: {
            pendingSharePost = nil
        }) {
            if let post = pendingSharePost {
                ShareActivityView(post: post) {
                    showShareGallery = false
                    pendingSharePost = nil
                    isPresented = false
                    onComplete()
                }
            }
        }
    }
    
    func saveWorkout() {
        Task(priority: .userInitiated) {
            await MainActor.run {
                isSaving = true
            }
            
            let splits = computeSplits()
            let trimmedTemplateName = templateName.trimmingCharacters(in: .whitespacesAndNewlines)
            
            let exercisesData: [GymExercisePost]? = gymExercises?.map { exercise in
                GymExercisePost(
                    id: exercise.id,
                    name: exercise.name,
                    category: exercise.category,
                    sets: exercise.sets.count,
                    reps: exercise.sets.map { $0.reps },
                    kg: exercise.sets.map { $0.kg }
                )
            }
            
            var pointsToAward = earnedPoints
            if activity.rawValue == "Gympass" {
                let key = gymPointsKey(for: Date())
                let alreadyAwarded = UserDefaults.standard.integer(forKey: key)
                let remaining = max(0, 50 - alreadyAwarded)
                pointsToAward = min(pointsToAward, remaining)
            }
            
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
                splits: splits.isEmpty ? nil : splits,
                exercises: exercisesData
            )
            
            do {
                if shouldSaveTemplate,
                   let exercisesData = exercisesData,
                   !exercisesData.isEmpty,
                   let userId = authViewModel.currentUser?.id,
                   !trimmedTemplateName.isEmpty {
                    do {
                        let savedTemplate = try await SavedWorkoutService.shared.saveWorkoutTemplate(userId: userId, name: trimmedTemplateName, exercises: exercisesData)
                        NotificationCenter.default.post(name: .savedGymWorkoutCreated, object: savedTemplate)
                    } catch {
                        print("⚠️ Failed to save workout template: \(error)")
                    }
                }
                
                try await WorkoutService.shared.saveWorkoutPost(post, routeImage: routeImage, userImage: sessionImage, earnedPoints: pointsToAward)
                
                let sharePost = SocialWorkoutPost(
                    from: post,
                    userName: authViewModel.currentUser?.name,
                    userAvatarUrl: authViewModel.currentUser?.avatarUrl,
                    userIsPro: authViewModel.currentUser?.isProMember
                )
                
                if activity.rawValue == "Gympass" && pointsToAward > 0 {
                    let key = gymPointsKey(for: Date())
                    let existing = UserDefaults.standard.integer(forKey: key)
                    UserDefaults.standard.set(existing + pointsToAward, forKey: key)
                }
                
                if let userId = authViewModel.currentUser?.id {
                    if let updatedProfile = try? await ProfileService.shared.fetchUserProfile(userId: userId) {
                        await MainActor.run {
                            authViewModel.currentUser = updatedProfile
                        }
                    }
                }
                
                NotificationCenter.default.post(name: NSNotification.Name("WorkoutSaved"), object: nil)
                
                await MainActor.run {
                    isSaving = false
                    shouldSaveTemplate = false
                    templateName = ""
                    pendingSharePost = sharePost
                    triggerSaveSuccessAnimation()
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
    
    private func gymPointsKey(for date: Date) -> String {
        let formatter = DateFormatter()
        formatter.dateFormat = "yyyy-MM-dd"
        return "gymPoints_\(formatter.string(from: date))"
    }
    
    private func triggerSaveSuccessAnimation() {
        showSaveSuccess = true
        successScale = 0.7
        successOpacity = 0.0
        
        withAnimation(.spring(response: 0.45, dampingFraction: 0.65, blendDuration: 0.2)) {
            successScale = 1.0
            successOpacity = 1.0
        }
        
        DispatchQueue.main.asyncAfter(deadline: .now() + 1.1) {
            withAnimation(.easeInOut(duration: 0.25)) {
                successOpacity = 0.0
            }
        }
        
        DispatchQueue.main.asyncAfter(deadline: .now() + 1.4) {
            showSaveSuccess = false
            if pendingSharePost != nil {
                showShareGallery = true
            } else {
                isPresented = false
                onComplete()
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
                        // PRO user - only show total points
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
                            
                            // Show PRO badge instead of comparison
                            HStack(spacing: 4) {
                                Image(systemName: "crown.fill")
                                    .foregroundColor(.yellow)
                                Text("PRO Boost aktiv")
                                    .font(.caption)
                                    .fontWeight(.medium)
                                    .foregroundColor(.black)
                            }
                            .padding(.horizontal, 10)
                            .padding(.vertical, 6)
                            .background(Color.yellow.opacity(0.2))
                            .cornerRadius(20)
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
        gymExercises: nil,
        isPresented: .constant(true),
        onComplete: {},
        onDelete: {}
    )
    .environmentObject(AuthViewModel())
}
