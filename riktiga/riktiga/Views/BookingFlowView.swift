import SwiftUI
import MapKit
import StripePaymentSheet
import Combine

struct BookingFlowView: View {
    let trainer: GolfTrainer
    let onComplete: () -> Void
    
    @Environment(\.dismiss) private var dismiss
    @StateObject private var viewModel: BookingFlowViewModel
    
    @State private var currentStep = 0
    @State private var showPaymentSheet = false
    @State private var showConfirmation = false
    
    init(trainer: GolfTrainer, onComplete: @escaping () -> Void) {
        self.trainer = trainer
        self.onComplete = onComplete
        _viewModel = StateObject(wrappedValue: BookingFlowViewModel(trainer: trainer))
    }
    
    var body: some View {
        NavigationStack {
            VStack(spacing: 0) {
                // Progress indicator
                progressIndicator
                
                // Content based on step (no swipe, buttons only)
                Group {
                    switch currentStep {
                    case 0: step1LessonType
                    case 1: step2DateTime
                    case 2: step3Location
                    case 3: step4Summary
                    default: step1LessonType
                    }
                }
                .animation(.easeInOut, value: currentStep)
                
                // Navigation
                navigationButtons
            }
            .navigationTitle("Boka lektion")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarLeading) {
                    Button("Avbryt") {
                        dismiss()
                    }
                }
            }
            .task {
                await viewModel.loadLessonTypes()
                await viewModel.loadGolfCourses()
            }
            .sheet(isPresented: $showPaymentSheet) {
                TrainerPaymentView(
                    trainer: trainer,
                    amount: viewModel.selectedLessonType?.price ?? trainer.hourlyRate,
                    lessonType: viewModel.selectedLessonType,
                    onPaymentSuccess: { paymentId in
                        Task {
                            await viewModel.createBooking(stripePaymentId: paymentId)
                            showConfirmation = true
                        }
                    }
                )
            }
            .fullScreenCover(isPresented: $showConfirmation) {
                BookingConfirmationView(
                    trainer: trainer,
                    lessonType: viewModel.selectedLessonType,
                    date: viewModel.formattedDate,
                    time: viewModel.formattedTime,
                    location: viewModel.locationDescription,
                    price: viewModel.totalPrice,
                    onDismiss: {
                        onComplete()
                        dismiss()
                    }
                )
            }
            .alert("Fel", isPresented: $viewModel.showError) {
                Button("OK") {}
            } message: {
                Text(viewModel.errorMessage ?? "Ett fel uppstod")
            }
        }
    }
    
    // MARK: - Progress Indicator
    
    private var progressIndicator: some View {
        VStack(spacing: 8) {
            HStack(spacing: 8) {
                ForEach(0..<4) { step in
                    VStack(spacing: 4) {
                        Circle()
                            .fill(step <= currentStep ? Color.black : Color.gray.opacity(0.3))
                            .frame(width: step == currentStep ? 12 : 8, height: step == currentStep ? 12 : 8)
                        
                        Text(stepTitle(for: step))
                            .font(.system(size: 10))
                            .foregroundColor(step <= currentStep ? .primary : .secondary)
                    }
                    
                    if step < 3 {
                        Rectangle()
                            .fill(step < currentStep ? Color.black : Color.gray.opacity(0.3))
                            .frame(height: 2)
                    }
                }
            }
            .padding(.horizontal)
        }
        .padding(.vertical, 12)
        .background(Color(.systemBackground))
    }
    
    private func stepTitle(for step: Int) -> String {
        switch step {
        case 0: return "Lektion"
        case 1: return "Tid"
        case 2: return "Plats"
        case 3: return "Betala"
        default: return ""
        }
    }
    
    // MARK: - Step 1: Lesson Type
    
    private var step1LessonType: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 20) {
                Text("Välj typ av lektion")
                    .font(.title2)
                    .fontWeight(.bold)
                
                if viewModel.isLoadingLessonTypes {
                    ProgressView()
                        .frame(maxWidth: .infinity, minHeight: 200)
                } else if viewModel.lessonTypes.isEmpty {
                    // Default lesson type based on hourly rate
                    LessonTypeCard(
                        name: "60 min lektion",
                        description: "Individuell lektion med \(trainer.name)",
                        duration: 60,
                        price: trainer.hourlyRate,
                        isSelected: viewModel.selectedLessonType == nil
                    ) {
                        viewModel.selectedLessonType = nil
                        viewModel.customLessonPrice = trainer.hourlyRate
                        viewModel.customLessonDuration = 60
                    }
                } else {
                    ForEach(viewModel.lessonTypes) { lessonType in
                        LessonTypeCard(
                            name: lessonType.name,
                            description: lessonType.description ?? "",
                            duration: lessonType.durationMinutes,
                            price: lessonType.price,
                            isSelected: viewModel.selectedLessonType?.id == lessonType.id
                        ) {
                            viewModel.selectedLessonType = lessonType
                        }
                    }
                }
            }
            .padding()
        }
    }
    
    // MARK: - Step 2: Date & Time
    
    private var step2DateTime: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 20) {
                Text("Välj datum och tid")
                    .font(.title2)
                    .fontWeight(.bold)
                
                // Date picker
                VStack(alignment: .leading, spacing: 8) {
                    Text("Datum")
                        .font(.headline)
                    
                    DatePicker(
                        "Välj datum",
                        selection: $viewModel.selectedDate,
                        in: Date()...,
                        displayedComponents: .date
                    )
                    .datePickerStyle(.graphical)
                    .tint(.green)
                }
                .padding()
                .background(Color(.systemGray6))
                .cornerRadius(12)
                
                // Time picker
                VStack(alignment: .leading, spacing: 12) {
                    Text("Tid")
                        .font(.headline)
                    
                    if viewModel.isLoadingSlots {
                        HStack {
                            ProgressView()
                            Text("Laddar lediga tider...")
                                .foregroundColor(.secondary)
                        }
                        .padding()
                    } else if viewModel.availableSlots.isEmpty {
                        VStack(spacing: 12) {
                            Image(systemName: "calendar.badge.exclamationmark")
                                .font(.largeTitle)
                                .foregroundColor(.orange)
                            
                            Text("Tränaren är inte tillgänglig denna dag")
                                .font(.subheadline)
                                .foregroundColor(.secondary)
                                .multilineTextAlignment(.center)
                            
                            Text("Välj en annan dag i kalendern ovan")
                                .font(.caption)
                                .foregroundColor(.secondary)
                        }
                        .frame(maxWidth: .infinity)
                        .padding()
                    } else {
                        LazyVGrid(columns: [GridItem(.flexible()), GridItem(.flexible()), GridItem(.flexible())], spacing: 10) {
                            ForEach(viewModel.availableSlots, id: \.self) { slot in
                                Button {
                                    viewModel.selectedTimeSlot = slot
                                } label: {
                                    Text(slot.formattedTime)
                                        .font(.system(size: 14, weight: .medium))
                                        .foregroundColor(viewModel.selectedTimeSlot?.id == slot.id ? .white : .primary)
                                        .padding(.horizontal, 16)
                                        .padding(.vertical, 10)
                                        .frame(maxWidth: .infinity)
                                        .background(viewModel.selectedTimeSlot?.id == slot.id ? Color.black : Color(.systemGray6))
                                        .cornerRadius(8)
                                }
                            }
                        }
                    }
                }
                .padding()
                .background(Color(.systemGray6))
                .cornerRadius(12)
                
                // Message to trainer
                VStack(alignment: .leading, spacing: 8) {
                    Text("Meddelande till tränaren (valfritt)")
                        .font(.headline)
                    
                    TextEditor(text: $viewModel.messageToTrainer)
                        .frame(height: 100)
                        .padding(8)
                        .background(Color(.systemBackground))
                        .cornerRadius(8)
                        .overlay(
                            RoundedRectangle(cornerRadius: 8)
                                .stroke(Color.gray.opacity(0.3))
                        )
                }
                .padding()
                .background(Color(.systemGray6))
                .cornerRadius(12)
            }
            .padding()
        }
        .onChange(of: viewModel.selectedDate) { _ in
            Task { await viewModel.loadAvailableSlots() }
        }
    }
    
    // MARK: - Step 3: Location (Only within trainer's service area)
    
    private var step3Location: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 20) {
                Text("Välj plats för lektionen")
                    .font(.title2)
                    .fontWeight(.bold)
                
                Text("Placera pinen inom tränarens täckningsområde")
                    .font(.subheadline)
                    .foregroundColor(.secondary)
                
                // Service area map - only option
                serviceAreaPicker
            }
            .padding()
        }
        .onAppear {
            // Force location type to trainer location
            viewModel.locationType = .trainerLocation
        }
    }
    
    private var serviceAreaPicker: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                Image(systemName: "mappin.and.ellipse")
                    .foregroundColor(.black)
                Text("Tränarens täckningsområde (\(Int(trainer.serviceRadiusKm ?? 10)) km)")
                    .font(.headline)
            }
            
            Text("Flytta kartan för att välja var du vill ha lektionen")
                .font(.caption)
                .foregroundColor(.secondary)
            
            // Map with service area circle and draggable center
            ZStack {
                Map(coordinateRegion: $viewModel.serviceAreaRegion)
                    .cornerRadius(12)
                
                // Service area circle (visual overlay) - shows allowed area
                Circle()
                    .stroke(viewModel.isLocationWithinServiceArea ? Color.green : Color.red, lineWidth: 3)
                    .background(Circle().fill(viewModel.isLocationWithinServiceArea ? Color.green.opacity(0.1) : Color.red.opacity(0.1)))
                    .frame(width: serviceAreaCircleSize, height: serviceAreaCircleSize)
                    .allowsHitTesting(false)
                
                // Center pin - changes color based on validity
                VStack(spacing: 0) {
                    Image(systemName: "mappin.circle.fill")
                        .font(.system(size: 36))
                        .foregroundColor(viewModel.isLocationWithinServiceArea ? .green : .red)
                    
                    Image(systemName: "arrowtriangle.down.fill")
                        .font(.system(size: 12))
                        .foregroundColor(viewModel.isLocationWithinServiceArea ? .green : .red)
                        .offset(y: -5)
                }
                .allowsHitTesting(false)
            }
            .frame(height: 250)
            
            // Status indicator
            if viewModel.isLocationWithinServiceArea {
                HStack {
                    Image(systemName: "checkmark.circle.fill")
                        .foregroundColor(.green)
                    Text("Perfekt! Platsen är inom tränarens område")
                        .font(.subheadline)
                        .foregroundColor(.green)
                }
                .padding()
                .frame(maxWidth: .infinity)
                .background(Color.green.opacity(0.1))
                .cornerRadius(12)
            } else {
                HStack {
                    Image(systemName: "xmark.circle.fill")
                        .foregroundColor(.red)
                    Text("Flytta pinen innanför cirkeln")
                        .font(.subheadline)
                        .foregroundColor(.red)
                }
                .padding()
                .frame(maxWidth: .infinity)
                .background(Color.red.opacity(0.1))
                .cornerRadius(12)
            }
        }
        .padding()
        .background(Color(.systemGray6))
        .cornerRadius(12)
        .onAppear {
            viewModel.initializeServiceAreaRegion(trainer: trainer)
        }
    }
    
    // Calculate circle size based on trainer's radius and map zoom
    private var serviceAreaCircleSize: CGFloat {
        let radiusKm = trainer.serviceRadiusKm ?? 10
        let degreesPerKm = 1.0 / 111.0
        let radiusInDegrees = radiusKm * degreesPerKm
        let mapWidthInDegrees = viewModel.serviceAreaRegion.span.latitudeDelta
        let screenWidth: CGFloat = 220 // map frame height
        let pixelsPerDegree = screenWidth / mapWidthInDegrees
        return min(CGFloat(radiusInDegrees * 2 * pixelsPerDegree), screenWidth * 0.9)
    }
    
    // MARK: - Step 4: Summary & Payment
    
    private var step4Summary: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 20) {
                Text("Sammanfattning")
                    .font(.title2)
                    .fontWeight(.bold)
                
                // Trainer info
                HStack(spacing: 16) {
                    AsyncImage(url: URL(string: trainer.avatarUrl ?? "")) { image in
                        image.resizable().scaledToFill()
                    } placeholder: {
                        Circle().fill(Color.gray.opacity(0.3))
                    }
                    .frame(width: 60, height: 60)
                    .clipShape(Circle())
                    
                    VStack(alignment: .leading, spacing: 4) {
                        Text(trainer.name)
                            .font(.headline)
                        Text("Golftränare")
                            .font(.subheadline)
                            .foregroundColor(.secondary)
                    }
                    
                    Spacer()
                }
                .padding()
                .background(Color(.systemGray6))
                .cornerRadius(12)
                
                // Booking details
                VStack(spacing: 0) {
                    SummaryRow(icon: "book.fill", title: "Lektion", value: viewModel.selectedLessonType?.name ?? "60 min lektion")
                    Divider()
                    SummaryRow(icon: "calendar", title: "Datum", value: viewModel.formattedDate)
                    Divider()
                    SummaryRow(icon: "clock.fill", title: "Tid", value: viewModel.formattedTime)
                    Divider()
                    SummaryRow(icon: "mappin.circle.fill", title: "Plats", value: viewModel.locationDescription)
                }
                .padding()
                .background(Color(.systemGray6))
                .cornerRadius(12)
                
                // Price
                VStack(spacing: 12) {
                    HStack {
                        Text("Lektionsavgift")
                            .foregroundColor(.secondary)
                        Spacer()
                        Text("\(viewModel.totalPrice) kr")
                    }
                    
                    Divider()
                    
                    HStack {
                        Text("Totalt att betala")
                            .font(.headline)
                        Spacer()
                        Text("\(viewModel.totalPrice) kr")
                            .font(.title2)
                            .fontWeight(.bold)
                            .foregroundColor(.black)
                    }
                }
                .padding()
                .background(Color(.systemGray6))
                .cornerRadius(12)
                
                // Terms
                Text("Genom att boka godkänner du våra villkor. Avbokning kan ske senast 24 timmar innan lektionen.")
                    .font(.caption)
                    .foregroundColor(.secondary)
                    .multilineTextAlignment(.center)
                    .padding()
            }
            .padding()
        }
    }
    
    // MARK: - Navigation Buttons
    
    private var navigationButtons: some View {
        HStack(spacing: 16) {
            if currentStep > 0 {
                Button {
                    withAnimation { currentStep -= 1 }
                } label: {
                    HStack {
                        Image(systemName: "chevron.left")
                        Text("Tillbaka")
                    }
                    .font(.headline)
                    .foregroundColor(.primary)
                    .frame(maxWidth: .infinity)
                    .padding()
                    .background(Color(.systemGray5))
                    .cornerRadius(12)
                }
            }
            
            Button {
                if currentStep < 3 {
                    withAnimation { currentStep += 1 }
                } else {
                    showPaymentSheet = true
                }
            } label: {
                HStack {
                    Text(currentStep == 3 ? "Betala \(viewModel.totalPrice) kr" : "Nästa")
                    if currentStep < 3 {
                        Image(systemName: "chevron.right")
                    } else {
                        Image(systemName: "creditcard.fill")
                    }
                }
                .font(.headline)
                .foregroundColor(.white)
                .frame(maxWidth: .infinity)
                .padding()
                .background(canProceed ? Color.black : Color.gray)
                .cornerRadius(12)
            }
            .disabled(!canProceed)
        }
        .padding()
        .background(Color(.systemBackground))
    }
    
    private var canProceed: Bool {
        switch currentStep {
        case 0:
            return true // Lesson type selected or default
        case 1:
            return viewModel.selectedTimeSlot != nil || !viewModel.availableSlots.isEmpty // Must have selected a time
        case 2:
            return viewModel.hasValidLocation
        case 3:
            return true
        default:
            return false
        }
    }
}

