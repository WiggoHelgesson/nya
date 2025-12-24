import SwiftUI

// MARK: - Home Sub Tab
enum HomeSubTab: String, CaseIterable {
    case zonkriget = "Zonkriget"
    case lektioner = "Lektioner"
}

struct HomeContainerView: View {
    @State private var selectedSubTab: HomeSubTab = .zonkriget
    
    var body: some View {
        VStack(spacing: 0) {
            // Sub-tab selector
            HStack(spacing: 0) {
                ForEach(HomeSubTab.allCases, id: \.self) { tab in
                    Button {
                        withAnimation(.easeInOut(duration: 0.2)) {
                            selectedSubTab = tab
                        }
                    } label: {
                        VStack(spacing: 8) {
                            Text(tab.rawValue)
                                .font(.system(size: 16, weight: selectedSubTab == tab ? .bold : .medium))
                                .foregroundColor(selectedSubTab == tab ? .primary : .secondary)
                            
                            Rectangle()
                                .fill(selectedSubTab == tab ? Color.primary : Color.clear)
                                .frame(height: 2)
                        }
                        .frame(maxWidth: .infinity)
                        .contentShape(Rectangle())
                    }
                    .buttonStyle(.plain)
                }
            }
            .padding(.horizontal, 16)
            .padding(.top, 8)
            .padding(.bottom, 4)
            .background(Color(.systemBackground))
            
            // Content based on selected sub-tab
            if selectedSubTab == .zonkriget {
                ZoneWarView()
            } else {
                LessonsView()
            }
        }
        .onReceive(NotificationCenter.default.publisher(for: NSNotification.Name("NavigateToLektionerSubTab"))) { _ in
            withAnimation {
                selectedSubTab = .lektioner
            }
        }
        .onReceive(NotificationCenter.default.publisher(for: NSNotification.Name("NavigateToZonkrigetSubTab"))) { _ in
            withAnimation {
                selectedSubTab = .zonkriget
            }
        }
    }
}

#Preview {
    HomeContainerView()
}

