import SwiftUI
import MapKit
import Combine

private let buyerShippingAddressKey = "marketplace.buyer.shipping.address.v1"

extension UserDefaults {
    func saveBuyerShippingAddress(_ address: BuyerShippingAddress) {
        let payload: [String: Any] = [
            "fullName": address.fullName,
            "country": address.country,
            "street": address.street,
            "details": address.details,
            "postalCode": address.postalCode,
            "city": address.city,
            "phone": address.phone
        ]
        set(payload, forKey: buyerShippingAddressKey)
    }

    func loadBuyerShippingAddress() -> BuyerShippingAddress? {
        guard let dict = dictionary(forKey: buyerShippingAddressKey) else { return nil }
        var address = BuyerShippingAddress()
        address.fullName = dict["fullName"] as? String ?? ""
        address.country = dict["country"] as? String ?? "Sverige"
        address.street = dict["street"] as? String ?? ""
        address.details = dict["details"] as? String ?? ""
        address.postalCode = dict["postalCode"] as? String ?? ""
        address.city = dict["city"] as? String ?? ""
        address.phone = dict["phone"] as? String ?? ""
        return address.isValid ? address : nil
    }
}

/// Shared buyer-side shipping address model used by the Vinted-style checkout.
struct BuyerShippingAddress: Equatable {
    var fullName: String = ""
    var country: String = "Sverige"
    var street: String = ""
    var details: String = ""
    var postalCode: String = ""
    var city: String = ""
    /// Mobil för leveransavisering (Shipmondo `receiver_mobile`, t.ex. DHL hemleverans).
    var phone: String = ""

    /// Single-line address used in summaries and passed to Stripe.
    var displayLine: String {
        if details.trimmingCharacters(in: .whitespaces).isEmpty {
            return street
        }
        return "\(street), \(details)"
    }

    /// `+46701234567`-format; nil om fältet saknas eller inte är ett svenskt mobilnummer.
    var normalizedPhoneE164: String? {
        Self.normalizeSwedishMobile(phone)
    }

    var isValid: Bool {
        guard !fullName.trimmingCharacters(in: .whitespaces).isEmpty,
              !street.trimmingCharacters(in: .whitespaces).isEmpty,
              !postalCode.trimmingCharacters(in: .whitespaces).isEmpty,
              !city.trimmingCharacters(in: .whitespaces).isEmpty else {
            return false
        }
        return normalizedPhoneE164 != nil
    }

    /// Accepts `07…`, `7…` (9 digits), or `+46…` / `46…` with 9 subscriber digits starting with 7.
    private static func normalizeSwedishMobile(_ raw: String) -> String? {
        let trimmed = raw.trimmingCharacters(in: .whitespacesAndNewlines)
        if trimmed.isEmpty { return nil }
        let digits = trimmed.filter(\.isNumber)
        if digits.hasPrefix("46") {
            let sub = String(digits.dropFirst(2))
            if sub.count == 9, sub.first == "7" { return "+46" + sub }
            return nil
        }
        if digits.count == 10, digits.first == "0",
           digits[digits.index(digits.startIndex, offsetBy: 1)] == "7" {
            return "+46" + String(digits.dropFirst())
        }
        if digits.count == 9, digits.first == "7" {
            return "+46" + digits
        }
        return nil
    }
}

/// Vinted-matching address form. Presented as a sheet from
/// `MarketplaceCheckoutView` when the buyer taps "Lägg till din leveransadress".
struct AddressFormView: View {
    let initial: BuyerShippingAddress?
    var onSave: (BuyerShippingAddress) -> Void

    @Environment(\.dismiss) private var dismiss

    @State private var showAddressSearch = false
    @State private var fullName: String
    @State private var country: String
    @State private var street: String
    @State private var details: String
    @State private var postalCode: String
    @State private var city: String
    @State private var phone: String

    private let accent = Color.black