// MARK: - Supporting Views

struct LessonTypeCard: View {
    let name: String
    let description: String
    let duration: Int
    let price: Int
    let isSelected: Bool
    let onTap: () -> Void
    
    var body: some View {
        Button(action: onTap) {
            HStack {
                VStack(alignment: .leading, spacing: 4) {
                    Text(name)
                        .font(.headline)
                        .foregroundColor(.primary)
                    
                    if !description.isEmpty {
                        Text(description)
                            .font(.caption)
                            .foregroundColor(.secondary)
                            .lineLimit(2)
                    }
                    
                    HStack(spacing: 12) {
                        Label("\(duration) min", systemImage: "clock")
                        Label("\(price) kr", systemImage: "creditcard")
                    }
                    .font(.caption)
                    .foregroundColor(.secondary)
                }
                
                Spacer()
                
                if isSelected {
                    Image(systemName: "checkmark.circle.fill")
                        .font(.title2)
                        .foregroundColor(.black)
                } else {
                    Circle()
                        .stroke(Color.gray, lineWidth: 2)
                        .frame(width: 24, height: 24)
                }
            }
            .padding()
            .background(isSelected ? Color.black.opacity(0.1) : Color(.systemGray6))
            .cornerRadius(12)
            .overlay(
                RoundedRectangle(cornerRadius: 12)
                    .stroke(isSelected ? Color.black : Color.clear, lineWidth: 2)
            )
        }
    }
}

