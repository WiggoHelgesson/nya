//
//  CaloriesWidget.swift
//  UpDownLiveActivity
//
//  Widget som visar kalorier kvar med cirkulär progress
//

import WidgetKit
import SwiftUI

// MARK: - Calories Widget Provider
struct CaloriesWidgetProvider: TimelineProvider {
    func placeholder(in context: Context) -> CaloriesWidgetEntry {
        CaloriesWidgetEntry(date: Date(), caloriesLeft: 571, progress: 0.7)
    }
    
    func getSnapshot(in context: Context, completion: @escaping (CaloriesWidgetEntry) -> Void) {
        let caloriesLeft = WidgetDataManager.getCaloriesLeft()
        let progress = WidgetDataManager.getCaloriesProgress()
        
        let entry = CaloriesWidgetEntry(
            date: Date(),
            caloriesLeft: caloriesLeft,
            progress: progress
        )
        completion(entry)
    }
    
    func getTimeline(in context: Context, completion: @escaping (Timeline<CaloriesWidgetEntry>) -> Void) {
        let currentDate = Date()
        let caloriesLeft = WidgetDataManager.getCaloriesLeft()
        let progress = WidgetDataManager.getCaloriesProgress()
        
        let entry = CaloriesWidgetEntry(
            date: currentDate,
            caloriesLeft: caloriesLeft,
            progress: progress
        )
        
        // Refresh every 30 minutes
        let nextUpdate = Calendar.current.date(byAdding: .minute, value: 30, to: currentDate) ?? currentDate
        let timeline = Timeline(entries: [entry], policy: .after(nextUpdate))
        
        completion(timeline)
    }
}

// MARK: - Calories Widget Entry
struct CaloriesWidgetEntry: TimelineEntry {
    let date: Date
    let caloriesLeft: Int
    let progress: Double
}

// MARK: - Calories Widget View
struct CaloriesWidgetView: View {
    var entry: CaloriesWidgetEntry
    @Environment(\.widgetFamily) var family
    
    var body: some View {
        ZStack {
            Color.white
            
            VStack(spacing: 12) {
                // Circular progress ring with calories
                ZStack {
                    // Background ring
                    Circle()
                        .stroke(Color.gray.opacity(0.2), lineWidth: 8)
                        .frame(width: 80, height: 80)
                    
                    // Progress ring
                    Circle()
                        .trim(from: 0, to: entry.progress)
                        .stroke(Color.black, style: StrokeStyle(lineWidth: 8, lineCap: .round))
                        .frame(width: 80, height: 80)
                        .rotationEffect(.degrees(-90))
                    
                    // Calories text
                    VStack(spacing: 2) {
                        Text("\(entry.caloriesLeft)")
                            .font(.system(size: 22, weight: .bold, design: .rounded))
                            .foregroundColor(.primary)
                        
                        Text("Kalorier kvar")
                            .font(.system(size: 8, weight: .medium))
                            .foregroundColor(.secondary)
                    }
                }
                
                // Log food button (visual only, opens app on tap)
                HStack(spacing: 6) {
                    Image(systemName: "plus")
                        .font(.system(size: 12, weight: .semibold))
                    Text("Logga mat")
                        .font(.system(size: 12, weight: .semibold))
                }
                .foregroundColor(.white)
                .padding(.horizontal, 14)
                .padding(.vertical, 8)
                .background(Color.black)
                .cornerRadius(16)
            }
            .padding(12)
        }
        .containerBackground(.white, for: .widget)
    }
}

// MARK: - Calories Widget Configuration
struct CaloriesWidget: Widget {
    let kind: String = "CaloriesWidget"
    
    var body: some WidgetConfiguration {
        StaticConfiguration(kind: kind, provider: CaloriesWidgetProvider()) { entry in
            CaloriesWidgetView(entry: entry)
        }
        .configurationDisplayName("Generell Info")
        .description("Denna widget visar dina dagliga kalorier och ger dig snabb åtkomst att logga mat.")
        .supportedFamilies([.systemSmall])
    }
}

// MARK: - Preview
#Preview(as: .systemSmall) {
    CaloriesWidget()
} timeline: {
    CaloriesWidgetEntry(date: .now, caloriesLeft: 571, progress: 0.7)
    CaloriesWidgetEntry(date: .now, caloriesLeft: 1200, progress: 0.4)
}
