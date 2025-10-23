import SwiftUI
import MapKit
import CoreLocation

struct StartSessionView: View {
    @State private var showActivitySelection = true
    @State private var selectedActivityType: ActivityType?
    
    var body: some View {
        if showActivitySelection {
            SelectActivityView(isPresented: $showActivitySelection, selectedActivity: $selectedActivityType)
        } else if let activity = selectedActivityType {
            SessionMapView(activity: activity, isPresented: $showActivitySelection)
        }
    }
}

enum ActivityType: String, CaseIterable {
    case running = "Löppass"
    case golf = "Golfrunda"
    case walking = "Promenad"
    case hiking = "Bestiga berg"
    
    var icon: String {
        switch self {
        case .running:
            return "figure.run"
        case .golf:
            return "flag.fill"
        case .walking:
            return "figure.walk"
        case .hiking:
            return "mountain.2.fill"
        }
    }
}

struct SelectActivityView: View {
    @Binding var isPresented: Bool
    @Binding var selectedActivity: ActivityType?
    @Environment(\.dismiss) var dismiss
    
    let activities: [ActivityType] = [.running, .golf, .walking, .hiking]
    
    var body: some View {
        VStack(spacing: 0) {
            // MARK: - Header with Branding and Background
            VStack(spacing: 8) {
                Text("VÄLJ AKTIVITET")
                    .font(.system(size: 40, weight: .black))
                    .foregroundColor(.white)
                    .frame(maxWidth: .infinity, alignment: .leading)
                
                Text("Vilken aktivitet vill du göra idag?")
                    .font(.system(size: 16, weight: .semibold))
                    .foregroundColor(.white)
                    .frame(maxWidth: .infinity, alignment: .leading)
            }
            .frame(maxWidth: .infinity, alignment: .leading)
            .padding(24)
            .background(AppColors.brandBlue.opacity(0.8))
            .rotationEffect(.degrees(-2))
            .padding(.bottom, 12)
            
            Spacer()
            
            // MARK: - Activity Cards
            VStack(spacing: 16) {
                ForEach(activities, id: \.self) { activity in
                    Button(action: {
                        selectedActivity = activity
                        isPresented = false
                    }) {
                        HStack(spacing: 16) {
                            Image(systemName: activity.icon)
                                .font(.system(size: 32))
                                .foregroundColor(.black)
                                .frame(width: 60, height: 60)
                                .background(Color(.systemGray6))
                                .cornerRadius(12)
                            
                            VStack(alignment: .leading, spacing: 4) {
                                Text(activity.rawValue)
                                    .font(.system(size: 18, weight: .semibold))
                                    .foregroundColor(.black)
                                Text("Starta ett nytt pass")
                                    .font(.caption)
                                    .foregroundColor(.gray)
                            }
                            
                            Spacer()
                            
                            Image(systemName: "chevron.right")
                                .foregroundColor(.gray)
                        }
                        .padding(16)
                        .background(Color.white)
                        .cornerRadius(14)
                        .overlay(
                            RoundedRectangle(cornerRadius: 14)
                                .stroke(Color(.systemGray6), lineWidth: 1)
                        )
                    }
                }
            }
            .padding(16)
            
            Spacer()
            
            // MARK: - Cancel Button
            Button(action: {
                dismiss()
            }) {
                Text("AVBRYT")
                    .font(.system(size: 16, weight: .black))
                    .frame(maxWidth: .infinity)
                    .padding(14)
                    .background(Color(.systemGray5))
                    .foregroundColor(.black)
                    .cornerRadius(10)
            }
            .padding(16)
        }
        .background(AppColors.white)
    }
}

struct SessionMapView: View {
    let activity: ActivityType
    @Binding var isPresented: Bool
    @State private var region = MKCoordinateRegion(
        center: CLLocationCoordinate2D(latitude: 59.3293, longitude: 18.0686),
        span: MKCoordinateSpan(latitudeDelta: 0.05, longitudeDelta: 0.05)
    )
    @State private var isRunning = false
    @State private var sessionDuration: Int = 0
    @State private var sessionDistance: Double = 0.0
    @State private var currentPace: String = "0'00\"/km"
    @State private var timer: Timer?
    @Environment(\.dismiss) var dismiss

