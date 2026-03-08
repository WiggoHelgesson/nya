import SwiftUI
import PhotosUI
import Supabase
import MapKit
import CoreLocation
import Combine

struct EditProfileView: View {
    @EnvironmentObject var authViewModel: AuthViewModel
    @Environment(\.dismiss) private var dismiss
    
    // Image pickers
    @State private var username: String = ""
    @State private var selectedImage: UIImage?
    @State private var selectedBannerImage: UIImage?
    @State private var isSaving = false
    @State private var showAlert = false
    @State private var alertMessage = ""
    @State private var photosPickerItem: PhotosPickerItem?
    @State private var bannerPickerItem: PhotosPickerItem?
    
    // Section expand/collapse
    @State private var introExpanded = true
    @State private var prestationExpanded = true
    @State private var traningExpanded = true
    
    // Functional data
    @State private var bio: String = ""
    @State private var pinnedPostIds: [String] = []
    @State private var gymPb1Name: String = ""
    @State private var gymPb1Kg: String = ""
    @State private var gymPb1Reps: String = ""
    @State private var gymPb2Name: String = ""
    @State private var gymPb2Kg: String = ""
    @State private var gymPb2Reps: String = ""
    @State private var gymPb3Name: String = ""
    @State private var gymPb3Kg: String = ""
    @State private var gymPb3Reps: String = ""
    @State private var pb5km: String = ""
    @State private var pb10kmH: String = ""
    @State private var pb10kmM: String = ""
    @State private var pbMarathonH: String = ""
    @State private var pbMarathonM: String = ""
    
    // Träningsinfo data
    @State private var homeGym: String = ""
    @State private var trainingGoal: String = ""
    @State private var trainingIdentity: String = ""
    
    // Sheet states
    @State private var showBioSheet = false
    @State private var showPinnedSheet = false
    @State private var showGymPbSheet = false
    @State private var showRunningPbSheet = false
    @State private var showHomeGymSheet = false
    @State private var showTrainingGoalSheet = false
    @State private var showIdentitySheet = false
    
    // Posts for pinned picker
    @StateObject private var pinnedFeedViewModel = SocialViewModel()
    
