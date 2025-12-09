import SwiftUI
import MapKit
import CoreLocation
import Combine

struct EditTrainerProfileView: View {
    @Environment(\.dismiss) private var dismiss
    @StateObject private var locationManager = EditTrainerLocationManager()
    
    @State private var name: String = ""
    @State private var description: String = ""
    @State private var hourlyRate: String = ""
    @State private var handicap: String = ""
    @State private var selectedLocation: CLLocationCoordinate2D?
    @State private var region = MKCoordinateRegion(
        center: CLLocationCoordinate2D(latitude: 59.3293, longitude: 18.0686),
        span: MKCoordinateSpan(latitudeDelta: 0.05, longitudeDelta: 0.05)
    )
    
    @State private var isLoading = true
    @State private var isSaving = false
    @State private var showSuccess = false
    @State private var errorMessage: String?
    @State private var showError = false
    @State private var trainerId: UUID?
    @State private var isActive = true
    
    var body: some View {
        NavigationStack {
            Group {
                if isLoading {
                    ProgressView("Laddar profil...")
                } else {
                    Form {
                        // Basic Info
                        Section("Grundinfo") {
                            TextField("Namn", text: $name)
                            
                            VStack(alignment: .leading) {
                                Text("Beskrivning")
                                    .font(.caption)
                                    .foregroundColor(.secondary)
                                TextEditor(text: $description)
                                    .frame(height: 100)
                            }
                        }
                        
                        // Pricing
                        Section("Prissattning") {
                            HStack {
                                TextField("Pris per timme", text: $hourlyRate)
                                    .keyboardType(.numberPad)
                                Text("kr/h")
                                    .foregroundColor(.secondary)
                            }
                            
                            HStack {
                                TextField("Handicap", text: $handicap)
                                    .keyboardType(.numberPad)
                                Text("HCP")
                                    .foregroundColor(.secondary)
                            }
                        }
                        
                        // Location
                        Section("Plats") {
                            VStack(alignment: .leading, spacing: 12) {
                                Text("Tryck och hall for att valja plats. Zooma och panorera fritt.")
                                    .font(.caption)
                                    .foregroundColor(.secondary)
                                
                                ZStack(alignment: .topTrailing) {
                                    InteractiveMapView(
                                        region: $region,
                                        selectedLocation: $selectedLocation
                                    )
                                    .frame(height: 250)
                                    .cornerRadius(12)
                                    
                                    // Zoom buttons
                                    VStack(spacing: 0) {
                                        Image(systemName: "plus")
                                            .font(.title3)
                                            .fontWeight(.semibold)
                                            .foregroundColor(.primary)
                                            .frame(width: 44, height: 44)
                                            .background(Color.white.opacity(0.9))
                                            .contentShape(Rectangle())
                                            .onTapGesture {
                                                zoomIn()
                                            }
                                        
                                        Divider()
                                            .frame(width: 44)
                                            .background(Color.gray.opacity(0.3))
                                        
                                        Image(systemName: "minus")
                                            .font(.title3)
                                            .fontWeight(.semibold)
                                            .foregroundColor(.primary)
                                            .frame(width: 44, height: 44)
                                            .background(Color.white.opacity(0.9))
                                            .contentShape(Rectangle())
                                            .onTapGesture {
                                                zoomOut()
                                            }
                                    }
                                    .clipShape(RoundedRectangle(cornerRadius: 8))
                                    .shadow(color: .black.opacity(0.25), radius: 4, y: 2)
                                    .padding(10)
                                }
                                
                                if let loc = selectedLocation {
                                    HStack {
                                        Image(systemName: "mappin.circle.fill")
                                            .foregroundColor(.black)
                                        Text("Vald plats: \(String(format: "%.4f", loc.latitude)), \(String(format: "%.4f", loc.longitude))")
                                            .font(.caption)
                                            .foregroundColor(.black)
                                    }
                                }
                                
                                Button {
                                    if let userLoc = locationManager.userLocation {
                                        selectedLocation = userLoc
                                        region.center = userLoc
                                    }
                                } label: {
                                    HStack {
                                        Image(systemName: "location.fill")
                                        Text("Anvand min nuvarande plats")
                                    }
                                    .font(.subheadline)
                                }
                            }
                        }
                        
                        // Status
                        Section("Status") {
                            Toggle("Annons aktiv", isOn: $isActive)
                            
                            if !isActive {
                                Text("Din annons visas inte for andra användare")
                                    .font(.caption)
                                    .foregroundColor(.orange)
                            }
                        }
                    }
                }
            }
            .navigationTitle("Hantera annons")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarLeading) {
                    Button("Avbryt") {
                        dismiss()
                    }
                }
                
                ToolbarItem(placement: .topBarTrailing) {
                    Button {
                        saveChanges()
                    } label: {
                        if isSaving {
                            ProgressView()
                        } else {
                            Text("Spara")
                                .fontWeight(.semibold)
                        }
                    }
                    .disabled(isSaving || !isFormValid)
                }
            }
            .task {
                await loadProfile()
            }
            .alert("Sparat!", isPresented: $showSuccess) {
                Button("OK") {
                    dismiss()
                }
            } message: {
                Text("Dina andringar har sparats.")
            }
            .alert("Fel", isPresented: $showError) {
                Button("OK") { }
            } message: {
                Text(errorMessage ?? "Ett fel uppstod")
            }
        }
    }
    
    private var selectedLocationAnnotations: [LocationAnnotation] {
        if let loc = selectedLocation {
            return [LocationAnnotation(coordinate: loc)]
        }
        return []
    }
    
    private var isFormValid: Bool {
        !name.isEmpty &&
        !description.isEmpty &&
        Int(hourlyRate) != nil &&
        Int(handicap) != nil &&
        selectedLocation != nil
    }
    
    private func zoomIn() {
        let newSpan = MKCoordinateSpan(
            latitudeDelta: max(region.span.latitudeDelta / 2, 0.001),
            longitudeDelta: max(region.span.longitudeDelta / 2, 0.001)
        )
        withAnimation {
            region.span = newSpan
        }
    }
    
    private func zoomOut() {
        let newSpan = MKCoordinateSpan(
            latitudeDelta: min(region.span.latitudeDelta * 2, 100),
            longitudeDelta: min(region.span.longitudeDelta * 2, 100)
        )
        withAnimation {
            region.span = newSpan
        }
    }
    
    private func loadProfile() async {
        isLoading = true
        
        do {
            if let profile = try await TrainerService.shared.getUserTrainerProfile() {
                await MainActor.run {
                    self.trainerId = profile.id
                    self.name = profile.name
                    self.description = profile.description
                    self.hourlyRate = "\(profile.hourlyRate)"
                    self.handicap = "\(profile.handicap)"
                    self.selectedLocation = profile.coordinate
                    self.region.center = profile.coordinate
                    self.isActive = true // Assuming active since we fetched it
                    self.isLoading = false
                }
            } else {
                await MainActor.run {
                    self.errorMessage = "Kunde inte hitta din tranarprofil"
                    self.showError = true
                    self.isLoading = false
                }
            }
        } catch {
            await MainActor.run {
                self.errorMessage = error.localizedDescription
                self.showError = true
                self.isLoading = false
            }
        }
    }
    
    private func saveChanges() {
        guard let trainerId = trainerId,
              let location = selectedLocation,
              let rate = Int(hourlyRate),
              let hcp = Int(handicap) else {
            return
        }
        
        isSaving = true
        
        Task {
            do {
                try await TrainerService.shared.updateTrainerProfile(
                    trainerId: trainerId,
                    name: name,
                    description: description,
                    hourlyRate: rate,
                    handicap: hcp,
                    latitude: location.latitude,
                    longitude: location.longitude,
                    isActive: isActive
                )
                
                await MainActor.run {
                    isSaving = false
                    showSuccess = true
                }
            } catch {
                await MainActor.run {
                    isSaving = false
                    errorMessage = error.localizedDescription
                    showError = true
                }
            }
        }
    }
}

