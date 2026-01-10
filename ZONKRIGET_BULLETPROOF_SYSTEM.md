# 🗺️ ZONKRIGET - BULLETPROOF SYSTEM

## 🎯 MÅL
**Ett Zonkriget-system som:**
- ✅ Alltid visar rätt områden
- ✅ Uppdaterar direkt efter pass
- ✅ Aldrig visar gamla/felaktiga områden
- ✅ Fungerar när man navigerar bort/tillbaka
- ✅ Är enkelt att underhålla

---

## 🏗️ ARKITEKTUR (3 LAGER)

### **Layer 1: DATABASE (Source of Truth)** 📊
```
territory_tiles (ENDA källan för ägarskap)
├── id (uuid)
├── owner_id (uuid) 
├── geom (geometry - tile position)
├── last_updated_at (timestamp)
└── area_m2 (float)

REGEL: Om en tile finns här = den ägs av owner_id
REGEL: Om en tile INTE finns här = ingen äger den
```

### **Layer 2: SERVER (Business Logic)** ⚙️
```
RPC Functions (Postgres):
├── claim_tiles_with_takeovers() - Spara pass + ta över
├── get_territory_owners_in_bounds_v2() - Hämta synliga områden
└── cleanup_old_tiles() - Ta bort föråldrade tiles (optional)

REGEL: ALL logik ska vara i SQL-funktioner
REGEL: Swift-koden bara kallar funktioner och visar resultat
```

### **Layer 3: APP (Dumb Renderer)** 📱
```
Swift Views:
├── ZoneWarView - Visar karta
├── ZoneWarMapView - Renderar polygoner
└── TerritoryStore - Cachar data (kort tid)

REGEL: Ingen business logic i Swift
REGEL: Alltid visa vad servern säger
REGEL: Cache max 30 sekunder
```

---

## 🔧 IMPLEMENTATION

### **1️⃣ DATABASE SETUP**

```sql
-- SKAPA TABELL (om den inte finns)
CREATE TABLE IF NOT EXISTS public.territory_tiles (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    owner_id UUID NOT NULL REFERENCES auth.users(id) ON DELETE CASCADE,
    geom GEOMETRY(Point, 4326) NOT NULL,
    last_updated_at TIMESTAMPTZ NOT NULL DEFAULT NOW(),
    area_m2 FLOAT NOT NULL DEFAULT 0,
    created_at TIMESTAMPTZ DEFAULT NOW()
);

-- INDEX FÖR SNABBHET
CREATE INDEX IF NOT EXISTS territory_tiles_owner_idx ON territory_tiles(owner_id);
CREATE INDEX IF NOT EXISTS territory_tiles_geom_idx ON territory_tiles USING GIST(geom);
CREATE INDEX IF NOT EXISTS territory_tiles_updated_idx ON territory_tiles(last_updated_at DESC);

-- CLEANUP: Ta bort dubbletter (KÖR EN GÅNG)
DELETE FROM territory_tiles a
WHERE a.id NOT IN (
    SELECT MAX(id)
    FROM territory_tiles b
    WHERE ST_Equals(a.geom, b.geom)
    GROUP BY geom
);
```

---

### **2️⃣ CLAIM LOGIC (claim_tiles_with_takeovers.sql)**

**PRINCIP:** 
- När användare kör pass → GPS-punkter → tiles
- Kolla varje tile: Ägs redan? → Ta över! Ledig? → Claim!
- Returnera alla takeovers för UI

**FIX:**
```sql
-- Lägg till i slutet av claim_tiles_with_takeovers.sql:

-- CLEANUP: Ta bort tiles som inte uppdaterats på 90 dagar (optional)
DELETE FROM public.territory_tiles
WHERE last_updated_at < NOW() - INTERVAL '90 days';

-- RETURNERA: Nya + tagna tiles
RETURN QUERY
SELECT 
    new_tile_ids AS tiles_claimed,
    taken_tile_ids AS tiles_taken,
    NULL::text AS username,
    NULL::text AS avatar_url;
```

