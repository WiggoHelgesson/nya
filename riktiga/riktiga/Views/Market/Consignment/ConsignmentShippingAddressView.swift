import SwiftUI

struct ConsignmentShippingAddressView: View {
    let submissionId: UUID
    let initialAddress: ShippingAddress?
    var onSaved: (ShippingAddress) -> Void = { _ in }

    @Environment(\.dismiss) private var dismiss

    @State private var fullName: String
    @State private var phone: String
    @State private var street: String
    @State private var postalCode: String
    @State private var city: String
    @State private var country: String

    @State private var isSaving = false
    @State private var errorText: String?

    init(
        submissionId: UUID,
        initialAddress: ShippingAddress? = nil,
        onSaved: @escaping (ShippingAddress) -> Void = { _ in }
    ) {
        self.submissionId = submissionId
        self.initialAddress = initialAddress
        self.onSaved = onSaved
        let base = initialAddress ?? .empty
        _fullName = State(initialValue: base.fullName)
        _phone = State(initialValue: base.phone)
        _street = State(initialValue: base.street)
        _postalCode = State(initialValue: base.postalCode)
        _city = State(initialValue: base.city)
        _country = State(initialValue: base.country.isEmpty ? "SE" : base.country)
    }

    var body: some View {
        NavigationStack {
            Form {
                Section(
                    header: Text(L.t(sv: "Avsändaradress", nb: "Avsenderadresse")),
                    footer: Text(L.t(
                        sv: "Vi använder adressen till din fraktsedel. Dubbelkolla att allt stämmer.",
                        nb: "Vi bruker adressen til fraktseddelen. Dobbeltsjekk at alt stemmer."
                    ))
                ) {
                    TextField(L.t(sv: "Fullständigt namn", nb: "Fullt navn"), text: $fullName)
                        .textContentType(.name)
                        .autocorrectionDisabled()
                    TextField(L.t(sv: "Telefon", nb: "Telefon"), text: $phone)
                        .keyboardType(.phonePad)
                        .textContentType(.telephoneNumber)
                    TextField(L.t(sv: "Gatuadress", nb: "Gateadresse"), text: $street)
                        .textContentType(.streetAddressLine1)
                    TextField(L.t(sv: "Postnummer", nb: "Postnummer"), text: $postalCode)
                        .keyboardType(.numberPad)
                        .textContentType(.postalCode)
                    TextField(L.t(sv: "Ort", nb: "Sted"), text: $city)
                        .textContentType(.addressCity)
                    TextField(L.t(sv: "Land", nb: "Land"), text: $country)
                        .autocapitalization(.allCharacters)
                        .autocorrectionDisabled()
                }

                if let errorText {
                    Section {
                        Label(errorText, systemImage: "exclamationmark.triangle.fill")
                            .foregroundColor(.red)
                            .font(.system(size: 13))
                    }
                }

                Section {
                    Button {
                        Task { await save() }
                    } label: {
                        HStack {
                            Spacer()
                            if isSaving {
                                ProgressView()
                            } else {
                                Text(L.t(sv: "Spara och beställ fraktsedel", nb: "Lagre og bestill fraktseddel"))
                                    .font(.system(size: 16, weight: .semibold))
                            }
                            Spacer()
                        }
                    }
                    .disabled(!isValid || isSaving)
                }
            }
            .navigationTitle(L.t(sv: "Fraktadress", nb: "Fraktadresse"))
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button(L.t(sv: "Avbryt", nb: "Avbryt")) { dismiss() }
                }
            }
        }
    }

    private var isValid: Bool {
        !fullName.trimmingCharacters(in: .whitespaces).isEmpty
            && !street.trimmingCharacters(in: .whitespaces).isEmpty
            && postalCode.filter(\.isNumber).count >= 4
            && !city.trimmingCharacters(in: .whitespaces).isEmpty
            && !country.trimmingCharacters(in: .whitespaces).isEmpty
    }

    private func save() async {
        await MainActor.run {
            isSaving = true
            errorText = nil
        }
        let address = ShippingAddress(
            fullName: fullName.trimmingCharacters(in: .whitespacesAndNewlines),
            phone: phone.trimmingCharacters(in: .whitespacesAndNewlines),
            street: street.trimmingCharacters(in: .whitespacesAndNewlines),
            postalCode: postalCode.trimmingCharacters(in: .whitespacesAndNewlines),
            city: city.trimmingCharacters(in: .whitespacesAndNewlines),
            country: country.trimmingCharacters(in: .whitespacesAndNewlines).uppercased()
        )
        do {
            try await ShippingLabelService.shared.saveAddress(
                submissionId: submissionId,
                address: address
            )
            await MainActor.run {
                isSaving = false
                onSaved(address)
                dismiss()
            }
        } catch {
            await MainActor.run {
                isSaving = false
                errorText = error.localizedDescription
            }
        }
    }
}

#Preview {
    ConsignmentShippingAddressView(submissionId: UUID())
}
