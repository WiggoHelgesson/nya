import Combine
import Foundation
import SwiftUI

// MARK: - Navigation

enum SellRoute: Hashable {
    case category
    case result
}

// MARK: - Flow state (shared across steps)

final class SellFlowModel: ObservableObject {
    @Published var images: [UIImage] = []
    @Published var selectedCategory: String = ""
    @Published var categorySuggestions: [String] = []
    @Published var analysis: SellAnalysisResult?
    @Published var userBrand: String = ""
    @Published var userCondition: String = ""
    @Published var didSubmit: Bool = false

    func resetForNewListing() {
        images = []
        selectedCategory = ""
        categorySuggestions = []
        analysis = nil
        userBrand = ""
        userCondition = ""
        didSubmit = false
    }

    func applyAnalysis(_ result: SellAnalysisResult) {
        analysis = result
        userBrand = result.brandGuess
        userCondition = result.condition
    }
}

// MARK: - AI result

struct SellAnalysisResult: Codable, Equatable, Hashable {
    var productName: String
    var condition: String
    var priceRangeLabel: String
    var title: String
    var description: String
    var brandGuess: String
    var sellerPayoutRange: String

    enum CodingKeys: String, CodingKey {
        case productName = "product_name"
        case condition
        case priceRangeLabel = "price_range_label"
        case title
        case description
        case brandGuess = "brand_guess"
        case sellerPayoutRange = "seller_payout_range"
    }

    static let empty = SellAnalysisResult(
        productName: "",
        condition: "",
        priceRangeLabel: "",
        title: "",
        description: "",
        brandGuess: "",
        sellerPayoutRange: ""
    )
}

// MARK: - Category catalogue (sport / golf)

enum SellConsignmentCategories {
    static let all: [String] = [
        "Golf / Driver",
        "Golf / Fairwaywood & hybrid",
        "Golf / Järnset",
        "Golf / Wedges",
        "Golf / Putters",
        "Golf / Golfbollar",
        "Golf / Golfväska & cartbag",
        "Golf / Golfskor",
        "Golf / Golfkläder",
        "Golf / Tillbehör (GPS, range finder)",
        "Träning / Löparskor",
        "Träning / Träningsskor",
        "Träning / Träningskläder",
        "Träning / Vätskebälte & väska",
        "Träning / Pulsklocka & GPS",
        "Träning / Hantlar & kettlebells",
        "Träning / Yogamatta & block",
        "Cykel / Cykel",
        "Cykel / Hjälm & skydd",
        "Cykel / Cykelkläder",
        "Längdskidor / Skidor & stavar",
        "Längdskidor / Skidpjäxor & bindningar",
        "Alpint / Skidor & pjäxor",
        "Racketsport / Tennis & padel",
        "Racketsport / Badminton & squash",
        "Övrigt / Sport och fritid"
    ]
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

struct ConsignmentSubmissionRow: Decodable, Identifiable {
    let id: UUID
    let userId: UUID
    let imageUrls: [String]
    let category: String
    let aiPayload: SellAnalysisResult
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

    enum CodingKeys: String, CodingKey {
        case id
        case userId = "user_id"
        case imageUrls = "image_urls"
        case category
        case aiPayload = "ai_payload"
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
    }

    init(from decoder: Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        id = try c.decode(UUID.self, forKey: .id)
        userId = try c.decode(UUID.self, forKey: .userId)
        imageUrls = try c.decode([String].self, forKey: .imageUrls)
        category = try c.decode(String.self, forKey: .category)
        userBrand = try c.decodeIfPresent(String.self, forKey: .userBrand)
        userCondition = try c.decodeIfPresent(String.self, forKey: .userCondition)
        adminStatus = try c.decode(String.self, forKey: .adminStatus)
        finalPriceRange = try c.decodeIfPresent(String.self, forKey: .finalPriceRange)
        adminNotes = try c.decodeIfPresent(String.self, forKey: .adminNotes)
        createdAt = try c.decodeIfPresent(String.self, forKey: .createdAt)
        aiPayload = (try? c.decode(SellAnalysisResult.self, forKey: .aiPayload)) ?? .empty
        shippingStatus = try c.decodeIfPresent(String.self, forKey: .shippingStatus)
        shippingAddress = try c.decodeIfPresent(ShippingAddress.self, forKey: .shippingAddress)
        shippingLabelUrl = try c.decodeIfPresent(String.self, forKey: .shippingLabelUrl)
        shippingCarrier = try c.decodeIfPresent(String.self, forKey: .shippingCarrier)
        shippingTrackingNumber = try c.decodeIfPresent(String.self, forKey: .shippingTrackingNumber)
        shippedAt = try c.decodeIfPresent(String.self, forKey: .shippedAt)
        receivedAt = try c.decodeIfPresent(String.self, forKey: .receivedAt)
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
