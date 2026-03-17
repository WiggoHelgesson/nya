import SwiftUI

struct SchoolBattleView: View {
    @EnvironmentObject var authViewModel: AuthViewModel
    @Environment(\.colorScheme) private var colorScheme
    
    @State private var entries: [SchoolLeaderboardEntry] = []
    @State private var isLoading = true
    @State private var rowsVisible: [Bool] = []
    @State private var headerVisible = false
    @State private var showSchoolVerification = false
    @State private var isSchoolVerified = false
    
    private var isDark: Bool { colorScheme == .dark }
    
    private var userSchoolDomain: String? {
        guard let user = authViewModel.currentUser else { return nil }
        return SchoolService.verifiedDomain(for: user)
    }
    
    var body: some View {
        VStack(spacing: 0) {
            if userSchoolDomain != nil {
                leaderboardContent
            } else {
                unverifiedContent
            }
        }
        .background(isDark ? Color.black : Color(.systemBackground))
        .navigationTitle(L.t(sv: "Skolkampen", nb: "Skolkampen"))
        .navigationBarTitleDisplayMode(.inline)
        .task {
            checkVerification()
            if userSchoolDomain != nil {
                await loadEntries()
            }
        }
        .sheet(isPresented: $showSchoolVerification) {
            SchoolVerificationView(
                isVerified: $isSchoolVerified,
                onVerified: {
                    Task { await loadEntries() }
                }
            )
            .environmentObject(authViewModel)
        }
    }
    
    // MARK: - Unverified State
    
