import SwiftUI
import MapKit
import CoreLocation

enum GymSplitType: String, CaseIterable {
    case push = "Push"
    case pull = "Pull"
    case legs = "Ben"
}

struct QuickTrackingFlowView: View {
    @Environment(\.dismiss) private var dismiss
    @EnvironmentObject var authViewModel: AuthViewModel
    
    @State private var showCamera = true
    @State private var capturedImage: UIImage?
    
    var body: some View {
        Group {
            if let image = capturedImage {
                QuickTrackPostView(capturedImage: image, onPublish: {
                    dismiss()
                }, onCancel: {
                    dismiss()
                })
                .environmentObject(authViewModel)
            } else {
                Color.black
            }
        }
        .fullScreenCover(isPresented: $showCamera) {
            LivePhotoCaptureView(capturedImage: $capturedImage, onCapture: {})
                .ignoresSafeArea()
        }
        .onChange(of: showCamera) { _, isShowing in
            if !isShowing && capturedImage == nil {
                dismiss()
            }
        }
    }
}

// MARK: - Quick Track Post View

struct QuickTrackPostView: View {
    let capturedImage: UIImage
    let onPublish: () -> Void
    let onCancel: () -> Void
    
    @EnvironmentObject var authViewModel: AuthViewModel
    
    @State private var title: String = ""
    @State private var description: String = ""
    @State private var selectedSplit: GymSplitType?
    @State private var difficultyRating: Double = 0.5
    @State private var isPublishing = false
    @State private var detectedLocation: String?
    @State private var isSearchingLocation = false
    @State private var nearbyGyms: [(name: String, location: String)] = []
    @State private var showGymPicker = false
    @State private var claimedPB = false
    
