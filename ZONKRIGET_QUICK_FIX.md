# ⚡ ZONKRIGET - QUICK FIX GUIDE

## 🎯 FIX ZONKRIGET PÅ 30 MINUTER

### **STEG 1: DATABASE (5 min)** 📊

1. Öppna Supabase SQL Editor
2. Kör `zonkriget_bulletproof_setup.sql`
3. Verifiera: Ska visa "✅ SETUP COMPLETE!"

```sql
-- Snabb-check:
SELECT COUNT(*) as tiles, COUNT(DISTINCT owner_id) as owners 
FROM territory_tiles;
```

---

### **STEG 2: SWIFT - TerritoryStore (10 min)** 💻

Öppna `riktiga/riktiga/Stores/TerritoryStore.swift`:

**Lägg till överst:**
```swift
private let CACHE_VALID_SECONDS: TimeInterval = 30
private var lastFetchTime: Date?
```

**Lägg till funktion:**
```swift
func invalidateCache() {
    lastFetchTime = nil
    print("🔄 Cache invalidated")
}
```

**Ändra i `fetchTerritoriesInViewport`:**
```swift
func fetchTerritoriesInViewport(bounds: MKMapRect) async {
    // Lägg till överst:
    if let lastFetch = lastFetchTime,
       Date().timeIntervalSince(lastFetch) < CACHE_VALID_SECONDS {
        return
    }
    
    // Efter successful fetch:
    await MainActor.run {
        self.territories = response
        self.lastFetchTime = Date() // ← LÄGG TILL DENNA
    }
}
```

**Ändra i `finalizeTerritoryCaptureAndReturnTakeovers`:**
```swift
// Efter RPC call, före return:
self.invalidateCache()
```

---

### **STEG 3: SWIFT - ZoneWarView (10 min)** 🗺️

Öppna `riktiga/riktiga/Views/ZoneWarView.swift`:

**Lägg till listener:**
```swift
var body: some View {
    ZStack {
        // ... existing code ...
    }
    // LÄGG TILL:
    .onReceive(NotificationCenter.default.publisher(for: NSNotification.Name("WorkoutSaved"))) { _ in
        Task {
            TerritoryStore.shared.invalidateCache()
            await TerritoryStore.shared.fetchTerritoriesInViewport(bounds: currentBounds)
        }
    }
}
```

---

### **STEG 4: SWIFT - StartSessionView (5 min)** 📱

Öppna `riktiga/riktiga/StartSessionView.swift`:

**Hitta där pass sparas och lägg till:**
```swift
// Efter successful save:
await MainActor.run {
    NotificationCenter.default.post(
        name: NSNotification.Name("WorkoutSaved"),
        object: nil
    )
}
```

---

## ✅ KLART!

**Bygg och testa:**
```bash
Cmd + B  # Build
Cmd + R  # Run
```

**Testa:**
1. Kör ett pass
2. Gå till Hem
3. ✅ Området ska synas direkt!

---

## 🐛 OM DET INTE FUNGERAR

### **Check 1: Database**
```sql
SELECT COUNT(*) FROM territory_tiles;
-- Ska visa antal > 0
```

### **Check 2: Cache**
```swift
// Lägg till i ZoneWarView.onAppear:
print("🔍 Territories: \(TerritoryStore.shared.territories.count)")
```

### **Check 3: Notifications**
```swift
// Lägg till i ZoneWarView listener:
print("🔔 WorkoutSaved received!")
```

---

## 💡 KEY CHANGES

1. ✅ Cache max 30 sekunder
2. ✅ Invalidera efter pass
3. ✅ Notification-system
4. ✅ Stateless rendering

**= Bulletproof Zonkriget!** 🛡️








