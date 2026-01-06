import SwiftUI

struct StrengthScoreView: View {
    let userId: String
    let posts: [SocialWorkoutPost]
    @State private var strengthScore: StrengthScore?
    
    var body: some View {
        NavigationLink(destination: StrengthScoreDetailView(userId: userId, posts: posts)) {
            ZStack {
                RoundedRectangle(cornerRadius: 20)
                    .fill(Color(red: 0.12, green: 0.12, blue: 0.12))
                
                VStack(spacing: 0) {
                    HStack(spacing: 16) {
                        // Score och info
                        VStack(alignment: .leading, spacing: 16) {
                            if let score = strengthScore {
                                HStack(alignment: .firstTextBaseline, spacing: 4) {
                                    Text("\(score.totalScore)")
                                        .font(.system(size: 56, weight: .bold))
                                        .foregroundColor(Color(
                                            red: score.level.color.red,
                                            green: score.level.color.green,
                                            blue: score.level.color.blue
                                        ))
                                    
                                    Text("/100")
                                        .font(.system(size: 28, weight: .medium))
                                        .foregroundColor(.gray)
                                }
                                
                                // Level badge
                                Text(score.level.rawValue)
                                    .font(.system(size: 16, weight: .semibold))
                                    .foregroundColor(Color(
                                        red: score.level.color.red,
                                        green: score.level.color.green,
                                        blue: score.level.color.blue
                                    ))
                                    .padding(.horizontal, 16)
                                    .padding(.vertical, 8)
                                    .background(
                                        Capsule()
                                            .stroke(Color(
                                                red: score.level.color.red,
                                                green: score.level.color.green,
                                                blue: score.level.color.blue
                                            ), lineWidth: 2)
                                    )
                            } else {
                                ProgressView()
                                    .tint(.white)
                            }
                            
                            Spacer()
                        }
                        
                        Spacer()
                        
                        // Mini kroppsillustration + level badges
                        if let score = strengthScore {
                            VStack(spacing: 8) {
                                MiniBodyIllustration(muscleProgress: score.muscleProgress)
                                    .frame(width: 100, height: 180)
                                
                                // Top 3 muscles
                                let topMuscles = score.muscleProgress
                                    .sorted { $0.currentLevel > $1.currentLevel }
                                    .prefix(3)
                                
                                VStack(spacing: 4) {
                                    ForEach(Array(topMuscles), id: \.muscleGroup) { muscle in
                                        if muscle.currentLevel > 0 {
                                            HStack(spacing: 6) {
                                                Circle()
                                                    .fill(Color(
                                                        red: muscle.color.red,
                                                        green: muscle.color.green,
                                                        blue: muscle.color.blue
                                                    ))
                                                    .frame(width: 8, height: 8)
                                                
                                                Text("\(muscle.muscleGroup)")
                                                    .font(.system(size: 11))
                                                    .foregroundColor(.white)
                                                
                                                Spacer()
                                                
                                                Text("Lv \(muscle.currentLevel)")
                                                    .font(.system(size: 11, weight: .bold))
                                                    .foregroundColor(Color(
                                                        red: muscle.color.red,
                                                        green: muscle.color.green,
                                                        blue: muscle.color.blue
                                                    ))
                                            }
                                        }
                                    }
                                }
                                .padding(8)
                                .background(Color.black.opacity(0.3))
                                .cornerRadius(8)
                            }
                        }
                    }
                    .padding(24)
                    
                    // Progress bar section
                    if let score = strengthScore, score.pointsToNextLevel > 0 {
                        VStack(spacing: 10) {
                            Divider()
                                .background(Color.white.opacity(0.2))
                                .padding(.horizontal, 24)
                            
                            HStack(spacing: 12) {
                                Text("\(score.pointsToNextLevel) poäng till Level \(nextLevelName(score.level))")
                                    .font(.system(size: 15, weight: .semibold))
                                    .foregroundColor(.white)
                                
                                Spacer()
                                
                                // Percentage
                                let currentRangeStart = score.level.range.lowerBound
                                let currentRangeEnd = score.level.range.upperBound
                                let progressInLevel = Double(score.totalScore - currentRangeStart) / Double(currentRangeEnd - currentRangeStart)
                                
                                Text("\(Int(progressInLevel * 100))%")
                                    .font(.system(size: 16, weight: .bold))
                                    .foregroundColor(Color(
                                        red: score.level.color.red,
                                        green: score.level.color.green,
                                        blue: score.level.color.blue
                                    ))
                            }
                            .padding(.horizontal, 24)
                            
                            // Progress bar
                            GeometryReader { geo in
                                ZStack(alignment: .leading) {
                                    RoundedRectangle(cornerRadius: 6)
                                        .fill(Color.white.opacity(0.1))
                                    
                                    let currentRangeStart = score.level.range.lowerBound
                                    let currentRangeEnd = score.level.range.upperBound
                                    let progressInLevel = Double(score.totalScore - currentRangeStart) / Double(currentRangeEnd - currentRangeStart)
                                    
                                    RoundedRectangle(cornerRadius: 6)
                                        .fill(
                                            LinearGradient(
                                                colors: [
                                                    Color(red: score.level.color.red, green: score.level.color.green, blue: score.level.color.blue),
                                                    Color(red: score.level.color.red, green: score.level.color.green, blue: score.level.color.blue).opacity(0.7)
                                                ],
                                                startPoint: .leading,
                                                endPoint: .trailing
                                            )
                                        )
                                        .frame(width: geo.size.width * CGFloat(max(0.05, progressInLevel)))
                                }
                            }
                            .frame(height: 12)
                            .padding(.horizontal, 24)
                        }
                        .padding(.bottom, 16)
                    }
                    
                    // Chevron
                    VStack {
                        HStack {
                            Spacer()
                            Image(systemName: "chevron.right")
                                .font(.system(size: 18, weight: .semibold))
                                .foregroundColor(.white.opacity(0.3))
                                .padding()
                        }
                        Spacer()
                    }
                }
            }
            .frame(minHeight: 240)
        }
        .buttonStyle(PlainButtonStyle())
        .onAppear {
            calculateScore()
        }
    }
    
