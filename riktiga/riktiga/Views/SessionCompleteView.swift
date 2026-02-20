import SwiftUI
import PhotosUI
import MapKit
import CoreLocation
import ConfettiSwiftUI

struct SessionCompleteView: View {
    @StateObject private var stravaService = StravaService.shared
    @StateObject private var celebrationManager = CelebrationManager.shared
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
    var gymSessionStartTime: Date? = nil  // For gym: when session started
    var gymSessionLatitude: Double? = nil  // For gym: session location
    var gymSessionLongitude: Double? = nil
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
    @State private var showCelebration = false
    @State private var celebrationPost: SocialWorkoutPost?
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
    
    // Trained with friends detection
    @State private var trainedWithFriends: [ActiveSessionService.TrainedWithFriend] = []
    @State private var includeTrainedWith = true // Pre-selected by default
    @State private var isLoadingTrainedWith = false
    @State private var sessionStartTime: Date?
    @State private var sessionLocation: CLLocationCoordinate2D?
    @State private var detectedGymName: String?
    
    // Gym location search
    @State private var showGymSearchSheet = false
    @State private var gymSearchResults: [MKMapItem] = []
    @State private var isSearchingGyms = false
    
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
        .fullScreenCover(isPresented: $showCelebration) {
            if let sharePost = celebrationPost {
                WorkoutCelebrationView(post: sharePost) {
                    // On dismiss from celebration view - delay to let animation complete
                    DispatchQueue.main.asyncAfter(deadline: .now() + 0.3) {
                        isPresented = false
                        onComplete()
                        
                        // Navigate to social tab
                        DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) {
                            NotificationCenter.default.post(name: NSNotification.Name("NavigateToSocial"), object: nil)
                        }
                    }
                }
            }
        }
        .onAppear {
            // If a live photo was taken during the session, use it
            if let livePhoto = sessionLivePhoto {
                sessionImage = livePhoto
                isLivePhoto = true
            }
            
            // Load trained-with friends and detect gym for gym sessions
            if isGymWorkout {
                Task {
                    // Auto-search and select closest gym
                    await searchAndSelectClosestGym()
                    // Load trained-with friends
                    await loadTrainedWithFriends()
                }
            }
        }
        .confettiCannon(
            counter: $celebrationManager.confettiCounter,
            num: celebrationManager.confettiCount,
            colors: celebrationManager.confettiColors,
            confettiSize: celebrationManager.confettiSize,
            rainHeight: celebrationManager.rainHeight,
            radius: celebrationManager.radius,
            repetitions: celebrationManager.repetitions,
            repetitionInterval: celebrationManager.repetitionInterval
        )
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
    @ViewBuilder
    private var contentSection: some View {
        if isGymWorkout {
            gymContentSection
        } else {
            VStack(spacing: 24) {
                titleSection
                difficultySliderSection
                descriptionSection
                photoOptionsSection
                saveButton
            }
        }
    }
    
    // MARK: - Gym Content Section (Strava-style)
    private var gymContentSection: some View {
        VStack(spacing: 0) {
            // Title input field
            gymTitleField
            
            // Description field
            gymDescriptionField
            
            // Activity type row
            gymActivityTypeRow
            
            // Photo and exercises preview
            gymMediaSection
            
            // Details section
            gymDetailsSection
            
            // Save button
            gymSaveButton
        }
    }
    
    // MARK: - Gym Title Field
    private var gymTitleField: some View {
        VStack(spacing: 0) {
            TextField("Morgonpass", text: $title)
                .font(.system(size: 17))
                .padding(.horizontal, 16)
                .padding(.vertical, 16)
                .background(Color(.systemBackground))
                .overlay(
                    RoundedRectangle(cornerRadius: 10)
                        .stroke(Color(.systemGray4), lineWidth: 1)
                )
                .padding(.horizontal, 16)
                .padding(.top, 16)
        }
    }
    
    // MARK: - Gym Description Field
    private var gymDescriptionField: some View {
        ZStack(alignment: .topLeading) {
            if description.isEmpty {
                Text("Berätta om ditt pass för dina vänner!")
                    .font(.system(size: 17))
                    .foregroundColor(Color(.placeholderText))
                    .padding(.horizontal, 20)
                    .padding(.vertical, 18)
            }
            
            TextEditor(text: $description)
                .font(.system(size: 17))
                .frame(minHeight: 80)
                .padding(.horizontal, 12)
                .padding(.vertical, 10)
                .scrollContentBackground(.hidden)
                .background(Color(.systemBackground))
        }
        .overlay(
            RoundedRectangle(cornerRadius: 10)
                .stroke(Color(.systemGray4), lineWidth: 1)
        )
        .padding(.horizontal, 16)
        .padding(.top, 12)
    }
    
    // MARK: - Gym Activity Type Row
    private var gymActivityTypeRow: some View {
        HStack {
            Image(systemName: "dumbbell.fill")
                .font(.system(size: 18))
                .foregroundColor(.primary)
            
            Text("Gympass")
                .font(.system(size: 17))
                .foregroundColor(.primary)
            
            Spacer()
            
            Image(systemName: "chevron.down")
                .font(.system(size: 14, weight: .medium))
                .foregroundColor(.gray)
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 16)
        .background(Color(.systemBackground))
        .overlay(
            RoundedRectangle(cornerRadius: 10)
                .stroke(Color(.systemGray4), lineWidth: 1)
        )
        .padding(.horizontal, 16)
        .padding(.top, 12)
    }
    
    // MARK: - Gym Media Section
    private var gymMediaSection: some View {
        VStack(spacing: 12) {
            // Exercises summary card with stats
            VStack(alignment: .leading, spacing: 8) {
                // Exercise count
                HStack(spacing: 4) {
                    Image(systemName: "list.bullet.clipboard")
                        .font(.system(size: 14))
                        .foregroundColor(.gray)
                    
                    Text("\(gymExercises?.count ?? 0) övningar")
                        .font(.system(size: 13))
                        .foregroundColor(.gray)
                }
                
                // Stats - Tid and Volym
                HStack(spacing: 24) {
                    VStack(alignment: .leading, spacing: 2) {
                        Text(formatDuration(duration))
                            .font(.system(size: 22, weight: .bold))
                        Text("Tid")
                            .font(.system(size: 12))
                            .foregroundColor(.gray)
                    }
                    
                    VStack(alignment: .leading, spacing: 2) {
                        Text(formatVolume(gymVolume))
                            .font(.system(size: 22, weight: .bold))
                        Text("Volym")
                            .font(.system(size: 12))
                            .foregroundColor(.gray)
                    }
                    
                    Spacer()
                }
                .padding(.top, 4)
            }
            .padding(14)
            .frame(maxWidth: .infinity, alignment: .leading)
            .background(Color(.systemGray6))
            .cornerRadius(12)
            
            // Photo buttons on their own row
            if sessionImage == nil {
                HStack(spacing: 10) {
                    PhotosPicker(selection: $selectedItem, matching: .images) {
                        HStack(spacing: 8) {
                            Image(systemName: "photo.on.rectangle.angled")
                                .font(.system(size: 18))
                                .foregroundColor(.gray)
                            
                            Text("Lägg till bild")
                                .font(.system(size: 14, weight: .medium))
                                .foregroundColor(.gray)
                        }
                        .frame(maxWidth: .infinity)
                        .frame(height: 50)
                        .background(Color(.systemGray6))
                        .cornerRadius(10)
                    }
                    
                    Button(action: {
                        showLiveCapture = true
                    }) {
                        HStack(spacing: 8) {
                            Image(systemName: "camera.fill")
                                .font(.system(size: 18))
                                .foregroundColor(.primary)
                            
                            Text("UP&DOWN Live")
                                .font(.system(size: 14, weight: .semibold))
                                .foregroundColor(.primary)
                        }
                        .frame(maxWidth: .infinity)
                        .frame(height: 50)
                        .background(Color(.systemGray6))
                        .cornerRadius(10)
                        .overlay(
                            RoundedRectangle(cornerRadius: 10)
                                .stroke(Color.black.opacity(0.15), lineWidth: 1)
                        )
                    }
                }
            } else {
                // Show selected image with remove button
                ZStack(alignment: .topTrailing) {
                    Image(uiImage: sessionImage!)
                        .resizable()
                        .scaledToFill()
                        .frame(height: 120)
                        .frame(maxWidth: .infinity)
                        .cornerRadius(12)
                        .clipped()
                    
                    Button(action: {
                        sessionImage = nil
                        selectedItem = nil
                        isLivePhoto = false
                    }) {
                        Image(systemName: "xmark.circle.fill")
                            .font(.system(size: 24))
                            .foregroundColor(.white)
                            .shadow(radius: 2)
                    }
                    .padding(8)
                }
            }
            
            // MARK: - Gym Location Section (Gym only)
            if isGymWorkout {
                gymLocationSection
            }
            
            // MARK: - Trained With Friends Section (Gym only)
            if isGymWorkout && !trainedWithFriends.isEmpty {
                trainedWithSection
            }
        }
        .padding(.horizontal, 16)
        .padding(.top, 12)
    }
    
    // MARK: - Trained With Section
    private var trainedWithSection: some View {
        Button(action: {
            includeTrainedWith.toggle()
        }) {
            HStack(spacing: 12) {
                // Checkbox
                Image(systemName: includeTrainedWith ? "checkmark.square.fill" : "square")
                    .font(.system(size: 22))
                    .foregroundColor(includeTrainedWith ? .green : .gray)
                
                // Text
                VStack(alignment: .leading, spacing: 2) {
                    if trainedWithFriends.count == 1 {
                        Text("Tränade du med \(trainedWithFriends[0].username)?")
                            .font(.system(size: 15, weight: .medium))
                            .foregroundColor(.primary)
                    } else {
                        Text("Tränade med \(trainedWithFriends.count) vänner")
                            .font(.system(size: 15, weight: .medium))
                            .foregroundColor(.primary)
                    }
                }
                
                Spacer()
                
                // Profile pictures (max 3)
                HStack(spacing: -8) {
                    ForEach(Array(trainedWithFriends.prefix(3).enumerated()), id: \.element.id) { index, friend in
                        ProfileImage(url: friend.avatarUrl, size: 32)
                            .overlay(
                                Circle()
                                    .stroke(Color(.systemBackground), lineWidth: 2)
                            )
                            .zIndex(Double(3 - index))
                    }
                }
            }
            .padding(14)
            .background(Color(.systemGray6))
            .cornerRadius(12)
        }
        .buttonStyle(.plain)
        .padding(.top, 8)
    }
    
    // MARK: - Gym Location Section
    private var gymLocationSection: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack(spacing: 12) {
                Image(systemName: "mappin.circle.fill")
                    .font(.system(size: 22))
                    .foregroundColor(.black)
                
                VStack(alignment: .leading, spacing: 2) {
                    Text("Plats")
                        .font(.system(size: 13))
                        .foregroundColor(.secondary)
                    
                    if let gymName = detectedGymName, !gymName.isEmpty {
                        Text(gymName)
                            .font(.system(size: 15, weight: .medium))
                            .foregroundColor(.primary)
                    } else {
                        Text("Ingen plats detekterad")
                            .font(.system(size: 15))
                            .foregroundColor(.secondary)
                    }
                }
                
                Spacer()
                
                Button(action: {
                    showGymSearchSheet = true
                }) {
                    Text("Ändra")
                        .font(.system(size: 14, weight: .medium))
                        .foregroundColor(.black)
                }
            }
            .padding(14)
            .background(Color(.systemGray6))
            .cornerRadius(12)
        }
        .padding(.top, 8)
        .sheet(isPresented: $showGymSearchSheet) {
            gymSearchSheet
        }
    }
    
    // MARK: - Gym Search Sheet
    private var gymSearchSheet: some View {
        NavigationView {
            VStack(spacing: 0) {
                if isSearchingGyms {
                    ProgressView("Söker efter gym...")
                        .padding()
                } else if gymSearchResults.isEmpty {
                    VStack(spacing: 16) {
                        Image(systemName: "mappin.slash")
                            .font(.system(size: 50))
                            .foregroundColor(.secondary)
                        Text("Inga gym hittades i närheten")
                            .font(.system(size: 17))
                            .foregroundColor(.secondary)
                    }
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
                } else {
                    List(gymSearchResults, id: \.self) { mapItem in
                        Button(action: {
                            selectGym(mapItem)
                            showGymSearchSheet = false
                        }) {
                            HStack(spacing: 12) {
                                Image(systemName: "mappin.circle.fill")
                                    .font(.system(size: 20))
                                    .foregroundColor(.black)
                                
                                VStack(alignment: .leading, spacing: 4) {
                                    Text(mapItem.name ?? "Okänt gym")
                                        .font(.system(size: 16, weight: .medium))
                                        .foregroundColor(.primary)
                                    
                                    if let address = mapItem.placemark.title {
                                        Text(address)
                                            .font(.system(size: 13))
                                            .foregroundColor(.secondary)
                                    }
                                    
                                    // Show distance
                                    if let currentLocation = GymLocationManager.shared.currentLocation {
                                        let distance = currentLocation.distance(from: CLLocation(
                                            latitude: mapItem.placemark.coordinate.latitude,
                                            longitude: mapItem.placemark.coordinate.longitude
                                        ))
                                        Text("\(Int(distance))m bort")
                                            .font(.system(size: 12))
                                            .foregroundColor(.secondary)
                                    }
                                }
                                
                                Spacer()
                                
                                Image(systemName: "chevron.right")
                                    .font(.system(size: 13, weight: .medium))
                                    .foregroundColor(.secondary)
                            }
                            .padding(.vertical, 8)
                        }
                    }
                    .listStyle(.plain)
                }
            }
            .navigationTitle("Välj gym")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button("Stäng") {
                        showGymSearchSheet = false
                    }
                }
            }
            .onAppear {
                Task {
                    await searchNearbyGyms()
                }
            }
        }
    }
    
    // MARK: - Gym Details Section
    private var gymDetailsSection: some View {
        VStack(alignment: .leading, spacing: 0) {
            Text("Detaljer")
                .font(.system(size: 20, weight: .bold))
                .padding(.horizontal, 16)
                .padding(.top, 24)
                .padding(.bottom, 12)
            
            // PB (Personal Best) row
            Button(action: {
                showPBSheet = true
            }) {
                HStack {
                    Image(systemName: hasPB ? "trophy.fill" : "trophy")
                        .font(.system(size: 18))
                        .foregroundColor(hasPB ? .yellow : .primary)
                    
                    if hasPB {
                        VStack(alignment: .leading, spacing: 2) {
                            Text("Nytt PB!")
                                .font(.system(size: 17))
                                .foregroundColor(.primary)
                            Text("\(pbExerciseName): \(pbValue)")
                                .font(.system(size: 13))
                                .foregroundColor(.gray)
                        }
                    } else {
                        Text("Tog du ett PB idag?")
                            .font(.system(size: 17))
                            .foregroundColor(.primary)
                    }
                    
                    Spacer()
                    
                    Image(systemName: "chevron.down")
                        .font(.system(size: 14, weight: .medium))
                        .foregroundColor(.gray)
                }
                .padding(.horizontal, 16)
                .padding(.vertical, 16)
                .background(Color(.systemBackground))
                .overlay(
                    RoundedRectangle(cornerRadius: 10)
                        .stroke(Color(.systemGray4), lineWidth: 1)
                )
            }
            .buttonStyle(PlainButtonStyle())
            .padding(.horizontal, 16)
            
            // Difficulty row
            VStack(alignment: .leading, spacing: 12) {
                HStack {
                    Image(systemName: "face.smiling")
                        .font(.system(size: 18))
                        .foregroundColor(.primary)
                    
                    Text("Hur kändes passet?")
                        .font(.system(size: 17))
                        .foregroundColor(.primary)
                    
                    Spacer()
                }
                
                // Difficulty slider
                VStack(spacing: 8) {
                    GeometryReader { geometry in
                        ZStack(alignment: .leading) {
                            Capsule()
                                .fill(Color.black.opacity(0.15))
                                .frame(height: 8)
                            
                            Capsule()
                                .fill(Color.black)
                                .frame(width: max(8, geometry.size.width * difficultyRating), height: 8)
                            
                            Circle()
                                .fill(Color.white)
                                .frame(width: 24, height: 24)
                                .shadow(color: .black.opacity(0.15), radius: 3, x: 0, y: 1)
                                .offset(x: max(0, (geometry.size.width - 24) * difficultyRating))
                                .gesture(
                                    DragGesture()
                                        .onChanged { value in
                                            let newValue = value.location.x / geometry.size.width
                                            difficultyRating = min(max(0, newValue), 1)
                                        }
                                )
                        }
                    }
                    .frame(height: 24)
                    
                    HStack {
                        Text("Lätt")
                            .font(.system(size: 12, weight: .medium))
                            .foregroundColor(.secondary)
                        Spacer()
                        Text("Svårt")
                            .font(.system(size: 12, weight: .medium))
                            .foregroundColor(.secondary)
                    }
                }
            }
            .padding(.horizontal, 16)
            .padding(.vertical, 16)
            .background(Color(.systemBackground))
            .overlay(
                RoundedRectangle(cornerRadius: 10)
                    .stroke(Color(.systemGray4), lineWidth: 1)
            )
            .padding(.horizontal, 16)
            .padding(.top, 12)
            
            // Save as template toggle
            if let gymExercises, !gymExercises.isEmpty {
                HStack {
                    Image(systemName: "doc.on.doc")
                        .font(.system(size: 18))
                        .foregroundColor(.primary)
                    
                    Text("Spara som mall")
                        .font(.system(size: 17))
                        .foregroundColor(.primary)
                    
                    Spacer()
                    
                    Toggle("", isOn: Binding(
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
                    ))
                    .toggleStyle(SwitchToggleStyle(tint: .black))
                    .labelsHidden()
                }
                .padding(.horizontal, 16)
                .padding(.vertical, 16)
                .background(Color(.systemBackground))
                .overlay(
                    RoundedRectangle(cornerRadius: 10)
                        .stroke(Color(.systemGray4), lineWidth: 1)
                )
                .padding(.horizontal, 16)
                .padding(.top, 12)
            }
        }
        .sheet(isPresented: $showPBSheet) {
            pbSelectionSheet
        }
    }
    
    // MARK: - Gym Save Button
    private var gymSaveButton: some View {
        Button(action: {
            guard !saveButtonTapped else { return }
            let generator = UIImpactFeedbackGenerator(style: .medium)
            generator.impactOccurred()
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
        .cornerRadius(14)
        .disabled(saveButtonTapped)
        .opacity(saveButtonTapped ? 0.7 : 1.0)
        .padding(.horizontal, 16)
        .padding(.top, 32)
        .padding(.bottom, 40)
        .allowsHitTesting(!saveButtonTapped)
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
        
        // Trigga milestone konfetti för nytt PB! 🎉
        celebrationManager.celebrateMilestone()
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
                            Text("Berätta om ditt pass för dina vänner!")
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
            
            // Strava sync indicator (only for running activities)
            if stravaService.isConnected && !isGymWorkout {
                HStack(spacing: 8) {
                    Image("59")
                        .resizable()
                        .scaledToFit()
                        .frame(width: 20, height: 20)
                    
                    Text("Synkar automatiskt med Strava")
                        .font(.system(size: 14))
                        .foregroundColor(.secondary)
                }
                .padding(.top, 4)
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
            let generator = UIImpactFeedbackGenerator(style: .medium)
            generator.impactOccurred()
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
    
    // MARK: - Load Trained With Friends
    private func loadTrainedWithFriends() async {
        guard let userId = authViewModel.currentUser?.id,
              let startTime = gymSessionStartTime,
              let latitude = gymSessionLatitude,
              let longitude = gymSessionLongitude else {
            print("⚠️ Missing data for trained-with detection")
            return
        }
        
        await MainActor.run {
            isLoadingTrainedWith = true
        }
        
        do {
            let endTime = Date()
            let friends = try await ActiveSessionService.shared.findFriendsTrainedWith(
                userId: userId,
                myStartTime: startTime,
                myEndTime: endTime,
                myLatitude: latitude,
                myLongitude: longitude
            )
            
            await MainActor.run {
                trainedWithFriends = friends
                isLoadingTrainedWith = false
                print("✅ Found \(friends.count) friends who trained with user")
            }
        } catch {
            print("❌ Error loading trained-with friends: \(error)")
            await MainActor.run {
                isLoadingTrainedWith = false
            }
        }
    }
    
    // MARK: - Gym Search Functions
    
    private func searchNearbyGyms() async {
        guard let currentLocation = GymLocationManager.shared.currentLocation else {
            print("⚠️ No current location for gym search")
            return
        }
        
        await MainActor.run {
            isSearchingGyms = true
        }
        
        let request = MKLocalSearch.Request()
        request.naturalLanguageQuery = "gym"
        request.resultTypes = [.pointOfInterest]
        request.region = MKCoordinateRegion(
            center: currentLocation.coordinate,
            latitudinalMeters: 5000, // 5 km radius
            longitudinalMeters: 5000
        )
        
        let search = MKLocalSearch(request: request)
        do {
            let response = try await search.start()
            
            // Sort by distance
            let sortedResults = response.mapItems.sorted { item1, item2 in
                let loc1 = CLLocation(latitude: item1.placemark.coordinate.latitude,
                                     longitude: item1.placemark.coordinate.longitude)
                let loc2 = CLLocation(latitude: item2.placemark.coordinate.latitude,
                                     longitude: item2.placemark.coordinate.longitude)
                return currentLocation.distance(from: loc1) < currentLocation.distance(from: loc2)
            }
            
            await MainActor.run {
                gymSearchResults = sortedResults
                isSearchingGyms = false
                print("✅ Found \(sortedResults.count) gyms nearby")
            }
        } catch {
            print("❌ Error searching for gyms: \(error)")
            await MainActor.run {
                isSearchingGyms = false
            }
        }
    }
    
    private func searchAndSelectClosestGym() async {
        guard let currentLocation = GymLocationManager.shared.currentLocation else {
            await MainActor.run {
                detectedGymName = GymLocationManager.shared.getCurrentGymName()
            }
            return
        }
        
        await MainActor.run {
            isSearchingGyms = true
        }
        
        let request = MKLocalSearch.Request()
        request.naturalLanguageQuery = "gym"
        request.resultTypes = [.pointOfInterest]
        request.region = MKCoordinateRegion(
            center: currentLocation.coordinate,
            latitudinalMeters: 5000, // 5 km radius
            longitudinalMeters: 5000
        )
        
        let search = MKLocalSearch(request: request)
        do {
            let response = try await search.start()
            
            // Sort by distance to find the actually closest gym
            let sortedByDistance = response.mapItems.sorted { item1, item2 in
                let loc1 = CLLocation(latitude: item1.placemark.coordinate.latitude,
                                     longitude: item1.placemark.coordinate.longitude)
                let loc2 = CLLocation(latitude: item2.placemark.coordinate.latitude,
                                     longitude: item2.placemark.coordinate.longitude)
                return currentLocation.distance(from: loc1) < currentLocation.distance(from: loc2)
            }
            
            await MainActor.run {
                isSearchingGyms = false
                gymSearchResults = sortedByDistance // Pre-populate for manual picker too
                if let closest = sortedByDistance.first {
                    selectGym(closest)
                    let dist = currentLocation.distance(from: CLLocation(
                        latitude: closest.placemark.coordinate.latitude,
                        longitude: closest.placemark.coordinate.longitude
                    ))
                    print("📍 Auto-selected closest gym: \(closest.name ?? "Unknown") (\(Int(dist))m away)")
                } else {
                    detectedGymName = GymLocationManager.shared.getCurrentGymName()
                }
            }
        } catch {
            print("❌ Error searching for closest gym: \(error)")
            await MainActor.run {
                isSearchingGyms = false
                detectedGymName = GymLocationManager.shared.getCurrentGymName()
            }
        }
    }
    
    private func selectGym(_ mapItem: MKMapItem) {
        detectedGymName = mapItem.name
        print("📍 Selected gym: \(mapItem.name ?? "Unknown")")
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
    
    // MARK: - Gym Header Section (Strava-style)
    private var gymHeaderSection: some View {
        VStack(spacing: 0) {
            // Navigation bar
            HStack {
                Button(action: {
                    showDeleteConfirmation = true
                }) {
                    Text("Avbryt")
                        .font(.system(size: 17, weight: .regular))
                        .foregroundColor(.primary)
                }
                
                Spacer()
                
                Text("Spara pass")
                    .font(.system(size: 17, weight: .bold))
                    .foregroundColor(.primary)
                
                Spacer()
                
                // Invisible placeholder for balance
                Text("Avbryt")
                    .font(.system(size: 17, weight: .regular))
                    .foregroundColor(.clear)
            }
            .padding(.horizontal, 16)
            .padding(.top, 60)
            .padding(.bottom, 12)
            
            Divider()
        }
    }
    
    func saveWorkout() {
        guard !isSaving else {
            print("⚠️ Save already in progress, ignoring duplicate tap")
            return
        }
        
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
                    kg: exercise.sets.map { $0.kg },
                    notes: exercise.notes
                )
            }
            
            var pointsToAward = earnedPoints
            if activity.rawValue == "Gympass" {
                let key = gymPointsKey(for: Date())
                let alreadyAwarded = UserDefaults.standard.integer(forKey: key)
                let remaining = max(0, 50 - alreadyAwarded)
                pointsToAward = min(pointsToAward, remaining)
            }
            
            let finalTitle = title.isEmpty ? defaultTitle : title
            
            var routeDataJson: String? = nil
            if !routeCoordinates.isEmpty {
                let coordsArray = routeCoordinates.map { ["lat": $0.latitude, "lon": $0.longitude] }
                if let jsonData = try? JSONSerialization.data(withJSONObject: coordsArray),
                   let jsonString = String(data: jsonData, encoding: .utf8) {
                    routeDataJson = jsonString
                }
            }
            
            let currentStreak = StreakManager.shared.currentStreak
            
            var workoutLocation: String? = nil
            if activity.rawValue == "Gympass" {
                workoutLocation = detectedGymName ?? GymLocationManager.shared.getCurrentGymName()
            } else if !routeCoordinates.isEmpty {
                let firstCoord = routeCoordinates[0]
                let location = CLLocation(latitude: firstCoord.latitude, longitude: firstCoord.longitude)
                if let placemarks = try? await CLGeocoder().reverseGeocodeLocation(location),
                   let placemark = placemarks.first {
                    let city = placemark.locality ?? placemark.subAdministrativeArea ?? ""
                    let county = placemark.administrativeArea ?? ""
                    if !city.isEmpty && !county.isEmpty {
                        workoutLocation = "\(city), \(county)"
                    } else if !city.isEmpty {
                        workoutLocation = city
                    } else if !county.isEmpty {
                        workoutLocation = county
                    }
                }
            }
            
            let trainedWithData: [WorkoutPost.TrainedWithPerson]? = (activity.rawValue == "Gympass" && includeTrainedWith && !trainedWithFriends.isEmpty) ? trainedWithFriends.map { friend in
                WorkoutPost.TrainedWithPerson(
                    id: friend.id,
                    username: friend.username,
                    avatarUrl: friend.avatarUrl
                )
            } : nil
            
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
                pbValue: hasPB ? pbValue : nil,
                streakCount: currentStreak > 0 ? currentStreak : nil,
                location: workoutLocation,
                trainedWith: trainedWithData
            )
            
            // Save template (fast, non-blocking)
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
            
            // Build context and hand off the slow work (image upload + DB insert) to PostUploadManager
            let uploadContext = PostUploadManager.UploadContext(
                post: post,
                routeImage: routeImage,
                userImage: sessionImage,
                earnedPoints: pointsToAward,
                isLivePhoto: isLivePhoto,
                activityType: activity.rawValue,
                exercisesData: exercisesData,
                userId: authViewModel.currentUser?.id,
                userName: authViewModel.currentUser?.name,
                userAvatarUrl: authViewModel.currentUser?.avatarUrl,
                hasPB: hasPB,
                pbExerciseName: pbExerciseName,
                pbValue: pbValue,
                stravaConnected: stravaService.isConnected,
                stravaTitle: finalTitle,
                stravaDescription: description,
                stravaDuration: duration,
                stravaDistance: distance,
                stravaRouteCoordinates: routeCoordinates
            )
            
            let sharePost = SocialWorkoutPost(
                from: post,
                userName: authViewModel.currentUser?.name,
                userAvatarUrl: authViewModel.currentUser?.avatarUrl,
                userIsPro: RevenueCatManager.shared.isProMember
            )
            
            await MainActor.run {
                // Fire off background upload
                PostUploadManager.shared.startUpload(context: uploadContext)
                
                isSaving = false
                shouldSaveTemplate = false
                templateName = ""
                pendingSharePost = sharePost
                triggerSaveSuccessAnimation()
                
                StreakManager.shared.registerActivityCompletion()
                AchievementManager.shared.unlock("first_workout")
                ReviewManager.shared.recordWorkoutCompleted()
                ReviewManager.shared.requestReviewAfterWorkoutIfEligible()
                NotificationManager.shared.scheduleWorkoutCompleteNotification(userName: authViewModel.currentUser?.name)
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
        // Show celebration view with the saved post
        if let sharePost = pendingSharePost {
            celebrationPost = sharePost
            showCelebration = true
        } else {
            // Fallback: just dismiss if no share post available
            isPresented = false
            onComplete()
            
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
