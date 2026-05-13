import SwiftUI

/// Admin-vy för att avgöra öppna marketplace-tvister. Visar order-detaljer,
/// köparens dispute-anledning, och tre beslutsknappar:
///   - Refunda köparen (full)
///   - Släpp pengar till säljaren
///   - Partiell refund (admin matar in belopp + anteckning)
///
/// Anropas från `ConsignmentSubmissionsAdminView` när det finns öppna
/// tvister. Kräver att den inloggade är admin (RLS sköter datavisningen).
struct AdminDisputesView: View {
    @State private var disputes: [MarketplaceOrderRow] = []
    @State private var isLoading = false
    @State private var errorText: String?
    @State private var actionInProgressId: UUID?
    @State private var actionResult: String?

    @State private var resolvingOrder: MarketplaceOrderRow?
    @State private var pendingDecision: Decision?
    @State private var partialAmountSEK: String = ""
    @State private var adminNote: String = ""

    enum Decision: String { case refundBuyer = "refund_buyer"
        case releaseSeller = "release_seller"
        case partialRefund = "partial_refund" }

    var body: some View {
        List {
            if isLoading && disputes.isEmpty {
                Section { ProgressView().frame(maxWidth: .infinity) }
            }
            if let actionResult {
                Section {
                    Text(actionResult)
                        .font(.system(size: 13))
                        .foregroundStyle(.green)
                }
            }
            if let errorText {
                Section {
                    Text(errorText)
                        .font(.system(size: 13))
                        .foregroundStyle(.red)
                }
            }
            if disputes.isEmpty && !isLoading {
                Section {
                    VStack(spacing: 8) {
                        Image(systemName: "checkmark.shield.fill")
                            .font(.system(size: 36))
                            .foregroundStyle(.green)
                        Text("Inga öppna tvister")
                            .font(.system(size: 16, weight: .semibold))
                    }
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 24)
                }
            }
            ForEach(disputes) { order in
                Section(header: Text("Order \(order.id.uuidString.prefix(8))").font(.system(size: 13, weight: .semibold))) {
                    disputeRow(order: order)
                }
            }
        }
        .navigationTitle("Öppna tvister")
        .navigationBarTitleDisplayMode(.inline)
        .refreshable { await load() }
        .task { await load() }
        .sheet(item: $resolvingOrder) { order in
            resolveSheet(order: order)
        }
    }

    @ViewBuilder
    private func disputeRow(order: MarketplaceOrderRow) -> some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack {
                Text(MarketplacePricing.formatSEK(Double(order.amountBuyerTotal) / 100.0))
                    .font(.system(size: 15, weight: .semibold))
                Spacer()
                if let opened = order.disputeOpenedAtDate {
                    Text(Self.dateFormatter.string(from: opened))
                        .font(.system(size: 11))
                        .foregroundStyle(.secondary)
                }
            }
            if let reason = order.disputeReason, !reason.isEmpty {
                Text(reason)
                    .font(.system(size: 13))
                    .foregroundStyle(.secondary)
            }
            HStack(spacing: 6) {
                Label("Köpare", systemImage: "person.fill")
                    .font(.system(size: 11, weight: .semibold))
                    .foregroundStyle(.secondary)
                Text(order.buyerId.uuidString.prefix(8))
                    .font(.system(size: 11, design: .monospaced))
                Spacer()
                Label("Säljare", systemImage: "tag.fill")
                    .font(.system(size: 11, weight: .semibold))
                    .foregroundStyle(.secondary)
                Text(order.sellerId.uuidString.prefix(8))
                    .font(.system(size: 11, design: .monospaced))
            }
            HStack(spacing: 8) {
                resolveButton(order: order, decision: .refundBuyer, label: "Refunda köpare", color: .red)
                resolveButton(order: order, decision: .releaseSeller, label: "Släpp till säljare", color: .green)
                resolveButton(order: order, decision: .partialRefund, label: "Partiell", color: .orange)
            }
            if actionInProgressId == order.id {
                ProgressView().padding(.top, 4)
            }
        }
        .padding(.vertical, 6)
    }

    private func resolveButton(
        order: MarketplaceOrderRow,
        decision: Decision,
        label: String,
        color: Color
    ) -> some View {
        Button {
            partialAmountSEK = ""
            adminNote = ""
            pendingDecision = decision
            resolvingOrder = order
        } label: {
            Text(label)
                .font(.system(size: 11, weight: .semibold))
                .foregroundColor(.white)
                .frame(maxWidth: .infinity)
                .padding(.vertical, 8)
                .background(color)
                .clipShape(RoundedRectangle(cornerRadius: 8))
        }
        .buttonStyle(.plain)
        .disabled(actionInProgressId != nil)
    }

    @ViewBuilder
    private func resolveSheet(order: MarketplaceOrderRow) -> some View {
        NavigationStack {
            Form {
                Section(header: Text("Order")) {
                    HStack {
                        Text("Belopp")
                        Spacer()
                        Text(MarketplacePricing.formatSEK(Double(order.amountBuyerTotal) / 100.0))
                            .foregroundStyle(.secondary)
                    }
                    if let reason = order.disputeReason {
                        Text(reason)
                            .font(.system(size: 13))
                            .foregroundStyle(.secondary)
                    }
                }
                Section(header: Text("Beslut")) {
                    Text(decisionLabel(pendingDecision))
                        .font(.system(size: 14, weight: .semibold))
                }
                if pendingDecision == .partialRefund {
                    Section(header: Text("Refund-belopp i SEK")) {
                        TextField("0", text: $partialAmountSEK)
                            .keyboardType(.numberPad)
                    }
                }
                Section(header: Text("Anteckning till båda parter")) {
                    TextField("Frivillig kommentar", text: $adminNote, axis: .vertical)
                        .lineLimit(3...6)
                }
                Section {
                    Button {
                        Task { await submit(order: order) }
                    } label: {
                        HStack {
                            Spacer()
                            Text("Bekräfta beslut")
                                .font(.system(size: 16, weight: .semibold))
                                .foregroundColor(.white)
                            Spacer()
                        }
                        .padding(.vertical, 6)
                    }
                    .listRowBackground(submitDisabled() ? Color.gray.opacity(0.4) : Color.black)
                    .disabled(submitDisabled())
                }
            }
            .navigationTitle("Bekräfta beslut")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Avbryt") { resolvingOrder = nil }
                }
            }
        }
        .presentationDetents([.large, .medium])
    }

    private func submitDisabled() -> Bool {
        if actionInProgressId != nil { return true }
        if pendingDecision == .partialRefund {
            let val = Int(partialAmountSEK.filter(\.isNumber)) ?? 0
            if val <= 0 { return true }
        }
        return false
    }

    private func decisionLabel(_ d: Decision?) -> String {
        switch d {
        case .refundBuyer: return "Full refund till köpare"
        case .releaseSeller: return "Släpp pengarna till säljaren"
        case .partialRefund: return "Partiell refund + resten till säljaren"
        case nil: return ""
        }
    }

    // MARK: - Networking

    private func load() async {
        isLoading = true
        defer { isLoading = false }
        do {
            disputes = try await MarketplaceOrdersService.shared.fetchOpenDisputes()
            errorText = nil
        } catch {
            errorText = error.localizedDescription
        }
    }

    private func submit(order: MarketplaceOrderRow) async {
        guard let decision = pendingDecision else { return }
        actionInProgressId = order.id
        defer { actionInProgressId = nil }
        do {
            let refundOre: Int?
            if decision == .partialRefund {
                let sek = Int(partialAmountSEK.filter(\.isNumber)) ?? 0
                refundOre = sek * 100
            } else {
                refundOre = nil
            }
            _ = try await MarketplaceOrdersService.shared.resolveDispute(
                orderId: order.id,
                decision: decision.rawValue,
                refundOre: refundOre,
                note: adminNote.isEmpty ? nil : adminNote
            )
            resolvingOrder = nil
            actionResult = "Beslut registrerat: \(decisionLabel(decision))"
            await load()
        } catch {
            errorText = error.localizedDescription
        }
    }

    private static let dateFormatter: DateFormatter = {
        let f = DateFormatter()
        f.locale = Locale(identifier: "sv_SE")
        f.dateFormat = "d MMM HH:mm"
        return f
    }()
}
