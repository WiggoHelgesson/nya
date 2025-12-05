import SwiftUI
import MapKit
import CoreLocation

struct TrainerOnboardingView: View {
    @Environment(\.dismiss) private var dismiss
    @StateObject private var locationManager = OnboardingLocationManager()
    
    @State private var currentStep = 0
    @State private var name = ""
    @State private var description = ""
    @State private var hourlyRate = ""
    @State private var handicap = ""
    @State private var selectedLocation: CLLocationCoordinate2D?
    @State private var region = MKCoordinateRegion(
        center: CLLocationCoordinate2D(latitude: 59.3293, longitude: 18.0686),
        span: MKCoordinateSpan(latitudeDelta: 0.05, longitudeDelta: 0.05)
    )
    
    @State private var isSubmitting = false
    @State private var showSuccess = false
    @State private var errorMessage: String?
    
    var body: some View {
        NavigationStack {
            VStack(spacing: 0) {
                // Progress indicator
                progressIndicator
                
                // Content
                TabView(selection: $currentStep) {
                    step1NameDescription.tag(0)
                    step2PriceHandicap.tag(1)
                    step3Location.tag(2)
                    step4Review.tag(3)
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
            .alert("Fel", isPresented: .init(
                get: { errorMessage != nil },
                set: { if !$0 { errorMessage = nil } }
            )) {
                Button("OK") { errorMessage = nil }
            } message: {
                Text(errorMessage ?? "")
            }
            .alert("Tränarprofil skapad!", isPresented: $showSuccess) {
                Button("Perfekt!") {
                    dismiss()
                }
            } message: {
                Text("Din profil är nu synlig för alla golfare i närheten. Lycka till!")
            }
        }
    }
    
    // MARK: - Progress Indicator
    
    private var progressIndicator: some View {
        HStack(spacing: 8) {
            ForEach(0..<4) { step in
                Capsule()
                    .fill(step <= currentStep ? Color.green : Color.gray.opacity(0.3))
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
                    
                    Text("Visa ditt spelhandicap så eleverna vet din nivå.")
                        .font(.caption)
                        .foregroundColor(.secondary)
                    
                    TextField("Ex: 5", text: $handicap)
                        .keyboardType(.numberPad)
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
    
    // MARK: - Step 3: Location
    
    private var step3Location: some View {
        VStack(spacing: 16) {
            Text("Var håller du lektioner?")
                .font(.headline)
            
            Text("Tryck på kartan för att placera din pin")
                .font(.subheadline)
                .foregroundColor(.secondary)
            
            ZStack {
                Map(coordinateRegion: $region, annotationItems: selectedLocation.map { [LocationPin(coordinate: $0)] } ?? []) { pin in
                    MapAnnotation(coordinate: pin.coordinate) {
                        Image(systemName: "mappin.circle.fill")
                            .font(.largeTitle)
                            .foregroundColor(.green)
                    }
                }
                .gesture(
                    DragGesture(minimumDistance: 0)
                        .onEnded { value in
                            // This is a simplified tap detection
                        }
                )
                .onTapGesture { location in
                    // Get tap location on map
                    // For simplicity, use the center of the region
                }
                .cornerRadius(12)
                
                // Crosshair in center
                VStack {
                    Spacer()
                    HStack {
                        Spacer()
                        Image(systemName: "plus")
                            .font(.title)
                            .foregroundColor(.green)
                            .padding(8)
                            .background(Circle().fill(.white))
                            .shadow(radius: 4)
                        Spacer()
                    }
                    Spacer()
                }
            }
            .frame(height: 300)
            
            Button {
                // Use center of map as selected location
                selectedLocation = region.center
            } label: {
                HStack {
                    Image(systemName: "mappin.and.ellipse")
                    Text("Sätt pin här")
                }
                .font(.headline)
                .foregroundColor(.white)
                .frame(maxWidth: .infinity)
                .padding()
                .background(Color.green)
                .cornerRadius(12)
            }
            
            if let location = selectedLocation {
                HStack {
                    Image(systemName: "checkmark.circle.fill")
                        .foregroundColor(.green)
                    Text("Plats vald!")
                        .foregroundColor(.green)
                }
                .font(.subheadline)
            }
            
            Spacer()
        }
        .padding()
        .onAppear {
            if let userLocation = locationManager.userLocation {
                region.center = userLocation
            }
        }
    }
    
    // MARK: - Step 4: Review
    
    private var step4Review: some View {
        ScrollView {
            VStack(spacing: 20) {
                Text("Granska din profil")
                    .font(.title2)
                    .fontWeight(.bold)
                
                // Preview card
                VStack(spacing: 16) {
                    Image(systemName: "person.circle.fill")
                        .font(.system(size: 60))
                        .foregroundColor(.gray)
                    
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
                if currentStep < 3 {
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
                        .background(Color.green)
                        .cornerRadius(12)
                } else {
                    Text(currentStep < 3 ? "Nästa" : "Skapa profil")
                        .font(.headline)
                        .foregroundColor(.white)
                        .frame(maxWidth: .infinity)
                        .padding()
                        .background(canProceed ? Color.green : Color.gray)
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
        case 2: return selectedLocation != nil
        case 3: return !name.isEmpty && !description.isEmpty && !hourlyRate.isEmpty && !handicap.isEmpty && selectedLocation != nil
        default: return false
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
                _ = try await TrainerService.shared.createTrainerProfile(
                    name: name,
                    description: description,
                    hourlyRate: rate,
                    handicap: hcp,
                    latitude: location.latitude,
                    longitude: location.longitude
                )
                
                await MainActor.run {
                    isSubmitting = false
                    showSuccess = true
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

// MARK: - Helper Views

struct RoundedTextFieldStyle: TextFieldStyle {
    func _body(configuration: TextField<Self._Label>) -> some View {
        configuration
            .padding()
            .background(Color(.systemGray6))
            .cornerRadius(12)
    }
}

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

#Preview {
    TrainerOnboardingView()
}