struct LocationOptionCard: View {
    let icon: String
    let title: String
    let subtitle: String
    let isSelected: Bool
    let onTap: () -> Void
    
    var body: some View {
        Button(action: onTap) {
            HStack(spacing: 16) {
                Image(systemName: icon)
                    .font(.title2)
                    .foregroundColor(isSelected ? .green : .gray)
                    .frame(width: 44)
                
                VStack(alignment: .leading, spacing: 2) {
                    Text(title)
                        .font(.headline)
                        .foregroundColor(.primary)
                    Text(subtitle)
                        .font(.caption)
                        .foregroundColor(.secondary)
                }
                
                Spacer()
                
                if isSelected {
                    Image(systemName: "checkmark.circle.fill")
                        .foregroundColor(.black)
                }
            }
            .padding()
            .background(isSelected ? Color.black.opacity(0.1) : Color(.systemGray6))
            .cornerRadius(12)
        }
    }
}

struct SummaryRow: View {
    let icon: String
    let title: String
    let value: String
    
    var body: some View {
        HStack {
            Image(systemName: icon)
                .foregroundColor(.black)
                .frame(width: 30)
            
            Text(title)
                .foregroundColor(.secondary)
            
            Spacer()
            
            Text(value)
                .fontWeight(.medium)
        }
        .padding(.vertical, 12)
    }
}

