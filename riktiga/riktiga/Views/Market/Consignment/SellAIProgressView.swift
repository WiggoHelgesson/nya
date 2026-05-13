import Combine
import SwiftUI

/// Fullskärms-laddning med sporttema: ärlig indeterminate-feedback + shimmer (ingen fejkad procentsats).
struct SellAIProgressView: View {
    enum Phase: Equatable {
        case category
        case copyWriting

        var title: String {
            switch self {
            case .category:
                return L.t(sv: "Varan placeras i en kategori…", nb: "Varen plasseres i en kategori …")
            case .copyWriting:
                return L.t(sv: "Beskrivning skapas", nb: "Beskrivelse lages")
            }
        }

        var subtitle: String {
            switch self {
            case .category:
                return L.t(
                    sv: "Vi analyserar dina bilder och väljer rätt sportkategori.",
                    nb: "Vi analyserer bildene dine og velger riktig sportkategori."
                )
            case .copyWriting:
                return L.t(
                    sv: "Baserat på bilderna och vald kategori skapas nu rubrik och beskrivning.",
                    nb: "Basert på bildene og valgt kategori lages nå tittel og beskrivelse."
                )
            }
        }

        var iconName: String {
            switch self {
            case .category: return "figure.run"
            case .copyWriting: return "figure.strengthtraining.traditional"
            }
        }

        var rotatingHints: [String] {
            switch self {
            case .category:
                return [
                    L.t(sv: "Läser dina bilder…", nb: "Leser bildene dine …"),
                    L.t(sv: "Jämför med sportkategorier…", nb: "Sammenligner med sportkategorier …"),
                    L.t(sv: "Snart klart …", nb: "Snart ferdig …")
                ]
            case .copyWriting:
                return [
                    L.t(sv: "Formulerar rubrik…", nb: "Formulerer tittel …"),
                    L.t(sv: "Skriver beskrivning…", nb: "Skriver beskrivelse …"),
                    L.t(sv: "Finputsar ton och detaljer…", nb: "Finpusser tone og detaljer …")
                ]
            }
        }
    }

    let phase: Phase

    @State private var stepIndex = 0
    @State private var legacyPulse = false

    private let hintTick = Timer.publish(every: 2.35, on: .main, in: .common).autoconnect()

    var body: some View {
        VStack(spacing: 24) {
            Spacer(minLength: 28)

            phaseIcon

            ProgressView()
                .controlSize(.large)
                .tint(.primary)

            SellShimmerProgressTrack()

            Text(phase.title)
                .font(.system(size: 22, weight: .bold))
                .multilineTextAlignment(.center)
                .padding(.horizontal, 24)

            Text(currentHint)
                .font(.system(size: 15, weight: .medium))
                .foregroundStyle(.secondary)
                .multilineTextAlignment(.center)
                .padding(.horizontal, 28)
                .animation(.easeInOut(duration: 0.35), value: stepIndex)
                .accessibilityLabel(currentHint)

            Text(phase.subtitle)
                .font(.system(size: 14))
                .foregroundStyle(.tertiary)
                .multilineTextAlignment(.center)
                .padding(.horizontal, 32)

            Spacer(minLength: 48)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background(Color(.systemBackground))
        .onAppear {
            stepIndex = 0
            legacyPulse = false
            if #available(iOS 17.0, *) {
                return
            }
            legacyPulse = true
        }
        .onChange(of: phase) { _, _ in
            stepIndex = 0
        }
        .onReceive(hintTick) { _ in
            let n = phase.rotatingHints.count
            guard n > 0 else { return }
            stepIndex = (stepIndex + 1) % n
        }
    }

    private var currentHint: String {
        let hints = phase.rotatingHints
        guard !hints.isEmpty else { return "" }
        return hints[stepIndex % hints.count]
    }

    @ViewBuilder
    private var phaseIcon: some View {
        ZStack {
            Capsule()
                .fill(Color.black.opacity(0.06))
                .frame(width: 168, height: 92)

            if #available(iOS 17.0, *) {
                Image(systemName: phase.iconName)
                    .font(.system(size: 56, weight: .light))
                    .foregroundStyle(.primary)
                    .symbolEffect(.pulse, options: .repeating)
            } else {
                Image(systemName: phase.iconName)
                    .font(.system(size: 56, weight: .light))
                    .foregroundStyle(.primary)
                    .scaleEffect(legacyPulse ? 1.06 : 1.0)
                    .animation(.easeInOut(duration: 1.1).repeatForever(autoreverses: true), value: legacyPulse)
            }
        }
    }
}

// MARK: - Shimmer track

private struct SellShimmerProgressTrack: View {
    var body: some View {
        GeometryReader { geo in
            let width = geo.size.width
            TimelineView(.animation(minimumInterval: 1.0 / 50.0, paused: false)) { context in
                let t = context.date.timeIntervalSinceReferenceDate
                let period = 1.85
                let phase = t.truncatingRemainder(dividingBy: period) / period
                let travel = phase * (width + 100)
                ZStack(alignment: .leading) {
                    Capsule()
                        .fill(Color(.systemGray5))
                    LinearGradient(
                        colors: [
                            Color.clear,
                            Color.primary.opacity(0.28),
                            Color.clear
                        ],
                        startPoint: .leading,
                        endPoint: .trailing
                    )
                    .frame(width: min(160, width * 0.42))
                    .offset(x: travel - 80)
                }
                .clipShape(Capsule())
            }
        }
        .frame(height: 8)
        .padding(.horizontal, 40)
        .accessibilityHidden(true)
    }
}
