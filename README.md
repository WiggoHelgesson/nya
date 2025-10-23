# up&down iOS App 📱💪

En modern fitness- och aktivitetsspårningsapp för iOS, byggd med SwiftUI.

## Funktioner

### 🔐 Autentisering
- **Skapa konto**: Registrera dig med namn, email och lösenord
- **Logga in**: Logga in med befintligt konto
- Clean UI med gradient bakgrund och validering

### 🏠 Hem-skärm
- Personlig hälsning
- Veckoöversikt med framstegscirkel
- Dagens aktiviteter med kaloriberäkning
- Dail tips för träning

### 🏃 Aktiviteter
- Se alla tidigare träningspass
- Filtrera efter tidsperiod (denna vecka, månad, alla)
- Statistik: totalt brända kalorier, total träning, genomsnitt
- Detaljerade aktivitetskort

### ▶️ Starta pass
- Startklocka för träningspass
- Välj aktivitetstyp (löpning, cykling, promenad, etc.)
- Live-statistik för brända kalorier
- Paus/starta funktionalitet

### ⭐ Belöningar
- Poängsystem för träning
- Olåsta och låsta belöningar
- Framstegsstaplar
- Motiverande badges (Bronze, Silver, Gold, etc.)

### 👤 Profil
- Användarinformation
- Träningsstatistik
- Inställningar (redigera profil, notifikationer, sekretess)
- Logga ut

## Projektstruktur

```
Views/
├── AuthenticationView.swift      # Login & Signup
├── MainTabView.swift            # Tab navigation
├── HomeView.swift               # Hem-skärm
├── ActivitiesView.swift         # Aktivitetslista
├── StartSessionView.swift       # Träningspass
├── RewardsView.swift            # Belöningar
└── ProfileView.swift            # Användarens profil

ViewModels/
└── AuthViewModel.swift          # Autentisering

Models/
├── User.swift                   # Användarmodell
├── Activity.swift               # Aktivitetsmodell
└── Reward.swift                 # Belöningsmodell

up_downApp.swift                 # App entry point
```

## Komma igång

### Krav
- iOS 15+
- Xcode 14+
- Swift 5.7+

### Installation

1. **Öppna projektet i Xcode**
   ```bash
   open riktiga/
   ```

2. **Välj simulatorn eller enhet**
   - Välj en iOS simulator från Xcode
   - Eller koppla en fysisk enhet

3. **Kör appen**
   - Tryck `Cmd + R` eller välj Product → Run

4. **Testa autentisering**
   - Skapa ett konto eller logga in
   - Använd en giltig email (ex: test@example.com)
   - Lösenord måste vara minst 6 tecken

## Design

- **Färgschema**: Blå gradient (från ljus till mörk blå)
- **Komponenter**: SwiftUI med modernt design
- **Animationer**: Smooth transitions och progress circles
- **Layout**: Tab-baserad navigation med floating action button

## Framtida förbättringar

- [ ] Backend API-integrering (Firebase, REST API)
- [ ] Core Data för lokal lagring
- [ ] Push-notifikationer
- [ ] Health Kit-integrering
- [ ] Dark mode support
- [ ] Grafer och detaljerad analys
- [ ] Social features (dela resultat, lagkamrater)
- [ ] Export funktionalitet

## Använda färger

- **Primär blå**: RGB(26, 153, 204) / #1a99cc
- **Sekundär blå**: RGB(51, 102, 230) / #3366e6
- **Grå**: iOS systemGray6
- **Accentfärger**: Röd för logout, grön för checkmark, orange för notifikationer

## Tips för utveckling

1. **Lägg till Core Data** för att spara aktiviteter lokalt
2. **Implementera Health Kit** för att integrera med iOS Hälsa-appen
3. **Lägg till Firebase** för backend och autentisering
4. **Skapa en backend API** för serverlagring
5. **Implementera push-notifikationer** för påminnelser
6. **Lägg till Dark Mode** för komfort vid kvälläxercise

## Licens

MIT License - Du är fri att använda och modifiera denna kod.

---

**Happy coding! 💪**
