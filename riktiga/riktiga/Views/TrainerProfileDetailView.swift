import SwiftUI

struct TrainerProfileDetailView: View {
    let trainer: GolfTrainer
    @EnvironmentObject var authViewModel: AuthViewModel
    @Environment(\.dismiss) var dismiss
    @Environment(\.colorScheme) var colorScheme
    @State private var showChat = false
    @State private var currentImageIndex = 0
    
    var body: some View {
        ZStack(alignment: .bottom) {
            ScrollView {
                VStack(spacing: 0) {
                    // MARK: - Hero Image
                    heroImageSection
                    
                    // MARK: - Name and Rating
                    nameAndRatingSection
                    
                    // MARK: - Stats Row
                    statsRow
                    
                    // MARK: - Description
                    descriptionSection
                    
                    // MARK: - Prices
                    pricesSection
                    
                    // MARK: - Social Media
                    socialMediaSection
                    
                    // Bottom padding for CTA button
                    Spacer()
                        .frame(height: 120)
                }
            }
            
            // MARK: - Fixed Contact Button
            contactButton
        }
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            ToolbarItem(placement: .navigationBarLeading) {
                Button {
                    dismiss()
                } label: {
                    Image(systemName: "chevron.left")
                        .font(.system(size: 16, weight: .semibold))
                        .foregroundColor(.white)
                        .frame(width: 36, height: 36)
                        .background(Color.black.opacity(0.5))
                        .clipShape(Circle())
                }
            }
        }
        .navigationBarBackButtonHidden(true)
        .ignoresSafeArea(edges: .top)
        .onAppear { NavigationDepthTracker.shared.setAtRoot(false) }
        .onDisappear { NavigationDepthTracker.shared.setAtRoot(true) }
        .fullScreenCover(isPresented: $showChat) {
            TrainerChatView(trainer: trainer)
        }
    }
    
    // MARK: - Hero Image Section
    
    private var heroImageSection: some View {
        let allImages = trainer.allGalleryImages
        
        return ZStack(alignment: .bottom) {
            if !allImages.isEmpty {
                ZStack(alignment: .topTrailing) {
                    // Multiple images: use swipeable TabView
                    TabView(selection: $currentImageIndex) {
                        ForEach(allImages.indices, id: \.self) { index in
                            OptimizedAsyncImage(
                                url: allImages[index],
                                width: UIScreen.main.bounds.width,
                                height: 450,
                                cornerRadius: 0
                            )
                            .tag(index)
                        }
                    }
                    .tabViewStyle(.page(indexDisplayMode: .never))
                    .frame(height: 450)
                    
                    // Image counter (only show if multiple images)
                    if allImages.count > 1 {
                        Text("\(currentImageIndex + 1)/\(allImages.count)")
                            .font(.system(size: 14, weight: .semibold))
                            .foregroundColor(.white)
                            .padding(.horizontal, 12)
                            .padding(.vertical, 6)
                            .background(Color.black.opacity(0.6))
                            .cornerRadius(16)
                            .padding(16)
                    }
                }
            } else {
                // No images: show placeholder
                trainerPlaceholder
                    .frame(height: 450)
            }
            
            // Gradient overlay
            LinearGradient(
                colors: [.clear, .clear, Color(.systemBackground)],
                startPoint: .top,
                endPoint: .bottom
            )
            .frame(height: 150)
        }
        .frame(height: 450)
    }
    
    // MARK: - Name and Rating Section
    
    private var nameAndRatingSection: some View {
        VStack(spacing: 8) {
            Text(trainer.name)
                .font(.system(size: 26, weight: .bold))
                .foregroundColor(.primary)
            
            if trainer.hasRating {
                HStack(spacing: 6) {
                    Image(systemName: "star.fill")
                        .font(.system(size: 16))
                        .foregroundColor(.yellow)
                    
                    Text(trainer.formattedRating)
                        .font(.system(size: 16, weight: .bold))
                        .foregroundColor(.primary)
                    
                    if let reviews = trainer.totalReviews, reviews > 0 {
                        Text("(\(reviews) recensioner)")
                            .font(.system(size: 14))
                            .foregroundColor(.secondary)
                    }
                }
            }
        }
        .padding(.top, -20)
        .padding(.bottom, 16)
    }
    
    // MARK: - Stats Row
    
    private var statsRow: some View {
        HStack(spacing: 0) {
            // Hourly rate
            statItem(value: "\(trainer.hourlyRate)kr", label: "Timpris")
            
            Divider()
                .frame(height: 40)
            
            // Experience
            if let years = trainer.experienceYears, years > 0 {
                statItem(value: "\(years) år", label: "Erfarenhet")
            } else {
                statItem(value: "-", label: "Erfarenhet")
            }
        }
        .padding(.vertical, 16)
        .background(
            RoundedRectangle(cornerRadius: 12)
                .stroke(Color(.systemGray4), lineWidth: 1)
        )
        .padding(.horizontal, 16)
        .padding(.bottom, 24)
    }
    
    private func statItem(value: String, label: String) -> some View {
        VStack(spacing: 4) {
            Text(value)
                .font(.system(size: 18, weight: .bold))
                .foregroundColor(.primary)
            Text(label)
                .font(.system(size: 12))
                .foregroundColor(.secondary)
        }
        .frame(maxWidth: .infinity)
    }
    
    // MARK: - Description Section
    
    private var descriptionSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            if let bio = trainer.bio, !bio.isEmpty {
                Text(bio)
                    .font(.system(size: 15))
                    .foregroundColor(.primary)
                    .lineSpacing(4)
            } else {
                Text(trainer.description)
                    .font(.system(size: 15))
                    .foregroundColor(.primary)
                    .lineSpacing(4)
            }
            
            // Tags
            if let club = trainer.clubAffiliation, !club.isEmpty {
                HStack(spacing: 8) {
                    tagView(text: club)
                }
                .padding(.top, 4)
            }
            
            // Location
            if let city = trainer.city, !city.isEmpty {
                VStack(alignment: .leading, spacing: 8) {
                    Text("Kursplatser")
                        .font(.system(size: 18, weight: .bold))
                        .foregroundColor(.primary)
                        .padding(.top, 8)
                    
                    HStack(spacing: 8) {
                        Image(systemName: "mappin.and.ellipse")
                            .font(.system(size: 14))
                            .foregroundColor(.secondary)
                        Text(city)
                            .font(.system(size: 14))
                            .foregroundColor(.secondary)
                    }
                    .padding(12)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .background(
                        RoundedRectangle(cornerRadius: 10)
                            .stroke(Color(.systemGray4), lineWidth: 1)
                    )
                }
            }
        }
        .padding(.horizontal, 16)
        .padding(.bottom, 24)
    }
    
    private func tagView(text: String) -> some View {
        Text(text)
            .font(.system(size: 13, weight: .medium))
            .foregroundColor(.primary.opacity(0.8))
            .padding(.horizontal, 12)
            .padding(.vertical, 6)
            .background(
                Capsule()
                    .stroke(Color.primary.opacity(0.3), lineWidth: 1)
            )
    }
    
    // MARK: - Prices Section
    
    private var pricesSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Priser")
                .font(.system(size: 20, weight: .bold))
                .foregroundColor(.primary)
            
            VStack(alignment: .leading, spacing: 12) {
                priceRow(label: "Timpris", value: "\(trainer.hourlyRate)kr/h")
            }
            .padding(16)
            .background(
                RoundedRectangle(cornerRadius: 12)
                    .stroke(Color(.systemGray4), lineWidth: 1)
            )
        }
        .padding(.horizontal, 16)
        .padding(.bottom, 24)
    }
    
    private func priceRow(label: String, value: String) -> some View {
        HStack {
            Text(label)
                .font(.system(size: 16, weight: .semibold))
                .foregroundColor(.primary)
            Spacer()
            if !value.isEmpty {
                Text(value)
                    .font(.system(size: 16))
                    .foregroundColor(.primary)
            }
        }
    }
    
    // MARK: - Social Media Section
    
    private var socialMediaSection: some View {
        let hasSocialMedia = (trainer.instagramUrl != nil && !(trainer.instagramUrl?.isEmpty ?? true)) ||
                             (trainer.facebookUrl != nil && !(trainer.facebookUrl?.isEmpty ?? true)) ||
                             (trainer.websiteUrl != nil && !(trainer.websiteUrl?.isEmpty ?? true))
        
        return Group {
            if hasSocialMedia {
                VStack(alignment: .leading, spacing: 12) {
                    Text("Sociala medier")
                        .font(.system(size: 20, weight: .bold))
                        .foregroundColor(.primary)
                    
                    VStack(spacing: 12) {
                        if let instagram = trainer.instagramUrl, !instagram.isEmpty {
                            socialMediaButton(
                                icon: "camera.fill",
                                label: "Instagram",
                                url: instagram
                            )
                        }
                        
                        if let facebook = trainer.facebookUrl, !facebook.isEmpty {
                            socialMediaButton(
                                icon: "hand.thumbsup.fill",
                                label: "Facebook",
                                url: facebook
                            )
                        }
                        
                        if let website = trainer.websiteUrl, !website.isEmpty {
                            socialMediaButton(
                                icon: "globe",
                                label: "Hemsida",
                                url: website
                            )
                        }
                    }
                }
                .padding(.horizontal, 16)
                .padding(.bottom, 24)
            }
        }
    }
    
    private func socialMediaButton(icon: String, label: String, url: String) -> some View {
        Button {
            if let link = URL(string: url) {
                UIApplication.shared.open(link)
            }
        } label: {
            HStack(spacing: 12) {
                Image(systemName: icon)
                    .font(.system(size: 18))
                    .foregroundColor(.primary)
                    .frame(width: 36, height: 36)
                    .background(Color(.systemGray6))
                    .clipShape(Circle())
                
                Text(label)
                    .font(.system(size: 15, weight: .medium))
                    .foregroundColor(.primary)
                
                Spacer()
                
                Image(systemName: "arrow.up.right")
                    .font(.system(size: 13, weight: .semibold))
                    .foregroundColor(.secondary)
            }
            .padding(12)
            .background(
                RoundedRectangle(cornerRadius: 12)
                    .stroke(Color(.systemGray4), lineWidth: 1)
            )
        }
        .buttonStyle(.plain)
    }
    
    // MARK: - Contact Button
    
    private var contactButton: some View {
        VStack(spacing: 0) {
            // Gradient fade
            LinearGradient(
                colors: [Color(.systemBackground).opacity(0), Color(.systemBackground)],
                startPoint: .top,
                endPoint: .bottom
            )
            .frame(height: 20)
            
            VStack(spacing: 8) {
                // Contact CTA
                Button {
                    contactTrainer()
                } label: {
                    HStack(spacing: 8) {
                        Image(systemName: "message.fill")
                            .font(.system(size: 16, weight: .semibold))
                        Text("Kontakta tränaren")
                            .font(.system(size: 17, weight: .bold))
                    }
                    .foregroundColor(.white)
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 16)
                    .background(Color.primary)
                    .cornerRadius(30)
                }
                .padding(.horizontal, 24)
                
                // Trainer info mini row
                HStack(spacing: 8) {
                    ProfileImage(url: trainer.avatarUrl, size: 32)
                    
                    HStack(spacing: 4) {
                        Text(trainer.name)
                            .font(.system(size: 13, weight: .bold))
                        Image(systemName: "star.fill")
                            .font(.system(size: 11))
                            .foregroundColor(.yellow)
                        Text(trainer.formattedRating)
                            .font(.system(size: 12))
                            .foregroundColor(.secondary)
                    }
                    
                    Spacer()
                    
                    Text("\(trainer.hourlyRate)kr/h")
                        .font(.system(size: 14, weight: .semibold))
                        .foregroundColor(.primary)
                }
                .padding(.horizontal, 24)
                .padding(.bottom, 8)
            }
            .padding(.top, 8)
            .padding(.bottom, 16)
            .background(Color(.systemBackground))
        }
    }
    
    // MARK: - Contact Action
    
    private func contactTrainer() {
        showChat = true
    }
    
    // MARK: - Placeholder
    
    private var trainerPlaceholder: some View {
        ZStack {
            Color(.systemGray5)
            Image(systemName: "person.fill")
                .font(.system(size: 80))
                .foregroundColor(.gray)
        }
    }
}

#Preview {
    NavigationStack {
        TrainerProfileDetailView(
            trainer: GolfTrainer(
                id: UUID(),
                userId: "test",
                name: "Josefine",
                description: "6 års utbildning i dans på högstadie och gymnasienivå. 4 år utbildning i musikal på högskola och universitetsnivå.",
                hourlyRate: 189,
                handicap: 0,
                latitude: 57.7,
                longitude: 11.9,
                avatarUrl: nil,
                createdAt: nil,
                city: "Göteborg",
                bio: "Goda kunskaper inom olika stretchtekniker och övningar. Jobbar med både flexibilitet och mobilitet efter behov.",
                experienceYears: 6,
                clubAffiliation: "Stretching",
                averageRating: 4.9,
                totalReviews: 5,
                totalLessons: 29,
                isActive: true,
                serviceRadiusKm: nil,
                instagramUrl: "https://instagram.com/test",
                facebookUrl: nil,
                websiteUrl: "https://example.com",
                phoneNumber: nil,
                contactEmail: "test@example.com",
                galleryUrls: nil
            )
        )
        .environmentObject(AuthViewModel())
    }
}
