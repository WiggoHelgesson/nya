import SwiftUI
import MapKit
import CoreLocation
import Combine

struct TrainerOnboardingView: View {
    @Environment(\.dismiss) private var dismiss
    @EnvironmentObject var authViewModel: AuthViewModel
    @StateObject private var locationManager = OnboardingLocationManager()
    
    // Edit mode support
    var isEditMode: Bool = false
    var existingTrainerId: UUID? = nil
    
    @State private var currentStep = 0
    @State private var name = ""
    // Structured description fields
    @State private var backgroundExperience = ""
    @State private var trainingPhilosophy = ""
    @State private var hourlyRate = ""
    @State private var handicap = ""
    @State private var city = ""
    @State private var clubAffiliation = ""
    @State private var experienceYears = ""
    @State private var selectedLocation: CLLocationCoordinate2D?
    @State private var serviceRadiusKm: Double = 10.0
    @State private var region = MKCoordinateRegion(
        center: CLLocationCoordinate2D(latitude: 59.3293, longitude: 18.0686),
        span: MKCoordinateSpan(latitudeDelta: 0.2, longitudeDelta: 0.2)
    )
    
    // Specialties
    @State private var allSpecialties: [TrainerSpecialty] = []
    @State private var selectedSpecialties: Set<UUID> = []
    
    // Lesson Types
    @State private var lessonTypes: [NewLessonType] = []
    @State private var showAddLessonType = false
    
    // Availability
    @State private var availability: [DayAvailability] = DayAvailability.defaultWeek()
    
    // Profile Image
    @State private var showImagePicker = false
    @State private var profileImage: UIImage?
    
    @State private var isSubmitting = false
    @State private var showConfirmation = false
    @State private var errorMessage: String?
    @State private var createdTrainerId: UUID?
    
    // Availability state
    @State private var weeklyAvailability: [WeekDayAvailability] = WeekDayAvailability.defaultWeek()
    
    // Location map state
    @State private var isMapLocked = false
    @State private var isAdjustingZoomProgrammatically = false
    
    // Loading state for edit mode
    @State private var isLoadingExistingProfile = false
    
    private let totalSteps = 7
    
    private var hasProfilePicture: Bool {
        profileImage != nil || (authViewModel.currentUser?.avatarUrl != nil && !authViewModel.currentUser!.avatarUrl!.isEmpty)
    }
    
