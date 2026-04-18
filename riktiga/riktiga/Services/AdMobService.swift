import Foundation
import SwiftUI
import Combine
import AppTrackingTransparency

#if canImport(GoogleMobileAds)
import GoogleMobileAds
#endif

#if canImport(UserMessagingPlatform)
import UserMessagingPlatform
#endif

/// Handles Google AdMob bootstrap (ATT + UMP consent + SDK start) and preloads
/// native ads for inline feed insertion. Pro users never hit this service.
@MainActor
final class AdMobService: NSObject, ObservableObject {
    static let shared = AdMobService()

    #if canImport(GoogleMobileAds)
    @Published private(set) var nativeAds: [NativeAd] = []
    #else
    @Published private(set) var nativeAds: [Any] = []
    #endif

    @Published private(set) var isInitialized = false

    #if DEBUG
    private let nativeAdUnitId = "ca-app-pub-3940256099942544/3986624511" // Google test
    #else
    private let nativeAdUnitId = "ca-app-pub-7998412098246140/3202590470" // prod
    #endif

    // NOTE: MultipleAdsAdLoaderOptions.numberOfAds is capped at 5 by the
    // Google Mobile Ads SDK. Keep preloadCount in sync with that limit.
    private let preloadCount = 5

    // MARK: - Contextual targeting
    //
    // Signals sent with every native ad request so Google's auction skews
    // toward sport / training / retail advertisers. Works even when ATT is
    // denied since it is pure contextual targeting (not user-level).

    private let primaryContentURL = "https://upanddownapp.com/collections/up-down"

    private let neighboringContentURLs: [String] = [
        "https://upanddownapp.com/collections/upanddown",
        "https://upanddownapp.com/collections/up-down",
        "https://upanddownapp.com/products/up-down-pase",
        "https://upanddownapp.com/"
    ]

    private let targetingKeywords: [String] = [
        "sport", "gym", "training", "fitness", "workout",
        "running", "löpning", "padel", "tennis", "golf",
        "sportswear", "sportkläder", "sneakers", "activewear",
        "nike", "adidas", "puma", "asics", "under armour",
        "j.lindeberg", "gymshark", "xxl", "stadium", "intersport"
    ]

    #if canImport(GoogleMobileAds)
    private var adLoader: AdLoader?

    /// Builds a native ad `Request` pre-populated with our contextual
    /// targeting signals. Google crawls `contentURL` / `neighboringContentURLs`
    /// to infer topical category and also uses `keywords` as a hint.
    private func makeTargetedRequest() -> Request {
        let request = Request()
        request.contentURL = primaryContentURL
        request.neighboringContentURLs = neighboringContentURLs
        request.keywords = targetingKeywords
        return request
    }
    #endif

    private override init() {
        super.init()
    }

    // MARK: - Bootstrap

    func bootstrap() async {
        #if canImport(GoogleMobileAds)
        #if DEBUG
        let buildType = "DEBUG"
        #else
        let buildType = "RELEASE"
        #endif
        print("[AdMob] bootstrap start — build=\(buildType) adUnitId=\(nativeAdUnitId) sdkVersion=\(MobileAds.shared.versionNumber)")

        await requestConsent()
        await requestATT()

        #if DEBUG
        // iOS simulators are automatically treated as test devices by Google Mobile
        // Ads SDK v11+, so no explicit simulator ID is needed. To also register a
        // physical iPhone as a test device, run the app once on the device, copy
        // the hash printed in Xcode's console ("To get test ads on this device, set:
        // Mobile Ads SDK Test Device Hashes..."), and add it to the array below.
        MobileAds.shared.requestConfiguration.testDeviceIdentifiers = [
            // "PASTE_PHYSICAL_DEVICE_HASH_HERE",
        ]
        #endif

        print("[AdMob] calling MobileAds.shared.start()")
        let status = await MobileAds.shared.start()
        let adapters = status.adapterStatusesByClassName
        print("[AdMob] MobileAds.start() completed — adapterCount=\(adapters.count)")
        for (className, adapterStatus) in adapters {
            let stateName: String
            switch adapterStatus.state {
            case .notReady: stateName = "notReady"
            case .ready: stateName = "ready"
            @unknown default: stateName = "unknown(\(adapterStatus.state.rawValue))"
            }
            print("[AdMob]   adapter=\(className) state=\(stateName) latency=\(adapterStatus.latency) desc=\(adapterStatus.description)")
        }

        isInitialized = true
        print("[AdMob] isInitialized=true — triggering preload()")
        preload()
        #else
        print("[AdMob] GoogleMobileAds SDK not linked at compile time. Skipping bootstrap.")
        #endif
    }

