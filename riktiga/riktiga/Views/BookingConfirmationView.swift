import SwiftUI

struct BookingConfirmationView: View {
    let trainer: GolfTrainer
    let lessonType: TrainerLessonType?
    let date: String
    let time: String
    let location: String
    let price: Int
    let onDismiss: () -> Void
    
    @State private var showCheckmark = false
    @State private var showContent = false
    
    var body: some View {
        ZStack {
            Color.white.ignoresSafeArea()
            
            ScrollView {
                VStack(spacing: 24) {
                    Spacer().frame(height: 40)
                    
                    // Success checkmark animation
                    ZStack {
                        Circle()
                            .fill(Color.black)
                            .frame(width: 100, height: 100)
                            .scaleEffect(showCheckmark ? 1 : 0)
                        
                        Image(systemName: "checkmark")
                            .font(.system(size: 50, weight: .bold))
                            .foregroundColor(.white)
                            .scaleEffect(showCheckmark ? 1 : 0)
                    }
                    .animation(.spring(response: 0.5, dampingFraction: 0.6), value: showCheckmark)
                    
                    VStack(spacing: 8) {
                        Text("Bokning bekräftad!")
                            .font(.system(size: 28, weight: .bold))
                            .foregroundColor(.black)
                        
                        Text("Din lektion är nu bokad")
                            .font(.subheadline)
                            .foregroundColor(.secondary)
                    }
                    .opacity(showContent ? 1 : 0)
                    .offset(y: showContent ? 0 : 20)
                    
                    // Booking details card
                    VStack(spacing: 0) {
                        // Trainer info header
                        HStack(spacing: 16) {
                            ProfileImage(url: trainer.avatarUrl, size: 60)
                                .overlay(Circle().stroke(Color(.systemGray4), lineWidth: 1))
                            
                            VStack(alignment: .leading, spacing: 4) {
                                Text(trainer.name)
                                    .font(.headline)
                                    .foregroundColor(.black)
                                
                                if let city = trainer.city {
                                    HStack(spacing: 4) {
                                        Image(systemName: "mappin.circle.fill")
                                            .font(.caption)
                                        Text(city)
                                            .font(.caption)
                                    }
                                    .foregroundColor(.secondary)
                                }
                            }
                            
                            Spacer()
                        }
                        .padding()
                        .background(Color(.systemGray6))
                        
                        Divider()
                        
                        // Booking details
                        VStack(spacing: 16) {
                            if let lesson = lessonType {
                                ConfirmationDetailRow(
                                    icon: "figure.golf",
                                    title: "Lektionstyp",
                                    value: lesson.name
                                )
                            }
                            
                            ConfirmationDetailRow(
                                icon: "calendar",
                                title: "Datum",
                                value: date
                            )
                            
                            ConfirmationDetailRow(
                                icon: "clock.fill",
                                title: "Tid",
                                value: time
                            )
                            
                            ConfirmationDetailRow(
                                icon: "mappin.and.ellipse",
                                title: "Plats",
                                value: location
                            )
                            
                            if let lesson = lessonType {
                                ConfirmationDetailRow(
                                    icon: "timer",
                                    title: "Längd",
                                    value: "\(lesson.durationMinutes) minuter"
                                )
                            }
                            
                            Divider()
                                .padding(.vertical, 4)
                            
                            HStack {
                                Text("Totalt betalt")
                                    .font(.headline)
                                    .foregroundColor(.black)
                                
                                Spacer()
                                
                                Text("\(price) kr")
                                    .font(.system(size: 24, weight: .bold))
                                    .foregroundColor(.black)
                            }
                        }
                        .padding()
                    }
                    .background(Color.white)
                    .cornerRadius(16)
                    .shadow(color: .black.opacity(0.08), radius: 12, x: 0, y: 4)
                    .padding(.horizontal)
                    .opacity(showContent ? 1 : 0)
                    .offset(y: showContent ? 0 : 30)
                    
                    // Info text
                    VStack(spacing: 12) {
                        HStack(spacing: 8) {
                            Image(systemName: "bell.badge.fill")
                                .foregroundColor(.black)
                            Text("Tränaren kommer att bekräfta din bokning inom kort")
                                .font(.subheadline)
                                .foregroundColor(.secondary)
                        }
                        
                        HStack(spacing: 8) {
                            Image(systemName: "message.fill")
                                .foregroundColor(.black)
                            Text("Du får en notis när bokningen är bekräftad")
                                .font(.subheadline)
                                .foregroundColor(.secondary)
                        }
                    }
                    .padding()
                    .frame(maxWidth: .infinity)
                    .background(Color(.systemGray6))
                    .cornerRadius(12)
                    .padding(.horizontal)
                    .opacity(showContent ? 1 : 0)
                    
                    Spacer().frame(height: 20)
                    
                    // Done button
                    Button {
                        onDismiss()
                    } label: {
                        Text("Klar")
                            .font(.headline)
                            .foregroundColor(.white)
                            .frame(maxWidth: .infinity)
                            .padding(.vertical, 16)
                            .background(Color.black)
                            .cornerRadius(12)
                    }
                    .padding(.horizontal)
                    .opacity(showContent ? 1 : 0)
                    
                    Spacer().frame(height: 40)
                }
            }
        }
        .onAppear {
            withAnimation(.easeOut(duration: 0.4)) {
                showCheckmark = true
            }
            
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.3) {
                withAnimation(.easeOut(duration: 0.5)) {
                    showContent = true
                }
            }
        }
    }
}

// MARK: - Detail Row

private struct ConfirmationDetailRow: View {
    let icon: String
    let title: String
    let value: String
    
    var body: some View {
        HStack(spacing: 12) {
            Image(systemName: icon)
                .font(.system(size: 18))
                .foregroundColor(.black)
                .frame(width: 24)
            
            Text(title)
                .font(.subheadline)
                .foregroundColor(.secondary)
            
            Spacer()
            
            Text(value)
                .font(.subheadline)
                .fontWeight(.medium)
                .foregroundColor(.black)
                .multilineTextAlignment(.trailing)
        }
    }
}

#Preview {
    BookingConfirmationView(
        trainer: GolfTrainer(
            id: UUID(),
            userId: "test",
            name: "Erik Andersson",
            description: "Erfaren golftränare",
            hourlyRate: 500,
            handicap: 5,
            latitude: 59.3293,
            longitude: 18.0686,
            avatarUrl: nil,
            createdAt: nil,
            city: "Stockholm",
            bio: nil,
            experienceYears: nil,
            clubAffiliation: nil,
            averageRating: nil,
            totalReviews: nil,
            totalLessons: nil,
            isActive: true,
            serviceRadiusKm: 15
        ),
        lessonType: TrainerLessonType(
            id: UUID(),
            trainerId: UUID(),
            name: "Nybörjarlektion",
            description: "Perfekt för dig som är ny",
            durationMinutes: 60,
            price: 500,
            isActive: true,
            sortOrder: 0
        ),
        date: "Lördag 14 december",
        time: "14:00",
        location: "Djursholms Golfklubb",
        price: 500,
        onDismiss: {}
    )
}

