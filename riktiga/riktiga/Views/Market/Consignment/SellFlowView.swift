import SwiftUI
import UIKit

struct SellFlowView: View {
    @EnvironmentObject var authViewModel: AuthViewModel
    var editingRow: ConsignmentSubmissionRow? = nil
    var onAbandonFlow: () -> Void

    @StateObject private var model = SellFlowModel()
    @State private var path = NavigationPath()
    @State private var isLoadingExistingImages: Bool = false
    @State private var didPrefill: Bool = false
    @State private var showExitConfirmation = false

    var body: some View {
        NavigationStack(path: $path) {
            Group {
                if editingRow != nil {
                    NewListingFormView(
                        model: model,
                        path: $path,
                        onClose: requestExitConfirmation,
                        onAbandonWithoutConfirmation: onAbandonFlow
                    )
                } else {
                    SellListingWizardContainerView(
                        model: model,
                        path: $path,
                        onClose: requestExitConfirmation
                    )
                }
            }
            .environmentObject(authViewModel)
            .navigationDestination(for: SellRoute.self) { route in
                switch route {
                case .category:
                    SellCategoryPickerView(model: model, path: $path)
                case .subcategory(let topId):
                    SellSubcategoryPickerView(model: model, path: $path, topCategoryId: topId)
                case .condition:
                    SellConditionPickerView(model: model, path: $path)
                case .packageSize:
                    SellPackageSizePickerView(model: model, path: $path)
                case .pickupAddress:
                    SellerPickupAddressPickerView(model: model, path: $path)
                case .success:
                    ListingSuccessView(onDone: {
                        onAbandonFlow()
                        DispatchQueue.main.asyncAfter(deadline: .now() + 0.15) {
                            NotificationCenter.default.post(
                                name: NSNotification.Name("NavigateToMyListings"),
                                object: nil
                            )
                        }
                    })
                }
            }
        }
        .tint(Color.primary)
        .sheet(isPresented: $showExitConfirmation) {
            SellExitConfirmationSheet(
                onContinueEditing: {
                    showExitConfirmation = false
                },
                onCloseFlow: {
                    showExitConfirmation = false
                    onAbandonFlow()
                }
            )
            .presentationDetents([.medium])
            .presentationDragIndicator(.visible)
        }
        .overlay {
            if isLoadingExistingImages {
                loadingOverlay
            }
        }
        .task {
            await loadSavedPickupAddressIfNeeded()
            guard let row = editingRow, !didPrefill else { return }
            didPrefill = true
            model.prefill(from: row)
            await loadExistingImages(urls: row.imageUrls)
        }
    }

    private func requestExitConfirmation() {
        showExitConfirmation = true
    }

    private func loadSavedPickupAddressIfNeeded() async {
        do {
            if let existing = try await ShipmondoShippingService.shared.fetchSellerPickupAddress() {
                await MainActor.run {
                    model.pickupAddress = existing
                    model.hasSavedPickupAddress = true
                }
            }
        } catch {
            // User can still fill pickup in the sell flow.
        }
    }

    private var loadingOverlay: some View {
        ZStack {
            Color.black.opacity(0.35).ignoresSafeArea()
            VStack(spacing: 14) {
                ProgressView().controlSize(.large).tint(.white)
                Text(L.t(sv: "Laddar bilder…", nb: "Laster bilder…"))
                    .font(.system(size: 15, weight: .semibold))
                    .foregroundStyle(.white)
            }
            .padding(24)
            .background(Color.black.opacity(0.5))
            .clipShape(RoundedRectangle(cornerRadius: 14))
        }
    }

    private func loadExistingImages(urls: [String]) async {
        guard !urls.isEmpty else { return }
        await MainActor.run { isLoadingExistingImages = true }
        var loaded: [UIImage] = []
        for urlString in urls {
            guard let url = URL(string: urlString) else { continue }
            do {
                let (data, _) = try await URLSession.shared.data(from: url)
                if let image = UIImage(data: data) {
                    loaded.append(image)
                }
            } catch {
                print("Edit flow: failed to download existing image \(urlString): \(error)")
            }
        }
        await MainActor.run {
            model.images = loaded
            isLoadingExistingImages = false
        }
    }
}
