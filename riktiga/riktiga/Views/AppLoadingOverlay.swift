//
//  AppLoadingOverlay.swift
//  Up&Down
//
//  Full-screen white overlay shown on top of MainTabView right after the
//  splash screen dismisses, while AppLaunchCoordinator warms up the first
//  tab's data. A slowly rotating gear communicates "loading" without the
//  jank of progressive content pop-in.
//

import SwiftUI

struct AppLoadingOverlay: View {
    @State private var isSpinning = false

    var body: some View {
        ZStack {
            Color.white.ignoresSafeArea()

            Image(systemName: "gearshape.fill")
                .font(.system(size: 36, weight: .regular))
                .foregroundStyle(.black.opacity(0.7))
                .rotationEffect(.degrees(isSpinning ? 360 : 0))
                .animation(
                    .linear(duration: 1.2).repeatForever(autoreverses: false),
                    value: isSpinning
                )
        }
        .onAppear { isSpinning = true }
    }
}

/// Simple Strava-style inline spinner: a small gray circular activity
/// indicator, no ring, no breathing — just the standard UIKit-style spokes
/// spinner. Used inline in the feed area while the top nav and bottom tab
/// bar remain visible.
struct FeedLoadingGear: View {
    var body: some View {
        ProgressView()
            .progressViewStyle(.circular)
            .tint(Color.gray)
            .scaleEffect(1.1)
            .accessibilityElement()
            .accessibilityLabel(Text("Laddar"))
    }
}

#Preview {
    AppLoadingOverlay()
}

#Preview("Inline") {
    FeedLoadingGear()
        .frame(maxWidth: .infinity, minHeight: 300)
}
