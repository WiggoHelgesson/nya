import Foundation
import Combine
import Supabase

/// Hanterar produktfavoriter (hjärtan) i Vår shop.
/// Favoriter lagras i Supabase-tabellen `product_favorites` per produkt-handle,
/// och antal likes per produkt visas på produktkorten som social proof.
@MainActor
final class ProductFavoritesService: ObservableObject {
    static let shared = ProductFavoritesService()

    /// Produkthandles som den inloggade användaren har gillat.
    @Published private(set) var favoriteHandles: Set<String> = []

    /// Totalt antal likes per produkt-handle (alla användare).
    @Published private(set) var counts: [String: Int] = [:]

    private let supabase = SupabaseConfig.supabase
    private var hasLoadedFavorites = false

    private init() {}

    func isFavorite(_ handle: String) -> Bool {
        favoriteHandles.contains(handle)
    }

    // MARK: - Loading

    func loadFavorites() async {
        guard !hasLoadedFavorites else { return }
        do {
            let session = try await supabase.auth.session
            struct Row: Decodable {
                let productHandle: String
                enum CodingKeys: String, CodingKey {
                    case productHandle = "product_handle"
                }
            }
            let rows: [Row] = try await supabase
                .from("product_favorites")
                .select("product_handle")
                .eq("user_id", value: session.user.id.uuidString)
                .execute()
                .value
            favoriteHandles = Set(rows.map(\.productHandle))
            hasLoadedFavorites = true
        } catch {
            print("[ProductFavoritesService] Failed to load favorites: \(error)")
        }
    }

    /// Hämtar like-räknare för en uppsättning produkter (t.ex. synliga i griden).
    func loadCounts(handles: [String]) async {
        let unique = Array(Set(handles))
        guard !unique.isEmpty else { return }
        do {
            struct Row: Decodable {
                let productHandle: String
                enum CodingKeys: String, CodingKey {
                    case productHandle = "product_handle"
                }
            }
            let rows: [Row] = try await supabase
                .from("product_favorites")
                .select("product_handle")
                .in("product_handle", values: unique)
                .execute()
                .value

            var newCounts: [String: Int] = [:]
            for row in rows {
                newCounts[row.productHandle, default: 0] += 1
            }
            for handle in unique where newCounts[handle] == nil {
                newCounts[handle] = 0
            }
            counts.merge(newCounts) { _, new in new }
        } catch {
            print("[ProductFavoritesService] Failed to load counts: \(error)")
        }
    }

    // MARK: - Toggle

    /// Optimistisk toggle: uppdaterar UI direkt och synkar mot Supabase i bakgrunden.
    func toggle(handle: String) {
        if favoriteHandles.contains(handle) {
            favoriteHandles.remove(handle)
            counts[handle] = max((counts[handle] ?? 1) - 1, 0)
            Task { await removeRemote(handle) }
        } else {
            favoriteHandles.insert(handle)
            counts[handle, default: 0] += 1
            Task { await insertRemote(handle) }
        }
    }

    private func insertRemote(_ handle: String) async {
        do {
            let session = try await supabase.auth.session
            struct Insert: Encodable {
                let user_id: String
                let product_handle: String
            }
            try await supabase
                .from("product_favorites")
                .upsert(
                    Insert(user_id: session.user.id.uuidString, product_handle: handle),
                    onConflict: "user_id,product_handle"
                )
                .execute()
        } catch {
            print("[ProductFavoritesService] Failed to insert favorite: \(error)")
            favoriteHandles.remove(handle)
            counts[handle] = max((counts[handle] ?? 1) - 1, 0)
        }
    }

    private func removeRemote(_ handle: String) async {
        do {
            let session = try await supabase.auth.session
            try await supabase
                .from("product_favorites")
                .delete()
                .eq("user_id", value: session.user.id.uuidString)
                .eq("product_handle", value: handle)
                .execute()
        } catch {
            print("[ProductFavoritesService] Failed to remove favorite: \(error)")
            favoriteHandles.insert(handle)
            counts[handle, default: 0] += 1
        }
    }
}
