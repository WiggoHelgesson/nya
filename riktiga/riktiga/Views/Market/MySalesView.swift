import SwiftUI
import Supabase
import PostgREST

// MARK: - Data Models

struct SellerBag: Codable, Identifiable {
    let id: String
    let userId: String
    let bagCode: String
    let status: String
    let quantity: Int
    let createdAt: String
    let shippedAt: String?
    let receivedAt: String?
    let trackingUrl: String?
    let senderName: String?
    let senderEmail: String?

    enum CodingKeys: String, CodingKey {
        case id
        case userId = "user_id"
        case bagCode = "bag_code"
        case status
        case quantity
        case createdAt = "created_at"
        case shippedAt = "shipped_at"
        case receivedAt = "received_at"
        case trackingUrl = "tracking_url"
        case senderName = "sender_name"
        case senderEmail = "sender_email"
    }
}

struct SellerItem: Codable, Identifiable {
    let id: String
    let bagId: String
    let userId: String
    let shopifyProductId: String?
    let shopifyHandle: String?
    let title: String?
    let imageUrl: String?
    let price: Double
    let status: String
    let soldAt: String?
    let sellerShare: Double
    let adCost: Double
    let createdAt: String

    enum CodingKeys: String, CodingKey {
        case id
        case bagId = "bag_id"
        case userId = "user_id"
        case shopifyProductId = "shopify_product_id"
        case shopifyHandle = "shopify_handle"
        case title
        case imageUrl = "image_url"
        case price
        case status
        case soldAt = "sold_at"
        case sellerShare = "seller_share"
        case adCost = "ad_cost"
        case createdAt = "created_at"
    }
}

// MARK: - My Sales View

struct MySalesView: View {
    @EnvironmentObject var authViewModel: AuthViewModel
    @Environment(\.dismiss) private var dismiss
    @Environment(\.colorScheme) private var colorScheme

    @State private var bags: [SellerBag] = []
    @State private var itemsByBag: [String: [SellerItem]] = [:]
    @State private var expandedBagId: String?
    @State private var isLoading = true
    @State private var totalEarned: Double = 0
    @State private var itemsListed: Int = 0
    @State private var itemsSold: Int = 0

    var body: some View {
        VStack(spacing: 0) {
            header
            
            if isLoading {
                Spacer()
                ProgressView()
                Spacer()
            } else if bags.isEmpty {
                emptyState
            } else {
                ScrollView {
                    VStack(spacing: 16) {
                        summaryCards
                            .padding(.horizontal, 16)
                            .padding(.top, 16)

                        ForEach(bags) { bag in
                            bagCard(bag)
                                .padding(.horizontal, 16)
                        }

                        Spacer(minLength: 40)
                    }
                }
            }
        }
        .presentationDetents([.large])
        .task { await loadData() }
    }

    // MARK: - Header

    private var header: some View {
        HStack {
            Button { dismiss() } label: {
                Image(systemName: "xmark")
                    .font(.system(size: 14, weight: .medium))
                    .foregroundColor(.primary)
            }

            Spacer()

            Text(L.t(sv: "Mina försäljningar", nb: "Mine salg"))
                .font(.system(size: 16, weight: .semibold))

            Spacer()

            Image(systemName: "xmark")
                .font(.system(size: 14, weight: .medium))
                .foregroundColor(.clear)
        }
        .padding(.horizontal, 20)
        .padding(.vertical, 14)
    }

    // MARK: - Summary

    private var summaryCards: some View {
        HStack(spacing: 12) {
            summaryCard(
                icon: "banknote",
                value: "\(Int(totalEarned)) kr",
                label: L.t(sv: "Intjänat", nb: "Tjent")
            )
            summaryCard(
                icon: "tag",
                value: "\(itemsListed)",
                label: L.t(sv: "Till salu", nb: "Til salgs")
            )
            summaryCard(
                icon: "checkmark.circle",
                value: "\(itemsSold)",
                label: L.t(sv: "Sålda", nb: "Solgt")
            )
        }
    }

    private func summaryCard(icon: String, value: String, label: String) -> some View {
        VStack(spacing: 6) {
            Image(systemName: icon)
                .font(.system(size: 18))
                .foregroundColor(Color(red: 0.3, green: 0.6, blue: 0.7))

            Text(value)
                .font(.system(size: 20, weight: .bold))

            Text(label)
                .font(.system(size: 12))
                .foregroundColor(.secondary)
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 16)
        .background(
            RoundedRectangle(cornerRadius: 14)
                .fill(colorScheme == .dark ? Color(red: 0.12, green: 0.12, blue: 0.12) : Color(.systemGray6))
        )
    }

    // MARK: - Empty State

