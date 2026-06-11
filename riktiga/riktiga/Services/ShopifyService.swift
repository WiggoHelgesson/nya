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
            let rawBody = String(data: data, encoding: .utf8) ?? "<non-utf8>"
            print("[ShopifyService] HTTP ERROR \(code) — body: \(rawBody.prefix(500))")
            throw ShopifyError.httpError(code)
        }

        let gql: GraphQLResponse<T>
        do {
            gql = try decoder.decode(GraphQLResponse<T>.self, from: data)
        } catch {
            let rawBody = String(data: data, encoding: .utf8) ?? "<non-utf8>"
            print("[ShopifyService] DECODE ERROR: \(error)")
            print("[ShopifyService] Raw JSON: \(rawBody.prefix(800))")
            throw error
        }
        if let errors = gql.errors, !errors.isEmpty {
            print("[ShopifyService] GraphQL ERRORS: \(errors.map(\.message).joined(separator: ", "))")
            throw ShopifyError.graphQL(errors.map(\.message).joined(separator: ", "))
        }
        guard let result = gql.data else {
            print("[ShopifyService] WARNING: gql.data is nil (no errors reported)")
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
                      image { url altText }
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
                  image { url altText }
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

    func isStorefrontPurchasable(handle: String) async -> Bool {
        (try? await fetchProductByHandle(handle)) != nil
    }

    // MARK: - Collection Products

    func fetchCollectionProducts(handle: String, first: Int = 20) async throws -> [ShopifyProduct] {
        print("[ShopifyService] fetchCollectionProducts START — handle='\(handle)', first=\(first)")
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
                                        image { url altText }
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
        print("[ShopifyService] Executing GraphQL query for collection '\(handle)'...")
        let result: CollectionResponse = try await execute(query: query, variables: vars)

        if let collection = result.collection {
            let products = collection.products.edges.map(\.node)
            print("[ShopifyService] Collection '\(handle)' found — \(products.count) products")
            if !products.isEmpty { return products }
        } else {
            print("[ShopifyService] WARNING: collection '\(handle)' returned nil — trying JSON fallback")
        }

        let jsonProducts = try await fetchCollectionProductsFromJSON(handle: handle, limit: first)
        let hydrated = await hydrateJSONProducts(jsonProducts)
        print("[ShopifyService] Collection '\(handle)' JSON fallback — \(hydrated.count) products")
        return hydrated
    }

    private func hydrateJSONProducts(_ jsonProducts: [ShopifyProduct]) async -> [ShopifyProduct] {
        var result: [ShopifyProduct] = []
        for jsonProduct in jsonProducts {
            if let storefront = try? await fetchProductByHandle(jsonProduct.handle) {
                result.append(storefront)
                print("[ShopifyService] Hydrated '\(jsonProduct.handle)' from Storefront API")
            } else {
                result.append(jsonProduct)
                print("[ShopifyService] '\(jsonProduct.handle)' not in Storefront API — display only")
            }
        }
        return result
    }

    /// Hämtar exakt de produkter som tillhör en kollektion via Shopifys publika
    /// `/collections/{handle}/products.json`-endpoint. Används när Storefront GraphQL
    /// returnerar tom lista (t.ex. produkter publicerade till Online Store men inte Headless).
    private func fetchCollectionProductsFromJSON(handle: String, limit: Int) async throws -> [ShopifyProduct] {
        guard let url = URL(string: "https://\(shopDomain)/collections/\(handle)/products.json?limit=\(limit)") else {
            return []
        }

        let (data, response) = try await session.data(from: url)
        guard let http = response as? HTTPURLResponse, (200...299).contains(http.statusCode) else {
            let code = (response as? HTTPURLResponse)?.statusCode ?? -1
            print("[ShopifyService] Collection JSON HTTP ERROR \(code) for '\(handle)'")
            return []
        }

        let payload = try decoder.decode(CollectionProductsJSONResponse.self, from: data)
        return payload.products.map(mapJSONProductToShopifyProduct)
    }

    private func mapJSONProductToShopifyProduct(_ product: CollectionJSONProduct) -> ShopifyProduct {
        let imageEdges = product.images.map { image in
            ShopifyEdge(
                node: ShopifyImage(url: image.src, altText: image.alt),
                cursor: nil
            )
        }
        let variantEdges = product.variants.map { variant in
            ShopifyEdge(
                node: ShopifyVariant(
                    id: "gid://shopify/ProductVariant/\(variant.id)",
                    title: variant.title,
                    availableForSale: variant.available,
                    price: ShopifyMoney(amount: variant.price, currencyCode: "SEK"),
                    selectedOptions: variant.option1.map { [ShopifyOption(name: "Storlek", value: $0)] } ?? [],
                    image: variant.featured_image.map { ShopifyImage(url: $0.src, altText: $0.alt) }
                ),
                cursor: nil
            )
        }

        let prices = product.variants.map { Double($0.price) ?? 0 }
        let minPrice = prices.min() ?? 0
        let maxPrice = prices.max() ?? minPrice
        let money = { (amount: Double) in ShopifyMoney(amount: String(format: "%.2f", amount), currencyCode: "SEK") }

        return ShopifyProduct(
            id: "gid://shopify/Product/\(product.id)",
            title: product.title,
            handle: product.handle,
            description: product.body_html ?? "",
            productType: product.product_type,
            vendor: product.vendor,
            tags: product.tags,
            images: ShopifyConnection(edges: imageEdges),
            variants: ShopifyConnection(edges: variantEdges),
            priceRange: ShopifyPriceRange(
                minVariantPrice: money(minPrice),
                maxVariantPrice: money(maxPrice)
            )
        )
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

// MARK: - Collection JSON API (Online Store)

private struct CollectionProductsJSONResponse: Decodable {
    let products: [CollectionJSONProduct]
}

private struct CollectionJSONProduct: Decodable {
    let id: Int
    let title: String
    let handle: String
    let body_html: String?
    let vendor: String
    let product_type: String
    let tags: [String]
    let variants: [CollectionJSONVariant]
    let images: [CollectionJSONImage]
}

private struct CollectionJSONVariant: Decodable {
    let id: Int
    let title: String
    let available: Bool
    let price: String
    let option1: String?
    let featured_image: CollectionJSONImage?
}

private struct CollectionJSONImage: Decodable {
    let src: String
    let alt: String?
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