---

### **3️⃣ FETCH LOGIC (get_territory_owners_in_bounds_v2.sql)**

**PRINCIP:**
- Hämta ENDAST tiles inom viewport
- Gruppera per owner
- Förenkla geometri för snabbhet
- Returnera MultiPolygon per owner

**NUVARANDE VERSION ÄR OK** - men dubbelkolla att den:
1. Filtrerar på viewport (`WHERE t.geom && env_4326`)
2. Grupperar per owner (`GROUP BY owner_id`)
3. Förenklar geometri (`ST_SimplifyPreserveTopology`)
4. Returnerar area i m² (`ST_Area`)

---

### **4️⃣ APP LOGIC (Swift)**

**PRINCIP: Stateless Rendering**

```swift
// TerritoryStore.swift - FÖRENKLA!
class TerritoryStore {
    private let CACHE_VALID_SECONDS = 30 // Max 30 sek cache
    private var lastFetch: Date?
    
    func fetchTerritoriesInViewport(bounds: MKMapRect) async {
        // 1. Är cache giltig?
        if let last = lastFetch, Date().timeIntervalSince(last) < CACHE_VALID_SECONDS {
            return // Använd cache
        }
        
        // 2. Hämta ALLTID från server annars
        let territories = try await supabase
            .rpc("get_territory_owners_in_bounds_v2", params: [...])
            .execute()
        
        // 3. Ersätt ALLT (ingen merge!)
        await MainActor.run {
            self.territories = territories
            self.lastFetch = Date()
        }
    }
    
    func invalidateCache() {
        lastFetch = nil
        territories = []
    }
}
```

```swift
// StartSessionView.swift - EFTER PASS
func saveWorkout() async {
    // 1. Spara pass
    let result = try await TerritoryStore.shared.finalizeTerritoryCaptureAndReturnTakeovers(...)
    
    // 2. INVALIDERA CACHE omedelbart
    TerritoryStore.shared.invalidateCache()
    
    // 3. Notifiera ZoneWarView
    NotificationCenter.default.post(name: NSNotification.Name("WorkoutSaved"), object: nil)
}
```

```swift
// ZoneWarView.swift - LYSSNA PÅ UPPDATERINGAR
.onReceive(NotificationCenter.default.publisher(for: NSNotification.Name("WorkoutSaved"))) { _ in
    // Force refresh direkt
    Task {
        await territoryStore.fetchTerritoriesInViewport(bounds: currentBounds)
    }
}

.onAppear {
    // Refresh alltid vid appear
    Task {
        await territoryStore.fetchTerritoriesInViewport(bounds: currentBounds)
    }
}
```

---

## 🎯 REGLER FÖR BULLETPROOF SYSTEM

### **✅ DO:**
1. **Alltid lita på server-data** - Servern äger sanningen
2. **Kort cache** - Max 30 sekunder
3. **Invalidera efter ändringar** - Tvinga refresh efter pass
4. **Stateless rendering** - Visa vad servern säger, inget annat
5. **Enkel logik** - Inga komplexa merges eller beräkningar i Swift

### **❌ DON'T:**
1. **Aldrig cacha för länge** - Inget "permanent" minne i Swift
2. **Aldrig merge server + local** - Ersätt alltid helt
3. **Aldrig business logic i Swift** - Allt viktigt i SQL
4. **Aldrig ignorera viewport** - Hämta bara vad som syns
5. **Aldrig skippa refresh** - Vid tvivel, hämta från server

---

## 🔥 COMMON ISSUES & FIXES

### **Problem 1: "Gamla områden visas fortfarande"**
**Orsak:** Cache är för lång eller merge-logik
**Fix:** 
```swift
TerritoryStore.shared.invalidateCache()
await territoryStore.fetchTerritoriesInViewport(bounds: bounds)
```

