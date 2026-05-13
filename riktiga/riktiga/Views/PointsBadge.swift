import SwiftUI

/// Compact badge that shows the new coin asset ("101") next to the user's
/// current XP. Used in the top navigation bars on Social/Rewards/Profile
/// and on top of the Profile → Aktiviteter tab. The size is configurable so
/// the same component can render at header scale in the nav bars and at a
/// larger scale as a prominent badge on the Activities tab.
struct PointsBadge: View {
    let points: Int
    var iconSize: CGFloat = 22
    var fontSize: CGFloat = 16

    var body: some View {
        HStack(spacing: 6) {
            Image("101")
                .resizable()
                .scaledToFit()
                .frame(width: iconSize, height: iconSize)
            Text("\(points)")
                .font(.system(size: fontSize, weight: .bold))
                .foregroundColor(.primary)
                .contentTransition(.numericText())
                .animation(.snappy, value: points)
        }
        .padding(.leading, 6)
        .padding(.trailing, 12)
        .padding(.vertical, 4)
        .background(
            Capsule()
                .fill(Color(.systemGray6))
        )
        .overlay(
            Capsule()
                .strokeBorder(
                    Color(red: 0.00, green: 0.55, blue: 0.65).opacity(0.55),
                    lineWidth: 1
                )
        )
    }
}

#Preview {
    VStack(spacing: 16) {
        PointsBadge(points: 1234)
        PointsBadge(points: 1234, iconSize: 28, fontSize: 20)
    }
    .padding()
}
