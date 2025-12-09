import SwiftUI
import MapKit
import CoreLocation
import Combine

struct TrainerOnboardingView: View {
    @Environment(\.dismiss) private var dismiss
    @EnvironmentObject var authViewModel: AuthViewModel
    @StateObject private var locationManager = OnboardingLocationManager()
    
    @State private var currentStep = 0
    @State private var name = ""
    @State private var description = ""
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
    
    private let totalSteps = 6
    
    private var hasProfilePicture: Bool {
        profileImage != nil || (authViewModel.currentUser?.avatarUrl != nil && !authViewModel.currentUser!.avatarUrl!.isEmpty)
    }
    
    var body: some View {
        NavigationStack {
            VStack(spacing: 0) {
                // Progress indicator
                progressIndicator
                
                // Content
                TabView(selection: $currentStep) {
                    step1NameDescription.tag(0)
                    step2PriceHandicap.tag(1)
                    step3Specialties.tag(2)
                    step4LessonTypes.tag(3)
                    step5Location.tag(4)
                    step6Review.tag(5)
                }
                .tabViewStyle(.page(indexDisplayMode: .never))
                .animation(.easeInOut, value: currentStep)
                
                // Navigation buttons
                navigationButtons
            }
            .navigationTitle("Bli golftränare")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarLeading) {
                    Button("Avbryt") {
                        dismiss()
                    }
                }
            }
            .task {
                await loadSpecialties()
            }
            .alert("Fel", isPresented: .init(
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
    }
    
    private func loadSpecialties() async {
        do {
            allSpecialties = try await TrainerService.shared.fetchSpecialtiesCatalog()
        } catch {
            print("❌ Failed to load specialties: \(error)")
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
                    Text("Ditt namn")
                        .font(.headline)
                    
                    TextField("Förnamn Efternamn", text: $name)
                        .textFieldStyle(RoundedTextFieldStyle())
                }
                
                VStack(alignment: .leading, spacing: 8) {
                    Text("Beskriv dig själv")
                        .font(.headline)
                    
                    Text("Berätta om din erfarenhet, vad du kan hjälpa med och varför elever ska välja dig.")
                        .font(.caption)
                        .foregroundColor(.secondary)
                    
                    TextEditor(text: $description)
                        .frame(height: 150)
                        .padding(8)
                        .background(Color(.systemGray6))
                        .cornerRadius(12)
                        .overlay(
                            RoundedRectangle(cornerRadius: 12)
                                .stroke(Color.gray.opacity(0.3))
                        )
                }
                
                Spacer()
            }
            .padding()
        }
    }
    
    // MARK: - Step 2: Price & Handicap
    
    private var step2PriceHandicap: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 24) {
                VStack(alignment: .leading, spacing: 8) {
                    Text("Pris per timme")
                        .font(.headline)
                    
                    HStack {
                        TextField("Ex: 500", text: $hourlyRate)
                            .keyboardType(.numberPad)
                            .textFieldStyle(RoundedTextFieldStyle())
                        
                        Text("kr/timme")
                            .foregroundColor(.secondary)
                    }
                }
                
                VStack(alignment: .leading, spacing: 8) {
                    Text("Ditt handicap")
                        .font(.headline)
                    
                    TextField("Ex: 5", text: $handicap)
                        .keyboardType(.numberPad)
                        .textFieldStyle(RoundedTextFieldStyle())
                }
                
                VStack(alignment: .leading, spacing: 8) {
                    Text("Års erfarenhet")
                        .font(.headline)
                    
                    TextField("Ex: 10", text: $experienceYears)
                        .keyboardType(.numberPad)
                        .textFieldStyle(RoundedTextFieldStyle())
                }
                
                VStack(alignment: .leading, spacing: 8) {
                    Text("Stad")
                        .font(.headline)
                    
                    TextField("Ex: Stockholm", text: $city)
                        .textFieldStyle(RoundedTextFieldStyle())
                }
                
                VStack(alignment: .leading, spacing: 8) {
                    Text("Klubbtillhörighet (valfritt)")
                        .font(.headline)
                    
                    TextField("Ex: Djursholms GK", text: $clubAffiliation)
                        .textFieldStyle(RoundedTextFieldStyle())
                }
                
                // Tips
                VStack(alignment: .leading, spacing: 8) {
                    HStack {
                        Image(systemName: "lightbulb.fill")
                            .foregroundColor(.yellow)
                        Text("Tips")
                            .font(.headline)
                    }
                    
                    Text("Genomsnittspriset för en golflektion i Sverige är 400-800 kr/timme. Sätt ett konkurrenskraftigt pris för att få fler bokningar!")
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
    
    // MARK: - Step 3: Specialties
    
    private var step3Specialties: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 24) {
                Text("Vad är du bra på?")
                    .font(.title2)
                    .fontWeight(.bold)
                
                Text("Välj dina specialområden så att elever kan hitta rätt tränare.")
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
                    Text("Välj minst en specialitet")
                        .font(.caption)
                        .foregroundColor(.orange)
                } else {
                    Text("\(selectedSpecialties.count) specialiteter valda")
                        .font(.caption)
                        .foregroundColor(.black)
                }
                
                Spacer()
            }
            .padding()
        }
    }
    
    // MARK: - Step 4: Lesson Types
    
    private var step4LessonTypes: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 24) {
                Text("Vilka lektioner erbjuder du?")
                    .font(.title2)
                    .fontWeight(.bold)
                
                Text("Lägg till olika lektionstyper med olika priser och längder.")
                    .font(.subheadline)
                    .foregroundColor(.secondary)
                
                // Default lesson types suggestion
                if lessonTypes.isEmpty {
                    VStack(alignment: .leading, spacing: 12) {
                        Text("Förslag på lektionstyper:")
                            .font(.headline)
                        
                        ForEach(DefaultLessonTypes.types, id: \.name) { type in
                            Button {
                                let basePrice = Int(hourlyRate) ?? 500
                                let price = Int(Double(basePrice) * type.priceMultiplier)
                                lessonTypes.append(NewLessonType(
                                    name: type.name,
                                    description: type.description,
                                    duration: type.duration,
                                    price: price
                                ))
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
                                    
                                    Image(systemName: "plus.circle.fill")
                                        .foregroundColor(.black)
                                }
                                .padding()
                                .background(Color(.systemGray6))
                                .cornerRadius(12)
                            }
                            .foregroundColor(.primary)
                        }
                    }
                    .padding()
                    .background(Color.black.opacity(0.1))
                    .cornerRadius(12)
                }
                
                // Added lesson types
                if !lessonTypes.isEmpty {
                    VStack(alignment: .leading, spacing: 12) {
                        Text("Dina lektionstyper:")
                            .font(.headline)
                        
                        ForEach(lessonTypes) { type in
                            HStack {
                                VStack(alignment: .leading, spacing: 4) {
                                    Text(type.name)
                                        .font(.subheadline)
                                        .fontWeight(.medium)
                                    Text("\(type.duration) min • \(type.price) kr")
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
                
                Button {
                    showAddLessonType = true
                } label: {
                    HStack {
                        Image(systemName: "plus.circle.fill")
                        Text("Lägg till egen lektionstyp")
                    }
                    .font(.headline)
                    .foregroundColor(.black)
                    .frame(maxWidth: .infinity)
                    .padding()
                    .background(Color.black.opacity(0.15))
                    .cornerRadius(12)
                }
                
                Spacer()
            }
            .padding()
        }
    }
    
    // MARK: - Step 5: Location with Service Area
    
    private var step5Location: some View {
        VStack(spacing: 16) {
            Text("Var kan du hålla lektioner?")
                .font(.headline)
            
            Text("Flytta kartan för att välja centrum, justera sedan radien")
                .font(.subheadline)
                .foregroundColor(.secondary)
                .multilineTextAlignment(.center)
            
            // Simple Map with SwiftUI
            ZStack {
                Map(coordinateRegion: $region)
                    .cornerRadius(12)
                    .onChange(of: region.center.latitude) { _ in
                        // Auto-update selected location when map moves
                        selectedLocation = region.center
                    }
                
                // Circle overlay (visual only - drawn on top)
                Circle()
                    .stroke(Color.black, lineWidth: 2)
                    .background(Circle().fill(Color.black.opacity(0.1)))
                    .frame(width: circleSize, height: circleSize)
                
                // Center pin
                Image(systemName: "mappin.circle.fill")
                    .font(.system(size: 32))
                    .foregroundColor(.black)
            }
            .frame(height: 280)
            
            // Radius slider
            VStack(spacing: 8) {
                HStack {
                    Text("Täckningsområde")
                        .font(.subheadline)
                        .foregroundColor(.secondary)
                    Spacer()
                    Text("\(Int(serviceRadiusKm)) km radie")
                        .font(.system(size: 16, weight: .bold))
                }
                
                HStack(spacing: 12) {
                    Text("1")
                        .font(.caption)
                        .foregroundColor(.secondary)
                    
                    Slider(value: $serviceRadiusKm, in: 1...50, step: 1)
                        .accentColor(.black)
                    
                    Text("50")
                        .font(.caption)
                        .foregroundColor(.secondary)
                }
            }
            .padding()
            .background(Color(.systemGray6))
            .cornerRadius(12)
            
            // Status indicator
            HStack {
                Image(systemName: "checkmark.circle.fill")
                    .foregroundColor(.green)
                Text("Täckningsområde: \(Int(serviceRadiusKm)) km radie")
                    .font(.subheadline)
            }
            .padding()
            .frame(maxWidth: .infinity)
            .background(Color.green.opacity(0.1))
            .cornerRadius(12)
            
            Spacer()
        }
        .padding()
        .onAppear {
            if let userLocation = locationManager.userLocation {
                region.center = userLocation
            }
            // Auto-set location on appear
            selectedLocation = region.center
        }
    }
    
    // Calculate circle size based on radius and current map zoom
    private var circleSize: CGFloat {
        // Approximate: at zoom level showing ~0.1 degree, 10km ≈ 100px
        let degreesPerKm = 1.0 / 111.0
        let radiusInDegrees = serviceRadiusKm * degreesPerKm
        let mapWidthInDegrees = region.span.latitudeDelta
        let screenWidth: CGFloat = 280 // map frame height
        let pixelsPerDegree = screenWidth / mapWidthInDegrees
        return min(CGFloat(radiusInDegrees * 2 * pixelsPerDegree), screenWidth * 0.9)
    }
    
    // MARK: - Step 6: Review
    
    private var step6Review: some View {
        ScrollView {
            VStack(spacing: 20) {
                Text("Granska din profil")
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
                                .foregroundColor(.black)
                                .background(Circle().fill(.white).frame(width: 20, height: 20))
                        }
                    }
                    
                    if !hasProfilePicture {
                        Text("⚠️ Du måste ha en profilbild")
                            .font(.caption)
                            .foregroundColor(.red)
                    } else {
                        Text("Tryck för att ändra profilbild")
                            .font(.caption)
                            .foregroundColor(.secondary)
                    }
                    
                    Text(name.isEmpty ? "Ditt namn" : name)
                        .font(.title3)
                        .fontWeight(.semibold)
                    
                    HStack(spacing: 16) {
                        StatBadge(icon: "figure.golf", value: "HCP \(handicap.isEmpty ? "?" : handicap)")
                        StatBadge(icon: "clock", value: "\(hourlyRate.isEmpty ? "?" : hourlyRate) kr/h")
                    }
                    
                    Text(description.isEmpty ? "Din beskrivning..." : description)
                        .font(.body)
                        .foregroundColor(.secondary)
                        .multilineTextAlignment(.center)
                        .lineLimit(3)
                }
                .padding()
                .background(Color(.systemGray6))
                .cornerRadius(16)
                
                // Checklist
                VStack(alignment: .leading, spacing: 12) {
                    ChecklistItem(text: "Profilbild", isComplete: hasProfilePicture)
                    ChecklistItem(text: "Namn", isComplete: !name.isEmpty)
                    ChecklistItem(text: "Beskrivning", isComplete: !description.isEmpty)
                    ChecklistItem(text: "Pris", isComplete: !hourlyRate.isEmpty)
                    ChecklistItem(text: "Handicap", isComplete: !handicap.isEmpty)
                    ChecklistItem(text: "Plats", isComplete: selectedLocation != nil)
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
                    Text("Tillbaka")
                        .font(.headline)
                        .foregroundColor(.black)
                        .frame(maxWidth: .infinity)
                        .padding()
                        .background(Color(.systemGray5))
                        .cornerRadius(12)
                }
            }
            
            Button {
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
                    Text(currentStep < totalSteps - 1 ? "Nästa" : "Ansök")
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
    
    private var canProceed: Bool {
        switch currentStep {
        case 0: return !name.isEmpty && !description.isEmpty
        case 1: return !hourlyRate.isEmpty && !handicap.isEmpty
        case 2: return !selectedSpecialties.isEmpty
        case 3: return true // Lesson types är valfritt
        case 4: return selectedLocation != nil
        case 5: return hasProfilePicture && !name.isEmpty && !description.isEmpty && !hourlyRate.isEmpty && !handicap.isEmpty && selectedLocation != nil
        default: return true
        }
    }
    
    private func submitProfile() {
        guard let location = selectedLocation,
              let rate = Int(hourlyRate),
              let hcp = Int(handicap) else {
            errorMessage = "Vänligen fyll i alla fält korrekt"
            return
        }
        
        isSubmitting = true
        
        Task {
            do {
                // 1. Create trainer profile
                let trainer = try await TrainerService.shared.createTrainerProfile(
                    name: name,
                    description: description,
                    hourlyRate: rate,
                    handicap: hcp,
                    latitude: location.latitude,
                    longitude: location.longitude,
                    serviceRadiusKm: serviceRadiusKm
                )
                
                createdTrainerId = trainer.id
                
                // 2. Update extended profile fields
                try await TrainerService.shared.updateTrainerExtendedProfile(
                    trainerId: trainer.id,
                    city: city.isEmpty ? nil : city,
                    bio: nil,
                    experienceYears: Int(experienceYears),
                    clubAffiliation: clubAffiliation.isEmpty ? nil : clubAffiliation
                )
                
                // 3. Save specialties
                if !selectedSpecialties.isEmpty {
                    try await TrainerService.shared.saveTrainerSpecialties(
                        trainerId: trainer.id,
                        specialtyIds: Array(selectedSpecialties)
                    )
                }
                
                // 4. Save lesson types
                for lessonType in lessonTypes {
                    _ = try await TrainerService.shared.saveLessonType(
                        trainerId: trainer.id,
                        name: lessonType.name,
                        description: lessonType.description,
                        durationMinutes: lessonType.duration,
                        price: lessonType.price
                    )
                }
                
                await MainActor.run {
                    isSubmitting = false
                    showConfirmation = true
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

// MARK: - Day Availability Model

struct DayAvailability: Identifiable {
    let id = UUID()
    let dayOfWeek: Int
    let dayName: String
    var isEnabled: Bool
    var startTime: Date
    var endTime: Date
    
    static func defaultWeek() -> [DayAvailability] {
        let days = ["Söndag", "Måndag", "Tisdag", "Onsdag", "Torsdag", "Fredag", "Lördag"]
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
                Section("Lektionstyp") {
                    TextField("Namn (ex: 60 min lektion)", text: $name)
                    TextField("Beskrivning", text: $description)
                }
                
                Section("Detaljer") {
                    HStack {
                        Text("Längd")
                        Spacer()
                        TextField("60", text: $duration)
                            .keyboardType(.numberPad)
                            .frame(width: 60)
                            .multilineTextAlignment(.trailing)
                        Text("min")
                            .foregroundColor(.secondary)
                    }
                    
                    HStack {
                        Text("Pris")
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
            .navigationTitle("Ny lektionstyp")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarLeading) {
                    Button("Avbryt") {
                        dismiss()
                    }
                }
                
                ToolbarItem(placement: .topBarTrailing) {
                    Button("Lägg till") {
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
                    .foregroundColor(.black)
                Text("Vi behandlar din ansökan")
                    .font(.title3)
                    .fontWeight(.semibold)
                    .multilineTextAlignment(.center)
                Text("Du får ett meddelande när en admin har granskat dina uppgifter.")
                    .font(.body)
                    .foregroundColor(.secondary)
                    .multilineTextAlignment(.center)
                    .padding(.horizontal)
                Spacer()
                Button {
                    onClose()
                } label: {
                    Text("Stäng")
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