    private var unverifiedContent: some View {
        VStack(spacing: 24) {
            Spacer()
            
            Image(systemName: "trophy.fill")
                .font(.system(size: 56))
                .foregroundColor(.secondary)
            
            VStack(spacing: 12) {
                Text(L.t(sv: "För att se Skolkampen måste du tillhöra en skola", nb: "For å se Skolkampen må du tilhøre en skole"))
                    .font(.system(size: 22, weight: .bold))
                    .multilineTextAlignment(.center)
                
                Text(L.t(sv: "Sök efter din skola här", nb: "Søk etter skolen din her"))
                    .font(.system(size: 15))
                    .foregroundColor(.secondary)
                    .multilineTextAlignment(.center)
            }
            .padding(.horizontal, 32)
            
            Button {
                showSchoolVerification = true
            } label: {
                Text(L.t(sv: "Välj skola", nb: "Velg skole"))
                    .font(.system(size: 17, weight: .semibold))
                    .foregroundColor(isDark ? .black : .white)
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 16)
                    .background(isDark ? Color.white : Color.black)
                    .clipShape(Capsule())
            }
            .padding(.horizontal, 24)
            
            Spacer()
        }
    }
    
    // MARK: - Leaderboard Content
    
    private var leaderboardContent: some View {
        VStack(spacing: 0) {
            monthHeader
                .opacity(headerVisible ? 1 : 0)
                .offset(y: headerVisible ? 0 : -8)
            divider
            tableHeader
                .opacity(headerVisible ? 1 : 0)
            divider
            
            if isLoading {
                Spacer()
                ProgressView()
                Spacer()
            } else if entries.isEmpty {
                Spacer()
                emptyState
                Spacer()
            } else {
                schoolList
            }
        }
    }
    
    private var monthHeader: some View {
        Text(currentMonthName)
            .font(.system(size: 15))
            .foregroundColor(.secondary)
            .frame(maxWidth: .infinity, alignment: .leading)
            .padding(.horizontal, 20)
            .padding(.vertical, 12)
    }
    
    private var currentMonthName: String {
        let formatter = DateFormatter()
        formatter.locale = Locale(identifier: "sv_SE")
        formatter.dateFormat = "MMMM yyyy"
        return formatter.string(from: Date()).capitalized
    }
    
    private var tableHeader: some View {
        HStack {
            Text(L.t(sv: "RANK", nb: "RANK"))
                .frame(width: 44, alignment: .leading)
            Text(L.t(sv: "SKOLA", nb: "SKOLE"))
            Spacer()
            Text(L.t(sv: "VOLYM", nb: "VOLUM"))
                .frame(alignment: .trailing)
        }
        .font(.system(size: 11, weight: .medium))
        .foregroundColor(.secondary)
        .padding(.horizontal, 20)
        .padding(.vertical, 10)
    }
    
    private var divider: some View {
        Rectangle()
            .fill(Color(.separator))
            .frame(height: 0.5)
    }
    
    private var emptyState: some View {
        VStack(spacing: 12) {
            Image(systemName: "trophy")
                .font(.system(size: 40))
                .foregroundColor(.secondary)
            Text(L.t(sv: "Inga resultat ännu denna månaden", nb: "Ingen resultater denne måneden ennå"))
                .font(.system(size: 16))
                .foregroundColor(.secondary)
                .multilineTextAlignment(.center)
        }
        .padding(.horizontal, 32)
    }
    
    // MARK: - School List
    
    private var schoolList: some View {
        ScrollView {
            LazyVStack(spacing: 0) {
                ForEach(Array(entries.enumerated()), id: \.element.id) { index, entry in
                    schoolRow(rank: index + 1, entry: entry)
                        .opacity(index < rowsVisible.count && rowsVisible[index] ? 1 : 0)
                        .offset(y: index < rowsVisible.count && rowsVisible[index] ? 0 : 12)
                    divider
                        .opacity(index < rowsVisible.count && rowsVisible[index] ? 1 : 0)
                }
            }
        }
    }
    
    private func schoolRow(rank: Int, entry: SchoolLeaderboardEntry) -> some View {
        let isMySchool = entry.school_domain == userSchoolDomain
        
        return HStack(spacing: 12) {
            Text("\(rank)")
                .font(.system(size: 16, weight: .medium))
                .foregroundColor(rank <= 3 ? .primary : .secondary)
                .frame(width: 28, alignment: .leading)
            
            if rank == 1 {
                Image(systemName: "trophy.fill")
                    .font(.system(size: 20))
                    .foregroundColor(.yellow)
                    .frame(width: 40, height: 40)
            } else {
                Image(systemName: "building.columns.fill")
                    .font(.system(size: 18))
                    .foregroundColor(.secondary)
                    .frame(width: 40, height: 40)
            }
            
            VStack(alignment: .leading, spacing: 2) {
                Text(entry.school_name)
                    .font(.system(size: 16, weight: isMySchool ? .bold : .regular))
                    .foregroundColor(.primary)
                    .lineLimit(1)
                
                Text(L.t(
                    sv: "\(entry.student_count) aktiva studenter",
                    nb: "\(entry.student_count) aktive studenter"
                ))
                    .font(.system(size: 12))
                    .foregroundColor(.secondary)
            }
            
            Spacer()
            
            Text(entry.displayVolume)
                .font(.system(size: 15, weight: .medium))
                .foregroundColor(.primary)
        }
        .padding(.horizontal, 20)
        .padding(.vertical, 14)
        .background(isMySchool ? Color(.systemGray6) : Color.clear)
    }
    
    // MARK: - Logic
    
    private func checkVerification() {
        guard let user = authViewModel.currentUser else { return }
        isSchoolVerified = SchoolService.shared.isSchoolVerified(user: user)
    }
    
    private func loadEntries() async {
        await MainActor.run { isLoading = true }
        do {
            let result = try await LeaderboardService.shared.fetchSchoolBattleLeaderboard()
            await MainActor.run {
                entries = result
                isLoading = false
                animateRowsIn()
            }
        } catch {
            print("Failed to load school battle leaderboard: \(error)")
            await MainActor.run { isLoading = false }
        }
    }
    
    private func animateRowsIn() {
        rowsVisible = Array(repeating: false, count: entries.count)
        
        withAnimation(.easeOut(duration: 0.35)) {
            headerVisible = true
        }
        
        for index in entries.indices {
            let delay = 0.08 + Double(index) * 0.04
            withAnimation(.spring(response: 0.4, dampingFraction: 0.82).delay(delay)) {
                if index < rowsVisible.count {
                    rowsVisible[index] = true
                }
            }
        }
    }
}
