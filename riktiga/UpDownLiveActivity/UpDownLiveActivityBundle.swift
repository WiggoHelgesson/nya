//
//  UpDownLiveActivityBundle.swift
//  UpDownLiveActivity
//
//  Created by Wiggo Helgesson on 2026-01-05.
//

import WidgetKit
import SwiftUI

@main
struct UpDownLiveActivityBundle: WidgetBundle {
    var body: some Widget {
        // Home Screen Widgets
        StreakWidget()
        CaloriesWidget()
        DetailedNutritionWidget()
        
        // Live Activity
        UpDownLiveActivityLiveActivity()
        
        // Control Center Widget
        UpDownLiveActivityControl()
    }
}
