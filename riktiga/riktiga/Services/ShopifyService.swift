import Foundation

class ShopifyService {
    static let shared = ShopifyService()

    private let storefrontURL = URL(string: "https://up-down-gear-1b0k2.myshopify.com/api/2025-07/graphql.json")!
    private let storefrontToken = "6abfe4acd24fb42da29942f0fbe1bf3d"
    let shopDomain = "up-down-gear-1b0k2.myshopify.com"

    private let session: URLSession = {
        let config = URLSessionConfiguration.default
        config.timeoutIntervalForRequest = 15
        config.timeoutIntervalForResource = 30
        return URLSession(configuration: config)
    }()

    private let decoder: JSONDecoder = {
        let d = JSONDecoder()
        return d
    }()

    private init() {}

    // MARK: - Generic request

    private func execute<T: Decodable>(query: String, variables: [String: Any]? = nil) async throws -> T {
        var request = URLRequest(url: storefrontURL)
        request.httpMethod = "POST"
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        request.setValue(storefrontToken, forHTTPHeaderField: "X-Shopify-Storefront-Access-Token")

        var body: [String: Any] = ["query": query]
        if let variables { body["variables"] = variables }
        request.httpBody = try JSONSerialization.data(withJSONObject: body)

        let (data, response) = try await session.data(for: request)

        guard let http = response as? HTTPURLResponse, (200...299).contains(http.statusCode) else {
            let code = (response as? HTTPURLResponse)?.statusCode ?? -1
            throw ShopifyError.httpError(code)
        }

        let gql = try decoder.decode(GraphQLResponse<T>.self, from: data)
        if let errors = gql.errors, !errors.isEmpty {
            throw ShopifyError.graphQL(errors.map(\.message).joined(separator: ", "))
        }
        guard let result = gql.data else {
            throw ShopifyError.noData
        }
        return result
    }

    // MARK: - Products

    func fetchProducts(first: Int = 20, query searchQuery: String? = nil, after cursor: String? = nil) async throws -> ShopifyConnection<ShopifyProduct> {
        var variables: [String: Any] = ["first": first]
        if let searchQuery, !searchQuery.isEmpty { variables["query"] = searchQuery }
        if let cursor { variables["after"] = cursor }

        let query = """
        query GetProducts($first: Int!, $query: String, $after: String) {
          products(first: $first, query: $query, after: $after, sortKey: BEST_SELLING) {
            edges {
              cursor
              node {
                id
                title
                handle
                description
                productType
                vendor
                tags
                images(first: 5) {
                  edges { node { url altText } }
                }
                variants(first: 20) {
                  edges {
                    node {
                      id
                      title
                      availableForSale
                      price { amount currencyCode }
                      selectedOptions { name value }
                    }
                  }
                }
                priceRange {
                  minVariantPrice { amount currencyCode }
                  maxVariantPrice { amount currencyCode }
                }
              }
            }
            pageInfo { hasNextPage endCursor }
          }
        }
        """

        let response: ProductsQueryResponse = try await execute(query: query, variables: variables)
        return response.products
    }

    func fetchProductByHandle(_ handle: String) async throws -> ShopifyProduct? {
        let query = """
        query GetProduct($handle: String!) {
          product(handle: $handle) {
            id
            title
            handle
            description
            productType
            vendor
            tags
            images(first: 10) {
              edges { node { url altText } }
            }
            variants(first: 30) {
              edges {
                node {
                  id
                  title
                  availableForSale
                  price { amount currencyCode }
                  selectedOptions { name value }
                }
              }
            }
            priceRange {
              minVariantPrice { amount currencyCode }
              maxVariantPrice { amount currencyCode }
            }
          }
        }
        """

        let response: ProductByHandleResponse = try await execute(query: query, variables: ["handle": handle])
        return response.product
    }

    // MARK: - Collection Products

    func fetchCollectionProducts(handle: String, first: Int = 20) async throws -> [ShopifyProduct] {
        let query = """
        query GetCollectionProducts($handle: String!, $first: Int!) {
            collection(handle: $handle) {
                products(first: $first) {
                    edges {
                        node {
                            id
                            title
                            handle
                            description
                            productType
                            vendor
                            tags
                            images(first: 10) {
                                edges { node { url altText } }
                            }
                            variants(first: 30) {
                                edges {
                                    node {
                                        id
                                        title
                                        availableForSale
                                        price { amount currencyCode }
                                        selectedOptions { name value }
                                    }
                                }
                            }
                            priceRange {
                                minVariantPrice { amount currencyCode }
                                maxVariantPrice { amount currencyCode }
                            }
                        }
                    }
                }
            }
        }
        """

        struct CollectionResponse: Decodable {
            let collection: CollectionNode?
        }
        struct CollectionNode: Decodable {
            let products: ShopifyConnection<ShopifyProduct>
        }

        let vars: [String: Any] = ["handle": handle, "first": first]
        let result: CollectionResponse = try await execute(query: query, variables: vars)

        guard let collection = result.collection else { return [] }
        return collection.products.edges.map(\.node)
    }

    // MARK: - Cart

