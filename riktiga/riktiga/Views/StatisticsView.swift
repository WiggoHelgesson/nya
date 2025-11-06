import SwiftUI

struct StatisticsView: View {
    @Environment(\.dismiss) private var dismiss
    
    var body: some View {
        NavigationStack {
            List {
                Section {
                    NavigationLink(destination: Text("Månadsrapport kommer här")) {
                        StatisticsMenuRow(
                            icon: "doc.text.magnifyingglass",
                            title: "Månadsrapport",
                            subtitle: "Sammanfattning av dina pass denna månad"
                        )
                    }
                    NavigationLink(destination: Text("Progressive Overload kommer här")) {
                        StatisticsMenuRow(
                            icon: "chart.bar.xaxis",
                            title: "Progressive Overload",
                            subtitle: "Följ din styrkeutveckling över tid"
                        )
                    }
                    NavigationLink(destination: Text("Mest använda gymövningar kommer här")) {
                        StatisticsMenuRow(
                            icon: "dumbbell.fill",
                            title: "Mest använda gymövningar",
                            subtitle: "Se vilka övningar du gör mest"
                        )
                    }
                }
            }
            .listStyle(.insetGrouped)
            .navigationTitle("Statistik")
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button("Stäng") { dismiss() }
                    .foregroundColor(.black)
                }
            }
        }
    }
}

private struct StatisticsMenuRow: View {
    let icon: String
    let title: String
    let subtitle: String
    
    var body: some View {
        HStack(spacing: 16) {
            ZStack {
                Circle()
                    .fill(Color(.systemGray6))
                    .frame(width: 48, height: 48)
                Image(systemName: icon)
                    .font(.system(size: 20, weight: .semibold))
                    .foregroundColor(.black)
            }
            VStack(alignment: .leading, spacing: 4) {
            Text(title)
                    .font(.system(size: 16, weight: .semibold))
                    .foregroundColor(.black)
                Text(subtitle)
                    .font(.system(size: 12))
                    .foregroundColor(.gray)
            }
        }
        .padding(.vertical, 4)
    }
}

#Preview {
    StatisticsView()
}
