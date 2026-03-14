import SwiftUI

struct InviteView: View {
    @EnvironmentObject var authViewModel: AuthViewModel
    @Environment(\.dismiss) private var dismiss
    
    @State private var invites: [InviteCode] = []
    @State private var isLoading = true
    @State private var showCopiedToast = false
    @State private var copiedCode: String?
    
    private var availableInvites: [InviteCode] {
        invites.filter { !$0.isUsed }
    }
    
    private var usedInvites: [InviteCode] {
        invites.filter { $0.isUsed }
    }
    
    var body: some View {
        ScrollView {
            VStack(spacing: 24) {
                headerSection
                
                if isLoading {
                    ProgressView()
                        .padding(.top, 40)
                } else {
                    statsSection
                    
                    if !availableInvites.isEmpty {
                        availableSection
                    }
                    
                    if !usedInvites.isEmpty {
                        usedSection
                    }
                }
            }
            .padding(.horizontal, 20)
            .padding(.bottom, 40)
        }
        .background(Color(.systemGroupedBackground))
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            ToolbarItem(placement: .principal) {
                Text(L.t(sv: "Inbjudningar", nb: "Invitasjoner"))
                    .font(.system(size: 17, weight: .semibold))
            }
        }
        .overlay(alignment: .top) {
            if showCopiedToast {
                copiedToastView
                    .transition(.move(edge: .top).combined(with: .opacity))
                    .padding(.top, 8)
            }
        }
        .task {
            await loadInvites()
        }
    }
    
    // MARK: - Header
    
    private var headerSection: some View {
        VStack(spacing: 12) {
            Image(systemName: "envelope.badge.person.crop")
                .font(.system(size: 44))
                .foregroundColor(.primary)
                .padding(.top, 16)
            
            Text(L.t(
                sv: "Bjud in vänner till Up & Down",
                nb: "Inviter venner til Up & Down"
            ))
            .font(.system(size: 22, weight: .bold))
            .multilineTextAlignment(.center)
            
            Text(L.t(
                sv: "Up & Down är just nu exklusivt för Danderyds Gymnasium. Dela dina inbjudningar så dina vänner också kan gå med.",
                nb: "Up & Down er for øyeblikket eksklusivt for Danderyds Gymnasium. Del invitasjonene dine slik at vennene dine også kan bli med."
            ))
            .font(.system(size: 15))
            .foregroundColor(.secondary)
            .multilineTextAlignment(.center)
        }
    }
    
    // MARK: - Stats
    
    private var statsSection: some View {
        HStack(spacing: 16) {
            statCard(
                value: "\(availableInvites.count)",
                label: L.t(sv: "Kvar", nb: "Igjen"),
                icon: "ticket",
                color: .green
            )
            statCard(
                value: "\(usedInvites.count)",
                label: L.t(sv: "Använda", nb: "Brukt"),
                icon: "checkmark.circle",
                color: .blue
            )
        }
    }
    
    private func statCard(value: String, label: String, icon: String, color: Color) -> some View {
        VStack(spacing: 8) {
            Image(systemName: icon)
                .font(.system(size: 24))
                .foregroundColor(color)
            Text(value)
                .font(.system(size: 28, weight: .bold))
            Text(label)
                .font(.system(size: 13))
                .foregroundColor(.secondary)
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 20)
        .background(Color(.systemBackground))
        .cornerRadius(16)
    }
    
    // MARK: - Available Invites
    
    private var availableSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text(L.t(sv: "Tillgängliga inbjudningar", nb: "Tilgjengelige invitasjoner"))
                .font(.system(size: 15, weight: .semibold))
                .foregroundColor(.secondary)
                .padding(.leading, 4)
            
            ForEach(availableInvites) { invite in
                inviteCard(invite: invite)
            }
        }
    }
    
    private func inviteCard(invite: InviteCode) -> some View {
        VStack(spacing: 14) {
            HStack {
                Text(invite.code)
                    .font(.system(size: 20, weight: .bold, design: .monospaced))
                    .foregroundColor(.primary)
                
                Spacer()
                
                Button {
                    copyCode(invite.code)
                } label: {
                    Image(systemName: "doc.on.doc")
                        .font(.system(size: 16))
                        .foregroundColor(.primary)
                        .padding(8)
                        .background(Color(.systemGray5))
                        .clipShape(Circle())
                }
            }
            
            ShareLink(
                item: InviteService.shared.shareText(code: invite.code)
            ) {
                HStack(spacing: 8) {
                    Image(systemName: "square.and.arrow.up")
                        .font(.system(size: 15, weight: .medium))
                    Text(L.t(sv: "Dela inbjudan", nb: "Del invitasjon"))
                        .font(.system(size: 16, weight: .semibold))
                }
                .foregroundColor(.white)
                .frame(maxWidth: .infinity)
                .padding(.vertical, 14)
                .background(Color.black)
                .cornerRadius(12)
            }
        }
        .padding(16)
        .background(Color(.systemBackground))
        .cornerRadius(16)
    }
    
    // MARK: - Used Invites
    
    private var usedSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text(L.t(sv: "Använda inbjudningar", nb: "Brukte invitasjoner"))
                .font(.system(size: 15, weight: .semibold))
                .foregroundColor(.secondary)
                .padding(.leading, 4)
            
            ForEach(usedInvites) { invite in
                HStack {
                    Text(invite.code)
                        .font(.system(size: 16, weight: .medium, design: .monospaced))
                        .foregroundColor(.secondary)
                    
                    Spacer()
                    
                    HStack(spacing: 4) {
                        Image(systemName: "checkmark.circle.fill")
                            .font(.system(size: 14))
                            .foregroundColor(.green)
                        Text(L.t(sv: "Använd", nb: "Brukt"))
                            .font(.system(size: 14))
                            .foregroundColor(.secondary)
                    }
                }
                .padding(16)
                .background(Color(.systemBackground))
                .cornerRadius(12)
            }
        }
    }
    
    // MARK: - Toast
    
    private var copiedToastView: some View {
        HStack(spacing: 8) {
            Image(systemName: "checkmark.circle.fill")
                .foregroundColor(.green)
            Text(L.t(sv: "Kod kopierad!", nb: "Kode kopiert!"))
                .font(.system(size: 15, weight: .medium))
        }
        .padding(.horizontal, 20)
        .padding(.vertical, 12)
        .background(.ultraThinMaterial)
        .cornerRadius(25)
    }
    
    // MARK: - Actions
    
    private func loadInvites() async {
        guard let userId = authViewModel.currentUser?.id else { return }
        do {
            let result = try await InviteService.shared.getMyInvites(userId: userId)
            await MainActor.run {
                invites = result
                isLoading = false
            }
        } catch {
            print("❌ Error loading invites: \(error)")
            await MainActor.run { isLoading = false }
        }
    }
    
    private func copyCode(_ code: String) {
        UIPasteboard.general.string = code
        copiedCode = code
        withAnimation(.spring(response: 0.3)) {
            showCopiedToast = true
        }
        DispatchQueue.main.asyncAfter(deadline: .now() + 2) {
            withAnimation { showCopiedToast = false }
        }
    }
}