    private func nextLevelName(_ level: StrengthLevel) -> String {
        switch level {
        case .beginner: return "Grundnivå"
        case .novice: return "Medel"
        case .intermediate: return "Avancerad"
        case .advanced: return "Expert"
        case .expert: return "Max"
        }
    }
    
    private func calculateScore() {
        Task {
            strengthScore = await StrengthScoreService.shared.calculateStrengthScore(userId: userId, from: posts)
        }
    }
}

// MARK: - Detail View

struct StrengthScoreDetailView: View {
    let userId: String
    let posts: [SocialWorkoutPost]
    @State private var strengthScore: StrengthScore?
    @Environment(\.dismiss) private var dismiss
    
    var body: some View {
        ZStack(alignment: .topLeading) {
            ScrollView {
                VStack(spacing: 24) {
                    if let score = strengthScore {
                        // Kroppsillustration längst upp
                        BodyIllustrationView(muscleProgress: score.muscleProgress)
                            .padding(.top, 60)
                            .padding(.horizontal)
                        
                        // Header med score
                        VStack(spacing: 16) {
                            HStack(alignment: .firstTextBaseline, spacing: 4) {
                                Text("\(score.totalScore)")
                                    .font(.system(size: 72, weight: .bold))
                                    .foregroundColor(Color(
                                        red: score.level.color.red,
                                        green: score.level.color.green,
                                        blue: score.level.color.blue
                                    ))
                                
                                Text("/100")
                                    .font(.system(size: 36, weight: .medium))
                                    .foregroundColor(.gray)
                            }
                            
                            // Level badge
                            Text(score.level.rawValue)
                                .font(.system(size: 20, weight: .semibold))
                                .foregroundColor(Color(
                                    red: score.level.color.red,
                                    green: score.level.color.green,
                                    blue: score.level.color.blue
                                ))
                                .padding(.horizontal, 24)
                                .padding(.vertical, 12)
                                .background(
                                    Capsule()
                                        .stroke(Color(
                                            red: score.level.color.red,
                                            green: score.level.color.green,
                                            blue: score.level.color.blue
                                        ), lineWidth: 2)
                                )
                            
                            // Total XP
                            VStack(spacing: 4) {
                                Text("\(Int(score.totalXP)) totalt XP")
                                    .font(.system(size: 18, weight: .medium))
                                    .foregroundColor(.white.opacity(0.8))
                                
                                let totalLevels = score.muscleProgress.reduce(0) { $0 + $1.currentLevel }
                                Text("\(totalLevels) totala muskelnivåer")
                                    .font(.system(size: 14))
                                    .foregroundColor(.gray)
                            }
                            .padding(.top, 8)
                        }
                        .padding(.top, 20)
                    
                    // Muskelnivåer lista
                    VStack(alignment: .leading, spacing: 12) {
                        Text("Muskelnivåer")
                            .font(.system(size: 20, weight: .bold))
                            .foregroundColor(.white)
                        
                        ForEach(score.muscleProgress.sorted(by: { $0.currentLevel > $1.currentLevel }), id: \.muscleGroup) { muscle in
                            VStack(spacing: 4) {
                                HStack {
                                    Text(muscle.muscleGroup)
                                        .font(.system(size: 16, weight: .medium))
                                        .foregroundColor(.white)
                                    
                                    Spacer()
                                    
                                    Text("Nivå \(muscle.currentLevel)")
                                        .font(.system(size: 16, weight: .bold))
                                        .foregroundColor(Color(
                                            red: muscle.color.red,
                                            green: muscle.color.green,
                                            blue: muscle.color.blue
                                        ))
                                }
                                
                                // Progress bar
                                GeometryReader { geo in
                                    ZStack(alignment: .leading) {
                                        RoundedRectangle(cornerRadius: 4)
                                            .fill(Color.white.opacity(0.1))
                                        
                                        RoundedRectangle(cornerRadius: 4)
                                            .fill(Color(
                                                red: muscle.color.red,
                                                green: muscle.color.green,
                                                blue: muscle.color.blue
                                            ))
                                            .frame(width: geo.size.width * muscle.progressToNextLevel)
                                    }
                                }
                                .frame(height: 8)
                                
                                HStack {
                                    Text("\(Int(muscle.currentXP)) XP")
                                        .font(.system(size: 12))
                                        .foregroundColor(.gray)
                                    
                                    Spacer()
                                    
                                    if muscle.currentLevel < 100 {
                                        Text("\(Int(muscle.nextLevelXP - muscle.currentXP)) XP till nästa")
                                            .font(.system(size: 12))
                                            .foregroundColor(.gray)
                                    } else {
                                        Text("MAX")
                                            .font(.system(size: 12, weight: .bold))
                                            .foregroundColor(.yellow)
                                    }
                                }
                            }
                            .padding()
                            .background(Color.white.opacity(0.05))
                            .cornerRadius(12)
                        }
                    }
                    .padding(.horizontal)
                    
                    // Achievements
                    if !score.achievements.isEmpty {
                        VStack(alignment: .leading, spacing: 12) {
                            Text("Prestationer")
                                .font(.system(size: 20, weight: .bold))
                                .foregroundColor(.white)
                            
                            ForEach(score.achievements, id: \.self) { achievement in
                                Text(achievement)
                                    .font(.system(size: 16))
                                    .foregroundColor(.white)
                                    .padding()
                                    .frame(maxWidth: .infinity, alignment: .leading)
                                    .background(Color.white.opacity(0.1))
                                    .cornerRadius(12)
                            }
                        }
                        .padding(.horizontal)
                    }
                    
                } else {
                    ProgressView()
                        .tint(.white)
                        .padding(.top, 100)
                }
            }
            .padding(.bottom, 40)
        }
        .background(Color.black.ignoresSafeArea())
        .toolbar(.hidden, for: .navigationBar)
        .onAppear {
            calculateScore()
        }
        
            // Stäng-knapp
            Button(action: { dismiss() }) {
                ZStack {
                    Circle()
                        .fill(Color.white.opacity(0.2))
                        .frame(width: 36, height: 36)
                    
                    Image(systemName: "xmark")
                        .font(.system(size: 14, weight: .semibold))
                        .foregroundColor(.white)
                }
            }
            .padding(.top, 60)
            .padding(.leading, 20)
        }
    }
    
