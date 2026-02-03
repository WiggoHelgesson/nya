import SwiftUI

// MARK: - Cheer Emoji Picker View
struct CheerEmojiPickerView: View {
    let friend: ActiveFriendSession
    let senderName: String
    let senderId: String
    @Binding var isSending: Bool
    let onSend: (String) -> Void
    let onDismiss: () -> Void
    
    @State private var selectedEmoji: String?
    
    // Available cheer emojis
    private let emojis = ["💪", "🔥", "⚡️", "🏆", "👊", "🎯", "💯", "🚀"]
    
    var body: some View {
        VStack(spacing: 20) {
            // Header
            HStack {
                Button {
                    onDismiss()
                } label: {
                    Image(systemName: "xmark")
                        .font(.system(size: 16, weight: .medium))
                        .foregroundColor(.gray)
                        .frame(width: 32, height: 32)
                        .background(Color.gray.opacity(0.1))
                        .clipShape(Circle())
                }
                
                Spacer()
                
                VStack(spacing: 2) {
                    Text("Heja på")
                        .font(.system(size: 14))
                        .foregroundColor(.gray)
                    Text(friend.userName.components(separatedBy: " ").first ?? friend.userName)
                        .font(.system(size: 18, weight: .bold))
                }
                
                Spacer()
                
                // Invisible spacer for balance
                Color.clear
                    .frame(width: 32, height: 32)
            }
            .padding(.horizontal, 20)
            .padding(.top, 16)
            
            // Emoji grid
            LazyVGrid(columns: Array(repeating: GridItem(.flexible()), count: 4), spacing: 16) {
                ForEach(emojis, id: \.self) { emoji in
                    Button {
                        selectedEmoji = emoji
                        UIImpactFeedbackGenerator(style: .light).impactOccurred()
                    } label: {
                        Text(emoji)
                            .font(.system(size: 40))
                            .frame(width: 60, height: 60)
                            .background(
                                Circle()
                                    .fill(selectedEmoji == emoji ? Color.green.opacity(0.2) : Color.gray.opacity(0.1))
                            )
                            .overlay(
                                Circle()
                                    .stroke(selectedEmoji == emoji ? Color.green : Color.clear, lineWidth: 2)
                            )
                    }
                    .scaleEffect(selectedEmoji == emoji ? 1.1 : 1.0)
                    .animation(.spring(response: 0.3, dampingFraction: 0.7), value: selectedEmoji)
                }
            }
            .padding(.horizontal, 20)
            
            // Send button
            Button {
                if let emoji = selectedEmoji {
                    onSend(emoji)
                }
            } label: {
                HStack(spacing: 8) {
                    if isSending {
                        ProgressView()
                            .progressViewStyle(CircularProgressViewStyle(tint: .white))
                            .scaleEffect(0.8)
                    } else {
                        Text("Skicka")
                            .font(.system(size: 17, weight: .semibold))
                        if let emoji = selectedEmoji {
                            Text(emoji)
                                .font(.system(size: 20))
                        }
                    }
                }
                .foregroundColor(.white)
                .frame(maxWidth: .infinity)
                .padding(.vertical, 16)
                .background(selectedEmoji != nil ? Color.black : Color.gray.opacity(0.3))
                .cornerRadius(14)
            }
            .disabled(selectedEmoji == nil || isSending)
            .padding(.horizontal, 20)
            .padding(.bottom, 20)
        }
        .background(Color(.systemBackground))
    }
}

// MARK: - Cheer Received Animation View
struct CheerReceivedAnimationView: View {
    let cheer: ReceivedCheer
    @Binding var isShowing: Bool
    
    @State private var scale: CGFloat = 0.5
    @State private var opacity: Double = 0
    @State private var emojiScale: CGFloat = 0.5
    @State private var emojiRotation: Double = -20
    
    var body: some View {
        ZStack {
            // Semi-transparent background
            Color.black.opacity(0.4)
                .ignoresSafeArea()
                .onTapGesture {
                    dismissAnimation()
                }
            
            // Cheer card
            VStack(spacing: 16) {
                // Large emoji with animation
                Text(cheer.emoji)
                    .font(.system(size: 80))
                    .scaleEffect(emojiScale)
                    .rotationEffect(.degrees(emojiRotation))
                
                // Message
                VStack(spacing: 4) {
                    Text("\(cheer.fromUserName) skickade")
                        .font(.system(size: 18, weight: .medium))
                        .foregroundColor(.black)
                    
                    Text(cheer.emoji)
                        .font(.system(size: 24))
                }
                
                // Motivational message
                Text("Du är grym, fortsätt kämpa!")
                    .font(.system(size: 16))
                    .foregroundColor(.gray)
                    .padding(.top, 4)
                
                // Dismiss button
                Button {
                    dismissAnimation()
                } label: {
                    Text("Tack!")
                        .font(.system(size: 17, weight: .semibold))
                        .foregroundColor(.white)
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 14)
                        .background(Color.black)
                        .cornerRadius(12)
                }
                .padding(.top, 8)
            }
            .padding(24)
            .background(Color.white)
            .cornerRadius(24)
            .shadow(color: .black.opacity(0.15), radius: 20, x: 0, y: 10)
            .padding(.horizontal, 40)
            .scaleEffect(scale)
            .opacity(opacity)
        }
        .onAppear {
            withAnimation(.spring(response: 0.5, dampingFraction: 0.7)) {
                scale = 1.0
                opacity = 1.0
            }
            
            withAnimation(.spring(response: 0.6, dampingFraction: 0.5).delay(0.2)) {
                emojiScale = 1.2
                emojiRotation = 10
            }
            
            withAnimation(.spring(response: 0.3, dampingFraction: 0.6).delay(0.5)) {
                emojiScale = 1.0
                emojiRotation = 0
            }
            
            // Auto-dismiss after 4 seconds
            DispatchQueue.main.asyncAfter(deadline: .now() + 4) {
                if isShowing {
                    dismissAnimation()
                }
            }
        }
    }
    
    private func dismissAnimation() {
        withAnimation(.easeOut(duration: 0.2)) {
            scale = 0.8
            opacity = 0
        }
        
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.2) {
            isShowing = false
        }
    }
}

#Preview {
    CheerEmojiPickerView(
        friend: ActiveFriendSession(
            id: "1",
            oderId: "1",
            userName: "Oscar",
            avatarUrl: nil,
            activityType: "gym",
            startedAt: Date().addingTimeInterval(-3600),
            latitude: nil,
            longitude: nil
        ),
        senderName: "Wiggo",
        senderId: "123",
        isSending: .constant(false),
        onSend: { _ in },
        onDismiss: {}
    )
}
