import SwiftUI

struct LotteryTicketCard: View {
    let myTickets: Int
    let totalTickets: Int
    let drawDate: String
    @Binding var isExpanded: Bool
    
    var percentage: Double {
        guard totalTickets > 0 else { return 0 }
        return (Double(myTickets) / Double(totalTickets)) * 100
    }
    
    var body: some View {
        VStack(spacing: isExpanded ? 10 : 0) {
            // Collapsed: Just ticket count
            Button {
                withAnimation(.spring(response: 0.3, dampingFraction: 0.8)) {
                    isExpanded.toggle()
                }
            } label: {
                HStack(spacing: 4) {
                    Text("\(myTickets)")
                        .font(.system(size: 28, weight: .black))
                        .foregroundColor(.white)
                    Text("lotter")
                        .font(.system(size: 12, weight: .bold))
                        .foregroundColor(.gray)
                        .padding(.top, 8)
                    
                    Image(systemName: isExpanded ? "chevron.up" : "chevron.down")
                        .font(.system(size: 10, weight: .bold))
                        .foregroundColor(.gray)
                        .padding(.top, 8)
                }
            }
            .buttonStyle(.plain)
            
            // Expanded content
            if isExpanded {
                // Progress bar with percentage
                VStack(spacing: 6) {
                    GeometryReader { geo in
                        ZStack(alignment: .leading) {
                            RoundedRectangle(cornerRadius: 4)
                                .fill(Color.white.opacity(0.15))
                            RoundedRectangle(cornerRadius: 4)
                                .fill(
                                    LinearGradient(
                                        colors: [.yellow, .orange],
                                        startPoint: .leading,
                                        endPoint: .trailing
                                    )
                                )
                                .frame(width: max(geo.size.width * min(CGFloat(percentage) / 100, 1), 4))
                        }
                    }
                    .frame(height: 10)
                    
                    // Percentage text
                    HStack(spacing: 4) {
                        Text("Du äger")
                            .foregroundColor(.gray)
                        Text(String(format: "%.1f%%", percentage))
                            .foregroundColor(.yellow)
                            .fontWeight(.bold)
                        Text("av alla")
                            .foregroundColor(.gray)
                    }
                    .font(.system(size: 10))
                    
                    // Total count
                    Text("\(myTickets) av \(formatNumber(totalTickets)) totalt")
                        .font(.system(size: 9))
                        .foregroundColor(.gray.opacity(0.6))
                }
                
                // Divider
                Rectangle()
                    .fill(Color.gray.opacity(0.2))
                    .frame(height: 1)
                
                // Footer info
                VStack(spacing: 6) {
                    // Draw date
                    HStack(spacing: 3) {
                        Text("📅")
                            .font(.system(size: 9))
                        Text("Dragning: \(drawDate)")
                            .font(.system(size: 9, weight: .medium))
                            .foregroundColor(.gray)
                    }
                    
                    // Info text
                    Text("Desto fler lotter du har desto större chans har du att vinna priserna")
                        .font(.system(size: 8, weight: .medium))
                        .foregroundColor(.yellow.opacity(0.8))
                        .multilineTextAlignment(.center)
                        .fixedSize(horizontal: false, vertical: true)
                }
            }
        }
        .padding(.horizontal, 12)
        .padding(.vertical, isExpanded ? 12 : 8)
        .background(
            RoundedRectangle(cornerRadius: 12, style: .continuous)
                .fill(Color.black.opacity(0.85))
        )
    }
    
    private func formatNumber(_ num: Int) -> String {
        let formatter = NumberFormatter()
        formatter.numberStyle = .decimal
        formatter.groupingSeparator = " "
        return formatter.string(from: NSNumber(value: num)) ?? "\(num)"
    }
}

// MARK: - Preview

struct LotteryTicketCardPreview: View {
    @State private var isExpanded1 = false
    @State private var isExpanded2 = true
    
    var body: some View {
        ZStack {
            Color.gray.opacity(0.3)
            VStack(spacing: 20) {
                LotteryTicketCard(
                    myTickets: 156,
                    totalTickets: 1258,
                    drawDate: "1 april",
                    isExpanded: $isExpanded1
                )
                .frame(width: 195)
                
                LotteryTicketCard(
                    myTickets: 42,
                    totalTickets: 500,
                    drawDate: "1 april",
                    isExpanded: $isExpanded2
                )
                .frame(width: 195)
            }
            .padding()
        }
    }
}

#Preview {
    LotteryTicketCardPreview()
}

