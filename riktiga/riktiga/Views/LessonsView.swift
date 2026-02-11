import SwiftUI
import MapKit
import CoreLocation
import Combine

struct LessonsView: View {
    private let showFullFeature = true
    
    @StateObject private var viewModel = LessonsViewModel()
    @State private var selectedTrainer: GolfTrainer?
    @State private var region = MKCoordinateRegion(
        center: CLLocationCoordinate2D(latitude: 59.3293, longitude: 18.0686),
        span: MKCoordinateSpan(latitudeDelta: 0.1, longitudeDelta: 0.1)
    )
    
    // Search & Filter
    @State private var searchText = ""
    @State private var debouncedSearchText = "" // For debounced search
    @State private var showFilterSheet = false
    @State private var showListView = false
    @State private var filter = TrainerSearchFilter()
    @State private var specialtiesCatalog: [TrainerSpecialty] = []
    @State private var cachedFilteredTrainers: [GolfTrainer] = [] // Cache filtered results
    
    // Debounce timer
    @State private var searchDebounceTask: Task<Void, Never>?
    
    // Performance: Delay heavy map rendering
    @State private var isMapReady = false
    @State private var hasAppeared = false
    
    var body: some View {
        if showFullFeature {
            fullLessonsView
        } else {
            comingSoonView
        }
    }
    
    // MARK: - Coming Soon View
    private var comingSoonView: some View {
        NavigationStack {
            VStack(spacing: 24) {
                Spacer()
                
                Image(systemName: "figure.golf")
                    .font(.system(size: 80))
                    .foregroundColor(.primary)
                
                Text("Golflektioner")
                    .font(.system(size: 28, weight: .bold))
                
                Text("Kommer inom väldigt snar framtid...")
                    .font(.system(size: 18))
                    .foregroundColor(.gray)
                    .multilineTextAlignment(.center)
                    .padding(.horizontal, 40)
                
                Spacer()
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity)
            .background(Color(.systemBackground))
        }
    }
    
