//
//  StreakWidget.swift
//  UpDownLiveActivity
//
//  Widget som visar användarens streak
//

import WidgetKit
import SwiftUI

// MARK: - Streak Widget Provider
struct StreakWidgetProvider: TimelineProvider {
    func placeholder(in context: Context) -> StreakWidgetEntry {
        StreakWidgetEntry(date: Date(), streak: 7)
    }
    
    func getSnapshot(in context: Context, completion: @escaping (StreakWidgetEntry) -> Void) {
        let entry = StreakWidgetEntry(
            date: Date(),
            streak: WidgetDataManager.getCurrentStreak()
        )
        completion(entry)
    }
    
    func getTimeline(in context: Context, completion: @escaping (Timeline<StreakWidgetEntry>) -> Void) {
        let currentDate = Date()
        let streak = WidgetDataManager.getCurrentStreak()
        
        let entry = StreakWidgetEntry(date: currentDate, streak: streak)
        
        // Refresh every hour
        let nextUpdate = Calendar.current.date(byAdding: .hour, value: 1, to: currentDate) ?? currentDate
        let timeline = Timeline(entries: [entry], policy: .after(nextUpdate))
        
        completion(timeline)
    }
}

// MARK: - Streak Widget Entry
struct StreakWidgetEntry: TimelineEntry {
    let date: Date
    let streak: Int
}

// MARK: - Streak Widget View
struct StreakWidgetView: View {
    var entry: StreakWidgetEntry
    @Environment(\.widgetFamily) var family
    
    var body: some View {
        ZStack {
            // Background
            Color.white
            
            VStack(spacing: 0) {
                // Flame icon with streak number
                ZStack {
                    // Flame image - much larger
                    Image(systemName: "flame.fill")
                        .font(.system(size: 85, weight: .medium))
                        .foregroundStyle(
                            LinearGradient(
                                colors: [Color.orange, Color.yellow.opacity(0.9)],
                                startPoint: .top,
                                endPoint: .bottom
                            )
                        )
                    
                    // Streak number inside flame
                    Text("\(entry.streak)")
                        .font(.system(size: 32, weight: .bold, design: .rounded))
                        .foregroundColor(.white)
                        .shadow(color: .black.opacity(0.3), radius: 2, x: 0, y: 1)
                        .offset(y: 12)
                }
            }
        }
        .containerBackground(.white, for: .widget)
    }
}

// MARK: - Streak Widget Configuration
struct StreakWidget: Widget {
    let kind: String = "StreakWidget"
    
    var body: some WidgetConfiguration {
        StaticConfiguration(kind: kind, provider: StreakWidgetProvider()) { entry in
            StreakWidgetView(entry: entry)
        }
        .configurationDisplayName("Streak")
        .description("Denna widget hjälper dig att hålla koll på din streak.")
        .supportedFamilies([.systemSmall])
    }
}

// MARK: - Preview
#Preview(as: .systemSmall) {
    StreakWidget()
} timeline: {
    StreakWidgetEntry(date: .now, streak: 1)
    StreakWidgetEntry(date: .now, streak: 7)
    StreakWidgetEntry(date: .now, streak: 30)
}
