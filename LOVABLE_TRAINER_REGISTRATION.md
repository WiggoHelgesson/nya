# Lovable: Tränare-registreringssida för Up&Down Coach

Skapa en sida på upanddowncoach.com där personliga tränare kan registrera sig och skapa sin profil. Profilen visas sedan i vår iOS-app under "Hitta tränare"-fliken.

---

## Supabase-projekt

```
URL: https://xebatkodviqgkpsbyuiv.supabase.co
Anon Key: eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9.eyJpc3MiOiJzdXBhYmFzZSIsInJlZiI6InhlYmF0a29kdmlxZ2twc2J5dWl2Iiwicm9sZSI6ImFub24iLCJpYXQiOjE3NDQzMTY2MzIsImV4cCI6MjA1OTg5MjYzMn0.e4W2ut1w_AHiQ_Uhi3HmEXdeGIe4eX-ZhgvIqU_ld6Q
```

---

## Databas-tabell: `trainer_profiles`

Tabellen finns redan i Supabase. Här är kolumnerna som tränaren ska kunna fylla i:

| Kolumn | Typ | Beskrivning |
|--------|-----|-------------|
| `id` | UUID (auto) | Primärnyckel, genereras automatiskt |
| `user_id` | UUID | Kopplas till auth.users.id |
| `name` | TEXT | Tränarens fullständiga namn |
| `description` | TEXT | Kort sammanfattning (visas i listan) |
| `bio` | TEXT | Längre beskrivning av tränaren |
| `hourly_rate` | INTEGER | Timpris i SEK (t.ex. 189) |
| `city` | TEXT | Stad (t.ex. "Göteborg") |
| `avatar_url` | TEXT | URL till profilbild (laddas upp till Supabase Storage) |
| `experience_years` | INTEGER | Antal års erfarenhet |
| `club_affiliation` | TEXT | Gym/klubb-tillhörighet |
| `latitude` | DOUBLE | Latitud (kan sättas via stad) |
| `longitude` | DOUBLE | Longitud (kan sättas via stad) |
| `handicap` | INTEGER | Sätt till 0 som default |
| `is_active` | BOOLEAN | Default false - sätts till true efter godkännande |
| `instagram_url` | TEXT | Instagram-profil URL |
| `facebook_url` | TEXT | Facebook-profil URL |
| `website_url` | TEXT | Personlig hemsida URL |
| `phone_number` | TEXT | Kontakttelefon |
| `contact_email` | TEXT | Kontakt-email |

---

## Funktionalitet

### 1. Landing Page

En snygg landningssida med:
- Rubrik: "Bli tränare på Up&Down Coach"
- Underrubrik: "Visa upp dig för tusentals aktiva användare i vår app"
- CTA-knapp: "Registrera dig som tränare"
- Fördelar/features:
  - "Nå ut till nya kunder"
  - "Visa din profil i appen"
  - "Inga dolda avgifter"
  - "Hantera din profil enkelt"

### 2. Registrering/Inloggning

Tränare ska kunna:
- Registrera sig med email + lösenord via Supabase Auth
- Logga in om de redan har ett konto
- Google Sign-In (valfritt, om det redan är konfigurerat)

### 3. Skapa/Redigera Tränarprofil

Ett formulär (flerstegs eller en sida) där tränaren fyller i:

**Steg 1 - Grundinfo:**
- Namn (obligatoriskt)
- Profilbild (ladda upp till Supabase Storage bucket `avatars`)
- Stad (obligatoriskt)
- Kort beskrivning (obligatoriskt, max 200 tecken)

**Steg 2 - Detaljer:**
- Längre bio/beskrivning
- Erfarenhet (antal år)
- Specialområden/klubbtillhörighet
- Timpris i SEK (obligatoriskt)

**Steg 3 - Kontakt & Sociala medier:**
- Kontakt-email (obligatoriskt)
- Telefonnummer
- Instagram URL
- Facebook URL
- Hemsida URL

### 4. Dashboard

Efter registrering ska tränaren ha en dashboard där de kan:
- Se sin profil som den ser ut i appen (preview)
- Redigera all information
- Ladda upp/byta profilbild
- Se status: "Väntar på godkännande" eller "Aktiv"

### 5. Bilduppladdning

- Ladda upp till Supabase Storage bucket `avatars`
- Generera en public URL
- Spara URL:en i `avatar_url`-kolumnen
- Max storlek: 5MB
- Format: JPG, PNG, WebP

---

## Supabase Storage Setup

Se till att bucket `avatars` finns (den borde redan finnas). Om inte:

```sql
INSERT INTO storage.buckets (id, name, public) 
VALUES ('avatars', 'avatars', true)
ON CONFLICT (id) DO NOTHING;
```

---

## Design

- Modern, ren design med vit bakgrund
- Använd Up&Down-loggan (kan laddas från appen eller läggas som asset)
- Primärfärg: Svart (#000000)
- Accent: Röd (#FF3B30) för CTA-knappar
- Typsnitt: System/Inter
- Responsiv - ska fungera på mobil och desktop
- Inspireras av Superprof.se:s tränarsidor

---

## TypeScript-kod (exempel)

### Skapa tränarprofil:

```typescript
const { data, error } = await supabase
  .from('trainer_profiles')
  .insert({
    user_id: user.id,
    name: formData.name,
    description: formData.description,
    bio: formData.bio,
    hourly_rate: formData.hourlyRate,
    city: formData.city,
    avatar_url: uploadedImageUrl,
    experience_years: formData.experienceYears,
    club_affiliation: formData.clubAffiliation,
    latitude: 0, // Can be set via geocoding
    longitude: 0,
    handicap: 0,
    is_active: false, // Requires admin approval
    instagram_url: formData.instagramUrl,
    facebook_url: formData.facebookUrl,
    website_url: formData.websiteUrl,
    phone_number: formData.phoneNumber,
    contact_email: formData.contactEmail,
  });
```

### Ladda upp profilbild:

```typescript
const fileExt = file.name.split('.').pop();
const filePath = `trainer-${user.id}.${fileExt}`;

const { error: uploadError } = await supabase.storage
  .from('avatars')
  .upload(filePath, file, { upsert: true });

const { data: { publicUrl } } = supabase.storage
  .from('avatars')
  .getPublicUrl(filePath);

// Save publicUrl as avatar_url
```

### Hämta egen profil:

```typescript
const { data: profile } = await supabase
  .from('trainer_profiles')
  .select('*')
  .eq('user_id', user.id)
  .single();
```

### Uppdatera profil:

```typescript
const { error } = await supabase
  .from('trainer_profiles')
  .update({
    name: formData.name,
    description: formData.description,
    // ... alla fält
  })
  .eq('user_id', user.id);
```

---

## Viktigt

- `is_active` ska alltid vara `false` vid skapande. En admin godkänner sedan profilen (sätter `is_active = true`) så att den syns i iOS-appen.
- Tränaren ska se tydligt om profilen är "aktiv" eller "väntar på godkännande"
- Validera att timpris är ett positivt heltal
- Validera URL-format för sociala medier
- Kontakt-email är obligatorisk

---

## Sidstruktur

```
/ (Landing page)
/login (Inloggning)
/register (Registrering)
/dashboard (Tränardashboard - kräver inloggning)
/dashboard/edit (Redigera profil)
/dashboard/preview (Förhandsvisning av profil)
```
