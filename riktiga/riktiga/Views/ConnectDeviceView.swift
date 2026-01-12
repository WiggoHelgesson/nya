import SwiftUI
import SafariServices

struct ConnectDeviceView: View {
    @Environment(\.dismiss) var dismiss
    @EnvironmentObject var authViewModel: AuthViewModel
    @StateObject private var terraService = TerraService.shared
    
    @State private var isConnecting = false
    @State private var selectedProvider: TerraProvider?
    @State private var showSafari = false
    @State private var safariURL: URL?
    @State private var showError = false
    @State private var errorMessage = ""
    
    // Grid of providers - only those with logos
    private let providerRows: [[TerraProvider]] = [
        [.apple, .garmin],
        [.polar, .zwift],
        [.suunto, .wahoo],
        [.fitbit, .oura]
    ]
    
    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: 24) {
                    // Header
                    VStack(alignment: .leading, spacing: 12) {
                        Text("Anslut till Up&Down")
                            .font(.system(size: 28, weight: .bold))
                            .foregroundColor(.black)
                        
                        Text("Up&Down kopplas till nästan alla träningsenheter och appar. Få sömlös synkronisering av aktiviteter – och en bättre bild av din prestation och återhämtning.")
                            .font(.system(size: 15))
                            .foregroundColor(.secondary)
                            .lineSpacing(4)
                    }
                    .padding(.horizontal, 20)
                    .padding(.top, 16)
                    
                    // Devices Grid
                    VStack(spacing: 12) {
                        ForEach(providerRows, id: \.first?.id) { row in
                            HStack(spacing: 12) {
                                ForEach(row) { provider in
                                    DeviceButton(
                                        provider: provider,
                                        isConnected: terraService.isProviderConnected(provider),
                                        isLoading: isConnecting && selectedProvider == provider,
                                        action: {
                                            handleProviderTap(provider)
                                        }
                                    )
                                }
                            }
                        }
                    }
                    .padding(.horizontal, 20)
                    
                    Spacer(minLength: 40)
                }
            }
            .background(Color.white)
            .navigationBarTitleDisplayMode(.inline)
            .navigationTitle("Enheter")
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button {
                        dismiss()
                    } label: {
                        Image(systemName: "xmark")
                            .font(.system(size: 16, weight: .medium))
                            .foregroundColor(.black)
                    }
                }
            }
        }
        .onAppear {
            if let userId = authViewModel.currentUser?.id {
                Task {
                    await terraService.fetchConnectedProviders(userId: userId)
                }
            }
        }
        .sheet(isPresented: $showSafari) {
            if let url = safariURL {
                SafariView(url: url)
            }
        }
        .alert("Fel", isPresented: $showError) {
            Button("OK", role: .cancel) {}
        } message: {
            Text(errorMessage)
        }
        .onOpenURL { url in
            handleTerraCallback(url: url)
        }
    }
    
    private func handleProviderTap(_ provider: TerraProvider) {
        if terraService.isProviderConnected(provider) {
            disconnectProvider(provider)
        } else {
            connectToProvider(provider)
        }
    }
    
    private func connectToProvider(_ provider: TerraProvider) {
        guard let userId = authViewModel.currentUser?.id else { return }
        
        selectedProvider = provider
        isConnecting = true
        
        // Apple Health uses SDK, not web widget
        if provider.requiresSDK {
            connectAppleHealth(userId: userId)
            return
        }
        
        // Other providers use web widget
        Task {
            do {
                let widgetURL = try await terraService.generateWidgetSession(for: provider, userId: userId)
                
                await MainActor.run {
                    safariURL = widgetURL
                    showSafari = true
                    isConnecting = false
                }
            } catch {
                await MainActor.run {
                    errorMessage = error.localizedDescription
                    showError = true
                    isConnecting = false
                    selectedProvider = nil
                }
            }
        }
    }
    
    private func connectAppleHealth(userId: String) {
        terraService.connectAppleHealth(userId: userId) { success, error in
            DispatchQueue.main.async {
                isConnecting = false
                selectedProvider = nil
                
                if success {
                    print("✅ Apple Health connected successfully")
                } else {
                    errorMessage = error ?? "Kunde inte ansluta Apple Health"
                    showError = true
                }
            }
        }
    }
    
    private func disconnectProvider(_ provider: TerraProvider) {
        guard let connection = terraService.getConnection(for: provider) else { return }
        
        Task {
            do {
                try await terraService.disconnectProvider(connectionId: connection.id)
                
                if let userId = authViewModel.currentUser?.id {
                    await terraService.fetchConnectedProviders(userId: userId)
                }
            } catch {
                await MainActor.run {
                    errorMessage = "Kunde inte koppla bort enheten"
                    showError = true
                }
            }
        }
    }
    
    private func handleTerraCallback(url: URL) {
        guard url.scheme == "updown",
              url.host == "terra-callback" else { return }
        
        showSafari = false
        
        if url.absoluteString.contains("success=true") {
            if let userId = authViewModel.currentUser?.id {
                Task {
                    await terraService.fetchConnectedProviders(userId: userId)
                }
            }
        } else {
            errorMessage = "Anslutningen avbröts eller misslyckades"
            showError = true
        }
        
        selectedProvider = nil
    }
}

