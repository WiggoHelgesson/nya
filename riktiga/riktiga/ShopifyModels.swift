import Foundation

// MARK: - GraphQL Response Wrappers

struct GraphQLResponse<T: Decodable>: Decodable {
    let data: T?
    let errors: [GraphQLError]?
}

struct GraphQLError: Decodable {
    let message: String
}

// MARK: - Product

struct ShopifyProduct: Identifiable, Decodable {
    let id: String
    let title: String
    let handle: String
    let description: String
    let productType: String
    let vendor: String
    let tags: [String]
    let images: ShopifyConnection<ShopifyImage>
    let variants: ShopifyConnection<ShopifyVariant>
    let priceRange: ShopifyPriceRange

    var firstImage: URL? {
        guard let src = images.edges.first?.node.url else { return nil }
        return URL(string: src)
    }

    var allImages: [URL] {
        images.edges.compactMap { URL(string: $0.node.url) }
    }

    var minPrice: String {
        priceRange.minVariantPrice.amount
    }

    var currencyCode: String {
        priceRange.minVariantPrice.currencyCode
    }

    var formattedPrice: String {
        let amount = Double(minPrice) ?? 0
        return "\(Int(amount)) \(currencyCode)"
    }

    var firstAvailableVariant: ShopifyVariant? {
        variants.edges.first(where: { $0.node.availableForSale })?.node
    }
}

// MARK: - Variant

struct ShopifyVariant: Identifiable, Decodable {
    let id: String
    let title: String
    let availableForSale: Bool
    let price: ShopifyMoney
    let selectedOptions: [ShopifyOption]

    var formattedPrice: String {
        let amount = Double(price.amount) ?? 0
        return "\(Int(amount)) \(price.currencyCode)"
    }
}

struct ShopifyOption: Decodable {
    let name: String
    let value: String
}

// MARK: - Image

struct ShopifyImage: Decodable {
    let url: String
    let altText: String?
}

// MARK: - Price

struct ShopifyMoney: Decodable {
    let amount: String
    let currencyCode: String
}

struct ShopifyPriceRange: Decodable {
    let minVariantPrice: ShopifyMoney
    let maxVariantPrice: ShopifyMoney
}

// MARK: - Connection / Edge (Shopify Relay pagination)

struct ShopifyConnection<T: Decodable>: Decodable {
    let edges: [ShopifyEdge<T>]
    let pageInfo: ShopifyPageInfo?

    enum CodingKeys: String, CodingKey {
        case edges, pageInfo
    }

    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        edges = try container.decode([ShopifyEdge<T>].self, forKey: .edges)
        pageInfo = try container.decodeIfPresent(ShopifyPageInfo.self, forKey: .pageInfo)
    }
}

struct ShopifyEdge<T: Decodable>: Decodable {
    let node: T
    let cursor: String?

    enum CodingKeys: String, CodingKey {
        case node, cursor
    }

    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        node = try container.decode(T.self, forKey: .node)
        cursor = try container.decodeIfPresent(String.self, forKey: .cursor)
    }
}

struct ShopifyPageInfo: Decodable {
    let hasNextPage: Bool
    let endCursor: String?
}

// MARK: - Cart

struct ShopifyCart: Decodable {
    let id: String
    let checkoutUrl: String
    let lines: ShopifyConnection<ShopifyCartLine>
    let cost: ShopifyCartCost
    let discountCodes: [ShopifyDiscountCode]?

    var totalAmount: String {
        let amount = Double(cost.totalAmount.amount) ?? 0
        return "\(Int(amount)) \(cost.totalAmount.currencyCode)"
    }

    var subtotalAmount: String {
        let amount = Double(cost.subtotalAmount.amount) ?? 0
        return "\(Int(amount)) \(cost.subtotalAmount.currencyCode)"
    }
}

struct ShopifyCartLine: Identifiable, Decodable {
    let id: String
    let quantity: Int
    let merchandise: ShopifyCartMerchandise
    let cost: ShopifyCartLineCost
}

struct ShopifyCartMerchandise: Decodable {
    let id: String
    let title: String
    let product: ShopifyCartProduct
    let image: ShopifyImage?
    let price: ShopifyMoney
}

struct ShopifyCartProduct: Decodable {
    let title: String
    let handle: String
    let vendor: String
}

struct ShopifyCartLineCost: Decodable {
    let totalAmount: ShopifyMoney
}

struct ShopifyCartCost: Decodable {
    let totalAmount: ShopifyMoney
    let subtotalAmount: ShopifyMoney
}

struct ShopifyDiscountCode: Decodable {
    let code: String
    let applicable: Bool
}

// MARK: - Query Response Types

struct ProductsQueryResponse: Decodable {
    let products: ShopifyConnection<ShopifyProduct>
}

struct ProductByHandleResponse: Decodable {
    let product: ShopifyProduct?
}

struct CartCreateResponse: Decodable {
    let cartCreate: CartPayload
}

struct CartLinesAddResponse: Decodable {
    let cartLinesAdd: CartPayload
}

struct CartLinesUpdateResponse: Decodable {
    let cartLinesUpdate: CartPayload
}

struct CartLinesRemoveResponse: Decodable {
    let cartLinesRemove: CartPayload
}

struct CartDiscountCodesUpdateResponse: Decodable {
    let cartDiscountCodesUpdate: CartPayload
}

struct CartPayload: Decodable {
    let cart: ShopifyCart?
    let userErrors: [ShopifyUserError]?
}

struct ShopifyUserError: Decodable {
    let field: [String]?
    let message: String
}