    var body: some View {
        NavigationStack {
            ZStack {
                // Background color
                Color(.systemBackground)
                    .ignoresSafeArea()
                
                VStack(spacing: 0) {
                    // Progress indicator
                    progressIndicator
                    
                    // Content - No swiping allowed, only button navigation
                    Group {
                        switch currentStep {
                        case 0: step1NameDescription
                        case 1: step2Availability
                        case 2: step3PriceHandicap
                        case 3: step4Specialties
                        case 4: step5LessonTypes
                        case 5: step6Location
                        case 6: step7Review
                        default: step1NameDescription
                        }
                    }
                    .animation(.easeInOut, value: currentStep)
                    
                    // Navigation buttons
                    navigationButtons
                }
                
                // Loading overlay for edit mode
                if isLoadingExistingProfile {
                    Color.black.opacity(0.3)
                        .ignoresSafeArea()
                    
                    VStack(spacing: 16) {
                        ProgressView()
                            .scaleEffect(1.5)
                        Text(L.t(sv: "Laddar din profil...", nb: "Laster profilen din..."))
                            .font(.headline)
                            .foregroundColor(.white)
                    }
                    .padding(24)
                    .background(Color(.systemGray6))
                    .cornerRadius(16)
                }
            }
            .navigationTitle(isEditMode ? L.t(sv: "Hantera annons", nb: "Administrer annonse") : L.t(sv: "Bli golftränare", nb: "Bli golfinstruktør"))
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarLeading) {
                    Button(L.t(sv: "Avbryt", nb: "Avbryt")) {
                        dismiss()
                    }
                }
            }
            .task {
                await loadSpecialties()
                if isEditMode {
                    await loadExistingProfile()
                }
            }
            .alert(L.t(sv: "Fel", nb: "Feil"), isPresented: .init(
                get: { errorMessage != nil },
                set: { if !$0 { errorMessage = nil } }
            )) {
                Button("OK") { errorMessage = nil }
            } message: {
                Text(errorMessage ?? "")
            }
            .sheet(isPresented: $showAddLessonType) {
                AddLessonTypeSheet(basePrice: Int(hourlyRate) ?? 500) { newType in
                    lessonTypes.append(newType)
                }
            }
            .sheet(isPresented: $showConfirmation) {
                TrainerApplicationConfirmationView { dismiss() }
            }
        }
        .interactiveDismissDisabled() // Prevent swipe-down to dismiss
    }
    
    private func loadSpecialties() async {
        do {
            allSpecialties = try await TrainerService.shared.fetchSpecialtiesCatalog()
        } catch {
            print("❌ Failed to load specialties: \(error)")
        }
    }
    
    // MARK: - Load Existing Profile (Edit Mode)
    
    private func loadExistingProfile() async {
        isLoadingExistingProfile = true
        
        do {
            if let profile = try await TrainerService.shared.getUserTrainerProfile() {
                await MainActor.run {
                    // Pre-fill all fields with existing data
                    self.name = profile.name
                    self.hourlyRate = "\(profile.hourlyRate)"
                    self.handicap = "\(profile.handicap)"
                    
                    // Parse bio into structured fields if possible
                    if let bio = profile.bio {
                        // Try to extract structured data, fallback to full bio
                        self.backgroundExperience = bio
                    } else {
                        self.backgroundExperience = profile.description
                    }
                    
                    // Location
                    self.selectedLocation = profile.coordinate
                    self.region.center = profile.coordinate
                    
                    // Optional fields
                    if let cityVal = profile.city {
                        self.city = cityVal
                    }
                    if let club = profile.clubAffiliation {
                        self.clubAffiliation = club
                    }
                    if let years = profile.experienceYears {
                        self.experienceYears = "\(years)"
                    }
                    if let radius = profile.serviceRadiusKm {
                        self.serviceRadiusKm = radius
                    }
                    
                    // Store trainer ID for update
                    self.createdTrainerId = profile.id
                    
                    self.isLoadingExistingProfile = false
                }
            } else {
                await MainActor.run {
                    self.errorMessage = L.t(sv: "Kunde inte hitta din tränarprofil", nb: "Kunne ikke finne trenerprofilen din")
                    self.isLoadingExistingProfile = false
                }
            }
        } catch {
            await MainActor.run {
                self.errorMessage = L.t(sv: "Fel vid laddning: \(error.localizedDescription)", nb: "Feil ved lasting: \(error.localizedDescription)")
                self.isLoadingExistingProfile = false
            }
        }
    }
    
    // MARK: - Progress Indicator
    
    private var progressIndicator: some View {
        HStack(spacing: 4) {
            ForEach(0..<totalSteps, id: \.self) { step in
                Capsule()
                    .fill(step <= currentStep ? Color.black : Color.gray.opacity(0.3))
                    .frame(height: 4)
            }
        }
        .padding()
    }
    
    // MARK: - Step 1: Name & Description
    
    private var step1NameDescription: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 24) {
                VStack(alignment: .leading, spacing: 8) {
                    Text(L.t(sv: "Ditt namn", nb: "Ditt navn"))
                        .font(.headline)
                    
                    TextField(L.t(sv: "Förnamn Efternamn", nb: "Fornavn Etternavn"), text: $name)
                        .textFieldStyle(RoundedTextFieldStyle())
                }
                
                VStack(alignment: .leading, spacing: 8) {
                    HStack {
                        Image(systemName: "person.text.rectangle")
                            .foregroundColor(.primary)
                        Text(L.t(sv: "Din bakgrund", nb: "Din bakgrunn"))
                            .font(.headline)
                    }
                    
                    Text(L.t(sv: "Berätta kort om din erfarenhet som golftränare", nb: "Fortell kort om din erfaring som golfinstruktør"))
                        .font(.caption)
                        .foregroundColor(.secondary)
                    
                    TextEditor(text: $backgroundExperience)
                        .frame(height: 100)
                        .padding(8)
                        .background(Color(.systemGray6))
                        .cornerRadius(12)
                        .overlay(
                            RoundedRectangle(cornerRadius: 12)
                                .stroke(Color.gray.opacity(0.3))
                        )
                        .overlay(alignment: .topLeading) {
                            if backgroundExperience.isEmpty {
                                Text(L.t(sv: "Ex: Jag har tränat golf i 10 år och är PGA-certifierad...", nb: "Eks: Jeg har trent golf i 10 år og er PGA-sertifisert..."))
                                    .font(.body)
                                    .foregroundColor(.gray.opacity(0.5))
                                    .padding(.horizontal, 12)
                                    .padding(.vertical, 16)
                                    .allowsHitTesting(false)
                            }
                        }
                }
                
                VStack(alignment: .leading, spacing: 8) {
                    HStack {
                        Image(systemName: "lightbulb")
                            .foregroundColor(.primary)
                        Text(L.t(sv: "Din träningsfilosofi", nb: "Din treningsfilosofi"))
                            .font(.headline)
                    }
                    
                    Text(L.t(sv: "Hur brukar du lägga upp träningen?", nb: "Hvordan pleier du å legge opp treningen?"))
                        .font(.caption)
                        .foregroundColor(.secondary)
                    
                    TextEditor(text: $trainingPhilosophy)
                        .frame(height: 100)
                        .padding(8)
                        .background(Color(.systemGray6))
                        .cornerRadius(12)
                        .overlay(
                            RoundedRectangle(cornerRadius: 12)
                                .stroke(Color.gray.opacity(0.3))
                        )
                        .overlay(alignment: .topLeading) {
                            if trainingPhilosophy.isEmpty {
                                Text(L.t(sv: "Ex: Jag fokuserar på grundteknik och anpassar mig efter elevens nivå...", nb: "Eks: Jeg fokuserer på grunnleggende teknikk og tilpasser meg etter elevens nivå..."))
                                    .font(.body)
                                    .foregroundColor(.gray.opacity(0.5))
                                    .padding(.horizontal, 12)
                                    .padding(.vertical, 16)
                                    .allowsHitTesting(false)
                            }
                        }
                }
                
                Spacer()
            }
            .padding()
        }
    }
    
    // MARK: - Step 2: Availability
    
    private var step2Availability: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 24) {
                Text(L.t(sv: "När är du tillgänglig?", nb: "Når er du tilgjengelig?"))
                    .font(.title2)
                    .fontWeight(.bold)
                
                Text(L.t(sv: "Välj vilka dagar och tider du kan ta emot bokningar.", nb: "Velg hvilke dager og tider du kan ta imot bestillinger."))
                    .font(.subheadline)
                    .foregroundColor(.secondary)
                
                VStack(spacing: 12) {
                    ForEach($weeklyAvailability) { $day in
                        AvailabilityDayRow(day: $day)
                    }
                }
                
                // Tips
                VStack(alignment: .leading, spacing: 8) {
                    HStack {
                        Image(systemName: "lightbulb.fill")
                            .foregroundColor(.yellow)
                        Text(L.t(sv: "Tips", nb: "Tips"))
                            .font(.headline)
                    }
                    
                    Text(L.t(sv: "Du kan alltid ändra dina tider senare i inställningarna. Elever kan bara boka under de tider du angivit.", nb: "Du kan alltid endre tidene dine senere i innstillingene. Elever kan bare bestille i de tidene du har oppgitt."))
                        .font(.caption)
                        .foregroundColor(.secondary)
                }
                .padding()
                .background(Color.yellow.opacity(0.1))
                .cornerRadius(12)
                
                Spacer()
            }
            .padding()
        }
    }
    
    // MARK: - Step 3: Price & Handicap
    
    private var step3PriceHandicap: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 24) {
                VStack(alignment: .leading, spacing: 8) {
                    Text(L.t(sv: "Pris per timme", nb: "Pris per time"))
                        .font(.headline)
                    
                    HStack {
                        TextField(L.t(sv: "Ex: 500", nb: "Eks: 500"), text: $hourlyRate)
                            .keyboardType(.numberPad)
                            .textFieldStyle(RoundedTextFieldStyle())
                        
                        Text(L.t(sv: "kr/timme", nb: "kr/time"))
                            .foregroundColor(.secondary)
                    }
                }
                
                VStack(alignment: .leading, spacing: 8) {
                    Text(L.t(sv: "Ditt handicap", nb: "Ditt handicap"))
                        .font(.headline)
                    
                    TextField(L.t(sv: "Ex: 5", nb: "Eks: 5"), text: $handicap)
                        .keyboardType(.numberPad)
                        .textFieldStyle(RoundedTextFieldStyle())
                }
                
                VStack(alignment: .leading, spacing: 8) {
                    Text(L.t(sv: "Års erfarenhet", nb: "Års erfaring"))
                        .font(.headline)
                    
                    TextField(L.t(sv: "Ex: 10", nb: "Eks: 10"), text: $experienceYears)
                        .keyboardType(.numberPad)
                        .textFieldStyle(RoundedTextFieldStyle())
                }
                
                VStack(alignment: .leading, spacing: 8) {
                    Text(L.t(sv: "Stad", nb: "By"))
                        .font(.headline)
                    
                    TextField(L.t(sv: "Ex: Stockholm", nb: "Eks: Oslo"), text: $city)
                        .textFieldStyle(RoundedTextFieldStyle())
                }
                
                VStack(alignment: .leading, spacing: 8) {
                    Text(L.t(sv: "Klubbtillhörighet (valfritt)", nb: "Klubbtilhørighet (valgfritt)"))
                        .font(.headline)
                    
                    TextField(L.t(sv: "Ex: Djursholms GK", nb: "Eks: Oslo GK"), text: $clubAffiliation)
                        .textFieldStyle(RoundedTextFieldStyle())
                }
                
                // Tips
                VStack(alignment: .leading, spacing: 8) {
                    HStack {
                        Image(systemName: "lightbulb.fill")
                            .foregroundColor(.yellow)
                        Text(L.t(sv: "Tips", nb: "Tips"))
                            .font(.headline)
                    }
                    
                    Text(L.t(sv: "Genomsnittspriset för en golflektion i Sverige är 400-800 kr/timme. Sätt ett konkurrenskraftigt pris för att få fler bokningar!", nb: "Gjennomsnittsprisen for en golftime er 400-800 kr/time. Sett en konkurransedyktig pris for å få flere bestillinger!"))
                        .font(.caption)
                        .foregroundColor(.secondary)
                }
                .padding()
                .background(Color.yellow.opacity(0.1))
                .cornerRadius(12)
                
                Spacer()
            }
            .padding()
        }
    }
    
    // MARK: - Step 4: Specialties
    
    private var step4Specialties: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 24) {
                Text(L.t(sv: "Vad är du bra på?", nb: "Hva er du god på?"))
                    .font(.title2)
                    .fontWeight(.bold)
                
                Text(L.t(sv: "Välj dina specialområden så att elever kan hitta rätt tränare.", nb: "Velg dine spesialområder slik at elever kan finne riktig trener."))
                    .font(.subheadline)
                    .foregroundColor(.secondary)
                
                LazyVGrid(columns: [GridItem(.flexible()), GridItem(.flexible())], spacing: 12) {
                    ForEach(allSpecialties) { specialty in
                        Button {
                            if selectedSpecialties.contains(specialty.id) {
                                selectedSpecialties.remove(specialty.id)
                            } else {
                                selectedSpecialties.insert(specialty.id)
                            }
                        } label: {
                            HStack(spacing: 8) {
                                if let icon = specialty.icon {
                                    Image(systemName: icon)
                                        .font(.system(size: 16))
                                }
                                Text(specialty.name)
                                    .font(.system(size: 14, weight: .medium))
                                    .lineLimit(1)
                            }
                            .foregroundColor(selectedSpecialties.contains(specialty.id) ? .white : .primary)
                            .padding(.horizontal, 12)
                            .padding(.vertical, 12)
                            .frame(maxWidth: .infinity)
                            .background(selectedSpecialties.contains(specialty.id) ? Color.black : Color(.systemGray6))
                            .cornerRadius(12)
                        }
                    }
                }
                
                if selectedSpecialties.isEmpty {
                    Text(L.t(sv: "Välj minst en specialitet", nb: "Velg minst én spesialitet"))
                        .font(.caption)
                        .foregroundColor(.orange)
                } else {
                    Text(L.t(sv: "\(selectedSpecialties.count) specialiteter valda", nb: "\(selectedSpecialties.count) spesialiteter valgt"))
                        .font(.caption)
                        .foregroundColor(.primary)
                }
                
                Spacer()
            }
            .padding()
        }
    }
    
    // MARK: - Step 5: Lesson Types
    
    private var step5LessonTypes: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 24) {
                Text(L.t(sv: "Vilka lektioner erbjuder du?", nb: "Hvilke leksjoner tilbyr du?"))
                    .font(.title2)
                    .fontWeight(.bold)
                
                Text(L.t(sv: "Lägg till olika lektionstyper med olika priser och längder.", nb: "Legg til ulike leksjonstyper med ulike priser og lengder."))
                    .font(.subheadline)
                    .foregroundColor(.secondary)
                
                // Add custom lesson type button - FIRST
                Button {
                    showAddLessonType = true
                } label: {
                    HStack {
                        Image(systemName: "plus.circle.fill")
                        Text(L.t(sv: "Lägg till egen lektionstyp", nb: "Legg til egen leksjonstype"))
                    }
                    .font(.headline)
                    .foregroundColor(.white)
                    .frame(maxWidth: .infinity)
                    .padding()
                    .background(Color.black)
                    .cornerRadius(12)
                }
                
                // Added lesson types
                if !lessonTypes.isEmpty {
                    VStack(alignment: .leading, spacing: 12) {
                        Text(L.t(sv: "Dina lektionstyper:", nb: "Dine leksjonstyper:"))
                            .font(.headline)
                        
                        ForEach(lessonTypes) { type in
                            HStack {
                                VStack(alignment: .leading, spacing: 4) {
                                    Text(type.name)
                                        .font(.subheadline)
                                        .fontWeight(.medium)
                                    Text(L.t(sv: "\(type.duration) min • \(type.price) kr", nb: "\(type.duration) min • \(type.price) kr"))
                                        .font(.caption)
                                        .foregroundColor(.secondary)
                                }
                                
                                Spacer()
                                
                                Button {
                                    lessonTypes.removeAll { $0.id == type.id }
                                } label: {
                                    Image(systemName: "xmark.circle.fill")
                                        .foregroundColor(.red)
                                }
                            }
                            .padding()
                            .background(Color(.systemGray6))
                            .cornerRadius(12)
                        }
                    }
                }
                
                // Default lesson types suggestion
                VStack(alignment: .leading, spacing: 12) {
                    Text(L.t(sv: "Förslag på lektionstyper:", nb: "Forslag til leksjonstyper:"))
                        .font(.headline)
                    
                    ForEach(DefaultLessonTypes.types, id: \.name) { type in
                        let alreadyAdded = lessonTypes.contains { $0.name == type.name }
                        
                        Button {
                            if !alreadyAdded {
                                let basePrice = Int(hourlyRate) ?? 500
                                let price = Int(Double(basePrice) * type.priceMultiplier)
                                lessonTypes.append(NewLessonType(
                                    name: type.name,
                                    description: type.description,
                                    duration: type.duration,
                                    price: price
                                ))
                            }
                        } label: {
                            HStack {
                                VStack(alignment: .leading, spacing: 4) {
                                    Text(type.name)
                                        .font(.subheadline)
                                        .fontWeight(.medium)
                                    Text("\(type.duration) min")
                                        .font(.caption)
                                        .foregroundColor(.secondary)
                                }
                                
                                Spacer()
                                
                                Image(systemName: alreadyAdded ? "checkmark.circle.fill" : "plus.circle.fill")
                                    .foregroundColor(alreadyAdded ? .green : .black)
                            }
                            .padding()
                            .background(Color(.systemGray6))
                            .cornerRadius(12)
                        }
                        .foregroundColor(.primary)
                        .disabled(alreadyAdded)
                    }
                }
                .padding()
                .background(Color.black.opacity(0.05))
                .cornerRadius(12)
                
                Spacer()
            }
            .padding()
        }
    }
    
    // MARK: - Step 6: Location with Service Area
    
    private var step6Location: some View {
        VStack(spacing: 16) {
            Text(L.t(sv: "Var kan du hålla lektioner?", nb: "Hvor kan du holde leksjoner?"))
                .font(.headline)
            
            Text(isMapLocked ? L.t(sv: "Pin placerad! Justera radien nedan.", nb: "Pin plassert! Juster radiusen nedenfor.") : L.t(sv: "Flytta kartan för att välja centrum", nb: "Flytt kartet for å velge sentrum"))
                .font(.subheadline)
                .foregroundColor(.secondary)
                .multilineTextAlignment(.center)
            
            // Map with lock/unlock functionality
            ZStack {
                Map(coordinateRegion: $region, interactionModes: isMapLocked ? [] : [.pan, .zoom])
                    .cornerRadius(12)
                    .onChange(of: region.center.latitude) { _ in
                        if !isMapLocked {
                            selectedLocation = region.center
                        }
                    }
                    .onChange(of: region.span.latitudeDelta) { newSpan in
                        // When user zooms in manually (not from slider), adjust radius if circle would be too big
                        if !isMapLocked && !isAdjustingZoomProgrammatically {
                            adjustRadiusToFitScreen(mapSpan: newSpan)
                        }
                    }
                
                // Circle overlay (visual only - drawn on top, passes touches through)
                Circle()
                    .stroke(Color.black, lineWidth: 2)
                    .background(Circle().fill(Color.black.opacity(0.1)))
                    .frame(width: circleSize, height: circleSize)
                    .allowsHitTesting(false)
                
                // Center pin (passes touches through to map)
                VStack(spacing: 0) {
                    Image(systemName: "mappin.circle.fill")
                        .font(.system(size: 36))
                        .foregroundColor(isMapLocked ? .green : .black)
                    
                    if !isMapLocked {
                        Image(systemName: "arrowtriangle.down.fill")
                            .font(.system(size: 10))
                            .foregroundColor(.primary)
                            .offset(y: -5)
                    }
                }
                .allowsHitTesting(false)
                
                // Lock indicator overlay
                if isMapLocked {
                    VStack {
                        HStack {
                            Spacer()
                            HStack(spacing: 4) {
                                Image(systemName: "lock.fill")
                                Text(L.t(sv: "Låst", nb: "Låst"))
                            }
                            .font(.caption)
                            .foregroundColor(.white)
                            .padding(.horizontal, 8)
                            .padding(.vertical, 4)
                            .background(Color.green)
                            .cornerRadius(8)
                            .padding(8)
                        }
                        Spacer()
                    }
                    .allowsHitTesting(false)
                }
            }
            .frame(height: 280)
            
            // Lock/Unlock buttons
            HStack(spacing: 12) {
                if isMapLocked {
                    Button {
                        withAnimation {
                            isMapLocked = false
                        }
                    } label: {
                        HStack {
                            Image(systemName: "pencil")
                            Text(L.t(sv: "Ändra", nb: "Endre"))
                        }
                        .font(.headline)
                        .foregroundColor(.primary)
                        .frame(maxWidth: .infinity)
                        .padding()
                        .background(Color(.systemGray5))
                        .cornerRadius(12)
                    }
                } else {
                    Button {
                        withAnimation {
                            isMapLocked = true
                            selectedLocation = region.center
                        }
                    } label: {
                        HStack {
                            Image(systemName: "mappin.and.ellipse")
                            Text(L.t(sv: "Sätt ut pin", nb: "Sett ut pin"))
                        }
                        .font(.headline)
                        .foregroundColor(.white)
                        .frame(maxWidth: .infinity)
                        .padding()
                        .background(Color.black)
                        .cornerRadius(12)
                    }
                }
            }
            
            // Radius slider
            VStack(spacing: 8) {
                HStack {
                    Text(L.t(sv: "Täckningsområde", nb: "Dekningsområde"))
                        .font(.subheadline)
                        .foregroundColor(.secondary)
                    Spacer()
                    Text(L.t(sv: "\(Int(serviceRadiusKm)) km radie", nb: "\(Int(serviceRadiusKm)) km radius"))
                        .font(.system(size: 16, weight: .bold))
                }
                
                HStack(spacing: 12) {
                    Text("1")
                        .font(.caption)
                        .foregroundColor(.secondary)
                    
                    Slider(value: $serviceRadiusKm, in: 1...50, step: 1)
                        .accentColor(.black)
                        .onChange(of: serviceRadiusKm) { newValue in
                            // Auto-zoom map to fit the circle
                            adjustMapZoomForRadius(newValue)
                        }
                    
                    Text("50")
                        .font(.caption)
                        .foregroundColor(.secondary)
                }
            }
            .padding()
            .background(Color(.systemGray6))
            .cornerRadius(12)
            
            // Status indicator
            if isMapLocked {
                HStack {
                    Image(systemName: "checkmark.circle.fill")
                        .foregroundColor(.green)
                    Text(L.t(sv: "Täckningsområde: \(Int(serviceRadiusKm)) km radie", nb: "Dekningsområde: \(Int(serviceRadiusKm)) km radius"))
                        .font(.subheadline)
                }
                .padding()
                .frame(maxWidth: .infinity)
                .background(Color.green.opacity(0.1))
                .cornerRadius(12)
            } else {
                HStack {
                    Image(systemName: "info.circle.fill")
                        .foregroundColor(.orange)
                    Text(L.t(sv: "Flytta kartan och tryck \"Sätt ut pin\"", nb: "Flytt kartet og trykk \"Sett ut pin\""))
                        .font(.subheadline)
                }
                .padding()
                .frame(maxWidth: .infinity)
                .background(Color.orange.opacity(0.1))
                .cornerRadius(12)
            }
            
            Spacer()
        }
        .padding()
        .onAppear {
            if let userLocation = locationManager.userLocation {
                region.center = userLocation
            }
            selectedLocation = region.center
            // Set initial zoom based on default radius
            adjustMapZoomForRadius(serviceRadiusKm)
        }
    }
    
    // Adjust map zoom to fit the service radius circle
    private func adjustMapZoomForRadius(_ radiusKm: Double) {
        let degreesPerKm = 1.0 / 111.0
        // Make span 2.5x the radius diameter to ensure circle fits with padding
        let spanDelta = radiusKm * degreesPerKm * 2.5
        
        // Set flag to prevent feedback loop
        isAdjustingZoomProgrammatically = true
        
        withAnimation(.easeInOut(duration: 0.3)) {
            region = MKCoordinateRegion(
                center: region.center,
                span: MKCoordinateSpan(latitudeDelta: spanDelta, longitudeDelta: spanDelta)
            )
        }
        
        // Reset flag after a short delay
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) {
            isAdjustingZoomProgrammatically = false
        }
    }
    
    // Adjust radius when user zooms in to keep circle on screen
    private func adjustRadiusToFitScreen(mapSpan: Double) {
        let degreesPerKm = 1.0 / 111.0
        // Calculate max radius that fits in current zoom (with padding)
        let maxRadiusKm = (mapSpan / 2.5) / degreesPerKm
        
        // If current radius is too big for the zoom level, shrink it
        if serviceRadiusKm > maxRadiusKm && maxRadiusKm >= 1 {
            serviceRadiusKm = max(1, floor(maxRadiusKm))
        }
    }
    
    // Calculate circle size based on radius and current map zoom
    private var circleSize: CGFloat {
        let degreesPerKm = 1.0 / 111.0
        let radiusInDegrees = serviceRadiusKm * degreesPerKm
        let mapWidthInDegrees = region.span.latitudeDelta
        let screenWidth: CGFloat = 280 // map frame height
        let pixelsPerDegree = screenWidth / mapWidthInDegrees
        return min(CGFloat(radiusInDegrees * 2 * pixelsPerDegree), screenWidth * 0.9)
    }
    
    // MARK: - Step 7: Review
    
    private var step7Review: some View {
        ScrollView {
            VStack(spacing: 20) {
                Text(L.t(sv: "Granska din profil", nb: "Se over profilen din"))
                    .font(.title2)
                    .fontWeight(.bold)
                
                // Preview card
                VStack(spacing: 16) {
                    // Profile Picture - Tappable to change
                    Button {
                        showImagePicker = true
                    } label: {
                        ZStack(alignment: .bottomTrailing) {
                            if let image = profileImage {
                                Image(uiImage: image)
                                    .resizable()
                                    .scaledToFill()
                                    .frame(width: 80, height: 80)
                                    .clipShape(Circle())
                            } else {
                                ProfileImage(url: authViewModel.currentUser?.avatarUrl, size: 80)
                            }
                            
                            // Edit badge
                            Image(systemName: "camera.circle.fill")
                                .font(.system(size: 24))
                                .foregroundColor(.primary)
                                .background(Circle().fill(.white).frame(width: 20, height: 20))
                        }
                    }
                    
                    if !hasProfilePicture {
                        Text(L.t(sv: "⚠️ Du måste ha en profilbild", nb: "⚠️ Du må ha et profilbilde"))
                            .font(.caption)
                            .foregroundColor(.red)
                    } else {
                        Text(L.t(sv: "Tryck för att ändra profilbild", nb: "Trykk for å endre profilbilde"))
                            .font(.caption)
                            .foregroundColor(.secondary)
                    }
                    
                    Text(name.isEmpty ? L.t(sv: "Ditt namn", nb: "Ditt navn") : name)
                        .font(.title3)
                        .fontWeight(.semibold)
                    
                    HStack(spacing: 16) {
                        StatBadge(icon: "figure.golf", value: "HCP \(handicap.isEmpty ? "?" : handicap)")
                        StatBadge(icon: "clock", value: "\(hourlyRate.isEmpty ? "?" : hourlyRate) kr/h")
                    }
                    
                    Text(combinedDescription.isEmpty ? L.t(sv: "Din beskrivning...", nb: "Din beskrivelse...") : combinedDescription)
                        .font(.body)
                        .foregroundColor(.secondary)
                        .multilineTextAlignment(.center)
                        .lineLimit(5)
                }
                .padding()
                .background(Color(.systemGray6))
                .cornerRadius(16)
                
                // Checklist
                VStack(alignment: .leading, spacing: 12) {
                    ChecklistItem(text: L.t(sv: "Profilbild", nb: "Profilbilde"), isComplete: hasProfilePicture)
                    ChecklistItem(text: L.t(sv: "Namn", nb: "Navn"), isComplete: !name.isEmpty)
                    ChecklistItem(text: L.t(sv: "Bakgrund", nb: "Bakgrunn"), isComplete: !backgroundExperience.isEmpty)
                    ChecklistItem(text: L.t(sv: "Träningsfilosofi", nb: "Treningsfilosofi"), isComplete: !trainingPhilosophy.isEmpty)
                    ChecklistItem(text: L.t(sv: "Tillgänglighet", nb: "Tilgjengelighet"), isComplete: hasAtLeastOneAvailableDay)
                    ChecklistItem(text: L.t(sv: "Pris", nb: "Pris"), isComplete: !hourlyRate.isEmpty)
                    ChecklistItem(text: L.t(sv: "Handicap", nb: "Handicap"), isComplete: !handicap.isEmpty)
                    ChecklistItem(text: L.t(sv: "Plats", nb: "Sted"), isComplete: selectedLocation != nil)
                }
                .padding()
                .background(Color(.systemGray6))
                .cornerRadius(12)
                
                Spacer()
            }
            .padding()
        }
        .sheet(isPresented: $showImagePicker) {
            ImagePicker(image: $profileImage, authViewModel: authViewModel)
        }
    }
    
    // MARK: - Navigation Buttons
    
    private var navigationButtons: some View {
        HStack(spacing: 16) {
            if currentStep > 0 {
                Button {
                    withAnimation {
                        currentStep -= 1
                    }
                } label: {
                    Text(L.t(sv: "Tillbaka", nb: "Tilbake"))
                        .font(.headline)
                        .foregroundColor(.primary)
                        .frame(maxWidth: .infinity)
                        .padding()
                        .background(Color(.systemGray5))
                        .cornerRadius(12)
                }
            }
            
            Button {
                // Dismiss keyboard before transitioning
                UIApplication.shared.sendAction(#selector(UIResponder.resignFirstResponder), to: nil, from: nil, for: nil)
                
                if currentStep < totalSteps - 1 {
                    withAnimation {
                        currentStep += 1
                    }
                } else {
                    submitProfile()
                }
            } label: {
                if isSubmitting {
                    ProgressView()
                        .tint(.white)
                        .frame(maxWidth: .infinity)
                        .padding()
                        .background(Color.black)
                        .cornerRadius(12)
                } else {
                    Text(currentStep < totalSteps - 1 ? L.t(sv: "Nästa", nb: "Neste") : L.t(sv: "Ansök", nb: "Søk"))
                        .font(.headline)
                        .foregroundColor(.white)
                        .frame(maxWidth: .infinity)
                        .padding()
                        .background(canProceed ? Color.black : Color.gray)
                        .cornerRadius(12)
                }
            }
            .disabled(!canProceed || isSubmitting)
        }
        .padding()
    }
    
    // Combined description from structured fields
    private var combinedDescription: String {
        var parts: [String] = []
        if !backgroundExperience.isEmpty {
            parts.append(L.t(sv: "📋 Bakgrund: \(backgroundExperience)", nb: "📋 Bakgrunn: \(backgroundExperience)"))
        }
        if !trainingPhilosophy.isEmpty {
            parts.append(L.t(sv: "💡 Träningsfilosofi: \(trainingPhilosophy)", nb: "💡 Treningsfilosofi: \(trainingPhilosophy)"))
        }
        return parts.joined(separator: "\n\n")
    }
    
    private var hasAtLeastOneAvailableDay: Bool {
        weeklyAvailability.contains { $0.isEnabled }
    }
    
    private var canProceed: Bool {
        switch currentStep {
        case 0: return !name.isEmpty && !backgroundExperience.isEmpty && !trainingPhilosophy.isEmpty
        case 1: return hasAtLeastOneAvailableDay // Availability
        case 2: return !hourlyRate.isEmpty && !handicap.isEmpty
        case 3: return !selectedSpecialties.isEmpty
        case 4: return true // Lesson types är valfritt
        case 5: return isMapLocked && selectedLocation != nil // Must lock pin
        case 6: return hasProfilePicture && !name.isEmpty && !backgroundExperience.isEmpty && !trainingPhilosophy.isEmpty && !hourlyRate.isEmpty && !handicap.isEmpty && selectedLocation != nil && hasAtLeastOneAvailableDay && isMapLocked
        default: return true
        }
    }
    
    private func formatTimeForDB(_ date: Date) -> String {
        let formatter = DateFormatter()
        formatter.dateFormat = "HH:mm:ss"
        return formatter.string(from: date)
    }
    
    private func submitProfile() {
        guard let location = selectedLocation,
              let rate = Int(hourlyRate),
              let hcp = Int(handicap) else {
            errorMessage = L.t(sv: "Vänligen fyll i alla fält korrekt", nb: "Vennligst fyll inn alle felt riktig")
            return
        }
        
        isSubmitting = true
        
        Task {
            do {
                let trainerId: UUID
                
                if isEditMode, let existingId = createdTrainerId ?? existingTrainerId {
                    // UPDATE existing profile
                    trainerId = existingId
                    
                    try await TrainerService.shared.updateTrainerProfile(
                        trainerId: existingId,
                        name: name,
                        description: combinedDescription,
                        hourlyRate: rate,
                        handicap: hcp,
                        latitude: location.latitude,
                        longitude: location.longitude,
                        isActive: true
                    )
                    
                    print("✅ Updated existing trainer profile")
                } else {
                    // CREATE new profile
                    let trainer = try await TrainerService.shared.createTrainerProfile(
                        name: name,
                        description: combinedDescription,
                        hourlyRate: rate,
                        handicap: hcp,
                        latitude: location.latitude,
                        longitude: location.longitude,
                        serviceRadiusKm: serviceRadiusKm
                    )
                    trainerId = trainer.id
                    createdTrainerId = trainer.id
                    print("✅ Created new trainer profile")
                }
                
                // 2. Update extended profile fields
                try await TrainerService.shared.updateTrainerExtendedProfile(
                    trainerId: trainerId,
                    city: city.isEmpty ? nil : city,
                    bio: nil,
                    experienceYears: Int(experienceYears),
                    clubAffiliation: clubAffiliation.isEmpty ? nil : clubAffiliation
                )
                
                // 3. Save specialties
                if !selectedSpecialties.isEmpty {
                    try await TrainerService.shared.saveTrainerSpecialties(
                        trainerId: trainerId,
                        specialtyIds: Array(selectedSpecialties)
                    )
                }
                
                // 4. Clear old lesson types first, then save new ones
                try await TrainerService.shared.deleteAllLessonTypes(trainerId: trainerId)
                for lessonType in lessonTypes {
                    _ = try await TrainerService.shared.saveLessonType(
                        trainerId: trainerId,
                        name: lessonType.name,
                        description: lessonType.description,
                        durationMinutes: lessonType.duration,
                        price: lessonType.price
                    )
                }
                
                // 5. Clear old availability first, then save new ones
                try await TrainerService.shared.deleteAllAvailability(trainerId: trainerId)
                for day in weeklyAvailability where day.isEnabled {
                    let startTimeString = formatTimeForDB(day.startTime)
                    let endTimeString = formatTimeForDB(day.endTime)
                    try await TrainerService.shared.saveAvailability(
                        trainerId: trainerId,
                        dayOfWeek: day.dayOfWeek,
                        startTime: startTimeString,
                        endTime: endTimeString
                    )
                }
                
                await MainActor.run {
                    isSubmitting = false
                    if isEditMode {
                        // For edit mode, just dismiss with success
                        dismiss()
                    } else {
                        showConfirmation = true
                    }
                }
            } catch {
                await MainActor.run {
                    isSubmitting = false
                    errorMessage = error.localizedDescription
                }
            }
        }
    }
}

