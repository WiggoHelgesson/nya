import SwiftUI

struct SettingsView: View {
    @EnvironmentObject var authViewModel: AuthViewModel
    @Environment(\.dismiss) var dismiss
    
    var body: some View {
        NavigationStack {
            ZStack {
                Color(.systemGray6)
                    .ignoresSafeArea()
                
                VStack(spacing: 24) {
                    // MARK: - PRENUMERATION Section
                    VStack(alignment: .leading, spacing: 0) {
                        Text("PRENUMERATION")
                            .font(.system(size: 12, weight: .bold))
                            .foregroundColor(.gray)
                            .padding(.horizontal, 16)
                            .padding(.bottom, 8)
                        
                        VStack(spacing: 0) {
                            SettingsRow(
                                title: "Up&Down PRO",
                                icon: "chevron.right",
                                action: {}
                            )
                            
                            Divider()
                                .padding(.leading, 16)
                            
                            SettingsRow(
                                title: "Hantera prenumeration",
                                icon: "chevron.right",
                                action: {}
                            )
                        }
                        .background(Color.white)
                        .cornerRadius(12)
                    }
                    
                    // MARK: - INFORMATION Section
                    VStack(alignment: .leading, spacing: 0) {
                        Text("INFORMATION")
                            .font(.system(size: 12, weight: .bold))
                            .foregroundColor(.gray)
                            .padding(.horizontal, 16)
                            .padding(.bottom, 8)
                        
                        VStack(spacing: 0) {
                            SettingsRow(
                                title: "Hur du använder Up&Down",
                                icon: "chevron.right",
                                action: {}
                            )
                            
                            Divider()
                                .padding(.leading, 16)
                            
                            SettingsRow(
                                title: "Vanliga frågor",
                                icon: "chevron.right",
                                action: {}
                            )
                            
                            Divider()
                                .padding(.leading, 16)
                            
                            SettingsRow(
                                title: "Kontakta oss",
                                icon: "chevron.right",
                                action: {}
                            )
                            
                            Divider()
                                .padding(.leading, 16)
                            
                            SettingsRow(
                                title: "Privacy Policy",
                                icon: "chevron.right",
                                action: {}
                            )
                        }
                        .background(Color.white)
                        .cornerRadius(12)
                    }
                    
                    Spacer()
                    
                    // MARK: - Logga ut Button
                    Button(action: {
                        authViewModel.logout()
                        dismiss()
                    }) {
                        HStack(spacing: 12) {
                            Image(systemName: "rectangle.portrait.and.arrow.right")
                                .font(.system(size: 16))
                                .foregroundColor(.red)
                            
                            Text("Logga ut")
                                .font(.system(size: 16, weight: .medium))
                                .foregroundColor(.red)
                            
                            Spacer()
                        }
                        .padding(16)
                        .background(Color.white)
                        .cornerRadius(12)
                    }
                }
                .padding(16)
            }
            .navigationTitle("Inställningar")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button("Klar") {
                        dismiss()
                    }
                    .foregroundColor(.black)
                }
            }
        }
    }
}

struct SettingsRow: View {
    let title: String
    let icon: String
    let action: () -> Void
    
    var body: some View {
        Button(action: action) {
            HStack {
                Text(title)
                    .font(.system(size: 16))
                    .foregroundColor(.black)
                
                Spacer()
                
                Image(systemName: icon)
                    .font(.system(size: 14, weight: .medium))
                    .foregroundColor(.gray)
            }
            .padding(16)
        }
    }
}

#Preview {
    SettingsView()
        .environmentObject(AuthViewModel())
}