    // MARK: - Full Lessons View
    private var fullLessonsView: some View {
        NavigationStack {
            ZStack {
                // Show placeholder color immediately while map loads
                Color(.systemGroupedBackground)
                    .ignoresSafeArea()
                
                if showListView {
                    trainerListView
                } else if isMapReady {
                    trainerMapView
                        .transition(.opacity)
                }
                
                // Header with search - always visible
                VStack(spacing: 0) {
                    searchAndFilterHeader
                    Spacer()
                }
                
                // Loading indicator
                if viewModel.isLoading && !hasAppeared {
                    ProgressView()
                        .scaleEffect(1.5)
                        .padding()
                        .background(.ultraThinMaterial)
                        .cornerRadius(10)
                }
            }
            .onAppear {
                // Use cached data immediately if available
                if !hasAppeared {
                    hasAppeared = true
                    // Show cached trainers instantly
                    if !LessonsViewModel.hasCachedTrainers {
                        viewModel.loadFromCacheImmediately()
                    }
                    updateFilteredTrainers()
                    
                    // Delay map rendering for smoother appearance
                    DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) {
                        withAnimation(.easeIn(duration: 0.2)) {
                            isMapReady = true
                        }
                    }
                }
            }
            .task {
                // Load fresh data in background
                await withTaskGroup(of: Void.self) { group in
                    group.addTask {
                        await self.viewModel.fetchTrainers()
                    }
                    group.addTask {
                        await self.loadSpecialties()
                    }
                }
                updateFilteredTrainers()
                prefetchTrainerImages()
            }
            .onChange(of: searchText) { _, newValue in
                // Debounce search
                searchDebounceTask?.cancel()
                searchDebounceTask = Task {
                    try? await Task.sleep(nanoseconds: 300_000_000) // 300ms debounce
                    guard !Task.isCancelled else { return }
                    await MainActor.run {
                        debouncedSearchText = newValue
                        updateFilteredTrainers()
                    }
                }
            }
            .onChange(of: viewModel.trainers) { _, _ in
                updateFilteredTrainers()
            }
            .sheet(item: $selectedTrainer) { trainer in
                TrainerDetailView(trainer: trainer)
                    .presentationDetents([.medium, .large])
            }
            .sheet(isPresented: $showFilterSheet) {
                FilterSheetView(
                    filter: $filter,
                    specialties: specialtiesCatalog,
                    onApply: {
                        showFilterSheet = false
                        Task { await applyFilter() }
                    }
                )
                .presentationDetents([.medium, .large])
            }
        }
    }
    
    // MARK: - Search and Filter Header
    
    private var searchAndFilterHeader: some View {
        VStack(spacing: 12) {
            // Search bar
            HStack(spacing: 12) {
                HStack {
                    Image(systemName: "magnifyingglass")
                        .foregroundColor(.gray)
                    
                    TextField("Sök tränare, stad eller klubb...", text: $searchText)
                        .textFieldStyle(.plain)
                        .onSubmit {
                            Task { await applyFilter() }
                        }
                    
                    if !searchText.isEmpty {
                        Button {
                            searchText = ""
                            Task { await applyFilter() }
                        } label: {
                            Image(systemName: "xmark.circle.fill")
                                .foregroundColor(.gray)
                        }
                    }
                }
                .padding(12)
                .background(Color(.systemGray6))
                .cornerRadius(12)
                
                // Filter button
                Button {
                    showFilterSheet = true
                } label: {
                    Image(systemName: filter.isEmpty ? "slider.horizontal.3" : "slider.horizontal.3")
                        .font(.system(size: 18, weight: .semibold))
                        .foregroundColor(filter.isEmpty ? .gray : .white)
                        .padding(12)
                        .background(filter.isEmpty ? Color(.systemGray6) : Color.black)
                        .cornerRadius(12)
                }
            }
            
            // Toggle and sort row
            HStack {
                // Map/List toggle
                HStack(spacing: 0) {
                    Button {
                        withAnimation { showListView = false }
                    } label: {
                        Image(systemName: "map")
                            .font(.system(size: 14, weight: .semibold))
                            .foregroundColor(!showListView ? .white : .gray)
                            .padding(.horizontal, 16)
                            .padding(.vertical, 8)
                            .background(!showListView ? Color.black : Color.clear)
                            .cornerRadius(8)
                    }
                    
                    Button {
                        withAnimation { showListView = true }
                    } label: {
                        Image(systemName: "list.bullet")
                            .font(.system(size: 14, weight: .semibold))
                            .foregroundColor(showListView ? .white : .gray)
                            .padding(.horizontal, 16)
                            .padding(.vertical, 8)
                            .background(showListView ? Color.black : Color.clear)
                            .cornerRadius(8)
                    }
                }
                .padding(4)
                .background(Color(.systemGray6))
                .cornerRadius(12)
                
                Spacer()
                
                // Sort picker
                Menu {
                    ForEach(TrainerSortOption.allCases, id: \.self) { option in
                        Button {
                            filter.sortBy = option
                            Task { await applyFilter() }
                        } label: {
                            HStack {
                                Text(option.displayName)
                                if filter.sortBy == option {
                                    Image(systemName: "checkmark")
                                }
                            }
                        }
                    }
                } label: {
                    HStack(spacing: 4) {
                        Text(filter.sortBy.displayName)
                            .font(.system(size: 14, weight: .medium))
                        Image(systemName: "chevron.down")
                            .font(.system(size: 12))
                    }
                    .foregroundColor(.gray)
                    .padding(.horizontal, 12)
                    .padding(.vertical, 8)
                    .background(Color(.systemGray6))
                    .cornerRadius(8)
                }
                
                // Trainer count
                Text("\(filteredTrainers.count) tränare")
                    .font(.system(size: 14))
                    .foregroundColor(.gray)
            }
        }
        .padding()
        .background(
            RoundedRectangle(cornerRadius: 16)
                .fill(Color(.systemBackground).opacity(0.95)) // Much faster than ultraThinMaterial
                .shadow(color: .black.opacity(0.1), radius: 10)
        )
        .padding(.horizontal)
        .padding(.top, 60)
    }
    
    // MARK: - Map View (Optimized)
    
    private var trainerMapView: some View {
        // Use cached trainers and limit visible pins for performance
        let trainersToShow = cachedFilteredTrainers.isEmpty ? filteredTrainers : cachedFilteredTrainers
        let limitedTrainers = Array(trainersToShow.prefix(10))
        
        return Map(coordinateRegion: $region, annotationItems: limitedTrainers) { trainer in
            MapAnnotation(coordinate: trainer.coordinate) {
                // Show profile image on pins
                SimpleTrainerPin(trainer: trainer) {
                    selectedTrainer = trainer
                }
            }
        }
        .ignoresSafeArea(edges: .top)
    }
    
    // MARK: - List View (Optimized)
    
    private var trainerListView: some View {
        ScrollView {
            LazyVStack(spacing: 12) {
                // Spacer for header
                Color.clear.frame(height: 180)
                
                // Use pre-computed cached trainers for best performance
                let trainersToDisplay = cachedFilteredTrainers.isEmpty ? filteredTrainers : cachedFilteredTrainers
                
                ForEach(trainersToDisplay) { trainer in
                    TrainerListCard(trainer: trainer) {
                        selectedTrainer = trainer
                    }
                    .id(trainer.id) // Stable identity for better diffing
                }
                
                if filteredTrainers.isEmpty && !viewModel.isLoading {
                    VStack(spacing: 16) {
                        Image(systemName: "person.slash")
                            .font(.system(size: 48))
                            .foregroundColor(.gray)
                        Text("Inga tränare hittades")
                            .font(.headline)
                        Text("Prova att ändra dina filter")
                            .font(.subheadline)
                            .foregroundColor(.gray)
                    }
                    .padding(.top, 60)
                }
            }
            .padding(.horizontal)
            .padding(.bottom, 20)
        }
        .background(Color(.systemGroupedBackground))
    }
    
    // MARK: - Computed Properties
    
    private var filteredTrainers: [GolfTrainer] {
        // Use cached results if available
        if !cachedFilteredTrainers.isEmpty && debouncedSearchText == searchText {
            return cachedFilteredTrainers
        }
        return computeFilteredTrainers()
    }
    
    private func computeFilteredTrainers() -> [GolfTrainer] {
        var trainers = viewModel.trainers
        
        // Apply search text locally if not empty
        if !debouncedSearchText.isEmpty {
            let search = debouncedSearchText.lowercased()
            trainers = trainers.filter { trainer in
                trainer.name.lowercased().contains(search) ||
                (trainer.city?.lowercased().contains(search) ?? false) ||
                (trainer.clubAffiliation?.lowercased().contains(search) ?? false)
            }
        }
        
        return trainers
    }
    
    private func updateFilteredTrainers() {
        cachedFilteredTrainers = computeFilteredTrainers()
    }
    
    // MARK: - Functions
    
    private func loadSpecialties() async {
        // Use cached specialties if available
        if let cached = SpecialtiesCache.shared.specialties {
            specialtiesCatalog = cached
            return
        }
        
        do {
            let fetched = try await TrainerService.shared.fetchSpecialtiesCatalog()
            SpecialtiesCache.shared.specialties = fetched
            specialtiesCatalog = fetched
        } catch {
            print("❌ Failed to load specialties: \(error)")
        }
    }
    
    private func applyFilter() async {
        filter.searchText = searchText
        await viewModel.searchTrainers(filter: filter)
        prefetchTrainerImages()
    }
    
    private func prefetchTrainerImages() {
        let avatarUrls = viewModel.trainers.compactMap { $0.avatarUrl }
        if !avatarUrls.isEmpty {
            ImageCacheManager.shared.prefetch(urls: avatarUrls)
        }
    }
}

