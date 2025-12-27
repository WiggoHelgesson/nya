import SwiftUI
import PhotosUI
import MapKit
import CoreLocation

struct SessionCompleteView: View {
    let activity: ActivityType
    let distance: Double
    let duration: Int
    let earnedPoints: Int
    let routeImage: UIImage?
    let routeCoordinates: [CLLocationCoordinate2D]  // Route coordinates for interactive map
    let elevationGain: Double?
    let maxSpeed: Double?
    let completedSplits: [WorkoutSplit]
    let gymExercises: [GymExercise]?
    let sessionLivePhoto: UIImage?  // Live photo taken during session
    @Binding var isPresented: Bool
    let onComplete: () -> Void
    let onDelete: () -> Void
    @Environment(\.dismiss) var dismiss
    @EnvironmentObject var authViewModel: AuthViewModel
    @State private var isPremium = RevenueCatManager.shared.isProMember
    
    @State private var title: String = ""
    @State private var description: String = ""
    @State private var sessionImage: UIImage?
    @State private var selectedItem: PhotosPickerItem?
    @State private var isSaving = false
    @State private var saveButtonTapped = false
    @State private var showDeleteConfirmation = false
    @State private var shouldSaveTemplate = false
    @State private var showSaveTemplateSheet = false
    @State private var templateName: String = ""
    @State private var showSaveSuccess = false
    @State private var successScale: CGFloat = 0.7
    @State private var successOpacity: Double = 0.0
    @State private var pendingSharePost: SocialWorkoutPost?
    @State private var showShareGallery = false
    @State private var isEditingTitle = false
    @State private var mapRegion: MKCoordinateRegion = MKCoordinateRegion()
    @State private var mapInitialized = false
    @State private var showLiveCapture = false
    @State private var difficultyRating: Double = 0.5  // 0 = Lätt, 1 = Svårt
    @State private var isLivePhoto = false  // Track if image was taken with Up&Down Live
    
    // PB (Personal Best) tracking
    @State private var showPBSheet = false
    @State private var selectedPBExercise: GymExercise?
    @State private var pbWeight: String = ""
    @State private var pbReps: String = ""
    @State private var hasPB = false
    @State private var pbExerciseName: String = ""
    @State private var pbValue: String = ""
    
    // Default titles based on activity
    private var defaultTitle: String {
        switch activity {
        case .running: return "Löppass"
        case .golf: return "Golfrunda"
        case .skiing: return "Skidpass"
        case .walking: return "Gympass"  // walking is actually gym
        case .hiking: return "Bergsbestigning"
        }
    }
    
    // Calculate captured territory (approximate based on distance)
    private var capturedTerritory: Double {
        // Rough estimate: running path ~50m wide, so area = distance * 0.05 km
        // This is just for display - actual territory is calculated by the server
        return max(0, distance * 0.05)
    }
    
    // Check if this is a gym workout
    private var isGymWorkout: Bool {
        activity == .walking // walking is used for gym
    }
    
    // Calculate gym volume
    private var gymVolume: Int {
        guard let exercises = gymExercises else { return 0 }
        var total = 0
        for exercise in exercises {
            for set in exercise.sets {
                total += Int(set.kg) * set.reps
            }
        }
        return total
    }
    
    var body: some View {
        ZStack {
            Color(.systemBackground).ignoresSafeArea()
            
            ScrollView {
                VStack(spacing: 0) {
                    // MARK: - Header Section
                    headerSection
                    
                    // MARK: - Content
                    contentSection
                }
            }
            .ignoresSafeArea(edges: .top)
            
            // Delete confirmation overlay
            deleteConfirmationOverlay
        }
        .onChange(of: selectedItem) { _, newItem in
            handleImageSelection(newItem)
        }
        .sheet(isPresented: $showSaveTemplateSheet) {
            templateNameSheet
        }
        .sheet(isPresented: $showLiveCapture) {
            liveCaptureSheet
        }
        .onAppear {
            // If a live photo was taken during the session, use it
            if let livePhoto = sessionLivePhoto {
                sessionImage = livePhoto
                isLivePhoto = true
            }
        }
    }
    
    // MARK: - Header Section
    @ViewBuilder
    private var headerSection: some View {
        if isGymWorkout {
            gymHeaderSection
        } else {
            mapHeaderSection
        }
    }
    
