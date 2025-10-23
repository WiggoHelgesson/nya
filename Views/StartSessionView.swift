import SwiftUI

struct StartSessionView: View {
    @Environment(\.dismiss) var dismiss
    @State private var selectedActivity = "Löpning"
    @State private var duration: Double = 30
    @State private var isRunning = false
    @State private var elapsedTime: Int = 0
    @State private var timer: Timer?
    
    let activities = ["Löpning", "Cykling", "Promenad", "Styrketräning", "Yoga", "Simning"]
    
    var caloriesBurned: Int {
        let caloriesPerMinute = selectedActivity == "Löpning" ? 10 : selectedActivity == "Cykling" ? 9 : 5
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
                        Text(selectedActivity)
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
                
                // Aktivitetsväljare
                VStack(alignment: .leading, spacing: 8) {
                    Text("Välj aktivitet")
                        .font(.headline)
                    
                    Picker("Aktivitet", selection: $selectedActivity) {
                        ForEach(activities, id: \.self) { activity in
                            Text(activity).tag(activity)
                        }
                    }
                    .pickerStyle(.segmented)
                }
                .padding(.horizontal)
                
                Spacer()
                
                // Kontrollknappar
                HStack(spacing: 16) {
                    Button(action: {
                        dismiss()
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
