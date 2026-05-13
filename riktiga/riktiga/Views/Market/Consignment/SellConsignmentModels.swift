import Combine
import Foundation
import SwiftUI

// MARK: - Navigation

enum SellRoute: Hashable {
    case subcategory(topCategoryId: String)
    case category
    case condition
    case packageSize
    case pickupAddress
    case success
}

// MARK: - Flow state (shared across steps)

final class SellFlowModel: ObservableObject {
    @Published var images: [UIImage] = []
    @Published var title: String = ""
    @Published var listingDescription: String = ""
    @Published var selectedCategory: String = ""
    @Published var brand: String = ""
    @Published var condition: String = ""
    @Published var colors: [String] = []
    @Published var material: String = ""
    @Published var priceSEK: Int? = nil
    @Published var packageSize: String = ""
    /// Cached seller pickup row for marketplace `from_address`; shared across listings.
    @Published var pickupAddress: ShippingAddress?
    @Published var hasSavedPickupAddress: Bool = false
    @Published var didSubmit: Bool = false

    @Published var editingId: UUID? = nil
    @Published var existingImageUrls: [String] = []
    /// Wizard: om AI ska generera rubrik/beskrivning efter vald kategori.
    @Published var useAiGeneratedCopy: Bool = true

    var isEditing: Bool { editingId != nil }

    func resetForNewListing() {
        images = []
        title = ""
        listingDescription = ""
        selectedCategory = ""
        brand = ""
        condition = ""
        colors = []
        material = ""
        priceSEK = nil
        packageSize = ""
        didSubmit = false
        editingId = nil
        existingImageUrls = []
        useAiGeneratedCopy = true
    }

    func prefill(from row: ConsignmentSubmissionRow) {
        editingId = row.id
        existingImageUrls = row.imageUrls
        title = row.title ?? ""
        listingDescription = row.description ?? ""
        selectedCategory = row.category
        brand = row.userBrand ?? ""
        condition = row.userCondition ?? ""
        colors = row.colors
        material = row.material ?? ""
        priceSEK = row.priceSEK
        packageSize = row.packageSize ?? ""
        didSubmit = false
    }

    /// True when all required fields are valid and the form can be submitted.
    var isReadyToSubmit: Bool {
        !images.isEmpty
            && !title.trimmed.isEmpty
            && !listingDescription.trimmed.isEmpty
            && !selectedCategory.isEmpty
            && !brand.trimmed.isEmpty
            && !condition.isEmpty
            && (priceSEK ?? 0) > 0
            && !packageSize.isEmpty
            && hasSavedPickupAddress
    }
}

private extension String {
    var trimmed: String { trimmingCharacters(in: .whitespacesAndNewlines) }
}

// MARK: - Sport category taxonomy (manual listing flow)

struct SportSubcategory: Identifiable, Hashable {
    let id: String
    let nameSV: String
    let nameNB: String

    var displayName: String { L.t(sv: nameSV, nb: nameNB) }
}

struct SportCategory: Identifiable, Hashable {
    let id: String
    let nameSV: String
    let nameNB: String
    let sfSymbol: String
    let subcategories: [SportSubcategory]

    var displayName: String { L.t(sv: nameSV, nb: nameNB) }