// MARK: - Location Annotation

struct LocationAnnotation: Identifiable {
    let id = UUID()
    let coordinate: CLLocationCoordinate2D
}

// MARK: - Interactive Map View (UIViewRepresentable)

struct InteractiveMapView: UIViewRepresentable {
    @Binding var region: MKCoordinateRegion
    @Binding var selectedLocation: CLLocationCoordinate2D?
    
    func makeUIView(context: Context) -> MKMapView {
        let mapView = MKMapView()
        mapView.delegate = context.coordinator
        mapView.showsUserLocation = true
        mapView.isZoomEnabled = true
        mapView.isScrollEnabled = true
        mapView.isRotateEnabled = true
        mapView.isPitchEnabled = true
        
        // Set initial region
        mapView.setRegion(region, animated: false)
        
        // Add long press gesture for selecting location
        let longPress = UILongPressGestureRecognizer(
            target: context.coordinator,
            action: #selector(Coordinator.handleLongPress(_:))
        )
        longPress.minimumPressDuration = 0.5
        mapView.addGestureRecognizer(longPress)
        
        return mapView
    }
    
    func updateUIView(_ mapView: MKMapView, context: Context) {
        // Update region if center or zoom level changed significantly
        let currentCenter = mapView.region.center
        let currentSpan = mapView.region.span
        let newCenter = region.center
        let newSpan = region.span
        let centerThreshold = 0.0001
        let spanThreshold = 0.001
        
        let centerChanged = abs(currentCenter.latitude - newCenter.latitude) > centerThreshold ||
                           abs(currentCenter.longitude - newCenter.longitude) > centerThreshold
        let spanChanged = abs(currentSpan.latitudeDelta - newSpan.latitudeDelta) > spanThreshold ||
                         abs(currentSpan.longitudeDelta - newSpan.longitudeDelta) > spanThreshold
        
        if centerChanged || spanChanged {
            mapView.setRegion(region, animated: true)
        }
        
        // Update annotation
        mapView.removeAnnotations(mapView.annotations.filter { !($0 is MKUserLocation) })
        
        if let location = selectedLocation {
            let annotation = MKPointAnnotation()
            annotation.coordinate = location
            annotation.title = "Vald plats"
            mapView.addAnnotation(annotation)
        }
    }
    