// MARK: - Specialties Cache (Singleton)

// MARK: - Specialties Cache (Singleton)

private class SpecialtiesCache {
    static let shared = SpecialtiesCache()
    var specialties: [TrainerSpecialty]?
    private init() {}
}

// MARK: - Trainer List Card

struct TrainerListCard: View {
    let trainer: GolfTrainer
    let onTap: () -> Void
    
    var body: some View {
        Button(action: onTap) {
            HStack(spacing: 14) {
                // Use cached ProfileImage
                ProfileImage(url: trainer.avatarUrl, size: 60)
                
                // Info
                VStack(alignment: .leading, spacing: 4) {
                    HStack {
                        Text(trainer.name)
                            .font(.system(size: 16, weight: .semibold))
                            .foregroundColor(.primary)
                        
                        if let rating = trainer.averageRating, rating > 0 {
                            HStack(spacing: 2) {
                                Image(systemName: "star.fill")
                                    .font(.system(size: 12))
                                    .foregroundColor(.yellow)
                                Text(String(format: "%.1f", rating))
                                    .font(.system(size: 13, weight: .medium))
                                    .foregroundColor(.secondary)
                            }
                        }
                    }
                    
                    if let city = trainer.city {
                        HStack(spacing: 4) {
                            Image(systemName: "mappin")
                                .font(.system(size: 11))
                            Text(city)
                                .font(.system(size: 13))
                        }
                        .foregroundColor(.secondary)
                    }
                    
                    Text(trainer.description)
                        .font(.system(size: 13))
                        .foregroundColor(.secondary)
                        .lineLimit(2)
                }
                
                Spacer()
                
                // Price
                VStack(alignment: .trailing, spacing: 4) {
                    Text("\(trainer.hourlyRate) kr")
                        .font(.system(size: 18, weight: .bold))
                        .foregroundColor(.primary)
                    Text("/timme")
                        .font(.system(size: 11))
                        .foregroundColor(.secondary)
                }
            }
            .padding(16)
            .background(Color(.systemBackground))
            .cornerRadius(16)
            .shadow(color: .black.opacity(0.05), radius: 8, x: 0, y: 2)
            .drawingGroup() // Flatten for better scroll performance
        }
        .buttonStyle(.plain)
    }
}

// MARK: - Filter Sheet View

struct FilterSheetView: View {
    @Binding var filter: TrainerSearchFilter
    let specialties: [TrainerSpecialty]
    let onApply: () -> Void
    @Environment(\.dismiss) private var dismiss
    
    @State private var minPrice: Double = 0
    @State private var maxPrice: Double = 2000
    @State private var minRating: Double = 0
    
    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: 24) {
                    // Price Range
                    VStack(alignment: .leading, spacing: 12) {
                        Text("Prisintervall")
                            .font(.headline)
                        
                        HStack {
                            Text("\(Int(minPrice)) kr")
                                .font(.subheadline)
                                .foregroundColor(.secondary)
                            Spacer()
                            Text("\(Int(maxPrice)) kr")
                                .font(.subheadline)
                                .foregroundColor(.secondary)
                        }
                        
                        HStack {
                            Slider(value: $minPrice, in: 0...2000, step: 50)
                            Slider(value: $maxPrice, in: 0...2000, step: 50)
                        }
                    }
                    
                    Divider()
                    
                    // Rating
                    VStack(alignment: .leading, spacing: 12) {
                        Text("Minsta betyg")
                            .font(.headline)
                        
                        HStack {
                            ForEach(0..<5) { index in
                                Image(systemName: Double(index) < minRating ? "star.fill" : "star")
                                    .font(.title2)
                                    .foregroundColor(.yellow)
                                    .onTapGesture {
                                        minRating = Double(index + 1)
                                    }
                            }
                            
                            Spacer()
                            
                            if minRating > 0 {
                                Button("Rensa") {
                                    minRating = 0
                                }
                                .font(.caption)
                                .foregroundColor(.blue)
                            }
                        }
                    }
                    
                    Divider()
                    
                    // Specialties
                    VStack(alignment: .leading, spacing: 12) {
                        Text("Specialiteter")
                            .font(.headline)
                        
                        LazyVGrid(columns: [GridItem(.flexible()), GridItem(.flexible())], spacing: 10) {
                            ForEach(specialties) { specialty in
                                Button {
                                    if filter.selectedSpecialties.contains(specialty.id) {
                                        filter.selectedSpecialties.remove(specialty.id)
                                    } else {
                                        filter.selectedSpecialties.insert(specialty.id)
                                    }
                                } label: {
                                    HStack {
                                        if let icon = specialty.icon {
                                            Image(systemName: icon)
                                                .font(.system(size: 14))
                                        }
                                        Text(specialty.name)
                                            .font(.system(size: 14, weight: .medium))
                                    }
                                    .foregroundColor(filter.selectedSpecialties.contains(specialty.id) ? .white : .primary)
                                    .padding(.horizontal, 12)
                                    .padding(.vertical, 10)
                                    .frame(maxWidth: .infinity)
                                    .background(filter.selectedSpecialties.contains(specialty.id) ? Color.black : Color(.systemGray6))
                                    .cornerRadius(10)
                                }
                            }
                        }
                    }
                }
                .padding()
            }
            .navigationTitle("Filter")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarLeading) {
                    Button("Rensa allt") {
                        filter = TrainerSearchFilter()
                        minPrice = 0
                        maxPrice = 2000
                        minRating = 0
                    }
                    .foregroundColor(.red)
                }
                
                ToolbarItem(placement: .topBarTrailing) {
                    Button("Tillämpa") {
                        filter.minPrice = minPrice > 0 ? Int(minPrice) : nil
                        filter.maxPrice = maxPrice < 2000 ? Int(maxPrice) : nil
                        filter.minRating = minRating > 0 ? minRating : nil
                        onApply()
                    }
                    .fontWeight(.semibold)
                }
            }
        }
        .onAppear {
            minPrice = Double(filter.minPrice ?? 0)
            maxPrice = Double(filter.maxPrice ?? 2000)
            minRating = filter.minRating ?? 0
        }
    }
}