    var body: some View {
        NavigationStack {
            ZStack {
                Color(.systemGroupedBackground).ignoresSafeArea()
                
                ScrollView {
                    VStack(spacing: 0) {
                        headerSection
                        
                        VStack(spacing: 16) {
                            usernameSection
                            introduktionSection
                            prestationsstatusSection
                            traningsinfoSection
                            saveButton
                        }
                        .padding(.horizontal, 16)
                        .padding(.top, 20)
                        .padding(.bottom, 40)
                    }
                }
            }
            .navigationTitle(L.t(sv: "Redigera profil", nb: "Rediger profil"))
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button(L.t(sv: "Avbryt", nb: "Avbryt")) {
                        dismiss()
                    }
                }
            }
            .onAppear { loadCurrentProfile() }
            .onChange(of: photosPickerItem) { _, newItem in
                Task {
                    if let data = try? await newItem?.loadTransferable(type: Data.self),
                       let uiImage = UIImage(data: data) {
                        selectedImage = uiImage
                    }
                }
            }
            .onChange(of: bannerPickerItem) { _, newItem in
                Task {
                    if let data = try? await newItem?.loadTransferable(type: Data.self),
                       let uiImage = UIImage(data: data) {
                        selectedBannerImage = uiImage
                    }
                }
            }
            .alert(L.t(sv: "Meddelande", nb: "Melding"), isPresented: $showAlert) {
                Button("OK") {
                    if alertMessage.contains("sparad") || alertMessage.contains("lagret") {
                        dismiss()
                    }
                }
            } message: {
                Text(alertMessage)
            }
            .sheet(isPresented: $showBioSheet) { bioSheet }
            .sheet(isPresented: $showPinnedSheet) { pinnedPostsSheet }
            .sheet(isPresented: $showGymPbSheet) { gymPbSheet }
            .sheet(isPresented: $showRunningPbSheet) { runningPbSheet }
            .sheet(isPresented: $showHomeGymSheet) { homeGymSheet }
            .sheet(isPresented: $showTrainingGoalSheet) { trainingGoalSheet }
            .sheet(isPresented: $showIdentitySheet) { identitySheet }
        }
    }
    
    // MARK: - Header (Banner + Avatar)
    
    private var headerSection: some View {
        ZStack(alignment: .bottom) {
            ZStack(alignment: .bottomTrailing) {
                if let bannerImage = selectedBannerImage {
                    Image(uiImage: bannerImage)
                        .resizable()
                        .scaledToFill()
                        .frame(maxWidth: .infinity)
                        .frame(height: 200)
                        .clipped()
                } else if let bannerUrl = authViewModel.currentUser?.bannerUrl, !bannerUrl.isEmpty {
                    LocalAsyncImage(path: bannerUrl)
                        .aspectRatio(contentMode: .fill)
                        .frame(maxWidth: .infinity)
                        .frame(height: 200)
                        .clipped()
                } else {
                    Color(.systemGray4)
                        .frame(height: 200)
                }
                
                PhotosPicker(selection: $bannerPickerItem, matching: .images) {
                    Image(systemName: "camera.fill")
                        .font(.system(size: 13))
                        .foregroundColor(.white)
                        .frame(width: 32, height: 32)
                        .background(Color.black.opacity(0.6))
                        .clipShape(Circle())
                }
                .padding(12)
            }
            .frame(height: 200)
            
            ZStack(alignment: .bottomTrailing) {
                if let avatarImage = selectedImage {
                    Image(uiImage: avatarImage)
                        .resizable()
                        .scaledToFill()
                        .frame(width: 100, height: 100)
                        .clipShape(Circle())
                        .overlay(Circle().stroke(Color(.systemBackground), lineWidth: 4))
                } else {
                    ProfileImage(url: authViewModel.currentUser?.avatarUrl, size: 100)
                        .overlay(Circle().stroke(Color(.systemBackground), lineWidth: 4))
                }
                
                PhotosPicker(selection: $photosPickerItem, matching: .images) {
                    Image(systemName: "camera.fill")
                        .font(.system(size: 11))
                        .foregroundColor(.white)
                        .frame(width: 28, height: 28)
                        .background(Color.black.opacity(0.7))
                        .clipShape(Circle())
                        .overlay(Circle().stroke(Color(.systemBackground), lineWidth: 2))
                }
            }
            .offset(y: 50)
        }
        .padding(.bottom, 50)
    }
    
    // MARK: - Username
    
    private var usernameSection: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text(L.t(sv: "Användarnamn", nb: "Brukernavn"))
                .font(.system(size: 14, weight: .semibold))
                .foregroundColor(.secondary)
                .padding(.leading, 4)
            
            TextField(L.t(sv: "Användarnamn", nb: "Brukernavn"), text: $username)
                .font(.system(size: 16))
                .padding(12)
                .background(Color(.systemBackground))
                .cornerRadius(10)
        }
    }
    
    // MARK: - Introduktion
    
    private var introduktionSection: some View {
        VStack(spacing: 0) {
            sectionHeader(title: L.t(sv: "Introduktion", nb: "Introduksjon"), isExpanded: $introExpanded)
            
            if introExpanded {
                Divider().padding(.horizontal, 16)
                
                editRow(icon: "pin.fill", label: L.t(sv: "Pinna dina favoritpass", nb: "Fest dine favorittøkter"), detail: pinnedPostIds.isEmpty ? nil : "\(pinnedPostIds.count)/3") {
                    showPinnedSheet = true
                }
                
                Divider().padding(.leading, 58)
                
                editRow(icon: "text.quote", label: L.t(sv: "Berätta kort om dig", nb: "Fortell kort om deg"), detail: bio.isEmpty ? nil : String(bio.prefix(20)) + (bio.count > 20 ? "..." : "")) {
                    showBioSheet = true
                }
            }
        }
        .background(Color(.systemBackground))
        .cornerRadius(12)
    }
    
    // MARK: - Prestationsstatus
    
    private var prestationsstatusSection: some View {
        VStack(spacing: 0) {
            sectionHeader(title: L.t(sv: "Prestationsstatus", nb: "Prestasjonsstatus"), isExpanded: $prestationExpanded)
            
            if prestationExpanded {
                Divider().padding(.horizontal, 16)
                
                editRow(icon: "dumbbell.fill", label: L.t(sv: "PB inom gymmet", nb: "PB i gymmet"), detail: gymPbSummary) {
                    showGymPbSheet = true
                }
                
                Divider().padding(.leading, 58)
                
                editRow(icon: "figure.run", label: L.t(sv: "PB inom löpning", nb: "PB i løping"), detail: runningPbSummary) {
                    showRunningPbSheet = true
                }
                
                Divider().padding(.leading, 58)
                
                editRow(icon: "flag.fill", label: L.t(sv: "Genomförda officiella lopp", nb: "Gjennomførte offisielle løp"), detail: nil) {
                    // Placeholder for future
                }
            }
        }
        .background(Color(.systemBackground))
        .cornerRadius(12)
    }
    
    // MARK: - Träningsinfo
    
    private var traningsinfoSection: some View {
        VStack(spacing: 0) {
            sectionHeader(title: L.t(sv: "Träningsinfo", nb: "Treningsinfo"), isExpanded: $traningExpanded)
            
            if traningExpanded {
                Divider().padding(.horizontal, 16)
                
                editRow(icon: "house.fill", label: L.t(sv: "Hemmagym", nb: "Hjemmegym"), detail: homeGym.isEmpty ? nil : homeGym) {
                    showHomeGymSheet = true
                }
                Divider().padding(.leading, 58)
                editRow(icon: "target", label: L.t(sv: "Tränar inför", nb: "Trener mot"), detail: trainingGoal.isEmpty ? nil : String(trainingGoal.prefix(25)) + (trainingGoal.count > 25 ? "..." : "")) {
                    showTrainingGoalSheet = true
                }
                Divider().padding(.leading, 58)
                editRow(icon: "person.fill", label: L.t(sv: "Träningsidentitet", nb: "Treningsidentitet"), detail: trainingIdentity.isEmpty ? nil : trainingIdentity) {
                    showIdentitySheet = true
                }
            }
        }
        .background(Color(.systemBackground))
        .cornerRadius(12)
    }
    
    // MARK: - Save Button
    
    private var saveButton: some View {
        Button(action: saveProfile) {
            if isSaving {
                ProgressView().tint(.white)
            } else {
                Text(L.t(sv: "Spara ändringar", nb: "Lagre endringer"))
                    .font(.system(size: 16, weight: .semibold))
                    .foregroundColor(.white)
            }
        }
        .frame(maxWidth: .infinity)
        .padding(16)
        .background(Color.black)
        .cornerRadius(10)
        .disabled(isSaving)
        .padding(.top, 8)
    }
    
    // MARK: - Reusable Components
    
    private func sectionHeader(title: String, isExpanded: Binding<Bool>) -> some View {
        Button {
            withAnimation(.easeInOut(duration: 0.25)) { isExpanded.wrappedValue.toggle() }
        } label: {
            HStack {
                Text(title)
                    .font(.system(size: 17, weight: .bold))
                    .foregroundColor(.primary)
                Spacer()
                Image(systemName: isExpanded.wrappedValue ? "chevron.up" : "chevron.down")
                    .font(.system(size: 14, weight: .medium))
                    .foregroundColor(.secondary)
            }
            .padding(.horizontal, 16)
            .padding(.vertical, 14)
        }
    }
    
    private func editRow(icon: String, label: String, detail: String?, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            HStack(spacing: 14) {
                Image(systemName: icon)
                    .font(.system(size: 18))
                    .foregroundColor(.secondary)
                    .frame(width: 28, alignment: .center)
                
                Text(label)
                    .font(.system(size: 15))
                    .foregroundColor(.primary)
                
                Spacer()
                
                if let detail = detail {
                    Text(detail)
                        .font(.system(size: 13))
                        .foregroundColor(.secondary)
                        .lineLimit(1)
                }
                
                Image(systemName: "pencil")
                    .font(.system(size: 14))
                    .foregroundColor(.secondary)
            }
            .padding(.horizontal, 16)
            .padding(.vertical, 13)
        }
    }
    
    // MARK: - Summaries
    
    private var gymPbSummary: String? {
        let names = [gymPb1Name, gymPb2Name, gymPb3Name].filter { !$0.isEmpty }
        if names.isEmpty { return nil }
        return names.joined(separator: ", ")
    }
    
    private var runningPbSummary: String? {
        var parts: [String] = []
        if !pb5km.isEmpty { parts.append("5km") }
        if !pb10kmM.isEmpty { parts.append("10km") }
        if !pbMarathonM.isEmpty { parts.append("42km") }
        if parts.isEmpty { return nil }
        return parts.joined(separator: ", ")
    }
    
    // MARK: - Bio Sheet
    
    private var bioSheet: some View {
        NavigationStack {
            VStack(alignment: .leading, spacing: 16) {
                Text(L.t(sv: "Berätta kort om dig", nb: "Fortell kort om deg"))
                    .font(.system(size: 15, weight: .medium))
                    .foregroundColor(.secondary)
                    .padding(.horizontal, 16)
                
                TextEditor(text: $bio)
                    .font(.system(size: 16))
                    .frame(minHeight: 120)
                    .padding(8)
                    .background(Color(.systemGray6))
                    .cornerRadius(10)
                    .padding(.horizontal, 16)
                
                Text("\(bio.count)/200")
                    .font(.system(size: 12))
                    .foregroundColor(bio.count > 200 ? .red : .secondary)
                    .padding(.horizontal, 16)
                
                Spacer()
            }
            .padding(.top, 20)
            .navigationTitle(L.t(sv: "Om dig", nb: "Om deg"))
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button(L.t(sv: "Klar", nb: "Ferdig")) { showBioSheet = false }
                        .fontWeight(.semibold)
                }
            }
        }
        .presentationDetents([.medium])
    }
    
    // MARK: - Pinned Posts Sheet
    
    private var pinnedPostsSheet: some View {
        NavigationStack {
            ZStack {
                Color(.systemGroupedBackground).ignoresSafeArea()
                
                ScrollView {
                    if pinnedFeedViewModel.isLoading && pinnedFeedViewModel.posts.isEmpty {
                        VStack(spacing: 12) {
                            ProgressView()
                            Text(L.t(sv: "Laddar dina pass...", nb: "Laster dine økter..."))
                                .font(.system(size: 14))
                                .foregroundColor(.secondary)
                        }
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 60)
                    } else if pinnedFeedViewModel.posts.isEmpty {
                        Text(L.t(sv: "Inga loggade pass hittades", nb: "Ingen loggede økter funnet"))
                            .foregroundColor(.secondary)
                            .frame(maxWidth: .infinity)
                            .padding(.vertical, 60)
                    } else {
                        LazyVStack(spacing: 0) {
                            ForEach(pinnedFeedViewModel.posts) { post in
                                let isSelected = pinnedPostIds.contains(post.id)
                                
                                ZStack(alignment: .topTrailing) {
                                    SocialPostCard(
                                        post: post,
                                        onOpenDetail: { _ in },
                                        onLikeChanged: { _, _, _ in },
                                        onCommentCountChanged: { _, _ in },
                                        onPostDeleted: { _ in }
                                    )
                                    .allowsHitTesting(false)
                                    
                                    Button {
                                        withAnimation(.easeInOut(duration: 0.2)) {
                                            if isSelected {
                                                pinnedPostIds.removeAll { $0 == post.id }
                                            } else if pinnedPostIds.count < 3 {
                                                pinnedPostIds.append(post.id)
                                            }
                                        }
                                    } label: {
                                        HStack(spacing: 6) {
                                            Image(systemName: isSelected ? "pin.fill" : "pin")
                                                .font(.system(size: 14, weight: .semibold))
                                            Text(isSelected ? L.t(sv: "Pinnad", nb: "Festet") : L.t(sv: "Pinna", nb: "Fest"))
                                                .font(.system(size: 13, weight: .semibold))
                                        }
                                        .foregroundColor(isSelected ? .white : .primary)
                                        .padding(.horizontal, 14)
                                        .padding(.vertical, 8)
                                        .background(isSelected ? Color.blue : Color(.systemGray5))
                                        .cornerRadius(20)
                                    }
                                    .padding(.top, 12)
                                    .padding(.trailing, 12)
                                    .opacity(isSelected || pinnedPostIds.count < 3 ? 1 : 0.4)
                                    .disabled(!isSelected && pinnedPostIds.count >= 3)
                                }
                            }
                        }
                    }
                }
            }
            .navigationTitle(L.t(sv: "Välj favoritpass", nb: "Velg favorittøkter"))
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarLeading) {
                    Text("\(pinnedPostIds.count)/3")
                        .font(.system(size: 15, weight: .bold))
                        .foregroundColor(pinnedPostIds.count == 3 ? .blue : .secondary)
                }
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button(L.t(sv: "Klar", nb: "Ferdig")) { showPinnedSheet = false }
                        .fontWeight(.semibold)
                }
            }
            .task {
                if let userId = authViewModel.currentUser?.id {
                    await pinnedFeedViewModel.loadPostsForUser(userId: userId, viewerId: userId, force: true)
                }
            }
        }
    }
    
    // MARK: - Gym PB Sheet
    
    private var gymPbSheet: some View {
        NavigationStack {
            ScrollView {
                VStack(spacing: 20) {
                    gymPbSlot(
                        index: 1,
                        name: $gymPb1Name,
                        kg: $gymPb1Kg,
                        reps: $gymPb1Reps
                    )
                    gymPbSlot(
                        index: 2,
                        name: $gymPb2Name,
                        kg: $gymPb2Kg,
                        reps: $gymPb2Reps
                    )
                    gymPbSlot(
                        index: 3,
                        name: $gymPb3Name,
                        kg: $gymPb3Kg,
                        reps: $gymPb3Reps
                    )
                }
                .padding(16)
            }
            .navigationTitle(L.t(sv: "PB inom gymmet", nb: "PB i gymmet"))
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button(L.t(sv: "Klar", nb: "Ferdig")) { showGymPbSheet = false }
                        .fontWeight(.semibold)
                }
            }
        }
        .presentationDetents([.large])
    }
    
    private func gymPbSlot(index: Int, name: Binding<String>, kg: Binding<String>, reps: Binding<String>) -> some View {
        VStack(alignment: .leading, spacing: 10) {
            Text(L.t(sv: "Övning \(index)", nb: "Øvelse \(index)"))
                .font(.system(size: 14, weight: .semibold))
                .foregroundColor(.secondary)
            
            TextField(L.t(sv: "Övningsnamn (t.ex. Bänkpress)", nb: "Øvelsesnavn (f.eks. Benkpress)"), text: name)
                .font(.system(size: 16))
                .padding(12)
                .background(Color(.systemGray6))
                .cornerRadius(10)
            
            HStack(spacing: 12) {
                VStack(alignment: .leading, spacing: 4) {
                    Text("Kg")
                        .font(.system(size: 12, weight: .medium))
                        .foregroundColor(.secondary)
                    TextField("0", text: kg)
                        .keyboardType(.decimalPad)
                        .font(.system(size: 16))
                        .padding(12)
                        .background(Color(.systemGray6))
                        .cornerRadius(10)
                }
                
                VStack(alignment: .leading, spacing: 4) {
                    Text("Reps")
                        .font(.system(size: 12, weight: .medium))
                        .foregroundColor(.secondary)
                    TextField("0", text: reps)
                        .keyboardType(.numberPad)
                        .font(.system(size: 16))
                        .padding(12)
                        .background(Color(.systemGray6))
                        .cornerRadius(10)
                }
            }
        }
        .padding(16)
        .background(Color(.systemBackground))
        .cornerRadius(12)
    }
    
    // MARK: - Running PB Sheet
    
    private var runningPbSheet: some View {
        NavigationStack {
            ScrollView {
                VStack(spacing: 20) {
                    runningPbRow(
                        distance: "5 km",
                        showHours: false,
                        hours: .constant(""),
                        minutes: $pb5km
                    )
                    
                    runningPbRow(
                        distance: "10 km",
                        showHours: true,
                        hours: $pb10kmH,
                        minutes: $pb10kmM
                    )
                    
                    runningPbRow(
                        distance: L.t(sv: "42 km (Maraton)", nb: "42 km (Maraton)"),
                        showHours: true,
                        hours: $pbMarathonH,
                        minutes: $pbMarathonM
                    )
                }
                .padding(16)
            }
            .navigationTitle(L.t(sv: "PB inom löpning", nb: "PB i løping"))
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button(L.t(sv: "Klar", nb: "Ferdig")) { showRunningPbSheet = false }
                        .fontWeight(.semibold)
                }
            }
        }
        .presentationDetents([.medium])
    }
    
    private func runningPbRow(distance: String, showHours: Bool, hours: Binding<String>, minutes: Binding<String>) -> some View {
        VStack(alignment: .leading, spacing: 10) {
            Text(distance)
                .font(.system(size: 15, weight: .semibold))
            
            HStack(spacing: 12) {
                if showHours {
                    VStack(alignment: .leading, spacing: 4) {
                        Text(L.t(sv: "Timmar", nb: "Timer"))
                            .font(.system(size: 12, weight: .medium))
                            .foregroundColor(.secondary)
                        TextField("0", text: hours)
                            .keyboardType(.numberPad)
                            .font(.system(size: 16))
                            .padding(12)
                            .background(Color(.systemGray6))
                            .cornerRadius(10)
                    }
                }
                
                VStack(alignment: .leading, spacing: 4) {
                    Text(L.t(sv: "Minuter", nb: "Minutter"))
                        .font(.system(size: 12, weight: .medium))
                        .foregroundColor(.secondary)
                    TextField("0", text: minutes)
                        .keyboardType(.numberPad)
                        .font(.system(size: 16))
                        .padding(12)
                        .background(Color(.systemGray6))
                        .cornerRadius(10)
                }
            }
        }
        .padding(16)
        .background(Color(.systemBackground))
        .cornerRadius(12)
    }
    
    // MARK: - Home Gym Sheet
    
    private var homeGymSheet: some View {
        HomeGymSearchSheet(selectedGym: $homeGym, isPresented: $showHomeGymSheet)
    }
    
    // MARK: - Training Goal Sheet
    
    private var trainingGoalSheet: some View {
        NavigationStack {
            VStack(alignment: .leading, spacing: 16) {
                Text(L.t(sv: "Vad tränar du inför?", nb: "Hva trener du mot?"))
                    .font(.system(size: 15, weight: .medium))
                    .foregroundColor(.secondary)
                    .padding(.horizontal, 16)
                
                TextEditor(text: $trainingGoal)
                    .font(.system(size: 16))
                    .frame(minHeight: 100)
                    .padding(8)
                    .background(Color(.systemGray6))
                    .cornerRadius(10)
                    .padding(.horizontal, 16)
                
                let wordCount = trainingGoal.split(separator: " ").count
                Text("\(wordCount)/40 \(L.t(sv: "ord", nb: "ord"))")
                    .font(.system(size: 12))
                    .foregroundColor(wordCount > 40 ? .red : .secondary)
                    .padding(.horizontal, 16)
                
                Spacer()
            }
            .padding(.top, 20)
            .navigationTitle(L.t(sv: "Tränar inför", nb: "Trener mot"))
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button(L.t(sv: "Klar", nb: "Ferdig")) { showTrainingGoalSheet = false }
                        .fontWeight(.semibold)
                }
            }
        }
        .presentationDetents([.medium])
    }
    
    // MARK: - Training Identity Sheet
    
    private var identitySheet: some View {
        NavigationStack {
            VStack(spacing: 12) {
                ForEach(["Gymrat", "Hybrid atlet", "Löpare", "Golfare"], id: \.self) { option in
                    Button {
                        trainingIdentity = (trainingIdentity == option) ? "" : option
                    } label: {
                        HStack {
                            Text(option)
                                .font(.system(size: 16, weight: .medium))
                                .foregroundColor(.primary)
                            Spacer()
                            if trainingIdentity == option {
                                Image(systemName: "checkmark.circle.fill")
                                    .font(.system(size: 22))
                                    .foregroundColor(.blue)
                            } else {
                                Image(systemName: "circle")
                                    .font(.system(size: 22))
                                    .foregroundColor(.gray)
                            }
                        }
                        .padding(16)
                        .background(trainingIdentity == option ? Color.blue.opacity(0.08) : Color(.systemBackground))
                        .cornerRadius(12)
                    }
                }
            }
            .padding(16)
            .navigationTitle(L.t(sv: "Träningsidentitet", nb: "Treningsidentitet"))
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button(L.t(sv: "Klar", nb: "Ferdig")) { showIdentitySheet = false }
                        .fontWeight(.semibold)
                }
            }
        }
        .presentationDetents([.medium])
    }
    
    // MARK: - Helpers
    
    private func iconForActivity(_ type: String) -> String {
        switch type {
        case "Gym": return "dumbbell.fill"
        case "Löpning": return "figure.run"
        case "Golf": return "figure.golf"
        case "Skidor": return "figure.skiing.downhill"
        case "Bergsklättring": return "mountain.2.fill"
        case "Simning": return "figure.pool.swim"
        case "Cykling": return "figure.outdoor.cycle"
        default: return "figure.walk"
        }
    }
    
    private func formatPostDate(_ dateString: String) -> String {
        let isoFormatter = ISO8601DateFormatter()
        isoFormatter.formatOptions = [.withInternetDateTime, .withFractionalSeconds]
        if let date = isoFormatter.date(from: dateString) {
            let df = DateFormatter()
            df.dateStyle = .medium
            df.timeStyle = .none
            df.locale = Locale(identifier: "sv_SE")
            return df.string(from: date)
        }
        let isoNoMs = ISO8601DateFormatter()
        isoNoMs.formatOptions = [.withInternetDateTime]
        if let date = isoNoMs.date(from: dateString) {
            let df = DateFormatter()
            df.dateStyle = .medium
            df.timeStyle = .none
            df.locale = Locale(identifier: "sv_SE")
            return df.string(from: date)
        }
        return dateString
    }
    
    // MARK: - Data Loading
    
    private func loadCurrentProfile() {
        guard let user = authViewModel.currentUser else { return }
        username = user.name
        bio = user.bio ?? ""
        pinnedPostIds = user.pinnedPostIds
        
        // Load gym PBs
        if user.gymPbs.count > 0 {
            gymPb1Name = user.gymPbs[0].name
            gymPb1Kg = user.gymPbs[0].kg > 0 ? String(format: "%.0f", user.gymPbs[0].kg) : ""
            gymPb1Reps = user.gymPbs[0].reps > 0 ? "\(user.gymPbs[0].reps)" : ""
        }
        if user.gymPbs.count > 1 {
            gymPb2Name = user.gymPbs[1].name
            gymPb2Kg = user.gymPbs[1].kg > 0 ? String(format: "%.0f", user.gymPbs[1].kg) : ""
            gymPb2Reps = user.gymPbs[1].reps > 0 ? "\(user.gymPbs[1].reps)" : ""
        }
        if user.gymPbs.count > 2 {
            gymPb3Name = user.gymPbs[2].name
            gymPb3Kg = user.gymPbs[2].kg > 0 ? String(format: "%.0f", user.gymPbs[2].kg) : ""
            gymPb3Reps = user.gymPbs[2].reps > 0 ? "\(user.gymPbs[2].reps)" : ""
        }
        
        // Load running PBs
        if let m = user.pb5kmMinutes { pb5km = "\(m)" }
        if let h = user.pb10kmHours { pb10kmH = "\(h)" }
        if let m = user.pb10kmMinutes { pb10kmM = "\(m)" }
        if let h = user.pbMarathonHours { pbMarathonH = "\(h)" }
        if let m = user.pbMarathonMinutes { pbMarathonM = "\(m)" }
        
        // Load träningsinfo
        homeGym = user.homeGym ?? ""
        trainingGoal = user.trainingGoal ?? ""
        trainingIdentity = user.trainingIdentity ?? ""
    }
    
    // MARK: - Build Gym PBs Array
    
    private func buildGymPbs() -> [[String: Any]] {
        var result: [[String: Any]] = []
        if !gymPb1Name.isEmpty {
            result.append(["name": gymPb1Name, "kg": Double(gymPb1Kg) ?? 0, "reps": Int(gymPb1Reps) ?? 0])
        }
        if !gymPb2Name.isEmpty {
            result.append(["name": gymPb2Name, "kg": Double(gymPb2Kg) ?? 0, "reps": Int(gymPb2Reps) ?? 0])
        }
        if !gymPb3Name.isEmpty {
            result.append(["name": gymPb3Name, "kg": Double(gymPb3Kg) ?? 0, "reps": Int(gymPb3Reps) ?? 0])
        }
        return result
    }
    
    // MARK: - Save
    
    private func saveProfile() {
        isSaving = true
        
        Task {
            do {
                var imageUrl: String?
                if let selectedImage = selectedImage {
                    imageUrl = try await uploadProfileImage(selectedImage)
                }
                
                var newBannerUrl: String?
                if let selectedBannerImage = selectedBannerImage {
                    newBannerUrl = try await uploadBannerImage(selectedBannerImage)
                }
                
                try await updateUserProfile(
                    username: username,
                    avatarUrl: imageUrl,
                    bannerUrl: newBannerUrl
                )
                
                await MainActor.run {
                    isSaving = false
                    alertMessage = L.t(sv: "Profilen har sparats!", nb: "Profilen har blitt lagret!")
                    showAlert = true
                }
            } catch {
                await MainActor.run {
                    isSaving = false
                    alertMessage = L.t(sv: "Ett fel uppstod: \(error.localizedDescription)", nb: "En feil oppstod: \(error.localizedDescription)")
                    showAlert = true
                }
            }
        }
    }
    
    private func uploadProfileImage(_ image: UIImage) async throws -> String {
        guard let userId = authViewModel.currentUser?.id else {
            throw NSError(domain: "ProfileError", code: -1, userInfo: [NSLocalizedDescriptionKey: "Ingen användare hittades"])
        }
        guard let imageData = image.jpegData(compressionQuality: 0.85) else {
            throw NSError(domain: "ImageError", code: -1, userInfo: [NSLocalizedDescriptionKey: "Kunde inte konvertera bilden"])
        }
        return try await ProfileService.shared.uploadAvatarImageData(imageData, userId: userId)
    }
    
    private func uploadBannerImage(_ image: UIImage) async throws -> String {
        guard let userId = authViewModel.currentUser?.id else {
            throw NSError(domain: "ProfileError", code: -1, userInfo: [NSLocalizedDescriptionKey: "Ingen användare hittades"])
        }
        guard let imageData = image.jpegData(compressionQuality: 0.7) else {
            throw NSError(domain: "ImageError", code: -1, userInfo: [NSLocalizedDescriptionKey: "Kunde inte konvertera bilden"])
        }
        
        let filename = "banners/\(userId)/\(UUID().uuidString).jpg"
        let supabase = SupabaseConfig.supabase
        
        _ = try await supabase.storage
            .from("avatars")
            .upload(filename, data: imageData, options: .init(contentType: "image/jpeg", upsert: true))
        
        let publicUrl = try supabase.storage
            .from("avatars")
            .getPublicURL(path: filename)
            .absoluteString
        
        return publicUrl
    }
    
    private func updateUserProfile(
        username: String,
        avatarUrl: String?,
        bannerUrl: String? = nil
    ) async throws {
        guard let userId = authViewModel.currentUser?.id else { return }
        
        let supabase = SupabaseConfig.supabase
        let gymPbsData = buildGymPbs()
        
        var updateData: [String: DynamicEncodable] = [
            "username": DynamicEncodable(username),
            "bio": DynamicEncodable(bio.isEmpty ? NSNull() : bio),
            "pinned_post_ids": DynamicEncodable(pinnedPostIds),
            "gym_pbs": DynamicEncodable(gymPbsData),
            "pb_5km_minutes": DynamicEncodable(Int(pb5km) ?? NSNull() as Any),
            "pb_10km_hours": DynamicEncodable(Int(pb10kmH) ?? NSNull() as Any),
            "pb_10km_minutes": DynamicEncodable(Int(pb10kmM) ?? NSNull() as Any),
            "pb_marathon_hours": DynamicEncodable(Int(pbMarathonH) ?? NSNull() as Any),
            "pb_marathon_minutes": DynamicEncodable(Int(pbMarathonM) ?? NSNull() as Any),
            "home_gym": DynamicEncodable(homeGym.isEmpty ? NSNull() : homeGym),
            "training_goal": DynamicEncodable(trainingGoal.isEmpty ? NSNull() : trainingGoal),
            "training_identity": DynamicEncodable(trainingIdentity.isEmpty ? NSNull() : trainingIdentity)
        ]
        
        if let avatarUrl = avatarUrl {
            updateData["avatar_url"] = DynamicEncodable(avatarUrl)
        }
        
        if let bannerUrl = bannerUrl {
            updateData["banner_url"] = DynamicEncodable(bannerUrl)
        }
        
        do {
            _ = try await supabase
                .from("profiles")
                .update(updateData)
                .eq("id", value: userId)
                .execute()
            
            await MainActor.run {
                authViewModel.currentUser?.name = username
                authViewModel.currentUser?.bio = bio.isEmpty ? nil : bio
                authViewModel.currentUser?.pinnedPostIds = pinnedPostIds
                authViewModel.currentUser?.gymPbs = buildGymPbModels()
                authViewModel.currentUser?.pb5kmMinutes = Int(pb5km)
                authViewModel.currentUser?.pb10kmHours = Int(pb10kmH)
                authViewModel.currentUser?.pb10kmMinutes = Int(pb10kmM)
                authViewModel.currentUser?.pbMarathonHours = Int(pbMarathonH)
                authViewModel.currentUser?.pbMarathonMinutes = Int(pbMarathonM)
                authViewModel.currentUser?.homeGym = homeGym.isEmpty ? nil : homeGym
                authViewModel.currentUser?.trainingGoal = trainingGoal.isEmpty ? nil : trainingGoal
                authViewModel.currentUser?.trainingIdentity = trainingIdentity.isEmpty ? nil : trainingIdentity
                if let avatarUrl = avatarUrl { authViewModel.currentUser?.avatarUrl = avatarUrl }
                if let bannerUrl = bannerUrl { authViewModel.currentUser?.bannerUrl = bannerUrl }
            }
        } catch {
            if ProfileService.shared.isMissingPersonalBestColumnsError(error) {
                var fallbackData: [String: DynamicEncodable] = [
                    "username": DynamicEncodable(username),
                    "bio": DynamicEncodable(bio.isEmpty ? NSNull() : bio)
                ]
                if let avatarUrl = avatarUrl { fallbackData["avatar_url"] = DynamicEncodable(avatarUrl) }
                if let bannerUrl = bannerUrl { fallbackData["banner_url"] = DynamicEncodable(bannerUrl) }
                
                _ = try await supabase
                    .from("profiles")
                    .update(fallbackData)
                    .eq("id", value: userId)
                    .execute()
                
                await MainActor.run {
                    authViewModel.currentUser?.name = username
                    authViewModel.currentUser?.bio = bio.isEmpty ? nil : bio
                    if let avatarUrl = avatarUrl { authViewModel.currentUser?.avatarUrl = avatarUrl }
                    if let bannerUrl = bannerUrl { authViewModel.currentUser?.bannerUrl = bannerUrl }
                }
            } else {
                throw error
            }
        }
    }
    
    private func buildGymPbModels() -> [GymPB] {
        var result: [GymPB] = []
        if !gymPb1Name.isEmpty {
            result.append(GymPB(name: gymPb1Name, kg: Double(gymPb1Kg) ?? 0, reps: Int(gymPb1Reps) ?? 0))
        }
        if !gymPb2Name.isEmpty {
            result.append(GymPB(name: gymPb2Name, kg: Double(gymPb2Kg) ?? 0, reps: Int(gymPb2Reps) ?? 0))
        }
        if !gymPb3Name.isEmpty {
            result.append(GymPB(name: gymPb3Name, kg: Double(gymPb3Kg) ?? 0, reps: Int(gymPb3Reps) ?? 0))
        }
        return result
    }
}

