import SwiftUI

struct ProWelcomeView: View {
    @Environment(\.dismiss) private var dismiss
    var onDismiss: (() -> Void)? = nil
    
    // Animation states
    @State private var showBackground = false
    @State private var showLogo = false
    @State private var showTitle = false
    @State private var showSubtitle = false
    @State private var showButton = false
    @State private var showParticles = false
    @State private var logoScale: CGFloat = 0.3
    @State private var logoRotation: Double = -30
    
    var body: some View {
        ZStack {
            // MARK: - Animated Background
            backgroundGradient
            
            // MARK: - Particle Effects
            if showParticles {
                ProParticleView()
                    .opacity(0.6)
            }
            
            // MARK: - Content
            VStack(spacing: 0) {
                Spacer()
                
                // Logo with glow
                ZStack {
                    // Outer glow
                    Circle()
                        .fill(
                            RadialGradient(
                                colors: [
                                    Color.white.opacity(0.3),
                                    Color.white.opacity(0.1),
                                    Color.clear
                                ],
                                center: .center,
                                startRadius: 40,
                                endRadius: 120
                            )
                        )
                        .frame(width: 240, height: 240)
                        .blur(radius: 20)
                        .opacity(showLogo ? 1 : 0)
                    
                    // Logo container
                    ZStack {
                        // Silver ring
                        Circle()
                            .stroke(
                                LinearGradient(
                                    colors: [
                                        Color(hex: "E8E8E8"),
                                        Color(hex: "B8B8B8"),
                                        Color(hex: "D0D0D0"),
                                        Color(hex: "A0A0A0")
                                    ],
                                    startPoint: .topLeading,
                                    endPoint: .bottomTrailing
                                ),
                                lineWidth: 3
                            )
                            .frame(width: 140, height: 140)
                        
                        // Inner dark circle
                        Circle()
                            .fill(
                                LinearGradient(
                                    colors: [
                                        Color(hex: "2A2A2A"),
                                        Color(hex: "1A1A1A")
                                    ],
                                    startPoint: .topLeading,
                                    endPoint: .bottomTrailing
                                )
                            )
                            .frame(width: 130, height: 130)
                        
                        // App logo
                        Image("23")
                            .resizable()
                            .scaledToFit()
                            .frame(width: 80, height: 80)
                            .cornerRadius(16)
                    }
                    .scaleEffect(logoScale)
                    .rotationEffect(.degrees(logoRotation))
                }
                .padding(.bottom, 40)
                
                // Title
                Text("Välkommen!")
                    .font(.system(size: 42, weight: .bold, design: .rounded))
                    .foregroundStyle(
                        LinearGradient(
                            colors: [
                                Color.white,
                                Color(hex: "E0E0E0")
                            ],
                            startPoint: .top,
                            endPoint: .bottom
                        )
                    )
                    .opacity(showTitle ? 1 : 0)
                    .offset(y: showTitle ? 0 : 20)
                    .padding(.bottom, 12)
                
                // Subtitle
                Text("Du är nu Pro-medlem")
                    .font(.system(size: 18, weight: .medium))
                    .foregroundColor(Color(hex: "A0A0A0"))
                    .opacity(showSubtitle ? 1 : 0)
                    .offset(y: showSubtitle ? 0 : 15)
                
                Spacer()
                
                // Button
                Button {
                    hapticFeedback()
                    withAnimation(.easeOut(duration: 0.3)) {
                        showBackground = false
                        showLogo = false
                        showTitle = false
                        showSubtitle = false
                        showButton = false
                    }
                    DispatchQueue.main.asyncAfter(deadline: .now() + 0.3) {
                        onDismiss?()
                        dismiss()
                    }
                } label: {
                    HStack(spacing: 10) {
                        Text("Kom igång")
                            .font(.system(size: 18, weight: .semibold))
                        
                        Image(systemName: "arrow.right")
                            .font(.system(size: 16, weight: .semibold))
                    }
                    .foregroundColor(.black)
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 18)
                    .background(
                        LinearGradient(
                            colors: [
                                Color.white,
                                Color(hex: "E8E8E8")
                            ],
                            startPoint: .top,
                            endPoint: .bottom
                        )
                    )
                    .cornerRadius(16)
                    .shadow(color: .white.opacity(0.2), radius: 20, x: 0, y: 0)
                }
                .padding(.horizontal, 24)
                .padding(.bottom, 50)
                .opacity(showButton ? 1 : 0)
                .offset(y: showButton ? 0 : 30)
                .scaleEffect(showButton ? 1 : 0.9)
            }
        }
        .onAppear {
            startAnimations()
        }
    }
    
    // MARK: - Background Gradient
    private var backgroundGradient: some View {
        ZStack {
            // Base black
            Color.black
            
            // Subtle gradient overlay
            LinearGradient(
                colors: [
                    Color(hex: "1A1A1A"),
                    Color.black,
                    Color(hex: "0D0D0D")
                ],
                startPoint: .top,
                endPoint: .bottom
            )
            
            // Silver/gray accent at top
            RadialGradient(
                colors: [
                    Color(hex: "3A3A3A").opacity(showBackground ? 0.6 : 0),
                    Color.clear
                ],
                center: .top,
                startRadius: 0,
                endRadius: 400
            )
            
            // Subtle silver shimmer
            RadialGradient(
                colors: [
                    Color(hex: "4A4A4A").opacity(showBackground ? 0.3 : 0),
                    Color.clear
                ],
                center: UnitPoint(x: 0.8, y: 0.2),
                startRadius: 0,
                endRadius: 300
            )
        }
        .ignoresSafeArea()
    }
    
    // MARK: - Animations
    private func startAnimations() {
        // Background fade in
        withAnimation(.easeOut(duration: 0.8)) {
            showBackground = true
        }
        
        // Particles
        withAnimation(.easeOut(duration: 0.5).delay(0.2)) {
            showParticles = true
        }
        
        // Logo animation
        withAnimation(.spring(response: 0.8, dampingFraction: 0.6).delay(0.3)) {
            showLogo = true
            logoScale = 1.0
            logoRotation = 0
        }
        
        // Title
        withAnimation(.spring(response: 0.6, dampingFraction: 0.8).delay(0.6)) {
            showTitle = true
        }
        
        // Subtitle and benefits
        withAnimation(.spring(response: 0.6, dampingFraction: 0.8).delay(0.8)) {
            showSubtitle = true
        }
        
        // Button
        withAnimation(.spring(response: 0.6, dampingFraction: 0.7).delay(1.0)) {
            showButton = true
        }
    }
    
    private func hapticFeedback() {
        let generator = UIImpactFeedbackGenerator(style: .medium)
        generator.impactOccurred()
    }
}

