import SwiftUI

struct SchoolVerificationView: View {
    @EnvironmentObject var authViewModel: AuthViewModel
    @Environment(\.dismiss) private var dismiss
    @Environment(\.colorScheme) private var colorScheme
    
    @Binding var isVerified: Bool
    var onVerified: () -> Void
    
    @State private var searchText = ""
    @State private var selectedSchoolId: String? = nil
    @State private var isAssigning = false
    @State private var schools: [School] = []
    @State private var isLoadingSchools = false
    
    private var isDark: Bool { colorScheme == .dark }
    
    private var filteredSchools: [School] {
        if searchText.isEmpty { return schools }
        return schools.filter {
            $0.name.localizedCaseInsensitiveContains(searchText) ||
            ($0.municipality?.localizedCaseInsensitiveContains(searchText) ?? false)
        }
    }
    
    var body: some View {
        NavigationView {
            VStack(spacing: 0) {
                VStack(spacing: 8) {
                    Text(L.t(sv: "Välj din skola", nb: "Velg skolen din"))
                        .font(.system(size: 24, weight: .bold))
                    
                    Text(L.t(sv: "Välj din skola för att se inlägg från alla på din skola.", nb: "Velg skolen din for å se innlegg fra alle på skolen din."))
                        .font(.system(size: 15))
                        .foregroundColor(.secondary)
                        .multilineTextAlignment(.center)
                }
                .padding(.horizontal, 24)
                .padding(.top, 24)
                .padding(.bottom, 16)
                
                HStack(spacing: 8) {
                    Image(systemName: "magnifyingglass")
                        .foregroundColor(.secondary)
                        .font(.system(size: 15))
                    TextField(L.t(sv: "Sök skola...", nb: "Søk skole..."), text: $searchText)
                        .font(.system(size: 16))
                        .textInputAutocapitalization(.never)
                        .autocorrectionDisabled()
                    if !searchText.isEmpty {
                        Button {
                            searchText = ""
                        } label: {
                            Image(systemName: "xmark.circle.fill")
                                .foregroundColor(.secondary)
                        }
                    }
                }
                .padding(12)
                .background(Color(.systemGray6))
                .cornerRadius(10)
                .padding(.horizontal, 24)
                .padding(.bottom, 12)
                
                if isLoadingSchools {
                    Spacer()
                    ProgressView()
                    Spacer()
                } else {
                    ScrollView {
                        LazyVStack(spacing: 0) {
                            ForEach(Array(filteredSchools.enumerated()), id: \.element.id) { index, school in
                                let isSelected = selectedSchoolId == school.id
                                Button {
                                    withAnimation(.easeInOut(duration: 0.2)) {
                                        selectedSchoolId = school.id
                                    }
                                } label: {
                                    HStack {
                                        Text(school.name)
                                            .font(.system(size: 15, weight: isSelected ? .semibold : .regular))
                                            .foregroundColor(.primary)
                                            .lineLimit(1)
                                        
                                        Spacer()
                                        
                                        if isSelected {
                                            Image(systemName: "checkmark")
                                                .font(.system(size: 14, weight: .semibold))
                                                .foregroundColor(isDark ? .white : .black)
                                        }
                                    }
                                    .padding(.horizontal, 16)
                                    .padding(.vertical, 14)
                                    .background(isSelected ? (isDark ? Color.white.opacity(0.08) : Color.black.opacity(0.04)) : Color.clear)
                                }
                                .buttonStyle(.plain)
                                
                                if index < filteredSchools.count - 1 {
                                    Divider()
                                        .padding(.leading, 16)
                                }
                            }
                        }
                        .background(Color(.systemBackground))
                        .cornerRadius(12)
                        .padding(.horizontal, 24)
                    }
                }
                
                Button {
                    assignSchool()
                } label: {
                    if isAssigning {
                        ProgressView()
                            .tint(isDark ? .black : .white)
                            .frame(maxWidth: .infinity)
                            .padding(.vertical, 16)
                            .background(isDark ? Color.white : Color.black)
                            .clipShape(Capsule())
                    } else {
                        Text(L.t(sv: "Välj skola", nb: "Velg skole"))
                            .font(.system(size: 17, weight: .semibold))
                            .foregroundColor(selectedSchoolId != nil ? (isDark ? .black : .white) : .gray)
                            .frame(maxWidth: .infinity)
                            .padding(.vertical, 16)
                            .background(selectedSchoolId != nil ? (isDark ? Color.white : Color.black) : Color(.systemGray4))
                            .clipShape(Capsule())
                    }
                }
                .disabled(selectedSchoolId == nil || isAssigning)
                .padding(.horizontal, 24)
                .padding(.vertical, 16)
            }
            .background(isDark ? Color.black : Color.white)
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button {
                        dismiss()
                    } label: {
                        Image(systemName: "xmark")
                            .font(.system(size: 14, weight: .medium))
                            .foregroundColor(.secondary)
                            .frame(width: 30, height: 30)
                            .background(Color(.systemGray5))
                            .clipShape(Circle())
                    }
                }
            }
            .task {
                guard schools.isEmpty else { return }
                isLoadingSchools = true
                schools = await SchoolService.shared.fetchAllSchools()
                isLoadingSchools = false
            }
        }
    }
    
    private func assignSchool() {
        guard let schoolId = selectedSchoolId,
              let userId = authViewModel.currentUser?.id else { return }
        
        isAssigning = true
        Task {
            await SchoolService.shared.assignSchool(userId: userId, schoolId: schoolId)
            await MainActor.run {
                authViewModel.currentUser?.verifiedSchoolEmail = "selected@\(schoolId)"
                isAssigning = false
                isVerified = true
                onVerified()
                dismiss()
            }
        }
    }
}
