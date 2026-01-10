# 🔒 SÄKER TEST AV FORCE UPDATE - STEG FÖR STEG

## ⚠️ VIKTIGT: Följ dessa steg i exakt denna ordning!

---

## 📝 Steg 1: KOLLA NUVARANDE INSTÄLLNINGAR

**Kör i Supabase SQL Editor:**
```sql
-- Öppna: QUICK_check_current_settings.sql
-- Kör hela skriptet
```

**📸 SPARA/ANTECKNA RESULTATET!**
Du behöver dessa värden för att återställa:
- `min_version`: ___________
- `force_update`: ___________
- `update_message_sv`: ___________

---

## 🧪 Steg 2: AKTIVERA TEST-FORCE UPDATE

**Kör i Supabase SQL Editor:**
```sql
-- Öppna: TEST_force_update_104.sql
-- Kör hela skriptet
```

**Resultat:**
- ✅ `min_version` → `104.0`
- ✅ `force_update` → `true`
- ✅ Meddelande uppdaterat

---

## 📱 Steg 3: TESTA APPEN I XCODE

**Version 103.0 (nuvarande):**
1. Öppna Xcode
2. Bygg och kör appen (`Cmd + R`)
3. **FÖRVÄNTAT:**
   - 🟢 Splash screen visas (2 sek)
   - 🔴 **Force update-vy blockerar appen**
   - 📱 Meddelande visas
   - 🔘 "Uppdatera nu"-knapp

**Debug i Console:**
Leta efter:
```
📱 Version check: current=103.0, min=104.0, force=true
```

---

## 🔄 Steg 4: ÅTERSTÄLL TILL URSPRUNGLIGA INSTÄLLNINGAR

**⚠️ VIKTIGT: Kör detta direkt efter testet!**

**Kör i Supabase SQL Editor:**
```sql
-- Öppna: RESTORE_force_update.sql
-- INNAN du kör: Kontrollera att värdena matchar steg 1
-- Kör hela skriptet
```

**Resultat:**
- ✅ `min_version` → `103.0` (återställd)
- ✅ `force_update` → `false` (AVSTÄNGT)
- ✅ Alla användare kan använda appen normalt

---

## ✅ Steg 5: VERIFIERA ÅTERSTÄLLNING

**Kör i Supabase SQL Editor:**
```sql
-- Öppna: QUICK_check_current_settings.sql igen
-- Kör hela skriptet
```

**Kontrollera:**
- ✅ `min_version` = samma som i steg 1
- ✅ `force_update` = `false`

---

## 🚀 När du är redo för RIKTIG release:

### 1. Uppdatera app-version i Xcode
```
MARKETING_VERSION: 103.0 → 104.0
```

### 2. Bygg och testa version 104
```
Appen ska fungera normalt (ingen force update)
```

### 3. Ladda upp till App Store Connect

### 4. När appen är godkänd, aktivera force update:
```sql
UPDATE public.app_config
SET 
    min_version = '104.0',
    force_update = true,
    update_message_sv = 'En ny version av Up&Down finns tillgänglig. Uppdatera för att fortsätta använda appen! 💪'
WHERE id = 1;
```

---

## 🆘 Om något går fel:

### Problemet: Force update visas inte i testet
```sql
-- Kör detta för att felsöka:
SELECT * FROM public.app_config WHERE id = 1;

-- Kontrollera:
-- min_version = '104.0'
-- force_update = true
```

### Problemet: Glömde återställa efter test
```sql
-- Kör RESTORE_force_update.sql omedelbart
```

### Problemet: Användare rapporterar att appen är blockerad
```sql
-- SNABB FIX: Stäng av force update
UPDATE public.app_config 
SET force_update = false 
WHERE id = 1;
```

---

## 📋 Checklista:

- [ ] Steg 1: Kollat och sparat nuvarande inställningar
- [ ] Steg 2: Aktiverat test-force update
- [ ] Steg 3: Testat i Xcode (version 103)
- [ ] Steg 4: **ÅTERSTÄLLT** efter test
- [ ] Steg 5: Verifierat återställning

**⚠️ GLÖM INTE ATT ÅTERSTÄLLA EFTER TESTET! ⚠️**