// MARK: - Home Gym Search Sheet

struct HomeGymSearchSheet: View {
    @Binding var selectedGym: String
    @Binding var isPresented: Bool
    
    @State private var searchText: String = ""
    @State private var nearbyGyms: [MKMapItem] = []
    @State private var isSearching = false
    @StateObject private var locationHelper = GymSearchLocationHelper()
    
    var body: some View {
        NavigationStack {
            VStack(spacing: 0) {
                HStack {
                    Image(systemName: "magnifyingglass")
                        .foregroundColor(.secondary)
                    TextField(L.t(sv: "Sök gym...", nb: "Søk gym..."), text: $searchText)
                        .font(.system(size: 16))
                        .onSubmit { searchGyms(query: searchText) }
                }
                .padding(12)
                .background(Color(.systemGray6))
                .cornerRadius(10)
                .padding(.horizontal, 16)
                .padding(.top, 12)
                
                if !selectedGym.isEmpty {
                    HStack {
                        Image(systemName: "checkmark.circle.fill")
                            .foregroundColor(.blue)
                        Text(selectedGym)
                            .font(.system(size: 14, weight: .medium))
                        Spacer()
                        Button {
                            selectedGym = ""
                        } label: {
                            Image(systemName: "xmark.circle.fill")
                                .foregroundColor(.secondary)
                        }
                    }
                    .padding(12)
                    .background(Color.blue.opacity(0.08))
                    .cornerRadius(10)
                    .padding(.horizontal, 16)
                    .padding(.top, 8)
                }
                
                if isSearching {
                    ProgressView()
                        .padding(.top, 30)
                    Spacer()
                } else {
                    List {
                        ForEach(nearbyGyms, id: \.self) { item in
                            Button {
                                selectedGym = item.name ?? L.t(sv: "Okänt gym", nb: "Ukjent gym")
                            } label: {
                                HStack(spacing: 12) {
                                    Image(systemName: "building.2.fill")
                                        .font(.system(size: 16))
                                        .foregroundColor(.secondary)
                                        .frame(width: 28)
                                    
                                    VStack(alignment: .leading, spacing: 2) {
                                        Text(item.name ?? "")
                                            .font(.system(size: 15, weight: .medium))
                                            .foregroundColor(.primary)
                                        if let address = item.placemark.title {
                                            Text(address)
                                                .font(.system(size: 12))
                                                .foregroundColor(.secondary)
                                                .lineLimit(1)
                                        }
                                    }
                                    
                                    Spacer()
                                    
                                    if selectedGym == item.name {
                                        Image(systemName: "checkmark")
                                            .foregroundColor(.blue)
                                            .fontWeight(.semibold)
                                    }
                                }
                            }
                        }
                    }
                    .listStyle(.plain)
                }
            }
            .navigationTitle(L.t(sv: "Välj hemmagym", nb: "Velg hjemmegym"))
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button(L.t(sv: "Klar", nb: "Ferdig")) { isPresented = false }
                        .fontWeight(.semibold)
                }
            }
            .task {
                locationHelper.requestLocation()
            }
            .onChange(of: locationHelper.currentLocation) { _, location in
                if let location = location, nearbyGyms.isEmpty {
                    searchGyms(near: location)
                }
            }
        }
    }
    
    private func searchGyms(query: String = "gym", near location: CLLocation? = nil) {
        isSearching = true
        let request = MKLocalSearch.Request()
        request.naturalLanguageQuery = query.isEmpty ? "gym" : query
        request.resultTypes = [.pointOfInterest]
        
        if let loc = location ?? locationHelper.currentLocation {
            request.region = MKCoordinateRegion(
                center: loc.coordinate,
                latitudinalMeters: 10000,
                longitudinalMeters: 10000
            )
        }
        
        let search = MKLocalSearch(request: request)
        search.start { response, error in
            DispatchQueue.main.async {
                isSearching = false
                if let items = response?.mapItems {
                    nearbyGyms = items
                }
            }
        }
    }
}

@MainActor
class GymSearchLocationHelper: NSObject, ObservableObject, CLLocationManagerDelegate {
    private let manager = CLLocationManager()
    @Published var currentLocation: CLLocation?
    
    override init() {
        super.init()
        manager.delegate = self
        manager.desiredAccuracy = kCLLocationAccuracyHundredMeters
    }
    
    func requestLocation() {
        manager.requestWhenInUseAuthorization()
        manager.requestLocation()
    }
    
    nonisolated func locationManager(_ manager: CLLocationManager, didUpdateLocations locations: [CLLocation]) {
        let location = locations.last
        Task { @MainActor in
            self.currentLocation = location
        }
    }
    
    nonisolated func locationManager(_ manager: CLLocationManager, didFailWithError error: Error) {
        print("Location error: \(error.localizedDescription)")
    }
}

#Preview {
    EditProfileView()
        .environmentObject(AuthViewModel())
}