    // MARK: - Map Header (Non-gym)
    private var mapHeaderSection: some View {
        VStack(spacing: 0) {
            ZStack(alignment: .topTrailing) {
                RouteMapView(coordinates: routeCoordinates, region: $mapRegion)
                    .onAppear {
                        initializeMapRegion()
                    }
                
                Button(action: {
                    showDeleteConfirmation = true
                }) {
                    Image(systemName: "xmark")
                        .font(.system(size: 16, weight: .medium))
                        .foregroundColor(.primary)
                        .padding(10)
                        .background(Color.white.opacity(0.9))
                        .clipShape(Circle())
                        .shadow(radius: 2)
                }
                .padding(.horizontal, 16)
                .padding(.top, 60)
            }
            .frame(height: 320)
            
            territoryStatsRow
            
            Divider()
        }
    }
    
    // MARK: - Territory Stats Row
    private var territoryStatsRow: some View {
        HStack(spacing: 0) {
            VStack(spacing: 4) {
                HStack(alignment: .firstTextBaseline, spacing: 4) {
                    Text(String(format: "%.0f", capturedTerritory * 1000))
                        .font(.system(size: 32, weight: .bold))
                    Text("KM²")
                        .font(.system(size: 14, weight: .semibold))
                        .foregroundColor(.secondary)
                }
                Text("Erövrat område")
                    .font(.system(size: 13))
                    .foregroundColor(.secondary)
            }
            .frame(maxWidth: .infinity)
            
            Rectangle()
                .fill(Color.gray.opacity(0.3))
                .frame(width: 1, height: 50)
            
            VStack(spacing: 4) {
                HStack(alignment: .firstTextBaseline, spacing: 4) {
                    Text("\(earnedPoints)")
                        .font(.system(size: 32, weight: .bold))
                    Text("XP")
                        .font(.system(size: 14, weight: .semibold))
                        .foregroundColor(.secondary)
                }
                Text("Intjänat")
                    .font(.system(size: 13))
                    .foregroundColor(.secondary)
            }
            .frame(maxWidth: .infinity)
        }
        .padding(.vertical, 20)
        .background(Color(.systemBackground))
    }
    
    // MARK: - Content Section
    private var contentSection: some View {
        VStack(spacing: 24) {
            titleSection
            difficultySliderSection
            if isGymWorkout {
                pbButtonSection
            }
            descriptionSection
            photoOptionsSection
            gymTemplateToggle
            saveButton
        }
    }
    
