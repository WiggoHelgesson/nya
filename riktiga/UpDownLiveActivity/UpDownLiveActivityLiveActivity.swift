import ActivityKit
import WidgetKit
import SwiftUI
import AppIntents


// MARK: - App Logo View Helper
struct AppLogoView: View {
    let size: CGFloat
    let cornerRadius: CGFloat
    
    // Försök hitta logga i extensionens bundle - prova flera namn
    private var logoImage: UIImage? {
        // Prova "udlogo" först (nytt namn)
        if let img = UIImage(named: "udlogo") {
            return img
        }
        // Prova "logga"
        if let img = UIImage(named: "logga") {
            return img
        }
        return nil
    }
    
    var body: some View {
        Group {
            if let img = logoImage {
                Image(uiImage: img)
                    .resizable()
                    .scaledToFit()
            } else {
                // Fallback: Snygg text-baserad UD logo som matchar originalet
                ZStack {
                    RoundedRectangle(cornerRadius: cornerRadius)
                        .fill(
                            LinearGradient(
                                colors: [Color(white: 0.15), Color.black],
                                startPoint: .topLeading,
                                endPoint: .bottomTrailing
                            )
                        )
                    
                    // UD text som liknar loggan
                    HStack(spacing: -size * 0.12) {
                        Text("U")
                            .font(.system(size: size * 0.52, weight: .black, design: .rounded))
                        Text("D")
                            .font(.system(size: size * 0.52, weight: .black, design: .rounded))
                    }
                    .foregroundColor(.white)
                }
            }
        }
        .frame(width: size, height: size)
        .clipShape(RoundedRectangle(cornerRadius: cornerRadius))
    }
}

struct UpDownLiveActivityLiveActivity: Widget {
    var body: some WidgetConfiguration {
        ActivityConfiguration(for: WorkoutActivityAttributes.self) { context in
            // MARK: - Lock Screen / Banner UI
            VStack(spacing: 0) {
                if context.attributes.workoutType == "Löppass" {
                    RunningWorkoutView(context: context)
                } else {
                    GymWorkoutView(context: context)
                }
            }
            .activityBackgroundTint(Color.black)

        } dynamicIsland: { context in
            DynamicIsland {
                // MARK: - Expanded UI
                DynamicIslandExpandedRegion(.leading) {
                    AppLogoView(size: 32, cornerRadius: 8)
                }
                DynamicIslandExpandedRegion(.trailing) {
                    Text(timerInterval: context.state.startTime()...Date().addingTimeInterval(3600*10), countsDown: false)
                        .font(.system(.body, design: .monospaced).bold())
                        .foregroundColor(.white)
                }
                DynamicIslandExpandedRegion(.center) {
                    if context.attributes.workoutType == "Löppass" {
                        Text("Löppass")
                            .font(.headline)
                            .foregroundColor(.white)
                    } else {
                        Text(context.state.currentExercise ?? "Gympass")
                            .font(.headline)
                            .foregroundColor(.white)
                            .lineLimit(1)
                    }
                }
                DynamicIslandExpandedRegion(.bottom) {
                    if context.attributes.workoutType == "Löppass" {
                        HStack {
                            VStack {
                                Text("TEMPO").font(.caption2.bold()).foregroundColor(.gray)
                                Text(context.state.pace ?? "0:00").font(.title3.bold()).foregroundColor(.white)
                            }
                            Spacer()
                            VStack {
                                Text("DISTANS").font(.caption2.bold()).foregroundColor(.gray)
                                Text(String(format: "%.2f km", context.state.distance ?? 0)).font(.title3.bold()).foregroundColor(.white)
                            }
                        }
                        .padding(.horizontal)
                    } else {
                        // Gym: Visa set info och progressionsbar
                        VStack(spacing: 8) {
                            HStack {
                                Text("Set \(context.state.currentSet ?? 1) av \(context.state.totalSets ?? 1)")
                                    .font(.subheadline.bold())
                                    .foregroundColor(.white)
                                Spacer()
                                let volume = Int(context.state.totalVolume ?? 0)
                                Text("\(volume)/5000 kg")
                                    .font(.caption.bold())
                                    .foregroundColor(.white.opacity(0.6))
                            }
                            
                            // Progress bar
                            GeometryReader { geo in
                                let progress = min((context.state.totalVolume ?? 0) / 5000.0, 1.0)
                                ZStack(alignment: .leading) {
                                    RoundedRectangle(cornerRadius: 3)
                                        .fill(Color.white.opacity(0.2))
                                        .frame(height: 4)
                                    RoundedRectangle(cornerRadius: 3)
                                        .fill(progress >= 1.0 ? Color.green : Color.white)
                                        .frame(width: geo.size.width * progress, height: 4)
                                }
                            }
                            .frame(height: 4)
                        }
                        .padding(.horizontal)
                    }
                }
            } compactLeading: {
                // MARK: - Compact Leading
                AppLogoView(size: 24, cornerRadius: 6)
            } compactTrailing: {
                // MARK: - Compact Trailing
                Text(timerInterval: context.state.startTime()...Date().addingTimeInterval(3600*10), countsDown: false)
                    .font(.system(.caption, design: .monospaced).bold())
                    .foregroundColor(.white)
                    .frame(width: 45)
            } minimal: {
                AppLogoView(size: 20, cornerRadius: 5)
            }
            .widgetURL(URL(string: "upanddown://"))
            .keylineTint(Color.white)
        }
    }
}

