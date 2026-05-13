import SwiftUI

struct SimulatePurchaseAdminView: View {
    @EnvironmentObject private var authViewModel: AuthViewModel
    @Environment(\.dismiss) private var dismiss

    @State private var listings: [ConsignmentSubmissionRow] = []
    @State private var selectedListing: ConsignmentSubmissionRow?
    @State private var showConfirmDialog = false
    @State private var isLoading = false
    @State private var isRunning = false
    @State private var includeShippingBooking = true
    @State private var enableReplayCheck = true
    @State private var errorText: String?
    @State private var successText: String?

    var body: some View {
        NavigationStack {
            List {
                Section {
                    Toggle(
                        L.t(
                            sv: "Boka fraktsedel via Shipmondo",
                            nb: "Book fraktseddel via Shipmondo"
                        ),
                        isOn: $includeShippingBooking
                    )
                    .disabled(isRunning)

                    Toggle(
                        L.t(
                            sv: "Kör idempotens-check (dubbelkör webhooksteg)",
                            nb: "Kjør idempotenssjekk (dobbelkjør webhooksteg)"
                        ),
                        isOn: $enableReplayCheck
                    )
                    .disabled(isRunning)

                    Button {
                        Task { await runDeadlineSweep() }
                    } label: {
                        HStack {
                            if isRunning { ProgressView() }
                            Text(L.t(
                                sv: "Kör deadline-cron på testordrar",
                                nb: "Kjør deadline-cron på testordrer"
                            ))
                        }
                    }
                    .disabled(isRunning)
                } footer: {
                    Text(
                        L.t(
                            sv: "Detta kör ett riktigt efterköpsflöde i databasen men markerar ordern som test.",
                            nb: "Dette kjører en ekte etterkjøpsflyt i databasen, men markerer ordren som test."
                        )
                    )
                }

                if isLoading {
                    Section {
                        HStack {
                            ProgressView()
                            Text(L.t(sv: "Laddar annonser...", nb: "Laster annonser..."))
                        }
                    }
                } else {
                    Section(header: Text(L.t(sv: "Välj annons att simulera köp på", nb: "Velg annonse for simulert kjøp"))) {
                        ForEach(listings, id: \.id) { listing in
                            Button {
                                selectedListing = listing
                                showConfirmDialog = true
                            } label: {
                                VStack(alignment: .leading, spacing: 4) {
                                    Text(listing.title ?? L.t(sv: "Annons utan titel", nb: "Annonse uten tittel"))
                                        .font(.system(size: 15, weight: .semibold))
                                        .foregroundStyle(.primary)
                                        .lineLimit(2)
                                    HStack {
                                        Text("ID: \(listing.id.uuidString.prefix(8))")
                                        Spacer()
                                        if let price = listing.priceSEK {
                                            Text("\(price) kr")
                                        }
                                    }
                                    .font(.system(size: 12))
                                    .foregroundStyle(.secondary)
                                }
                                .padding(.vertical, 2)
                            }
                            .buttonStyle(.plain)
                            .disabled(isRunning)
                        }
                    }
                }

                if let successText {
                    Section {
                        Text(successText)
                            .font(.system(size: 13))
                            .foregroundStyle(.green)
                            .fixedSize(horizontal: false, vertical: true)
                    } header: {
                        Text(L.t(sv: "Resultat", nb: "Resultat"))
                    }
                }

                if let errorText {
                    Section {
                        Text(errorText)
                            .font(.system(size: 13))
                            .foregroundStyle(.red)
                            .fixedSize(horizontal: false, vertical: true)
                    } header: {
                        Text(L.t(sv: "Fel", nb: "Feil"))
                    }
                }
            }
            .navigationTitle(L.t(sv: "Simulera köp", nb: "Simuler kjøp"))
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button(L.t(sv: "Stäng", nb: "Lukk")) { dismiss() }
                }
                ToolbarItem(placement: .primaryAction) {
                    Button {
                        Task { await reloadListings() }
                    } label: {
                        Image(systemName: "arrow.clockwise")
                    }
                    .disabled(isLoading || isRunning)
                }
            }
            .task { await reloadListings() }
            .confirmationDialog(
                L.t(sv: "Bekräfta testköp", nb: "Bekreft testkjøp"),
                isPresented: $showConfirmDialog
            ) {
                Button(L.t(sv: "Kör simulering", nb: "Kjør simulering")) {
                    guard let listing = selectedListing else { return }
                    Task { await runSimulation(for: listing) }
                }
                Button(L.t(sv: "Avbryt", nb: "Avbryt"), role: .cancel) {}
            } message: {
                Text(
                    L.t(
                        sv: "Skapa testorder för \"\(selectedListing?.title ?? "annons")\" som inloggad admin-köpare?",
                        nb: "Opprette testordre for \"\(selectedListing?.title ?? "annonse")\" som innlogget admin-kjøper?"
                    )
                )
            }
        }
    }

    private func reloadListings() async {
        await MainActor.run {
            isLoading = true
            errorText = nil
            successText = nil
        }
        do {
            let all = try await CommunityListingsService.shared.fetchAcceptedListings(limit: 60)
            let myId = UUID(uuidString: authViewModel.currentUser?.id ?? "")
            let filtered = all.filter { row in
                if row.soldAt != nil { return false }
                if let myId { return row.userId != myId }
                return true
            }
            await MainActor.run {
                listings = filtered
                isLoading = false
            }
        } catch {
            await MainActor.run {
                errorText = error.localizedDescription
                isLoading = false
            }
        }
    }

    private func runSimulation(for listing: ConsignmentSubmissionRow) async {
        await MainActor.run {
            isRunning = true
            errorText = nil
            successText = nil
        }
        do {
            let result = try await MarketplaceSimulationService.shared.simulatePurchase(
                listingId: listing.id,
                bookShipping: includeShippingBooking,
                replay: enableReplayCheck
            )
            let orderShort = String(result.orderId.prefix(8))
            let shippingText = result.bookedShipping
                ? L.t(sv: "Frakt bokad.", nb: "Frakt booket.")
                : L.t(sv: "Frakt bokades inte.", nb: "Frakt ble ikke booket.")
            let replayText: String
            if enableReplayCheck {
                replayText = (result.replaySecondPassSkipped ?? false)
                    ? L.t(sv: "Idempotens OK (andra passet skipades).", nb: "Idempotens OK (andre pass ble hoppet over).")
                    : L.t(sv: "Idempotens-varning: andra passet skipades inte.", nb: "Idempotens-varsel: andre pass ble ikke hoppet over.")
            } else {
                replayText = ""
            }
            await MainActor.run {
                successText = L.t(
                    sv: "Testköp klart. Order \(orderShort). \(shippingText) \(replayText)",
                    nb: "Testkjøp ferdig. Ordre \(orderShort). \(shippingText) \(replayText)"
                )
                isRunning = false
                listings.removeAll { $0.id == listing.id }
            }
        } catch {
            await MainActor.run {
                errorText = error.localizedDescription
                isRunning = false
            }
        }
    }

    private func runDeadlineSweep() async {
        await MainActor.run {
            isRunning = true
            errorText = nil
            successText = nil
        }
        do {
            let result = try await MarketplaceSimulationService.shared.runDeadlineSweep(
                limit: 200,
                includeTestOrders: true
            )
            let summary = L.t(
                sv: "Cron körd. reminders24=\(result.shipReminders ?? 0), reminders48=\(result.shipReminders48h ?? 0), autoCancel=\(result.autoCancelled ?? 0), autoRelease=\(result.autoReleased ?? 0), errors=\(result.errors ?? 0).",
                nb: "Cron kjørt. reminders24=\(result.shipReminders ?? 0), reminders48=\(result.shipReminders48h ?? 0), autoCancel=\(result.autoCancelled ?? 0), autoRelease=\(result.autoReleased ?? 0), errors=\(result.errors ?? 0)."
            )
            await MainActor.run {
                successText = summary
                isRunning = false
            }
        } catch {
            await MainActor.run {
                errorText = error.localizedDescription
                isRunning = false
            }
        }
    }
}
