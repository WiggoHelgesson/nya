import SwiftUI

// MARK: - Achievement Popup View (Duolingo-style)
struct AchievementPopupView: View {
    let achievement: Achievement
    let onDismiss: () -> Void
    
    @Environment(\.colorScheme) private var colorScheme
    
    @State private var showBadge = false
    @State private var showText = false
    @State private var showDetails = false
    @State private var badgeScale: CGFloat = 0.3
    @State private var badgeRotation: Double = -30
    @State private var glowOpacity: Double = 0
    @State private var particlesVisible = false
    
    private var isDarkMode: Bool {
        colorScheme == .dark
    }
    
    private var dateFormatter: DateFormatter {
        let formatter = DateFormatter()
        formatter.dateStyle = .long
        formatter.locale = Locale(identifier: "sv_SE")
        return formatter
    }
    
    var body: some View {
        ZStack {
            // Background - solid black for dark mode, gradient for light mode
            if isDarkMode {
                Color.black
                    .ignoresSafeArea()
            } else {
                LinearGradient(
                    colors: achievement.gradientColors + [Color.white.opacity(0.9)],
                    startPoint: .top,
                    endPoint: .bottom
                )
                .ignoresSafeArea()
            }
            
            // Particle effects
            if particlesVisible {
                ParticleEffectView(color: achievement.category.color)
            }
            
            VStack(spacing: 0) {
                Spacer()
                
                // Badge with glow effect
                ZStack {
                    // Outer glow - brighter in dark mode
                    Circle()
                        .fill(
                            RadialGradient(
                                colors: isDarkMode 
                                    ? [achievement.category.color.opacity(0.5), Color.clear]
                                    : [Color.white.opacity(0.6), Color.clear],
                                center: .center,
                                startRadius: 80,
                                endRadius: 180
                            )
                        )
                        .frame(width: 360, height: 360)
                        .opacity(glowOpacity)
                    
                    // Badge circle
                    ZStack {
                        // Background circle with gradient (uses tier-based colors)
                        Circle()
                            .fill(
                                LinearGradient(
                                    colors: achievement.gradientColors,
                                    startPoint: .topLeading,
                                    endPoint: .bottomTrailing
                                )
                            )
                            .frame(width: 220, height: 220)
                        
                        // Glass overlay effect
                        Circle()
                            .fill(
                                LinearGradient(
                                    colors: [Color.white.opacity(0.4), Color.clear],
                                    startPoint: .topLeading,
                                    endPoint: .bottomTrailing
                                )
                            )
                            .frame(width: 220, height: 220)
                        
                        // Inner decorative circle
                        Circle()
                            .stroke(Color.white.opacity(0.3), lineWidth: 2)
                            .frame(width: 200, height: 200)
                        
                        // Diagonal shine lines
                        DiagonalShineView()
                            .frame(width: 220, height: 220)
                            .clipShape(Circle())
                        
                        // Icon
                        VStack(spacing: 8) {
                            Image(systemName: achievement.icon)
                                .font(.system(size: 70, weight: .medium))
                                .foregroundStyle(
                                    LinearGradient(
                                        colors: [Color.white, Color.white.opacity(0.8)],
                                        startPoint: .top,
                                        endPoint: .bottom
                                    )
                                )
                                .shadow(color: .black.opacity(0.2), radius: 4, x: 0, y: 2)
                            
                            // Requirement number badge
                            Text("\(achievement.requirement)")
                                .font(.system(size: 36, weight: .bold, design: .rounded))
                                .foregroundColor(.white.opacity(0.9))
                                .shadow(color: .black.opacity(0.2), radius: 2, x: 0, y: 1)
                        }
                        
                        // Outer ring
                        Circle()
                            .stroke(
                                LinearGradient(
                                    colors: [Color.white.opacity(0.8), Color.white.opacity(0.3)],
                                    startPoint: .topLeading,
                                    endPoint: .bottomTrailing
                                ),
                                lineWidth: 6
                            )
                            .frame(width: 220, height: 220)
                        
                        // Decorative sparkles around badge
                        SparklesAroundBadge()
                    }
                    .scaleEffect(badgeScale)
                    .rotationEffect(.degrees(badgeRotation))
                }
                .opacity(showBadge ? 1 : 0)
                
                Spacer()
                    .frame(height: 30)
                
                // Text content
                VStack(spacing: 8) {
                    Text("Badge Unlocked")
                        .font(.system(size: 16, weight: .medium))
                        .foregroundColor(isDarkMode ? .white.opacity(0.6) : .black.opacity(0.5))
                    
                    Text(achievement.name)
                        .font(.system(size: 32, weight: .bold, design: .rounded))
                        .foregroundColor(isDarkMode ? .white : .black)
                    
                    Text(achievement.description)
                        .font(.system(size: 18))
                        .foregroundColor(isDarkMode ? .white.opacity(0.7) : .black.opacity(0.6))
                }
                .opacity(showText ? 1 : 0)
                .offset(y: showText ? 0 : 30)
                
                Spacer()
                
                // Bottom details
                VStack(spacing: 8) {
                    HStack(spacing: 6) {
                        Image(systemName: "checkmark")
                            .font(.system(size: 14, weight: .medium))
                            .foregroundColor(isDarkMode ? .white.opacity(0.6) : .black.opacity(0.5))
                        
                        Text("Unlocked on \(dateFormatter.string(from: achievement.unlockedAt ?? Date()))")
                            .font(.system(size: 14))
                            .foregroundColor(isDarkMode ? .white.opacity(0.6) : .black.opacity(0.5))
                    }
                    
                    Text(achievement.motivationalQuote)
                        .font(.system(size: 16, weight: .medium))
                        .foregroundColor(isDarkMode ? .white.opacity(0.8) : .black.opacity(0.7))
                        .multilineTextAlignment(.center)
                        .padding(.horizontal, 40)
                }
                .opacity(showDetails ? 1 : 0)
                .offset(y: showDetails ? 0 : 20)
                .padding(.bottom, 60)
            }
            .padding(.top, 100)
        }
        .onTapGesture {
            dismissWithAnimation()
        }
        .gesture(
            DragGesture(minimumDistance: 50)
                .onEnded { value in
                    if value.translation.height > 100 {
                        dismissWithAnimation()
                    }
                }
        )
        .onAppear {
            startAnimations()
        }
    }
    