    // MARK: - PB Button Section
    @ViewBuilder
    private var pbButtonSection: some View {
        VStack(spacing: 12) {
            if hasPB {
                // Show PB badge when set
                HStack(spacing: 12) {
                    Image(systemName: "trophy.fill")
                        .font(.system(size: 24))
                        .foregroundColor(.yellow)
                    
                    VStack(alignment: .leading, spacing: 2) {
                        Text("Nytt PB!")
                            .font(.system(size: 14, weight: .bold))
                            .foregroundColor(.yellow)
                        Text("\(pbExerciseName): \(pbValue)")
                            .font(.system(size: 16, weight: .semibold))
                            .foregroundColor(.primary)
                    }
                    
                    Spacer()
                    
                    Button {
                        // Clear PB
                        hasPB = false
                        selectedPBExercise = nil
                        pbWeight = ""
                        pbReps = ""
                    } label: {
                        Image(systemName: "xmark.circle.fill")
                            .font(.system(size: 20))
                            .foregroundColor(.gray)
                    }
                }
                .padding(16)
                .background(Color(.systemGray6))
                .cornerRadius(12)
                .padding(.horizontal, 16)
            } else {
                // Show PB button
                Button {
                    showPBSheet = true
                } label: {
                    HStack(spacing: 10) {
                        Image(systemName: "trophy")
                            .font(.system(size: 18, weight: .semibold))
                        Text("Tog du ett PB idag?")
                            .font(.system(size: 16, weight: .semibold))
                    }
                    .foregroundColor(.black)
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 14)
                    .background(Color(.systemGray5))
                    .cornerRadius(12)
                }
                .padding(.horizontal, 16)
            }
        }
        .sheet(isPresented: $showPBSheet) {
            pbSelectionSheet
        }
    }
    
    // MARK: - PB Selection Sheet
    private var pbSelectionSheet: some View {
        NavigationStack {
            VStack(spacing: 0) {
                if let exercises = gymExercises, !exercises.isEmpty {
                    List {
                        Section {
                            ForEach(exercises) { exercise in
                                Button {
                                    selectedPBExercise = exercise
                                    // Pre-fill with best set from this workout
                                    if let bestSet = exercise.sets.max(by: { $0.kg < $1.kg }) {
                                        pbWeight = String(format: "%.1f", bestSet.kg)
                                        pbReps = "\(bestSet.reps)"
                                    }
                                } label: {
                                    HStack {
                                        VStack(alignment: .leading, spacing: 4) {
                                            Text(exercise.name)
                                                .font(.system(size: 16, weight: .semibold))
                                                .foregroundColor(.primary)
                                            
                                            // Show best set from this workout
                                            if let bestSet = exercise.sets.max(by: { $0.kg < $1.kg }) {
                                                Text("Bästa set: \(String(format: "%.1f", bestSet.kg)) kg x \(bestSet.reps)")
                                                    .font(.system(size: 13))
                                                    .foregroundColor(.secondary)
                                            }
                                        }
                                        
                                        Spacer()
                                        
                                        if selectedPBExercise?.id == exercise.id {
                                            Image(systemName: "checkmark.circle.fill")
                                                .foregroundColor(.green)
                                                .font(.system(size: 22))
                                        } else {
                                            Image(systemName: "circle")
                                                .foregroundColor(.gray)
                                                .font(.system(size: 22))
                                        }
                                    }
                                    .padding(.vertical, 4)
                                }
                            }
                        } header: {
                            Text("Välj övning")
                        }
                        
                        if selectedPBExercise != nil {
                            Section {
                                HStack(spacing: 16) {
                                    VStack(alignment: .leading, spacing: 4) {
                                        Text("Vikt (kg)")
                                            .font(.system(size: 13, weight: .medium))
                                            .foregroundColor(.secondary)
                                        TextField("0", text: $pbWeight)
                                            .keyboardType(.decimalPad)
                                            .font(.system(size: 24, weight: .bold))
                                            .padding(12)
                                            .background(Color(.systemGray6))
                                            .cornerRadius(8)
                                    }
                                    
                                    VStack(alignment: .leading, spacing: 4) {
                                        Text("Reps")
                                            .font(.system(size: 13, weight: .medium))
                                            .foregroundColor(.secondary)
                                        TextField("0", text: $pbReps)
                                            .keyboardType(.numberPad)
                                            .font(.system(size: 24, weight: .bold))
                                            .padding(12)
                                            .background(Color(.systemGray6))
                                            .cornerRadius(8)
                                    }
                                }
                            } header: {
                                Text("Ditt nya PB")
                            }
                        }
                    }
                    .listStyle(.insetGrouped)
                } else {
                    VStack(spacing: 16) {
                        Image(systemName: "dumbbell")
                            .font(.system(size: 48))
                            .foregroundColor(.gray)
                        Text("Inga övningar i detta pass")
                            .font(.system(size: 16, weight: .medium))
                            .foregroundColor(.gray)
                    }
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
                }
            }
            .navigationTitle("Nytt PB")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarLeading) {
                    Button("Avbryt") {
                        showPBSheet = false
                    }
                }
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button("Spara") {
                        savePB()
                    }
                    .disabled(selectedPBExercise == nil || pbWeight.isEmpty || pbReps.isEmpty)
                    .fontWeight(.semibold)
                }
            }
        }
    }
    
    // MARK: - Save PB
    private func savePB() {
        guard let exercise = selectedPBExercise,
              let weight = Double(pbWeight.replacingOccurrences(of: ",", with: ".")),
              let reps = Int(pbReps) else { return }
        
        hasPB = true
        pbExerciseName = exercise.name
        pbValue = "\(String(format: "%.1f", weight)) kg x \(reps) reps"
        showPBSheet = false
    }
    
    // MARK: - Title Section
    private var titleSection: some View {
        VStack(spacing: 12) {
            HStack {
                if isEditingTitle {
                    TextField("Titel", text: $title)
                        .font(.system(size: 32, weight: .black))
                        .multilineTextAlignment(.center)
                        .onSubmit {
                            isEditingTitle = false
                        }
                } else {
                    Text(title.isEmpty ? defaultTitle : title)
                        .font(.system(size: 32, weight: .black))
                }
                
                Button(action: {
                    if title.isEmpty {
                        title = defaultTitle
                    }
                    isEditingTitle.toggle()
                }) {
                    Image(systemName: "pencil")
                        .font(.system(size: 18))
                        .foregroundColor(.gray)
                }
            }
            
            workoutStatsRow
        }
        .padding(.top, 16)
    }
    
    // MARK: - Workout Stats Row
    @ViewBuilder
    private var workoutStatsRow: some View {
        if isGymWorkout {
            gymStatsRow
        } else {
            activityStatsRow
        }
    }
    
    // MARK: - Gym Stats Row
    private var gymStatsRow: some View {
        HStack(spacing: 0) {
            VStack(spacing: 4) {
                Text(duration > 0 ? formatDuration(duration) : "0:00")
                    .font(.system(size: 28, weight: .black))
                Text("Tid")
                    .font(.system(size: 12, weight: .medium))
                    .foregroundColor(.secondary)
            }
            .frame(maxWidth: .infinity)
            
            Rectangle()
                .fill(Color.gray.opacity(0.3))
                .frame(width: 1, height: 40)
            
            VStack(spacing: 4) {
                Text(formatVolume(gymVolume))
                    .font(.system(size: 28, weight: .black))
                Text("Volym")
                    .font(.system(size: 12, weight: .medium))
                    .foregroundColor(.secondary)
            }
            .frame(maxWidth: .infinity)
        }
        .padding(.top, 8)
    }
    
    // MARK: - Activity Stats Row (Non-gym)
    private var activityStatsRow: some View {
        HStack(spacing: 24) {
            VStack(spacing: 4) {
                Text(distance > 0 ? String(format: "%.2f", distance) : "N/A")
                    .font(.system(size: 24, weight: .black))
                Text("Distans (km)")
                    .font(.system(size: 12, weight: .medium))
                    .foregroundColor(.secondary)
            }
            
            VStack(spacing: 4) {
                Text(duration > 0 ? formatDuration(duration) : "N/A")
                    .font(.system(size: 24, weight: .black))
                Text("Tid")
                    .font(.system(size: 12, weight: .medium))
                    .foregroundColor(.secondary)
            }
            
            VStack(spacing: 4) {
                Text(distance > 0 && duration > 0 ? formatPace(distance: distance, duration: duration) : "0:00")
                    .font(.system(size: 24, weight: .black))
                Text("Tempo (min/km)")
                    .font(.system(size: 12, weight: .medium))
                    .foregroundColor(.secondary)
            }
        }
        .padding(.top, 8)
    }
    
    // MARK: - Difficulty Slider Section
    private var difficultySliderSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Hur tufft var passet")
                .font(.system(size: 16, weight: .bold))
            
            VStack(spacing: 8) {
                GeometryReader { geometry in
                    ZStack(alignment: .leading) {
                        Capsule()
                            .fill(Color.black.opacity(0.15))
                            .frame(height: 40)
                        
                        Capsule()
                            .fill(Color.black)
                            .frame(width: max(40, geometry.size.width * difficultyRating), height: 40)
                        
                        Circle()
                            .fill(Color.white)
                            .frame(width: 36, height: 36)
                            .shadow(color: .black.opacity(0.15), radius: 4, x: 0, y: 2)
                            .offset(x: max(2, (geometry.size.width - 36) * difficultyRating))
                            .gesture(
                                DragGesture()
                                    .onChanged { value in
                                        let newValue = value.location.x / geometry.size.width
                                        difficultyRating = min(max(0, newValue), 1)
                                    }
                            )
                    }
                }
                .frame(height: 40)
                
                HStack {
                    Text("Lätt")
                        .font(.system(size: 13, weight: .medium))
                        .foregroundColor(.secondary)
                    Spacer()
                    Text("Svårt")
                        .font(.system(size: 13, weight: .medium))
                        .foregroundColor(.secondary)
                }
            }
        }
        .padding(.horizontal, 16)
    }
    
    // MARK: - Description Section
    private var descriptionSection: some View {
        VStack(alignment: .leading, spacing: 8) {
            TextEditor(text: $description)
                .frame(minHeight: 80)
                .padding(12)
                .background(Color(.systemGray6))
                .cornerRadius(12)
                .overlay(
                    Group {
                        if description.isEmpty {
                            Text("Beskriv ditt pass...")
                                .foregroundColor(.gray)
                                .padding(.horizontal, 16)
                                .padding(.vertical, 20)
                        }
                    },
                    alignment: .topLeading
                )
        }
        .padding(.horizontal, 16)
    }
    
    // MARK: - Photo Options Section
    @ViewBuilder
    private var photoOptionsSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            if let currentImage = sessionImage {
                selectedImageView(currentImage)
            } else {
                photoPickerButtons
            }
        }
        .padding(.horizontal, 16)
    }
    
    // MARK: - Selected Image View
    private func selectedImageView(_ image: UIImage) -> some View {
        ZStack(alignment: .topTrailing) {
            Image(uiImage: image)
                .resizable()
                .scaledToFill()
                .frame(height: 250)
                .cornerRadius(12)
                .clipped()
            
            Button(action: {
                sessionImage = nil
                selectedItem = nil
                isLivePhoto = false  // Reset live photo flag
            }) {
                Image(systemName: "xmark.circle.fill")
                    .font(.system(size: 28))
                    .foregroundColor(.white)
                    .shadow(radius: 2)
            }
            .padding(12)
        }
    }
    
    // MARK: - Photo Picker Buttons
    private var photoPickerButtons: some View {
        HStack(spacing: 12) {
            PhotosPicker(selection: $selectedItem, matching: .images) {
                VStack(spacing: 8) {
                    Image(systemName: "photo.on.rectangle.angled")
                        .font(.system(size: 28))
                        .foregroundColor(.gray)
                    Text("Lägg till bild")
                        .font(.system(size: 14, weight: .medium))
                        .foregroundColor(.gray)
                }
                .frame(maxWidth: .infinity)
                .frame(height: 100)
                .background(Color(.systemGray6))
                .cornerRadius(12)
            }
            
            Button(action: {
                showLiveCapture = true
            }) {
                VStack(spacing: 8) {
                    Image(systemName: "camera.fill")
                        .font(.system(size: 28))
                        .foregroundColor(.primary)
                    Text("Up&Down Live")
                        .font(.system(size: 14, weight: .semibold))
                        .foregroundColor(.primary)
                }
                .frame(maxWidth: .infinity)
                .frame(height: 100)
                .background(
                    LinearGradient(
                        colors: [Color.white, Color(.systemGray5)],
                        startPoint: .top,
                        endPoint: .bottom
                    )
                )
                .cornerRadius(12)
                .overlay(
                    RoundedRectangle(cornerRadius: 12)
                        .stroke(Color.black.opacity(0.1), lineWidth: 1)
                )
            }
        }
    }
    
    // MARK: - Gym Template Toggle
    @ViewBuilder
    private var gymTemplateToggle: some View {
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
                Text("Spara som mall")
                    .font(.system(size: 16, weight: .medium))
            }
            .padding(.horizontal, 16)
            .toggleStyle(SwitchToggleStyle(tint: .black))
        }
    }
    
    // MARK: - Save Button
    private var saveButton: some View {
        Button(action: {
            // Immediately block further taps
            guard !saveButtonTapped else { return }
            saveButtonTapped = true
            saveWorkout()
        }) {
            HStack {
                Spacer()
                if isSaving || saveButtonTapped {
                    ProgressView()
                        .tint(.white)
                } else {
                    Text("Spara pass")
                        .font(.system(size: 17, weight: .semibold))
                }
                Spacer()
            }
            .frame(height: 54)
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .frame(maxWidth: .infinity)
        .frame(height: 54)
        .background(saveButtonTapped ? Color.gray : Color.black)
        .foregroundColor(.white)
        .cornerRadius(27)
        .disabled(saveButtonTapped)
        .opacity(saveButtonTapped ? 0.7 : 1.0)
        .padding(.horizontal, 40)
        .padding(.top, 20)
        .padding(.bottom, 40)
        .allowsHitTesting(!saveButtonTapped)
    }
    
    // MARK: - Delete Confirmation Overlay
    @ViewBuilder
    private var deleteConfirmationOverlay: some View {
        if showDeleteConfirmation {
            ZStack {
                Color.black.opacity(0.4)
                    .ignoresSafeArea()
                
                VStack(spacing: 20) {
                    Text("Vill du verkligen radera passet?")
                        .font(.system(size: 18, weight: .bold))
                        .multilineTextAlignment(.center)
                    
                    Text("Alla data kommer att försvinna")
                        .font(.system(size: 14))
                        .foregroundColor(.gray)
                    
                    HStack(spacing: 16) {
                        Button(action: {
                            showDeleteConfirmation = false
                        }) {
                            Text("Avbryt")
                                .font(.system(size: 16, weight: .medium))
                                .frame(maxWidth: .infinity)
                                .padding(12)
                                .background(Color(.systemGray5))
                                .foregroundColor(.primary)
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
                .background(Color(.secondarySystemBackground))
                .cornerRadius(16)
                .shadow(radius: 20)
                .padding(40)
            }
        }
    }
    
    // MARK: - Template Name Sheet
    private var templateNameSheet: some View {
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
                        if !templateName.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
                            shouldSaveTemplate = true
                            showSaveTemplateSheet = false
                        }
                    }
                }
            }
            .presentationDetents([.medium])
        }
    }
    
    // MARK: - Live Capture Sheet
    private var liveCaptureSheet: some View {
        LivePhotoCaptureView(
            capturedImage: $sessionImage,
            onCapture: {
                isLivePhoto = true  // Mark as Up&Down Live photo
            }
        )
    }
    
    // MARK: - Handle Image Selection
    private func handleImageSelection(_ newItem: PhotosPickerItem?) {
        guard let newItem else { return }
        Task(priority: .userInitiated) {
            if let data = try? await newItem.loadTransferable(type: Data.self),
               let uiImage = UIImage(data: data) {
                await MainActor.run {
                    sessionImage = uiImage
                    isLivePhoto = false  // Regular gallery image, not Up&Down Live
                }
            }
        }
    }
    
    // MARK: - Helper Functions
    
    private func formatDuration(_ seconds: Int) -> String {
        let hours = seconds / 3600
        let minutes = (seconds % 3600) / 60
        let secs = seconds % 60
        if hours > 0 {
            return String(format: "%d:%02d:%02d", hours, minutes, secs)
        } else {
            return String(format: "%d:%02d", minutes, secs)
        }
    }
    
    private func formatPace(distance: Double, duration: Int) -> String {
        guard distance > 0 else { return "0:00" }
        let paceSeconds = Double(duration) / distance
        let paceMinutes = Int(paceSeconds) / 60
        let paceSecs = Int(paceSeconds) % 60
        return String(format: "%d:%02d", paceMinutes, paceSecs)
    }
    
    private func formatVolume(_ volume: Int) -> String {
        if volume >= 1000 {
            let thousands = Double(volume) / 1000.0
            return String(format: "%.1f k kg", thousands)
        }
        return "\(volume) kg"
    }
    
    // MARK: - Gym Header Section
    private var gymHeaderSection: some View {
        VStack(spacing: 0) {
            // Top bar with close button
            HStack {
                Spacer()
                Button(action: {
                    showDeleteConfirmation = true
                }) {
                    Image(systemName: "xmark")
                        .font(.system(size: 16, weight: .medium))
                        .foregroundColor(.primary)
                        .padding(10)
                        .background(Color(.systemGray6))
                        .clipShape(Circle())
                }
            }
            .padding(.horizontal, 16)
            .padding(.top, 60)
            
            // Gym icon and XP earned
            VStack(spacing: 16) {
                ZStack {
                    Circle()
                        .fill(Color.black)
                        .frame(width: 80, height: 80)
                    
                    Image(systemName: "dumbbell.fill")
                        .font(.system(size: 36, weight: .bold))
                        .foregroundColor(.white)
                }
                
                // XP earned
                HStack(alignment: .firstTextBaseline, spacing: 4) {
                    Text("+\(earnedPoints)")
                        .font(.system(size: 36, weight: .black))
                    Text("XP")
                        .font(.system(size: 18, weight: .bold))
                        .foregroundColor(.secondary)
                }
            }
            .padding(.vertical, 24)
        }
    }
    
    func saveWorkout() {
        // Guard against double-taps - check both flags
        guard !isSaving else {
            print("⚠️ Save already in progress, ignoring duplicate tap")
            return
        }
        
        // Set both flags immediately to block any further interaction
        isSaving = true
        saveButtonTapped = true
        
        Task(priority: .userInitiated) {
            
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
            
            // Use the title (which has default value set)
            let finalTitle = title.isEmpty ? defaultTitle : title
            
            // Convert route coordinates to JSON string for database storage
            var routeDataJson: String? = nil
            if !routeCoordinates.isEmpty {
                let coordsArray = routeCoordinates.map { ["lat": $0.latitude, "lon": $0.longitude] }
                if let jsonData = try? JSONSerialization.data(withJSONObject: coordsArray),
                   let jsonString = String(data: jsonData, encoding: .utf8) {
                    routeDataJson = jsonString
                    print("📍 Route data prepared: \(routeCoordinates.count) coordinates")
                }
            }
            
            let post = WorkoutPost(
                userId: authViewModel.currentUser?.id ?? "",
                activityType: activity.rawValue,
                title: finalTitle,
                description: description,
                distance: distance,
                duration: duration,
                imageUrl: nil,
                userImageUrl: nil,
                elevationGain: elevationGain,
                maxSpeed: maxSpeed,
                splits: splits.isEmpty ? nil : splits,
                exercises: exercisesData,
                routeData: routeDataJson,
                pbExerciseName: hasPB ? pbExerciseName : nil,
                pbValue: hasPB ? pbValue : nil
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
                
                try await WorkoutService.shared.saveWorkoutPost(post, routeImage: routeImage, userImage: sessionImage, earnedPoints: pointsToAward, isLivePhoto: isLivePhoto)
                
                let sharePost = SocialWorkoutPost(
                    from: post,
                    userName: authViewModel.currentUser?.name,
                    userAvatarUrl: authViewModel.currentUser?.avatarUrl,
                    userIsPro: RevenueCatManager.shared.isProMember
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
                
                // Send PB notification to followers if user set a new PB
                if hasPB, let userId = authViewModel.currentUser?.id {
                    Task {
                        await PushNotificationService.shared.notifyFollowersAboutPB(
                            userId: userId,
                            userName: authViewModel.currentUser?.name ?? "En användare",
                            userAvatar: authViewModel.currentUser?.avatarUrl,
                            exerciseName: pbExerciseName,
                            pbValue: pbValue,
                            postId: post.id
                        )
                    }
                }
                
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
        
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.8) {
            withAnimation(.easeInOut(duration: 0.2)) {
                successOpacity = 0.0
            }
        }
        
        DispatchQueue.main.asyncAfter(deadline: .now() + 1.0) {
            showSaveSuccess = false
            isPresented = false
            onComplete()
            
            // Navigate to social tab
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) {
                NotificationCenter.default.post(name: NSNotification.Name("NavigateToSocial"), object: nil)
            }
        }
    }
    
    private func initializeMapRegion() {
        guard !mapInitialized else { return }
        mapInitialized = true
        
        if routeCoordinates.count >= 2 {
            // Calculate bounding box for route
            let lats = routeCoordinates.map { $0.latitude }
            let lons = routeCoordinates.map { $0.longitude }
            
            guard let minLat = lats.min(),
                  let maxLat = lats.max(),
                  let minLon = lons.min(),
                  let maxLon = lons.max() else {
                // Fallback to Stockholm
                mapRegion = MKCoordinateRegion(
                    center: CLLocationCoordinate2D(latitude: 59.3293, longitude: 18.0686),
                    span: MKCoordinateSpan(latitudeDelta: 0.05, longitudeDelta: 0.05)
                )
                return
            }
            
            let centerLat = (minLat + maxLat) / 2
            let centerLon = (minLon + maxLon) / 2
            let spanLat = (maxLat - minLat) * 1.5  // Add some padding
            let spanLon = (maxLon - minLon) * 1.5
            
            // Ensure minimum span
            let finalSpanLat = max(spanLat, 0.005)
            let finalSpanLon = max(spanLon, 0.005)
            
            mapRegion = MKCoordinateRegion(
                center: CLLocationCoordinate2D(latitude: centerLat, longitude: centerLon),
                span: MKCoordinateSpan(latitudeDelta: finalSpanLat, longitudeDelta: finalSpanLon)
            )
        } else if let firstCoord = routeCoordinates.first {
            // Single point - zoom in on it
            mapRegion = MKCoordinateRegion(
                center: firstCoord,
                span: MKCoordinateSpan(latitudeDelta: 0.01, longitudeDelta: 0.01)
            )
        } else {
            // No route - show Stockholm as default
            mapRegion = MKCoordinateRegion(
                center: CLLocationCoordinate2D(latitude: 59.3293, longitude: 18.0686),
                span: MKCoordinateSpan(latitudeDelta: 0.1, longitudeDelta: 0.1)
            )
        }
    }
}

