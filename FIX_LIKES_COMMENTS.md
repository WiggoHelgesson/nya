# FIX: Like- och Kommentarssystem

## Problem som identifierats:

### 1. LIKES FÖRSVINNER
**Orsak:** När `markLikedPosts` körs i `SocialService.swift` skapas nya `SocialWorkoutPost`-objekt, men `likeCount` hämtas från gamla cached värden.

**Symptom:**
- Likes registreras i databasen men visas inte för användare
- Like-counts är inte synkroniserade
- `isLikedByCurrentUser` uppdateras inte konsekvent

### 2. KOMMENTARER FÖRSVINNER VISUELLT
**Orsak:** `CommentsViewModel` cachar kommentarer men laddas inte om när man återöppnar kommentarsvyn.

**Symptom:**
- Kommentarer sparas i databasen men visas inte i UI
- När man stänger och öppnar kommentarer igen syns inga kommentarer
- Counts uppdateras inte korrekt

## LÖSNING:

### Steg 1: Kör detta SQL-skript i Supabase SQL Editor

Kör `/Users/wiggohelgesson/Desktop/riktiga/supabase/sql/fix_social_rls_policies.sql`

Detta säkerställer att RLS-policies är korrekt konfigurerade.

### Steg 2: Fixa SocialService.swift

Problemet är i `markLikedPosts()` - den måste ALLTID hämta fresh counts från databasen, inte från cachat post-objekt.

Ändra rad 873-877 från:
```swift
likeCount: post.likeCount,
commentCount: post.commentCount,
```

Till:
```swift
likeCount: postCountsCache[post.id]?.likeCount ?? post.likeCount ?? 0,
commentCount: postCountsCache[post.id]?.commentCount ?? post.commentCount ?? 0,
```

Men ännu bättre: Hämta ALLTID fresh counts från DB när vi checkar likes.

### Steg 3: Fixa CommentsView i SocialView.swift

Lägg till force-reload när vyn öppnas:

I `CommentsView.onAppear`:
```swift
.onAppear {
    Task {
        await reloadComments() // Force reload ALWAYS när vyn öppnas
    }
}
```

I `reloadComments()`:
```swift
private func reloadComments() async {
    print("🔄 Force reloading comments from database for post: \(postId)")
    await commentsViewModel.fetchCommentsAsync(postId: postId, currentUserId: authViewModel.currentUser?.id)
}
```

### Steg 4: Förbättra CommentsViewModel

I `fetchCommentsAsync()`, säkerställ att den ALLTID rensar gamla data först:

```swift
func fetchCommentsAsync(postId: String, currentUserId: String?) async {
    await MainActor.run {
        self.threads = [] // ALLTID rensa först
        self.isLoading = true
        self.postId = postId
        self.currentUserId = currentUserId
    }
    // ... rest av koden
}
```

### Steg 5: Säkerställ att cache uppdateras vid likes

När en användare likar/unlikar ett inlägg, uppdatera BÅDE UI OCH cache:

```swift
// Efter successful like/unlike
viewModel.updatePostLikeStatus(postId: post.id, isLiked: isLiked, likeCount: likeCount)
// OCH rensa social feed cache så att den hämtas fresh nästa gång
AppCacheManager.shared.clearSocialFeedCache(userId: userId)
```

## TEST:

1. Lika ett inlägg → Stäng appen → Öppna igen → Like ska fortfarande finnas ✅
2. Kommentera → Stäng kommentarer → Öppna igen → Kommentar ska synas ✅
3. Flera användare likar samma inlägg → Alla ska se rätt count ✅