    static let all: [SportCategory] = [
        .init(
            id: "cykling",
            nameSV: "Cykling", nameNB: "Sykling",
            sfSymbol: "bicycle",
            subcategories: [
                .init(id: "cyklar_vuxen", nameSV: "Cyklar för vuxna", nameNB: "Sykler for voksne"),
                .init(id: "cyklar_barn", nameSV: "Cyklar för barn", nameNB: "Sykler for barn"),
                .init(id: "hjälm_skydd", nameSV: "Hjälmar & skydd", nameNB: "Hjelmer og beskyttelse"),
                .init(id: "cykelkläder", nameSV: "Cykelkläder", nameNB: "Sykkelklær"),
                .init(id: "cykel_tillbehör", nameSV: "Tillbehör & reservdelar", nameNB: "Tilbehør og reservedeler")
            ]
        ),
        .init(
            id: "traning_lopning_yoga",
            nameSV: "Träning, löpning & yoga", nameNB: "Trening, løping og yoga",
            sfSymbol: "figure.run",
            subcategories: [
                .init(id: "löparskor", nameSV: "Löparskor", nameNB: "Løpesko"),
                .init(id: "träningsskor", nameSV: "Träningsskor", nameNB: "Treningssko"),
                .init(id: "träningskläder", nameSV: "Träningskläder", nameNB: "Treningsklær"),
                .init(id: "yoga_matta", nameSV: "Yogamatta & tillbehör", nameNB: "Yogamatte og tilbehør"),
                .init(id: "hantlar_kettlebells", nameSV: "Hantlar & kettlebells", nameNB: "Manualer og kettlebells"),
                .init(id: "puls_klocka", nameSV: "Pulsklocka & GPS", nameNB: "Pulsklokke og GPS")
            ]
        ),
        .init(
            id: "utomhussport",
            nameSV: "Utomhussport", nameNB: "Utendørssport",
            sfSymbol: "mountain.2",
            subcategories: [
                .init(id: "vandring", nameSV: "Vandring & trekking", nameNB: "Vandring og trekking"),
                .init(id: "klättring", nameSV: "Klättring", nameNB: "Klatring"),
                .init(id: "camping", nameSV: "Camping", nameNB: "Camping"),
                .init(id: "jakt_fiske", nameSV: "Jakt & fiske", nameNB: "Jakt og fiske")
            ]
        ),
        .init(
            id: "vattensporter",
            nameSV: "Vattensporter", nameNB: "Vannsport",
            sfSymbol: "drop.fill",
            subcategories: [
                .init(id: "surfing", nameSV: "Surfing & SUP", nameNB: "Surfing og SUP"),
                .init(id: "kajak", nameSV: "Kajak & kanot", nameNB: "Kajakk og kano"),
                .init(id: "dykning", nameSV: "Dykning & snorkling", nameNB: "Dykking og snorkling"),
                .init(id: "simning", nameSV: "Simning", nameNB: "Svømming")
            ]
        ),
        .init(
            id: "lagsporter",
            nameSV: "Lagsporter", nameNB: "Lagidretter",
            sfSymbol: "soccerball",
            subcategories: [
                .init(id: "fotboll", nameSV: "Fotboll", nameNB: "Fotball"),
                .init(id: "hockey", nameSV: "Ishockey", nameNB: "Ishockey"),
                .init(id: "basket", nameSV: "Basket", nameNB: "Basket"),
                .init(id: "innebandy", nameSV: "Innebandy", nameNB: "Innebandy"),
                .init(id: "handboll", nameSV: "Handboll", nameNB: "Håndball")
            ]
        ),
        .init(
            id: "racketsporter",
            nameSV: "Racketsporter", nameNB: "Racketsport",
            sfSymbol: "figure.tennis",
            subcategories: [
                .init(id: "tennis", nameSV: "Tennis", nameNB: "Tennis"),
                .init(id: "padel", nameSV: "Padel", nameNB: "Padel"),
                .init(id: "badminton", nameSV: "Badminton", nameNB: "Badminton"),
                .init(id: "squash", nameSV: "Squash", nameNB: "Squash"),
                .init(id: "bordtennis", nameSV: "Bordtennis", nameNB: "Bordtennis")
            ]
        ),
        .init(
            id: "golf",
            nameSV: "Golf", nameNB: "Golf",
            sfSymbol: "flag.fill",
            subcategories: [
                .init(id: "driver", nameSV: "Driver", nameNB: "Driver"),
                .init(id: "fairwaywood", nameSV: "Fairwaywood & hybrid", nameNB: "Fairwaywood og hybrid"),
                .init(id: "järnset", nameSV: "Järnset", nameNB: "Jernsett"),
                .init(id: "wedges", nameSV: "Wedges", nameNB: "Wedges"),
                .init(id: "putters", nameSV: "Putters", nameNB: "Puttere"),
                .init(id: "golfväska", nameSV: "Golfväska & cartbag", nameNB: "Golfbag og cartbag"),
                .init(id: "golfskor", nameSV: "Golfskor", nameNB: "Golfsko"),
                .init(id: "golfkläder", nameSV: "Golfkläder", nameNB: "Golfklær"),
                .init(id: "golf_tillbehör", nameSV: "Tillbehör (GPS, bollar)", nameNB: "Tilbehør (GPS, baller)")
            ]
        ),
        .init(
            id: "ridsport",
            nameSV: "Ridsport", nameNB: "Ridesport",
            sfSymbol: "figure.equestrian.sports",
            subcategories: [
                .init(id: "ridkläder", nameSV: "Ridkläder", nameNB: "Rideklær"),
                .init(id: "ridutrustning", nameSV: "Utrustning & tillbehör", nameNB: "Utstyr og tilbehør"),
                .init(id: "ridstövlar", nameSV: "Ridstövlar & hjälmar", nameNB: "Ridestøvler og hjelmer")
            ]
        ),
        .init(
            id: "skateboards_sparkcyklar",
            nameSV: "Skateboards & sparkcyklar", nameNB: "Skateboards og sparkesykler",
            sfSymbol: "skateboard",
            subcategories: [
                .init(id: "skateboard", nameSV: "Skateboard", nameNB: "Skateboard"),
                .init(id: "longboard", nameSV: "Longboard", nameNB: "Longboard"),
                .init(id: "sparkcykel", nameSV: "Sparkcykel", nameNB: "Sparkesykkel"),
                .init(id: "skydd_skateboard", nameSV: "Skydd & hjälmar", nameNB: "Beskyttelse og hjelmer")
            ]
        ),
        .init(
            id: "boxning_kampsport",
            nameSV: "Boxning & kampsport", nameNB: "Boksing og kampsport",
            sfSymbol: "figure.boxing",
            subcategories: [
                .init(id: "boxning", nameSV: "Boxning", nameNB: "Boksing"),
                .init(id: "mma", nameSV: "MMA & BJJ", nameNB: "MMA og BJJ"),
                .init(id: "karate_taekwondo", nameSV: "Karate & taekwondo", nameNB: "Karate og taekwondo")
            ]
        ),
        .init(
            id: "fritidssporter_spel",
            nameSV: "Fritidssporter & spel", nameNB: "Fritidssport og spill",
            sfSymbol: "gamecontroller",
            subcategories: [
                .init(id: "bordtennis_fritid", nameSV: "Bordtennis & biljard", nameNB: "Bordtennis og biljard"),
                .init(id: "dart", nameSV: "Dart", nameNB: "Dart"),
                .init(id: "pickleball", nameSV: "Pickleball & kubb", nameNB: "Pickleball og kubb")
            ]
        ),
        .init(
            id: "vintersport",
            nameSV: "Vintersport", nameNB: "Vintersport",
            sfSymbol: "snowflake",
            subcategories: [
                .init(id: "alpint", nameSV: "Alpint & freeride", nameNB: "Alpint og freeride"),
                .init(id: "längdskidor", nameSV: "Längdskidor", nameNB: "Langrenn"),
                .init(id: "snowboard", nameSV: "Snowboard", nameNB: "Snowboard"),
                .init(id: "skridskor", nameSV: "Skridskor", nameNB: "Skøyter"),
                .init(id: "pjäxor_bindningar", nameSV: "Pjäxor & bindningar", nameNB: "Støvler og bindinger")
            ]
        )
    ]

