import SwiftUI

struct TrophyCaseView: View, Equatable {
    let activityCount: Int
    @State private var showAllTrophies = false
    
    static func == (lhs: TrophyCaseView, rhs: TrophyCaseView) -> Bool {
        return lhs.activityCount == rhs.activityCount
    }
    
    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            HStack {
                Text("Pokaler")
                    .font(.system(size: 18, weight: .bold))
                    .foregroundColor(.black)
                
                Spacer()
                
                Text("\(unlockedTrophiesCount)")
                    .font(.system(size: 16, weight: .semibold))
                    .foregroundColor(.gray)
            }
            
            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: 20) {
                    ForEach(trophies.prefix(4), id: \.milestone) { trophy in
                        TrophyBadge(trophy: trophy, isUnlocked: activityCount >= trophy.milestone)
                    }
                }
            }
            
            Button(action: {
                showAllTrophies = true
            }) {
                HStack {
                    Text("Alla pokaler")
                        .font(.system(size: 16, weight: .medium))
                        .foregroundColor(.black)
                    Spacer()
                    Image(systemName: "chevron.right")
                        .foregroundColor(.gray)
                }
                .padding(.top, 8)
            }
        }
        .padding(16)
        .background(Color.white)
        .cornerRadius(12)
        .sheet(isPresented: $showAllTrophies) {
            AllTrophiesView(activityCount: activityCount)
        }
    }
    
    private var trophies: [Trophy] {
        [
            Trophy(milestone: 25, title: "25:e aktivitet"),
            Trophy(milestone: 50, title: "50:e aktivitet"),
            Trophy(milestone: 75, title: "75:e aktivitet"),
            Trophy(milestone: 100, title: "100:e aktivitet"),
            Trophy(milestone: 150, title: "150:e aktivitet"),
            Trophy(milestone: 200, title: "200:e aktivitet")
        ]
    }
    
    private var unlockedTrophiesCount: Int {
        trophies.filter { activityCount >= $0.milestone }.count
    }
}

struct Trophy {
    let milestone: Int
    let title: String
}

struct TrophyBadge: View {
    let trophy: Trophy
    let isUnlocked: Bool
    
    var body: some View {
        VStack(spacing: 12) {
            ZStack {
                // Hexagon background
                HexagonShape()
                    .fill(
                        LinearGradient(
                            gradient: Gradient(colors: isUnlocked ? [Color(red: 0.2, green: 0.3, blue: 0.35), Color(red: 0.15, green: 0.25, blue: 0.3)] : [Color.gray.opacity(0.3), Color.gray.opacity(0.2)]),
                            startPoint: .top,
                            endPoint: .bottom
                        )
                    )
                    .frame(width: 90, height: 90)
                    .overlay(
                        HexagonShape()
                            .stroke(isUnlocked ? Color.orange : Color.gray.opacity(0.5), lineWidth: 4)
                    )
                
                // Trophy icon at top
                Image(systemName: "bolt.fill")
                    .font(.system(size: 14, weight: .bold))
                    .foregroundColor(isUnlocked ? .orange : .gray)
                    .offset(y: -28)
                
                // Number
                Text("\(trophy.milestone)")
                    .font(.system(size: 32, weight: .bold))
                    .foregroundColor(isUnlocked ? .white : .gray.opacity(0.5))
            }
            
            Text(trophy.title)
                .font(.system(size: 13, weight: .medium))
                .foregroundColor(.black)
                .multilineTextAlignment(.center)
                .frame(width: 90)
        }
    }
}

struct HexagonShape: Shape {
    func path(in rect: CGRect) -> Path {
        var path = Path()
        let width = rect.width
        let height = rect.height
        let centerX = width / 2
        let centerY = height / 2
        let radius = min(width, height) / 2
        
        for i in 0..<6 {
            let angle = CGFloat(i) * .pi / 3 - .pi / 2
            let x = centerX + radius * cos(angle)
            let y = centerY + radius * sin(angle)
            
            if i == 0 {
                path.move(to: CGPoint(x: x, y: y))
            } else {
                path.addLine(to: CGPoint(x: x, y: y))
            }
        }
        path.closeSubpath()
        
        return path
    }
}

struct AllTrophiesView: View {
    let activityCount: Int
    @Environment(\.dismiss) var dismiss
    
    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(spacing: 20) {
                    ForEach(allTrophies, id: \.milestone) { trophy in
                        HStack(spacing: 16) {
                            TrophyBadge(trophy: trophy, isUnlocked: activityCount >= trophy.milestone)
                            
                            VStack(alignment: .leading, spacing: 4) {
                                Text(trophy.title)
                                    .font(.system(size: 16, weight: .semibold))
                                    .foregroundColor(.black)
                                
                                if activityCount >= trophy.milestone {
                                    Text("Upplåst!")
                                        .font(.system(size: 14))
                                        .foregroundColor(.green)
                                } else {
                                    Text("\(trophy.milestone - activityCount) aktiviteter kvar")
                                        .font(.system(size: 14))
                                        .foregroundColor(.gray)
                                }
                            }
                            
                            Spacer()
                        }
                        .padding(16)
                        .background(Color(.systemGray6))
                        .cornerRadius(12)
                    }
                }
                .padding(16)
            }
            .navigationTitle("Alla pokaler")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button("Klar") {
                        dismiss()
                    }
                }
            }
        }
    }
    
    private var allTrophies: [Trophy] {
        [
            Trophy(milestone: 25, title: "25:e aktivitet"),
            Trophy(milestone: 50, title: "50:e aktivitet"),
            Trophy(milestone: 75, title: "75:e aktivitet"),
            Trophy(milestone: 100, title: "100:e aktivitet"),
            Trophy(milestone: 150, title: "150:e aktivitet"),
            Trophy(milestone: 200, title: "200:e aktivitet")
        ]
    }
}

#Preview {
    TrophyCaseView(activityCount: 127)
        .padding()
}

