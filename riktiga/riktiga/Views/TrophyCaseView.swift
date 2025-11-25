import SwiftUI

private let trophyCatalog: [Trophy] = [
    Trophy(id: "bench-60kg", title: "Bänkpress 60 kg", requirement: .benchPress(60)),
    Trophy(id: "bench-100kg", title: "Bänkpress 100 kg", requirement: .benchPress(100)),
    Trophy(id: "bench-140kg", title: "Bänkpress 140 kg", requirement: .benchPress(140))
]

struct PersonalBestInfo: Equatable {
    let fiveKmMinutes: Int?
    let tenKmMinutes: Int?
    let benchMaxKg: Double?
    
    init(fiveKmMinutes: Int? = nil, tenKmMinutes: Int? = nil, benchMaxKg: Double? = nil) {
        self.fiveKmMinutes = fiveKmMinutes
        self.tenKmMinutes = tenKmMinutes
        self.benchMaxKg = benchMaxKg
    }
    
    var formattedFiveKm: String? {
        guard let minutes = fiveKmMinutes else { return nil }
        return "\(minutes) min"
    }
    
    var formattedTenKm: String? {
        guard let minutes = tenKmMinutes else { return nil }
        return formatMinutes(minutes)
    }
    
    var formattedBench: String? {
        guard let kg = benchMaxKg else { return nil }
        return "\(String(format: "%.1f", kg)) kg"
    }
}

enum TrophyRequirement: Equatable {
    case activities(Int)
    case fiveKmUnder(Int)
    case tenKmUnder(Int)
    case benchPress(Double)
}

struct Trophy: Equatable {
    let id: String
    let title: String
    let requirement: TrophyRequirement
    
    var badgeText: String {
        switch requirement {
        case .activities(let count):
            return "\(count)"
        case .fiveKmUnder:
            return "5K"
        case .tenKmUnder:
            return "10K"
        case .benchPress(let kg):
            return "\(Int(kg))"
        }
    }
}

struct TrophyCaseView: View, Equatable {
    let activityCount: Int
    let personalBests: PersonalBestInfo
    @State private var showAllTrophies = false
    
    static func == (lhs: TrophyCaseView, rhs: TrophyCaseView) -> Bool {
        lhs.activityCount == rhs.activityCount && lhs.personalBests == rhs.personalBests
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
                    ForEach(trophyCatalog.prefix(4), id: \.id) { trophy in
                        TrophyBadge(
                            trophy: trophy,
                            isUnlocked: isUnlocked(trophy, activityCount: activityCount, personalBests: personalBests)
                        )
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
            AllTrophiesView(activityCount: activityCount, personalBests: personalBests)
        }
    }
    
    private var unlockedTrophiesCount: Int {
        trophyCatalog.filter { isUnlocked($0, activityCount: activityCount, personalBests: personalBests) }.count
    }
}

struct TrophyBadge: View {
    let trophy: Trophy
    let isUnlocked: Bool
    
    var body: some View {
        VStack(spacing: 12) {
            ZStack {
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
                
                Image(systemName: "bolt.fill")
                    .font(.system(size: 14, weight: .bold))
                    .foregroundColor(isUnlocked ? .orange : .gray)
                    .offset(y: -28)
                
                Text(trophy.badgeText)
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
    let personalBests: PersonalBestInfo
    @Environment(\.dismiss) var dismiss
    
    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(spacing: 20) {
                    ForEach(trophyCatalog, id: \.id) { trophy in
                        let unlocked = isUnlocked(trophy, activityCount: activityCount, personalBests: personalBests)
                        HStack(spacing: 16) {
                            TrophyBadge(trophy: trophy, isUnlocked: unlocked)
                            
                            VStack(alignment: .leading, spacing: 4) {
                                Text(trophy.title)
                                    .font(.system(size: 16, weight: .semibold))
                                    .foregroundColor(.black)
                                Text(detailText(for: trophy, activityCount: activityCount, personalBests: personalBests))
                                    .font(.system(size: 14))
                                    .foregroundColor(unlocked ? .green : .gray)
                                    .fixedSize(horizontal: false, vertical: true)
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
}

private func isUnlocked(_ trophy: Trophy, activityCount: Int, personalBests: PersonalBestInfo) -> Bool {
    switch trophy.requirement {
    case .activities(let count):
        return activityCount >= count
    case .fiveKmUnder(let target):
        guard let pb = personalBests.fiveKmMinutes else { return false }
        return pb < target
    case .tenKmUnder(let target):
        guard let pb = personalBests.tenKmMinutes else { return false }
        return pb < target
    case .benchPress(let target):
        guard let pb = personalBests.benchMaxKg else { return false }
        return pb >= target
    }
}

private func detailText(for trophy: Trophy, activityCount: Int, personalBests: PersonalBestInfo) -> String {
    let unlocked = isUnlocked(trophy, activityCount: activityCount, personalBests: personalBests)
    switch trophy.requirement {
    case .activities(let count):
        if unlocked {
            return "Upplåst!"
        }
        let remaining = max(count - activityCount, 0)
        return "\(remaining) aktiviteter kvar"
    case .fiveKmUnder(let target):
        let current = personalBests.formattedFiveKm
        if unlocked {
            if let current {
                return "Upplåst! Bästa tid: \(current)"
            }
            return "Upplåst!"
        }
        if let current {
            return "Spring 5 km under \(target) min (nu: \(current))"
        }
        return "Spring 5 km under \(target) min"
    case .tenKmUnder(let target):
        let current = personalBests.formattedTenKm
        if unlocked {
            if let current {
                return "Upplåst! Bästa tid: \(current)"
            }
            return "Upplåst!"
        }
        if let current {
            return "Spring 10 km under \(target) min (nu: \(current))"
        }
        return "Spring 10 km under \(target) min"
    case .benchPress(let target):
        let current = personalBests.formattedBench
        if unlocked {
            if let current {
                return "Upplåst! Bästa lyft: \(current)"
            }
            return "Upplåst!"
        }
        if let current {
            return "Bänkpress \(Int(target)) kg eller mer (nu: \(current))"
        }
        return "Bänkpress \(Int(target)) kg eller mer"
    }
}

private func formatMinutes(_ totalMinutes: Int) -> String {
    let hours = totalMinutes / 60
    let minutes = totalMinutes % 60
    if hours > 0 {
        return "\(hours) h \(minutes) min"
    }
    return "\(minutes) min"
}

#Preview {
    TrophyCaseView(
        activityCount: 127,
        personalBests: PersonalBestInfo(fiveKmMinutes: 18, tenKmMinutes: 42)
    )
    .padding()
}