// MARK: - New Lesson Type Model

struct NewLessonType: Identifiable {
    let id = UUID()
    var name: String
    var description: String
    var duration: Int
    var price: Int
}

// MARK: - Weekly Availability Model (for onboarding)

struct WeekDayAvailability: Identifiable {
    let id = UUID()
    let dayOfWeek: Int // 0=Sunday, 6=Saturday
    let dayName: String
    var isEnabled: Bool
    var startTime: Date
    var endTime: Date
    
    static func defaultWeek() -> [WeekDayAvailability] {
        let days = [L.t(sv: "Söndag", nb: "Søndag"), L.t(sv: "Måndag", nb: "Mandag"), L.t(sv: "Tisdag", nb: "Tirsdag"), L.t(sv: "Onsdag", nb: "Onsdag"), L.t(sv: "Torsdag", nb: "Torsdag"), L.t(sv: "Fredag", nb: "Fredag"), L.t(sv: "Lördag", nb: "Lørdag")]
        let calendar = Calendar.current
        let today = calendar.startOfDay(for: Date())
        let defaultStart = calendar.date(byAdding: .hour, value: 9, to: today)!
        let defaultEnd = calendar.date(byAdding: .hour, value: 17, to: today)!
        
        return days.enumerated().map { index, name in
            WeekDayAvailability(
                dayOfWeek: index,
                dayName: name,
                isEnabled: index >= 1 && index <= 5, // Mon-Fri enabled by default
                startTime: defaultStart,
                endTime: defaultEnd
            )
        }
    }
}