    static func find(id: String) -> SportCategory? {
        all.first { $0.id == id }
    }
}

// MARK: - Condition

enum SellCondition: String, CaseIterable, Identifiable {
    case newWithTag, newWithoutTag, veryGood, good, acceptable

    var id: String { rawValue }

    var title: String {
        switch self {
        case .newWithTag: return L.t(sv: "Ny med prislapp", nb: "Ny med prislapp")
        case .newWithoutTag: return L.t(sv: "Ny utan prislapp", nb: "Ny uten prislapp")
        case .veryGood: return L.t(sv: "Mycket bra", nb: "Veldig bra")
        case .good: return L.t(sv: "Bra", nb: "Bra")
        case .acceptable: return L.t(sv: "Tillfredsställande", nb: "Akseptabel")
        }
    }

    /// Returns the localized Swedish/Norwegian title for a raw database value
    /// such as `"newWithTag"`. Falls back to the raw string if it cannot be
    /// mapped to a known case, and returns `nil` for empty/missing values.
    static func localizedTitle(raw: String?) -> String? {
        guard let trimmed = raw?.trimmingCharacters(in: .whitespacesAndNewlines),
              !trimmed.isEmpty else { return nil }
        return SellCondition(rawValue: trimmed)?.title ?? trimmed
    }

