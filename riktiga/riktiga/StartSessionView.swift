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
                                .foregroundColor(AppColors.brandBlue)
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
    @State private var isPaused = false
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

            // MARK: - Stats and Controls Overlay
            VStack {
                Spacer()

                VStack(spacing: 16) {
                    // Activity Title
                    Text(activity.rawValue)
                        .font(.system(size: 20, weight: .bold))
                        .foregroundColor(.black)

                    // Stats
                    HStack(spacing: 16) {
                        StatView(
                            value: String(format: "%.2f", sessionDistance / 1000),
                            label: "KM"
                        )
                        StatView(
                            value: formattedTime(sessionDuration),
                            label: "TID"
                        )
                        StatView(
                            value: currentPace,
                            label: "TEMPO"
                        )
                    }
                    .padding(.vertical, 12)

                    // Control Buttons
                    if isPaused {
                        HStack(spacing: 12) {
                            Button(action: {
                                isPaused = false
                                isRunning = true
                                startTimer()
                            }) {
                                Text("FORTSÄTT")
                                    .font(.system(size: 16, weight: .black))
                                    .frame(maxWidth: .infinity)
                                    .padding(12)
                                    .background(AppColors.brandBlue)
                                    .foregroundColor(.white)
                                    .cornerRadius(10)
                            }

                            Button(action: {
                                stopTimer()
                                dismiss()
                            }) {
                                Text("AVSLUTA")
                                    .font(.system(size: 16, weight: .black))
                                    .frame(maxWidth: .infinity)
                                    .padding(12)
                                    .background(.black)
                                    .foregroundColor(.white)
                                    .cornerRadius(10)
                            }
                        }
                    } else {
                        Button(action: {
                            if isRunning {
                                isPaused = true
                                isRunning = false
                                stopTimer()
                            } else {
                                startTimer()
                                isRunning = true
                            }
                        }) {
                            HStack(spacing: 8) {
                                Image(systemName: isRunning ? "pause.fill" : "play.fill")
                                Text(isRunning ? "PAUSA" : "STARTA")
                            }
                            .font(.system(size: 16, weight: .black))
                            .frame(maxWidth: .infinity)
                            .padding(12)
                            .background(
                                LinearGradient(
                                    gradient: Gradient(colors: [
                                        AppColors.brandBlue,
                                        AppColors.brandGreen
                                    ]),
                                    startPoint: .leading,
                                    endPoint: .trailing
                                )
                            )
                            .foregroundColor(.white)
                            .cornerRadius(10)
                        }
                    }
                }
                .padding(16)
                .background(
                    RoundedRectangle(cornerRadius: 16)
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

struct StatView: View {
    let value: String
    let label: String

    var body: some View {
        VStack(spacing: 4) {
            Text(value)
                .font(.system(size: 18, weight: .black))
                .foregroundColor(.black)
            Text(label)
                .font(.system(size: 12, weight: .semibold))
                .foregroundColor(.gray)
        }
        .frame(maxWidth: .infinity)
    }
}

#Preview {
    StartSessionView()
}