// MARK: - Availability Day Row View

struct AvailabilityDayRow: View {
    @Binding var day: WeekDayAvailability
    
    var body: some View {
        VStack(spacing: 8) {
            HStack {
                Toggle(isOn: $day.isEnabled) {
                    Text(day.dayName)
                        .font(.headline)
                }
                .toggleStyle(SwitchToggleStyle(tint: .black))
            }
            
            if day.isEnabled {
                HStack(spacing: 12) {
                    VStack(alignment: .leading, spacing: 4) {
                        Text(L.t(sv: "Från", nb: "Fra"))
                            .font(.caption)
                            .foregroundColor(.secondary)
                        DatePicker("", selection: $day.startTime, displayedComponents: .hourAndMinute)
                            .labelsHidden()
                    }
                    
                    Image(systemName: "arrow.right")
                        .foregroundColor(.secondary)
                    
                    VStack(alignment: .leading, spacing: 4) {
                        Text(L.t(sv: "Till", nb: "Til"))
                            .font(.caption)
                            .foregroundColor(.secondary)
                        DatePicker("", selection: $day.endTime, displayedComponents: .hourAndMinute)
                            .labelsHidden()
                    }
                    
                    Spacer()
                }
                .padding(.leading, 8)
            }
        }
        .padding()
        .background(day.isEnabled ? Color.black.opacity(0.05) : Color(.systemGray6))
        .cornerRadius(12)
    }
}

