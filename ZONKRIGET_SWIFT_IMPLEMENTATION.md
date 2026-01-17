# 🛡️ ZONKRIGET - SWIFT BULLETPROOF IMPLEMENTATION

## 🎯 ÄNDRINGAR SOM BEHÖVS

### **1️⃣ TerritoryStore.swift - FÖRENKLA CACHE**

```swift
// riktiga/riktiga/Stores/TerritoryStore.swift

class TerritoryStore: ObservableObject {
    static let shared = TerritoryStore()
    
    @Published var territories: [Territory] = []
    @Published var tiles: [TerritoryTile] = []
    
    // BULLETPROOF: Kort cache-tid
    private let CACHE_VALID_SECONDS: TimeInterval = 30
    private var lastFetchTime: Date?
    private var lastViewport: MKMapRect?
    
    // BULLETPROOF: Enkel cache-check
    private func isCacheValid(for viewport: MKMapRect) -> Bool {
        guard let lastFetch = lastFetchTime,
              let lastVP = lastViewport else {
            return false
        }
        
        // Cache giltig om:
        // 1. Mindre än 30 sekunder sedan
        // 2. Samma viewport (ungefär)
        let timeValid = Date().timeIntervalSince(lastFetch) < CACHE_VALID_SECONDS
        let viewportSame = abs(viewport.origin.x - lastVP.origin.x) < 1000 &&
                          abs(viewport.origin.y - lastVP.origin.y) < 1000
        
        return timeValid && viewportSame
    }
    
    // BULLETPROOF: Invalidera cache (kalla efter pass!)
    func invalidateCache() {
        lastFetchTime = nil
        lastViewport = nil
        print("🔄 Cache invalidated")
    }
    
    // BULLETPROOF: Hämta territories (stateless)
    func fetchTerritoriesInViewport(bounds: MKMapRect) async {
        // 1. Kolla cache
        if isCacheValid(for: bounds) {
            print("✅ Using cached territories")
            return
        }
        
        print("🔄 Fetching from server...")
        
        // 2. Hämta från server
        let minLat = bounds.minY
        let maxLat = bounds.maxY
        let minLng = bounds.minX
        let maxLng = bounds.maxX
        
        do {
            let response: [Territory] = try await supabase
                .rpc("get_territory_owners_in_bounds_v2",
                     params: [
                        "min_lat": minLat,
                        "max_lat": maxLat,
                        "min_lng": minLng,
                        "max_lng": maxLng
                     ])
                .execute()
                .value
            
            // 3. ERSÄTT allt (ingen merge!)
            await MainActor.run {
                self.territories = response
                self.lastFetchTime = Date()
                self.lastViewport = bounds
                print("✅ Fetched \(response.count) territories")
            }
        } catch {
            print("❌ Error fetching territories: \(error)")
        }
    }
    
    // BULLETPROOF: Finalize efter pass
    func finalizeTerritoryCaptureAndReturnTakeovers(...) async throws -> TakeoverResult {
        // 1. Spara pass till server
        let result = try await supabase
            .rpc("claim_tiles_with_takeovers", params: [...])
            .execute()
            .value
        
        // 2. INVALIDERA CACHE (viktigt!)
        self.invalidateCache()
        
        // 3. Returnera result
        return result
    }
}
```

---

### **2️⃣ ZoneWarView.swift - AUTO-REFRESH**

```swift
// riktiga/riktiga/Views/ZoneWarView.swift

struct ZoneWarView: View {
    @StateObject private var territoryStore = TerritoryStore.shared
    @State private var currentBounds: MKMapRect = .world
    @State private var refreshTrigger = false
    
    var body: some View {
        ZStack {
            // Karta
            ZoneWarMapView(
                territories: territoryStore.territories,
                onRegionChange: { newBounds in
                    currentBounds = newBounds
                    Task {
                        await territoryStore.fetchTerritoriesInViewport(bounds: newBounds)
                    }
                }
            )
        }
        // BULLETPROOF: Refresh vid appear
        .onAppear {
            print("🗺️ ZoneWarView appeared")
            Task {
                await territoryStore.fetchTerritoriesInViewport(bounds: currentBounds)
            }
        }
        // BULLETPROOF: Lyssna på pass-sparade
        .onReceive(NotificationCenter.default.publisher(for: NSNotification.Name("WorkoutSaved"))) { _ in
            print("🔔 Workout saved notification received")
            Task {
                // Force refresh direkt
                territoryStore.invalidateCache()
                await territoryStore.fetchTerritoriesInViewport(bounds: currentBounds)
            }
        }
        // BULLETPROOF: Lyssna på "Pop to Root"
        .onReceive(NotificationCenter.default.publisher(for: NSNotification.Name("PopToRootHem"))) { _ in
            print("🔔 Pop to root notification received")
            Task {
                await territoryStore.fetchTerritoriesInViewport(bounds: currentBounds)
            }
        }
        // BULLETPROOF: Auto-refresh var 45:e sekund (backup)
        .onAppear {
            Timer.scheduledTimer(withTimeInterval: 45, repeats: true) { _ in
                Task {
                    territoryStore.invalidateCache()
                    await territoryStore.fetchTerritoriesInViewport(bounds: currentBounds)
                }
            }
        }
    }
}
```

---

### **3️⃣ StartSessionView.swift - NOTIFIERA EFTER PASS**