    init(initial: BuyerShippingAddress?, onSave: @escaping (BuyerShippingAddress) -> Void) {
        self.initial = initial
        self.onSave = onSave
        _fullName = State(initialValue: initial?.fullName ?? "")
        _country = State(initialValue: initial?.country ?? "Sverige")
        _street = State(initialValue: initial?.street ?? "")
        _details = State(initialValue: initial?.details ?? "")
        _postalCode = State(initialValue: initial?.postalCode ?? "")
        _city = State(initialValue: initial?.city ?? "")
        _phone = State(initialValue: initial?.phone ?? "")
    }

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: 22) {
                    searchField
                        .padding(.top, 8)

                    field(title: L.t(sv: "Fullständigt namn", nb: "Fullt navn"),
                          text: $fullName,
                          placeholder: "")

                    phoneField

                    countryField

                    field(title: L.t(sv: "Gata och husnummer", nb: "Gate og husnummer"),
                          text: $street,
                          placeholder: L.t(sv: "t.ex. Storgatan 71", nb: "f.eks. Storgata 71"))

                    field(title: L.t(sv: "Adressdetaljer (valfritt)", nb: "Adressedetaljer (valgfritt)"),
                          text: $details,
                          placeholder: L.t(sv: "Lägenhetsnummer, våning etc.",
                                           nb: "Leilighetsnummer, etasje etc."))

                    field(title: L.t(sv: "Postnummer", nb: "Postnummer"),
                          text: $postalCode,
                          placeholder: L.t(sv: "t.ex. 18461", nb: "f.eks. 18461"),
                          keyboard: .numberPad)

                    cityField
                }
                .padding(.horizontal, 20)
                .padding(.bottom, 120)
            }
            .background(Color(.systemBackground))
            .navigationTitle(L.t(sv: "Adress", nb: "Adresse"))
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarLeading) {
                    Button(L.t(sv: "Stäng", nb: "Lukk")) { dismiss() }
                        .foregroundColor(.primary)
                }
            }
            .safeAreaInset(edge: .bottom) { saveBar }
            .fullScreenCover(isPresented: $showAddressSearch) {
                AddressSearchView { resolved in
                    apply(resolved)
                }
            }
        }
    }

    // MARK: - Search

    private var searchField: some View {
        Button {
            showAddressSearch = true
        } label: {
            HStack(spacing: 10) {
                Image(systemName: "magnifyingglass")
                    .font(.system(size: 15))
                    .foregroundColor(.secondary)
                Text(L.t(sv: "Sök efter din adress", nb: "Søk etter adressen din"))
                    .font(.system(size: 15))
                    .foregroundColor(.secondary)
                Spacer()
            }
            .padding(.horizontal, 14)
            .padding(.vertical, 10)
            .background(Color(.systemGray6))
            .clipShape(RoundedRectangle(cornerRadius: 10, style: .continuous))
        }
        .buttonStyle(.plain)
    }

    private func apply(_ partial: BuyerShippingAddress) {
        if !partial.street.isEmpty { street = partial.street }
        if !partial.postalCode.isEmpty { postalCode = partial.postalCode }
        if !partial.city.isEmpty { city = partial.city }
        if !partial.country.isEmpty { country = partial.country }
    }

    // MARK: - Generic field (underlined, Vinted-style)

    private func field(
        title: String,
        text: Binding<String>,
        placeholder: String,
        keyboard: UIKeyboardType = .default
    ) -> some View {
        VStack(alignment: .leading, spacing: 6) {
            Text(title)
                .font(.system(size: 12))
                .foregroundColor(.secondary)
            TextField(placeholder, text: text)
                .font(.system(size: 16))
                .foregroundColor(.primary)
                .keyboardType(keyboard)
                .autocorrectionDisabled()
                .padding(.bottom, 6)
            Rectangle()
                .fill(Color(.systemGray4))
                .frame(height: 1)
        }
    }

    // MARK: - Country (locked to Sverige)

    private var countryField: some View {
        VStack(alignment: .leading, spacing: 6) {
            Text(L.t(sv: "Land", nb: "Land"))
                .font(.system(size: 12))
                .foregroundColor(.secondary)
            HStack {
                Text(country)
                    .font(.system(size: 16))
                    .foregroundColor(.primary)
                Spacer()
                Image(systemName: "chevron.down")
                    .font(.system(size: 13, weight: .semibold))
                    .foregroundColor(.secondary)
            }
            .padding(.bottom, 6)
            Rectangle()
                .fill(Color(.systemGray4))
                .frame(height: 1)
        }
    }

    // MARK: - City (with helper text)

    private var cityField: some View {
        VStack(alignment: .leading, spacing: 6) {
            Text(L.t(sv: "Stad/ort", nb: "Sted"))
                .font(.system(size: 12))
                .foregroundColor(.secondary)
            TextField(L.t(sv: "Stad/ort", nb: "Sted"), text: $city)
                .font(.system(size: 16))
                .foregroundColor(.primary)
                .autocorrectionDisabled()
                .padding(.bottom, 6)
            Rectangle()
                .fill(Color(.systemGray4))
                .frame(height: 1)
            Text(L.t(
                sv: "Orten fylls i automatiskt baserat på ditt postnummer",
                nb: "Stedet fylles inn automatisk basert på postnummeret"
            ))
            .font(.system(size: 12))
            .foregroundColor(.secondary)
            .padding(.top, 2)
        }
    }

    // MARK: - Phone (validation feedback)

    private var phoneField: some View {
        let trimmed = phone.trimmingCharacters(in: .whitespaces)
        let invalid = !trimmed.isEmpty && BuyerShippingAddress(
            fullName: "",
            country: "Sverige",
            street: "",
            details: "",
            postalCode: "11111",
            city: "",
            phone: trimmed
        ).normalizedPhoneE164 == nil

        return VStack(alignment: .leading, spacing: 6) {
            Text(L.t(sv: "Mobilnummer (för leveransavisering)", nb: "Mobilnummer"))
                .font(.system(size: 12))
                .foregroundColor(.secondary)
            TextField(
                L.t(sv: "t.ex. 0701234567", nb: "f.eks. 0701234567"),
                text: $phone
            )
            .font(.system(size: 16))
            .foregroundColor(.primary)
            .keyboardType(.phonePad)
            .textContentType(.telephoneNumber)
            .autocorrectionDisabled()
            .padding(.bottom, 6)
            Rectangle()
                .fill(invalid ? Color.red.opacity(0.7) : Color(.systemGray4))
                .frame(height: 1)
            Text(
                invalid
                    ? L.t(
                        sv: "Ogiltigt mobilnummer — använd 10 siffror, t.ex. 0701234567",
                        nb: "Ugyldig mobilnummer — bruk 10 sifre, f.eks. 0701234567"
                    )
                    : L.t(
                        sv: "Svenskt mobilnummer, 10 siffror — används för leveransavisering",
                        nb: "Svensk mobil, 10 siffer (07 …) — brukes til leveransevarsel"
                    )
            )
            .font(.system(size: 12))
            .foregroundColor(invalid ? .red : .secondary)
            .padding(.top, 2)
        }
    }

    // MARK: - Save bar

    private var saveBar: some View {
        VStack(spacing: 0) {
            Divider()
            Button {
                let address = BuyerShippingAddress(
                    fullName: fullName.trimmingCharacters(in: .whitespaces),
                    country: country,
                    street: street.trimmingCharacters(in: .whitespaces),
                    details: details.trimmingCharacters(in: .whitespaces),
                    postalCode: postalCode.trimmingCharacters(in: .whitespaces),
                    city: city.trimmingCharacters(in: .whitespaces),
                    phone: phone.trimmingCharacters(in: .whitespaces)
                )
                onSave(address)
                dismiss()
            } label: {
                Text(L.t(sv: "Spara adress", nb: "Lagre adresse"))
                    .font(.system(size: 16, weight: .semibold))
                    .foregroundColor(.white)
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 15)
                    .background(canSave ? accent : Color.gray.opacity(0.4))
                    .clipShape(RoundedRectangle(cornerRadius: 12, style: .continuous))
            }
            .disabled(!canSave)
            .padding(.horizontal, 16)
            .padding(.top, 12)
            .padding(.bottom, 12)
        }
        .background(Color(.systemBackground))
    }

    private var canSave: Bool {
        BuyerShippingAddress(
            fullName: fullName,
            country: country,
            street: street,
            details: details,
            postalCode: postalCode,
            city: city,
            phone: phone
        ).isValid
    }
}