// MARK: - Device Button (Clean style)
struct DeviceButton: View {
    let provider: TerraProvider
    let isConnected: Bool
    let isLoading: Bool
    let action: () -> Void
    
    var body: some View {
        Button(action: action) {
            ZStack {
                // Centered logo
                providerLogo
                    .frame(height: 20)
                
                // Connection indicator - clear checkmark in top right
                if isLoading || isConnected {
                    VStack {
                        HStack {
                            Spacer()
                            if isLoading {
                                ProgressView()
                                    .scaleEffect(0.7)
                            } else if isConnected {
                                ZStack {
                                    Circle()
                                        .fill(Color.green)
                                        .frame(width: 24, height: 24)
                                    Image(systemName: "checkmark")
                                        .font(.system(size: 12, weight: .bold))
                                        .foregroundColor(.white)
                                }
                            }
                        }
                        Spacer()
                    }
                    .padding(8)
                }
            }
            .frame(maxWidth: .infinity)
            .padding(.vertical, 18)
            .background(isConnected ? Color.green.opacity(0.08) : Color.white)
            .cornerRadius(30)
            .overlay(
                RoundedRectangle(cornerRadius: 30)
                    .stroke(isConnected ? Color.green : Color(.systemGray4), lineWidth: isConnected ? 2 : 1)
            )
        }
        .buttonStyle(.plain)
    }
    
    @ViewBuilder
    private var providerLogo: some View {
        // Try to use image from assets
        if let uiImage = UIImage(named: provider.imageName) {
            Image(uiImage: uiImage)
                .resizable()
                .scaledToFit()
                .frame(maxWidth: 100)
        } else {
            // Fallback to styled text
            providerTextLogo
        }
    }
    
    @ViewBuilder
    private var providerTextLogo: some View {
        switch provider {
        case .apple:
            HStack(spacing: 4) {
                Image(systemName: "applewatch")
                    .font(.system(size: 16, weight: .medium))
                Text("WATCH")
                    .font(.system(size: 14, weight: .semibold))
            }
            .foregroundColor(.black)
        case .garmin:
            Text("GARMIN")
                .font(.system(size: 14, weight: .bold))
                .foregroundColor(.black)
        case .fitbit:
            HStack(spacing: 2) {
                Text("····")
                    .font(.system(size: 8, weight: .bold))
                Text("fitbit")
                    .font(.system(size: 14, weight: .semibold))
            }
            .foregroundColor(.init(red: 0, green: 0.7, blue: 0.7))
        case .zwift:
            HStack(spacing: 2) {
                Text("Z")
                    .font(.system(size: 16, weight: .black))
                    .foregroundColor(.orange)
                Text("ZWIFT")
                    .font(.system(size: 14, weight: .black))
                    .foregroundColor(.black)
            }
        case .oura:
            Text("ŌURA")
                .font(.system(size: 14, weight: .medium))
                .foregroundColor(.black)
        case .polar:
            Text("POLAR")
                .font(.system(size: 14, weight: .bold))
                .foregroundColor(.init(red: 0.85, green: 0, blue: 0))
        case .wahoo:
            Text("wahoo")
                .font(.system(size: 14, weight: .bold))
                .foregroundColor(.black)
        case .suunto:
            HStack(spacing: 2) {
                Text("▲")
                    .font(.system(size: 10))
                    .foregroundColor(.red)
                Text("SUUNTO")
                    .font(.system(size: 12, weight: .bold))
                    .foregroundColor(.black)
            }
        default:
            Text(provider.displayName.uppercased())
                .font(.system(size: 12, weight: .bold))
                .foregroundColor(.black)
        }
    }
}

// MARK: - TerraProvider Extension for Image Names
extension TerraProvider {
    var imageName: String {
        // Image names in Xcode assets
        switch self {
        case .apple: return "applewatch"
        case .garmin: return "garmin"
        case .polar: return "polar"
        case .zwift: return "zwift"
        case .suunto: return "suunto"
        case .wahoo: return "wahoo"
        case .fitbit: return "fitbit"
        case .oura: return "oura"
        default: return rawValue.lowercased()
        }
    }
}

// MARK: - Safari View
struct SafariView: UIViewControllerRepresentable {
    let url: URL
    
    func makeUIViewController(context: Context) -> SFSafariViewController {
        let config = SFSafariViewController.Configuration()
        config.entersReaderIfAvailable = false
        let safari = SFSafariViewController(url: url, configuration: config)
        safari.preferredControlTintColor = .black
        return safari
    }
    
    func updateUIViewController(_ uiViewController: SFSafariViewController, context: Context) {}
}

#Preview {
    ConnectDeviceView()
        .environmentObject(AuthViewModel())
}
