import SwiftUI

struct EventsSliderView: View {
    let events: [Event]
    let isOwnProfile: Bool
    var onCreateTapped: (() -> Void)? = nil
    var onEventTapped: ((Event) -> Void)? = nil
    
    var body: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: 16) {
                if isOwnProfile {
                    Button {
                        onCreateTapped?()
                    } label: {
                        VStack(spacing: 6) {
                            ZStack {
                                Circle()
                                    .fill(Color(.systemGray6))
                                    .frame(width: 64, height: 64)
                                
                                Circle()
                                    .strokeBorder(
                                        Color(.systemGray3).opacity(0.6),
                                        style: StrokeStyle(lineWidth: 1.5, dash: [5, 3])
                                    )
                                    .frame(width: 64, height: 64)
                                
                                Image(systemName: "plus")
                                    .font(.system(size: 22, weight: .medium))
                                    .foregroundColor(Color(.systemGray2))
                            }
                            
                            Text(L.t(sv: "Ny", nb: "Ny"))
                                .font(.system(size: 11, weight: .medium))
                                .foregroundColor(.secondary)
                                .lineLimit(1)
                                .frame(maxWidth: 74)
                        }
                    }
                }
                
                ForEach(events) { event in
                    Button {
                        onEventTapped?(event)
                    } label: {
                        EventCardView(event: event)
                    }
                }
            }
            .padding(.horizontal, 16)
        }
        .padding(.vertical, 12)
    }
}

// MARK: - Event Card (Circle)
struct EventCardView: View {
    let event: Event
    
    var body: some View {
        VStack(spacing: 6) {
            AsyncImage(url: URL(string: SupabaseConfig.rewriteURL(event.coverImageUrl))) { phase in
                switch phase {
                case .success(let image):
                    image
                        .resizable()
                        .scaledToFill()
                case .failure:
                    Color(.systemGray5)
                        .overlay {
                            Image(systemName: "photo")
                                .font(.system(size: 18))
                                .foregroundColor(Color(.systemGray3))
                        }
                default:
                    Color(.systemGray5)
                        .overlay { ProgressView().tint(.secondary) }
                }
            }
            .frame(width: 64, height: 64)
            .clipShape(Circle())
            .overlay(
                Circle()
                    .stroke(Color(.systemGray3).opacity(0.5), lineWidth: 1.5)
                    .frame(width: 72, height: 72)
            )
            .frame(width: 74, height: 74)
            
            Text(event.title)
                .font(.system(size: 11, weight: .medium))
                .foregroundColor(.primary)
                .lineLimit(1)
                .frame(maxWidth: 74)
        }
    }
}