// MARK: - Particle View
struct ProParticleView: View {
    @State private var particles: [ProParticle] = []
    
    var body: some View {
        GeometryReader { geo in
            ZStack {
                ForEach(particles) { particle in
                    Circle()
                        .fill(particle.color)
                        .frame(width: particle.size, height: particle.size)
                        .position(particle.position)
                        .opacity(particle.opacity)
                        .blur(radius: particle.size / 4)
                }
            }
            .onAppear {
                createParticles(in: geo.size)
                animateParticles(in: geo.size)
            }
        }
    }
    
    private func createParticles(in size: CGSize) {
        particles = (0..<20).map { _ in
            ProParticle(
                position: CGPoint(
                    x: CGFloat.random(in: 0...size.width),
                    y: CGFloat.random(in: 0...size.height)
                ),
                size: CGFloat.random(in: 2...6),
                opacity: Double.random(in: 0.1...0.4),
                color: [
                    Color.white.opacity(0.5),
                    Color(hex: "C0C0C0").opacity(0.3),
                    Color(hex: "808080").opacity(0.2)
                ].randomElement()!
            )
        }
    }
    
    private func animateParticles(in size: CGSize) {
        Timer.scheduledTimer(withTimeInterval: 0.05, repeats: true) { _ in
            for i in particles.indices {
                withAnimation(.linear(duration: 0.05)) {
                    particles[i].position.y -= CGFloat.random(in: 0.3...1.0)
                    particles[i].position.x += CGFloat.random(in: -0.5...0.5)
                    
                    if particles[i].position.y < -10 {
                        particles[i].position.y = size.height + 10
                        particles[i].position.x = CGFloat.random(in: 0...size.width)
                    }
                }
            }
        }
    }
}

struct ProParticle: Identifiable {
    let id = UUID()
    var position: CGPoint
    var size: CGFloat
    var opacity: Double
    var color: Color
}

#Preview {
    ProWelcomeView()
}

