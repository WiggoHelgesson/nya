import SwiftUI

struct ProfileView: View {
    @EnvironmentObject var authViewModel: AuthViewModel
    @State private var showingAlert = false
    
    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(spacing: 0) {
                    // MARK: - Profile Header
                    VStack(spacing: 16) {
                        // Profilbild
                        Image(systemName: "person.crop.circle.fill")
                            .font(.system(size: 80))
                            .foregroundColor(Color(red: 0.1, green: 0.6, blue: 0.8))
                        
                        // Namn
                        Text(authViewModel.currentUser?.name ?? "User")
                            .font(.system(size: 24, weight: .bold))
                        
                        // Stats
                        HStack(spacing: 30) {
                            VStack(spacing: 4) {
                                Text("1")
                                    .font(.system(size: 18, weight: .bold))
                                Text("Träningspass")
                                    .font(.caption)
                                    .foregroundColor(.gray)
                            }
                            
                            VStack(spacing: 4) {
                                Text("12")
                                    .font(.system(size: 18, weight: .bold))
                                Text("Följare")
                                    .font(.caption)
                                    .foregroundColor(.gray)
                            }
                            
                            VStack(spacing: 4) {
                                Text("18")
                                    .font(.system(size: 18, weight: .bold))
                                Text("Följer")
                                    .font(.caption)
                                    .foregroundColor(.gray)
                            }
                        }
                        
                        // Edit profil link
                        NavigationLink(destination: Text("Redigera profil")) {
                            Text("Förhandsgranska din profil")
                                .font(.caption)
                                .foregroundColor(.blue)
                                .underline()
                        }
                    }
                    .frame(maxWidth: .infinity)
                    .padding(24)
                    .background(Color(.systemGray6))
                    
                    // MARK: - XP Display Box
                    VStack(spacing: 0) {
                        HStack(spacing: 16) {
                            // U Symbol
                            Text("U")
                                .font(.system(size: 36, weight: .bold))
                                .foregroundColor(.white)
                                .frame(width: 60, height: 60)
                                .background(Color.black)
                                .cornerRadius(12)
                            
                            // XP Text
                            VStack(alignment: .leading, spacing: 4) {
                                Text("\(formatNumber(authViewModel.currentUser?.currentXP ?? 0)) Poäng")
                                    .font(.system(size: 20, weight: .bold))
                                
                                if let currentLevel = authViewModel.currentUser?.currentLevel {
                                    Text("Level \(currentLevel)")
                                        .font(.body)
                                        .foregroundColor(.gray)
                                }
                            }
                            
                            Spacer()
                        }
                        .padding(20)
                        .background(Color.black)
                        .cornerRadius(12)
                    }
                    .padding(16)
                    
                    // MARK: - Stats Buttons
                    VStack(spacing: 12) {
                        HStack(spacing: 12) {
                            StatButton(
                                icon: "cart.fill",
                                label: "Mina köp"
                            )
                            
                            StatButton(
                                icon: "chart.bar.fill",
                                label: "Statistik"
                            )
                        }
                        
                        HStack(spacing: 12) {
                            StatButton(
                                icon: "arrow.up.right.circle.fill",
                                label: "Utveckling"
                            )
                            
                            StatButton(
                                icon: "target",
                                label: "Mål"
                            )
                        }
                    }
                    .padding(16)
                    
                    Divider()
                        .padding(.vertical, 8)
                    
                    // MARK: - Settings
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
                    .padding(.horizontal, 16)
                    
                    Spacer(minLength: 20)
                    
                    // MARK: - Logout Button
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
                    .padding(.horizontal, 16)
                    .padding(.bottom, 20)
                }
            }
            .navigationTitle("Inställningar")
            .navigationBarTitleDisplayMode(.inline)
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

struct StatButton: View {
    let icon: String
    let label: String
    
    var body: some View {
        VStack(spacing: 8) {
            Image(systemName: icon)
                .font(.title2)
                .foregroundColor(.white)
                .frame(height: 40)
            
            Text(label)
                .font(.caption)
                .foregroundColor(.black)
                .lineLimit(1)
        }
        .frame(maxWidth: .infinity)
        .padding(16)
        .background(Color(.systemGray6))
        .cornerRadius(10)
    }
}

struct SettingsRow: View {
    let icon: String
    let label: String
    let color: Color
    
    var body: some View {
        HStack(spacing: 12) {
            Image(systemName: icon)
                .foregroundColor(color)
                .frame(width: 24, height: 24)
            
            Text(label)
                .foregroundColor(.black)
            
            Spacer()
            
            Image(systemName: "chevron.right")
                .font(.caption)
                .foregroundColor(.gray)
        }
        .padding(16)
    }
}

#Preview {
    ProfileView()
        .environmentObject(AuthViewModel())
}

// MARK: - Helper Functions
func formatNumber(_ number: Int) -> String {
    let formatter = NumberFormatter()
    formatter.numberStyle = .decimal
    formatter.groupingSeparator = ","
    return formatter.string(from: NSNumber(value: number)) ?? "\(number)"
}
