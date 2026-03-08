import SwiftUI

private enum UppyChatConstants {
    static let freeMessageLimit = 3
}

enum UppyChatRole {
    case system
    case user
    case assistant
    
    var apiRole: String {
        switch self {
        case .system: return "system"
        case .user: return "user"
        case .assistant: return "assistant"
        }
    }
}

struct UppyChatMessage: Identifiable {
    let id: UUID
    let role: UppyChatRole
    var content: String
    var isLoading: Bool
    
    init(id: UUID = UUID(), role: UppyChatRole, content: String, isLoading: Bool = false) {
        self.id = id
        self.role = role
        self.content = content
        self.isLoading = isLoading
    }
}

struct UppyChatView: View {
    @EnvironmentObject var authViewModel: AuthViewModel
    @State private var messages: [UppyChatMessage]
    @State private var inputText: String = ""
    @State private var isSending: Bool = false
    @State private var errorMessage: String?
    @FocusState private var isInputFocused: Bool
    @State private var showPaywall = false
    @State private var didSendInitialPrompt = false
    
    private let initialPrompt: String?
    
    init(initialPrompt: String? = nil) {
        self.initialPrompt = initialPrompt
        self._messages = State(initialValue: [
            UppyChatMessage(
                role: .assistant,
                content: L.t(sv: "Hej! Jag är UPPY 🤖 Din personliga träningscoach. Vad vill du prata om idag?", nb: "Hei! Jeg er UPPY 🤖 Din personlige treningscoach. Hva vil du snakke om i dag?")
            )
        ])
    }
    
    private let quickPrompts = [
        L.t(sv: "Utveckla mitt träningsschema", nb: "Utvikle treningsplanen min"),
        L.t(sv: "Vad är mitt bästa pass hittils?", nb: "Hva er mitt beste pass hittil?"),
        L.t(sv: "Tränar jag för mycket/lite?", nb: "Trener jeg for mye/lite?"),
        L.t(sv: "Vilken övning kör jag mest på gymmet?", nb: "Hvilken øvelse gjør jeg mest på treningssenteret?")
    ]
    
    private let systemPrompt = UppyChatMessage(
        role: .system,
        content: """
        Du är Up&Downs träningsassistent. Ditt jobb är att hjälpa användaren att förstå sina träningspass, ge korta och tydliga svar samt erbjuda konkreta tips på återhämtning, motivation och förbättringar.
        
        Mål och ton:
        • Var positiv, uppmuntrande och enkel att förstå.
        • Svara kort men värdefullt.
        • Anpassa svaren efter användarens senaste träningspass, aktivitet och utveckling.
        • Låtsas aldrig veta något som inte finns i användarens data.
        • Ge aldrig medicinska diagnoser. Vid tveksamheter – hänvisa till vården.
        • Använd aldrig Markdown-fetstil eller ". Skriv allt i vanlig text utan dekorativa tecken.
        
        Data du får och ska använda:
        • Typ av pass (t.ex. löpning, styrka, cykel, promenad, intervaller)
        • Duration
        • Intensitet eller ansträngningsnivå
        • Pulsdata om det finns
        • Frekvens av träning
        • Aktivitet senaste dagarna
        • Steg per dag
        • Sömn (om användaren har delat det)
        • Användarens mål (t.ex. bli starkare, gå ner i vikt, bygga vanor, prestera bättre)
        
        Vad du ska göra i varje svar:
        1. Analysera användarens senaste pass och ge en kort sammanfattning som visar att du förstår vad de gjort.
        2. Ge återhämtningstips baserat på deras aktivitet, exempelvis rekommenderad vila, rörlighet, lätt aktivitet, vätskeintag, sömnfokus, protein och energi, samt när ett lugnt pass kan vara smart.
        3. Ge ett konkret förslag på nästa steg i träningen som matchar intensitet och frekvens, t.ex. ett lättare återhämtningspass, fortsätta i samma tempo, lägga in variation eller små tekniktips för träningsformen.
        4. Om användaren inte tränat på länge – ge snälla och motiverande förslag för att komma igång.
        5. Om användaren tränar väldigt hårt och ofta – uppmana till balans och smart recovery utan att låta negativ.
        """
    )
    