// MARK: - ViewModel

@MainActor
class BookingFlowViewModel: ObservableObject {
    let trainer: GolfTrainer
    
    // Lesson Type
    @Published var lessonTypes: [TrainerLessonType] = []
    @Published var selectedLessonType: TrainerLessonType?
    @Published var customLessonPrice: Int = 0
    @Published var customLessonDuration: Int = 60
    @Published var isLoadingLessonTypes = false
    
    // Date & Time
    @Published var selectedDate = Date()
    @Published var selectedTime = Date()
    @Published var selectedTimeSlot: TimeSlot?
    @Published var availableSlots: [TimeSlot] = []
    @Published var isLoadingSlots = false
    @Published var messageToTrainer = ""
    
    // Location
    @Published var locationType: BookingLocationType = .trainerLocation
    @Published var golfCourses: [GolfCourse] = []
    @Published var selectedCourse: GolfCourse?
    @Published var customLocationName = ""
    @Published var customLocationRegion = MKCoordinateRegion(
        center: CLLocationCoordinate2D(latitude: 59.3293, longitude: 18.0686),
        span: MKCoordinateSpan(latitudeDelta: 0.05, longitudeDelta: 0.05)
    )
    @Published var serviceAreaRegion = MKCoordinateRegion(
        center: CLLocationCoordinate2D(latitude: 59.3293, longitude: 18.0686),
        span: MKCoordinateSpan(latitudeDelta: 0.1, longitudeDelta: 0.1)
    )
    @Published var isLoadingCourses = false
    
