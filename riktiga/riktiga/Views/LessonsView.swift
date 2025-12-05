import SwiftUI
import MapKit
import CoreLocation

struct LessonsView: View {
    @StateObject private var viewModel = LessonsViewModel()
    @State private var selectedTrainer: GolfTrainer?
    @State private var showTrainerDetail = false
    @State private var region = MKCoordinateRegion(
        center: CLLocationCoordinate2D(latitude: 59.3293, longitude: 18.0686),
        span: MKCoordinateSpan(latitudeDelta: 0.1, longitudeDelta: 0.1)
    )
    
    var body: some View {
        NavigationStack {
            ZStack {
                // Map with trainer pins
                Map(coordinateRegion: $region, annotationItems: viewModel.trainers) { trainer in
                    MapAnnotation(coordinate: trainer.coordinate) {
                        TrainerMapPin(trainer: trainer) {
                            selectedTrainer = trainer
                            showTrainerDetail = true
                        }
                    }
                }
                .ignoresSafeArea(edges: .top)
                
                // Header
                VStack {
                    headerView
                    Spacer()
                }
                
                // Loading indicator
                if viewModel.isLoading {
                    ProgressView()
                        .scaleEffect(1.5)
                        .padding()
                        .background(.ultraThinMaterial)
                        .cornerRadius(10)
                }
            }
            .task {
                await viewModel.fetchTrainers()
            }
            .sheet(isPresented: $showTrainerDetail) {
                if let trainer = selectedTrainer {
                    TrainerDetailView(trainer: trainer)
                        .presentationDetents([.medium, .large])
                }
            }
        }
    }
    
    private var headerView: some View {
        VStack(spacing: 8) {
            HStack {
                VStack(alignment: .leading, spacing: 4) {
                    Text("Golflektioner")
                        .font(.system(size: 28, weight: .bold))
                        .foregroundColor(.black)
                    
                    Text("\(viewModel.trainers.count) tränare tillgängliga")
                        .font(.subheadline)
                        .foregroundColor(.gray)
                }
                
                Spacer()
                
                Image(systemName: "figure.golf")
                    .font(.system(size: 32))
                    .foregroundColor(.green)
            }
            .padding()
            .background(
                RoundedRectangle(cornerRadius: 16)
                    .fill(.ultraThinMaterial)
                    .shadow(color: .black.opacity(0.1), radius: 10)
            )
            .padding(.horizontal)
            .padding(.top, 60)
        }
    }
}

// MARK: - Trainer Map Pin

struct TrainerMapPin: View {
    let trainer: GolfTrainer
    let onTap: () -> Void
    
    var body: some View {
        Button(action: onTap) {
            VStack(spacing: 4) {
                // Profile image
                AsyncImage(url: URL(string: trainer.avatarUrl ?? "")) { image in
                    image
                        .resizable()
                        .scaledToFill()
                } placeholder: {
                    Image(systemName: "person.circle.fill")
                        .resizable()
                        .foregroundColor(.gray)
                }
                .frame(width: 44, height: 44)
                .clipShape(Circle())
                .overlay(
                    Circle()
                        .stroke(Color.green, lineWidth: 3)
                )
                .shadow(radius: 4)
                
                // Price tag
                Text("\(trainer.hourlyRate) kr/h")
                    .font(.system(size: 10, weight: .bold))
                    .foregroundColor(.white)
                    .padding(.horizontal, 6)
                    .padding(.vertical, 2)
                    .background(Color.green)
                    .cornerRadius(4)
            }
        }
    }
}

// MARK: - Trainer Detail View

struct TrainerDetailView: View {
    let trainer: GolfTrainer
    @Environment(\.dismiss) private var dismiss
    @State private var showContactSheet = false
    
    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(spacing: 20) {
                    // Profile Header
                    VStack(spacing: 12) {
                        AsyncImage(url: URL(string: trainer.avatarUrl ?? "")) { image in
                            image
                                .resizable()
                                .scaledToFill()
                        } placeholder: {
                            Image(systemName: "person.circle.fill")
                                .resizable()
                                .foregroundColor(.gray)
                        }
                        .frame(width: 100, height: 100)
                        .clipShape(Circle())
                        .overlay(
                            Circle()
                                .stroke(Color.green, lineWidth: 3)
                        )
                        
                        Text(trainer.name)
                            .font(.title2)
                            .fontWeight(.bold)
                        
                        HStack(spacing: 16) {
                            StatBadge(icon: "figure.golf", value: "HCP \(trainer.handicap)")
                            StatBadge(icon: "clock", value: "\(trainer.hourlyRate) kr/h")
                        }
                    }
                    .padding(.top)
                    
                    // Description
                    VStack(alignment: .leading, spacing: 8) {
                        Text("Om mig")
                            .font(.headline)
                        
                        Text(trainer.description)
                            .font(.body)
                            .foregroundColor(.secondary)
                    }
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .padding()
                    .background(Color(.systemGray6))
                    .cornerRadius(12)
                    
                    // Location
                    VStack(alignment: .leading, spacing: 8) {
                        Text("Plats")
                            .font(.headline)
                        
                        Map(coordinateRegion: .constant(MKCoordinateRegion(
                            center: trainer.coordinate,
                            span: MKCoordinateSpan(latitudeDelta: 0.01, longitudeDelta: 0.01)
                        )), annotationItems: [trainer]) { t in
                            MapMarker(coordinate: t.coordinate, tint: .green)
                        }
                        .frame(height: 150)
                        .cornerRadius(12)
                    }
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .padding()
                    .background(Color(.systemGray6))
                    .cornerRadius(12)
                    
                    // Book Button
                    Button {
                        showContactSheet = true
                    } label: {
                        HStack {
                            Image(systemName: "calendar.badge.plus")
                            Text("Boka lektion")
                        }
                        .font(.headline)
                        .foregroundColor(.white)
                        .frame(maxWidth: .infinity)
                        .padding()
                        .background(Color.green)
                        .cornerRadius(12)
                    }
                }
                .padding()
            }
            .navigationTitle("Tränare")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    Button("Stäng") {
                        dismiss()
                    }
                }
            }
            .sheet(isPresented: $showContactSheet) {
                ContactTrainerView(trainer: trainer)
                    .presentationDetents([.medium])
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
        .foregroundColor(.green)
        .padding(.horizontal, 12)
        .padding(.vertical, 6)
        .background(Color.green.opacity(0.15))
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
                    sendMessage()
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
                .background(message.isEmpty ? Color.gray : Color.green)
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
        }
    }
    
    private func sendMessage() {
        isSending = true
        // TODO: Implement actual message sending via Supabase
        DispatchQueue.main.asyncAfter(deadline: .now() + 1) {
            isSending = false
            showSuccess = true
        }
    }
}

// MARK: - View Model

@MainActor
class LessonsViewModel: ObservableObject {
    @Published var trainers: [GolfTrainer] = []
    @Published var isLoading = false
    
    func fetchTrainers() async {
        isLoading = true
        
        do {
            trainers = try await TrainerService.shared.fetchTrainers()
        } catch {
            print("❌ Failed to fetch trainers: \(error)")
        }
        
        isLoading = false
    }
}

// MARK: - Golf Trainer Model

struct GolfTrainer: Identifiable, Codable {
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
    
    var coordinate: CLLocationCoordinate2D {
        CLLocationCoordinate2D(latitude: latitude, longitude: longitude)
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
    }
}

#Preview {
    LessonsView()
}