    private func startAnimations() {
        // Badge entrance animation
        withAnimation(.spring(response: 0.6, dampingFraction: 0.6)) {
            showBadge = true
            badgeScale = 1.0
            badgeRotation = 0
        }
        
        // Glow pulse
        withAnimation(.easeInOut(duration: 0.8)) {
            glowOpacity = 1
        }
        
        // Particles
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.2) {
            withAnimation {
                particlesVisible = true
            }
        }
        
        // Text animations
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.4) {
            withAnimation(.spring(response: 0.5, dampingFraction: 0.7)) {
                showText = true
            }
        }
        
        // Details animation
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.7) {
            withAnimation(.spring(response: 0.5, dampingFraction: 0.8)) {
                showDetails = true
            }
        }
    }
    
    private func dismissWithAnimation() {
        withAnimation(.spring(response: 0.3, dampingFraction: 0.8)) {
            badgeScale = 0.8
            showBadge = false
            showText = false
            showDetails = false
        }
        
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.25) {
            onDismiss()
        }
    }
}

// MARK: - Diagonal Shine Effect
struct DiagonalShineView: View {
    var body: some View {
        GeometryReader { geometry in
            let width = geometry.size.width
            let height = geometry.size.height
            
            Path { path in
                // First diagonal line
                path.move(to: CGPoint(x: width * 0.2, y: height))
                path.addLine(to: CGPoint(x: width * 0.35, y: 0))
                path.addLine(to: CGPoint(x: width * 0.4, y: 0))
                path.addLine(to: CGPoint(x: width * 0.25, y: height))
                path.closeSubpath()
                
                // Second diagonal line
                path.move(to: CGPoint(x: width * 0.45, y: height))
                path.addLine(to: CGPoint(x: width * 0.6, y: 0))
                path.addLine(to: CGPoint(x: width * 0.65, y: 0))
                path.addLine(to: CGPoint(x: width * 0.5, y: height))
                path.closeSubpath()
            }
            .fill(Color.white.opacity(0.15))
        }
    }
}

