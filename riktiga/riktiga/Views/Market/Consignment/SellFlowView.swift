import SwiftUI

struct SellFlowView: View {
    @EnvironmentObject var authViewModel: AuthViewModel
    var onAbandonFlow: () -> Void

    @StateObject private var model = SellFlowModel()
    @State private var path = NavigationPath()

    var body: some View {
        NavigationStack(path: $path) {
            SellCameraView(model: model, path: $path, onAbandonFlow: onAbandonFlow)
                .navigationDestination(for: SellRoute.self) { route in
                    switch route {
                    case .category:
                        SellCategoryStepView(model: model, path: $path)
                    case .result:
                        SellResultStepView(model: model, path: $path)
                            .environmentObject(authViewModel)
                    }
                }
        }
        .tint(Color.primary)
    }
}
