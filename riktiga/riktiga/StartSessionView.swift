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
        NavigationStack {
            VStack(spacing: 0) {
                VStack(spacing: 12) {
                    Text("Välj aktivitet")
                        .font(.system(size: 28, weight: .bold))
                    Text("Vilken aktivitet vill du göra idag?")
                        .font(.body)
                        .foregroundColor(.gray)
                }
                .frame(maxWidth: .infinity, alignment: .leading)
                .padding(24)
                
                Spacer()
                
                VStack(spacing: 16) {
                    ForEach(activities, id: \.self) { activity in
                        Button(action: {
                            selectedActivity = activity
                            isPresented = false
                        }) {
                            HStack(spacing: 16) {
                                Image(systemName: activity.icon)
                                    .font(.system(size: 32))
                                    .foregroundColor(Color(red: 0.1, green: 0.6, blue: 0.8))
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
                
                Button(action: {
                    dismiss()
                }) {
                    Text("Avbryt")
                        .frame(maxWidth: .infinity)
                        .padding(14)
                        .background(Color(.systemGray5))
                        .foregroundColor(.black)
                        .cornerRadius(25)
                        .font(.headline)
                }
                .padding(16)
            }
            .background(Color(.systemGray6).opacity(0.3))
            .navigationBarBackButtonHidden(true)
        }
    }
}

struct SessionMapView: View {
    let activity: ActivityType
    @Binding var isPresented: Bool
    @Environment(\.dismiss) var dismiss
    
    @StateObject private var locationManager = LocationManager()
    @State private var position: MapCameraPosition = .automatic
    @State private var elapsedTime: Int = 0
    @State private var isRunning = false
    @State private var timer: Timer?
    @State private var routePoints: [CLLocationCoordinate2D] = []
    @State private var lastLocationString = ""
    
    var caloriesBurned: Int {
        let caloriesPerMinute = activity == .running ? 10 : activity == .golf ? 6 : activity == .walking ? 5 : 8
        return elapsedTime * caloriesPerMinute / 60
    }
    
    var averagePace: String {
        guard elapsedTime > 0 && locationManager.distance > 0 else { return "0:00" }
        let paceSeconds = Int((Double(elapsedTime) / locationManager.distance) * 60)
        let minutes = paceSeconds / 60
        let seconds = paceSeconds % 60
        return String(format: "%d:%02d", minutes, seconds)
    }
    
    var body: some View {
        ZStack {
            Map(position: $position) {
                if let userLocation = locationManager.userLocation {
                    Annotation("", coordinate: userLocation) {
                        Image(systemName: "location.circle.fill")
                            .font(.system(size: 30))
                            .foregroundColor(.blue)
                    }
                }
                
                if routePoints.count > 1 {
                    MapPolyline(coordinates: routePoints)
                        .stroke(.blue, lineWidth: 3)
                }
            }
            .mapStyle(.standard)
            .ignoresSafeArea()
            
            VStack {
                HStack {
                    Button(action: {
                        locationManager.stopTracking()
                        stopTimer()
                        dismiss()
                    }) {
                        Image(systemName: "chevron.left")
                            .font(.headline)
                            .foregroundColor(.black)
                    }
                    
                    Spacer()
                    
                    Text(activity.rawValue)
                        .font(.headline)
                    
                    Spacer()
                    
                    Button(action: {}) {
                        Image(systemName: "ellipsis")
                            .font(.headline)
                            .foregroundColor(.black)
                    }
                }
                .padding(16)
                .background(Color.white.opacity(0.95))
                
                Spacer()
                
                VStack(spacing: 16) {
                    HStack {
                        Image(systemName: "location.circle.fill")
                            .foregroundColor(.red)
                        Text("GPS")
                            .font(.caption)
                        Spacer()
                    }
                    
                    HStack(spacing: 12) {
                        VStack(alignment: .leading, spacing: 4) {
                            Text("⭕m²")
                                .font(.system(size: 32, weight: .bold))
                            Text("Capture in Progress")
                                .font(.caption)
                                .foregroundColor(.gray)
                        }
                        Spacer()
                    }
                    
                    HStack(spacing: 24) {
                        VStack(alignment: .leading, spacing: 4) {
                            Text(String(format: "%.2f", locationManager.distance))
                                .font(.system(size: 18, weight: .bold))
                            Text("km")
                                .font(.caption2)
                                .foregroundColor(.gray)
                        }
                        
                        VStack(alignment: .leading, spacing: 4) {
                            Text(formattedTime(elapsedTime))
                                .font(.system(size: 18, weight: .bold))
                            Text("Duration")
                                .font(.caption2)
                                .foregroundColor(.gray)
                        }
                        
                        VStack(alignment: .leading, spacing: 4) {
                            Text(averagePace)
                                .font(.system(size: 18, weight: .bold))
                            Text("Average pace")
                                .font(.caption2)
                                .foregroundColor(.gray)
                        }
                        
                        Spacer()
                    }
                    
                    Button(action: {
                        if isRunning {
                            stopTimer()
                            locationManager.stopTracking()
                        } else {
                            startTimer()
                            locationManager.startTracking()
                        }
                        isRunning.toggle()
                    }) {
                        Text(isRunning ? "Pausa" : "Start Run")
                            .frame(maxWidth: .infinity)
                            .padding(14)
                            .background(Color.black)
                            .foregroundColor(.white)
                            .cornerRadius(10)
                            .font(.headline)
                    }
                    
                    Button(action: {}) {
                        Text("View other options")
                            .font(.caption)
                            .foregroundColor(.blue)
                            .underline()
                    }
                }
                .padding(16)
                .background(Color.white)
                .cornerRadius(16)
                .padding(16)
            }
        }
        .onAppear {
            locationManager.requestBackgroundLocationPermission()
        }
    }
    
    func startTimer() {
        timer = Timer.scheduledTimer(withTimeInterval: 1, repeats: true) { _ in
            elapsedTime += 1
        }
    }
    
    func stopTimer() {
        timer?.invalidate()
        timer = nil
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
