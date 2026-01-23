# 🚀 FORCE UPDATE TILL VERSION 104 - TESTPLAN

## 📋 Förberedelser

### 1. Uppdatera Xcode-projektet ✅
- [x] `MARKETING_VERSION` ändrad från `103.0` till `104.0` i `project.pbxproj`

### 2. Kolla databasen
```sql
-- Kör check_app_config.sql i Supabase SQL Editor
```

### 3. Aktivera force update
```sql
-- Kör force_update_to_104.sql i Supabase SQL Editor
```

---

## 🧪 Testa Force Update-systemet

### Test 1: Verifiera att version 104 INTE får force update
**Förväntat:** App startar normalt utan force update-meddelande

1. Öppna projektet i Xcode
2. Verifiera att version är `104.0` i project settings
3. Bygg och kör appen i simulator/device
4. **Resultat:** Appen ska starta normalt och visa splash screen → huvudvyn

---

### Test 2: Simulera version 103 (ska få force update)
**Förväntat:** App blockeras med force update-meddelande

1. Öppna `project.pbxproj`
2. Ändra tillfälligt `MARKETING_VERSION` till `103.0`
3. Bygg och kör appen
4. **Resultat:** 
   - ✅ Splash screen visas i 2 sekunder
   - ✅ Force update-vy visas (blå/vit design)
   - ✅ Meddelande: *"En ny version av Up&Down finns tillgänglig..."*
   - ✅ Knapp: "Uppdatera nu"
   - ✅ Appen är blockerad (kan inte komma till huvudvyn)

5. Tryck på "Uppdatera nu"
6. **Resultat:** App Store öppnas (eller visar felmeddelande om länk inte funkar i simulator)

7. Återställ `MARKETING_VERSION` till `104.0`

---

### Test 3: Simulera version 102 (äldre version)
**Förväntat:** Samma som Test 2

1. Ändra `MARKETING_VERSION` till `102.0`
2. Bygg och kör
3. **Resultat:** Force update-vy ska visas

---

### Test 4: Stäng av force update (för att släppa igenom alla)

```sql
UPDATE public.app_config
SET 
    force_update = false,
    updated_at = NOW()
WHERE id = 1;
```

1. Kör SQL ovan
2. Bygg appen med version `103.0`
3. Kör appen
4. **Resultat:** Appen ska starta normalt (ingen force update)

---

## 🐛 Felsökning

### Problem: Force update visas inte
**Möjliga orsaker:**
1. ✅ Databasen är inte uppdaterad - kör `force_update_to_104.sql`
2. ✅ `force_update` är `false` - sätt till `true` i databasen
3. ✅ Appen cachar gamla värden - starta om simulatorn helt
4. ✅ Version-jämförelsen är fel - kolla logs i Xcode console

**Debug i Xcode Console:**
Leta efter dessa loggar:
```
📱 Version check: current=103.0, min=104.0, force=true
```

### Problem: Force update visas för version 104
**Möjliga orsaker:**
1. ✅ `min_version` i databasen är för hög (över 104.0)
2. ✅ Appen läser fel version från `Info.plist`

**Fix:**
```sql
-- Sätt min_version till 104.0
UPDATE public.app_config SET min_version = '104.0' WHERE id = 1;
```

### Problem: App Store-länk fungerar inte
**Orsak:** Simulatorn kan ha problem med externa länkar

**Test på riktig enhet:** Deploy till TestFlight eller fysisk enhet

---

## ✅ Checklista innan release till App Store

- [ ] Version i Xcode är `104.0`
- [ ] Force update är aktiverat i databasen (`force_update = true`, `min_version = 104.0`)
- [ ] Testat att version 103 får force update
- [ ] Testat att version 104 INTE får force update
- [ ] App Store-länk fungerar: `https://apps.apple.com/app/id6744919845`
- [ ] Meddelande är korrekt på svenska
- [ ] Byggt och arkiverat för release
- [ ] Laddat upp till App Store Connect

---

## 📊 Förväntad användarbeteende

### Användare med version 103.0 eller lägre:
1. Öppnar appen
2. Ser splash screen
3. **BLOCKERAS** av force update-vy
4. Måste uppdatera via App Store
5. Efter uppdatering: appen fungerar normalt

### Användare med version 104.0:
1. Öppnar appen
2. Ser splash screen
3. Appen startar normalt
4. Ingen force update

---

## 🔧 SQL för snabb kontroll

```sql
-- Visa nuvarande status
SELECT min_version, force_update, updated_at 
FROM public.app_config 
WHERE id = 1;

-- Aktivera force update till 104
UPDATE public.app_config 
SET min_version = '104.0', force_update = true 
WHERE id = 1;

-- Stäng av force update
UPDATE public.app_config 
SET force_update = false 
WHERE id = 1;
```

---

## 💡 Tips

- Force update är **permanent tills du stänger av det** i databasen
- Du kan ändra meddelandet när som helst genom att uppdatera `update_message_sv`
- Systemet fungerar även för **oauthenticerade användare** (innan login)
- Version-jämförelsen är komponent-baserad: `104.0 > 103.5 > 103.0 > 102.9`