// MARK: - Day Availability Model (legacy, keep for compatibility)

struct DayAvailability: Identifiable {
    let id = UUID()
    let dayOfWeek: Int
    let dayName: String
    var isEnabled: Bool
    var startTime: Date
    var endTime: Date
    
    static func defaultWeek() -> [DayAvailability] {
        let days = [L.t(sv: "Söndag", nb: "Søndag"), L.t(sv: "Måndag", nb: "Mandag"), L.t(sv: "Tisdag", nb: "Tirsdag"), L.t(sv: "Onsdag", nb: "Onsdag"), L.t(sv: "Torsdag", nb: "Torsdag"), L.t(sv: "Fredag", nb: "Fredag"), L.t(sv: "Lördag", nb: "Lørdag")]
        let calendar = Calendar.current
        let today = calendar.startOfDay(for: Date())
        let defaultStart = calendar.date(byAdding: .hour, value: 9, to: today)!
        let defaultEnd = calendar.date(byAdding: .hour, value: 17, to: today)!
        
        return days.enumerated().map { index, name in
            DayAvailability(
                dayOfWeek: index,
                dayName: name,
                isEnabled: index >= 1 && index <= 5, // Mon-Fri enabled by default
                startTime: defaultStart,
                endTime: defaultEnd
            )
        }
    }
}

