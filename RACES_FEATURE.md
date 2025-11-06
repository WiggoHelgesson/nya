# Tävlingar (Races) Feature

## Översikt
Användare kan nu markera vilka tävlingar (som Iron Man) de har genomfört och lägga till bilder/minnen från dessa tävlingar på sin profil.

## Funktionalitet

### Redigera Profil
- Ny "Tävlingar" sektion med horisontell scroll (under "Bestigning")
- Varje tävling visas som ett kort med:
  - Bild på tävlingen (rundade hörn)
  - Tävlingens namn
  - Kryssruta för att markera som genomförd
- Klicka på tävlingsbilden för att öppna detalj-sidan
- Klicka på kryssrutan för att lägga till/ta bort tävling

### Publik Profil
- "Tävlingar" sektion visas endast om användaren har genomfört minst en tävling
- Horisontell scroll med alla genomförda tävlingar
- Varje tävling visas med bild (rundade hörn) och namn
- Klicka för att se bilder/minnen från tävlingen

### Tävlings-detaljsida (RaceDetailView)
- Visar tävlingens stora bild och namn
- **För ägaren**:
  - Kan lägga till upp till 10 bilder från tävlingen
  - "Välj foton" knapp
  - Kan ta bort bilder (X-knapp i hörnet)
- **För alla**:
  - Se alla bilder i 2-kolumns rutnät (kvadratiska bilder)
  - Klicka på bild för fullskärmsvisning
  - Räknar antal minnen: "Minnen (X)"

## Databas Schema

### profiles tabell - ny kolumn
```sql
ALTER TABLE profiles ADD COLUMN completed_races text[] DEFAULT '{}';
```

### race_memories tabell
```sql
CREATE TABLE race_memories (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    user_id UUID NOT NULL REFERENCES profiles(id) ON DELETE CASCADE,
    race_id TEXT NOT NULL,
    image_url TEXT NOT NULL,
    created_at TIMESTAMPTZ DEFAULT NOW()
);
```

Kör SQL-filen: `RACE_MEMORIES_SQL.sql` i din Supabase databas

### Row Level Security (RLS)
- Alla kan se alla minnen
- Användare kan bara lägga till sina egna minnen
- Användare kan bara ta bort sina egna minnen

## Tekniska Detaljer

### Modeller
- **Race**: `id`, `name`, `imageName`
- **RaceMemory**: `id`, `userId`, `raceId`, `imageUrl`, `createdAt`
- **User.completedRaces**: Array av tävlings-ID:n

### Tävlingar
För närvarande finns en tävling:
- **Iron Man** (bild: "26")

Fler tävlingar kan enkelt läggas till i `Race.all` array i `User.swift`.

### Vyer
- **RaceDetailView**: Visar tävling med galleri av minnen
  - Identisk funktionalitet som MountainDetailView
  - 2-kolumns rutnät för bilder
  - Fullskärmsvisning
  - Borttagning av bilder (endast ägare)
- **EditProfileView**: `RaceSelectionCard` för att välja tävlingar
- **UserProfileView**: Visar genomförda tävlingar på profilen

### Storage
Bilder lagras i Supabase storage bucket "avatars" med struktur:
```
{userId}/races/{raceId}/{uuid}.jpg
```

## Användningsflöde
1. Användare besöker "Redigera profil"
2. Scrollar ner till "Tävlingar" sektionen
3. Kryssar i "Iron Man" som genomförd
4. Klickar på Iron Man-bilden
5. Väljer "Välj foton" och laddar upp bilder från tävlingen
6. Bilder visas i 2-kolumns rutnät
7. Sparar profilen
8. "Tävlingar" sektionen visas nu på den offentliga profilen

## Design
- Samma design som "Bestigning" funktionen
- Rundade hörn på alla bilder
- Grön checkmark när vald
- 2-kolumns rutnät för minnen (kvadratiska bilder)
- Fullskärmsvisning med mörk bakgrund

## Framtida Förbättringar
- Lägg till fler tävlingar (Marathon, Ultra Trail, Triathlon, etc.)
- Datum för när tävlingen genomfördes
- Officiell tid/resultat från tävlingen
- Delningsfunktion för tävlingsbilder
- Länk till tävlingens officiella webbplats