    var body: some View {
        VStack(spacing: 0) {
            chatScrollView
            
            quickPromptSection
            
            if let errorMessage {
                errorBanner(errorMessage)
            }
            
            if shouldGateChat {
                Button {
                    SuperwallService.shared.showPaywall()
                } label: {
                    Text(L.t(sv: "Uppgradera till PRO", nb: "Oppgrader til PRO"))
                        .font(.system(size: 15, weight: .semibold))
                        .foregroundColor(.white)
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 12)
                        .background(AppColors.brandBlue)
                        .cornerRadius(14)
                }
                .padding(.horizontal, 20)
                .padding(.vertical, 10)
            }
            
            inputToolbar
                .background(Color(.systemBackground))
        }
        .toolbar {
            ToolbarItem(placement: .principal) {
                HStack(spacing: 10) {
                    Image("23")
                        .resizable()
                        .scaledToFit()
                        .frame(width: 28, height: 28)
                        .clipShape(Circle())
                    VStack(alignment: .leading, spacing: 2) {
                        Text(L.t(sv: "Prata med UPPY", nb: "Snakk med UPPY"))
                            .font(.system(size: 16, weight: .semibold))
                        Text(L.t(sv: "Din träningsassistent", nb: "Din treningsassistent"))
                            .font(.system(size: 11, weight: .medium))
                            .foregroundColor(.gray)
                    }
                }
            }
        }
        .toolbar {
            ToolbarItemGroup(placement: .keyboard) {
                Spacer()
                Button(L.t(sv: "Klart", nb: "Ferdig")) {
                    isInputFocused = false
                }
            }
        }
        .onAppear {
            guard !didSendInitialPrompt,
                  let prompt = initialPrompt?.trimmingCharacters(in: .whitespacesAndNewlines),
                  !prompt.isEmpty else { return }
            didSendInitialPrompt = true
            DispatchQueue.main.async {
                send(text: prompt, clearInput: true)
            }
        }
    }
    
    private var chatScrollView: some View {
        ScrollViewReader { proxy in
            ScrollView {
                LazyVStack(alignment: .leading, spacing: 16) {
                    ForEach(messages.filter { $0.role != .system }) { message in
                        UppyMessageBubble(
                            message: message,
                            isUser: message.role == .user,
                            userAvatarURL: authViewModel.currentUser?.avatarUrl
                        )
                        .id(message.id)
                    }
                }
                .padding(.horizontal, 16)
                .padding(.vertical, 24)
            }
            .background(Color(.systemGroupedBackground))
            .onChange(of: messages.count) { _ in
                scrollToBottom(proxy: proxy)
            }
        }
    }
    
    private func scrollToBottom(proxy: ScrollViewProxy) {
        guard let lastId = messages.filter({ $0.role != .system }).last?.id else { return }
        DispatchQueue.main.async {
            withAnimation(.easeOut(duration: 0.25)) {
                proxy.scrollTo(lastId, anchor: .bottom)
            }
        }
    }
    
    private func errorBanner(_ text: String) -> some View {
        HStack(spacing: 12) {
            Image(systemName: "exclamationmark.triangle.fill")
                .foregroundColor(.white)
            Text(text)
                .font(.system(size: 13, weight: .medium))
                .foregroundColor(.white)
                .lineLimit(3)
            Spacer()
            Button(action: { errorMessage = nil }) {
                Image(systemName: "xmark")
                    .font(.system(size: 12, weight: .bold))
                    .foregroundColor(.white.opacity(0.9))
            }
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 10)
        .background(Color.red.opacity(0.85))
    }
    
    private var inputToolbar: some View {
        VStack {
            Divider()
            HStack(alignment: .bottom, spacing: 12) {
                TextField(L.t(sv: "Skriv ett meddelande…", nb: "Skriv en melding…"), text: $inputText, axis: .vertical)
                    .lineLimit(1...5)
                    .padding(12)
                    .background(Color(.systemGray6))
                    .cornerRadius(14)
                    .focused($isInputFocused)
                    .disabled(isSending)
                
                Button(action: sendMessage) {
                    Image(systemName: "paperplane.fill")
                        .font(.system(size: 18, weight: .semibold))
                        .foregroundColor(.white)
                        .padding(12)
                        .background(isSendButtonEnabled ? AppColors.brandBlue : Color.gray)
                        .clipShape(Circle())
                }
                .disabled(!isSendButtonEnabled)
            }
            .padding(.horizontal, 16)
            .padding(.vertical, 12)
            .background(Color(.systemBackground))
        }
    }
    
    private var isSendButtonEnabled: Bool {
        !shouldGateChat && !isSending && !inputText.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
    }
    
    private var remainingFreeMessages: Int {
        max(0, UppyChatConstants.freeMessageLimit - usedFreeMessages)
    }
    
    private var usedFreeMessages: Int {
        UppyUsageTracker.shared.chatCount
    }
    
    private var isProUser: Bool {
        RevenueCatManager.shared.isProMember
    }
    
    private var shouldGateChat: Bool {
        !isProUser && remainingFreeMessages == 0
    }
    
    private var quickPromptSection: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: 12) {
                ForEach(quickPrompts, id: \.self) { prompt in
                    Button {
                        sendQuickPrompt(prompt)
                    } label: {
                        Text(prompt)
                            .font(.system(size: 13, weight: .semibold))
                            .foregroundColor(.primary)
                            .padding(.horizontal, 14)
                            .padding(.vertical, 10)
                            .background(Color(.systemGray5))
                            .clipShape(Capsule())
                    }
                    .disabled(shouldGateChat || isSending)
                    .opacity(shouldGateChat ? 0.4 : 1)
                }
            }
            .padding(.horizontal, 16)
            .padding(.vertical, 12)
        }
        .background(Color(.systemBackground))
    }
    
    private func sendMessage() {
        send(text: inputText, clearInput: true)
    }
    
    private func sendQuickPrompt(_ text: String) {
        send(text: text, clearInput: false)
    }
    
    private func send(text: String, clearInput: Bool) {
        if shouldGateChat {
            SuperwallService.shared.showPaywall()
            return
        }
        
        let trimmed = text.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return }
        
        isSending = true
        errorMessage = nil
        if clearInput {
            inputText = ""
        }
        isInputFocused = false
        
        let userMessage = UppyChatMessage(role: .user, content: trimmed)
        messages.append(userMessage)
        
        var placeholder = UppyChatMessage(role: .assistant, content: "", isLoading: true)
        messages.append(placeholder)
        
        Task {
            do {
                let context = await UppyContextBuilder.shared.buildContext(for: authViewModel.currentUser)
                let conversation = await MainActor.run { buildConversationForAPI(with: context) }
                let reply = try await UppyChatService.shared.sendConversation(messages: conversation)
                await MainActor.run {
                    if let index = messages.firstIndex(where: { $0.id == placeholder.id }) {
                        messages[index].content = reply
                        messages[index].isLoading = false
                    }
                    if !isProUser {
                        UppyUsageTracker.shared.incrementChatCount()
                    }
                    isSending = false
                }
            } catch {
                await MainActor.run {
                    if let index = messages.firstIndex(where: { $0.id == placeholder.id }) {
                        messages.remove(at: index)
                    }
                    errorMessage = error.localizedDescription
                    isSending = false
                }
            }
        }
    }
    
    @MainActor
    private func buildConversationForAPI(with context: String?) -> [UppyChatMessage] {
        var history = [systemPrompt]
        if let context = context, !context.isEmpty {
            let contextMessage = UppyChatMessage(role: .system, content: "Träningsdata:\n\(context)")
            history.append(contextMessage)
        }
        let visibleMessages = messages.filter { $0.role != .system && !$0.isLoading }
        
        // Limit conversation context to last 12 exchanges to control token usage
        let trimmedHistory = visibleMessages.suffix(12)
        history.append(contentsOf: trimmedHistory)
        return history
    }
}

