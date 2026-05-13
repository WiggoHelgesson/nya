import SwiftUI

/// Shared namespace used by the marketplace hero-zoom transition. Source
/// views (annons-cards) attach `.matchedTransitionSource(id:in:)` and the
/// pushed `CommunityListingDetailView` calls `.navigationTransition(.zoom(...))`
/// using the same namespace. We carry the `Namespace.ID` via the
/// environment so both sides share it without manual prop-drilling.
private struct MarketplaceHeroNamespaceKey: EnvironmentKey {
    static let defaultValue: Namespace.ID? = nil
}

extension EnvironmentValues {
    var marketplaceHeroNamespace: Namespace.ID? {
        get { self[MarketplaceHeroNamespaceKey.self] }
        set { self[MarketplaceHeroNamespaceKey.self] = newValue }
    }
}

/// Hashable navigation route for the community marketplace.
///
/// Lets us push annons-detail, "Köp nu"-checkout and "Prisförslag" as
/// real pages onto a `NavigationStack` (instead of the previous sheet
/// modals). Each `NavigationStack` that wants to host the marketplace
/// flow attaches the routes via `.marketplaceDestinations(...)`.
///
/// Apply once at the stack root:
///
/// ```swift
/// NavigationStack(path: $path) {
///     content
///         .marketplaceDestinations()
/// }
/// ```
///
/// Then push:
///
/// ```swift
/// NavigationLink(value: MarketplaceRoute.listing(row)) { card }
/// ```
enum MarketplaceRoute: Hashable {
    case listing(ConsignmentSubmissionRow)
    case checkout(ConsignmentSubmissionRow)
    case priceOffer(ConsignmentSubmissionRow)
    case orderDetail(MarketplaceOrderRow)
    /// När vi bara har order-id (t.ex. systemmeddelande `purchase_completed`).
    case orderDetailById(UUID)
}

extension View {
    /// Registers all marketplace destinations on the enclosing
    /// `NavigationStack`. Idempotent — safe to attach in multiple places
    /// because SwiftUI dedupes by route type.
    @ViewBuilder
    func marketplaceDestinations() -> some View {
        self
            .navigationDestination(for: MarketplaceRoute.self) { route in
                switch route {
                case .listing(let row):
                    CommunityListingDetailView(row: row)
                        .modifier(MarketplaceHeroDestinationModifier(id: row.id))
                case .checkout(let row):
                    MarketplaceCheckoutView(row: row)
                case .priceOffer(let row):
                    PriceOfferSheetView(row: row)
                case .orderDetail(let order):
                    OrderDetailView(orderId: order.id, initialOrder: order)
                case .orderDetailById(let id):
                    OrderDetailView(orderId: id, initialOrder: nil)
                }
            }
    }
}

// MARK: - Hero zoom (iOS 18+) with iOS 17 fallback

/// Attaches `.matchedTransitionSource(id:in:)` on iOS 18+ so the cell
/// participates in the zoom-push to `CommunityListingDetailView`. On
/// iOS 17 the modifier is a no-op (default slide-push is used).
struct MarketplaceHeroSourceModifier: ViewModifier {
    let id: UUID
    let namespace: Namespace.ID?

    func body(content: Content) -> some View {
        if #available(iOS 18.0, *), let ns = namespace {
            content.matchedTransitionSource(id: id, in: ns)
        } else {
            content
        }
    }
}

/// Mirror of `MarketplaceHeroSourceModifier` for the destination side.
struct MarketplaceHeroDestinationModifier: ViewModifier {
    @Environment(\.marketplaceHeroNamespace) private var namespace
    let id: UUID

    func body(content: Content) -> some View {
        if #available(iOS 18.0, *), let ns = namespace {
            content.navigationTransition(.zoom(sourceID: id, in: ns))
        } else {
            content
        }
    }
}

// MARK: - Pressable card button style

/// Subtle scale-down + opacity on press, Blocket-style. Used on annons-
/// kort i feeden/profilen så det känns att man "trycker ner" kortet
/// innan navigeringen tar vid.
struct PressableCardButtonStyle: ButtonStyle {
    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .scaleEffect(configuration.isPressed ? 0.97 : 1.0)
            .opacity(configuration.isPressed ? 0.92 : 1.0)
            .animation(.easeOut(duration: 0.18), value: configuration.isPressed)
            .contentShape(Rectangle())
    }
}