// MARK: - Trainer Map Pin

// MARK: - Simple Trainer Pin (Ultra-lightweight for map performance)

// MARK: - Optimized Trainer Pin (Ultra-lightweight for map performance)
struct OptimizedTrainerPin: View {
    let trainer: GolfTrainer
    let onTap: () -> Void
    
    var body: some View {
        Button(action: onTap) {
            // Simple circle with price - minimal rendering
            ZStack {
                Circle()
                    .fill(Color.black)
                    .frame(width: 36, height: 36)
                
                Text("\(trainer.hourlyRate)")
                    .font(.system(size: 11, weight: .bold))
                    .foregroundColor(.white)
            }
            .shadow(color: .black.opacity(0.2), radius: 2, x: 0, y: 1)
        }
        .buttonStyle(.plain)
    }
}

struct SimpleTrainerPin: View {
    let trainer: GolfTrainer
    let onTap: () -> Void
    
    var body: some View {
        Button(action: onTap) {
            VStack(spacing: 2) {
                // Profile image with border
                ProfileImage(url: trainer.avatarUrl, size: 40)
                    .overlay(Circle().stroke(Color.white, lineWidth: 2))
                    .shadow(color: .black.opacity(0.3), radius: 3, x: 0, y: 2)
                
                // Price tag
                Text("\(trainer.hourlyRate) kr")
                    .font(.system(size: 10, weight: .bold))
                    .foregroundColor(.white)
                    .padding(.horizontal, 6)
                    .padding(.vertical, 2)
                    .background(Color.black)
                    .cornerRadius(8)
            }
        }
        .buttonStyle(.plain)
    }
}

// MARK: - Full Trainer Map Pin (for detail views)

struct TrainerMapPin: View {
    let trainer: GolfTrainer
    let onTap: () -> Void
    
    var body: some View {
        Button(action: onTap) {
            VStack(spacing: 4) {
                ProfileImage(url: trainer.avatarUrl, size: 44)
                    .overlay(Circle().stroke(Color.black, lineWidth: 3))
                    .shadow(radius: 4)
                
                Text("\(trainer.hourlyRate) kr/h")
                    .font(.system(size: 10, weight: .bold))
                    .foregroundColor(.white)
                    .padding(.horizontal, 6)
                    .padding(.vertical, 2)
                    .background(Color.black)
                    .cornerRadius(4)
            }
        }
        .buttonStyle(.plain)
    }
}

// MARK: - Trainer Detail View

struct TrainerDetailView: View {
    let trainer: GolfTrainer
    @Environment(\.dismiss) private var dismiss
    @StateObject private var viewModel: TrainerDetailViewModel
    @State private var showBookingFlow = false
    @State private var showContactSheet = false
    @State private var showAllReviews = false
    
    init(trainer: GolfTrainer) {
        self.trainer = trainer
        _viewModel = StateObject(wrappedValue: TrainerDetailViewModel(trainer: trainer))
    }
    
    var body: some View {
        ScrollView {
            VStack(spacing: 20) {
                // Close button
                HStack {
                    Spacer()
                    Button {
                        dismiss()
                    } label: {
                        Image(systemName: "xmark.circle.fill")
                            .font(.title)
                            .foregroundStyle(.gray, Color(.systemGray5))
                    }
                }
                .padding(.top, 8)
                
                // Profile Header
                profileHeader
                
                // Quick Stats
                quickStats
                
                // Book Button (moved up, above specialties)
                bookButton
                
                // Service Area Map (right after book button)
                serviceAreaSection
                
                // Specialties
                if !viewModel.specialties.isEmpty {
                    specialtiesSection
                }
                
                // Description
                descriptionSection
                
                // Lesson Types
                if !viewModel.lessonTypes.isEmpty {
                    lessonTypesSection
                }
                
                // Reviews
                reviewsSection
            }
            .padding()
        }
        .background(Color(.systemBackground))
        .task {
            await viewModel.loadAllData()
        }
        .sheet(isPresented: $showBookingFlow) {
            BookingFlowView(trainer: trainer) {
                // Booking complete
                dismiss()
            }
        }
        .sheet(isPresented: $showContactSheet) {
            ContactTrainerView(trainer: trainer)
                .presentationDetents([.medium])
        }
        .sheet(isPresented: $showAllReviews) {
            AllReviewsView(trainerId: trainer.id, trainerName: trainer.name)
        }
    }
    
