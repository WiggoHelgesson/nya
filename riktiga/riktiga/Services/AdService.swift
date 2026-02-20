import Foundation
import SwiftUI
import Combine
import Supabase

struct AdCampaign: Identifiable, Codable {
    let id: String
    let format: String
    let title: String
    let description: String?
    let image_url: String?
    let cta_text: String?
    let cta_url: String?
    
    var imageURL: URL? {
        guard let urlString = image_url else { return nil }
        return URL(string: urlString)
    }
    
    var ctaURL: URL? {
        guard let urlString = cta_url else { return nil }
        return URL(string: urlString)
    }
    
    var ctaLabel: String {
        cta_text ?? "Läs mer"
    }
}

private struct GetActiveAdsResponse: Codable {
    let ads: [AdCampaign]
}

@MainActor
class AdService: ObservableObject {
    static let shared = AdService()
    
    @Published var feedAds: [AdCampaign] = []
    @Published var bannerAds: [AdCampaign] = []
    @Published var popupAd: AdCampaign?
    
    private var feedCacheTime: Date?
    private var bannerCacheTime: Date?
    private var popupCacheTime: Date?
    private let cacheDuration: TimeInterval = 300 // 5 min
    
    private let popupCooldownKey = "lastPopupAdShown"
    private let popupCooldown: TimeInterval = 86400 // 24h
    
    private init() {}
    
    // MARK: - Fetch Ads
    
    func fetchFeedAds() async {
        if let cacheTime = feedCacheTime, Date().timeIntervalSince(cacheTime) < cacheDuration, !feedAds.isEmpty {
            return
        }
        if let ads = await fetchAds(format: "feed") {
            feedAds = ads
            feedCacheTime = Date()
        }
    }
    
    func fetchBannerAds() async {
        if let cacheTime = bannerCacheTime, Date().timeIntervalSince(cacheTime) < cacheDuration, !bannerAds.isEmpty {
            return
        }
        if let ads = await fetchAds(format: "banner") {
            bannerAds = ads
            bannerCacheTime = Date()
        }
    }
    
    func fetchPopupAd() async {
        let lastShown = UserDefaults.standard.double(forKey: popupCooldownKey)
        if lastShown > 0, Date().timeIntervalSince1970 - lastShown < popupCooldown {
            popupAd = nil
            return
        }
        
        if let cacheTime = popupCacheTime, Date().timeIntervalSince(cacheTime) < cacheDuration {
            return
        }
        
        if let ads = await fetchAds(format: "popup"), let first = ads.first {
            popupAd = first
            popupCacheTime = Date()
        } else {
            popupAd = nil
        }
    }
    
    func markPopupShown() {
        UserDefaults.standard.set(Date().timeIntervalSince1970, forKey: popupCooldownKey)
        popupAd = nil
    }
    
    // MARK: - Track Click
    
    func trackClick(campaignId: String) {
        Task {
            do {
                try await SupabaseConfig.supabase.functions.invoke(
                    "track-ad-click",
                    options: FunctionInvokeOptions(body: ["campaign_id": campaignId])
                )
            } catch {
                print("⚠️ Failed to track ad click: \(error)")
            }
        }
    }
    
    // MARK: - Private
    
    private func fetchAds(format: String) async -> [AdCampaign]? {
        do {
            let response: GetActiveAdsResponse = try await SupabaseConfig.supabase.functions.invoke(
                "get-active-ads",
                options: FunctionInvokeOptions(body: ["format": format])
            )
            return response.ads
        } catch {
            print("⚠️ Failed to fetch \(format) ads: \(error)")
            return nil
        }
    }
}