// MARK: - Sparkles Around Badge
struct SparklesAroundBadge: View {
    @State private var sparkleOpacity: [Double] = [0.3, 0.5, 0.7, 0.4, 0.6, 0.8]
    @State private var sparkleScale: [CGFloat] = [0.8, 1.0, 0.9, 1.1, 0.85, 0.95]
    
    var body: some View {
        ZStack {
            // Sparkle positions around the badge
            ForEach(0..<6, id: \.self) { index in
                let angle = Double(index) * 60.0 - 30.0
                let radius: CGFloat = 130
                let x = cos(angle * .pi / 180) * radius
                let y = sin(angle * .pi / 180) * radius
                
                Image(systemName: index % 2 == 0 ? "sparkle" : "star.fill")
                    .font(.system(size: index % 2 == 0 ? 16 : 10))
                    .foregroundColor(.white.opacity(sparkleOpacity[index]))
                    .scaleEffect(sparkleScale[index])
                    .offset(x: x, y: y)
            }
        }
        .onAppear {
            // Animate sparkles
            withAnimation(.easeInOut(duration: 1.5).repeatForever(autoreverses: true)) {
                for i in 0..<6 {
                    sparkleOpacity[i] = Double.random(in: 0.5...1.0)
                    sparkleScale[i] = CGFloat.random(in: 0.8...1.2)
                }
            }
        }
    }
}

// MARK: - Particle Effect View
struct ParticleEffectView: View {
    let color: Color
    @State private var particles: [Particle] = []
    
    var body: some View {
        GeometryReader { geometry in
            ForEach(particles) { particle in
                Circle()
                    .fill(particle.color)
                    .frame(width: particle.size, height: particle.size)
                    .position(particle.position)
                    .opacity(particle.opacity)
            }
        }
        .onAppear {
            createParticles()
        }
    }
    
    private func createParticles() {
        let screenWidth = UIScreen.main.bounds.width
        let screenHeight = UIScreen.main.bounds.height
        
        for i in 0..<30 {
            let particle = Particle(
                id: i,
                position: CGPoint(
                    x: CGFloat.random(in: 0...screenWidth),
                    y: CGFloat.random(in: screenHeight * 0.3...screenHeight * 0.7)
                ),
                size: CGFloat.random(in: 4...12),
                color: [color, color.opacity(0.7), .white.opacity(0.6)].randomElement()!,
                opacity: Double.random(in: 0.4...0.9)
            )
            particles.append(particle)
        }
        
        // Animate particles
        for i in 0..<particles.count {
            let delay = Double(i) * 0.03
            
            DispatchQueue.main.asyncAfter(deadline: .now() + delay) {
                withAnimation(.easeOut(duration: Double.random(in: 1.5...3.0))) {
                    if i < particles.count {
                        particles[i].position.y -= CGFloat.random(in: 100...300)
                        particles[i].position.x += CGFloat.random(in: -50...50)
                        particles[i].opacity = 0
                    }
                }
            }
        }
    }
}

struct Particle: Identifiable {
    let id: Int
    var position: CGPoint
    let size: CGFloat
    let color: Color
    var opacity: Double
}

// MARK: - Preview
#Preview {
    AchievementPopupView(
        achievement: Achievement(
            id: "scans_50",
            name: "Locked in",
            description: "50 AI-skanningar",
            icon: "lock.fill",
            category: .meals,
            requirement: 50,
            motivationalQuote: "Ingenting stoppar dig nu! 🔒",
            tier: .diamond,
            unlockedAt: Date()
        ),
        onDismiss: {}
    )
}

