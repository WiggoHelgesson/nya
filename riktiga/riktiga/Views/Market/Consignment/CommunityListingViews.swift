import SwiftUI

#if canImport(GoogleMobileAds)
import GoogleMobileAds
#endif

// MARK: - Grid card used on the products page

struct CommunityListingCard: View {
    let row: ConsignmentSubmissionRow
    /// Visar kortet i en tätare 3-kolumns layout: mindre fonts, snävare
    /// padding och dold meta/grundpris så det får plats i smalare spalt.
    var compact: Bool = false

    private let protectionAccent = Color.black

    var body: some View {
        let brand = row.userBrand?.trimmingCharacters(in: .whitespacesAndNewlines) ?? ""
        let condition = SellCondition.localizedTitle(raw: row.userCondition) ?? ""
        let hasBrand = !brand.isEmpty
        let hasCondition = !condition.isEmpty

        return VStack(alignment: .leading, spacing: compact ? 4 : 6) {
            ZStack(alignment: .topLeading) {
                Color.clear
                    .aspectRatio(3.0 / 4.0, contentMode: .fit)
                    .overlay {
                        cover
                    }
                    .clipped()
                    .clipShape(RoundedRectangle(cornerRadius: 10, style: .continuous))
                    .overlay(
                        RoundedRectangle(cornerRadius: 10, style: .continuous)
                            .stroke(Color.black.opacity(0.05), lineWidth: 1)
                    )
            }

            if hasBrand || hasCondition {
                HStack(alignment: .firstTextBaseline, spacing: compact ? 4 : 6) {
                    if hasBrand {
                        Text(brand)
                            .font(.system(size: compact ? 12 : 14, weight: .bold))
                            .foregroundColor(.primary)
                            .lineLimit(1)
                    }
                    Spacer(minLength: 4)
                    if hasCondition && !compact {
                        Text(condition)
                            .font(.system(size: 13))
                            .foregroundColor(.secondary)
                            .lineLimit(1)
                    }
                }
                .padding(.top, 2)
            }

            if let meta = metaLine, !meta.isEmpty {
                Text(meta)
                    .font(.system(size: compact ? 11 : 12))
                    .foregroundColor(.secondary)
                    .lineLimit(1)
            }

            if !compact {
                Text(formattedPrice)
                    .font(.system(size: 13))
                    .foregroundColor(.secondary)
            }

            if let protectionPrice = buyerProtectionText {
                HStack(spacing: 4) {
                    Text(protectionPrice)
                        .font(.system(size: compact ? 13 : 15, weight: .bold))
                        .lineLimit(1)
                        .minimumScaleFactor(0.8)
                    Image(systemName: "checkmark.shield.fill")
                        .font(.system(size: compact ? 11 : 12, weight: .semibold))
                }
                .foregroundColor(.primary)
            }
        }
    }

    private var metaLine: String? {
        if let title = row.title?.trimmingCharacters(in: .whitespacesAndNewlines),
           !title.isEmpty {
            return title
        }
        if !row.category.isEmpty {
            return row.category
        }
        return nil
    }

    private var formattedPrice: String {
        if let price = row.priceSEK { return "\(price),00 kr" }
        return row.finalPriceRange ?? "—"
    }

    private var buyerProtectionText: String? {
        guard let price = row.priceSEK else { return nil }
        return "\(MarketplacePricing.buyerTotalFormatted(priceSEK: price)) inkl."
    }

    @ViewBuilder
    private var cover: some View {
        CachedRemoteImage(url: row.imageUrls.first) {
            placeholder
        }
    }

    private var placeholder: some View {
        Rectangle()
            .fill(Color(.systemGray5))
            .overlay {
                Image(systemName: "photo")
                    .foregroundColor(.gray)
                    .font(.system(size: 20))
            }
    }
}

// MARK: - Detail view (full-bleed, Sellpy-style)

struct CommunityListingDetailView: View {
    let row: ConsignmentSubmissionRow

    @EnvironmentObject var authViewModel: AuthViewModel
    @Environment(\.dismiss) private var dismiss
    @Environment(\.marketplaceHeroNamespace) private var heroNS