    private var xpToAward: Int {
        QuickTrackXPTracker.shared.pointsToAward()
    }
    
    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(spacing: 20) {
                    xpBanner
                    photoPreview
                    titleSection
                    descriptionSection
                    splitPicker
                    pbToggleSection
                    difficultySlider
                    publishButton
                }
                .padding(.bottom, 40)
            }
            .background(Color(.systemGroupedBackground))
            .navigationTitle(L.t(sv: "Skapa inlägg", nb: "Opprett innlegg"))
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarLeading) {
                    Button(L.t(sv: "Avbryt", nb: "Avbryt")) {
                        onCancel()
                    }
                }
            }
            .task {
                await detectGymLocation()
            }
            .sheet(isPresented: $showGymPicker) {
                gymPickerSheet
            }
        }
    }
    
    private var gymPickerSheet: some View {
        NavigationStack {
            List {
                ForEach(Array(nearbyGyms.enumerated()), id: \.offset) { _, gym in
                    Button {
                        detectedLocation = gym.location
                        showGymPicker = false
                    } label: {
                        HStack {
                            VStack(alignment: .leading, spacing: 2) {
                                Text(gym.name)
                                    .font(.system(size: 16, weight: .medium))
                                    .foregroundColor(.primary)
                                Text(gym.location)
                                    .font(.system(size: 13))
                                    .foregroundColor(.secondary)
                            }
                            Spacer()
                            if detectedLocation == gym.location {
                                Image(systemName: "checkmark")
                                    .font(.system(size: 14, weight: .semibold))
                                    .foregroundColor(.blue)
                            }
                        }
                    }
                }
            }
            .navigationTitle(L.t(sv: "Välj gym", nb: "Velg gym"))
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button(L.t(sv: "Klar", nb: "Ferdig")) {
                        showGymPicker = false
                    }
                    .fontWeight(.semibold)
                }
            }
        }
        .presentationDetents([.medium])
    }
    
    // MARK: - Gym Location Detection
    
    private func detectGymLocation() async {
        GymLocationManager.shared.requestPermissions()
        
        try? await Task.sleep(nanoseconds: 500_000_000)
        
        guard let currentLocation = GymLocationManager.shared.currentLocation else {
            return
        }
        
        await MainActor.run { isSearchingLocation = true }
        
        let request = MKLocalSearch.Request()
        request.naturalLanguageQuery = "gym"
        request.resultTypes = [.pointOfInterest]
        request.region = MKCoordinateRegion(
            center: currentLocation.coordinate,
            latitudinalMeters: 5000,
            longitudinalMeters: 5000
        )
        
        let search = MKLocalSearch(request: request)
        do {
            let response = try await search.start()
            let sortedByDistance = response.mapItems.sorted { item1, item2 in
                let loc1 = CLLocation(latitude: item1.placemark.coordinate.latitude,
                                     longitude: item1.placemark.coordinate.longitude)
                let loc2 = CLLocation(latitude: item2.placemark.coordinate.latitude,
                                     longitude: item2.placemark.coordinate.longitude)
                return currentLocation.distance(from: loc1) < currentLocation.distance(from: loc2)
            }
            
            var gymList: [(name: String, location: String)] = []
            for item in sortedByDistance {
                let gymName = item.name ?? ""
                guard !gymName.isEmpty else { continue }
                let city = item.placemark.locality ?? item.placemark.subAdministrativeArea ?? ""
                let county = item.placemark.administrativeArea ?? ""
                let geo: String? = if !city.isEmpty && !county.isEmpty {
                    "\(city), \(county)"
                } else if !city.isEmpty {
                    city
                } else if !county.isEmpty {
                    county
                } else {
                    nil
                }
                let formatted = if let geo { "\(gymName) · \(geo)" } else { gymName }
                gymList.append((name: gymName, location: formatted))
            }
            
            await MainActor.run {
                nearbyGyms = gymList
                detectedLocation = gymList.first?.location
                isSearchingLocation = false
            }
            
            if gymList.isEmpty {
                await reverseGeocodeOnly(location: currentLocation)
            }
        } catch {
            await reverseGeocodeOnly(location: currentLocation)
        }
    }
    
    private func reverseGeocodeOnly(location: CLLocation) async {
        if let placemarks = try? await CLGeocoder().reverseGeocodeLocation(location),
           let placemark = placemarks.first {
            let city = placemark.locality ?? placemark.subAdministrativeArea ?? ""
            let county = placemark.administrativeArea ?? ""
            let geo: String? = if !city.isEmpty && !county.isEmpty {
                "\(city), \(county)"
            } else if !city.isEmpty {
                city
            } else if !county.isEmpty {
                county
            } else {
                nil
            }
            await MainActor.run {
                detectedLocation = geo
                isSearchingLocation = false
            }
        } else {
            await MainActor.run { isSearchingLocation = false }
        }
    }
    
    // MARK: - XP Banner
    
    private var xpBanner: some View {
        VStack(spacing: 8) {
            HStack {
                if xpToAward > 0 {
                    Text(L.t(sv: "+\(xpToAward) XP", nb: "+\(xpToAward) XP"))
                        .font(.system(size: 16, weight: .bold))
                } else {
                    Text(L.t(sv: "0 XP (redan trackad idag)", nb: "0 XP (allerede tracket i dag)"))
                        .font(.system(size: 14, weight: .medium))
                        .foregroundColor(.secondary)
                }
                
                Spacer()
                
                Text(L.t(sv: "Snabb tracking", nb: "Rask tracking"))
                    .font(.system(size: 13, weight: .medium))
                    .foregroundColor(.secondary)
            }
            
            if let location = detectedLocation {
                Button { showGymPicker = true } label: {
                    HStack(spacing: 6) {
                        Image(systemName: "mappin.and.ellipse")
                            .font(.system(size: 13))
                            .foregroundColor(.secondary)
                        Text(location)
                            .font(.system(size: 13))
                            .foregroundColor(.secondary)
                            .lineLimit(1)
                        Spacer()
                        if nearbyGyms.count > 1 {
                            Text(L.t(sv: "Byt", nb: "Bytt"))
                                .font(.system(size: 12, weight: .medium))
                                .foregroundColor(.blue)
                        }
                    }
                }
                .buttonStyle(.plain)
            } else if isSearchingLocation {
                HStack(spacing: 6) {
                    ProgressView()
                        .scaleEffect(0.7)
                    Text(L.t(sv: "Söker gym...", nb: "Søker gym..."))
                        .font(.system(size: 13))
                        .foregroundColor(.secondary)
                    Spacer()
                }
            }
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 12)
        .background(Color(.systemBackground))
        .cornerRadius(12)
        .padding(.horizontal, 16)
        .padding(.top, 8)
    }
    
    // MARK: - Photo Preview
    
    private var photoPreview: some View {
        Image(uiImage: capturedImage)
            .resizable()
            .aspectRatio(contentMode: .fit)
            .cornerRadius(16)
            .padding(.horizontal, 16)
    }
    
    // MARK: - Title Section
    
    private var titleSection: some View {
        VStack(spacing: 0) {
            TextField(L.t(sv: "Morgonpass", nb: "Morgenøkt"), text: $title)
                .font(.system(size: 17))
                .padding(.horizontal, 16)
                .padding(.vertical, 16)
                .background(Color(.systemBackground))
                .overlay(
                    RoundedRectangle(cornerRadius: 10)
                        .stroke(Color(.systemGray4), lineWidth: 1)
                )
                .padding(.horizontal, 16)
        }
    }
    
    // MARK: - Description Section
    
    private var descriptionSection: some View {
        ZStack(alignment: .topLeading) {
            if description.isEmpty {
                Text(L.t(sv: "Skriv hur passet gick...", nb: "Skriv hvordan økten gikk..."))
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
    }
    
    // MARK: - Split Picker (Push / Pull / Ben)
    
    private var splitPicker: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text(L.t(sv: "Typ av pass", nb: "Type økt"))
                .font(.system(size: 16, weight: .bold))
                .padding(.horizontal, 16)
            
            HStack(spacing: 10) {
                ForEach(GymSplitType.allCases, id: \.self) { split in
                    Button {
                        withAnimation(.easeInOut(duration: 0.2)) {
                            if selectedSplit == split {
                                selectedSplit = nil
                            } else {
                                selectedSplit = split
                            }
                        }
                    } label: {
                        Text(split.rawValue)
                            .font(.system(size: 15, weight: .semibold))
                            .foregroundColor(selectedSplit == split ? .white : .primary)
                            .frame(maxWidth: .infinity)
                            .padding(.vertical, 14)
                            .background(selectedSplit == split ? Color.black : Color(.systemBackground))
                            .cornerRadius(12)
                            .overlay(
                                RoundedRectangle(cornerRadius: 12)
                                    .stroke(Color(.systemGray4), lineWidth: selectedSplit == split ? 0 : 1)
                            )
                    }
                    .buttonStyle(.plain)
                }
            }
            .padding(.horizontal, 16)
            
            Text(L.t(sv: "Valfritt", nb: "Valgfritt"))
                .font(.system(size: 12))
                .foregroundColor(.secondary)
                .padding(.horizontal, 16)
        }
    }
    
    // MARK: - PB Toggle
    
    private var pbToggleSection: some View {
        Button {
            withAnimation(.easeInOut(duration: 0.2)) {
                claimedPB.toggle()
            }
        } label: {
            HStack(spacing: 12) {
                Image(systemName: claimedPB ? "checkmark.circle.fill" : "circle")
                    .font(.system(size: 22))
                    .foregroundColor(claimedPB ? .black : Color(.systemGray3))
                
                Text(L.t(sv: "Tog du ett PB idag?", nb: "Tok du en PB i dag?"))
                    .font(.system(size: 16, weight: .medium))
                    .foregroundColor(.primary)
                
                Spacer()
            }
            .padding(.horizontal, 16)
            .padding(.vertical, 14)
            .background(Color(.systemBackground))
            .cornerRadius(12)
            .overlay(
                RoundedRectangle(cornerRadius: 12)
                    .stroke(claimedPB ? Color.black : Color(.systemGray4), lineWidth: claimedPB ? 2 : 1)
            )
        }
        .buttonStyle(.plain)
        .padding(.horizontal, 16)
    }
    
    // MARK: - Difficulty Slider
    
    private var difficultySlider: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text(L.t(sv: "Hur tufft var passet", nb: "Hvor tøff var økten"))
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
                    Text(L.t(sv: "Lätt", nb: "Lett"))
                        .font(.system(size: 13, weight: .medium))
                        .foregroundColor(.secondary)
                    Spacer()
                    Text(L.t(sv: "Svårt", nb: "Hardt"))
                        .font(.system(size: 13, weight: .medium))
                        .foregroundColor(.secondary)
                }
            }
        }
        .padding(.horizontal, 16)
    }
    
    // MARK: - Publish Button
    
    private var publishButton: some View {
        Button {
            publishPost()
        } label: {
            HStack(spacing: 8) {
                if isPublishing {
                    ProgressView()
                        .tint(.white)
                } else {
                    Image(systemName: "paperplane.fill")
                }
                Text(L.t(sv: "Publicera", nb: "Publiser"))
                    .font(.system(size: 18, weight: .bold))
            }
            .foregroundColor(.white)
            .frame(maxWidth: .infinity)
            .padding(.vertical, 16)
            .background(isPublishing ? Color.gray : Color.black)
            .cornerRadius(14)
        }
        .disabled(isPublishing)
        .padding(.horizontal, 16)
        .padding(.top, 8)
    }
    
    // MARK: - Publish Logic
    
    private func publishPost() {
        guard !isPublishing else { return }
        isPublishing = true
        
        let userId = authViewModel.currentUser?.id ?? ""
        let currentStreak = StreakManager.shared.currentStreak
        
        var finalTitle = title.trimmingCharacters(in: .whitespacesAndNewlines)
        if finalTitle.isEmpty {
            finalTitle = L.t(sv: "Gympass", nb: "Treningsøkt")
        }
        
        if let split = selectedSplit {
            finalTitle = "\(split.rawValue) – \(finalTitle)"
        }
        
        let pointsToAward = QuickTrackXPTracker.shared.pointsToAward()
        
        let post = WorkoutPost(
            userId: userId,
            activityType: "Gympass",
            title: finalTitle,
            description: description.isEmpty ? nil : description,
            distance: nil,
            duration: nil,
            streakCount: currentStreak > 0 ? currentStreak : nil,
            location: detectedLocation,
            isPublic: true
        )
        
        let uploadContext = PostUploadManager.UploadContext(
            post: post,
            routeImage: nil,
            userImage: capturedImage,
            userImages: [capturedImage],
            earnedPoints: pointsToAward,
            isLivePhoto: true,
            activityType: "Gympass",
            exercisesData: nil,
            userId: userId,
            userName: authViewModel.currentUser?.name,
            userAvatarUrl: authViewModel.currentUser?.avatarUrl,
            hasPB: claimedPB,
            pbExerciseName: claimedPB ? "Gympass" : "",
            pbValue: claimedPB ? "" : "",
            stravaConnected: false,
            stravaTitle: finalTitle,
            stravaDescription: description,
            stravaDuration: 0,
            stravaDistance: 0,
            stravaRouteCoordinates: [],
            isPublic: true,
            requiresModeration: true
        )
        
        PostUploadManager.shared.startUpload(context: uploadContext)
        
        if pointsToAward > 0 {
            QuickTrackXPTracker.shared.markAwarded()
        }
        
        StreakManager.shared.registerActivityCompletion()
        
        onPublish()
    }
}