    // MARK: - Profile Header
    
    private var profileHeader: some View {
        VStack(spacing: 12) {
            // Use cached ProfileImage instead of AsyncImage
            ProfileImage(url: trainer.avatarUrl, size: 100)
                .overlay(Circle().stroke(Color.black, lineWidth: 3))
            
            Text(trainer.name)
                .font(.title2)
                .fontWeight(.bold)
            
            if let city = trainer.city {
                HStack(spacing: 4) {
                    Image(systemName: "mappin")
                    Text(city)
                }
                .font(.subheadline)
                .foregroundColor(.secondary)
            }
            
            // Rating
            if let rating = trainer.averageRating, rating > 0 {
                HStack(spacing: 4) {
                    ForEach(0..<5) { index in
                        Image(systemName: Double(index) < rating ? "star.fill" : "star")
                            .foregroundColor(.yellow)
                            .font(.system(size: 14))
                    }
                    Text(String(format: "%.1f", rating))
                        .font(.subheadline)
                        .fontWeight(.semibold)
                    Text("(\(trainer.totalReviews ?? 0) omdömen)")
                        .font(.caption)
                        .foregroundColor(.secondary)
                }
            }
        }
    }
    
    // MARK: - Quick Stats
    
    private var quickStats: some View {
        HStack(spacing: 12) {
            StatBadge(icon: "figure.golf", value: "HCP \(trainer.handicap)")
            StatBadge(icon: "clock", value: "från \(trainer.hourlyRate) kr")
            if let years = trainer.experienceYears, years > 0 {
                StatBadge(icon: "calendar", value: "\(years) års erfarenhet")
            }
            if let lessons = trainer.totalLessons, lessons > 0 {
                StatBadge(icon: "person.2", value: "\(lessons) lektioner")
            }
        }
        .frame(maxWidth: .infinity)
    }
    
    // MARK: - Specialties Section
    
    private var specialtiesSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Specialiteter")
                .font(.headline)
            
            FlowLayout(spacing: 8) {
                ForEach(viewModel.specialties) { specialty in
                    HStack(spacing: 4) {
                        if let icon = specialty.icon {
                            Image(systemName: icon)
                                .font(.caption)
                        }
                        Text(specialty.name)
                            .font(.caption)
                            .fontWeight(.medium)
                    }
                    .foregroundColor(.primary)
                    .padding(.horizontal, 12)
                    .padding(.vertical, 6)
                    .background(Color.black.opacity(0.15))
                    .cornerRadius(20)
                }
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding()
        .background(Color(.systemGray6))
        .cornerRadius(12)
    }
    
    // MARK: - Description Section
    
    private var descriptionSection: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("Om mig")
                .font(.headline)
            
            Text(trainer.bio ?? trainer.description)
                .font(.body)
                .foregroundColor(.secondary)
            
            if let club = trainer.clubAffiliation {
                HStack(spacing: 4) {
                    Image(systemName: "building.2")
                    Text(club)
                }
                .font(.caption)
                .foregroundColor(.secondary)
                .padding(.top, 4)
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding()
        .background(Color(.systemGray6))
        .cornerRadius(12)
    }
    
    // MARK: - Lesson Types Section
    
    private var lessonTypesSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Lektioner")
                .font(.headline)
            
            ForEach(viewModel.lessonTypes) { lessonType in
                HStack {
                    VStack(alignment: .leading, spacing: 4) {
                        Text(lessonType.name)
                            .font(.subheadline)
                            .fontWeight(.medium)
                        if let desc = lessonType.description, !desc.isEmpty {
                            Text(desc)
                                .font(.caption)
                                .foregroundColor(.secondary)
                        }
                    }
                    
                    Spacer()
                    
                    VStack(alignment: .trailing, spacing: 2) {
                        Text("\(lessonType.price) kr")
                            .font(.subheadline)
                            .fontWeight(.bold)
                            .foregroundColor(.primary)
                        Text("\(lessonType.durationMinutes) min")
                            .font(.caption)
                            .foregroundColor(.secondary)
                    }
                }
                .padding(.vertical, 8)
                
                if lessonType.id != viewModel.lessonTypes.last?.id {
                    Divider()
                }
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding()
        .background(Color(.systemGray6))
        .cornerRadius(12)
    }
    
    // MARK: - Reviews Section
    
    private var reviewsSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                Text("Omdömen")
                    .font(.headline)
                
                Spacer()
                