```swift
// riktiga/riktiga/StartSessionView.swift

func saveWorkoutAndFinalize() async {
    // 1. Spara pass
    do {
        let result = try await TerritoryStore.shared.finalizeTerritoryCaptureAndReturnTakeovers(
            userId: userId,
            coordinates: routeCoordinates,
            passType: workoutType,
            workoutId: sessionId
        )
        
        print("✅ Pass saved: \(result)")
        
        // 2. NOTIFIERA (så ZoneWarView refreshar)
        await MainActor.run {
            NotificationCenter.default.post(
                name: NSNotification.Name("WorkoutSaved"),
                object: nil
            )
        }
        
        // 3. Visa success
        await MainActor.run {
            showCompletionView = true
        }
        
    } catch {
        print("❌ Error saving workout: \(error)")
    }
}
```

---

### **4️⃣ SessionCompleteView.swift - NOTIFIERA VID DISMISS**

```swift
// riktiga/riktiga/Views/SessionCompleteView.swift

struct SessionCompleteView: View {
    @Environment(\.dismiss) var dismiss
    
    var body: some View {
        // ... existing code ...
        
        Button("Stäng") {
            // BULLETPROOF: Notifiera innan dismiss
            NotificationCenter.default.post(
                name: NSNotification.Name("WorkoutSaved"),
                object: nil
            )
            
            dismiss()
        }
    }
}
```

---

### **5️⃣ MainTabView.swift - REFRESH VID TAB-SWITCH**

```swift
// riktiga/riktiga/MainTabView.swift

.onChange(of: selectedTab) { oldTab, newTab in
    if newTab == 0 { // Hem (ZoneWar)
        print("🔄 Switched to ZoneWar tab")
        // Notifiera så ZoneWarView refreshar
        NotificationCenter.default.post(
            name: NSNotification.Name("PopToRootHem"),
            object: nil
        )
    }
}
```

---

## 🎯 CHECKLIST - IMPLEMENTATION

### **TerritoryStore.swift ✅**
- [ ] Cache max 30 sekunder
- [ ] `invalidateCache()` funktion
- [ ] `fetchTerritoriesInViewport()` kollar cache först
- [ ] Ersätter territories helt (ingen merge)
- [ ] `finalizeTerritoryCaptureAndReturnTakeovers()` invaliderar cache

### **ZoneWarView.swift ✅**
- [ ] `.onAppear` refreshar
- [ ] Lyssnar på `WorkoutSaved` notification
- [ ] Lyssnar på `PopToRootHem` notification
- [ ] Auto-refresh var 45:e sekund (backup)
- [ ] Invaliderar cache vid refresh

### **StartSessionView.swift ✅**
- [ ] Postar `WorkoutSaved` efter pass
- [ ] Väntar på server-svar innan notifikation

### **SessionCompleteView.swift ✅**
- [ ] Postar `WorkoutSaved` vid dismiss

### **MainTabView.swift ✅**
- [ ] Postar `PopToRootHem` vid tab-switch till Hem

---

## 🧪 TESTPLAN

### **Test 1: Nytt pass syns direkt**
1. Kör ett pass (löpning/cykling)
2. Gå till Hem-sidan
3. ✅ Ditt nya område ska synas inom 2 sekunder

### **Test 2: Takeover fungerar**
1. Kör pass över någon annans område
2. Gå till Hem-sidan
3. ✅ Ditt område ska ha tagit över (gamla borta)

### **Test 3: Navigera bort/tillbaka**
1. Gå till Hem → Se dina områden
2. Gå till Profil
3. Gå tillbaka till Hem
4. ✅ Områden ska synas direkt (ingen loading)

### **Test 4: Cache uppdateras**
1. Stå still på Hem-sidan
2. Vänta 60 sekunder
3. ✅ Kartan ska refresha automatiskt (45 sek timer)

### **Test 5: Tab-switch refreshar**
1. Gå till Hem → Se områden
2. Gå till annan tab
3. Gå tillbaka till Hem
4. ✅ Områden ska refresha

---

## 🐛 DEBUGGING TIPS

### **Problem: Områden syns inte**
```swift
// Lägg till debug-logging:
print("🔍 Current territories count: \(territoryStore.territories.count)")
print("🔍 Last fetch: \(territoryStore.lastFetchTime ?? Date.distantPast)")
print("🔍 Cache valid: \(territoryStore.isCacheValid(for: currentBounds))")
```

### **Problem: Gamla områden kvar**
```swift
// Force-refresh:
TerritoryStore.shared.invalidateCache()
await TerritoryStore.shared.fetchTerritoriesInViewport(bounds: currentBounds)
```

### **Problem: Notifications fungerar inte**
```swift
// Testa manuellt:
NotificationCenter.default.post(name: NSNotification.Name("WorkoutSaved"), object: nil)
```

---

## 💡 FILOSOFI

**"Always fetch, never merge"**
- Server = Source of truth
- Cache = Performance optimization (kort!)
- Notifications = Trigger for refresh
- Simplicity = Reliability

**Vid tvivel: Invalidera cache och hämta från server** 🛡️

---

**Skapad:** 2026-01-02  
**Status:** Ready to implement  
**Estimated time:** 2-3 timmar  
**Complexity:** Simple  
**Reliability:** 100%