    @State private var otherListings: [ConsignmentSubmissionRow] = []
    @State private var currentImageIndex: Int = 0
    @State private var isCreatingConversation: Bool = false
    @State private var chatTarget: ChatTarget?
    @State private var showOwnerActions: Bool = false
    @State private var showDeleteConfirm: Bool = false
    @State private var showEditFlow: Bool = false
    @State private var isDeleting: Bool = false
    @State private var deleteError: String?
    @State private var sellerProfile: User?
    @State private var showSellerProfile: Bool = false

    private struct ChatTarget: Identifiable {
        let id: UUID
        let otherUserId: String
        let otherUsername: String
        let otherAvatarUrl: String?
    }

    #if canImport(GoogleMobileAds)
    @ObservedObject private var adMobService = AdMobService.shared
    #endif

    private let accent = Color.black
    private let columns = [
        GridItem(.flexible(), spacing: 12),
        GridItem(.flexible(), spacing: 12)
    ]

    var body: some View {
        ZStack(alignment: .topLeading) {
            ScrollView {
                VStack(spacing: 0) {
                    imageCarousel

                    VStack(alignment: .leading, spacing: 0) {
                        sectionContainer {
                            titleBlock
                            priceBlock
                        }
                        sectionSeparator
                        if let description = row.description, !description.isEmpty {
                            sectionContainer {
                                descriptionBlock(description)
                            }
                            sectionSeparator
                        }
                        if !isOwnListing {
                            sectionContainer { sellerBlock }
                            sectionSeparator
                        }
                        sectionContainer { buyerProtectionFeeBlock }
                        sectionSeparator
                        sectionContainer { factsBlock }
                        sectionSeparator
                        sectionContainer {
                            legalBlock
                            adBlock
                            feedBlock
                        }
                    }
                    .padding(.top, 20)
                    .padding(.bottom, 40)
                }
            }

            HStack {
                backButton
                Spacer()
                if isOwnListing || isAdmin {
                    ownerMenuButton
                }
            }
            .padding(.top, 8)
            .padding(.horizontal, 12)
        }
        .background(Color(.systemBackground))
        .ignoresSafeArea(edges: .top)
        .task {
            ImageCacheManager.shared.prefetch(urls: row.imageUrls)
            // Vänta ut zoom-pushen (~350ms) innan vi triggar tunga
            // state-mutations längre ner i vyn — annars kolliderar
            // ScrollView:ns content-storleksändring med transitionen
            // och bottendelen rycker till.
            try? await Task.sleep(nanoseconds: 350_000_000)
            await loadOtherListings()
            await loadSellerProfile()
        }
        .confirmationDialog(
            L.t(sv: "Välj åtgärd", nb: "Velg handling"),
            isPresented: $showOwnerActions,
            titleVisibility: .hidden
        ) {
            if isOwnListing {
                Button(L.t(sv: "Redigera", nb: "Rediger")) {
                    showEditFlow = true
                }
            }
            Button(L.t(sv: "Radera", nb: "Slett"), role: .destructive) {
                showDeleteConfirm = true
            }
            Button(L.t(sv: "Stäng", nb: "Lukk"), role: .cancel) {}
        }
        .confirmationDialog(
            L.t(sv: "Ta bort annonsen?", nb: "Slette annonsen?"),
            isPresented: $showDeleteConfirm,
            titleVisibility: .visible
        ) {
            Button(L.t(sv: "Radera", nb: "Slett"), role: .destructive) {
                performDelete()
            }
            Button(L.t(sv: "Avbryt", nb: "Avbryt"), role: .cancel) {}
        } message: {
            Text(L.t(
                sv: "Det här går inte att ångra.",
                nb: "Dette kan ikke angres."
            ))
        }
        .alert(
            L.t(sv: "Kunde inte radera", nb: "Kunne ikke slette"),
            isPresented: Binding(
                get: { deleteError != nil },
                set: { if !$0 { deleteError = nil } }
            )
        ) {
            Button("OK", role: .cancel) { deleteError = nil }
        } message: {
            Text(deleteError ?? "")
        }
        .fullScreenCover(isPresented: $showEditFlow) {
            SellFlowView(
                editingRow: row,
                onAbandonFlow: {
                    showEditFlow = false
                    DispatchQueue.main.asyncAfter(deadline: .now() + 0.15) {
                        NotificationCenter.default.post(
                            name: NSNotification.Name("NavigateToMyListings"),
                            object: nil
                        )
                    }
                    dismiss()
                }
            )
            .environmentObject(authViewModel)
        }
        .sheet(item: $chatTarget) { target in
            NavigationStack {
                DirectMessageView(
                    conversationId: target.id,
                    otherUserId: target.otherUserId,
                    otherUsername: target.otherUsername,
                    otherAvatarUrl: target.otherAvatarUrl,
                    listingId: row.id
                )
                .environmentObject(authViewModel)
            }
        }
        .sheet(isPresented: $showSellerProfile) {
            NavigationStack {
                UserProfileView(userId: row.userId.uuidString)
                    .environmentObject(authViewModel)
            }
        }
        .safeAreaInset(edge: .bottom) { buyBar }
        .toolbar(.hidden, for: .navigationBar)
        .onAppear {
            NavigationDepthTracker.shared.acquireHideTabBar()
        }
        .onDisappear {
            NavigationDepthTracker.shared.releaseHideTabBar()
        }
    }