    // Booking
    @Published var isCreatingBooking = false
    @Published var showError = false
    @Published var errorMessage: String?
    
    init(trainer: GolfTrainer) {
        self.trainer = trainer
        self.customLessonPrice = trainer.hourlyRate
    }
    
    var totalPrice: Int {
        selectedLessonType?.price ?? customLessonPrice
    }
    
    var formattedDate: String {
        let formatter = DateFormatter()
        formatter.locale = Locale(identifier: "sv_SE")
        formatter.dateFormat = "EEEE d MMMM"
        return formatter.string(from: selectedDate).capitalized
    }
    
    var formattedTime: String {
        if let slot = selectedTimeSlot {
            return slot.formattedTime
        }
        let formatter = DateFormatter()
        formatter.dateFormat = "HH:mm"
        return formatter.string(from: selectedTime)
    }
    
    var locationDescription: String {
        // Location within trainer's service area
        if let city = trainer.city {
            return "Inom \(city)-området"
        }
        return "Inom tränarens område"
    }
    
    var hasValidLocation: Bool {
        // Only allow locations within trainer's service area
        return isLocationWithinServiceArea
    }
    
    var isLocationWithinServiceArea: Bool {
        let trainerLocation = CLLocation(latitude: trainer.coordinate.latitude, longitude: trainer.coordinate.longitude)
        let selectedLocation = CLLocation(latitude: serviceAreaRegion.center.latitude, longitude: serviceAreaRegion.center.longitude)
        let distanceKm = trainerLocation.distance(from: selectedLocation) / 1000
        return distanceKm <= (trainer.serviceRadiusKm ?? 10)
    }
    