// MARK: - Address autocomplete (MapKit)

/// MKLocalSearchCompleter-driven autocomplete. Biased towards Sweden but will
/// fall back to anything the user types.
@MainActor
final class AddressSearchCompleter: NSObject, ObservableObject, MKLocalSearchCompleterDelegate {
    @Published var results: [MKLocalSearchCompletion] = []
    @Published var isSearching: Bool = false

    private let completer: MKLocalSearchCompleter

    override init() {
        self.completer = MKLocalSearchCompleter()
        super.init()
        completer.delegate = self
        completer.resultTypes = .address
        // Bias towards Sweden so results like "Klockargränd 18236 Danderyd" bubble up first.
        completer.region = MKCoordinateRegion(
            center: CLLocationCoordinate2D(latitude: 62.0, longitude: 15.0),
            span: MKCoordinateSpan(latitudeDelta: 18.0, longitudeDelta: 18.0)
        )
    }

    func update(_ query: String) {
        let trimmed = query.trimmingCharacters(in: .whitespacesAndNewlines)
        if trimmed.isEmpty {
            results = []
            completer.queryFragment = ""
            isSearching = false
            return
        }
        isSearching = true
        completer.queryFragment = trimmed
    }

    nonisolated func completerDidUpdateResults(_ completer: MKLocalSearchCompleter) {
        let newResults = completer.results
        Task { @MainActor in
            self.results = newResults
            self.isSearching = false
        }
    }