    func cartCreate(variantId: String, quantity: Int = 1) async throws -> ShopifyCart {
        let query = """
        mutation CartCreate($input: CartInput!) {
          cartCreate(input: $input) {
            cart { \(cartFragment) }
            userErrors { field message }
          }
        }
        """

        let variables: [String: Any] = [
            "input": [
                "lines": [["merchandiseId": variantId, "quantity": quantity]]
            ]
        ]

        let response: CartCreateResponse = try await execute(query: query, variables: variables)
        if let errors = response.cartCreate.userErrors, !errors.isEmpty {
            throw ShopifyError.userError(errors.map(\.message).joined(separator: ", "))
        }
        guard let cart = response.cartCreate.cart else { throw ShopifyError.noData }
        return cart
    }

    func cartLinesAdd(cartId: String, variantId: String, quantity: Int = 1) async throws -> ShopifyCart {
        let query = """
        mutation CartLinesAdd($cartId: ID!, $lines: [CartLineInput!]!) {
          cartLinesAdd(cartId: $cartId, lines: $lines) {
            cart { \(cartFragment) }
            userErrors { field message }
          }
        }
        """

        let variables: [String: Any] = [
            "cartId": cartId,
            "lines": [["merchandiseId": variantId, "quantity": quantity]]
        ]

        let response: CartLinesAddResponse = try await execute(query: query, variables: variables)
        if let errors = response.cartLinesAdd.userErrors, !errors.isEmpty {
            throw ShopifyError.userError(errors.map(\.message).joined(separator: ", "))
        }
        guard let cart = response.cartLinesAdd.cart else { throw ShopifyError.noData }
        return cart
    }

    func cartLinesUpdate(cartId: String, lineId: String, quantity: Int) async throws -> ShopifyCart {
        let query = """
        mutation CartLinesUpdate($cartId: ID!, $lines: [CartLineUpdateInput!]!) {
          cartLinesUpdate(cartId: $cartId, lines: $lines) {
            cart { \(cartFragment) }
            userErrors { field message }
          }
        }
        """

        let variables: [String: Any] = [
            "cartId": cartId,
            "lines": [["id": lineId, "quantity": quantity]]
        ]

        let response: CartLinesUpdateResponse = try await execute(query: query, variables: variables)
        if let errors = response.cartLinesUpdate.userErrors, !errors.isEmpty {
            throw ShopifyError.userError(errors.map(\.message).joined(separator: ", "))
        }
        guard let cart = response.cartLinesUpdate.cart else { throw ShopifyError.noData }
        return cart
    }

    func cartLinesRemove(cartId: String, lineIds: [String]) async throws -> ShopifyCart {
        let query = """
        mutation CartLinesRemove($cartId: ID!, $lineIds: [ID!]!) {
          cartLinesRemove(cartId: $cartId, lineIds: $lineIds) {
            cart { \(cartFragment) }
            userErrors { field message }
          }
        }
        """

        let variables: [String: Any] = [
            "cartId": cartId,
            "lineIds": lineIds
        ]

        let response: CartLinesRemoveResponse = try await execute(query: query, variables: variables)
        if let errors = response.cartLinesRemove.userErrors, !errors.isEmpty {
            throw ShopifyError.userError(errors.map(\.message).joined(separator: ", "))
        }
        guard let cart = response.cartLinesRemove.cart else { throw ShopifyError.noData }
        return cart
    }

    func cartDiscountCodesUpdate(cartId: String, discountCodes: [String]) async throws -> ShopifyCart {
        let query = """
        mutation CartDiscountCodesUpdate($cartId: ID!, $discountCodes: [String!]) {
          cartDiscountCodesUpdate(cartId: $cartId, discountCodes: $discountCodes) {
            cart { \(cartFragment) }
            userErrors { field message }
          }
        }
        """

        let variables: [String: Any] = [
            "cartId": cartId,
            "discountCodes": discountCodes
        ]

        let response: CartDiscountCodesUpdateResponse = try await execute(query: query, variables: variables)
        if let errors = response.cartDiscountCodesUpdate.userErrors, !errors.isEmpty {
            throw ShopifyError.userError(errors.map(\.message).joined(separator: ", "))
        }
        guard let cart = response.cartDiscountCodesUpdate.cart else { throw ShopifyError.noData }
        return cart
    }

    // MARK: - Cart Fragment

    private var cartFragment: String {
        """
        id
        checkoutUrl
        lines(first: 50) {
          edges {
            node {
              id
              quantity
              merchandise {
                ... on ProductVariant {
                  id
                  title
                  product { title handle vendor }
                  image { url altText }
                  price { amount currencyCode }
                }
              }
              cost { totalAmount { amount currencyCode } }
            }
          }
        }
        cost {
          totalAmount { amount currencyCode }
          subtotalAmount { amount currencyCode }
        }
        discountCodes { code applicable }
        """
    }
}

// MARK: - Errors

enum ShopifyError: LocalizedError {
    case httpError(Int)
    case graphQL(String)
    case noData
    case userError(String)

    var errorDescription: String? {
        switch self {
        case .httpError(let code): return "HTTP \(code)"
        case .graphQL(let msg): return msg
        case .noData: return "No data returned"
        case .userError(let msg): return msg
        }
    }
}
