import Foundation

/// Helpers for `workout-images` storage paths and public URLs (see `workout_images_bucket_public_read.sql`).
enum WorkoutImageURL {
    private static let bucketSegment = "workout-images"

    /// Object key after `workout-images/` in a storage URL path (sign or public).
    static func objectKey(from urlString: String) -> String? {
        let trimmed = urlString.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return nil }
        let rewritten = SupabaseConfig.rewriteURL(trimmed)
        guard let url = URL(string: rewritten) else { return nil }
        let parts = url.path.split(separator: "/").map(String.init)
        guard let idx = parts.lastIndex(of: bucketSegment), idx + 1 < parts.count else { return nil }
        return parts[(idx + 1)...].joined(separator: "/")
    }

    /// Public object URL on the app project host (no token). Requires bucket public read policy.
    static func publicURLString(forObjectKey key: String) -> String {
        var allowed = CharacterSet.urlPathAllowed
        allowed.remove(charactersIn: "/")
        let encoded = key.split(separator: "/")
            .map { String($0).addingPercentEncoding(withAllowedCharacters: allowed) ?? String($0) }
            .joined(separator: "/")
        return "\(SupabaseConfig.projectURL.absoluteString)/storage/v1/object/public/\(bucketSegment)/\(encoded)"
    }

    /// When a signed URL fails (truncated token, proxy, expiry), retry via public URL if policy allows.
    static func publicFallbackURL(from urlString: String) -> String? {
        guard shouldTryPublicFallback(for: urlString) else { return nil }
        guard let key = objectKey(from: urlString), !key.isEmpty else { return nil }
        return publicURLString(forObjectKey: key)
    }

    static func shouldTryPublicFallback(for urlString: String) -> Bool {
        let s = SupabaseConfig.rewriteURL(urlString)
        return s.localizedCaseInsensitiveContains("/object/sign/")
    }

    /// True when URL targets `/object/sign/` but has no `token` query (e.g. DB truncated the signed URL). Do not GET this URL.
    static func signURLMissingToken(_ urlString: String) -> Bool {
        let trimmed = urlString.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return false }
        let s = SupabaseConfig.rewriteURL(trimmed)
        guard s.localizedCaseInsensitiveContains("/object/sign/") else { return false }
        guard let components = URLComponents(string: s) else { return true }
        let token = components.queryItems?.first { $0.name == "token" }?.value
        return token == nil || (token?.isEmpty ?? true)
    }
}