    private var emptyState: some View {
        VStack(spacing: 16) {
            Spacer()

            Image(systemName: "shippingbox")
                .font(.system(size: 48))
                .foregroundColor(.secondary.opacity(0.5))

            Text(L.t(
                sv: "Inga påsar ännu",
                nb: "Ingen poser ennå"
            ))
            .font(.system(size: 18, weight: .bold))

            Text(L.t(
                sv: "När du skickar in en påse visas den här med status och intäkter",
                nb: "Når du sender inn en pose vises den her med status og inntekter"
            ))
            .font(.system(size: 14))
            .foregroundColor(.secondary)
            .multilineTextAlignment(.center)
            .padding(.horizontal, 40)

            Spacer()
        }
    }

    // MARK: - Bag Card

    private func bagCard(_ bag: SellerBag) -> some View {
        VStack(spacing: 0) {
            Button {
                withAnimation(.easeInOut(duration: 0.2)) {
                    expandedBagId = expandedBagId == bag.id ? nil : bag.id
                }
            } label: {
                HStack(spacing: 14) {
                    Image(systemName: "shippingbox.fill")
                        .font(.system(size: 22))
                        .foregroundColor(Color(red: 0.3, green: 0.6, blue: 0.7))
                        .frame(width: 40, height: 40)
                        .background(Color(red: 0.9, green: 0.96, blue: 0.97))
                        .clipShape(RoundedRectangle(cornerRadius: 10))

                    VStack(alignment: .leading, spacing: 3) {
                        HStack(spacing: 8) {
                            Text(bag.bagCode)
                                .font(.system(size: 16, weight: .bold))
                                .foregroundColor(.primary)

                            statusBadge(bag.status)
                        }

                        Text(formattedDate(bag.createdAt))
                            .font(.system(size: 13))
                            .foregroundColor(.secondary)
                    }

                    Spacer()

                    let items = itemsByBag[bag.id] ?? []
                    if !items.isEmpty {
                        Text("\(items.count) \(L.t(sv: "varor", nb: "varer"))")
                            .font(.system(size: 13))
                            .foregroundColor(.secondary)
                    }

                    Image(systemName: expandedBagId == bag.id ? "chevron.up" : "chevron.down")
                        .font(.system(size: 12, weight: .medium))
                        .foregroundColor(.secondary)
                }
                .padding(16)
                .contentShape(Rectangle())
            }
            .buttonStyle(.plain)

            if expandedBagId == bag.id {
                expandedContent(for: bag)
            }
        }
        .background(
            RoundedRectangle(cornerRadius: 14)
                .fill(colorScheme == .dark ? Color(red: 0.12, green: 0.12, blue: 0.12) : Color(.systemGray6))
        )
        .clipShape(RoundedRectangle(cornerRadius: 14))
    }

    // MARK: - Expanded Content

    private func expandedContent(for bag: SellerBag) -> some View {
        VStack(spacing: 0) {
            Divider().padding(.horizontal, 16)

            let items = itemsByBag[bag.id] ?? []

            if items.isEmpty {
                VStack(spacing: 8) {
                    Image(systemName: "clock")
                        .font(.system(size: 24))
                        .foregroundColor(.secondary.opacity(0.5))

                    Text(L.t(
                        sv: "Inga varor uppladdade ännu",
                        nb: "Ingen varer lastet opp ennå"
                    ))
                    .font(.system(size: 14))
                    .foregroundColor(.secondary)

                    Text(L.t(
                        sv: "Varor visas här när de läggs upp till salu",
                        nb: "Varer vises her når de legges ut for salg"
                    ))
                    .font(.system(size: 12))
                    .foregroundColor(.secondary.opacity(0.7))
                }
                .padding(.vertical, 20)
            } else {
                ForEach(items) { item in
                    itemRow(item)
                }
            }

            if let trackingUrl = bag.trackingUrl, !trackingUrl.isEmpty,
               let url = URL(string: trackingUrl) {
                Divider().padding(.horizontal, 16)

                Link(destination: url) {
                    HStack(spacing: 8) {
                        Image(systemName: "location.circle")
                            .font(.system(size: 14))
                        Text(L.t(sv: "Spåra paket", nb: "Spor pakke"))
                            .font(.system(size: 14, weight: .medium))
                    }
                    .foregroundColor(Color(red: 0.3, green: 0.6, blue: 0.7))
                    .padding(.vertical, 12)
                    .frame(maxWidth: .infinity)
                }
            }
        }
    }

    // MARK: - Item Row

