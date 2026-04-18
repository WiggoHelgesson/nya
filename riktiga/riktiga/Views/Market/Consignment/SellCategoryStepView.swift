import SwiftUI

struct SellCategoryStepView: View {
    @ObservedObject var model: SellFlowModel
    @Binding var path: NavigationPath

    @State private var isLoadingSuggestions = true
    @State private var loadError: String?
    @State private var showAllCategories = false
    @State private var isAnalyzing = false
    @State private var analysisError: String?

    var body: some View {
        ZStack {
            ScrollView {
                VStack(alignment: .leading, spacing: 20) {
                    sparkleTitle
                    Text(L.t(
                        sv: "I vilken kategori hör det här hemma?",
                        nb: "Hvilken kategori passer dette best i?"
                    ))
                    .font(.system(size: 22, weight: .bold))
                    .fixedSize(horizontal: false, vertical: true)

                    if isLoadingSuggestions {
                        HStack(spacing: 10) {
                            ProgressView()
                                .tint(.black)
                            Text(L.t(sv: "Hämtar förslag…", nb: "Henter forslag…"))
                                .foregroundStyle(.secondary)
                        }
                        .padding(.vertical, 24)
                    } else if let loadError {
                        Text(loadError)
                            .foregroundStyle(.red)
                            .font(.system(size: 14))
                    }

                    suggestionSection

                    Button {
                        withAnimation(.spring(response: 0.35, dampingFraction: 0.88)) {
                            showAllCategories.toggle()
                        }
                    } label: {
                        Text(L.t(sv: "Välj en annan kategori", nb: "Velg en annen kategori"))
                            .font(.system(size: 16, weight: .medium))
                            .frame(maxWidth: .infinity)
                    }
                    .buttonStyle(.plain)
                    .foregroundStyle(Color.black)

                    if showAllCategories {
                        allCategoriesList
                            .transition(.opacity.combined(with: .move(edge: .top)))
                    }

                    Spacer(minLength: 120)
                }
                .padding(.horizontal, 20)
                .padding(.top, 8)
            }

            if isAnalyzing {
                analyzingOverlay
            }
        }
        .background(Color(.systemBackground))
        .navigationBarBackButtonHidden(true)
        .toolbar {
            ToolbarItem(placement: .navigationBarLeading) {
                Button {
                    withAnimation(.spring(response: 0.32, dampingFraction: 0.86)) {
                        if !path.isEmpty { path.removeLast() }
                    }
                } label: {
                    HStack(spacing: 4) {
                        Image(systemName: "chevron.left")
                        Text(L.t(sv: "Bilder", nb: "Bilder"))
                    }
                    .font(.system(size: 16, weight: .medium))
                    .foregroundStyle(Color.black)
                }
            }
        }
        .safeAreaInset(edge: .bottom) {
            bottomContinueBar
        }
        .task {
            await loadSuggestionsIfNeeded()
        }
    }

    private var sparkleTitle: some View {
        HStack(spacing: 4) {
            Image(systemName: "sparkles")
                .font(.system(size: 14))
                .foregroundStyle(Color.black)
        }
    }

    @ViewBuilder
    private var suggestionSection: some View {
        if !model.categorySuggestions.isEmpty && !isLoadingSuggestions {
            VStack(alignment: .leading, spacing: 12) {
                HStack(spacing: 6) {
                    Image(systemName: "sparkles")
                        .font(.system(size: 13))
                        .foregroundStyle(Color.black)
                    Text(L.t(sv: "Förslag", nb: "Forslag"))
                        .font(.system(size: 15, weight: .semibold))
                }
                .padding(.top, 4)

                ForEach(model.categorySuggestions, id: \.self) { cat in
                    categoryCard(cat)
                }
            }
        }
    }

    private func categoryCard(_ cat: String) -> some View {
        let selected = model.selectedCategory == cat
        return Button {
            withAnimation(.spring(response: 0.28, dampingFraction: 0.82)) {
                model.selectedCategory = cat
            }
        } label: {
            HStack(alignment: .center, spacing: 14) {
                Image(systemName: selected ? "largecircle.fill.circle" : "circle")
                    .font(.system(size: 22))
                    .foregroundStyle(selected ? Color.black : Color(.systemGray3))
                Text(cat)
                    .font(.system(size: 16, weight: .semibold))
                    .foregroundStyle(.primary)
                    .multilineTextAlignment(.leading)
                Spacer(minLength: 0)
            }
            .padding(16)
            .background(
                RoundedRectangle(cornerRadius: 14, style: .continuous)
                    .fill(Color(.systemBackground))
                    .shadow(color: .black.opacity(selected ? 0.08 : 0.03), radius: selected ? 8 : 2, y: selected ? 3 : 1)
            )
            .overlay(
                RoundedRectangle(cornerRadius: 14, style: .continuous)
                    .strokeBorder(selected ? Color.black.opacity(0.45) : Color(.separator).opacity(0.6), lineWidth: selected ? 2 : 1)
            )
        }
        .buttonStyle(.plain)
    }