    private func calculateScore() {
        Task {
            strengthScore = await StrengthScoreService.shared.calculateStrengthScore(userId: userId, from: posts)
        }
    }
}

// MARK: - Mini Body Illustration (för card)

struct MiniBodyIllustration: View {
    let muscleProgress: [MuscleLevel]
    
    var body: some View {
        GeometryReader { geo in
            ZStack {
                let w = geo.size.width
                let h = geo.size.height
                
                // Huvud
                Circle()
                    .fill(
                        RadialGradient(
                            colors: [Color.white.opacity(0.15), Color.white.opacity(0.05)],
                            center: .center,
                            startRadius: 2,
                            endRadius: 15
                        )
                    )
                    .frame(width: w * 0.2, height: w * 0.2)
                    .position(x: w * 0.5, y: h * 0.10)
                    .overlay(
                        Circle()
                            .stroke(Color.white.opacity(0.3), lineWidth: 1)
                            .frame(width: w * 0.2, height: w * 0.2)
                            .position(x: w * 0.5, y: h * 0.10)
                    )
                
                // Axlar (shoulders)
                Path { path in
                    path.addEllipse(in: CGRect(x: w * 0.2, y: h * 0.18, width: w * 0.16, height: h * 0.09))
                    path.addEllipse(in: CGRect(x: w * 0.64, y: h * 0.18, width: w * 0.16, height: h * 0.09))
                }
                .fill(
                    RadialGradient(
                        colors: [
                            colorForMuscle("Axlar").opacity(0.8),
                            colorForMuscle("Axlar")
                        ],
                        center: .center,
                        startRadius: 5,
                        endRadius: 20
                    )
                )
                .shadow(color: colorForMuscle("Axlar").opacity(0.6), radius: 4, x: 0, y: 0)
                
                // Bröst (chest)
                Path { path in
                    path.addEllipse(in: CGRect(x: w * 0.36, y: h * 0.22, width: w * 0.11, height: h * 0.09))
                    path.addEllipse(in: CGRect(x: w * 0.53, y: h * 0.22, width: w * 0.11, height: h * 0.09))
                }
                .fill(
                    RadialGradient(
                        colors: [
                            colorForMuscle("Bröst").opacity(0.8),
                            colorForMuscle("Bröst")
                        ],
                        center: .center,
                        startRadius: 3,
                        endRadius: 18
                    )
                )
                .shadow(color: colorForMuscle("Bröst").opacity(0.6), radius: 5, x: 0, y: 0)
                
                // Mage (abs) - 4-pack mini version
                VStack(spacing: 2) {
                    HStack(spacing: 4) {
                        RoundedRectangle(cornerRadius: 3)
                            .fill(
                                LinearGradient(
                                    colors: [
                                        colorForMuscle("Mage").opacity(0.8),
                                        colorForMuscle("Mage")
                                    ],
                                    startPoint: .topLeading,
                                    endPoint: .bottomTrailing
                                )
                            )
                            .frame(width: w * 0.08, height: h * 0.05)
                        
                        RoundedRectangle(cornerRadius: 3)
                            .fill(
                                LinearGradient(
                                    colors: [
                                        colorForMuscle("Mage").opacity(0.8),
                                        colorForMuscle("Mage")
                                    ],
                                    startPoint: .topLeading,
                                    endPoint: .bottomTrailing
                                )
                            )
                            .frame(width: w * 0.08, height: h * 0.05)
                    }
                    
                    HStack(spacing: 4) {
                        RoundedRectangle(cornerRadius: 3)
                            .fill(
                                LinearGradient(
                                    colors: [
                                        colorForMuscle("Mage").opacity(0.8),
                                        colorForMuscle("Mage")
                                    ],
                                    startPoint: .topLeading,
                                    endPoint: .bottomTrailing
                                )
                            )
                            .frame(width: w * 0.08, height: h * 0.05)
                        
                        RoundedRectangle(cornerRadius: 3)
                            .fill(
                                LinearGradient(
                                    colors: [
                                        colorForMuscle("Mage").opacity(0.8),
                                        colorForMuscle("Mage")
                                    ],
                                    startPoint: .topLeading,
                                    endPoint: .bottomTrailing
                                )
                            )
                            .frame(width: w * 0.08, height: h * 0.05)
                    }
                }
                .shadow(color: colorForMuscle("Mage").opacity(0.5), radius: 3, x: 0, y: 0)
                .position(x: w * 0.5, y: h * 0.45)
                
                // Armar (biceps)
                Path { path in
                    path.addEllipse(in: CGRect(x: w * 0.17, y: h * 0.28, width: w * 0.09, height: h * 0.12))
                    path.addEllipse(in: CGRect(x: w * 0.74, y: h * 0.28, width: w * 0.09, height: h * 0.12))
                }
                .fill(
                    LinearGradient(
                        colors: [
                            colorForMuscle("Biceps").opacity(0.8),
                            colorForMuscle("Biceps")
                        ],
                        startPoint: .top,
                        endPoint: .bottom
                    )
                )
                .shadow(color: colorForMuscle("Biceps").opacity(0.4), radius: 3, x: 0, y: 0)
                
                // Ben (legs)
                Path { path in
                    path.addEllipse(in: CGRect(x: w * 0.34, y: h * 0.58, width: w * 0.12, height: h * 0.32))
                    path.addEllipse(in: CGRect(x: w * 0.54, y: h * 0.58, width: w * 0.12, height: h * 0.32))
                }
                .fill(
                    LinearGradient(
                        colors: [
                            colorForMuscle("Ben").opacity(0.8),
                            colorForMuscle("Ben")
                        ],
                        startPoint: .top,
                        endPoint: .bottom
                    )
                )
                .shadow(color: colorForMuscle("Ben").opacity(0.5), radius: 4, x: 0, y: 0)
            }
        }
    }
    
