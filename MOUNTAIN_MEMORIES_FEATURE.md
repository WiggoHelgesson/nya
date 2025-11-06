# Berg-minnen (Mountain Memories) Feature

## Översikt
Användare kan nu lägga till och visa bilder/minnen från sina bergbestigningar. Varje berg har sin egen bildgalleri där användaren kan samla sina resefoton.

## Funktionalitet

### För Berg-ägare (Redigera Profil)
1. Klicka på bergbilden (inte kryssikonen) i "Redigera profil"
2. Navigerar till MountainDetailView
3. Kan lägga till upp till 10 bilder åt gången från kamerarullen
4. Bilder laddas upp till Supabase storage och sparas i databasen
5. Se alla sina uppladdade minnen i ett 3-kolumns rutnät

### För Alla (Offentlig Profil)
1. Besök en användares profil
2. Se deras bestigning berg i "Bestigning" sektionen
3. Klicka på ett berg för att se alla bilder/minnen från den resan
4. Endast visning - inga uppladdningsknappar för andra användare

## Databas Schema

### mountain_memories Tabell
```sql
CREATE TABLE mountain_memories (
    id TEXT PRIMARY KEY,
    user_id TEXT NOT NULL REFERENCES profiles(id) ON DELETE CASCADE,
    mountain_id TEXT NOT NULL,
    image_url TEXT NOT NULL,
    created_at TIMESTAMPTZ DEFAULT NOW()
);
```

Kör SQL-filen: `MOUNTAIN_MEMORIES_SQL.sql` i din Supabase databas

### Row Level Security (RLS)
- Alla kan se alla minnen
- Användare kan bara lägga till sina egna minnen
- Användare kan bara ta bort sina egna minnen

## Tekniska Detaljer

### Modeller
- **MountainMemory**: `id`, `userId`, `mountainId`, `imageUrl`, `createdAt`

### Vyer
- **MountainDetailView**: Visar berg med galleri av minnen
  - `isOwner`: Bestämmer om uppladdningsknappar ska visas
  - 3-kolumns rutnät för bilder
  - PhotosPicker för att välja upp till 10 bilder
  - Progress indicator under uppladdning

### Navigation
- **EditProfileView**: NavigationLink från bergbild till MountainDetailView (isOwner: true)
- **UserProfileView**: NavigationLink från bergbild till MountainDetailView (isOwner: baserat på userId)

### Storage
Bilder lagras i Supabase storage bucket "avatars" med struktur:
```
{userId}/mountains/{mountainId}/{uuid}.jpg
```

## UI/UX Features
- Rundade hörn på alla bergbilder (RoundedRectangle)
- Laddningsindikator under bilduppladdning
- Tomt tillstånd med ikon och text när inga minnen finns
- Räknar antal minnen: "Minnen (X)"
- Felhantering med alert-dialog

## Användningsflöde
1. Användare besöker "Redigera profil"
2. Kryssar i Kebnekaise som bestigen
3. Klickar på Kebnekaise-bilden
4. Väljer "Välj foton" och laddar upp 3 bilder från resan
5. Bilder visas i galleriet
6. Sparar profilen
7. Vem som helst kan nu besöka profilen och se bilderna

## Framtida Förbättringar
- Ta bort enskilda bilder
- Fullskärmsvisning av bilder
- Bildtexter/beskrivningar
- Delningsfunktion
- Fler berg att välja mellan
