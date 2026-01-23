//
//  SuperwallService.swift
//  Up&Down
//
//  Created by Wiggo Helgesson on 2026-01-18.
//

import Foundation
import SuperwallKit

final class SuperwallService {
    static let shared = SuperwallService()
    
    private init() {}
    
    /// Show the paywall using Superwall
    /// - Parameter placement: The placement name configured in Superwall dashboard (default: "campaign_trigger")
    func showPaywall(placement: String = "campaign_trigger") {
        Superwall.shared.register(placement: placement)
        print("🎯 Superwall: Registering placement '\(placement)'")
    }
    
    /// Alternative method to trigger paywall with a handler
    func showPaywall(placement: String = "campaign_trigger", handler: PaywallPresentationHandler? = nil) {
        if let handler = handler {
            Superwall.shared.register(placement: placement, handler: handler)
        } else {
            Superwall.shared.register(placement: placement)
        }
        print("🎯 Superwall: Registering placement '\(placement)'")
    }
}

