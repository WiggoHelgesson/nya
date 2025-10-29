import SwiftUI

struct HomeHeaderView: View {
    @State private var showNotifications = false
    @State private var unreadNotifications = 0 // TODO: Connect to real notifications
    
    var body: some View {
        HStack(spacing: 16) {
            // Notifications Button on the left
            Button(action: {
                showNotifications = true
            }) {
                ZStack(alignment: .topTrailing) {
                    Image(systemName: "bell.fill")
                        .font(.system(size: 20, weight: .semibold))
                        .foregroundColor(.black)
                    
                    // Notification badge
                    if unreadNotifications > 0 {
                        Circle()
                            .fill(Color.red)
                            .frame(width: 20, height: 20)
                            .overlay(
                                Text("\(unreadNotifications)")
                                    .font(.system(size: 10, weight: .bold))
                                    .foregroundColor(.white)
                            )
                            .offset(x: 8, y: -8)
                    }
                }
            }
            
            Spacer()
            
            // Add Friends Button (Search) on the right
            NavigationLink(destination: FindFriendsView()) {
                Image(systemName: "magnifyingglass")
                    .font(.system(size: 20, weight: .semibold))
                    .foregroundColor(.black)
            }
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 12)
        .background(Color(.systemGray6))
        .cornerRadius(12)
        .padding(.horizontal, 16)
        .padding(.top, 12)
        .sheet(isPresented: $showNotifications) {
            NotificationsView()
        }
    }
}

#Preview {
    HomeHeaderView()
}
