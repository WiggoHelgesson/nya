import SwiftUI

struct FindTrainerView: View {
    @EnvironmentObject var authViewModel: AuthViewModel
    @State private var trainers: [GolfTrainer] = []
    @State private var isLoading = true
    @State private var errorMessage: String?
    @State private var navigationPath = NavigationPath()
    
    private let columns = [
        GridItem(.flexible(), spacing: 12),
        GridItem(.flexible(), spacing: 12)
    ]
    
    var body: some View {
        NavigationStack(path: $navigationPath) {
            ZStack {
                Color(.systemBackground)
                    .ignoresSafeArea()
                
                if isLoading {
                    trainerSkeletonView
                } else if trainers.isEmpty {
                    emptyStateView
                } else {
                    ScrollView {
                        VStack(spacing: 0) {
                            // Hero section
                            VStack(spacing: 8) {
                                Text("Personliga tränare")
                                    .font(.system(size: 22, weight: .bold))
                                    .foregroundColor(.primary)
                                    .frame(maxWidth: .infinity, alignment: .leading)
                                
                                Text("Hitta en tränare som passar dig")
                                    .font(.system(size: 14))
                                    .foregroundColor(.secondary)
                                    .frame(maxWidth: .infinity, alignment: .leading)
                            }
                            .padding(.horizontal, 16)
                            .padding(.top, 16)
                            .padding(.bottom, 12)
                            
                            // 2-column trainer grid
                            LazyVGrid(columns: columns, spacing: 16) {
                                ForEach(trainers) { trainer in
                                    TrainerGridCard(trainer: trainer)
                                        .contentShape(Rectangle())
                                        .onTapGesture {
                                            navigationPath.append(trainer.id)
                                        }
                                }
                            }
                            .padding(.horizontal, 16)
                            
                            // "Become a trainer" promo – full width
                            BecomeTrainerPromoCard()
                                .padding(.horizontal, 16)
                                .padding(.top, 24)
                                .padding(.bottom, 100)
                        }
                    }
                }
            }
            .navigationBarHidden(true)
            .navigationDestination(for: UUID.self) { trainerId in
                if let trainer = trainers.first(where: { $0.id == trainerId }) {
                    TrainerProfileDetailView(trainer: trainer)
                        .environmentObject(authViewModel)
                }
            }
            .task {
                await loadTrainers()
            }
        }
    }
    
    // MARK: - Load Trainers
    
    private func loadTrainers() async {
        isLoading = true
        do {
            trainers = try await TrainerService.shared.fetchTrainers()
            let avatarUrls = trainers.compactMap { $0.avatarUrl }.filter { !$0.isEmpty }
            ImageCacheManager.shared.prefetch(urls: avatarUrls)
        } catch {
            print("Failed to load trainers: \(error)")
            errorMessage = error.localizedDescription
        }
        isLoading = false
    }
    
    // MARK: - Empty State
    
    private var emptyStateView: some View {
        VStack(spacing: 16) {
            Image(systemName: "person.2.slash")
                .font(.system(size: 50))
                .foregroundColor(.secondary)
            
            Text("Inga tränare tillgängliga")
                .font(.system(size: 18, weight: .semibold))
                .foregroundColor(.primary)
            
            Text("Det finns inga tränare registrerade just nu. Kom tillbaka snart!")
                .font(.system(size: 14))
                .foregroundColor(.secondary)
                .multilineTextAlignment(.center)
                .padding(.horizontal, 40)
        }
    }
    
    // MARK: - Skeleton Loading
    
    private var trainerSkeletonView: some View {
        ScrollView {
            VStack(spacing: 16) {
                RoundedRectangle(cornerRadius: 6)
                    .fill(Color(.systemGray5))
                    .frame(height: 24)
                    .frame(maxWidth: 260, alignment: .leading)
                    .padding(.horizontal, 16)
                    .padding(.top, 16)
                
                RoundedRectangle(cornerRadius: 4)
                    .fill(Color(.systemGray6))
                    .frame(height: 16)
                    .frame(maxWidth: 200, alignment: .leading)
                    .padding(.horizontal, 16)
                
                LazyVGrid(columns: [GridItem(.flexible(), spacing: 12), GridItem(.flexible(), spacing: 12)], spacing: 16) {
                    ForEach(0..<4, id: \.self) { _ in
                        VStack(alignment: .leading, spacing: 0) {
                            RoundedRectangle(cornerRadius: 12)
                                .fill(Color(.systemGray5))
                                .aspectRatio(0.85, contentMode: .fit)
                            
                            VStack(alignment: .leading, spacing: 6) {
                                RoundedRectangle(cornerRadius: 4)
                                    .fill(Color(.systemGray5))
                                    .frame(height: 14)
                                RoundedRectangle(cornerRadius: 4)
                                    .fill(Color(.systemGray6))
                                    .frame(width: 80, height: 12)
                            }
                            .padding(.top, 8)
                        }
                    }
                }
                .padding(.horizontal, 16)
            }
        }
        .shimmer()
    }
}

// MARK: - Trainer Grid Card (Blocket-style)

struct TrainerGridCard: View {
    let trainer: GolfTrainer
    @State private var currentImageIndex = 0
    
    private var cardImageWidth: CGFloat {
        (UIScreen.main.bounds.width - 44) / 2
    }
    
