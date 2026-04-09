import SwiftUI

struct CaloriesContainerView: View {
    @EnvironmentObject var authViewModel: AuthViewModel
    let popToRootTrigger: Int
    @State private var navigationPath = NavigationPath()

    var body: some View {
        NavigationStack(path: $navigationPath) {
            VStack(spacing: 0) {
                StravaStyleHeaderView(pageTitle: L.t(sv: "Kalorier", nb: "Kalorier"))

                HomeView(embedded: true)
                    .environmentObject(authViewModel)
            }
            .navigationBarTitleDisplayMode(.inline)
            .toolbar(.hidden, for: .navigationBar)
        }
        .id(popToRootTrigger)
        .onChange(of: popToRootTrigger) { _, _ in
            navigationPath = NavigationPath()
        }
    }
}