                if viewModel.reviews.count > 2 {
                    Button("Visa alla") {
                        showAllReviews = true
                    }
                    .font(.subheadline)
                    .foregroundColor(.primary)
                }
            }
            
            if viewModel.isLoadingReviews {
                ProgressView()
                    .frame(maxWidth: .infinity)
            } else if viewModel.reviews.isEmpty {
                Text("Inga omdömen ännu")
                    .font(.subheadline)
                    .foregroundColor(.secondary)
                    .padding(.vertical, 8)
            } else {
                ForEach(viewModel.reviews.prefix(2)) { review in
                    ReviewCard(review: review)
                }
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding()
        .background(Color(.systemGray6))
        .cornerRadius(12)
    }
    
    // MARK: - Service Area Section (with circle)
    
    private var serviceAreaSection: some View {
        let radiusKm = trainer.serviceRadiusKm ?? 10
        let spanDelta = (radiusKm / 111.0) * 2.5
        
        return VStack(alignment: .leading, spacing: 8) {
            HStack {
                Image(systemName: "mappin.and.ellipse")
                    .foregroundColor(.primary)
                Text("Träningsområde")
                    .font(.headline)
            }
            
            Text("Tränaren kan hålla lektioner inom \(Int(radiusKm)) km radie")
                .font(.caption)
                .foregroundColor(.secondary)
            
            ZStack {
                Map(coordinateRegion: .constant(MKCoordinateRegion(
                    center: trainer.coordinate,
                    span: MKCoordinateSpan(latitudeDelta: spanDelta, longitudeDelta: spanDelta)
                )), interactionModes: []) // No interactions - fixed position
                .cornerRadius(12)
                
                // Service area circle overlay
                Circle()
                    .stroke(Color.black, lineWidth: 2)
                    .background(Circle().fill(Color.black.opacity(0.1)))
                    .frame(width: serviceAreaCircleSize(radiusKm: radiusKm, spanDelta: spanDelta), 
                           height: serviceAreaCircleSize(radiusKm: radiusKm, spanDelta: spanDelta))
                    .allowsHitTesting(false)
                
                // Center pin
                Image(systemName: "mappin.circle.fill")
                    .font(.system(size: 28))
                    .foregroundColor(.primary)
                    .allowsHitTesting(false)
            }
            .frame(height: 200)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding()
        .background(Color(.systemGray6))
        .cornerRadius(12)
    }
    
    private func serviceAreaCircleSize(radiusKm: Double, spanDelta: Double) -> CGFloat {
        let degreesPerKm = 1.0 / 111.0
        let radiusInDegrees = radiusKm * degreesPerKm
        let mapHeight: CGFloat = 200
        let pixelsPerDegree = mapHeight / spanDelta
        return min(CGFloat(radiusInDegrees * 2 * pixelsPerDegree), mapHeight * 0.85)
    }
    
    // MARK: - Location Section
    
    private var locationSection: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("Plats")
                .font(.headline)
            
            Map(coordinateRegion: .constant(MKCoordinateRegion(
                center: trainer.coordinate,
                span: MKCoordinateSpan(latitudeDelta: 0.01, longitudeDelta: 0.01)
            )), annotationItems: [trainer]) { t in
                MapMarker(coordinate: t.coordinate, tint: .black)
            }
            .frame(height: 150)
            .cornerRadius(12)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding()
        .background(Color(.systemGray6))
        .cornerRadius(12)
    }
    
    // MARK: - Book Button
    
    private var bookButton: some View {
        Button {
            showBookingFlow = true
        } label: {
            HStack {
                Image(systemName: "calendar.badge.plus")
                Text("Boka lektion")
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

// MARK: - Trainer Detail ViewModel

@MainActor
class TrainerDetailViewModel: ObservableObject {
    let trainer: GolfTrainer
    
    @Published var specialties: [TrainerSpecialty] = []
    @Published var lessonTypes: [TrainerLessonType] = []
    @Published var reviews: [TrainerReview] = []
    @Published var isLoadingReviews = false
    
    init(trainer: GolfTrainer) {
        self.trainer = trainer
    }
    
    func loadAllData() async {
        async let specialtiesTask = loadSpecialties()
        async let lessonTypesTask = loadLessonTypes()
        async let reviewsTask = loadReviews()
        
        _ = await (specialtiesTask, lessonTypesTask, reviewsTask)
    }
    
    private func loadSpecialties() async {
        do {
            specialties = try await TrainerService.shared.fetchTrainerSpecialties(trainerId: trainer.id)
        } catch {
            print("❌ Failed to load specialties: \(error)")
        }
    }
    
    private func loadLessonTypes() async {
        do {
            lessonTypes = try await TrainerService.shared.fetchLessonTypes(trainerId: trainer.id)
        } catch {
            print("❌ Failed to load lesson types: \(error)")
        }
    }
    
    private func loadReviews() async {
        isLoadingReviews = true
        do {
            reviews = try await TrainerService.shared.fetchReviews(trainerId: trainer.id)
        } catch {
            print("❌ Failed to load reviews: \(error)")
        }
        isLoadingReviews = false
    }
}

// MARK: - Review Card

struct ReviewCard: View {
    let review: TrainerReview
    
    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack {
                // Stars
                HStack(spacing: 2) {
                    ForEach(0..<5) { index in
                        Image(systemName: index < review.rating ? "star.fill" : "star")
                            .font(.caption)
                            .foregroundColor(.yellow)
                    }
                }
                
                Spacer()
                
                if let date = review.createdAt {
                    Text(date, style: .date)
                        .font(.caption)
                        .foregroundColor(.secondary)
                }
            }
            
            if let title = review.title, !title.isEmpty {
                Text(title)
                    .font(.subheadline)
                    .fontWeight(.semibold)
            }
            
            if let comment = review.comment, !comment.isEmpty {
                Text(comment)
                    .font(.subheadline)
                    .foregroundColor(.secondary)
            }
            
            if review.isVerified {
                HStack(spacing: 4) {
                    Image(systemName: "checkmark.seal.fill")
                    Text("Verifierad bokning")
                }
                .font(.caption)
                .foregroundColor(.primary)
            }
        }
        .padding()
        .background(Color(.systemBackground))
        .cornerRadius(8)
    }
}

// MARK: - Flow Layout (Optimized with cache)

struct FlowLayout: Layout {
    var spacing: CGFloat = 8
    
    struct CacheData {
        var size: CGSize = .zero
        var frames: [CGRect] = []
    }
    
    func makeCache(subviews: Subviews) -> CacheData {
        CacheData()
    }
    
    func sizeThatFits(proposal: ProposedViewSize, subviews: Subviews, cache: inout CacheData) -> CGSize {
        let result = arrangeSubviews(proposal: proposal, subviews: subviews)
        cache.size = result.size
        cache.frames = result.frames
        return result.size
    }
    
    func placeSubviews(in bounds: CGRect, proposal: ProposedViewSize, subviews: Subviews, cache: inout CacheData) {
        // Use cached frames if available
        let frames = cache.frames.isEmpty ? arrangeSubviews(proposal: proposal, subviews: subviews).frames : cache.frames
        for (index, frame) in frames.enumerated() where index < subviews.count {
            subviews[index].place(at: CGPoint(x: bounds.minX + frame.minX, y: bounds.minY + frame.minY), proposal: .init(frame.size))
        }
    }
    
    private func arrangeSubviews(proposal: ProposedViewSize, subviews: Subviews) -> (size: CGSize, frames: [CGRect]) {
        let maxWidth = proposal.width ?? .infinity
        var currentX: CGFloat = 0
        var currentY: CGFloat = 0
        var lineHeight: CGFloat = 0
        var frames: [CGRect] = []
        frames.reserveCapacity(subviews.count) // Pre-allocate
        
        for subview in subviews {
            let size = subview.sizeThatFits(.unspecified)
            
            if currentX + size.width > maxWidth && currentX > 0 {
                currentX = 0
                currentY += lineHeight + spacing
                lineHeight = 0
            }
            
            frames.append(CGRect(x: currentX, y: currentY, width: size.width, height: size.height))
            lineHeight = max(lineHeight, size.height)
            currentX += size.width + spacing
        }
        
        return (CGSize(width: maxWidth, height: currentY + lineHeight), frames)
    }
}

// MARK: - All Reviews View

struct AllReviewsView: View {
    let trainerId: UUID
    let trainerName: String
    @Environment(\.dismiss) private var dismiss
    @State private var reviews: [TrainerReview] = []
    @State private var isLoading = true
    
    var body: some View {
        NavigationStack {
            ScrollView {
                LazyVStack(spacing: 12) {
                    if isLoading {
                        ProgressView()
                            .padding(.top, 50)
                    } else if reviews.isEmpty {
                        Text("Inga omdömen ännu")
                            .foregroundColor(.secondary)
                            .padding(.top, 50)
                    } else {
                        ForEach(reviews) { review in
                            ReviewCard(review: review)
                        }
                    }
                }
                .padding()
            }
            .navigationTitle("Omdömen för \(trainerName)")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    Button("Stäng") {
                        dismiss()
                    }
                }
            }
            .task {
                do {
                    reviews = try await TrainerService.shared.fetchReviews(trainerId: trainerId)
                } catch {
                    print("❌ Failed to load reviews: \(error)")
                }
                isLoading = false
            }
        }
    }
}