    nonisolated func completer(_ completer: MKLocalSearchCompleter, didFailWithError error: Error) {
        Task { @MainActor in
            self.results = []
            self.isSearching = false
        }
    }

    /// Resolve a completion to a full placemark so we can pull out street/postal/city.
    func resolve(_ completion: MKLocalSearchCompletion) async -> MKPlacemark? {
        let request = MKLocalSearch.Request(completion: completion)
        let search = MKLocalSearch(request: request)
        return await withCheckedContinuation { continuation in
            search.start { response, _ in
                continuation.resume(returning: response?.mapItems.first?.placemark)
            }
        }
    }
}

/// Full-screen address search sheet. Mirrors the Vinted look: search bar at
/// top + Cancel action, live list of Apple Maps address completions.
struct AddressSearchView: View {
    var onSelect: (BuyerShippingAddress) -> Void

    @Environment(\.dismiss) private var dismiss
    @StateObject private var completer = AddressSearchCompleter()
    @State private var query: String = ""
    @State private var isResolving: Bool = false
    @FocusState private var focused: Bool

    var body: some View {
        NavigationStack {
            VStack(spacing: 0) {
                searchBar

                if query.isEmpty {
                    emptyHint
                } else if completer.results.isEmpty && !completer.isSearching {
                    noResults
                } else {
                    resultsList
                }
            }
            .navigationBarHidden(true)
            .background(Color(.systemBackground).ignoresSafeArea())
            .onAppear {
                focused = true
            }
        }
    }

    private var searchBar: some View {
        HStack(spacing: 10) {
            HStack(spacing: 8) {
                Image(systemName: "magnifyingglass")
                    .font(.system(size: 15))
                    .foregroundColor(.secondary)

                TextField(
                    L.t(sv: "Sök adress", nb: "Søk adresse"),
                    text: $query
                )
                .focused($focused)
                .textInputAutocapitalization(.words)
                .autocorrectionDisabled()
                .submitLabel(.search)
                .font(.system(size: 16))
                .foregroundColor(.primary)
                .onChange(of: query) { _, newValue in
                    completer.update(newValue)
                }

                if !query.isEmpty {
                    Button {
                        query = ""
                        completer.update("")
                    } label: {
                        Image(systemName: "xmark.circle.fill")
                            .font(.system(size: 15))
                            .foregroundColor(.secondary)
                    }
                }
            }
            .padding(.horizontal, 12)
            .padding(.vertical, 9)
            .background(Color(.systemGray6))
            .clipShape(RoundedRectangle(cornerRadius: 10, style: .continuous))

            Button(L.t(sv: "Avbryt", nb: "Avbryt")) {
                dismiss()
            }
            .foregroundColor(.primary)
        }
        .padding(.horizontal, 16)
        .padding(.top, 8)
        .padding(.bottom, 10)
    }