// MARK: - MapKit UIViewRepresentable for Route

struct RouteMapView: UIViewRepresentable {
    let coordinates: [CLLocationCoordinate2D]
    @Binding var region: MKCoordinateRegion
    
    func makeUIView(context: Context) -> MKMapView {
        let mapView = MKMapView()
        mapView.delegate = context.coordinator
        mapView.showsUserLocation = false
        mapView.isZoomEnabled = true
        mapView.isScrollEnabled = true
        mapView.isPitchEnabled = false
        mapView.isRotateEnabled = false
        return mapView
    }
    
    func updateUIView(_ mapView: MKMapView, context: Context) {
        // Update region
        mapView.setRegion(region, animated: false)
        
        // Remove old overlays
        mapView.removeOverlays(mapView.overlays)
        mapView.removeAnnotations(mapView.annotations)
        
        // Add route polyline
        if coordinates.count >= 2 {
            let polyline = MKPolyline(coordinates: coordinates, count: coordinates.count)
            mapView.addOverlay(polyline)
            
            // Add start point annotation
            if let startCoord = coordinates.first {
                let startAnnotation = MKPointAnnotation()
                startAnnotation.coordinate = startCoord
                startAnnotation.title = "Start"
                mapView.addAnnotation(startAnnotation)
            }
            
            // Add end point annotation
            if let endCoord = coordinates.last, coordinates.count > 1 {
                let endAnnotation = MKPointAnnotation()
                endAnnotation.coordinate = endCoord
                endAnnotation.title = "Slut"
                mapView.addAnnotation(endAnnotation)
            }
        }
    }
    