    func makeCoordinator() -> Coordinator {
        Coordinator(self)
    }
    
    class Coordinator: NSObject, MKMapViewDelegate {
        var parent: InteractiveMapView
        var isProgrammaticUpdate = false
        
        init(_ parent: InteractiveMapView) {
            self.parent = parent
        }
        
        @objc func handleLongPress(_ gesture: UILongPressGestureRecognizer) {
            guard gesture.state == .began else { return }
            
            let mapView = gesture.view as! MKMapView
            let point = gesture.location(in: mapView)
            let coordinate = mapView.convert(point, toCoordinateFrom: mapView)
            
            // Haptic feedback
            let generator = UIImpactFeedbackGenerator(style: .medium)
            generator.impactOccurred()
            
            parent.selectedLocation = coordinate
        }
        
        func mapView(_ mapView: MKMapView, regionDidChangeAnimated animated: Bool) {
            // Only update parent region when user interacts with the map
            // Skip if this was a programmatic update from zoom buttons
            DispatchQueue.main.async {
                self.parent.region = mapView.region
            }
        }
        
        func mapView(_ mapView: MKMapView, viewFor annotation: MKAnnotation) -> MKAnnotationView? {
            guard !(annotation is MKUserLocation) else { return nil }
            
            let identifier = "SelectedLocation"
            var annotationView = mapView.dequeueReusableAnnotationView(withIdentifier: identifier) as? MKMarkerAnnotationView
            
            if annotationView == nil {
                annotationView = MKMarkerAnnotationView(annotation: annotation, reuseIdentifier: identifier)
                annotationView?.canShowCallout = true
            } else {
                annotationView?.annotation = annotation
            }
            
            annotationView?.markerTintColor = .systemGreen
            annotationView?.glyphImage = UIImage(systemName: "figure.golf")
            
            return annotationView
        }
    }
}

// MARK: - Location Manager

final class EditTrainerLocationManager: NSObject, ObservableObject, CLLocationManagerDelegate {
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
            Task { @MainActor in
                self.userLocation = location.coordinate
            }
            locationManager.stopUpdatingLocation()
        }
    }
}

#Preview {
    EditTrainerProfileView()
}