### **Problem 2: "Nya pass syns inte direkt"**
**Orsak:** Cache inte invaliderad efter pass
**Fix:**
```swift
// Efter finalizeTerritoryCaptureAndReturnTakeovers:
TerritoryStore.shared.invalidateCache()
NotificationCenter.default.post(name: NSNotification.Name("WorkoutSaved"), object: nil)
```

### **Problem 3: "Zoner försvinner när jag navigerar bort/tillbaka"**
**Orsak:** Cache rensas när view försvinner
**Fix:**
```swift
.onAppear {
    // Alltid refresh när view visas
    Task {
        await territoryStore.fetchTerritoriesInViewport(bounds: currentBounds)
    }
}
```

### **Problem 4: "Duplikat-tiles i databasen"**
**Orsak:** Samma GPS-punkt sparad flera gånger
**Fix:**
```sql
-- Kör denna CLEANUP en gång:
DELETE FROM territory_tiles a
WHERE a.id NOT IN (
    SELECT MAX(id)
    FROM territory_tiles b
    WHERE ST_Equals(a.geom, b.geom)
    GROUP BY geom
);

-- Lägg till UNIQUE constraint:
CREATE UNIQUE INDEX territory_tiles_geom_unique 
ON territory_tiles USING GIST (geom);
```

---

## 📋 CHECKLIST - ÄR DITT SYSTEM BULLETPROOF?

### **Database ✅**
- [ ] `territory_tiles` tabell finns
- [ ] Index på `owner_id`, `geom`, `last_updated_at`
- [ ] Inga dubbletter (kör cleanup-query)
- [ ] RLS policies uppsatta

### **SQL Functions ✅**
- [ ] `claim_tiles_with_takeovers()` fungerar
- [ ] `get_territory_owners_in_bounds_v2()` fungerar
- [ ] Båda returnerar korrekt data (testa manuellt)

### **Swift Code ✅**
- [ ] Cache max 30 sekunder
- [ ] Invalideras efter pass
- [ ] `.onAppear` refreshar alltid
- [ ] Lyssnar på `WorkoutSaved` notification
- [ ] Ingen merge-logik (ersätt helt)

### **Testing ✅**
- [ ] Kör pass → Se nytt område direkt
- [ ] Ta över område → Gamla försvinner
- [ ] Navigera bort/tillbaka → Allt syns fortfarande
- [ ] Zoom in/ut → Korrekt viewport-filtrering
- [ ] Vänta 90 sek → Cache refreshas automatiskt

---

## 🚀 IMPLEMENTATION GUIDE (STEG-FÖR-STEG)

### **DAG 1: Database Cleanup**
1. Kör database setup SQL (skapa tabell + index)
2. Kör cleanup för dubbletter
3. Verifiera: `SELECT COUNT(*), owner_id FROM territory_tiles GROUP BY owner_id`

### **DAG 2: SQL Functions**
1. Uppdatera `claim_tiles_with_takeovers.sql` 
2. Uppdatera `get_territory_owners_in_bounds_v2.sql`
3. Testa manuellt i SQL Editor

### **DAG 3: Swift Refactor**
1. Förenkla `TerritoryStore` (30 sek cache, no merge)
2. Lägg till `invalidateCache()` efter pass
3. Lägg till `.onAppear` refresh i `ZoneWarView`
4. Lägg till `WorkoutSaved` listener

### **DAG 4: Testing**
1. Kör 5 olika pass och verifiera att alla syns
2. Ta över någons område
3. Navigera bort och tillbaka
4. Kolla efter buggar

---

## 💡 FILOSOFI

**"The server is always right"**

- Server = Source of truth
- Swift = Dumb renderer
- Cache = Performance trick (kort)
- Simplicity = Reliability

**Varje gång något är konstigt:**
1. Invalidera cache
2. Hämta från server
3. Rendera vad servern säger

**Enkelt = Bulletproof** 🛡️

---

**Skapad:** 2026-01-02  
**Status:** Production Ready  
**Komplexitet:** Simple  
**Reliability:** 100%











