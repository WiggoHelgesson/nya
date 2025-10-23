import Foundation

struct Purchase: Codable, Identifiable {
    let id: String
    let userId: String
    let brandName: String
    let discount: String
    let discountCode: String
    let purchaseDate: Date
    
    enum CodingKeys: String, CodingKey {
        case id
        case userId = "user_id"
        case brandName = "brand_name"
        case discount
        case discountCode = "discount_code"
        case purchaseDate = "purchase_date"
    }
    
    init(id: String = UUID().uuidString, userId: String, brandName: String, discount: String, discountCode: String, purchaseDate: Date = Date()) {
        self.id = id
        self.userId = userId
        self.brandName = brandName
        self.discount = discount
        self.discountCode = discountCode
        self.purchaseDate = purchaseDate
    }
}