// MARK: - Tracking Type Picker View

struct TrackingTypePickerView: View {
    let onNormalTracking: () -> Void
    let onQuickTracking: () -> Void
    
    var body: some View {
        VStack(spacing: 16) {
            Capsule()
                .fill(Color(.systemGray4))
                .frame(width: 40, height: 5)
                .padding(.top, 10)
            
            Text(L.t(sv: "Välj tracking", nb: "Velg tracking"))
                .font(.system(size: 20, weight: .bold))
                .padding(.top, 4)
            
            VStack(spacing: 12) {
                trackingCard(
                    title: L.t(sv: "Tracka normalt", nb: "Track normalt"),
                    subtitle: L.t(sv: "Logga övningar, set & reps", nb: "Logg øvelser, sett & reps"),
                    badge: L.t(sv: "Ger mest poäng", nb: "Gir mest poeng")
                ) {
                    onNormalTracking()
                }
                
                trackingCard(
                    title: L.t(sv: "Snabb tracking", nb: "Rask tracking"),
                    subtitle: L.t(sv: "Ta en bild & publicera direkt", nb: "Ta et bilde & publiser direkte"),
                    badge: L.t(sv: "Nyhet", nb: "Nyhet")
                ) {
                    onQuickTracking()
                }
            }
            .padding(.horizontal, 16)
            
            Spacer()
        }
        .presentationDetents([.height(320)])
        .presentationDragIndicator(.hidden)
    }
    