struct StatBadge: View {
    let icon: String
    let value: String
    
    var body: some View {
        HStack(spacing: 4) {
            Image(systemName: icon)
                .font(.caption)
            Text(value)
                .font(.caption)
                .fontWeight(.semibold)
        }
        .foregroundColor(.primary)
        .padding(.horizontal, 12)
        .padding(.vertical, 6)
        .background(Color.black.opacity(0.15))
        .cornerRadius(20)
    }
}

// MARK: - Contact Trainer View

struct ContactTrainerView: View {
    let trainer: GolfTrainer
    @Environment(\.dismiss) private var dismiss
    @State private var message = ""
    @State private var isSending = false
    @State private var showSuccess = false
    @State private var errorMessage: String?
    
    var body: some View {
        NavigationStack {
            VStack(spacing: 20) {
                Text("Kontakta \(trainer.name)")
                    .font(.headline)
                
                Text("Skriv ett meddelande för att boka en lektion. Tränaren kommer kontakta dig via appen.")
                    .font(.subheadline)
                    .foregroundColor(.secondary)
                    .multilineTextAlignment(.center)
                
                TextEditor(text: $message)
                    .frame(height: 120)
                    .padding(8)
                    .background(Color(.systemGray6))
                    .cornerRadius(12)
                    .overlay(
                        RoundedRectangle(cornerRadius: 12)
                            .stroke(Color.gray.opacity(0.3))
                    )
                
                Button {
                    sendBookingRequest()
                } label: {
                    if isSending {
                        ProgressView()
                            .tint(.white)
                    } else {
                        Text("Skicka förfrågan")
                    }
                }
                .font(.headline)
                .foregroundColor(.white)
                .frame(maxWidth: .infinity)
                .padding()
                .background(message.isEmpty ? Color.gray : Color.black)
                .cornerRadius(12)
                .disabled(message.isEmpty || isSending)
                
                Spacer()
            }
            .padding()
            .navigationTitle("Boka lektion")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarLeading) {
                    Button("Avbryt") {
                        dismiss()
                    }
                }
            }
            .alert("Förfrågan skickad!", isPresented: $showSuccess) {
                Button("OK") {
                    dismiss()
                }
            } message: {
                Text("\(trainer.name) har fått ditt meddelande och kommer kontakta dig snart.")
            }
            .alert("Fel", isPresented: .init(
                get: { errorMessage != nil },
                set: { if !$0 { errorMessage = nil } }
            )) {
                Button("OK") { errorMessage = nil }
            } message: {
                Text(errorMessage ?? "")
            }
        }
    }
    
    private func sendBookingRequest() {
        isSending = true
        
        Task {
            do {
                _ = try await TrainerService.shared.createBooking(
                    trainerId: trainer.id,
                    message: message
                )
                
                await MainActor.run {
                    isSending = false
                    showSuccess = true
                }
            } catch {
                await MainActor.run {
                    isSending = false
                    errorMessage = "Kunde inte skicka förfrågan: \(error.localizedDescription)"
                }
            }
        }
    }
}

