//
//  AppLaunchCoordinator.swift
//  Up&Down
//
//  Central "app ready" gate. Warms up the critical caches and data the first
//  tab (Social) needs so the in-app loading overlay can dismiss with the feed
//  fully rendered instead of letting content pop in piece by piece.
//
//  Splash screen stays fast and unchanged. This coordinator drives the
//  AppLoadingOverlay that sits on top of MainTabView right after splash.
//

import Foundation
import SwiftUI
import Combine

@MainActor
final class AppLaunchCoordinator: ObservableObject {
    static let shared = AppLaunchCoordinator()

    @Published private(set) var isReady: Bool = false
    @Published private(set) var phase: String = "idle"

    /// Hard upper bound — overlay will never stay up longer than this, even if
    /// network is dead. Tuned for "just long enough to warm caches on a good
    /// connection, not so long users feel stuck on a bad one."
    private let hardTimeout: TimeInterval = 4.0

    private var hasStarted: Bool = false

    private init() {}

    /// Called when there is no logged-in user: overlay dismisses immediately
    /// so the auth screen shows without delay.
    func markReadyImmediately() {
        guard !isReady else { return }
        phase = "logged-out shortcut"
        print("[Launch] markReadyImmediately — phase=\(phase)")
        isReady = true
    }

    /// Reset state on logout so the next login triggers a fresh warmup.
    func reset() {
        print("[Launch] reset — was isReady=\(isReady) hasStarted=\(hasStarted)")
        isReady = false
        hasStarted = false
        phase = "idle"
    }

    /// Kick off parallel preload. Idempotent within a single session.
    func start(userId: String) async {
        guard !hasStarted else { return }
        hasStarted = true
        phase = "starting"
        print("[Launch] start — userId=\(userId)")

        let startDate = Date()

        // Fast path: if AppCacheManager already has cached feed posts,
        // hydrate the in-memory view model synchronously, reveal the UI
        // immediately, and run the full warmup silently in the background.
        // Users with a warm cache never see the loader.
        if SocialViewModel.shared.hydrateFromCache(userId: userId) {
            print("[Launch] cache HIT — revealing UI instantly, refreshing in background")
            isReady = true
            phase = "ready (cache)"
            Task { await self.runWarmup(userId: userId) }
            return
        }

        // Slow path (cache miss): run the warmup behind the loader gate,
        // with the 4s hard timeout so we never block the user indefinitely.
        print("[Launch] cache MISS — running full warmup with loader")
        async let warmup: Void = runWarmup(userId: userId)
        async let timeout: Void = runHardTimeout()
        _ = await (warmup, timeout)

        if !isReady {
            isReady = true
        }
        phase = "ready"
        print("[Launch] ready — elapsed=\(String(format: "%.2f", Date().timeIntervalSince(startDate)))s")
    }

    // MARK: - Warmup

    private func runWarmup(userId: String) async {
        phase = "warming"
        print("[Launch] warmup starting")

        async let session: Void = warmSession()
        async let feed: Void = warmFeed(userId: userId)
        async let stories: Void = warmStories(userId: userId)
        async let activeFriends: Void = warmActiveFriends(userId: userId)
        async let collection: Void = warmShopifyCollection()
        async let feedAds: Void = warmFeedAds()

        _ = await (session, feed, stories, activeFriends, collection, feedAds)

        // Once feed + collection are in, prefetch the first images so the
        // very first scroll frame has them ready in memory.
        await warmImagePrefetch()

        if !isReady {
            isReady = true
        }
    }

    private func runHardTimeout() async {
        let ns = UInt64(hardTimeout * 1_000_000_000)
        try? await Task.sleep(nanoseconds: ns)
        if !isReady {
            print("[Launch] hard timeout hit — releasing overlay")
            isReady = true
        }
    }

    // MARK: - Individual warmup steps (each swallows its own errors)

    private func warmSession() async {
        do {
            try await AuthSessionManager.shared.ensureValidSession()
            print("[Launch] session OK")
        } catch {
            print("[Launch] session FAILED: \(error.localizedDescription)")
        }
    }

    private func warmFeed(userId: String) async {
        print("[Launch] feed fetch start")
        await SocialViewModel.shared.fetchSocialFeedAsync(userId: userId)
        print("[Launch] feed fetch done — posts=\(SocialViewModel.shared.posts.count)")
    }

    private func warmStories(userId: String) async {
        do {
            _ = try await StoryService.shared.fetchMyStories(userId: userId)
        } catch {
            print("[Launch] myStories FAILED: \(error.localizedDescription)")
        }
        do {
            _ = try await StoryService.shared.fetchFriendsStories(userId: userId)
        } catch {
            print("[Launch] friendsStories FAILED: \(error.localizedDescription)")
        }
    }

    private func warmActiveFriends(userId: String) async {
        try? await ActiveSessionService.shared.cleanupStaleSessions()
        do {
            _ = try await ActiveSessionService.shared.fetchActiveFriends(userId: userId)
            print("[Launch] activeFriends OK")
        } catch {
            print("[Launch] activeFriends FAILED: \(error.localizedDescription)")
        }
    }

    private func warmShopifyCollection() async {
        do {
            let products = try await ShopifyService.shared.fetchCollectionProducts(handle: "up-down")
            print("[Launch] shopify up-down OK — count=\(products.count)")
            let imageUrls = products.compactMap { $0.images.edges.first?.node.url }
            if !imageUrls.isEmpty {
                ImageCacheManager.shared.prefetch(urls: imageUrls)
            }
        } catch {
            print("[Launch] shopify up-down FAILED: \(error.localizedDescription)")
        }
    }

    private func warmFeedAds() async {
        await AdService.shared.fetchFeedAds()
        print("[Launch] feedAds OK")
    }

    private func warmImagePrefetch() async {
        // Grab the first handful of post media URLs and prime the image cache
        // so the very first frame of the feed paints instantly.
        let posts = SocialViewModel.shared.posts.prefix(6)
        var urls: [String] = []
        for post in posts {
            if let media = post.userImageUrl, !media.isEmpty {
                urls.append(media)
            } else if let route = post.imageUrl, !route.isEmpty {
                urls.append(route)
            }
            if let avatar = post.userAvatarUrl, !avatar.isEmpty {
                urls.append(avatar)
            }
        }
        guard !urls.isEmpty else { return }
        await ImageCacheManager.shared.prefetchHighPriority(urls: urls)
        print("[Launch] image prefetch OK — count=\(urls.count)")
    }
}