private struct UppyMessageBubble: View {
    let message: UppyChatMessage
    let isUser: Bool
    let userAvatarURL: String?
    
    var body: some View {
        HStack(alignment: .bottom, spacing: 12) {
            if isUser {
                Spacer(minLength: 40)
                bubbleContent(alignment: .trailing, bubbleColor: AppColors.brandBlue, textColor: .white)
                userAvatar
            } else {
                assistantAvatar
                bubbleContent(alignment: .leading, bubbleColor: Color.white, textColor: .black)
                Spacer(minLength: 40)
            }
        }
        .transition(.move(edge: isUser ? .trailing : .leading).combined(with: .opacity))
    }
    
    @ViewBuilder
    private func bubbleContent(alignment: HorizontalAlignment, bubbleColor: Color, textColor: Color) -> some View {
        VStack(alignment: alignment, spacing: 6) {
            if message.isLoading {
                ProgressView()
                    .tint(textColor == .white ? .white : AppColors.brandBlue)
            } else {
                Text(message.content)
                    .font(.system(size: 15))
                    .foregroundColor(textColor)
                    .multilineTextAlignment(alignment == .trailing ? .trailing : .leading)
            }
        }
        .padding(.horizontal, 14)
        .padding(.vertical, 12)
        .background(
            RoundedRectangle(cornerRadius: 18, style: .continuous)
                .fill(bubbleColor)
                .shadow(color: bubbleColor == .white ? Color.black.opacity(0.05) : .clear, radius: 4, x: 0, y: 2)
        )
    }
    
    private var assistantAvatar: some View {
        Image("23")
            .resizable()
            .scaledToFill()
            .frame(width: 36, height: 36)
            .clipShape(Circle())
            .overlay(Circle().stroke(Color.white, lineWidth: 1))
    }
    
    private var userAvatar: some View {
        Group {
            if let url = userAvatarURL, !url.isEmpty {
                ProfileImage(url: url, size: 36)
            } else {
                Image(systemName: "person.crop.circle.fill")
                    .resizable()
                    .scaledToFit()
                    .frame(width: 36, height: 36)
                    .foregroundColor(.gray)
            }
        }
    }
}

