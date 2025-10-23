import SwiftUI

struct ProfileView: View {
    @EnvironmentObject var authViewModel: AuthViewModel
    @State private var showingAlert = false
    
    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(spacing: 24) {
                    // Profilbild och namn
                    VStack(spacing: 16) {
                        Image(systemName: "person.crop.circle.fill")
                            .font(.system(size: 100))
                            .foregroundColor(Color(red: 0.1, green: 0.6, blue: 0.8))
                        
                        VStack(spacing: 4) {
                            Text(authViewModel.currentUser?.name ?? "User")
                                .font(.title2)
                                .fontWeight(.bold)
                            Text(authViewModel.currentUser?.email ?? "user@example.com")
                                .font(.caption)
                                .foregroundColor(.gray)
                        }
                    }
                    .padding(.top, 20)
                    
                    // Statistik
                    VStack(spacing: 12) {
                        Text("Din statistik")
                            .font(.headline)
                            .frame(maxWidth: .infinity, alignment: .leading)
                            .padding(.horizontal)
                        
                        VStack(spacing: 10) {
                            ProfileStatRow(icon: "calendar", label: "Medlem sedan", value: "3 månader")
                            ProfileStatRow(icon: "figure.walk", label: "Totala pass", value: "42")
                            ProfileStatRow(icon: "clock", label: "Total träning", value: "123h 45m")
                            ProfileStatRow(icon: "flame", label: "Totalt brända", value: "45,230 kcal")
                            ProfileStatRow(icon: "target", label: "Genomsnittligt måltempo", value: "7.5 min/km")
                        }
                        .padding(.horizontal)
                    }
                    
                    Divider()
                        .padding(.horizontal)
                    
                    // Inställningar
                    VStack(spacing: 12) {
                        Text("Inställningar")
                            .font(.headline)
                            .frame(maxWidth: .infinity, alignment: .leading)
                            .padding(.horizontal)
                        
                        VStack(spacing: 0) {
                            NavigationLink(destination: Text("Redigera profil")) {
                                SettingsRow(icon: "pencil", label: "Redigera profil", color: .blue)
                            }
                            
                            Divider()
                                .padding(.leading, 50)
                            
                            NavigationLink(destination: Text("Notifikationsinställningar")) {
                                SettingsRow(icon: "bell", label: "Notifikationer", color: .orange)
                            }
                            
                            Divider()
                                .padding(.leading, 50)
                            
                            NavigationLink(destination: Text("Sekretessinställningar")) {
                                SettingsRow(icon: "lock", label: "Sekretess", color: .green)
                            }
                        }
                        .background(Color(.systemGray6))
                        .cornerRadius(10)
                        .padding(.horizontal)
                    }
                    
                    Divider()
                        .padding(.horizontal)
                    
                    // Hjälp och annat
                    VStack(spacing: 12) {
                        VStack(spacing: 0) {
                            Button(action: {}) {
                                SettingsRow(icon: "questionmark.circle", label: "Hjälp & support", color: .purple, isButton: true)
                            }
                            
                            Divider()
                                .padding(.leading, 50)
                            
                            Button(action: {}) {
                                SettingsRow(icon: "info.circle", label: "Om appen", color: .gray, isButton: true)
                            }
                        }
                        .background(Color(.systemGray6))
                        .cornerRadius(10)
                        .padding(.horizontal)
                    }
                    
                    // Logga ut
                    Button(action: {
                        showingAlert = true
                    }) {
                        Text("Logga ut")
                            .frame(maxWidth: .infinity)
                            .padding(14)
                            .background(Color.red.opacity(0.1))
                            .foregroundColor(.red)
                            .cornerRadius(10)
                            .font(.headline)
                    }
                    .padding(.horizontal)
                    .padding(.vertical, 20)
                }
            }
            .navigationTitle("Profil")
            .alert("Logga ut", isPresented: $showingAlert) {
                Button("Avbryt", role: .cancel) { }
                Button("Logga ut", role: .destructive) {
                    authViewModel.logout()
                }
            } message: {
                Text("Är du säker på att du vill logga ut?")
            }
        }
    }
}

struct ProfileStatRow: View {
    let icon: String
    let label: String
    let value: String
    
    var body: some View {
        HStack(spacing: 12) {
            Image(systemName: icon)
                .foregroundColor(.white)
                .frame(width: 40, height: 40)
                .background(
                    LinearGradient(
                        gradient: Gradient(colors: [
                            Color(red: 0.1, green: 0.6, blue: 0.8),
                            Color(red: 0.2, green: 0.4, blue: 0.9)
                        ]),
                        startPoint: .topLeading,
                        endPoint: .bottomTrailing
                    )
                )
                .cornerRadius(8)
            
            VStack(alignment: .leading, spacing: 2) {
                Text(label)
                    .font(.caption)
                    .foregroundColor(.gray)
                Text(value)
                    .font(.headline)
                    .fontWeight(.bold)
            }
            
            Spacer()
        }
        .padding(10)
        .background(Color(.systemGray6))
        .cornerRadius(8)
    }
}

struct SettingsRow: View {
    let icon: String
    let label: String
    let color: Color
    var isButton = false
    
    var body: some View {
        HStack(spacing: 12) {
            Image(systemName: icon)
                .foregroundColor(color)
                .frame(width: 24, height: 24)
            
            Text(label)
                .foregroundColor(.black)
            
            Spacer()
            
            if !isButton {
                Image(systemName: "chevron.right")
                    .font(.caption)
                    .foregroundColor(.gray)
            }
        }
        .padding(16)
    }
}

#Preview {
    ProfileView()
        .environmentObject(AuthViewModel())
}
