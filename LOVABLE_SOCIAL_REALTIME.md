# Social Real-time Updates Implementation

## Översikt

iOS-appen har nu stöd för realtidsuppdateringar av:
- **Likes på inlägg** - När någon gillar/ogillar ett inlägg uppdateras antalet direkt
- **Kommentarer på inlägg** - När någon lägger till/tar bort en kommentar uppdateras räknaren
- **Likes på kommentarer** - När någon gillar/ogillar en kommentar uppdateras antalet direkt

## Implementering

### 1. RealtimeSocialService.swift
En dedikerad service som hanterar alla Supabase Realtime-kanaler för sociala funktioner:

```swift
@MainActor
class RealtimeSocialService: ObservableObject {
    static let shared = RealtimeSocialService()
    
    // Publishers för real-time events
    @Published var postLikeUpdated: (postId: String, delta: Int, userId: String)?
    @Published var commentAdded: (postId: String, comment: PostComment)?
    @Published var commentDeleted: (postId: String, commentId: String)?
    @Published var commentLikeUpdated: (commentId: String, delta: Int, userId: String)?
}
```

### 2. Kanaler som lyssnas på

#### Post Likes Channel
- **Tabell:** `workout_post_likes`
- **Events:** INSERT (ny like), DELETE (unlike)
- **Resultat:** Uppdaterar `likeCount` på inlägg direkt i feed

#### Comments Channel
- **Tabell:** `workout_post_comments`
- **Events:** INSERT (ny kommentar), DELETE (raderad kommentar)
- **Resultat:** Uppdaterar `commentCount` på inlägg direkt i feed
- **Viktigt:** Vid INSERT hämtas användarens profil automatiskt för att visa namn och avatar

#### Comment Likes Channel
- **Tabell:** `comment_likes`
- **Events:** INSERT (ny like), DELETE (unlike)
- **Resultat:** Uppdaterar `likeCount` på kommentarer direkt i kommentarsvyn

### 3. Integration i SocialViewModel

SocialViewModel lyssnar på events och uppdaterar `posts`-arrayen direkt:

```swift
func setupRealtimeListeners() {
    realtimeService.$postLikeUpdated
        .compactMap { $0 }
        .sink { [weak self] update in
            self?.handlePostLikeUpdate(postId: update.postId, delta: update.delta, userId: update.userId)
        }
        .store(in: &cancellables)
    
    // ... samma för comments och comment likes
}
```

### 4. Integration i CommentsViewModel

CommentsViewModel lyssnar på comment likes och uppdaterar kommentarerna direkt:

```swift
func setupRealtimeListeners(currentUserId: String?) {
    realtimeService.$commentLikeUpdated
        .compactMap { $0 }
        .sink { [weak self] update in
            self?.handleCommentLikeUpdate(commentId: update.commentId, delta: update.delta, userId: update.userId, currentUserId: currentUserId)
        }
        .store(in: &cancellables)
}
```

## Livscykel

### Start av Realtime
Realtime startas automatiskt när SocialView visas:

```swift
.task(id: authViewModel.currentUser?.id) {
    await loadInitialData()
    await MainActor.run {
        socialViewModel.setupRealtimeListeners()
        RealtimeSocialService.shared.startListening()
    }
}
```

### Stopp av Realtime
Realtime stoppas när användaren lämnar vyn:

```swift
.onDisappear {
    RealtimeSocialService.shared.stopListening()
}
```

Detta sparar resurser och förhindrar onödiga uppdateringar när användaren inte är i sociala flödet.

## Fördelar

✅ **Omedelbar feedback** - Användare ser likes och kommentarer i realtid
✅ **Mindre nätverkstrafik** - Inga konstanta polling-requests
✅ **Bättre UX** - Applikationen känns mer levande och responsiv
✅ **Korrekt state** - UI synkas automatiskt med databasen
✅ **Resurseffektiv** - Realtime stoppas när vyn inte är aktiv

## Tekniska Detaljer

### Delta-system
Istället för att alltid hämta hela posten/kommentaren så använder vi ett delta-system:
- `delta: 1` = ny like (öka räknaren)
- `delta: -1` = unlike (minska räknaren)

Detta gör uppdateringarna mycket snabbare och mer effektiva.

### Profilhämtning för Kommentarer
När en ny kommentar skapas hämtas användarens profil automatiskt från `profiles`-tabellen:

```swift
let profiles: [UserProfile] = try await supabase
    .from("profiles")
    .select("username, avatar_url")
    .eq("id", value: userId)
    .execute()
    .value
```

Detta säkerställer att nya kommentarer visas med korrekt användarinformation direkt.

### Felhantering
Om ett fel uppstår i någon kanal loggas det men applikationen fortsätter fungera normalt. Användaren kan alltid uppdatera genom att dra ner för att refresha.

## Viktigt för Lovable

### ⚠️ Inga Ändringar Behövs i Lovable

iOS-appen hanterar hela realtime-implementeringen själv. Lovable behöver **inte** göra några ändringar i:
- Edge Functions
- Databas-triggers
- API-endpoints

### ✅ Vad Lovable Gör som Vanligt

Fortsätt att:
1. Lägga till likes via POST till workout_post_likes-tabellen
2. Radera likes via DELETE från workout_post_likes-tabellen
3. Lägga till kommentarer via POST till workout_post_comments-tabellen
4. Radera kommentarer via DELETE från workout_post_comments-tabellen
5. Lägga till comment likes via POST till comment_likes-tabellen
6. Radera comment likes via DELETE från comment_likes-tabellen

iOS-appen kommer automatiskt att lyssna på dessa ändringar och uppdatera UI i realtid.

### 🔒 Realtime Access för Tabeller

Se till att följande tabeller har Realtime aktiverat i Supabase:
- `workout_post_likes`
- `workout_post_comments`
- `comment_likes`

Detta görs i Supabase Dashboard under:
**Database > Replication > workout_post_likes/comments/comment_likes > Enable Realtime**

## Testning

För att testa realtidsuppdateringar:

1. **Test med två enheter:**
   - Öppna samma inlägg på två olika enheter
   - Gilla inlägget på enhet 1
   - Se att hjärtat och räknaren uppdateras direkt på enhet 2

2. **Test med kommentarer:**
   - Öppna kommentarsvyn för ett inlägg på två enheter
   - Skriv en kommentar på enhet 1
   - Se att kommentarsräknaren på inlägget uppdateras direkt på enhet 2

3. **Test med comment likes:**
   - Öppna samma kommentarsvy på två enheter
   - Gilla en kommentar på enhet 1
   - Se att like-räknaren uppdateras direkt på enhet 2

## Prestanda

Realtime-kanalerna är mycket effektiva:
- **Minimal latens:** ~100-500ms från databas-ändring till UI-uppdatering
- **Låg bandbredd:** Endast delta-data skickas, inte hela objekt
- **Batterivänligt:** WebSocket-anslutningar är mycket mer effektiva än polling

## Framtida Förbättringar

Möjliga framtida tillägg:
- [ ] Realtime för nya inlägg i feed
- [ ] Realtime för profiländringar (avatar, username)
- [ ] Realtime för följ-notifieringar
- [ ] Realtime för direktmeddelanden