    private var resultsList: some View {
        List {
            ForEach(completer.results, id: \.self) { result in
                Button {
                    select(result)
                } label: {
                    HStack(alignment: .top, spacing: 12) {
                        Image(systemName: "mappin.circle")
                            .font(.system(size: 20))
                            .foregroundColor(.secondary)
                            .frame(width: 24)
                        VStack(alignment: .leading, spacing: 2) {
                            Text(result.title)
                                .font(.system(size: 16, weight: .semibold))
                                .foregroundColor(.primary)
                                .lineLimit(1)
                            if !result.subtitle.isEmpty {
                                Text(result.subtitle)
                                    .font(.system(size: 14))
                                    .foregroundColor(.secondary)
                                    .lineLimit(1)
                            }
                        }
                        Spacer()
                    }
                    .padding(.vertical, 6)
                }
                .buttonStyle(.plain)
                .listRowInsets(EdgeInsets(top: 4, leading: 16, bottom: 4, trailing: 16))
                .listRowSeparator(.visible)
            }
        }
        .listStyle(.plain)
        .overlay {
            if isResolving {
                Color.black.opacity(0.05).ignoresSafeArea()
                ProgressView()
            }
        }
    }

    private var emptyHint: some View {
        VStack(spacing: 8) {
            Spacer()
            Image(systemName: "magnifyingglass")
                .font(.system(size: 28))
                .foregroundColor(.secondary)
            Text(L.t(
                sv: "Börja skriva din gata, så hämtar vi matchande adresser",
                nb: "Begynn å skrive gaten din, så henter vi matchende adresser"
            ))
            .font(.system(size: 14))
            .foregroundColor(.secondary)
            .multilineTextAlignment(.center)
            .padding(.horizontal, 40)
            Spacer()
        }
    }

    private var noResults: some View {
        VStack(spacing: 8) {
            Spacer()
            Text(L.t(sv: "Inga träffar", nb: "Ingen treff"))
                .font(.system(size: 15, weight: .semibold))
                .foregroundColor(.primary)
            Text(L.t(
                sv: "Prova med en annan stavning eller lägg till husnummer.",
                nb: "Prøv en annen stavemåte eller legg til husnummer."
            ))
            .font(.system(size: 13))
            .foregroundColor(.secondary)
            .multilineTextAlignment(.center)
            .padding(.horizontal, 40)
            Spacer()
        }
    }

    private func select(_ completion: MKLocalSearchCompletion) {
        guard !isResolving else { return }
        isResolving = true
        Task {
            let placemark = await completer.resolve(completion)
            let partial = Self.buildAddress(
                from: placemark,
                fallback: (title: completion.title, subtitle: completion.subtitle)
            )
            isResolving = false
            onSelect(partial)
            dismiss()
        }
    }

    private static func buildAddress(
        from placemark: MKPlacemark?,
        fallback: (title: String, subtitle: String)
    ) -> BuyerShippingAddress {
        var address = BuyerShippingAddress()

        if let placemark {
            let street = [placemark.thoroughfare, placemark.subThoroughfare]
                .compactMap { $0?.trimmingCharacters(in: .whitespaces) }
                .filter { !$0.isEmpty }
                .joined(separator: " ")
            if !street.isEmpty {
                address.street = street
            } else {
                address.street = fallback.title
            }
            address.postalCode = placemark.postalCode ?? ""
            address.city = placemark.locality
                ?? placemark.subLocality
                ?? placemark.subAdministrativeArea
                ?? ""

            if let iso = placemark.isoCountryCode {
                switch iso.uppercased() {
                case "SE": address.country = "Sverige"
                case "NO": address.country = "Norge"
                case "DK": address.country = "Danmark"
                case "FI": address.country = "Finland"
                default:
                    if let c = placemark.country, !c.isEmpty {
                        address.country = c
                    }
                }
            }
        } else {
            // Last-resort parse of the completion subtitle, e.g.
            // "182 36 Danderyd, Sverige"
            address.street = fallback.title
            let parts = fallback.subtitle.components(separatedBy: ",")
            if let first = parts.first {
                let tokens = first
                    .trimmingCharacters(in: .whitespaces)
                    .components(separatedBy: " ")
                let digits = tokens.prefix(while: { $0.allSatisfy(\.isNumber) || $0.count <= 3 })
                let cityTokens = tokens.dropFirst(digits.count)
                address.postalCode = digits.joined()
                address.city = cityTokens.joined(separator: " ")
            }
            if parts.count > 1 {
                address.country = parts[1].trimmingCharacters(in: .whitespaces)
            }
        }

        return address
    }
}
