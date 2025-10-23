import SwiftUI

struct ActivitiesView: View {
    @State private var selectedFilter = "Denna vecka"
    let filters = ["Denna vecka", "Denna månad", "Alla"]
    
    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: 20) {
                    // Filter
                    Picker("Filter", selection: $selectedFilter) {
                        ForEach(filters, id: \.self) { filter in
                            Text(filter).tag(filter)
                        }
                    }
                    .pickerStyle(.segmented)
                    .padding(.horizontal)
                    
                    // Statistik
                    VStack(spacing: 12) {
                        StatCard(icon: "flame", title: "Totalt brända", value: "2,450 kcal")
                        StatCard(icon: "clock", title: "Total tid", value: "3h 45min")
                        StatCard(icon: "figure.walk", title: "Genomsnittlig aktivitet", value: "45 min")
                    }
                    .padding(.horizontal)
                    
                    // Aktivitetslista
                    VStack(alignment: .leading, spacing: 12) {
                        Text("Dina aktiviteter")
                            .font(.headline)
                            .padding(.horizontal)
                        
                        VStack(spacing: 10) {
                            ActivityListItem(
                                icon: "figure.walk",
                                title: "Promenad",
                                date: "Idag 14:30",
                                duration: "30 min",
                                calories: 150
                            )
                            
                            ActivityListItem(
                                icon: "figure.stairs",
                                title: "Löpning",
                                date: "Igår 07:00",
                                duration: "45 min",
                                calories: 380
                            )
                            
                            ActivityListItem(
                                icon: "dumbbell.fill",
                                title: "Styrketräning",
                                date: "2 dagar sedan 18:00",
                                duration: "60 min",
                                calories: 450
                            )
                            
                            ActivityListItem(
                                icon: "bicycle",
                                title: "Cykling",
                                date: "3 dagar sedan 10:00",
                                duration: "90 min",
                                calories: 650
                            )
                            
                            ActivityListItem(
                                icon: "figure.yoga",
                                title: "Yoga",
                                date: "4 dagar sedan 19:00",
                                duration: "30 min",
                                calories: 120
                            )
                        }
                        .padding(.horizontal)
                    }
                    
                    Spacer(minLength: 50)
                }
                .padding(.vertical)
            }
            .navigationTitle("Aktiviteter")
        }
    }
}

struct StatCard: View {
    let icon: String
    let title: String
    let value: String
    
    var body: some View {
        HStack(spacing: 16) {
            Image(systemName: icon)
                .font(.title2)
                .foregroundColor(.white)
                .frame(width: 50, height: 50)
                .background(
                    LinearGradient(
                        gradient: Gradient(colors: [
                            Color(red: 0.1, green: 0.6, blue: 0.8),
                            Color(red: 0.2, green: 0.4, blue: 0.9)
                        ]),
                        startPoint: .topLeading,
                        endPoint: .bottomTrailing
                    )
                )
                .cornerRadius(10)
            
            VStack(alignment: .leading, spacing: 4) {
                Text(title)
                    .font(.caption)
                    .foregroundColor(.gray)
                Text(value)
                    .font(.headline)
                    .fontWeight(.bold)
            }
            
            Spacer()
        }
        .padding(12)
        .background(Color(.systemGray6))
        .cornerRadius(10)
    }
}

struct ActivityListItem: View {
    let icon: String
    let title: String
    let date: String
    let duration: String
    let calories: Int
    
    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack(spacing: 12) {
                Image(systemName: icon)
                    .font(.title3)
                    .foregroundColor(.white)
                    .frame(width: 35, height: 35)
                    .background(
                        LinearGradient(
                            gradient: Gradient(colors: [
                                Color(red: 0.1, green: 0.6, blue: 0.8),
                                Color(red: 0.2, green: 0.4, blue: 0.9)
                            ]),
                            startPoint: .topLeading,
                            endPoint: .bottomTrailing
                        )
                    )
                    .cornerRadius(8)
                
                VStack(alignment: .leading, spacing: 4) {
                    Text(title)
                        .font(.headline)
                    Text(date)
                        .font(.caption)
                        .foregroundColor(.gray)
                }
                
                Spacer()
                
                VStack(alignment: .trailing, spacing: 4) {
                    Text("\(calories) kcal")
                        .font(.headline)
                    Text(duration)
                        .font(.caption)
                        .foregroundColor(.gray)
                }
            }
        }
        .padding(12)
        .background(Color(.systemGray6))
        .cornerRadius(10)
    }
}

#Preview {
    ActivitiesView()
}