    var body: some View {
        let allImages = trainer.allGalleryImages
        
        VStack(alignment: .leading, spacing: 0) {
            // Image section
            ZStack {
                if !allImages.isEmpty {
                    TabView(selection: $currentImageIndex) {
                        ForEach(allImages.indices, id: \.self) { index in
                            OptimizedAsyncImage(
                                url: allImages[index],
                                width: cardImageWidth,
                                height: cardImageWidth * 1.2,
                                cornerRadius: 0
                            )
                            .tag(index)
                        }
                    }
                    .tabViewStyle(.page(indexDisplayMode: .never))
                } else {
                    ZStack {
                        Color(.systemGray5)
                        Image(systemName: "person.fill")
                            .font(.system(size: 40))
                            .foregroundColor(.gray)
                    }
                }
                
                // Price badge (bottom left)
                VStack {
                    Spacer()
                    HStack {
                        Text("\(trainer.hourlyRate) kr/h")
                            .font(.system(size: 13, weight: .bold))
                            .foregroundColor(.white)
                            .padding(.horizontal, 10)
                            .padding(.vertical, 5)
                            .background(Color.black.opacity(0.65))
                            .cornerRadius(14)
                        Spacer()
                    }
                    .padding(8)
                }
                
                // Navigation arrows (vertically centered) - only if multiple images
                if allImages.count > 1 {
                    VStack {
                        Spacer()
                        HStack {
                            Button {
                                withAnimation(.easeInOut(duration: 0.25)) {
                                    currentImageIndex = max(currentImageIndex - 1, 0)
                                }
                            } label: {
                                Image(systemName: "chevron.left")
                                    .font(.system(size: 11, weight: .bold))
                                    .foregroundColor(.white)
                                    .frame(width: 26, height: 26)
                                    .background(Color.black.opacity(0.4))
                                    .clipShape(Circle())
                            }
                            .opacity(currentImageIndex > 0 ? 1 : 0)
                            
                            Spacer()
                            
                            Button {
                                withAnimation(.easeInOut(duration: 0.25)) {
                                    currentImageIndex = min(currentImageIndex + 1, allImages.count - 1)
                                }
                            } label: {
                                Image(systemName: "chevron.right")
                                    .font(.system(size: 11, weight: .bold))
                                    .foregroundColor(.white)
                                    .frame(width: 26, height: 26)
                                    .background(Color.black.opacity(0.4))
                                    .clipShape(Circle())
                            }
                            .opacity(currentImageIndex < allImages.count - 1 ? 1 : 0)
                        }
                        .padding(.horizontal, 4)
                        Spacer()
                    }
                }
            }
            .aspectRatio(0.85, contentMode: .fit)
            .clipShape(RoundedRectangle(cornerRadius: 10))
            
            // Text info below image – matches Blocket exactly
            VStack(alignment: .leading, spacing: 2) {
                // Time ago + City row
                HStack(spacing: 0) {
                    if let date = trainer.createdAt {
                        Text(timeAgoString(from: date))
                            .font(.system(size: 12))
                            .foregroundColor(.secondary)
                    }
                    
                    Spacer(minLength: 4)
                    
                    if let city = trainer.city, !city.isEmpty {
                        Text(city)
                            .font(.system(size: 12))
                            .foregroundColor(.secondary)
                            .lineLimit(1)
                    }
                }
                .padding(.top, 6)
                
                // Name (bold, like product title)
                Text(trainer.name)
                    .font(.system(size: 15, weight: .bold))
                    .foregroundColor(.primary)
                    .lineLimit(2)
                    .multilineTextAlignment(.leading)
                    .padding(.top, 1)
                
                // Subtitle (like brand name on Blocket)
                if let years = trainer.experienceYears, years > 0 {
                    Text("\(years) års erfarenhet")
                        .font(.system(size: 13))
                        .foregroundColor(.secondary)
                        .lineLimit(1)
                }
            }
        }
    }
    
    private func timeAgoString(from date: Date) -> String {
        let interval = Date().timeIntervalSince(date)
        let minutes = Int(interval / 60)
        let hours = Int(interval / 3600)
        let days = Int(interval / 86400)
        
        if minutes < 1 { return "Just nu" }
        if minutes < 60 { return "\(minutes) min sedan" }
        if hours < 24 { return "\(hours) h sedan" }
        if days < 7 { return "\(days) d sedan" }
        if days < 30 { return "\(days / 7) v sedan" }
        return "\(days / 30) mån sedan"
    }
}

// MARK: - Become a Trainer Promo Card (full-width)

struct BecomeTrainerPromoCard: View {
    var body: some View {
        Button {
            if let url = URL(string: "https://upanddowncoach.com/") {
                UIApplication.shared.open(url)
            }
        } label: {
            VStack(spacing: 0) {
                // Image
                Image("81")
                    .resizable()
                    .aspectRatio(contentMode: .fill)
                    .frame(height: 200)
                    .frame(maxWidth: .infinity)
                    .clipped()
                
                // Text content
                VStack(alignment: .leading, spacing: 8) {
                    Text("Signa upp dig\nsom tränare")
                        .font(.system(size: 24, weight: .bold))
                        .foregroundColor(.black)
                        .multilineTextAlignment(.leading)
                        .frame(maxWidth: .infinity, alignment: .leading)
                    
                    Text("Dela dina kunskaper, tips & bli betald")
                        .font(.system(size: 15))
                        .foregroundColor(.black.opacity(0.7))
                        .frame(maxWidth: .infinity, alignment: .leading)
                    
                    // CTA button
                    HStack {
                        Spacer()
                        Text("Mer information")
                            .font(.system(size: 15, weight: .semibold))
                            .foregroundColor(.white)
                        Spacer()
                    }
                    .padding(.vertical, 14)
                    .background(Color.black)
                    .cornerRadius(28)
                    .padding(.top, 8)
                }
                .padding(20)
                .background(Color(red: 0.98, green: 0.93, blue: 0.87))
            }
            .cornerRadius(16)
            .shadow(color: .black.opacity(0.08), radius: 8, x: 0, y: 4)
        }
        .buttonStyle(.plain)
    }
}

#Preview {
    FindTrainerView()
        .environmentObject(AuthViewModel())
}