    func initializeServiceAreaRegion(trainer: GolfTrainer) {
        let radiusKm = trainer.serviceRadiusKm ?? 10
        let spanDelta = (radiusKm / 111.0) * 2.5
        serviceAreaRegion = MKCoordinateRegion(
            center: trainer.coordinate,
            span: MKCoordinateSpan(latitudeDelta: spanDelta, longitudeDelta: spanDelta)
        )
    }
    
    func loadLessonTypes() async {
        isLoadingLessonTypes = true
        do {
            lessonTypes = try await TrainerService.shared.fetchLessonTypes(trainerId: trainer.id)
            if let first = lessonTypes.first {
                selectedLessonType = first
            }
        } catch {
            print("❌ Failed to load lesson types: \(error)")
        }
        isLoadingLessonTypes = false
    }
    
    func loadGolfCourses() async {
        // Use cached courses if available
        if let cached = GolfCoursesCache.shared.courses {
            golfCourses = cached
            return
        }
        
        isLoadingCourses = true
        do {
            let fetched = try await TrainerService.shared.fetchGolfCourses()
            GolfCoursesCache.shared.courses = fetched
            golfCourses = fetched
        } catch {
            print("❌ Failed to load golf courses: \(error)")
        }
        isLoadingCourses = false
    }
    
