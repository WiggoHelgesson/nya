import SwiftUI
import MapKit
import CoreLocation

struct StartSessionView: View {
    @State private var showActivitySelection = true
    @State private var selectedActivityType: ActivityType?
    
    var body: some View {
        if showActivitySelection {
            SelectActivityView(isPresented: $showActivitySelection, selectedActivity: $selectedActivityType)
        } else if let activity = selectedActivityType {
            SessionMapView(activity: activity, isPresented: $showActivitySelection)
        }
    }
}

enum ActivityType: String, CaseIterable {
    case running = "Löppass"
    case golf = "Golfrunda"
    case walking = "Promenad"
    case hiking = "Bestiga berg"
    
    var icon: String {
        switch self {
        case .running:
            return "figure.run"
        case .golf:
            return "flag.fill"
        case .walking:
            return "figure.walk"
        case .hiking:
            return "mountain.2.fill"
        }
    }
}

struct SelectActivityView: View {
    @Binding var isPresented: Bool
    @Binding var selectedActivity: ActivityType?
    @Environment(\.dismiss) var dismiss
    
    let activities: [ActivityType] = [.running, .golf, .walking, .hiking]
    
    var body: some View {
        VStack(spacing: 0) {
            // MARK: - Header with Branding and Background
            VStack(spacing: 8) {
                Text("VÄLJ AKTIVITET")
                    .font(.system(size: 40, weight: .black))
                    .foregroundColor(.white)
                    .frame(maxWidth: .infinity, alignment: .leading)
                
                Text("Vilken aktivitet vill du göra idag?")
                    .font(.system(size: 16, weight: .semibold))
                    .foregroundColor(.white)
                    .frame(maxWidth: .infinity, alignment: .leading)
            }
            .frame(maxWidth: .infinity, alignment: .leading)
            .padding(24)
            .background(AppColors.brandBlue.opacity(0.8))
            .rotationEffect(.degrees(-2))
            .padding(.bottom, 12)
            
            Spacer()
            
            // MARK: - Activity Cards
            VStack(spacing: 16) {
                ForEach(activities, id: \.self) { activity in
                    Button(action: {
                        selectedActivity = activity
                        isPresented = false
                    }) {
                        HStack(spacing: 16) {
                            Image(systemName: activity.icon)
                                .font(.system(size: 32))
                                .foregroundColor(AppColors.brandBlue)
                                .frame(width: 60, height: 60)
                                .background(Color(.systemGray6))
                                .cornerRadius(12)
                            
                            VStack(alignment: .leading, spacing: 4) {
                                Text(activity.rawValue)
                                    .font(.system(size: 18, weight: .semibold))
                                    .foregroundColor(.black)
                                Text("Starta ett nytt pass")
                                    .font(.caption)
                                    .foregroundColor(.gray)
                            }
                            
                            Spacer()
                            
                            Image(systemName: "chevron.right")
                                .foregroundColor(.gray)
                        }
                        .padding(16)
                        .background(Color.white)
                        .cornerRadius(14)
                        .overlay(
                            RoundedRectangle(cornerRadius: 14)
                                .stroke(Color(.systemGray6), lineWidth: 1)
                        )
                    }
                }
            }
            .padding(16)
            
            Spacer()
            
            // MARK: - Cancel Button
            Button(action: {
                dismiss()
            }) {
                Text("AVBRYT")
                    .font(.system(size: 16, weight: .black))
                    .frame(maxWidth: .infinity)
                    .padding(14)
                    .background(Color(.systemGray5))
                    .foregroundColor(.black)
                    .cornerRadius(10)
            }
            .padding(16)
        }
        .background(AppColors.white)
    }
}

struct SessionMapView: View {
    let activity: ActivityType
    @Binding var isPresented: Bool
    
    var body: some View {
        Text("SessionMapView")
    }
}

#Preview {
    StartSessionView()
}
