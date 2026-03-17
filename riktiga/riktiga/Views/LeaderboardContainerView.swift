import SwiftUI

struct LeaderboardContainerView: View {
    @EnvironmentObject var authViewModel: AuthViewModel
    let popToRootTrigger: Int
    @State private var navigationPath = NavigationPath()

    var body: some View {
        NavigationStack(path: $navigationPath) {
            LeaderboardView()
                .environmentObject(authViewModel)
                .navigationBarTitleDisplayMode(.inline)
                .toolbar(.hidden, for: .navigationBar)
                .navigationDestination(for: LeaderboardCategory.self) { category in
                    LeaderboardDetailView(category: category)
                        .environmentObject(authViewModel)
                }
                .navigationDestination(for: String.self) { destination in
                    if destination == "schoolBattle" {
                        SchoolBattleView()
                            .environmentObject(authViewModel)
                    }
                }
        }
        .id(popToRootTrigger)
        .onChange(of: popToRootTrigger) { _, _ in
            navigationPath = NavigationPath()
        }
    }
}