// MARK: - Add Lesson Type Sheet

struct AddLessonTypeSheet: View {
    let basePrice: Int
    let onAdd: (NewLessonType) -> Void
    
    @Environment(\.dismiss) private var dismiss
    @State private var name = ""
    @State private var description = ""
    @State private var duration = "60"
    @State private var price = ""
    
    var body: some View {
        NavigationStack {
            Form {
                Section(L.t(sv: "Lektionstyp", nb: "Leksjonstype")) {
                    TextField(L.t(sv: "Namn (ex: 60 min lektion)", nb: "Navn (eks: 60 min leksjon)"), text: $name)
                    TextField(L.t(sv: "Beskrivning", nb: "Beskrivelse"), text: $description)
                }
                
                Section(L.t(sv: "Detaljer", nb: "Detaljer")) {
                    HStack {
                        Text(L.t(sv: "Längd", nb: "Lengde"))
                        Spacer()
                        TextField("60", text: $duration)
                            .keyboardType(.numberPad)
                            .frame(width: 60)
                            .multilineTextAlignment(.trailing)
                        Text("min")
                            .foregroundColor(.secondary)
                    }
                    
                    HStack {
                        Text(L.t(sv: "Pris", nb: "Pris"))
                        Spacer()
                        TextField("\(basePrice)", text: $price)
                            .keyboardType(.numberPad)
                            .frame(width: 80)
                            .multilineTextAlignment(.trailing)
                        Text("kr")
                            .foregroundColor(.secondary)
                    }
                }
            }
            .navigationTitle(L.t(sv: "Ny lektionstyp", nb: "Ny leksjonstype"))
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarLeading) {
                    Button(L.t(sv: "Avbryt", nb: "Avbryt")) {
                        dismiss()
                    }
                }
                
                ToolbarItem(placement: .topBarTrailing) {
                    Button(L.t(sv: "Lägg till", nb: "Legg til")) {
                        let newType = NewLessonType(
                            name: name,
                            description: description,
                            duration: Int(duration) ?? 60,
                            price: Int(price) ?? basePrice
                        )
                        onAdd(newType)
                        dismiss()
                    }
                    .disabled(name.isEmpty)
                }
            }
        }
    }
}

