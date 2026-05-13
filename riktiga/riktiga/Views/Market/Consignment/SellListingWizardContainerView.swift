import SwiftUI

/// Flöde för ny annons: bilder → AI kategori → godkänn kategori → AI text → formulär.
struct SellListingWizardContainerView: View {
    @ObservedObject var model: SellFlowModel
    @Binding var path: NavigationPath
    let onClose: () -> Void

    private enum WizardPhase {
        case photos
        case analyzingCategory
        case categoryReview
        case analyzingCopy
        case details
    }

    @State private var phase: WizardPhase = .photos
    @State private var categoryAIError: String?

    var body: some View {
        Group {
            switch phase {
            case .photos:
                SellPhotoUploadStepView(model: model, onCancel: onClose) {
                    Task { await runCategoryAI() }
                }
            case .analyzingCategory:
                SellAIProgressView(phase: .category)
            case .categoryReview:
                SellCategoryReviewStepView(
                    model: model,
                    path: $path,
                    categoryAIError: categoryAIError,
                    onCancel: onClose
                ) {
                    advanceAfterCategoryConfirmed()
                }
            case .analyzingCopy:
                SellAIProgressView(phase: .copyWriting)
            case .details:
                NewListingFormView(
                    model: model,
                    path: $path,
                    onClose: onClose,
                    showPhotosSection: false,
                    maxPhotos: 7,
                    wizardDetailsMode: true
                )
            }
        }
    }

    private func runCategoryAI() async {
        guard !model.images.isEmpty else { return }
        await MainActor.run {
            phase = .analyzingCategory
            categoryAIError = nil
        }
        do {
            if let cat = try await ListingDraftAIService.suggestCategory(images: model.images) {
                await MainActor.run {
                    model.selectedCategory = cat
                    categoryAIError = nil
                    phase = .categoryReview
                }
            } else {
                await MainActor.run {
                    model.selectedCategory = ""
                    categoryAIError = L.t(
                        sv: "Vi kunde inte välja kategori automatiskt — tryck Redigera och välj.",
                        nb: "Vi kunne ikke velge kategori automatisk — trykk Rediger og velg."
                    )
                    phase = .categoryReview
                }
            }
        } catch {
            await MainActor.run {
                model.selectedCategory = ""
                categoryAIError = error.localizedDescription
                phase = .categoryReview
            }
        }
    }

    private func advanceAfterCategoryConfirmed() {
        guard !model.selectedCategory.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else { return }
        if model.useAiGeneratedCopy {
            Task { await runCopyAI() }
        } else {
            phase = .details
        }
    }

    private func runCopyAI() async {
        await MainActor.run { phase = .analyzingCopy }
        do {
            let result = try await ListingDraftAIService.suggestTitleDescription(
                images: model.images,
                categoryDisplayName: model.selectedCategory
            )
            await MainActor.run {
                model.title = result.title
                model.listingDescription = result.description
                phase = .details
            }
        } catch {
            await MainActor.run {
                phase = .details
            }
        }
    }
}