// MARK: - Gym View
struct GymWorkoutView: View {
    let context: ActivityViewContext<WorkoutActivityAttributes>
    
    // Beräkna progress mot 5000kg
    private var volumeProgress: Double {
        let volume = context.state.totalVolume ?? 0
        return min(volume / 5000.0, 1.0)
    }
    
    // Formatera volym snyggt
    private var formattedVolume: String {
        let volume = Int(context.state.totalVolume ?? 0)
        if volume >= 1000 {
            let thousands = Double(volume) / 1000.0
            return String(format: "%.1fk", thousands)
        }
        return "\(volume)"
    }
    
    // Antal genomförda set (markerade som klara)
    private var completedSets: Int {
        context.state.completedSets ?? 0
    }
    
    var body: some View {
        VStack(spacing: 15) {
            // Header: "Gympass" + Logo
            ZStack {
                Text("Gympass")
                    .font(.system(size: 18, weight: .bold))
                    .foregroundColor(.gray)
                HStack {
                    Spacer()
                    AppLogoView(size: 32, cornerRadius: 8)
                }
            }
            
            // Tre värden: Tid, Volym, Sets
            HStack(alignment: .bottom) {
                // Tid
                VStack(spacing: 4) {
                    Text(timerInterval: context.state.startTime()...Date().addingTimeInterval(3600*10), countsDown: false)
                        .font(.system(size: 32, weight: .bold, design: .rounded))
                        .foregroundColor(.white)
                    Text("Tid")
                        .font(.system(size: 14, weight: .medium))
                        .foregroundColor(.gray)
                }
                .frame(maxWidth: .infinity)
                
                // Volym
                VStack(spacing: 4) {
                    Text(formattedVolume)
                        .font(.system(size: 32, weight: .bold, design: .rounded))
                        .foregroundColor(.white)
                    Text("Volym")
                        .font(.system(size: 14, weight: .medium))
                        .foregroundColor(.gray)
                }
                .frame(maxWidth: .infinity)
                
                // Sets
                VStack(spacing: 4) {
                    Text("\(completedSets)")
                        .font(.system(size: 32, weight: .bold, design: .rounded))
                        .foregroundColor(.white)
                    Text("Sets")
                        .font(.system(size: 14, weight: .medium))
                        .foregroundColor(.gray)
                }
                .frame(maxWidth: .infinity)
            }
            
            // Progressionsbar för 5000kg lott
            VStack(spacing: 6) {
                HStack {
                    Image(systemName: "ticket.fill")
                        .font(.system(size: 11))
                        .foregroundColor(.white.opacity(0.5))
                    Text("\(Int(context.state.totalVolume ?? 0)) / 5000 kg")
                        .font(.system(size: 11, weight: .medium))
                        .foregroundColor(.white.opacity(0.5))
                    Spacer()
                    if volumeProgress >= 1.0 {
                        HStack(spacing: 3) {
                            Image(systemName: "ticket.fill")
                                .font(.system(size: 11))
                            Text("Lott!")
                                .font(.system(size: 11, weight: .bold))
                        }
                        .foregroundColor(.green)
                    }
                }
                
                GeometryReader { geo in
                    ZStack(alignment: .leading) {
                        RoundedRectangle(cornerRadius: 3)
                            .fill(Color.white.opacity(0.15))
                            .frame(height: 5)
                        
                        RoundedRectangle(cornerRadius: 3)
                            .fill(volumeProgress >= 1.0 ? Color.green : Color.green.opacity(0.8))
                            .frame(width: geo.size.width * volumeProgress, height: 5)
                    }
                }
                .frame(height: 5)
            }
            .padding(.top, 2)
        }
        .padding(20)
    }
}

// MARK: - Running View
struct RunningWorkoutView: View {
    let context: ActivityViewContext<WorkoutActivityAttributes>
    
    var body: some View {
        VStack(spacing: 15) {
            ZStack {
                Text("Löppass")
                    .font(.system(size: 18, weight: .bold))
                    .foregroundColor(.gray)
                HStack {
                    Spacer()
                    AppLogoView(size: 32, cornerRadius: 8)
                }
            }
            HStack(alignment: .bottom) {
                VStack(spacing: 4) {
                    Text(timerInterval: context.state.startTime()...Date().addingTimeInterval(3600*10), countsDown: false)
                        .font(.system(size: 32, weight: .bold, design: .rounded))
                        .foregroundColor(.white)
                    Text("Tid").font(.system(size: 14, weight: .medium)).foregroundColor(.gray)
                }
                .frame(maxWidth: .infinity)
                VStack(spacing: 4) {
                    Text(context.state.pace ?? "0:00")
                        .font(.system(size: 32, weight: .bold, design: .rounded))
                        .foregroundColor(.white)
                    Text("Tempo").font(.system(size: 14, weight: .medium)).foregroundColor(.gray)
                }
                .frame(maxWidth: .infinity)
                VStack(spacing: 4) {
                    Text(String(format: "%.2f", context.state.distance ?? 0))
                        .font(.system(size: 32, weight: .bold, design: .rounded))
                        .foregroundColor(.white)
                    Text("Distans").font(.system(size: 14, weight: .medium)).foregroundColor(.gray)
                }
                .frame(maxWidth: .infinity)
            }
            .padding(.bottom, 10)
        }
        .padding(20)
    }
}

extension WorkoutActivityAttributes.ContentState {
    func startTime() -> Date {
        return Date().addingTimeInterval(-TimeInterval(elapsedSeconds))
    }
}