    func loadAvailableSlots() async {
        isLoadingSlots = true
        
        var slots: [TimeSlot] = []
        let calendar = Calendar.current
        let baseDate = calendar.startOfDay(for: selectedDate)
        let dayOfWeek = calendar.component(.weekday, from: selectedDate) - 1 // Convert to 0=Sunday
        
        do {
            // Fetch trainer's availability from database
            let availability = try await TrainerService.shared.fetchAvailability(trainerId: trainer.id)
            
            // Find availability for selected day
            if let dayAvailability = availability.first(where: { $0.dayOfWeek == dayOfWeek && $0.isActive }) {
                // Parse start and end times
                let startHour = parseHour(from: dayAvailability.startTime)
                let endHour = parseHour(from: dayAvailability.endTime)
                
                let lessonDuration = selectedLessonType?.durationMinutes ?? 60
                
                // Generate slots within availability window
                var currentHour = startHour
                while currentHour < endHour {
                    if let start = calendar.date(byAdding: .hour, value: currentHour, to: baseDate),
                       let end = calendar.date(byAdding: .minute, value: lessonDuration, to: start) {
                        // Only add slot if it ends before trainer's end time
                        let slotEndHour = currentHour + (lessonDuration / 60)
                        if slotEndHour <= endHour {
                            slots.append(TimeSlot(startTime: start, endTime: end))
                        }
                    }
                    currentHour += 1
                }
            }
            // If no availability found for this day, slots will be empty
        } catch {
            print("❌ Failed to load availability: \(error)")
            // Fallback: show no slots if we can't load availability
        }
        
        availableSlots = slots
        selectedTimeSlot = slots.first
        isLoadingSlots = false
    }
    
    private func parseHour(from timeString: String) -> Int {
        // Parse "HH:mm:ss" format
        let components = timeString.split(separator: ":")
        return Int(components.first ?? "9") ?? 9
    }
    
    func createBooking(stripePaymentId: String?) async {
        isCreatingBooking = true
        
        do {
            let timeString = formattedTime + ":00"
            
            // Determine location coordinates based on type
            var locationLat: Double? = nil
            var locationLng: Double? = nil
            var locationName: String? = nil
            
            if locationType == .custom {
                locationLat = customLocationRegion.center.latitude
                locationLng = customLocationRegion.center.longitude
                locationName = customLocationName
            } else if locationType == .trainerLocation {
                locationLat = serviceAreaRegion.center.latitude
                locationLng = serviceAreaRegion.center.longitude
                locationName = "Inom tränarens område"
            }
            
            _ = try await TrainerService.shared.createExtendedBooking(
                trainerId: trainer.id,
                lessonTypeId: selectedLessonType?.id ?? UUID(),
                scheduledDate: selectedDate,
                scheduledTime: timeString,
                durationMinutes: selectedLessonType?.durationMinutes ?? customLessonDuration,
                price: totalPrice,
                locationType: locationType,
                golfCourseId: selectedCourse?.id,
                customLocationName: locationName,
                customLocationLat: locationLat,
                customLocationLng: locationLng,
                message: messageToTrainer.isEmpty ? nil : messageToTrainer,
                stripePaymentId: stripePaymentId
            )
            
            print("✅ Booking created successfully")
        } catch {
            print("❌ Failed to create booking: \(error)")
            errorMessage = error.localizedDescription
            showError = true
        }
        
        isCreatingBooking = false
    }
}

// MARK: - TextField Style

struct RoundedTextFieldStyle: TextFieldStyle {
    func _body(configuration: TextField<Self._Label>) -> some View {
        configuration
            .padding()
            .background(Color(.systemGray6))
            .cornerRadius(12)
    }
}

// MARK: - Golf Courses Cache

private class GolfCoursesCache {
    static let shared = GolfCoursesCache()
    var courses: [GolfCourse]?
    private init() {}
}

