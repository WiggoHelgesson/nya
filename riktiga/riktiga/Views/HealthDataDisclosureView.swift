import SwiftUI

struct HealthDataDisclosureView: View {
    enum Style {
        case card
        case inline
    }
    
    let title: String
    let description: String
    var style: Style = .card
    var showsManageButton: Bool = false
    var manageAction: (() -> Void)? = nil
    
    var body: some View {
        Group {
            if style == .card {
                content
                    .padding(18)
                    .background(Color.white)
                    .cornerRadius(14)
                    .shadow(color: Color.black.opacity(0.05), radius: 6, x: 0, y: 2)
            } else {
                content
            }
        }
        .accessibilityElement(children: .combine)
    }
    
    @ViewBuilder
    private var content: some View {
        VStack(alignment: .leading, spacing: 14) {
            HStack(alignment: .top, spacing: 14) {
                Image("24")
                    .resizable()
                    .scaledToFit()
                    .frame(width: 34, height: 34)
                    .cornerRadius(6)
                    .accessibilityHidden(true)
                VStack(alignment: .leading, spacing: 6) {
                    Text(title)
                        .font(.system(size: 15, weight: .semibold))
                        .foregroundColor(.black)
                    Text(description)
                        .font(.system(size: 13))
                        .foregroundColor(.gray)
                        .fixedSize(horizontal: false, vertical: true)
                }
            }
            
            if showsManageButton, let manageAction {
                Button(action: manageAction) {
                    HStack(spacing: 6) {
                        Text("Hantera Apple Health-behörighet")
                            .font(.system(size: 13, weight: .semibold))
                        Image(systemName: "chevron.right")
                            .font(.system(size: 12, weight: .bold))
                    }
                    .foregroundColor(.black)
                    .padding(.vertical, 10)
                    .padding(.horizontal, 14)
                    .background(Color(.systemGray5))
                    .cornerRadius(10)
                }
                .accessibilityLabel("Hantera Apple Health-behörighet")
            }
        }
    }
}

#Preview {
    VStack(spacing: 20) {
        HealthDataDisclosureView(
            title: "Data från Apple Health",
            description: "Up&Down läser steg, distans och kalorier från Apple Health för att visa din statistik." ,
            showsManageButton: true,
            manageAction: {}
        )
        .padding()
    }
    .background(Color(.systemGray6))
}