// MARK: - Confirmation View

struct TrainerApplicationConfirmationView: View {
    let onClose: () -> Void
    
    var body: some View {
        NavigationStack {
            VStack(spacing: 20) {
                Spacer()
                Image(systemName: "checkmark.seal.fill")
                    .font(.system(size: 48))
                    .foregroundColor(.primary)
                Text(L.t(sv: "Vi behandlar din ansökan", nb: "Vi behandler søknaden din"))
                    .font(.title3)
                    .fontWeight(.semibold)
                    .multilineTextAlignment(.center)
                Text(L.t(sv: "Du får ett meddelande när en admin har granskat dina uppgifter.", nb: "Du får en melding når en admin har gjennomgått opplysningene dine."))
                    .font(.body)
                    .foregroundColor(.secondary)
                    .multilineTextAlignment(.center)
                    .padding(.horizontal)
                Spacer()
                Button {
                    onClose()
                } label: {
                    Text(L.t(sv: "Stäng", nb: "Lukk"))
                        .font(.headline)
                        .foregroundColor(.white)
                        .frame(maxWidth: .infinity)
                        .padding()
                        .background(Color.black)
                        .cornerRadius(12)
                        .padding(.horizontal)
                }
                .padding(.bottom, 20)
            }
        }
    }
}