    private func colorForMuscle(_ muscleName: String) -> Color {
        if let muscle = muscleProgress.first(where: { $0.muscleGroup == muscleName }) {
            return Color(red: muscle.color.red, green: muscle.color.green, blue: muscle.color.blue)
        }
        return Color.gray.opacity(0.3)
    }
}

// MARK: - Full Body Illustration (för detail view)

struct BodyIllustrationView: View {
    let muscleProgress: [MuscleLevel]
    
    var body: some View {
        HStack(spacing: 40) {
            // Front view
            VStack {
                Text("Framsida")
                    .font(.system(size: 16, weight: .medium))
                    .foregroundColor(.gray)
                    .padding(.bottom, 8)
                
                ImprovedFrontBodyView(muscleProgress: muscleProgress)
                    .frame(width: 140, height: 320)
            }
            
            // Back view
            VStack {
                Text("Baksida")
                    .font(.system(size: 16, weight: .medium))
                    .foregroundColor(.gray)
                    .padding(.bottom, 8)
                
                ImprovedBackBodyView(muscleProgress: muscleProgress)
                    .frame(width: 140, height: 320)
            }
        }
    }
}

struct FrontBodyView: View {
    let muscleProgress: [MuscleLevel]
    
    var body: some View {
        GeometryReader { geo in
            ZStack {
                let w = geo.size.width
                let h = geo.size.height
                
                // Bröst (Chest)
                Path { path in
                    path.move(to: CGPoint(x: w * 0.35, y: h * 0.18))
                    path.addLine(to: CGPoint(x: w * 0.65, y: h * 0.18))
                    path.addLine(to: CGPoint(x: w * 0.6, y: h * 0.32))
                    path.addLine(to: CGPoint(x: w * 0.4, y: h * 0.32))
                    path.closeSubpath()
                }
                .fill(colorForMuscle("Bröst"))
                .overlay(
                    Path { path in
                        path.move(to: CGPoint(x: w * 0.35, y: h * 0.18))
                        path.addLine(to: CGPoint(x: w * 0.65, y: h * 0.18))
                        path.addLine(to: CGPoint(x: w * 0.6, y: h * 0.32))
                        path.addLine(to: CGPoint(x: w * 0.4, y: h * 0.32))
                        path.closeSubpath()
                    }
                    .stroke(Color.white.opacity(0.4), lineWidth: 1.5)
                )
                
                // Mage (Abs)
                Path { path in
                    path.move(to: CGPoint(x: w * 0.4, y: h * 0.34))
                    path.addLine(to: CGPoint(x: w * 0.6, y: h * 0.34))
                    path.addLine(to: CGPoint(x: w * 0.58, y: h * 0.52))
                    path.addLine(to: CGPoint(x: w * 0.42, y: h * 0.52))
                    path.closeSubpath()
                }
                .fill(colorForMuscle("Mage"))
                .overlay(
                    Path { path in
                        path.move(to: CGPoint(x: w * 0.4, y: h * 0.34))
                        path.addLine(to: CGPoint(x: w * 0.6, y: h * 0.34))
                        path.addLine(to: CGPoint(x: w * 0.58, y: h * 0.52))
                        path.addLine(to: CGPoint(x: w * 0.42, y: h * 0.52))
                        path.closeSubpath()
                    }
                    .stroke(Color.white.opacity(0.4), lineWidth: 1.5)
                )
                
                // Axlar (Shoulders)
                Path { path in
                    // Vänster axel
                    path.addEllipse(in: CGRect(x: w * 0.15, y: h * 0.15, width: w * 0.2, height: h * 0.08))
                    // Höger axel
                    path.addEllipse(in: CGRect(x: w * 0.65, y: h * 0.15, width: w * 0.2, height: h * 0.08))
                }
                .fill(colorForMuscle("Axlar"))
                .overlay(
                    Path { path in
                        path.addEllipse(in: CGRect(x: w * 0.15, y: h * 0.15, width: w * 0.2, height: h * 0.08))
                        path.addEllipse(in: CGRect(x: w * 0.65, y: h * 0.15, width: w * 0.2, height: h * 0.08))
                    }
                    .stroke(Color.white.opacity(0.4), lineWidth: 1.5)
                )
                
                // Biceps
                Path { path in
                    // Vänster bicep
                    path.move(to: CGPoint(x: w * 0.18, y: h * 0.24))
                    path.addLine(to: CGPoint(x: w * 0.28, y: h * 0.24))
                    path.addLine(to: CGPoint(x: w * 0.26, y: h * 0.38))
                    path.addLine(to: CGPoint(x: w * 0.16, y: h * 0.38))
                    path.closeSubpath()
                    
                    // Höger bicep
                    path.move(to: CGPoint(x: w * 0.72, y: h * 0.24))
                    path.addLine(to: CGPoint(x: w * 0.82, y: h * 0.24))
                    path.addLine(to: CGPoint(x: w * 0.84, y: h * 0.38))
                    path.addLine(to: CGPoint(x: w * 0.74, y: h * 0.38))
                    path.closeSubpath()
                }
                .fill(colorForMuscle("Biceps"))
                .overlay(
                    Path { path in
                        path.move(to: CGPoint(x: w * 0.18, y: h * 0.24))
                        path.addLine(to: CGPoint(x: w * 0.28, y: h * 0.24))
                        path.addLine(to: CGPoint(x: w * 0.26, y: h * 0.38))
                        path.addLine(to: CGPoint(x: w * 0.16, y: h * 0.38))
                        path.closeSubpath()
                        
                        path.move(to: CGPoint(x: w * 0.72, y: h * 0.24))
                        path.addLine(to: CGPoint(x: w * 0.82, y: h * 0.24))
                        path.addLine(to: CGPoint(x: w * 0.84, y: h * 0.38))
                        path.addLine(to: CGPoint(x: w * 0.74, y: h * 0.38))
                        path.closeSubpath()
                    }
                    .stroke(Color.white.opacity(0.4), lineWidth: 1.5)
                )
                
                // Ben (Legs/Quads)
                Path { path in
                    // Vänster ben
                    path.move(to: CGPoint(x: w * 0.32, y: h * 0.54))
                    path.addLine(to: CGPoint(x: w * 0.46, y: h * 0.54))
                    path.addLine(to: CGPoint(x: w * 0.44, y: h * 0.82))
                    path.addLine(to: CGPoint(x: w * 0.34, y: h * 0.82))
                    path.closeSubpath()
                    
                    // Höger ben
                    path.move(to: CGPoint(x: w * 0.54, y: h * 0.54))
                    path.addLine(to: CGPoint(x: w * 0.68, y: h * 0.54))
                    path.addLine(to: CGPoint(x: w * 0.66, y: h * 0.82))
                    path.addLine(to: CGPoint(x: w * 0.56, y: h * 0.82))
                    path.closeSubpath()
                }
                .fill(colorForMuscle("Ben"))
                .overlay(
                    Path { path in
                        path.move(to: CGPoint(x: w * 0.32, y: h * 0.54))
                        path.addLine(to: CGPoint(x: w * 0.46, y: h * 0.54))
                        path.addLine(to: CGPoint(x: w * 0.44, y: h * 0.82))
                        path.addLine(to: CGPoint(x: w * 0.34, y: h * 0.82))
                        path.closeSubpath()
                        
                        path.move(to: CGPoint(x: w * 0.54, y: h * 0.54))
                        path.addLine(to: CGPoint(x: w * 0.68, y: h * 0.54))
                        path.addLine(to: CGPoint(x: w * 0.66, y: h * 0.82))
                        path.addLine(to: CGPoint(x: w * 0.56, y: h * 0.82))
                        path.closeSubpath()
                    }
                    .stroke(Color.white.opacity(0.4), lineWidth: 1.5)
                )
                
                // Vader (Calves)
                Path { path in
                    // Vänster vad
                    path.move(to: CGPoint(x: w * 0.34, y: h * 0.84))
                    path.addLine(to: CGPoint(x: w * 0.44, y: h * 0.84))
                    path.addLine(to: CGPoint(x: w * 0.42, y: h * 0.96))
                    path.addLine(to: CGPoint(x: w * 0.36, y: h * 0.96))
                    path.closeSubpath()
                    
                    // Höger vad
                    path.move(to: CGPoint(x: w * 0.56, y: h * 0.84))
                    path.addLine(to: CGPoint(x: w * 0.66, y: h * 0.84))
                    path.addLine(to: CGPoint(x: w * 0.64, y: h * 0.96))
                    path.addLine(to: CGPoint(x: w * 0.58, y: h * 0.96))
                    path.closeSubpath()
                }
                .fill(colorForMuscle("Vader"))
                .overlay(
                    Path { path in
                        path.move(to: CGPoint(x: w * 0.34, y: h * 0.84))
                        path.addLine(to: CGPoint(x: w * 0.44, y: h * 0.84))
                        path.addLine(to: CGPoint(x: w * 0.42, y: h * 0.96))
                        path.addLine(to: CGPoint(x: w * 0.36, y: h * 0.96))
                        path.closeSubpath()
                        
                        path.move(to: CGPoint(x: w * 0.56, y: h * 0.84))
                        path.addLine(to: CGPoint(x: w * 0.66, y: h * 0.84))
                        path.addLine(to: CGPoint(x: w * 0.64, y: h * 0.96))
                        path.addLine(to: CGPoint(x: w * 0.58, y: h * 0.96))
                        path.closeSubpath()
                    }
                    .stroke(Color.white.opacity(0.4), lineWidth: 1.5)
                )
                
                // Huvud (outline)
                Circle()
                    .stroke(Color.white.opacity(0.4), lineWidth: 2)
                    .frame(width: w * 0.2, height: w * 0.2)
                    .position(x: w * 0.5, y: h * 0.08)
            }
        }
    }
    