    // MARK: - Bottom Buy bar

    @ViewBuilder
    private var buyBar: some View {
        if isOwnListing {
            EmptyView()
        } else if row.soldAt != nil {
            HStack {
                Image(systemName: "checkmark.seal.fill")
                Text(L.t(sv: "Såld", nb: "Solgt"))
                    .font(.system(size: 16, weight: .bold))
                Spacer()
            }
            .foregroundStyle(.white)
            .padding(.horizontal, 20)
            .padding(.vertical, 14)
            .background(Color.gray)
        } else {
            HStack(spacing: 10) {
                NavigationLink(value: MarketplaceRoute.priceOffer(row)) {
                    Text(L.t(sv: "Prisförslag", nb: "Prisforslag"))
                        .font(.system(size: 16, weight: .semibold))
                        .foregroundStyle(accent)
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 14)
                        .background(
                            RoundedRectangle(cornerRadius: 14)
                                .stroke(accent, lineWidth: 1.5)
                        )
                }
                .buttonStyle(.plain)
                .disabled(!hasPrice)

                NavigationLink(value: MarketplaceRoute.checkout(row)) {
                    Text(L.t(sv: "Köp nu", nb: "Kjøp nå"))
                        .font(.system(size: 16, weight: .semibold))
                        .foregroundStyle(.white)
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 14)
                        .background(hasPrice ? accent : Color.gray.opacity(0.5))
                        .clipShape(RoundedRectangle(cornerRadius: 14))
                }
                .buttonStyle(.plain)
                .disabled(!hasPrice)
            }
            .padding(.horizontal, 16)
            .padding(.top, 10)
            .padding(.bottom, 10)
            .background(
                Color(.systemBackground)
                    .shadow(color: Color.black.opacity(0.06), radius: 8, x: 0, y: -2)
                    .ignoresSafeArea(edges: .bottom)
            )
        }
    }

    private func openConversation() {
        guard !isCreatingConversation else { return }
        isCreatingConversation = true
        Task {
            defer { Task { @MainActor in isCreatingConversation = false } }
            do {
                let sellerIdString = row.userId.uuidString
                let conversationId = try await DirectMessageService.shared.getOrCreateConversation(
                    withUserId: sellerIdString,
                    listingId: row.id
                )
                var username = L.t(sv: "Säljare", nb: "Selger")
                var avatarUrl: String? = nil
                if let profile = try? await ProfileService.shared.fetchUserProfile(userId: sellerIdString) {
                    if !profile.name.isEmpty { username = profile.name }
                    avatarUrl = profile.avatarUrl
                }
                await MainActor.run {
                    chatTarget = ChatTarget(
                        id: conversationId,
                        otherUserId: sellerIdString,
                        otherUsername: username,
                        otherAvatarUrl: avatarUrl
                    )
                }
            } catch {
                print("CommunityListingDetailView.openConversation failed: \(error)")
            }
        }
    }

    private var isOwnListing: Bool {
        guard let currentId = authViewModel.currentUser?.id,
              let currentUUID = UUID(uuidString: currentId) else { return false }
        return currentUUID == row.userId
    }

    private var isAdmin: Bool {
        authViewModel.currentUser?.email.lowercased() == "info@bylito.se"
    }

    private var hasPrice: Bool {
        if let price = row.priceSEK, price > 0 { return true }
        return false
    }

    private var buyButtonTitle: String {
        guard let price = row.priceSEK else {
            return L.t(sv: "Köp", nb: "Kjøp")
        }
        let total = MarketplacePricing.buyerTotalFormatted(priceSEK: price)
        return L.t(sv: "Köp för \(total)", nb: "Kjøp for \(total)")
    }

    // MARK: - Back button

    private var backButton: some View {
        Button {
            dismiss()
        } label: {
            Image(systemName: "arrow.left")
                .font(.system(size: 17, weight: .semibold))
                .foregroundStyle(.white)
                .frame(width: 36, height: 36)
                .background(Circle().fill(Color.black.opacity(0.45)))
                .padding(.top, 40)
        }
        .buttonStyle(.plain)
    }

    private var ownerMenuButton: some View {
        Button {
            showOwnerActions = true
        } label: {
            ZStack {
                if isDeleting {
                    ProgressView()
                        .progressViewStyle(.circular)
                        .tint(.white)
                } else {
                    Image(systemName: "ellipsis")
                        .font(.system(size: 17, weight: .semibold))
                        .foregroundStyle(.white)
                }
            }
            .frame(width: 36, height: 36)
            .background(Circle().fill(Color.black.opacity(0.45)))
            .padding(.top, 40)
        }
        .buttonStyle(.plain)
        .disabled(isDeleting)
    }

    private func performDelete() {
        guard let userId = authViewModel.currentUser?.id else {
            deleteError = L.t(sv: "Du måste vara inloggad.", nb: "Du må være innlogget.")
            return
        }
        isDeleting = true
        let rowId = row.id
        let urls = row.imageUrls
        let deletingAsAdmin = !isOwnListing && isAdmin
        Task {
            defer { Task { @MainActor in isDeleting = false } }
            do {
                try await ConsignmentSubmissionService.shared.delete(
                    userId: userId,
                    rowId: rowId,
                    imageUrls: urls,
                    asAdmin: deletingAsAdmin
                )
                await MainActor.run {
                    NotificationCenter.default.post(
                        name: NSNotification.Name("NavigateToMyListings"),
                        object: nil
                    )
                    dismiss()
                }
            } catch {
                await MainActor.run {
                    deleteError = error.localizedDescription
                }
            }
        }
    }

    // MARK: - Image carousel (full-bleed to top)

    private var imageCarousel: some View {
        ZStack(alignment: .bottomTrailing) {
            TabView(selection: $currentImageIndex) {
                if row.imageUrls.isEmpty {
                    placeholder.tag(0)
                } else {
                    ForEach(Array(row.imageUrls.enumerated()), id: \.offset) { index, urlString in
                        CachedRemoteImage(url: urlString) {
                            placeholder
                        }
                        .frame(maxWidth: .infinity)
                        .clipped()
                        .tag(index)
                    }
                }
            }
            .tabViewStyle(.page(indexDisplayMode: .automatic))
            .frame(height: 520)
            .background(Color(.secondarySystemBackground))

            if row.imageUrls.count > 1 {
                Text("\(currentImageIndex + 1) / \(row.imageUrls.count)")
                    .font(.system(size: 12, weight: .semibold))
                    .foregroundStyle(.white)
                    .padding(.horizontal, 10)
                    .padding(.vertical, 5)
                    .background(Capsule().fill(Color.black.opacity(0.55)))
                    .padding(16)
            }
        }
    }

    private var placeholder: some View {
        Rectangle()
            .fill(Color(.systemGray5))
            .overlay {
                Image(systemName: "photo")
                    .foregroundColor(.gray)
                    .font(.system(size: 30))
            }
    }

    // MARK: - Price + buyer protection

    private var priceBlock: some View {
        VStack(alignment: .leading, spacing: 4) {
            Text(formattedPrice)
                .font(.system(size: 22, weight: .bold))

            if let totalText = buyerProtectionTotalText {
                HStack(spacing: 6) {
                    Text(totalText)
                        .font(.system(size: 15, weight: .semibold))
                    Text(L.t(sv: "Inkluderar köparskydd", nb: "Inkluderer kjøperbeskyttelse"))
                        .font(.system(size: 15, weight: .semibold))
                    Image(systemName: "checkmark.shield.fill")
                        .font(.system(size: 13, weight: .semibold))
                }
                .foregroundStyle(accent)
            }
        }
    }

    // MARK: - Title + meta

    private var titleBlock: some View {
        VStack(alignment: .leading, spacing: 6) {
            if let title = row.title, !title.isEmpty {
                Text(title)
                    .font(.system(size: 22, weight: .bold))
                    .foregroundStyle(.primary)
            }

            if !metaLine.isEmpty {
                Text(metaLine)
                    .font(.system(size: 14))
                    .foregroundStyle(.secondary)
                    .fixedSize(horizontal: false, vertical: true)
            }
        }
    }

    private var metaLine: String {
        var parts: [String] = []
        if let cond = SellCondition.localizedTitle(raw: row.userCondition) { parts.append(cond) }
        if let brand = row.userBrand, !brand.isEmpty { parts.append(brand) }
        if let created = row.createdAt {
            let rel = relativeDate(created)
            if !rel.isEmpty {
                parts.append(L.t(sv: "Uppladdad \(rel)", nb: "Lastet opp \(rel)"))
            }
        }
        return parts.joined(separator: " · ")
    }

    // MARK: - Description

    private func descriptionBlock(_ description: String) -> some View {
        VStack(alignment: .leading, spacing: 8) {
            Text(L.t(sv: "Beskrivning", nb: "Beskrivelse"))
                .font(.system(size: 15, weight: .bold))
                .foregroundStyle(.primary)
            Text(description)
                .font(.system(size: 15))
                .foregroundStyle(.primary)
                .fixedSize(horizontal: false, vertical: true)
        }
    }

    // MARK: - Facts grid

    private var factsBlock: some View {
        VStack(spacing: 0) {
            factRow(title: L.t(sv: "Kategori", nb: "Kategori"), value: row.category)
            if let brand = row.userBrand, !brand.isEmpty {
                Divider()
                factRow(title: L.t(sv: "Varumärke", nb: "Merke"), value: brand)
            }
            if let condition = SellCondition.localizedTitle(raw: row.userCondition) {
                Divider()
                factRow(title: L.t(sv: "Skick", nb: "Tilstand"), value: condition)
            }
            if !row.colors.isEmpty {
                Divider()
                factRow(title: L.t(sv: "Färg", nb: "Farge"), value: row.colors.joined(separator: ", "))
            }
            if let material = row.material, !material.isEmpty {
                Divider()
                factRow(title: L.t(sv: "Material", nb: "Materiale"), value: material)
            }
            if let size = row.packageSize, !size.isEmpty {
                Divider()
                factRow(title: L.t(sv: "Paketstorlek", nb: "Pakkestørrelse"), value: size)
            }
            if let created = row.createdAt {
                let rel = relativeDate(created)
                if !rel.isEmpty {
                    Divider()
                    factRow(title: L.t(sv: "Uppladdad", nb: "Lastet opp"), value: rel)
                }
            }
        }
    }

    private func factRow(title: String, value: String) -> some View {
        HStack {
            Text(title)
                .font(.system(size: 15))
                .foregroundStyle(.primary)
            Spacer()
            Text(value)
                .font(.system(size: 15))
                .foregroundStyle(.secondary)
                .multilineTextAlignment(.trailing)
            Image(systemName: "chevron.right")
                .font(.system(size: 12, weight: .semibold))
                .foregroundStyle(.tertiary)
        }
        .padding(.vertical, 14)
    }

    // MARK: - Legal / köparskydd block

    private var legalBlock: some View {
        VStack(alignment: .leading, spacing: 10) {
            Text(L.t(
                sv: "Köparskydd",
                nb: "Kjøperbeskyttelse"
            ))
            .font(.system(size: 15, weight: .bold))

            Text(L.t(
                sv: "Mer specifikt innebär detta att ångerrätten enligt 10 § Lag (2005:59) om distansavtal och avtal utanför affärslokaler inte är tillämplig på köpet. Därtill gäller inte heller det EU-rättsligt harmoniserade ansvaret gentemot en köpare som är konsument för bristande avtalsenlighet som visar sig inom två år.\n\nAllmänna regler och praxis enligt köplagen är emellertid tillämpliga på köp mellan privatpersoner. En köpare som mot bakgrund av köparens rätt att få en avtalsenlig vara anser att det föreligger fel i en vara måste reklamera felet till säljaren senast två år från leverans av varan (32 § Köplagen). Vidare är 18 § köplagen, där det framgår att en vara ska motsvara det som avtalats mellan parterna samt vara fri från dolda fel, tillämplig på köpet (om inte detta avtalats bort av köparen). En köpares val av påföljder vid fel i vara framgår av bestämmelserna i 31-40 § köplagen. Köp som görs genom \u{201C}Köp nu\u{201D}-knappen omfattas även av Köparskydd.",
                nb: "Kjøp mellom privatpersoner omfattes av kjøpsloven og ikke angreretten i fjernsalgsloven. Kjøperen må reklamere på feil innen to år fra levering (32 § kjøpsloven). Kjøp gjennom «Kjøp nå»-knappen omfattes også av Kjøperbeskyttelsen."
            ))
            .font(.system(size: 13))
            .foregroundStyle(.secondary)
            .fixedSize(horizontal: false, vertical: true)
        }
        .padding(16)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(Color(.secondarySystemBackground))
        .clipShape(RoundedRectangle(cornerRadius: 14))
    }

    // MARK: - AdMob ad

    @ViewBuilder
    private var adBlock: some View {
        #if canImport(GoogleMobileAds)
        if AdMobService.isAdsEnabled,
           !(authViewModel.currentUser?.isProMember ?? false),
           let nativeAd = adMobService.nativeAds.first {
            VStack(spacing: 8) {
                Text(L.t(sv: "Annonsering", nb: "Annonsering"))
                    .font(.system(size: 12))
                    .foregroundStyle(.secondary)

                NativeAdCard(nativeAd: nativeAd)
                    .frame(maxWidth: .infinity)
            }
        }
        #else
        EmptyView()
        #endif
    }

    // MARK: - Related feed

    @ViewBuilder
    private var feedBlock: some View {
        if !otherListings.isEmpty {
            VStack(alignment: .leading, spacing: 14) {
                Text(L.t(sv: "Fler annonser", nb: "Flere annonser"))
                    .font(.system(size: 18, weight: .bold))

                LazyVGrid(columns: columns, spacing: 16) {
                    ForEach(otherListings) { other in
                        NavigationLink(value: MarketplaceRoute.listing(other)) {
                            CommunityListingCard(row: other)
                        }
                        .buttonStyle(PressableCardButtonStyle())
                        .modifier(MarketplaceHeroSourceModifier(id: other.id, namespace: heroNS))
                    }
                }
            }
        }
    }

    // MARK: - Section layout helpers

    @ViewBuilder
    private func sectionContainer<Content: View>(@ViewBuilder _ content: () -> Content) -> some View {
        VStack(alignment: .leading, spacing: 14) {
            content()
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(.horizontal, 16)
        .padding(.vertical, 18)
    }

    private var sectionSeparator: some View {
        Rectangle()
            .fill(Color(.systemGray6))
            .frame(height: 10)
            .frame(maxWidth: .infinity)
    }

    // MARK: - Seller block

    @ViewBuilder
    private var sellerBlock: some View {
        HStack(spacing: 12) {
            Button { showSellerProfile = true } label: {
                ProfileImage(
                    url: sellerProfile?.avatarUrl,
                    size: 48,
                    isPro: sellerProfile?.isProMember ?? false
                )
            }
            .buttonStyle(.plain)

            Button { showSellerProfile = true } label: {
                Text(sellerProfile?.name ?? "—")
                    .font(.system(size: 16, weight: .semibold))
                    .foregroundColor(.primary)
                    .lineLimit(1)
            }
            .buttonStyle(.plain)

            Spacer(minLength: 8)

            Button { openConversation() } label: {
                HStack(spacing: 6) {
                    if isCreatingConversation { ProgressView().tint(accent) }
                    Text(L.t(sv: "Kontakta säljaren", nb: "Kontakt selger"))
                        .font(.system(size: 14, weight: .semibold))
                }
                .foregroundStyle(accent)
                .padding(.horizontal, 14)
                .padding(.vertical, 10)
                .background(
                    RoundedRectangle(cornerRadius: 10)
                        .stroke(accent, lineWidth: 1.5)
                )
            }
            .disabled(isCreatingConversation)
        }
    }

    // MARK: - Buyer protection fee block

    private var buyerProtectionFeeBlock: some View {
        HStack(alignment: .top, spacing: 12) {
            ZStack {
                Circle()
                    .fill(Color(.systemGray5))
                    .frame(width: 40, height: 40)
                Image(systemName: "checkmark.shield.fill")
                    .font(.system(size: 18, weight: .semibold))
                    .foregroundColor(.primary)
            }
            VStack(alignment: .leading, spacing: 4) {
                Text(L.t(sv: "Avgift för köparskydd", nb: "Avgift for kjøperbeskyttelse"))
                    .font(.system(size: 15, weight: .bold))
                Text(L.t(
                    sv: "Vårt köparskydd läggs till mot en avgift för varje köp som görs med knappen \"Köp nu\". Köparskyddet inkluderar vår återbetalningspolicy.",
                    nb: "Kjøperbeskyttelsen legges til mot en avgift for hvert kjøp som gjøres med «Kjøp nå»-knappen. Den inkluderer refusjonspolicyen."
                ))
                .font(.system(size: 13))
                .foregroundColor(.secondary)
                .fixedSize(horizontal: false, vertical: true)
            }
            Spacer(minLength: 0)
        }
    }

    // MARK: - Data

    private func loadSellerProfile() async {
        let idString = row.userId.uuidString
        if let profile = try? await ProfileService.shared.fetchUserProfile(userId: idString) {
            await MainActor.run {
                var t = Transaction()
                t.disablesAnimations = true
                withTransaction(t) {
                    self.sellerProfile = profile
                }
            }
        }
    }

    private func loadOtherListings() async {
        do {
            let rows = try await CommunityListingsService.shared.fetchAcceptedListings(limit: 40)
            await MainActor.run {
                let filtered = rows.filter { $0.id != row.id }
                var t = Transaction()
                t.disablesAnimations = true
                withTransaction(t) {
                    otherListings = filtered
                }
                ImageCacheManager.shared.prefetch(urls: filtered.flatMap { $0.imageUrls })
            }
        } catch {
            print("Failed to load related community listings: \(error)")
        }
    }

    // MARK: - Helpers

    private var formattedPrice: String {
        if let price = row.priceSEK { return "\(price),00 kr" }
        return row.finalPriceRange ?? "—"
    }

    private var buyerProtectionTotalText: String? {
        guard let price = row.priceSEK else { return nil }
        return MarketplacePricing.buyerTotalFormatted(priceSEK: price)
    }

    private func relativeDate(_ isoString: String) -> String {
        let formatter = ISO8601DateFormatter()
        formatter.formatOptions = [.withInternetDateTime, .withFractionalSeconds]
        var date = formatter.date(from: isoString)
        if date == nil {
            formatter.formatOptions = [.withInternetDateTime]
            date = formatter.date(from: isoString)
        }
        guard let parsed = date else { return "" }
        let elapsed = Int(Date().timeIntervalSince(parsed))
        if elapsed < 60 { return L.t(sv: "för \(max(elapsed, 1)) sek sedan", nb: "\(max(elapsed, 1)) sek siden") }
        let minutes = elapsed / 60
        if minutes < 60 { return L.t(sv: "för \(minutes) min sedan", nb: "\(minutes) min siden") }
        let hours = minutes / 60
        if hours < 24 { return L.t(sv: "för \(hours) timmar sedan", nb: "\(hours) timer siden") }
        let days = hours / 24
        if days < 7 { return L.t(sv: "för \(days) dagar sedan", nb: "\(days) dager siden") }
        let weeks = days / 7
        if weeks < 4 { return L.t(sv: "för \(weeks) veckor sedan", nb: "\(weeks) uker siden") }
        let months = days / 30
        return L.t(sv: "för \(months) månader sedan", nb: "\(months) måneder siden")
    }
}
