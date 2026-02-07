# Lovable: Hämta klientens vikt och progressbilder

Som tränare vill du kunna se klientens:
1. **Kroppsvikt** (nuvarande och målvikt)
2. **Progressbilder** med vikt och datum

---

## 1. Kroppsvikt

### Tabell: `profiles`

Klientens vikt sparas i `profiles`-tabellen.

| Kolumn | Typ | Beskrivning |
|--------|-----|-------------|
| `weight_kg` | DECIMAL | Nuvarande vikt i kg |
| `target_weight` | DECIMAL | Målvikt i kg |
| `height_cm` | INT | Längd i cm |
| `gender` | TEXT | "male" / "female" / "other" |
| `birth_date` | DATE | Födelsedatum |

### SQL Query - Hämta klientens profildata

```sql
SELECT 
  id,
  username,
  weight_kg,
  target_weight,
  height_cm,
  gender,
  birth_date,
  avatar_url
FROM profiles
WHERE id = '<client_user_id>';
```

### TypeScript-kod

```typescript
async function getClientProfile(clientId: string) {
  const { data, error } = await supabase
    .from('profiles')
    .select(`
      id,
      username,
      weight_kg,
      target_weight,
      height_cm,
      gender,
      birth_date,
      avatar_url
    `)
    .eq('id', clientId)
    .single();

  return data;
}

// Användning
const profile = await getClientProfile('client-uuid');
console.log(`Vikt: ${profile.weight_kg} kg`);
console.log(`Målvikt: ${profile.target_weight} kg`);
console.log(`Längd: ${profile.height_cm} cm`);
```

---

## 2. Progressbilder

### Tabell: `progress_photos`

| Kolumn | Typ | Beskrivning |
|--------|-----|-------------|
| `id` | TEXT | Unikt ID |
| `user_id` | UUID | Klientens user ID |
| `image_url` | TEXT | URL till bilden |
| `weight_kg` | DECIMAL | Vikten vid fototillfället |
| `photo_date` | DATE | Datum för fotot |
| `created_at` | TIMESTAMP | När posten skapades |

### Storage bucket: `progress-photos`

Bilderna lagras i Supabase Storage under:
```
progress-photos/{user_id}/{filename}.jpg
```

### SQL Query - Hämta klientens progressbilder

```sql
SELECT 
  id,
  image_url,
  weight_kg,
  photo_date,
  created_at
FROM progress_photos
WHERE user_id = '<client_user_id>'
ORDER BY photo_date DESC;
```

### TypeScript-kod

```typescript
interface ProgressPhoto {
  id: string;
  user_id: string;
  image_url: string;
  weight_kg: number;
  photo_date: string;  // "2024-02-01"
  created_at: string;
}

async function getClientProgressPhotos(clientId: string): Promise<ProgressPhoto[]> {
  const { data, error } = await supabase
    .from('progress_photos')
    .select('*')
    .eq('user_id', clientId)
    .order('photo_date', { ascending: false });

  if (error) throw error;
  return data || [];
}

// Användning
const photos = await getClientProgressPhotos('client-uuid');

photos.forEach(photo => {
  console.log(`Datum: ${photo.photo_date}`);
  console.log(`Vikt: ${photo.weight_kg} kg`);
  console.log(`Bild: ${photo.image_url}`);
});
```

---

## 3. RLS-policy för coach-åtkomst

**OBS!** För att tränaren ska kunna se klientens progressbilder behöver ni lägga till en RLS-policy:

```sql
-- Coaches can view their clients' progress photos
CREATE POLICY "Coaches can view client progress photos" ON progress_photos
FOR SELECT TO authenticated
USING (
  EXISTS (
    SELECT 1 FROM coach_clients
    WHERE coach_clients.coach_id = auth.uid()
      AND coach_clients.client_id = progress_photos.user_id
      AND coach_clients.status = 'active'
  )
);
```

Samma för profiles (om det inte redan finns):

```sql
-- Coaches can view their clients' profiles
CREATE POLICY "Coaches can view client profiles" ON profiles
FOR SELECT TO authenticated
USING (
  id = auth.uid()  -- User can see own profile
  OR EXISTS (
    SELECT 1 FROM coach_clients
    WHERE coach_clients.coach_id = auth.uid()
      AND coach_clients.client_id = profiles.id
      AND coach_clients.status = 'active'
  )
);
```

---

## 4. Komplett exempel - Coach Dashboard

```typescript
interface ClientOverview {
  profile: {
    id: string;
    username: string;
    weight_kg: number | null;
    target_weight: number | null;
    height_cm: number | null;
  };
  progressPhotos: ProgressPhoto[];
  weightChange: number | null;  // Kg förändring
}

async function getClientOverview(clientId: string): Promise<ClientOverview> {
  // Hämta profil
  const { data: profile } = await supabase
    .from('profiles')
    .select('id, username, weight_kg, target_weight, height_cm')
    .eq('id', clientId)
    .single();

  // Hämta progressbilder
  const { data: photos } = await supabase
    .from('progress_photos')
    .select('*')
    .eq('user_id', clientId)
    .order('photo_date', { ascending: false });

  // Beräkna viktförändring (första vs senaste foto)
  let weightChange = null;
  if (photos && photos.length >= 2) {
    const latestWeight = photos[0].weight_kg;
    const firstWeight = photos[photos.length - 1].weight_kg;
    weightChange = latestWeight - firstWeight;
  }

  return {
    profile: profile!,
    progressPhotos: photos || [],
    weightChange,
  };
}
```

---

## 5. UI-komponent för viktgraf

```tsx
import { LineChart, Line, XAxis, YAxis, Tooltip, ResponsiveContainer } from 'recharts';

function ClientWeightChart({ photos }: { photos: ProgressPhoto[] }) {
  // Sortera efter datum (äldst först)
  const chartData = [...photos]
    .sort((a, b) => new Date(a.photo_date).getTime() - new Date(b.photo_date).getTime())
    .map(photo => ({
      date: photo.photo_date,
      weight: photo.weight_kg,
    }));

  return (
    <div className="h-64">
      <ResponsiveContainer width="100%" height="100%">
        <LineChart data={chartData}>
          <XAxis dataKey="date" />
          <YAxis domain={['auto', 'auto']} />
          <Tooltip />
          <Line 
            type="monotone" 
            dataKey="weight" 
            stroke="#000" 
            strokeWidth={2}
            dot={{ fill: '#000' }}
          />
        </LineChart>
      </ResponsiveContainer>
    </div>
  );
}
```

---

## 6. Sammanfattning

| Data | Tabell | Viktiga kolumner |
|------|--------|------------------|
| Nuvarande vikt | `profiles` | `weight_kg` |
| Målvikt | `profiles` | `target_weight` |
| Längd | `profiles` | `height_cm` |
| Progressbilder | `progress_photos` | `image_url`, `weight_kg`, `photo_date` |
| Bildlagring | Storage bucket | `progress-photos/{user_id}/` |

**Viktigt:** Glöm inte att lägga till RLS-policies så att tränaren har behörighet att se klientens data!