    var descriptionText: String {
        switch self {
        case .newWithTag:
            return L.t(
                sv: "Ny och oanvänd artikel med prislappen kvar i originalförpackningen.",
                nb: "Ny og ubrukt vare med prislapp i originalemballasje."
            )
        case .newWithoutTag:
            return L.t(
                sv: "En helt ny, oanvänd produkt utan prislapp eller originalförpackning.",
                nb: "En helt ny, ubrukt vare uten prislapp eller originalemballasje."
            )
        case .veryGood:
            return L.t(
                sv: "Artikeln har använts lite och har några mindre skavanker men är fortfarande fin. Inkludera foton på och beskrivningar av eventuella skavanker i annonsen.",
                nb: "Varen er lite brukt og har små bruksspor, men er fortsatt fin. Inkluder bilder og beskrivelse av eventuelle bruksspor."
            )
        case .good:
            return L.t(
                sv: "Använda artiklar kan vara slitna och ha vissa skavanker. Lägg till foton på och beskrivningar av skavankerna i annonsen.",
                nb: "Brukte varer kan være slitt og ha synlige bruksspor. Legg til bilder og beskrivelse av bruksspor."
            )
        case .acceptable:
            return L.t(
                sv: "En välanvänd artikel med skavanker och tecken på slitage. Lägg till foton på och beskrivningar av skavankerna i annonsen.",
                nb: "En godt brukt vare med bruksspor og tegn på slitasje. Legg til bilder og beskrivelse av bruksspor."
            )
        }
    }
}

// MARK: - Package size

enum PackageSize: String, CaseIterable, Identifiable {
    case xs, s, m, l, xl

    var id: String { rawValue }

    var code: String { rawValue.uppercased() }

    var title: String { code }

    var descriptionText: String {
        switch self {
        case .xs: return L.t(sv: "Upp till 1 kg — brev eller litet paket.", nb: "Opptil 1 kg — brev eller liten pakke.")
        case .s: return L.t(sv: "Upp till 2 kg — litet paket.", nb: "Opptil 2 kg — liten pakke.")
        case .m: return L.t(sv: "Upp till 5 kg — mellanstort paket.", nb: "Opptil 5 kg — middels stor pakke.")
        case .l: return L.t(sv: "Upp till 10 kg — stort paket.", nb: "Opptil 10 kg — stor pakke.")
        case .xl: return L.t(sv: "Upp till 20 kg — extra stort paket.", nb: "Opptil 20 kg — ekstra stor pakke.")
        }
    }
}

// MARK: - Listing colors

enum ListingColor: String, CaseIterable, Identifiable {
    case black, white, grey, blue, red, green, yellow, pink, purple, brown, beige, orange, patterned