    private var allCategoriesList: some View {
        LazyVStack(alignment: .leading, spacing: 8) {
            ForEach(SellConsignmentCategories.all, id: \.self) { cat in
                Button {
                    withAnimation(.spring(response: 0.28, dampingFraction: 0.82)) {
                        model.selectedCategory = cat
                    }
                } label: {
                    HStack {
                        Text(cat)
                            .font(.system(size: 15))
                            .foregroundStyle(.primary)
                        Spacer()
                        if model.selectedCategory == cat {
                            Image(systemName: "checkmark.circle.fill")
                                .foregroundStyle(Color.black)
                        }
                    }
                    .padding(.vertical, 10)
                }
                .buttonStyle(.plain)
                Divider()
            }
        }
        .padding(.vertical, 8)
    }

    private var bottomContinueBar: some View {
        VStack(spacing: 0) {
            Rectangle()
                .fill(Color(.separator).opacity(0.35))
                .frame(height: 0.5)
            Button {
                Task { await runAnalysis() }
            } label: {
                Text(L.t(sv: "Fortsätt", nb: "Fortsett"))
                    .font(.system(size: 17, weight: .bold))
                    .foregroundStyle(.white)
                    .frame(maxWidth: .infinity)
                    .frame(height: 52)
                    .background(
                        RoundedRectangle(cornerRadius: 14, style: .continuous)
                            .fill(model.selectedCategory.isEmpty ? Color.gray.opacity(0.45) : Color.black)
                    )
            }
            .disabled(model.selectedCategory.isEmpty || isAnalyzing)
            .padding(.horizontal, 20)
            .padding(.vertical, 12)
            .background(Color(.systemGray6))
        }
    }

    private var analyzingOverlay: some View {
        ZStack {
            Color.black.opacity(0.35)
                .ignoresSafeArea()
            VStack(spacing: 18) {
                ProgressView()
                    .scaleEffect(1.2)
                    .tint(.white)
                Text(L.t(sv: "AI analyserar dina bilder…", nb: "AI analyserer bildene dine…"))
                    .font(.system(size: 16, weight: .medium))
                    .foregroundStyle(.white)
                if let analysisError {
                    Text(analysisError)
                        .font(.system(size: 13))
                        .foregroundStyle(.white.opacity(0.9))
                        .multilineTextAlignment(.center)
                        .padding(.horizontal)
                }
            }
            .padding(28)
            .background(.ultraThinMaterial, in: RoundedRectangle(cornerRadius: 20, style: .continuous))
            .padding(32)
        }
        .transition(.opacity)
    }

    private func loadSuggestionsIfNeeded() async {
        guard model.categorySuggestions.isEmpty else {
            await MainActor.run { isLoadingSuggestions = false }
            return
        }
        guard let first = model.images.first,
              let jpeg = SellImagePrep.jpegData(from: first) else {
            await MainActor.run {
                isLoadingSuggestions = false
                model.categorySuggestions = Array(SellConsignmentCategories.all.prefix(3))
            }
            return
        }
        await MainActor.run {
            isLoadingSuggestions = true
            loadError = nil
        }
        do {
            let sug = try await ConsignmentListingAIService.shared.suggestCategories(firstImageJPEG: jpeg)
            await MainActor.run {
                model.categorySuggestions = sug
                if model.selectedCategory.isEmpty, let first = sug.first {
                    model.selectedCategory = first
                }
                isLoadingSuggestions = false
            }
        } catch {
            await MainActor.run {
                model.categorySuggestions = Array(SellConsignmentCategories.all.prefix(3))
                if model.selectedCategory.isEmpty {
                    model.selectedCategory = model.categorySuggestions[0]
                }
                isLoadingSuggestions = false
                loadError = error.localizedDescription
            }
        }
    }

    private func runAnalysis() async {
        await MainActor.run {
            isAnalyzing = true
            analysisError = nil
        }
        let jpegChunks: [Data] = model.images.compactMap { SellImagePrep.jpegData(from: $0) }
        do {
            let result = try await ConsignmentListingAIService.shared.analyzeListing(
                imagesJPEG: jpegChunks,
                category: model.selectedCategory
            )
            await MainActor.run {
                model.applyAnalysis(result)
                isAnalyzing = false
                withAnimation(.spring(response: 0.38, dampingFraction: 0.88)) {
                    path.append(SellRoute.result)
                }
            }
        } catch {
            await MainActor.run {
                isAnalyzing = false
                analysisError = error.localizedDescription
            }
        }
    }
}