    // MARK: - Consent (UMP)

    private func requestConsent() async {
        #if canImport(UserMessagingPlatform)
        let info = ConsentInformation.shared
        print("[AdMob] UMP before update — consentStatus=\(Self.describe(info.consentStatus)) canRequestAds=\(info.canRequestAds) formStatus=\(Self.describe(info.formStatus))")

        let parameters = RequestParameters()
        await withCheckedContinuation { (cont: CheckedContinuation<Void, Never>) in
            info.requestConsentInfoUpdate(with: parameters) { error in
                if let error {
                    print("[AdMob] UMP info update FAILED: \(error.localizedDescription) — canRequestAds=\(info.canRequestAds) consentStatus=\(Self.describe(info.consentStatus))")
                    cont.resume()
                    return
                }
                print("[AdMob] UMP info update OK — consentStatus=\(Self.describe(info.consentStatus)) canRequestAds=\(info.canRequestAds) formStatus=\(Self.describe(info.formStatus))")
                Task { @MainActor in
                    guard let presenter = Self.topViewController() else {
                        print("[AdMob] UMP: no topViewController available to present consent form. Skipping.")
                        cont.resume()
                        return
                    }
                    do {
                        try await ConsentForm.loadAndPresentIfRequired(from: presenter)
                        print("[AdMob] UMP consent form handled — consentStatus=\(Self.describe(info.consentStatus)) canRequestAds=\(info.canRequestAds)")
                    } catch {
                        print("[AdMob] UMP consent form FAILED: \(error.localizedDescription) — canRequestAds=\(info.canRequestAds)")
                    }
                    cont.resume()
                }
            }
        }
        #else
        print("[AdMob] UserMessagingPlatform not linked at compile time — skipping consent")
        #endif
    }

    #if canImport(UserMessagingPlatform)
    private static func describe(_ status: ConsentStatus) -> String {
        switch status {
        case .unknown: return "unknown"
        case .required: return "required"
        case .notRequired: return "notRequired"
        case .obtained: return "obtained"
        @unknown default: return "unknown(\(status.rawValue))"
        }
    }

    private static func describe(_ status: FormStatus) -> String {
        switch status {
        case .unknown: return "unknown"
        case .available: return "available"
        case .unavailable: return "unavailable"
        @unknown default: return "unknown(\(status.rawValue))"
        }
    }
    #endif

    // MARK: - ATT

    private func requestATT() async {
        let before = ATTrackingManager.trackingAuthorizationStatus
        print("[AdMob] ATT before — status=\(Self.describe(before))")
        guard before == .notDetermined else {
            print("[AdMob] ATT already determined — skipping prompt")
            return
        }
        let result = await ATTrackingManager.requestTrackingAuthorization()
        print("[AdMob] ATT after prompt — status=\(Self.describe(result))")
    }

    private static func describe(_ status: ATTrackingManager.AuthorizationStatus) -> String {
        switch status {
        case .notDetermined: return "notDetermined"
        case .restricted: return "restricted"
        case .denied: return "denied"
        case .authorized: return "authorized"
        @unknown default: return "unknown(\(status.rawValue))"
        }
    }

    // MARK: - Preload Native Ads