    var id: String { rawValue }

    var displayName: String {
        switch self {
        case .black: return L.t(sv: "Svart", nb: "Svart")
        case .white: return L.t(sv: "Vit", nb: "Hvit")
        case .grey: return L.t(sv: "Grå", nb: "Grå")
        case .blue: return L.t(sv: "Blå", nb: "Blå")
        case .red: return L.t(sv: "Röd", nb: "Rød")
        case .green: return L.t(sv: "Grön", nb: "Grønn")
        case .yellow: return L.t(sv: "Gul", nb: "Gul")
        case .pink: return L.t(sv: "Rosa", nb: "Rosa")
        case .purple: return L.t(sv: "Lila", nb: "Lilla")
        case .brown: return L.t(sv: "Brun", nb: "Brun")
        case .beige: return L.t(sv: "Beige", nb: "Beige")
        case .orange: return L.t(sv: "Orange", nb: "Oransje")
        case .patterned: return L.t(sv: "Mönstrad", nb: "Mønstret")
        }
    }

    var swatch: Color {
        switch self {
        case .black: return .black
        case .white: return Color(white: 0.97)
        case .grey: return Color(white: 0.55)
        case .blue: return Color(red: 0.10, green: 0.35, blue: 0.85)
        case .red: return Color(red: 0.86, green: 0.18, blue: 0.18)
        case .green: return Color(red: 0.20, green: 0.60, blue: 0.30)
        case .yellow: return Color(red: 0.97, green: 0.80, blue: 0.20)
        case .pink: return Color(red: 0.98, green: 0.60, blue: 0.75)
        case .purple: return Color(red: 0.55, green: 0.30, blue: 0.75)
        case .brown: return Color(red: 0.45, green: 0.28, blue: 0.18)
        case .beige: return Color(red: 0.92, green: 0.86, blue: 0.72)
        case .orange: return Color(red: 0.95, green: 0.55, blue: 0.15)
        case .patterned: return Color.gray.opacity(0.4)
        }
    }
}

// MARK: - Shipping address (seller input)

struct ShippingAddress: Codable, Equatable, Hashable {
    var fullName: String
    var phone: String
    var street: String
    var postalCode: String
    var city: String
    var country: String

    enum CodingKeys: String, CodingKey {
        case fullName = "full_name"
        case phone
        case street
        case postalCode = "postal_code"
        case city
        case country
    }

    static let empty = ShippingAddress(
        fullName: "",
        phone: "",
        street: "",
        postalCode: "",
        city: "",
        country: "SE"
    )
}

// MARK: - Shipping status values

enum ShippingStatus {
    static let none = "none"
    static let awaitingAddress = "awaiting_address"
    static let awaitingLabel = "awaiting_label"
    static let labelReady = "label_ready"
    static let shipped = "shipped"
    static let received = "received"
}

// MARK: - DB row (admin + decode)

struct ConsignmentSubmissionRow: Decodable, Identifiable, Hashable {
    static func == (a: ConsignmentSubmissionRow, b: ConsignmentSubmissionRow) -> Bool {
        a.id == b.id
    }
    func hash(into hasher: inout Hasher) {
        hasher.combine(id)
    }

    let id: UUID
    let userId: UUID
    let imageUrls: [String]
    let category: String
    let title: String?
    let description: String?
    let priceSEK: Int?
    let colors: [String]
    let material: String?
    let packageSize: String?
    let userBrand: String?
    let userCondition: String?
    let adminStatus: String
    let finalPriceRange: String?
    let adminNotes: String?
    let createdAt: String?
    let shippingStatus: String?
    let shippingAddress: ShippingAddress?
    let shippingLabelUrl: String?
    let shippingCarrier: String?
    let shippingTrackingNumber: String?
    let shippedAt: String?
    let receivedAt: String?
    let soldAt: String?
    let soldOrderId: UUID?