    var body: some View {
        ZStack {
            // MARK: - Map Background
            Map(coordinateRegion: $region, showsUserLocation: true)
                .ignoresSafeArea()

            // MARK: - Back Button
            VStack {
                HStack {
                    Button(action: {
                        dismiss()
                        stopTimer()
                    }) {
                        Image(systemName: "chevron.left.circle.fill")
                            .font(.system(size: 32))
                            .foregroundColor(.white)
                            .shadow(radius: 5)
                    }
                    .padding(.leading, 16)
                    Spacer()
                }
                .padding(.top, 16)
                Spacer()
            }

            // MARK: - Bottom Stats and Controls
            VStack {
                Spacer()

                VStack(spacing: 20) {
                    // GPS Status
                    HStack(spacing: 8) {
                        Image(systemName: "location.fill")
                            .font(.system(size: 14))
                            .foregroundColor(AppColors.brandBlue)
                        Text("GPS")
                            .font(.system(size: 14, weight: .semibold))
                            .foregroundColor(.black)
                    }

                    // Status
                    VStack(spacing: 8) {
                        Text("Inspelning pågår")
                            .font(.system(size: 14, weight: .semibold))
                            .foregroundColor(.black)
                    }

                    // Stats Grid
                    HStack(spacing: 24) {
                        VStack(spacing: 4) {
                            Text(String(format: "%.2f", sessionDistance))
                                .font(.system(size: 24, weight: .black))
                                .foregroundColor(.black)
                            Text("km")
                                .font(.system(size: 12, weight: .semibold))
                                .foregroundColor(.gray)
                        }
                        
                        VStack(spacing: 4) {
                            Text(formattedTime(sessionDuration))
                                .font(.system(size: 24, weight: .black))
                                .foregroundColor(.black)
                            Text("Tid")
                                .font(.system(size: 12, weight: .semibold))
                                .foregroundColor(.gray)
                        }
                        
                        VStack(spacing: 4) {
                            Text(currentPace)
                                .font(.system(size: 24, weight: .black))
                                .foregroundColor(.black)
                            Text("Tempo")
                                .font(.system(size: 12, weight: .semibold))
                                .foregroundColor(.gray)
                        }
                        
                        Spacer()
                    }
                    .padding(.horizontal, 16)

                    // Start/Pause Button
                    Button(action: {
                        if isRunning {
                            stopTimer()
                            isRunning = false
                        } else {
                            startTimer()
                            isRunning = true
                        }
                    }) {
                        Text(isRunning ? "Pausa" : "Starta löpning")
                            .font(.system(size: 16, weight: .black))
                            .frame(maxWidth: .infinity)
                            .padding(14)
                            .background(.black)
                            .foregroundColor(.white)
                            .cornerRadius(12)
                    }
                    .padding(.horizontal, 16)

                    // View Other Options
                    NavigationLink(destination: Text("Andra alternativ")) {
                        Text("Se andra alternativ")
                            .font(.system(size: 14, weight: .semibold))
                            .foregroundColor(AppColors.brandBlue)
                            .frame(maxWidth: .infinity)
                            .padding(10)
                    }
                }
                .padding(20)
                .background(
                    RoundedRectangle(cornerRadius: 20)
                        .fill(Color.white.opacity(0.95))
                        .shadow(radius: 10)
                )
                .padding(16)
            }
        }
        .onDisappear {
            stopTimer()
        }
    }

    func startTimer() {
        isRunning = true
        timer = Timer.scheduledTimer(withTimeInterval: 1, repeats: true) { _ in
            sessionDuration += 1
            // Simulera distans (ca 10 km/h för löpning)
            sessionDistance += 0.00278
            updatePace()
        }
    }

    func stopTimer() {
        isRunning = false
        timer?.invalidate()
        timer = nil
    }

    func updatePace() {
        if sessionDuration > 0 && sessionDistance > 0 {
            let paceSeconds = (Double(sessionDuration) / sessionDistance) * 1000 // sekunder per km
            let minutes = Int(paceSeconds / 60)
            let seconds = Int(paceSeconds.truncatingRemainder(dividingBy: 60))
            currentPace = String(format: "%d'%02d\"/km", minutes, seconds)
        }
    }

    func formattedTime(_ seconds: Int) -> String {
        let hours = seconds / 3600
        let minutes = (seconds % 3600) / 60
        let secs = seconds % 60
        if hours > 0 {
            return String(format: "%d:%02d:%02d", hours, minutes, secs)
        } else {
            return String(format: "%02d:%02d", minutes, secs)
        }
    }
}

#Preview {
    StartSessionView()
}