    func makeCoordinator() -> Coordinator {
        Coordinator(self)
    }
    
    class Coordinator: NSObject, MKMapViewDelegate {
        var parent: RouteMapView
        
        init(_ parent: RouteMapView) {
            self.parent = parent
        }
        
        func mapView(_ mapView: MKMapView, rendererFor overlay: MKOverlay) -> MKOverlayRenderer {
            if let polyline = overlay as? MKPolyline {
                let renderer = MKPolylineRenderer(polyline: polyline)
                renderer.strokeColor = .black
                renderer.lineWidth = 4
                renderer.lineCap = .round
                renderer.lineJoin = .round
                return renderer
            }
            return MKOverlayRenderer(overlay: overlay)
        }
        
        func mapView(_ mapView: MKMapView, viewFor annotation: MKAnnotation) -> MKAnnotationView? {
            guard !(annotation is MKUserLocation) else { return nil }
            
            let identifier = "RoutePoint"
            var annotationView = mapView.dequeueReusableAnnotationView(withIdentifier: identifier)
            
            if annotationView == nil {
                annotationView = MKAnnotationView(annotation: annotation, reuseIdentifier: identifier)
            } else {
                annotationView?.annotation = annotation
            }
            
            // Create custom marker
            let size: CGFloat = 14
            let view = UIView(frame: CGRect(x: 0, y: 0, width: size, height: size))
            view.backgroundColor = annotation.title == "Start" ? .systemGreen : .systemRed
            view.layer.cornerRadius = size / 2
            view.layer.borderWidth = 2
            view.layer.borderColor = UIColor.white.cgColor
            
            let renderer = UIGraphicsImageRenderer(size: CGSize(width: size, height: size))
            annotationView?.image = renderer.image { ctx in
                view.layer.render(in: ctx.cgContext)
            }
            
            annotationView?.canShowCallout = false
            
            return annotationView
        }
        
