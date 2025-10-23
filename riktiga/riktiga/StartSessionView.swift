import SwiftUI

struct StartSessionView: View {
    @State private var showActivitySelection = true
    @State private var selectedActivityType: ActivityType?
    
    var body: some View {
        if showActivitySelection {
            SelectActivityView(isPresented: $showActivitySelection, selectedActivity: $selectedActivityType)
        } else if let activity = selectedActivityType {
            SessionTrackerView(activity: activity, isPresented: $showActivitySelection)
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
                // Header
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
                
                // Activity Grid
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
                
                // Cancel Button
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

struct SessionTrackerView: View {
    let activity: ActivityType
    @Binding var isPresented: Bool
    @Environment(\.dismiss) var dismiss
    
    @State private var duration: Double = 30
    @State private var isRunning = false
    @State private var elapsedTime: Int = 0
    @State private var timer: Timer?
    
    var caloriesBurned: Int {
        let caloriesPerMinute = activity == .running ? 10 : activity == .golf ? 6 : activity == .walking ? 5 : 8
        return elapsedTime * caloriesPerMinute / 60
    }
    
    var body: some View {
        NavigationStack {
            VStack(spacing: 20) {
                // Timer display
                ZStack {
                    Circle()
                        .stroke(Color.gray.opacity(0.2), lineWidth: 20)
                    
                    Circle()
                        .trim(from: 0, to: isRunning ? 1 : 0)
                        .stroke(
                            LinearGradient(
                                gradient: Gradient(colors: [
                                    Color(red: 0.1, green: 0.6, blue: 0.8),
                                    Color(red: 0.2, green: 0.4, blue: 0.9)
                                ]),
                                startPoint: .topLeading,
                                endPoint: .bottomTrailing
                            ),
                            style: StrokeStyle(lineWidth: 20, lineCap: .round)
                        )
                        .rotationEffect(.degrees(-90))
                        .animation(.linear(duration: 0.1), value: elapsedTime)
                    
                    VStack(spacing: 8) {
                        Text(formattedTime(elapsedTime))
                            .font(.system(size: 60, weight: .bold, design: .monospaced))
                        Text(activity.rawValue)
                            .font(.headline)
                            .foregroundColor(.gray)
                    }
                }
                .frame(height: 280)
                .padding(40)
                
                // Statistik
                HStack(spacing: 20) {
                    VStack(spacing: 8) {
                        Text(String(format: "%.0f", duration))
                            .font(.title2)
                            .fontWeight(.bold)
                        Text("Minuter planerat")
                            .font(.caption)
                            .foregroundColor(.gray)
                    }
                    .frame(maxWidth: .infinity)
                    
                    Divider()
                    
                    VStack(spacing: 8) {
                        Text("\(caloriesBurned)")
                            .font(.title2)
                            .fontWeight(.bold)
                        Text("kcal brände")
                            .font(.caption)
                            .foregroundColor(.gray)
                    }
                    .frame(maxWidth: .infinity)
                }
                .padding(16)
                .background(Color(.systemGray6))
                .cornerRadius(12)
                .padding(.horizontal)
                
                Spacer()
                
                // Kontrollknappar
                HStack(spacing: 16) {
                    Button(action: {
                        stopTimer()
                        isPresented = true
                    }) {
                        Text("Avbryt")
                            .frame(maxWidth: .infinity)
                            .padding(14)
                            .background(Color(.systemGray5))
                            .foregroundColor(.black)
                            .cornerRadius(10)
                            .font(.headline)
                    }
                    
                    Button(action: {
                        if isRunning {
                            stopTimer()
                        } else {
                            startTimer()
                        }
                    }) {
                        HStack(spacing: 8) {
                            Image(systemName: isRunning ? "pause.fill" : "play.fill")
                            Text(isRunning ? "Pausa" : "Starta")
                        }
                        .frame(maxWidth: .infinity)
                        .padding(14)
                        .background(
                            LinearGradient(
                                gradient: Gradient(colors: [
                                    Color(red: 0.1, green: 0.6, blue: 0.8),
                                    Color(red: 0.2, green: 0.4, blue: 0.9)
                                ]),
                                startPoint: .leading,
                                endPoint: .trailing
                            )
                        )
                        .foregroundColor(.white)
                        .cornerRadius(10)
                        .font(.headline)
                    }
                }
                .padding(.horizontal)
                .padding(.bottom, 20)
            }
            .navigationTitle("Starta pass")
            .navigationBarTitleDisplayMode(.inline)
            .navigationBarBackButtonHidden(false)
        }
        .onDisappear {
            stopTimer()
        }
    }
    
    func startTimer() {
        isRunning = true
        timer = Timer.scheduledTimer(withTimeInterval: 1, repeats: true) { _ in
            elapsedTime += 1
        }
    }
    
    func stopTimer() {
        isRunning = false
        timer?.invalidate()
        timer = nil
    }
    
    func formattedTime(_ seconds: Int) -> String {
        let minutes = seconds / 60
        let secs = seconds % 60
        return String(format: "%02d:%02d", minutes, secs)
    }
}

#Preview {
    StartSessionView()
}