    private func itemRow(_ item: SellerItem) -> some View {
        HStack(spacing: 12) {
            if let imageUrl = item.imageUrl, !imageUrl.isEmpty, let url = URL(string: imageUrl) {
                AsyncImage(url: url) { phase in
                    switch phase {
                    case .success(let img):
                        img.resizable().scaledToFill()
                    default:
                        Color(.systemGray5)
                    }
                }
                .frame(width: 50, height: 50)
                .clipShape(RoundedRectangle(cornerRadius: 8))
            } else {
                RoundedRectangle(cornerRadius: 8)
                    .fill(Color(.systemGray5))
                    .frame(width: 50, height: 50)
            }

            VStack(alignment: .leading, spacing: 3) {
                Text(item.title ?? L.t(sv: "Okänd vara", nb: "Ukjent vare"))
                    .font(.system(size: 14, weight: .medium))
                    .lineLimit(1)

                HStack(spacing: 6) {
                    Text("\(Int(item.price)) kr")
                        .font(.system(size: 13))
                        .foregroundColor(.secondary)

                    statusBadge(item.status)
                }
            }

            Spacer()

            VStack(alignment: .trailing, spacing: 2) {
                Text("+\(Int(item.sellerShare)) kr")
                    .font(.system(size: 14, weight: .bold))
                    .foregroundColor(item.status == "sold" ? .green : .secondary)

                Text(L.t(sv: "din andel", nb: "din andel"))
                    .font(.system(size: 11))
                    .foregroundColor(.secondary)
            }
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 10)
    }

    // MARK: - Status Badge

    private func statusBadge(_ status: String) -> some View {
        let (text, color) = statusInfo(status)
        return Text(text)
            .font(.system(size: 11, weight: .medium))
            .foregroundColor(color)
            .padding(.horizontal, 8)
            .padding(.vertical, 3)
            .background(color.opacity(0.12))
            .clipShape(Capsule())
    }

    private func statusInfo(_ status: String) -> (String, Color) {
        switch status {
        case "ordered":
            return (L.t(sv: "Beställd", nb: "Bestilt"), .blue)
        case "shipped":
            return (L.t(sv: "Skickad", nb: "Sendt"), .orange)
        case "received":
            return (L.t(sv: "Mottagen", nb: "Mottatt"), .purple)
        case "processing":
            return (L.t(sv: "Behandlas", nb: "Behandles"), .yellow)
        case "listed":
            return (L.t(sv: "Upplagd", nb: "Lagt ut"), .green)
        case "completed":
            return (L.t(sv: "Färdig", nb: "Ferdig"), .gray)
        case "sold":
            return (L.t(sv: "Såld", nb: "Solgt"), .green)
        case "unsold":
            return (L.t(sv: "Osåld", nb: "Usolgt"), .red)
        case "donated":
            return (L.t(sv: "Donerad", nb: "Donert"), .gray)
        default:
            return (status, .secondary)
        }
    }

    // MARK: - Helpers

    private func formattedDate(_ iso: String) -> String {
        let formatter = ISO8601DateFormatter()
        formatter.formatOptions = [.withInternetDateTime, .withFractionalSeconds]
        guard let date = formatter.date(from: iso) else {
            formatter.formatOptions = [.withInternetDateTime]
            guard let date2 = formatter.date(from: iso) else { return iso }
            return formatDate(date2)
        }
        return formatDate(date)
    }

    private func formatDate(_ date: Date) -> String {
        let df = DateFormatter()
        df.locale = Locale(identifier: "sv_SE")
        df.dateFormat = "d MMM yyyy"
        return df.string(from: date)
    }

    // MARK: - Data Loading

    private func loadData() async {
        guard let userId = authViewModel.currentUser?.id else {
            isLoading = false
            return
        }

        do {
            let fetchedBags: [SellerBag] = try await SupabaseConfig.supabase
                .from("seller_bags")
                .select()
                .eq("user_id", value: userId)
                .order("created_at", ascending: false)
                .execute()
                .value

            bags = fetchedBags

            let bagIds = fetchedBags.map { $0.id }
            if !bagIds.isEmpty {
                let fetchedItems: [SellerItem] = try await SupabaseConfig.supabase
                    .from("seller_items")
                    .select()
                    .eq("user_id", value: userId)
                    .order("created_at", ascending: false)
                    .execute()
                    .value

                var grouped: [String: [SellerItem]] = [:]
                for item in fetchedItems {
                    grouped[item.bagId, default: []].append(item)
                }
                itemsByBag = grouped

                totalEarned = fetchedItems
                    .filter { $0.status == "sold" }
                    .reduce(0) { $0 + $1.sellerShare }
                itemsListed = fetchedItems.filter { $0.status == "listed" }.count
                itemsSold = fetchedItems.filter { $0.status == "sold" }.count
            }
        } catch {
            print("Failed to load seller data: \(error)")
        }

        isLoading = false
    }
}