    func preload() {
        #if canImport(GoogleMobileAds)
        guard let root = Self.topViewController() else {
            let sceneCount = UIApplication.shared.connectedScenes.count
            let windowSceneCount = UIApplication.shared.connectedScenes.compactMap { $0 as? UIWindowScene }.count
            print("[AdMob] preload ABORTED: no root view controller — connectedScenes=\(sceneCount) windowScenes=\(windowSceneCount)")
            return
        }
        // Use MultipleAdsAdLoaderOptions so a SINGLE load() call can deliver
        // up to `preloadCount` native ads via separate didReceive callbacks.
        // The previous implementation called load() in a loop on the same
        // AdLoader, which caused every call after the first to be dropped
        // because the loader was already busy — so only slot 0 ever filled.
        let multipleOptions = MultipleAdsAdLoaderOptions()
        multipleOptions.numberOfAds = preloadCount

        print("[AdMob] preload starting — adUnitId=\(nativeAdUnitId) numberOfAds=\(preloadCount) rootVC=\(type(of: root))")
        print("[AdMob] targeting — contentURL=\(primaryContentURL) neighbors=\(neighboringContentURLs.count) keywords=\(targetingKeywords.count)")

        let loader = AdLoader(
            adUnitID: nativeAdUnitId,
            rootViewController: root,
            adTypes: [.native],
            options: [multipleOptions]
        )
        loader.delegate = self
        self.adLoader = loader
        loader.load(makeTargetedRequest())
        #else
        print("[AdMob] preload skipped — GoogleMobileAds not linked")
        #endif
    }

    // MARK: - Helpers

    private static func topViewController() -> UIViewController? {
        let scene = UIApplication.shared.connectedScenes
            .compactMap { $0 as? UIWindowScene }
            .first { $0.activationState == .foregroundActive } ?? UIApplication.shared.connectedScenes.compactMap { $0 as? UIWindowScene }.first
        guard let window = scene?.windows.first(where: { $0.isKeyWindow }) ?? scene?.windows.first else { return nil }
        var top = window.rootViewController
        while let presented = top?.presentedViewController {
            top = presented
        }
        return top
    }
}

// MARK: - Feed diagnostics

/// One-shot per-session loggers for the social feed ad slots. Prevents log
/// spam when SwiftUI re-evaluates bodies while still surfacing the first time
/// an ad slot is filled or skipped so you can correlate with bootstrap logs.
@MainActor
enum AdFeedDiagnostics {
    private static var loggedFills = Set<Int>()
    private static var loggedMisses = Set<Int>()

    static func logFill(slot: Int, loadedCount: Int) {
        guard !loggedFills.contains(slot) else { return }
        loggedFills.insert(slot)
        print("[AdMob] feed slot=\(slot) FILLED — loadedAds=\(loadedCount)")
    }

    static func logMiss(slot: Int, isPro: Bool, isInitialized: Bool, loadedCount: Int) {
        guard !loggedMisses.contains(slot) else { return }
        loggedMisses.insert(slot)
        print("[AdMob] feed slot=\(slot) SKIPPED — isPro=\(isPro) isInitialized=\(isInitialized) loadedAds=\(loadedCount)")
    }
}

#if canImport(GoogleMobileAds)
extension AdMobService: NativeAdLoaderDelegate {
    nonisolated func adLoader(_ adLoader: AdLoader, didReceive nativeAd: NativeAd) {
        let headline = nativeAd.headline ?? "<nil>"
        let adapter = nativeAd.responseInfo.adNetworkInfoArray.first?.adNetworkClassName ?? "<unknown>"
        Task { @MainActor in
            self.nativeAds.append(nativeAd)
            print("[AdMob] didReceive native ad — headline=\"\(headline)\" adapter=\(adapter) totalLoaded=\(self.nativeAds.count)")
        }
    }

    nonisolated func adLoader(_ adLoader: AdLoader, didFailToReceiveAdWithError error: any Error) {
        let ns = error as NSError
        print("[AdMob] Native ad FAILED — domain=\(ns.domain) code=\(ns.code) desc=\(ns.localizedDescription)")
        print("[AdMob]   userInfo=\(ns.userInfo)")
    }
}
#endif