    private func colorForMuscle(_ muscleName: String) -> Color {
        if let muscle = muscleProgress.first(where: { $0.muscleGroup == muscleName }) {
            return Color(red: muscle.color.red, green: muscle.color.green, blue: muscle.color.blue)
        }
        return Color.gray.opacity(0.3)
    }
}

struct BackBodyView: View {
    let muscleProgress: [MuscleLevel]
    
    var body: some View {
        GeometryReader { geo in
            ZStack {
                let w = geo.size.width
                let h = geo.size.height
                
                // Rygg (Back)
                Path { path in
                    path.move(to: CGPoint(x: w * 0.35, y: h * 0.18))
                    path.addLine(to: CGPoint(x: w * 0.65, y: h * 0.18))
                    path.addLine(to: CGPoint(x: w * 0.6, y: h * 0.42))
                    path.addLine(to: CGPoint(x: w * 0.4, y: h * 0.42))
                    path.closeSubpath()
                }
                .fill(colorForMuscle("Rygg"))
                .overlay(
                    Path { path in
                        path.move(to: CGPoint(x: w * 0.35, y: h * 0.18))
                        path.addLine(to: CGPoint(x: w * 0.65, y: h * 0.18))
                        path.addLine(to: CGPoint(x: w * 0.6, y: h * 0.42))
                        path.addLine(to: CGPoint(x: w * 0.4, y: h * 0.42))
                        path.closeSubpath()
                    }
                    .stroke(Color.white.opacity(0.4), lineWidth: 1.5)
                )
                
                // Axlar (Shoulders baksida)
                Path { path in
                    path.addEllipse(in: CGRect(x: w * 0.15, y: h * 0.15, width: w * 0.2, height: h * 0.08))
                    path.addEllipse(in: CGRect(x: w * 0.65, y: h * 0.15, width: w * 0.2, height: h * 0.08))
                }
                .fill(colorForMuscle("Axlar"))
                .overlay(
                    Path { path in
                        path.addEllipse(in: CGRect(x: w * 0.15, y: h * 0.15, width: w * 0.2, height: h * 0.08))
                        path.addEllipse(in: CGRect(x: w * 0.65, y: h * 0.15, width: w * 0.2, height: h * 0.08))
                    }
                    .stroke(Color.white.opacity(0.4), lineWidth: 1.5)
                )
                
                // Triceps
                Path { path in
                    // Vänster tricep
                    path.move(to: CGPoint(x: w * 0.18, y: h * 0.24))
                    path.addLine(to: CGPoint(x: w * 0.28, y: h * 0.24))
                    path.addLine(to: CGPoint(x: w * 0.26, y: h * 0.38))
                    path.addLine(to: CGPoint(x: w * 0.16, y: h * 0.38))
                    path.closeSubpath()
                    
                    // Höger tricep
                    path.move(to: CGPoint(x: w * 0.72, y: h * 0.24))
                    path.addLine(to: CGPoint(x: w * 0.82, y: h * 0.24))
                    path.addLine(to: CGPoint(x: w * 0.84, y: h * 0.38))
                    path.addLine(to: CGPoint(x: w * 0.74, y: h * 0.38))
                    path.closeSubpath()
                }
                .fill(colorForMuscle("Triceps"))
                .overlay(
                    Path { path in
                        path.move(to: CGPoint(x: w * 0.18, y: h * 0.24))
                        path.addLine(to: CGPoint(x: w * 0.28, y: h * 0.24))
                        path.addLine(to: CGPoint(x: w * 0.26, y: h * 0.38))
                        path.addLine(to: CGPoint(x: w * 0.16, y: h * 0.38))
                        path.closeSubpath()
                        
                        path.move(to: CGPoint(x: w * 0.72, y: h * 0.24))
                        path.addLine(to: CGPoint(x: w * 0.82, y: h * 0.24))
                        path.addLine(to: CGPoint(x: w * 0.84, y: h * 0.38))
                        path.addLine(to: CGPoint(x: w * 0.74, y: h * 0.38))
                        path.closeSubpath()
                    }
                    .stroke(Color.white.opacity(0.4), lineWidth: 1.5)
                )
                
                // Rumpa (Glutes)
                Path { path in
                    path.move(to: CGPoint(x: w * 0.38, y: h * 0.44))
                    path.addLine(to: CGPoint(x: w * 0.62, y: h * 0.44))
                    path.addLine(to: CGPoint(x: w * 0.6, y: h * 0.54))
                    path.addLine(to: CGPoint(x: w * 0.4, y: h * 0.54))
                    path.closeSubpath()
                }
                .fill(colorForMuscle("Rumpa"))
                .overlay(
                    Path { path in
                        path.move(to: CGPoint(x: w * 0.38, y: h * 0.44))
                        path.addLine(to: CGPoint(x: w * 0.62, y: h * 0.44))
                        path.addLine(to: CGPoint(x: w * 0.6, y: h * 0.54))
                        path.addLine(to: CGPoint(x: w * 0.4, y: h * 0.54))
                        path.closeSubpath()
                    }
                    .stroke(Color.white.opacity(0.4), lineWidth: 1.5)
                )
                
                // Ben (Hamstrings baksida)
                Path { path in
                    // Vänster ben
                    path.move(to: CGPoint(x: w * 0.32, y: h * 0.56))
                    path.addLine(to: CGPoint(x: w * 0.46, y: h * 0.56))
                    path.addLine(to: CGPoint(x: w * 0.44, y: h * 0.82))
                    path.addLine(to: CGPoint(x: w * 0.34, y: h * 0.82))
                    path.closeSubpath()
                    
                    // Höger ben
                    path.move(to: CGPoint(x: w * 0.54, y: h * 0.56))
                    path.addLine(to: CGPoint(x: w * 0.68, y: h * 0.56))
                    path.addLine(to: CGPoint(x: w * 0.66, y: h * 0.82))
                    path.addLine(to: CGPoint(x: w * 0.56, y: h * 0.82))
                    path.closeSubpath()
                }
                .fill(colorForMuscle("Ben"))
                .overlay(
                    Path { path in
                        path.move(to: CGPoint(x: w * 0.32, y: h * 0.56))
                        path.addLine(to: CGPoint(x: w * 0.46, y: h * 0.56))
                        path.addLine(to: CGPoint(x: w * 0.44, y: h * 0.82))
                        path.addLine(to: CGPoint(x: w * 0.34, y: h * 0.82))
                        path.closeSubpath()
                        
                        path.move(to: CGPoint(x: w * 0.54, y: h * 0.56))
                        path.addLine(to: CGPoint(x: w * 0.68, y: h * 0.56))
                        path.addLine(to: CGPoint(x: w * 0.66, y: h * 0.82))
                        path.addLine(to: CGPoint(x: w * 0.56, y: h * 0.82))
                        path.closeSubpath()
                    }
                    .stroke(Color.white.opacity(0.4), lineWidth: 1.5)
                )
                
                // Vader (Calves baksida)
                Path { path in
                    // Vänster vad
                    path.move(to: CGPoint(x: w * 0.34, y: h * 0.84))
                    path.addLine(to: CGPoint(x: w * 0.44, y: h * 0.84))
                    path.addLine(to: CGPoint(x: w * 0.42, y: h * 0.96))
                    path.addLine(to: CGPoint(x: w * 0.36, y: h * 0.96))
                    path.closeSubpath()
                    
                    // Höger vad
                    path.move(to: CGPoint(x: w * 0.56, y: h * 0.84))
                    path.addLine(to: CGPoint(x: w * 0.66, y: h * 0.84))
                    path.addLine(to: CGPoint(x: w * 0.64, y: h * 0.96))
                    path.addLine(to: CGPoint(x: w * 0.58, y: h * 0.96))
                    path.closeSubpath()
                }
                .fill(colorForMuscle("Vader"))
                .overlay(
                    Path { path in
                        path.move(to: CGPoint(x: w * 0.34, y: h * 0.84))
                        path.addLine(to: CGPoint(x: w * 0.44, y: h * 0.84))
                        path.addLine(to: CGPoint(x: w * 0.42, y: h * 0.96))
                        path.addLine(to: CGPoint(x: w * 0.36, y: h * 0.96))
                        path.closeSubpath()
                        
                        path.move(to: CGPoint(x: w * 0.56, y: h * 0.84))
                        path.addLine(to: CGPoint(x: w * 0.66, y: h * 0.84))
                        path.addLine(to: CGPoint(x: w * 0.64, y: h * 0.96))
                        path.addLine(to: CGPoint(x: w * 0.58, y: h * 0.96))
                        path.closeSubpath()
                    }
                    .stroke(Color.white.opacity(0.4), lineWidth: 1.5)
                )
                
                // Huvud (outline)
                Circle()
                    .stroke(Color.white.opacity(0.4), lineWidth: 2)
                    .frame(width: w * 0.2, height: w * 0.2)
                    .position(x: w * 0.5, y: h * 0.08)
            }
        }
    }
    
    private func colorForMuscle(_ muscleName: String) -> Color {
        if let muscle = muscleProgress.first(where: { $0.muscleGroup == muscleName }) {
            return Color(red: muscle.color.red, green: muscle.color.green, blue: muscle.color.blue)
        }
        return Color.gray.opacity(0.3)
    }
}