        func mapView(_ mapView: MKMapView, regionDidChangeAnimated animated: Bool) {
            DispatchQueue.main.async {
                self.parent.region = mapView.region
            }
        }
    }
}

// MARK: - Color Extension for Hex

extension Color {
    init(hex: String) {
        let hex = hex.trimmingCharacters(in: CharacterSet.alphanumerics.inverted)
        var int: UInt64 = 0
        Scanner(string: hex).scanHexInt64(&int)
        let a, r, g, b: UInt64
        switch hex.count {
        case 3: // RGB (12-bit)
            (a, r, g, b) = (255, (int >> 8) * 17, (int >> 4 & 0xF) * 17, (int & 0xF) * 17)
        case 6: // RGB (24-bit)
            (a, r, g, b) = (255, int >> 16, int >> 8 & 0xFF, int & 0xFF)
        case 8: // ARGB (32-bit)
            (a, r, g, b) = (int >> 24, int >> 16 & 0xFF, int >> 8 & 0xFF, int & 0xFF)
        default:
            (a, r, g, b) = (1, 1, 1, 0)
        }
        self.init(
            .sRGB,
            red: Double(r) / 255,
            green: Double(g) / 255,
            blue:  Double(b) / 255,
            opacity: Double(a) / 255
        )
    }
}

#Preview {
    SessionCompleteView(
        activity: .running, 
        distance: 5.2, 
        duration: 1800, 
        earnedPoints: 10,
        routeImage: nil,
        routeCoordinates: [
            CLLocationCoordinate2D(latitude: 59.3293, longitude: 18.0686),
            CLLocationCoordinate2D(latitude: 59.3310, longitude: 18.0700),
            CLLocationCoordinate2D(latitude: 59.3320, longitude: 18.0650)
        ],
        elevationGain: nil,
        maxSpeed: nil,
        completedSplits: [],
        gymExercises: nil,
        sessionLivePhoto: nil,
        isPresented: .constant(true),
        onComplete: {},
        onDelete: {}
    )
    .environmentObject(AuthViewModel())
}
