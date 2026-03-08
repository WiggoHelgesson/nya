import SwiftUI

struct IntelligenceView: View {
    @Environment(\.dismiss) private var dismiss
    
    private let gradientColors: [Color] = [
        Color(red: 0.95, green: 0.55, blue: 0.65),
        Color(red: 0.98, green: 0.65, blue: 0.45),
        Color(red: 0.98, green: 0.85, blue: 0.45),
        Color(red: 0.55, green: 0.85, blue: 0.55),
        Color(red: 0.45, green: 0.70, blue: 0.95),
    ]
    
    var body: some View {
        ZStack {
            backgroundGradient
            
            VStack(spacing: 0) {
                closeButton
                
                Spacer().frame(height: 20)
                
                previewBadge
                
                Spacer().frame(height: 24)
                
                titleSection
                
                Spacer().frame(height: 32)
                
                featureList
                
                Spacer()
                
                continueButton
                
                footerLinks
            }
            .padding(.horizontal, 28)
            .padding(.top, 16)
            .padding(.bottom, 20)
        }
    }
    
    // MARK: - Background
    
    private var backgroundGradient: some View {
        VStack {
            Spacer()
            LinearGradient(
                colors: [
                    Color.clear,
                    Color(red: 1.0, green: 0.97, blue: 0.88).opacity(0.5),
                    Color(red: 1.0, green: 0.95, blue: 0.82).opacity(0.4),
                ],
                startPoint: .top,
                endPoint: .bottom
            )
            .frame(height: 350)
        }
        .ignoresSafeArea()
    }
    
    // MARK: - Close Button
    
    private var closeButton: some View {
        HStack {
            Button {
                dismiss()
            } label: {
                Image(systemName: "xmark")
                    .font(.system(size: 15, weight: .medium))
                    .foregroundColor(.secondary)
                    .frame(width: 30, height: 30)
                    .background(Color(.systemGray6))
                    .clipShape(Circle())
            }
            Spacer()
        }
    }
    
    // MARK: - Preview Badge
    
    private var previewBadge: some View {
        HStack(spacing: 6) {
            Image(systemName: "cube.fill")
                .font(.system(size: 11, weight: .medium))
            Text(L.t(sv: "Förhandsvisning", nb: "Forhåndsvisning"))
                .font(.system(size: 13, weight: .semibold))
        }
        .foregroundColor(.secondary)
        .padding(.horizontal, 14)
        .padding(.vertical, 7)
        .background(
            Capsule()
                .fill(Color(.systemGray6))
        )
    }
    
    // MARK: - Title
    
    private var titleSection: some View {
        VStack(spacing: 14) {
            Text(L.t(sv: "Intelligens", nb: "Intelligens"))
                .font(.system(size: 48, weight: .bold, design: .rounded))
                .overlay(
                    LinearGradient(
                        colors: gradientColors,
                        startPoint: .leading,
                        endPoint: .trailing
                    )
                )
                .mask(
                    Text(L.t(sv: "Intelligens", nb: "Intelligens"))
                        .font(.system(size: 48, weight: .bold, design: .rounded))
                )
            
            Text(L.t(sv: "Lås upp alla Intelligens-funktioner\nmed Up&Down Pro.", nb: "Lås opp alle Intelligens-funksjoner\nmed Up&Down Pro."))
                .font(.system(size: 15, weight: .regular))
                .foregroundColor(.secondary)
                .multilineTextAlignment(.center)
                .lineSpacing(3)
        }
    }
    
    // MARK: - Features
    
    private var featureList: some View {
        VStack(spacing: 24) {
            featureRow(
                icon: "bubble.left.fill",
                iconColor: Color(red: 0.30, green: 0.55, blue: 0.95),
                iconBg: Color(red: 0.30, green: 0.55, blue: 0.95).opacity(0.12),
                title: L.t(sv: "Daglig Vägledning", nb: "Daglig Veiledning"),
                description: L.t(sv: "Utforska din hälsa genom konversation", nb: "Utforsk helsen din gjennom samtale")
            )
            
            featureRow(
                icon: "bolt.fill",
                iconColor: Color(red: 0.92, green: 0.35, blue: 0.35),
                iconBg: Color(red: 0.92, green: 0.35, blue: 0.35).opacity(0.12),
                title: L.t(sv: "Smarta Förslag", nb: "Smarte Forslag"),
                description: L.t(sv: "Personlig feedback över alla aktiviteter", nb: "Personlig tilbakemelding over alle aktiviteter")
            )
            
            featureRow(
                icon: "circle.grid.2x2.fill",
                iconColor: Color(red: 0.55, green: 0.40, blue: 0.85),
                iconBg: Color(red: 0.55, green: 0.40, blue: 0.85).opacity(0.12),
                title: L.t(sv: "Inbyggt Minne", nb: "Innebygd Minne"),
                description: L.t(sv: "Vägledning som lär sig från tidigare interaktioner", nb: "Veiledning som lærer av tidligere interaksjoner")
            )
        }
        .padding(.horizontal, 4)
    }
    
    private func featureRow(icon: String, iconColor: Color, iconBg: Color, title: String, description: String) -> some View {
        HStack(spacing: 16) {
            Image(systemName: icon)
                .font(.system(size: 18))
                .foregroundColor(iconColor)
                .frame(width: 44, height: 44)
                .background(iconBg)
                .clipShape(RoundedRectangle(cornerRadius: 12, style: .continuous))
            
            VStack(alignment: .leading, spacing: 3) {
                Text(title)
                    .font(.system(size: 16, weight: .semibold))
                    .foregroundColor(.primary)
                
                Text(description)
                    .font(.system(size: 14, weight: .regular))
                    .foregroundColor(.secondary)
            }
            
            Spacer()
        }
    }
    
    // MARK: - Continue Button
    
    private var continueButton: some View {
        Button {
            dismiss()
        } label: {
            Text(L.t(sv: "Fortsätt", nb: "Fortsett"))
                .font(.system(size: 17, weight: .semibold))
                .foregroundColor(.white)
                .frame(maxWidth: .infinity)
                .frame(height: 54)
                .background(Color.black)
                .cornerRadius(16)
        }
        .padding(.bottom, 12)
    }
    
    // MARK: - Footer
    
    private var footerLinks: some View {
        HStack(spacing: 24) {
            Button(L.t(sv: "Återställ köp", nb: "Gjenopprett kjøp")) {
                // TODO: restore purchases
            }
            .font(.system(size: 13, weight: .medium))
            .foregroundColor(.secondary)
            
            Button(L.t(sv: "Lös in kod", nb: "Løs inn kode")) {
                // TODO: redeem code
            }
            .font(.system(size: 13, weight: .medium))
            .foregroundColor(.secondary)
        }
        .padding(.bottom, 4)
    }
}

#Preview {
    IntelligenceView()
}