// MARK: - View Model

class LessonsViewModel: ObservableObject {
    @Published var trainers: [GolfTrainer] = []
    @Published var isLoading = false
    
    // Cache for trainers - increased duration for better performance
    private static var cachedTrainers: [GolfTrainer] = []
    private static var lastFetchTime: Date = .distantPast
    private static let cacheValidDuration: TimeInterval = 300 // 5 minutes
    
    // Check if we have cached trainers (for instant display)
    static var hasCachedTrainers: Bool {
        !cachedTrainers.isEmpty
    }
    
    /// Invalidate cache to force fresh data on next fetch
    static func invalidateCache() {
        lastFetchTime = .distantPast
    }
    
    // Load from cache immediately (synchronous, for instant UI)
    @MainActor
    func loadFromCacheImmediately() {
        if !Self.cachedTrainers.isEmpty {
            trainers = Self.cachedTrainers
        }
    }
    
    @MainActor
    func fetchTrainers(forceRefresh: Bool = false) async {
        // Check cache first
        let cacheValid = Date().timeIntervalSince(Self.lastFetchTime) < Self.cacheValidDuration
        
        if !forceRefresh && cacheValid && !Self.cachedTrainers.isEmpty {
            trainers = Self.cachedTrainers
            return
        }
        
        // Show loading only if no cached data AND no trainers displayed yet
        if trainers.isEmpty && Self.cachedTrainers.isEmpty {
            isLoading = true
        }
        
        do {
            let fetchedTrainers = try await TrainerService.shared.fetchTrainers()
            Self.cachedTrainers = fetchedTrainers
            Self.lastFetchTime = Date()
            trainers = fetchedTrainers
        } catch {
            print("❌ Failed to fetch trainers: \(error)")
            // Use cache on error
            if !Self.cachedTrainers.isEmpty {
                trainers = Self.cachedTrainers
            }
        }
        
        isLoading = false
    }
    
    @MainActor
    func searchTrainers(filter: TrainerSearchFilter) async {
        isLoading = true
        
        do {
            trainers = try await TrainerService.shared.searchTrainers(filter: filter)
        } catch {
            print("❌ Failed to search trainers: \(error)")
            // Fallback to cached trainers
            if !Self.cachedTrainers.isEmpty {
                trainers = Self.cachedTrainers
            } else {
                await fetchTrainers()
            }
        }
        
        isLoading = false
    }
}

// MARK: - Golf Trainer Model

struct GolfTrainer: Identifiable, Codable, Equatable {
    let id: UUID
    let userId: String
    let name: String
    let description: String
    let hourlyRate: Int
    let handicap: Int
    let latitude: Double
    let longitude: Double
    let avatarUrl: String?
    let createdAt: Date?
    
    // Extended fields
    let city: String?
    let bio: String?
    let experienceYears: Int?
    let clubAffiliation: String?
    let averageRating: Double?
    let totalReviews: Int?
    let totalLessons: Int?
    let isActive: Bool?
    let serviceRadiusKm: Double?
    
    // Social media & contact
    let instagramUrl: String?
    let facebookUrl: String?
    let websiteUrl: String?
    let phoneNumber: String?
    let contactEmail: String?
    
    // Gallery images (up to 4 images total including avatar)
    let galleryUrls: [String]?
    
    var coordinate: CLLocationCoordinate2D {
        CLLocationCoordinate2D(latitude: latitude, longitude: longitude)
    }
    
    /// All images for the gallery slider (avatar first, then gallery images, max 4 total)
    var allGalleryImages: [String] {
        var images: [String] = []
        
        // Add avatar first if it exists
        if let avatar = avatarUrl, !avatar.isEmpty {
            images.append(avatar)
        }
        
        // Add gallery images (up to 4 total)
        if let gallery = galleryUrls {
            let remainingSlots = 4 - images.count
            images.append(contentsOf: gallery.prefix(remainingSlots))
        }
        
        return images
    }
    
    var formattedRating: String {
        guard let rating = averageRating, rating > 0 else { return "-" }
        return String(format: "%.1f", rating)
    }
    
    var hasRating: Bool {
        guard let rating = averageRating else { return false }
        return rating > 0
    }
    
    enum CodingKeys: String, CodingKey {
        case id
        case userId = "user_id"
        case name
        case description
        case hourlyRate = "hourly_rate"
        case handicap
        case latitude
        case longitude
        case avatarUrl = "avatar_url"
        case createdAt = "created_at"
        case city
        case bio
        case experienceYears = "experience_years"
        case clubAffiliation = "club_affiliation"
        case averageRating = "average_rating"
        case totalReviews = "total_reviews"
        case totalLessons = "total_lessons"
        case isActive = "is_active"
        case serviceRadiusKm = "service_radius_km"
        case instagramUrl = "instagram_url"
        case facebookUrl = "facebook_url"
        case websiteUrl = "website_url"
        case phoneNumber = "phone_number"
        case contactEmail = "contact_email"
        case galleryUrls = "gallery_urls"
    }
}

#Preview {
    LessonsView()
}



