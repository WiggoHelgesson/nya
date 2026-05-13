import SwiftUI
import UIKit

/// Navigation destination for saving seller pickup address during listing creation.
struct SellerPickupAddressPickerView: View {
    @ObservedObject var model: SellFlowModel
    @Binding var path: NavigationPath

    var body: some View {
        SellerPickupAddressForm(
            initialAddress: model.pickupAddress,
            dismissOnSave: false,
            dismissOnCancel: false,
            onSave: { address in
                try await ShipmondoShippingService.shared.saveSellerPickupAddress(address)
                await MainActor.run {
                    model.pickupAddress = address
                    model.hasSavedPickupAddress = true
                    if !path.isEmpty { path.removeLast() }
                }
            },
            onCancel: {
                if !path.isEmpty { path.removeLast() }
            }
        )
    }
}

// MARK: - Seller pickup address form

/// Pickup address used as Shipmondo sender when booking marketplace shipments.
struct SellerPickupAddressForm: View {
    /// Prefill when editing from Settings or when returning to the form.
    var initialAddress: ShippingAddress?
    /// When `false`, caller pops navigation / closes UI after `onSave` completes (e.g. `path.removeLast()`).
    var dismissOnSave: Bool = true
    /// When `false`, only `onCancel()` runs (e.g. programmatic `path.removeLast()` without inner `dismiss()`).
    var dismissOnCancel: Bool = true
    var onSave: (ShippingAddress) async throws -> Void
    var onCancel: () -> Void

    @Environment(\.dismiss) private var dismiss

    @State private var saveError: String?
    @State private var fullName: String = ""
    @State private var phone: String = ""
    @State private var street: String = ""
    @State private var postalCode: String = ""
    @State private var city: String = ""

    private var canSave: Bool {
        !fullName.trimmingCharacters(in: .whitespaces).isEmpty
            && !phone.trimmingCharacters(in: .whitespaces).isEmpty
            && !street.trimmingCharacters(in: .whitespaces).isEmpty
            && postalCode.filter(\.isNumber).count >= 5
            && !city.trimmingCharacters(in: .whitespaces).isEmpty
    }

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 18) {
                if let saveError {
                    Text(saveError)
                        .font(.system(size: 13))
                        .foregroundStyle(.red)
                        .fixedSize(horizontal: false, vertical: true)
                }
                Text(L.t(
                    sv: "Vi behöver din upphämtningsadress så att Shipmondo kan boka frakt automatiskt när köparen slutför köpet.",
                    nb: "Vi trenger din hentadresse så Shipmondo kan booke frakt automatisk når kjøperen fullfører."
                ))
                .font(.system(size: 14))
                .foregroundStyle(.secondary)
                .fixedSize(horizontal: false, vertical: true)

                field(
                    title: L.t(sv: "För- och efternamn", nb: "Fornavn og etternavn"),
                    text: $fullName,
                    keyboard: .default
                )
                field(
                    title: L.t(sv: "Telefon", nb: "Telefon"),
                    text: $phone,
                    keyboard: .phonePad
                )
                field(
                    title: L.t(sv: "Gata och nummer", nb: "Gate og nummer"),
                    text: $street,
                    keyboard: .default
                )
                HStack(spacing: 12) {
                    field(
                        title: L.t(sv: "Postnummer", nb: "Postnummer"),
                        text: $postalCode,
                        keyboard: .numberPad
                    )
                    field(
                        title: L.t(sv: "Ort", nb: "By"),
                        text: $city,
                        keyboard: .default
                    )
                }
            }
            .padding(.horizontal, 20)
            .padding(.top, 16)
            .padding(.bottom, 24)
        }
        .background(Color(.systemBackground).ignoresSafeArea())
        .navigationTitle(L.t(sv: "Upphämtningsadress", nb: "Henteadresse"))
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            ToolbarItem(placement: .navigationBarLeading) {
                Button(L.t(sv: "Avbryt", nb: "Avbryt")) {
                    onCancel()
                    if dismissOnCancel {
                        dismiss()
                    }
                }
                .foregroundColor(.primary)
            }
            ToolbarItem(placement: .navigationBarTrailing) {
                Button {
                    guard canSave else { return }
                    let address = ShippingAddress(
                        fullName: fullName.trimmingCharacters(in: .whitespaces),
                        phone: phone.trimmingCharacters(in: .whitespaces),
                        street: street.trimmingCharacters(in: .whitespaces),
                        postalCode: postalCode.filter(\.isNumber),
                        city: city.trimmingCharacters(in: .whitespaces),
                        country: "SE"
                    )
                    Task {
                        await MainActor.run { saveError = nil }
                        do {
                            try await onSave(address)
                            if dismissOnSave {
                                await MainActor.run { dismiss() }
                            }
                        } catch {
                            await MainActor.run {
                                saveError = error.localizedDescription
                            }
                        }
                    }
                } label: {
                    Text(L.t(sv: "Spara", nb: "Lagre"))
                        .font(.system(size: 15, weight: .bold))
                        .foregroundColor(canSave ? .black : .secondary)
                }
                .disabled(!canSave)
            }
        }
        .onAppear {
            if let a = initialAddress {
                fullName = a.fullName
                phone = a.phone
                street = a.street
                postalCode = a.postalCode
                city = a.city
            }
        }
    }

    @ViewBuilder
    private func field(
        title: String,
        text: Binding<String>,
        keyboard: UIKeyboardType
    ) -> some View {
        VStack(alignment: .leading, spacing: 6) {
            Text(title)
                .font(.system(size: 12, weight: .semibold))
                .foregroundStyle(.secondary)
            TextField("", text: text)
                .keyboardType(keyboard)
                .font(.system(size: 16))
                .padding(.horizontal, 12)
                .padding(.vertical, 12)
                .background(Color(.systemBackground))
                .overlay(
                    RoundedRectangle(cornerRadius: 10, style: .continuous)
                        .stroke(Color.black.opacity(0.12), lineWidth: 1)
                )
        }
    }
}
