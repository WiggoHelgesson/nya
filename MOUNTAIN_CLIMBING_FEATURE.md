# Bestigning (Mountain Climbing) Feature

## Översikt
Användare kan nu markera vilka berg de har bestigt på sin profil.

## Databas Schema
Lägg till följande kolumn i `profiles` tabellen:

```sql
ALTER TABLE profiles ADD COLUMN climbed_mountains text[] DEFAULT '{}';
```

## Funktionalitet

### Redigera Profil
- Ny "Bestigning" sektion med horisontell scroll
- Varje berg visas som ett kort med:
  - Bild på berget (rundade hörn)
  - Bergets namn
  - Kryssruta för att markera som bestigen
- Klicka på kryssrutan för att lägga till/ta bort berg

### Publik Profil
- Bestigning sektion visas endast om användaren har bestigt minst ett berg
- Horisontell scroll med alla bestigning berg
- Varje berg visas med bild (rundade hörn) och namn

## Berg
För närvarande finns ett berg:
- **Kebnekaise** (bild: "25")

Fler berg kan enkelt läggas till i `Mountain.all` array i `User.swift`.

## Tekniska Detaljer

### Modeller
- `User.climbedMountains: [String]` - Array av berg-ID:n
- `Mountain` struct med ID, namn och bildnamn
- `Mountain.all` - Statisk array med alla tillgängliga berg

### Vyer
- `EditProfileView` - `MountainSelectionCard` för att välja berg
- `UserProfileView` - Visar bestigning berg på profilen

### Databas Synkning
- Sparas till `climbed_mountains` kolumnen i Supabase
- Hanterar fallback om kolumnen inte finns (samma som PB kolumner)

## Bildresurser
- Bild "25" används för Kebnekaise
- Alla bergbilder har rundade hörn (RoundedRectangle med cornerRadius)
