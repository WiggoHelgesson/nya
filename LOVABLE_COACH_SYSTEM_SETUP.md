# Lovable: Coach-system för schemalagda pass och dagliga tips

## Översikt

iOS-appen har uppdaterats med en ny Coach-flik som visar:
1. **Dagens träning** - Vilka pass tränaren har tilldelat för den valda veckodagen
2. **Tips från tränaren** - Ett dagligt meddelande från tränaren för varje veckodag
3. **Mitt program** - Information om det aktiva programmet

För att detta ska fungera behöver Lovable-plattformen uppdateras så att tränare kan schemalägga specifika pass på specifika veckodagar och skriva dagliga tips.

---

## 1. Databas-ändringar

### 1.1 Uppdatera `coach_programs`-tabellen

Lägg till en ny kolumn för dagliga tips:

```sql
ALTER TABLE coach_programs 
ADD COLUMN daily_tips TEXT[] DEFAULT ARRAY[NULL, NULL, NULL, NULL, NULL, NULL, NULL]::TEXT[];
```

**Format:** Array med 7 element där:
- Index 0 = Måndag
- Index 1 = Tisdag
- Index 2 = Onsdag
- Index 3 = Torsdag
- Index 4 = Fredag
- Index 5 = Lördag
- Index 6 = Söndag

**Exempel:**
```json
["Fokusera på uppvärmning idag", "Vila är viktigt", null, "Push-dag!", null, "Cardio idag", null]
```

### 1.2 Uppdatera `program_data` JSON-strukturen

I `program_data`-kolumnen (JSONB), lägg till `scheduled_days` för varje rutin:

```json
{
  "routines": [
    {
      "id": "uuid-1",
      "title": "Ben & Rygg",
      "note": "Fokusera på teknik",
      "scheduled_days": [0, 3],
      "exercises": [...]
    },
    {
      "id": "uuid-2", 
      "title": "Bröst & Axlar",
      "note": "Tungt idag",
      "scheduled_days": [1, 4],
      "exercises": [...]
    },
    {
      "id": "uuid-3",
      "title": "Armar & Core",
      "note": null,
      "scheduled_days": [2, 5],
      "exercises": [...]
    }
  ]
}
```

**Format för `scheduled_days`:**
- Array av heltal (integers)
- 0 = Måndag
- 1 = Tisdag
- 2 = Onsdag
- 3 = Torsdag
- 4 = Fredag
- 5 = Lördag
- 6 = Söndag

**Exempel:**
- `[0, 3]` = Måndag och Torsdag
- `[1, 2, 4]` = Tisdag, Onsdag och Fredag
- `null` eller saknas = Visas alla dagar (fallback)

---

## 2. UI-ändringar i Lovable (Coach Dashboard)

### 2.1 Program-redigering - Schemalägg pass

När en tränare skapar/redigerar ett program, lägg till möjligheten att välja vilka veckodagar varje rutin ska köras:

```tsx
// Exempel-komponent för att välja dagar
const DayScheduler = ({ routine, onUpdate }) => {
  const days = ['Mån', 'Tis', 'Ons', 'Tor', 'Fre', 'Lör', 'Sön'];
  const [selectedDays, setSelectedDays] = useState(routine.scheduled_days || []);

  const toggleDay = (index: number) => {
    const newDays = selectedDays.includes(index)
      ? selectedDays.filter(d => d !== index)
      : [...selectedDays, index].sort();
    setSelectedDays(newDays);
    onUpdate({ ...routine, scheduled_days: newDays });
  };

  return (
    <div className="flex gap-2">
      {days.map((day, index) => (
        <button
          key={index}
          onClick={() => toggleDay(index)}
          className={`px-3 py-2 rounded ${
            selectedDays.includes(index) 
              ? 'bg-black text-white' 
              : 'bg-gray-200 text-gray-600'
          }`}
        >
          {day}
        </button>
      ))}
    </div>
  );
};
```

### 2.2 Dagliga tips-editor

Lägg till en sektion där tränaren kan skriva tips för varje veckodag:

```tsx
const DailyTipsEditor = ({ program, onUpdate }) => {
  const days = ['Måndag', 'Tisdag', 'Onsdag', 'Torsdag', 'Fredag', 'Lördag', 'Söndag'];
  const [tips, setTips] = useState(program.daily_tips || Array(7).fill(null));

  const updateTip = (index: number, value: string) => {
    const newTips = [...tips];
    newTips[index] = value || null;
    setTips(newTips);
    onUpdate({ ...program, daily_tips: newTips });
  };

  return (
    <div className="space-y-4">
      <h3 className="font-bold">Dagliga tips till klienten</h3>
      {days.map((day, index) => (
        <div key={index} className="flex flex-col gap-1">
          <label className="text-sm font-medium">{day}</label>
          <textarea
            value={tips[index] || ''}
            onChange={(e) => updateTip(index, e.target.value)}
            placeholder={`Tips för ${day.toLowerCase()}...`}
            className="border rounded p-2"
            rows={2}
          />
        </div>
      ))}
    </div>
  );
};
```

---

## 3. API-ändringar

### 3.1 Hämta program med daily_tips

Se till att `daily_tips` returneras när iOS-appen hämtar tilldelade program:

```sql
-- Exempel på query som iOS-appen använder
SELECT 
  cpa.*,
  cp.id, cp.title, cp.note, cp.program_data, cp.daily_tips
FROM coach_program_assignments cpa
JOIN coach_programs cp ON cpa.program_id = cp.id
WHERE cpa.client_id = $1 AND cpa.status = 'active';
```

### 3.2 Uppdatera program-funktionen

När tränaren sparar ett program, inkludera `scheduled_days` i program_data och `daily_tips`:

```typescript
// Exempel: Spara program
const saveProgram = async (programId: string, data: {
  title: string;
  routines: Array<{
    id: string;
    title: string;
    note?: string;
    scheduled_days: number[];
    exercises: Exercise[];
  }>;
  daily_tips: (string | null)[];
}) => {
  const { error } = await supabase
    .from('coach_programs')
    .update({
      title: data.title,
      program_data: { routines: data.routines },
      daily_tips: data.daily_tips
    })
    .eq('id', programId);
};
```

---

## 4. iOS-appens förväntade dataformat

### 4.1 CoachProgram (Swift-modell)

```swift
struct CoachProgram: Codable {
    let id: String
    let coachId: String          // "coach_id"
    let title: String
    let note: String?
    let durationType: String     // "duration_type"
    let durationWeeks: Int?      // "duration_weeks"
    let programData: ProgramData // "program_data"
    let createdAt: String        // "created_at"
    let dailyTips: [String?]?    // "daily_tips" - Array med 7 element
}
```

### 4.2 ProgramRoutine (Swift-modell)

```swift
struct ProgramRoutine: Codable {
    let id: String
    let name: String             // eller "title"
    let note: String?
    let exercises: [ProgramExercise]
    let scheduledDays: [Int]?    // "scheduled_days" - t.ex. [0, 2, 4]
}
```

---

## 5. Sammanfattning

| Fält | Plats | Format | Beskrivning |
|------|-------|--------|-------------|
| `daily_tips` | coach_programs-tabellen | TEXT[] med 7 element | Tips för varje veckodag |
| `scheduled_days` | program_data.routines[] | INT[] | Vilka dagar rutinen körs |

### Veckodag-mapping:
| Index | Dag |
|-------|-----|
| 0 | Måndag |
| 1 | Tisdag |
| 2 | Onsdag |
| 3 | Torsdag |
| 4 | Fredag |
| 5 | Lördag |
| 6 | Söndag |

---

## 6. Exempel på komplett program-objekt

```json
{
  "id": "abc-123",
  "coach_id": "coach-456",
  "title": "4-dagars styrkeprogram",
  "note": "Fokus på hypertrofi",
  "duration_type": "weeks",
  "duration_weeks": 8,
  "daily_tips": [
    "Måndag = Push-dag! Fokusera på bröst och axlar.",
    "Vila och återhämtning idag.",
    "Ben-dag! Glöm inte uppvärmning.",
    null,
    "Rygg och biceps idag. Kör hårt!",
    "Lätt cardio om du känner för det.",
    "Total vila. Ät bra och sov ordentligt."
  ],
  "program_data": {
    "routines": [
      {
        "id": "routine-1",
        "title": "Push (Bröst/Axlar/Triceps)",
        "note": "Start med compound-övningar",
        "scheduled_days": [0],
        "exercises": [...]
      },
      {
        "id": "routine-2", 
        "title": "Ben",
        "note": "Fokus på knäböj-teknik",
        "scheduled_days": [2],
        "exercises": [...]
      },
      {
        "id": "routine-3",
        "title": "Pull (Rygg/Biceps)",
        "note": null,
        "scheduled_days": [4],
        "exercises": [...]
      }
    ]
  },
  "created_at": "2025-02-01T10:00:00Z"
}
```

---

## Kontakt

Vid frågor om implementationen, kontakta iOS-teamet.