    private func trackingCard(title: String, subtitle: String, badge: String, action: @escaping () -> Void) -> some View {
        Button(action: {
            let generator = UIImpactFeedbackGenerator(style: .medium)
            generator.impactOccurred()
            action()
        }) {
            HStack(spacing: 14) {
                Image("logga")
                    .resizable()
                    .aspectRatio(contentMode: .fit)
                    .frame(width: 36, height: 36)
                    .frame(width: 48, height: 48)
                    .background(Color.black)
                    .clipShape(RoundedRectangle(cornerRadius: 12))
                
                VStack(alignment: .leading, spacing: 3) {
                    HStack(spacing: 8) {
                        Text(title)
                            .font(.system(size: 17, weight: .semibold))
                            .foregroundColor(.primary)
                        
                        Text(badge)
                            .font(.system(size: 11, weight: .bold))
                            .foregroundColor(.white)
                            .padding(.horizontal, 8)
                            .padding(.vertical, 3)
                            .background(Color.black)
                            .clipShape(Capsule())
                    }
                    
                    Text(subtitle)
                        .font(.system(size: 14))
                        .foregroundColor(.secondary)
                }
                
                Spacer()
                
                Image(systemName: "chevron.right")
                    .font(.system(size: 14, weight: .medium))
                    .foregroundColor(.gray)
            }
            .padding(16)
            .background(Color(.systemBackground))
            .cornerRadius(16)
            .overlay(
                RoundedRectangle(cornerRadius: 16)
                    .stroke(Color(.systemGray4), lineWidth: 1)
            )
        }
        .buttonStyle(.plain)
    }
}
