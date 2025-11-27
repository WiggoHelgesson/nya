import SwiftUI

struct HealthDataDisclosureView: View {
    enum Style {
        case card
        case inline
    }
    
    let title: String
    let description: String
    var style: Style = .card
    var showsManageButton: Bool = false
    var manageAction: (() -> Void)? = nil
    
    @State private var isAuthorized = HealthKitManager.shared.isHealthDataAuthorized()
    @Environment(\.scenePhase) private var scenePhase
    
    var body: some View {
        Group {
            if style == .card {
                content
                    .padding(18)
                    .background(Color.white)
                    .cornerRadius(14)
                    .shadow(color: Color.black.opacity(0.05), radius: 6, x: 0, y: 2)
            } else {
                content
            }
        }
        .accessibilityElement(children: .combine)
        .onAppear {
            refreshAuthorizationState()
        }
        .onChange(of: scenePhase) { newPhase, _ in
            if newPhase == .active {
                refreshAuthorizationState()
            }
        }
    }
    
    @ViewBuilder
    private var content: some View {
        VStack(alignment: .leading, spacing: 14) {
            HStack(alignment: .top, spacing: 14) {
                Image("24")
                    .resizable()
                    .scaledToFit()
                    .frame(width: 34, height: 34)
                    .cornerRadius(6)
                    .accessibilityHidden(true)
                VStack(alignment: .leading, spacing: 6) {
                    Text(title)
                        .font(.system(size: 15, weight: .semibold))
                        .foregroundColor(.black)
                    Text(description)
                        .font(.system(size: 13))
                        .foregroundColor(.gray)
                        .fixedSize(horizontal: false, vertical: true)
                }
            }
            
            if showsManageButton {
                Button(action: handleManageButtonTap) {
                    HStack(spacing: 8) {
                        Text(isAuthorized ? "Hantera Apple Health" : "Aktivera Apple Health")
                            .font(.system(size: 13, weight: .semibold))
                        Image(systemName: isAuthorized ? "chevron.right" : "bolt.heart.fill")
                            .font(.system(size: 12, weight: .semibold))
                    }
                    .foregroundColor(.black)
                    .padding(.vertical, 10)
                    .padding(.horizontal, 14)
                    .background(isAuthorized ? Color(.systemGray5) : Color.black.opacity(0.08))
                    .cornerRadius(10)
                }
                .accessibilityLabel(isAuthorized ? "Hantera Apple Health-behörighet" : "Aktivera Apple Health")
            }
        }
    }
    
    private func refreshAuthorizationState() {
        isAuthorized = HealthKitManager.shared.isHealthDataAuthorized()
    }
    
    private func handleManageButtonTap() {
        if isAuthorized {
            if let manageAction {
                manageAction()
            } else {
                HealthKitManager.shared.handleManageAuthorizationButton()
            }
        } else {
            HealthKitManager.shared.requestAuthorization { granted in
                DispatchQueue.main.async {
                    self.isAuthorized = granted
                    if granted {
                        if let manageAction {
                            manageAction()
                        } else {
                            HealthKitManager.shared.handleManageAuthorizationButton()
                        }
                    }
                }
            }
        }
    }
}

#Preview {
    VStack(spacing: 20) {
        HealthDataDisclosureView(
            title: "Data från Apple Health",
            description: "Up&Down läser steg, distans och kalorier från Apple Health för att visa din statistik." ,
            showsManageButton: true,
            manageAction: {}
        )
        .padding()
    }
    .background(Color(.systemGray6))
}

