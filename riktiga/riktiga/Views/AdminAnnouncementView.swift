import SwiftUI

struct AdminAnnouncementView: View {
    @State private var isSending = false
    @State private var hasSent = false
    @State private var errorMessage: String?
    
    var body: some View {
        NavigationStack {
            ZStack {
                Color(.systemGroupedBackground)
                    .ignoresSafeArea()
                
                VStack(spacing: 24) {
                    // Warning banner
                    VStack(spacing: 12) {
                        Image(systemName: "exclamationmark.triangle.fill")
                            .font(.system(size: 40))
                            .foregroundColor(.orange)
                        
                        Text(L.t(sv: "⚠️ VARNING", nb: "⚠️ ADVARSEL"))
                            .font(.system(size: 22, weight: .bold))
                        
                        Text(L.t(sv: "Detta skickar en notis till ALLA användare i appen!", nb: "Dette sender et varsel til ALLE brukere i appen!"))
                            .font(.system(size: 15))
                            .foregroundColor(.secondary)
                            .multilineTextAlignment(.center)
                    }
                    .padding(24)
                    .background(Color(.secondarySystemBackground))
                    .cornerRadius(16)
                    .padding(.horizontal)
                    
                    // Preview of notification
                    VStack(alignment: .leading, spacing: 12) {
                        Text(L.t(sv: "📱 Förhandsgranskning av notis", nb: "📱 Forhåndsvisning av varsel"))
                            .font(.system(size: 16, weight: .semibold))
                            .foregroundColor(.secondary)
                        
                        VStack(alignment: .leading, spacing: 8) {
                            HStack {
                                Image(systemName: "app.badge")
                                    .foregroundColor(.blue)
                                Text("Up&Down")
                                    .font(.system(size: 14, weight: .semibold))
                                Spacer()
                                Text(L.t(sv: "nu", nb: "nå"))
                                    .font(.system(size: 12))
                                    .foregroundColor(.secondary)
                            }
                            
                            Text(L.t(sv: "Har du sett våra nya priser? 💪", nb: "Har du sett våre nye premier? 💪"))
                                .font(.system(size: 15, weight: .semibold))
                            
                            Text(L.t(sv: "Genom att träna ökar du dina chanser att vinna priser till ett värde över 3000+ kr", nb: "Ved å trene øker du sjansene dine for å vinne premier til en verdi over 3000+ kr"))
                                .font(.system(size: 14))
                                .foregroundColor(.secondary)
                        }
                        .padding(16)
                        .background(Color(.systemBackground))
                        .cornerRadius(12)
                        .shadow(color: Color.black.opacity(0.1), radius: 8, x: 0, y: 4)
                    }
                    .padding(.horizontal)
                    
                    Spacer()
                    
                    // Error message
                    if let errorMessage {
                        Text("❌ \(errorMessage)")
                            .font(.system(size: 14))
                            .foregroundColor(.red)
                            .padding(.horizontal)
                    }
                    
                    // Success message
                    if hasSent {
                        VStack(spacing: 12) {
                            Image(systemName: "checkmark.circle.fill")
                                .font(.system(size: 50))
                                .foregroundColor(.green)
                            
                            Text(L.t(sv: "✅ Notis skickad!", nb: "✅ Varsel sendt!"))
                                .font(.system(size: 18, weight: .bold))
                            
                            Text(L.t(sv: "Notisen har skickats till alla användare", nb: "Varselet er sendt til alle brukere"))
                                .font(.system(size: 14))
                                .foregroundColor(.secondary)
                        }
                        .padding(24)
                        .background(Color(.secondarySystemBackground))
                        .cornerRadius(16)
                        .padding(.horizontal)
                    }
                    
                    // Send button
                    if !hasSent {
                        Button(action: sendAnnouncement) {
                            HStack {
                                if isSending {
                                    ProgressView()
                                        .tint(.white)
                                    Text(L.t(sv: "Skickar...", nb: "Sender..."))
                                } else {
                                    Image(systemName: "paperplane.fill")
                                    Text(L.t(sv: "Skicka till alla användare", nb: "Send til alle brukere"))
                                }
                            }
                            .font(.system(size: 17, weight: .semibold))
                            .foregroundColor(.white)
                            .frame(maxWidth: .infinity)
                            .frame(height: 54)
                            .background(isSending ? Color.gray : Color.black)
                            .cornerRadius(12)
                        }
                        .disabled(isSending)
                        .padding(.horizontal)
                        .padding(.bottom, 32)
                    }
                }
                .padding(.top, 32)
            }
            .navigationTitle(L.t(sv: "Skicka Notis", nb: "Send Varsel"))
            .navigationBarTitleDisplayMode(.inline)
        }
    }
    
    private func sendAnnouncement() {
        isSending = true
        errorMessage = nil
        
        Task {
            do {
                await PushNotificationService.shared.sendAnnouncementToAllUsers(
                    title: L.t(sv: "Har du sett våra nya priser? 💪", nb: "Har du sett våre nye premier? 💪"),
                    body: L.t(sv: "Genom att träna ökar du dina chanser att vinna priser till ett värde över 3000+ kr", nb: "Ved å trene øker du sjansene dine for å vinne premier til en verdi over 3000+ kr")
                )
                
                await MainActor.run {
                    isSending = false
                    hasSent = true
                }
                
                print("✅ Announcement sent successfully!")
            } catch {
                await MainActor.run {
                    isSending = false
                    errorMessage = L.t(sv: "Kunde inte skicka notis: \(error.localizedDescription)", nb: "Kunne ikke sende varsel: \(error.localizedDescription)")
                }
                print("❌ Failed to send announcement: \(error)")
            }
        }
    }
}

#Preview {
    AdminAnnouncementView()
}