    enum CodingKeys: String, CodingKey {
        case id
        case userId = "user_id"
        case imageUrls = "image_urls"
        case category
        case title
        case description
        case priceSEK = "price_sek"
        case colors
        case material
        case packageSize = "package_size"
        case userBrand = "user_brand"
        case userCondition = "user_condition"
        case adminStatus = "admin_status"
        case finalPriceRange = "final_price_range"
        case adminNotes = "admin_notes"
        case createdAt = "created_at"
        case shippingStatus = "shipping_status"
        case shippingAddress = "shipping_address"
        case shippingLabelUrl = "shipping_label_url"
        case shippingCarrier = "shipping_carrier"
        case shippingTrackingNumber = "shipping_tracking_number"
        case shippedAt = "shipped_at"
        case receivedAt = "received_at"
        case soldAt = "sold_at"
        case soldOrderId = "sold_order_id"
    }

    init(from decoder: Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        id = try c.decode(UUID.self, forKey: .id)
        userId = try c.decode(UUID.self, forKey: .userId)
        imageUrls = try c.decode([String].self, forKey: .imageUrls)
        category = try c.decode(String.self, forKey: .category)
        title = try c.decodeIfPresent(String.self, forKey: .title)
        description = try c.decodeIfPresent(String.self, forKey: .description)
        priceSEK = try c.decodeIfPresent(Int.self, forKey: .priceSEK)
        colors = (try? c.decode([String].self, forKey: .colors)) ?? []
        material = try c.decodeIfPresent(String.self, forKey: .material)
        packageSize = try c.decodeIfPresent(String.self, forKey: .packageSize)
        userBrand = try c.decodeIfPresent(String.self, forKey: .userBrand)
        userCondition = try c.decodeIfPresent(String.self, forKey: .userCondition)
        adminStatus = try c.decode(String.self, forKey: .adminStatus)
        finalPriceRange = try c.decodeIfPresent(String.self, forKey: .finalPriceRange)
        adminNotes = try c.decodeIfPresent(String.self, forKey: .adminNotes)
        createdAt = try c.decodeIfPresent(String.self, forKey: .createdAt)
        shippingStatus = try c.decodeIfPresent(String.self, forKey: .shippingStatus)
        shippingAddress = try c.decodeIfPresent(ShippingAddress.self, forKey: .shippingAddress)
        shippingLabelUrl = try c.decodeIfPresent(String.self, forKey: .shippingLabelUrl)
        shippingCarrier = try c.decodeIfPresent(String.self, forKey: .shippingCarrier)
        shippingTrackingNumber = try c.decodeIfPresent(String.self, forKey: .shippingTrackingNumber)
        shippedAt = try c.decodeIfPresent(String.self, forKey: .shippedAt)
        receivedAt = try c.decodeIfPresent(String.self, forKey: .receivedAt)
        soldAt = try c.decodeIfPresent(String.self, forKey: .soldAt)
        soldOrderId = try c.decodeIfPresent(UUID.self, forKey: .soldOrderId)
    }
}

// MARK: - Image prep

enum SellImagePrep {
    static func jpegData(from image: UIImage, maxDimension: CGFloat = 1600, quality: CGFloat = 0.78) -> Data? {
        let resized = resize(image, maxDimension: maxDimension)
        return resized.jpegData(compressionQuality: quality)
    }

    private static func resize(_ image: UIImage, maxDimension: CGFloat) -> UIImage {
        let size = image.size
        let longest = max(size.width, size.height)
        guard longest > maxDimension else { return image }
        let scale = maxDimension / longest
        let newSize = CGSize(width: floor(size.width * scale), height: floor(size.height * scale))
        let renderer = UIGraphicsImageRenderer(size: newSize)
        return renderer.image { _ in
            image.draw(in: CGRect(origin: .zero, size: newSize))
        }
    }
}
