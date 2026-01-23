//
//  DetailedNutritionWidget.swift
//  UpDownLiveActivity
//
//  Widget som visar kalorier + protein/kolhydrater/fett med action-knappar
//

import WidgetKit
import SwiftUI
import AppIntents

// MARK: - Detailed Nutrition Widget Provider
struct DetailedNutritionWidgetProvider: TimelineProvider {
    func placeholder(in context: Context) -> DetailedNutritionWidgetEntry {
        DetailedNutritionWidgetEntry(
            date: Date(),
            caloriesLeft: 571,
            proteinLeft: 74,
            carbsLeft: 67,
            fatLeft: 1,
            progress: 0.7
        )
    }
    
    func getSnapshot(in context: Context, completion: @escaping (DetailedNutritionWidgetEntry) -> Void) {
        let entry = DetailedNutritionWidgetEntry(
            date: Date(),
            caloriesLeft: WidgetDataManager.getCaloriesLeft(),
            proteinLeft: WidgetDataManager.getProteinLeft(),
            carbsLeft: WidgetDataManager.getCarbsLeft(),
            fatLeft: WidgetDataManager.getFatLeft(),
            progress: WidgetDataManager.getCaloriesProgress()
        )
        completion(entry)
    }
    
    func getTimeline(in context: Context, completion: @escaping (Timeline<DetailedNutritionWidgetEntry>) -> Void) {
        let currentDate = Date()
        
        let entry = DetailedNutritionWidgetEntry(
            date: currentDate,
            caloriesLeft: WidgetDataManager.getCaloriesLeft(),
            proteinLeft: WidgetDataManager.getProteinLeft(),
            carbsLeft: WidgetDataManager.getCarbsLeft(),
            fatLeft: WidgetDataManager.getFatLeft(),
            progress: WidgetDataManager.getCaloriesProgress()
        )
        
        // Refresh every 30 minutes
        let nextUpdate = Calendar.current.date(byAdding: .minute, value: 30, to: currentDate) ?? currentDate
        let timeline = Timeline(entries: [entry], policy: .after(nextUpdate))
        
        completion(timeline)
    }
}

// MARK: - Detailed Nutrition Widget Entry
struct DetailedNutritionWidgetEntry: TimelineEntry {
    let date: Date
    let caloriesLeft: Int
    let proteinLeft: Int
    let carbsLeft: Int
    let fatLeft: Int
    let progress: Double
}

// MARK: - Detailed Nutrition Widget View
struct DetailedNutritionWidgetView: View {
    var entry: DetailedNutritionWidgetEntry
    @Environment(\.widgetFamily) var family
    
    var body: some View {
        ZStack {
            Color.white
            
            HStack(spacing: 12) {
                // Left side: Calories ring
                ZStack {
                    // Background ring
                    Circle()
                        .stroke(Color.gray.opacity(0.2), lineWidth: 6)
                        .frame(width: 70, height: 70)
                    
                    // Progress ring
                    Circle()
                        .trim(from: 0, to: entry.progress)
                        .stroke(Color.black, style: StrokeStyle(lineWidth: 6, lineCap: .round))
                        .frame(width: 70, height: 70)
                        .rotationEffect(.degrees(-90))
                    
                    // Calories text
                    VStack(spacing: 1) {
                        Text("\(entry.caloriesLeft)")
                            .font(.system(size: 18, weight: .bold, design: .rounded))
                            .foregroundColor(.primary)
                        
                        Text("Kalorier kvar")
                            .font(.system(size: 6, weight: .medium))
                            .foregroundColor(.secondary)
                    }
                }
                
                // Middle: Macros
                VStack(alignment: .leading, spacing: 6) {
                    // Protein
                    MacroRowView(
                        emoji: "🍗",
                        value: entry.proteinLeft,
                        unit: "g",
                        label: "Protein kvar"
                    )
                    
                    // Carbs
                    MacroRowView(
                        emoji: "🌾",
                        value: entry.carbsLeft,
                        unit: "g",
                        label: "Kolhydrater kvar"
                    )
                    
                    // Fat
                    MacroRowView(
                        emoji: "🥑",
                        value: entry.fatLeft,
                        unit: "g",
                        label: "Fett kvar"
                    )
                }
                
                // Right side: Action buttons
                VStack(spacing: 8) {
                    // Scan Food button
                    Link(destination: URL(string: "upanddown://scan-food")!) {
                        VStack(spacing: 4) {
                            Image(systemName: "camera.viewfinder")
                                .font(.system(size: 18, weight: .medium))
                            Text("Scanna mat")
                                .font(.system(size: 8, weight: .medium))
                        }
                        .foregroundColor(.primary)
                        .frame(width: 60, height: 50)
                        .background(Color.gray.opacity(0.1))
                        .cornerRadius(10)
                    }
                    
                    // Barcode button
                    Link(destination: URL(string: "upanddown://scan-barcode")!) {
                        VStack(spacing: 4) {
                            Image(systemName: "barcode.viewfinder")
                                .font(.system(size: 18, weight: .medium))
                            Text("Streckkod")
                                .font(.system(size: 8, weight: .medium))
                        }
                        .foregroundColor(.primary)
                        .frame(width: 60, height: 50)
                        .background(Color.gray.opacity(0.1))
                        .cornerRadius(10)
                    }
                }
            }
            .padding(12)
        }
        .containerBackground(.white, for: .widget)
    }
}

// MARK: - Macro Row View
struct MacroRowView: View {
    let emoji: String
    let value: Int
    let unit: String
    let label: String
    
    var body: some View {
        HStack(spacing: 6) {
            Text(emoji)
                .font(.system(size: 12))
            
            VStack(alignment: .leading, spacing: 0) {
                HStack(spacing: 2) {
                    Text("\(value)")
                        .font(.system(size: 14, weight: .bold, design: .rounded))
                        .foregroundColor(.black)
                    Text(unit)
                        .font(.system(size: 10, weight: .medium))
                        .foregroundColor(.secondary)
                }
                
                Text(label)
                    .font(.system(size: 7, weight: .medium))
                    .foregroundColor(.secondary)
            }
        }
    }
}

// MARK: - Detailed Nutrition Widget Configuration
struct DetailedNutritionWidget: Widget {
    let kind: String = "DetailedNutritionWidget"
    
    var body: some WidgetConfiguration {
        StaticConfiguration(kind: kind, provider: DetailedNutritionWidgetProvider()) { entry in
            DetailedNutritionWidgetView(entry: entry)
        }
        .configurationDisplayName("Detaljerad Info")
        .description("Denna widget visar dina dagliga protein/kolhydrater/fett och ger dig snabb åtkomst att logga mat.")
        .supportedFamilies([.systemMedium])
    }
}

// MARK: - Preview
#Preview(as: .systemMedium) {
    DetailedNutritionWidget()
} timeline: {
    DetailedNutritionWidgetEntry(
        date: .now,
        caloriesLeft: 571,
        proteinLeft: 74,
        carbsLeft: 67,
        fatLeft: 1,
        progress: 0.7
    )
}