// MARK: - Helper Views

struct ChecklistItem: View {
    let text: String
    let isComplete: Bool
    
    var body: some View {
        HStack {
            Image(systemName: isComplete ? "checkmark.circle.fill" : "circle")
                .foregroundColor(isComplete ? .green : .gray)
            Text(text)
                .foregroundColor(isComplete ? .primary : .secondary)
        }
    }
}

struct LocationPin: Identifiable {
    let id = UUID()
    let coordinate: CLLocationCoordinate2D
}

// MARK: - Location Manager for Onboarding

class OnboardingLocationManager: NSObject, ObservableObject, CLLocationManagerDelegate {
    @Published var userLocation: CLLocationCoordinate2D?
    private let locationManager = CLLocationManager()
    
    override init() {
        super.init()
        locationManager.delegate = self
        locationManager.desiredAccuracy = kCLLocationAccuracyBest
        locationManager.requestWhenInUseAuthorization()
        locationManager.startUpdatingLocation()
    }
    
    func locationManager(_ manager: CLLocationManager, didUpdateLocations locations: [CLLocation]) {
        if let location = locations.first {
            DispatchQueue.main.async {
                self.userLocation = location.coordinate
            }
            locationManager.stopUpdatingLocation()
        }
    }
}

// MARK: - Service Area Map View with Circle Overlay

struct ServiceAreaMapView: UIViewRepresentable {
    @Binding var region: MKCoordinateRegion
    let radiusKm: Double
    
    func makeUIView(context: Context) -> MKMapView {
        let mapView = MKMapView()
        mapView.delegate = context.coordinator
        mapView.showsUserLocation = true
        mapView.setRegion(region, animated: false)
        return mapView
    }
    
    func updateUIView(_ mapView: MKMapView, context: Context) {
        // Update region if changed significantly
        let currentCenter = mapView.centerCoordinate
        let newCenter = region.center
        let distance = CLLocation(latitude: currentCenter.latitude, longitude: currentCenter.longitude)
            .distance(from: CLLocation(latitude: newCenter.latitude, longitude: newCenter.longitude))
        
        if distance > 100 { // Only update if moved more than 100m
            mapView.setRegion(region, animated: true)
        }
        
        // Remove old overlays
        mapView.removeOverlays(mapView.overlays)
        
        // Add new circle overlay
        let circle = MKCircle(center: mapView.centerCoordinate, radius: radiusKm * 1000)
        mapView.addOverlay(circle)
    }
    
    func makeCoordinator() -> Coordinator {
        Coordinator(self)
    }
    
    class Coordinator: NSObject, MKMapViewDelegate {
        var parent: ServiceAreaMapView
        
        init(_ parent: ServiceAreaMapView) {
            self.parent = parent
        }
        
        func mapView(_ mapView: MKMapView, rendererFor overlay: MKOverlay) -> MKOverlayRenderer {
            if let circle = overlay as? MKCircle {
                let renderer = MKCircleRenderer(circle: circle)
                renderer.fillColor = UIColor.black.withAlphaComponent(0.1)
                renderer.strokeColor = UIColor.black
                renderer.lineWidth = 2
                return renderer
            }
            return MKOverlayRenderer(overlay: overlay)
        }
        
        func mapViewDidChangeVisibleRegion(_ mapView: MKMapView) {
            // Update binding when user moves the map
            DispatchQueue.main.async {
                self.parent.region.center = mapView.centerCoordinate
                
                // Update circle position
                mapView.removeOverlays(mapView.overlays)
                let circle = MKCircle(center: mapView.centerCoordinate, radius: self.parent.radiusKm * 1000)
                mapView.addOverlay(circle)
            }
        }
    }
}

#Preview {
    TrainerOnboardingView()
}


