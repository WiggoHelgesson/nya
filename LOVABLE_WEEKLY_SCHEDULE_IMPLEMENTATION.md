# Lovable: Implementera Veckoschema för Coach-Program

## Översikt

När en tränare tilldelar ett program till en klient behöver iOS-appen veta:
1. **Vilka pass som ska köras vilka dagar** (`scheduledDays` per rutin)
2. **Dagliga tips från tränaren** (`daily_tips` - ett per veckodag)

iOS-appen visar sedan "Dagens träning" baserat på vilken veckodag det är.

---

## 1. Databasschema

### Tabell: `coach_programs`

```sql
-- Lägg till daily_tips kolumn om den saknas
ALTER TABLE coach_programs 
ADD COLUMN IF NOT EXISTS daily_tips TEXT[] DEFAULT ARRAY[NULL, NULL, NULL, NULL, NULL, NULL, NULL]::TEXT[];
```

| Kolumn | Typ | Beskrivning |
|--------|-----|-------------|
| `id` | UUID | Program-ID |
| `coach_id` | UUID | Tränarens user ID |
| `title` | TEXT | Programmets namn |
| `note` | TEXT | Programbeskrivning |
| `duration_type` | TEXT | `'unlimited'` eller `'weeks'` |
| `duration_weeks` | INT | Antal veckor (om weeks) |
| `program_data` | JSONB | **Se format nedan** |
| `daily_tips` | TEXT[] | **Array med 7 element, ett per veckodag** |
| `created_at` | TIMESTAMP | Skapad |
| `updated_at` | TIMESTAMP | Uppdaterad |

### Tabell: `coach_program_assignments`

| Kolumn | Typ | Beskrivning |
|--------|-----|-------------|
| `id` | UUID | Assignment ID |
| `coach_id` | UUID | Tränarens user ID |
| `client_id` | UUID | Klientens user ID |
| `program_id` | UUID | FK till coach_programs |
| `status` | TEXT | `'active'`, `'paused'`, `'completed'` |
| `start_date` | DATE | När programmet startar |
| `assigned_at` | TIMESTAMP | När det tilldelades |

---

## 2. Veckodag-mapping (KRITISKT!)

**Både Lovable och iOS MÅSTE använda samma mapping:**

| Index | Dag |
|-------|-----|
| **0** | Måndag |
| **1** | Tisdag |
| **2** | Onsdag |
| **3** | Torsdag |
| **4** | Fredag |
| **5** | Lördag |
| **6** | Söndag |

**Exempel:** Om en rutin ska köras måndag och torsdag → `scheduledDays: [0, 3]`

---

## 3. program_data Format (JSONB)

```json
{
  "routines": [
    {
      "id": "uuid-för-rutin-1",
      "title": "Push (Bröst/Axlar/Triceps)",
      "note": "Fokusera på compound-övningar först",
      "scheduledDays": [0, 3],
      "exercises": [
        {
          "id": "uuid-för-övning",
          "exerciseId": "0001",
          "exerciseName": "Bänkpress",
          "exerciseImage": "0001",
          "muscleGroup": "chest",
          "note": "Kontrollerad negativ",
          "sets": [
            { "id": "set-1", "reps": 8, "weight": 80 },
            { "id": "set-2", "reps": 8, "weight": 80 },
            { "id": "set-3", "reps": 8, "weight": 75 }
          ]
        },
        {
          "id": "uuid-för-övning-2",
          "exerciseId": "0025",
          "exerciseName": "Axelpress",
          "exerciseImage": "0025",
          "muscleGroup": "shoulders",
          "note": null,
          "sets": [
            { "id": "set-1", "reps": 10, "weight": 40 },
            { "id": "set-2", "reps": 10, "weight": 40 },
            { "id": "set-3", "reps": 10, "weight": 40 }
          ]
        }
      ]
    },
    {
      "id": "uuid-för-rutin-2",
      "title": "Pull (Rygg/Biceps)",
      "note": null,
      "scheduledDays": [1, 4],
      "exercises": [...]
    },
    {
      "id": "uuid-för-rutin-3",
      "title": "Ben",
      "note": "Uppvärmning extra viktigt",
      "scheduledDays": [2, 5],
      "exercises": [...]
    }
  ]
}
```

### Viktiga fält per rutin:

| Fält | Typ | Obligatoriskt | Beskrivning |
|------|-----|---------------|-------------|
| `id` | string | ✅ | Unikt ID för rutinen |
| `title` | string | ✅ | Namn på passet (t.ex. "Push") |
| `note` | string \| null | ❌ | Anteckning för hela rutinen |
| `scheduledDays` | number[] | ✅ | **Array av veckodagar [0-6]** |
| `exercises` | array | ✅ | Lista av övningar |

### Viktiga fält per övning:

| Fält | Typ | Obligatoriskt | Beskrivning |
|------|-----|---------------|-------------|
| `id` | string | ✅ | Unikt ID för övningen i programmet |
| `exerciseId` | string | ✅ | **ID från ExerciseDB** (för bild/gif) |
| `exerciseName` | string | ✅ | Övningens namn |
| `exerciseImage` | string | ❌ | Bild-ID (samma som exerciseId oftast) |
| `muscleGroup` | string | ❌ | Muskelgrupp (chest, back, legs, etc.) |
| `note` | string \| null | ❌ | Tränartips för övningen |
| `sets` | array | ✅ | Lista av set |

### Set-format:

| Fält | Typ | Beskrivning |
|------|-----|-------------|
| `id` | string | Unikt ID för setet |
| `reps` | number | Antal repetitioner |
| `weight` | number \| null | Vikt i kg (kan vara null/0) |
| `rpe` | number \| null | RPE 1-10 (valfritt) |

---

## 4. daily_tips Format (TEXT[])

Array med **exakt 7 element** - ett för varje veckodag:

```json
[
  "Måndag: Push-dag! Fokusera på bröst och axlar. Ät bra frukost!",
  "Tisdag: Pull-dag idag. Glöm inte uppvärmning för ryggen.",
  null,
  "Torsdag: Push igen! Försök öka vikten från måndag.",
  "Fredag: Pull #2 - kör extra hårt på biceps idag! 💪",
  null,
  "Söndag: Vila och återhämtning. Stretcha om du känner för det."
]
```

**Viktigt:**
- Index 0 = Måndag, Index 6 = Söndag
- Använd `null` för dagar utan tips
- iOS visar tipset under "Tips från tränaren" på Coach-fliken

---

## 5. TypeScript-typer för Lovable

```typescript
// Typer för programmet
interface ProgramRoutine {
  id: string;
  title: string;
  note?: string | null;
  scheduledDays: number[];  // [0, 1, 2, 3, 4, 5, 6]
  exercises: ProgramExercise[];
}

interface ProgramExercise {
  id: string;
  exerciseId: string;       // ExerciseDB ID
  exerciseName: string;
  exerciseImage?: string;
  muscleGroup?: string;
  note?: string | null;
  sets: ExerciseSet[];
}

interface ExerciseSet {
  id: string;
  reps: number;
  weight?: number | null;
  rpe?: number | null;
}

interface CoachProgram {
  id: string;
  coach_id: string;
  title: string;
  note?: string | null;
  duration_type: 'unlimited' | 'weeks';
  duration_weeks?: number | null;
  program_data: {
    routines: ProgramRoutine[];
  };
  daily_tips: (string | null)[];  // Längd 7
}
```

---

## 6. Kod för att spara program (Lovable)

### 6.1 Spara/uppdatera program

```typescript
async function saveCoachProgram(
  coachId: string,
  program: {
    id: string;
    title: string;
    note?: string;
    duration: 'unlimited' | 'weeks';
    durationWeeks?: number;
    routines: ProgramRoutine[];
    dailyTips: (string | null)[];
  }
) {
  // Formatera program_data för databasen
  const programData = {
    routines: program.routines.map(routine => ({
      id: routine.id,
      title: routine.title,
      note: routine.note || null,
      scheduledDays: routine.scheduledDays || [],
      exercises: routine.exercises.map(ex => ({
        id: ex.id,
        exerciseId: ex.exerciseId,
        exerciseName: ex.exerciseName,
        exerciseImage: ex.exerciseImage || ex.exerciseId,
        muscleGroup: ex.muscleGroup || null,
        note: ex.note || null,
        sets: ex.sets.map(set => ({
          id: set.id,
          reps: set.reps,
          weight: set.weight || null,
          rpe: set.rpe || null
        }))
      }))
    }))
  };

  // Säkerställ att dailyTips har 7 element
  const dailyTips = [...(program.dailyTips || [])];
  while (dailyTips.length < 7) {
    dailyTips.push(null);
  }

  const { data, error } = await supabase
    .from('coach_programs')
    .upsert({
      id: program.id,
      coach_id: coachId,
      title: program.title,
      note: program.note || null,
      duration_type: program.duration,
      duration_weeks: program.durationWeeks || null,
      program_data: programData,
      daily_tips: dailyTips,
      updated_at: new Date().toISOString()
    }, { onConflict: 'id' })
    .select()
    .single();

  if (error) throw error;
  return data;
}
```

### 6.2 Tilldela program till klient

```typescript
async function assignProgramToClient(
  coachId: string,
  clientId: string,
  programId: string,
  startDate?: string
) {
  // Avaktivera tidigare aktiva program från samma coach
  await supabase
    .from('coach_program_assignments')
    .update({ status: 'replaced' })
    .eq('coach_id', coachId)
    .eq('client_id', clientId)
    .eq('status', 'active');

  // Skapa ny tilldelning
  const { data, error } = await supabase
    .from('coach_program_assignments')
    .insert({
      coach_id: coachId,
      client_id: clientId,
      program_id: programId,
      status: 'active',
      start_date: startDate || new Date().toISOString().split('T')[0],
      assigned_at: new Date().toISOString()
    })
    .select()
    .single();

  if (error) throw error;
  return data;
}
```

### 6.3 Kombinerad funktion: Spara och tilldela

```typescript
async function saveProgramAndAssign(
  coachId: string,
  clientId: string,
  program: CoachProgramInput
) {
  // 1. Spara programmet
  const savedProgram = await saveCoachProgram(coachId, program);
  
  // 2. Tilldela till klient
  const assignment = await assignProgramToClient(
    coachId,
    clientId,
    savedProgram.id
  );
  
  return { program: savedProgram, assignment };
}
```

---

## 7. UI-komponenter för Lovable

### 7.1 Dag-väljare för rutiner

```tsx
const WEEKDAYS = ['Mån', 'Tis', 'Ons', 'Tor', 'Fre', 'Lör', 'Sön'];

interface DaySchedulerProps {
  selectedDays: number[];
  onChange: (days: number[]) => void;
}

function DayScheduler({ selectedDays, onChange }: DaySchedulerProps) {
  const toggleDay = (dayIndex: number) => {
    if (selectedDays.includes(dayIndex)) {
      onChange(selectedDays.filter(d => d !== dayIndex));
    } else {
      onChange([...selectedDays, dayIndex].sort((a, b) => a - b));
    }
  };

  return (
    <div className="flex gap-2">
      {WEEKDAYS.map((day, index) => (
        <button
          key={index}
          type="button"
          onClick={() => toggleDay(index)}
          className={`
            w-10 h-10 rounded-full text-sm font-medium transition-all
            ${selectedDays.includes(index)
              ? 'bg-black text-white'
              : 'bg-gray-100 text-gray-600 hover:bg-gray-200'
            }
          `}
        >
          {day}
        </button>
      ))}
    </div>
  );
}
```

### 7.2 Dagliga tips-editor

```tsx
const WEEKDAY_NAMES = [
  'Måndag', 'Tisdag', 'Onsdag', 'Torsdag', 'Fredag', 'Lördag', 'Söndag'
];

interface DailyTipsEditorProps {
  tips: (string | null)[];
  onChange: (tips: (string | null)[]) => void;
}

function DailyTipsEditor({ tips, onChange }: DailyTipsEditorProps) {
  // Säkerställ att vi alltid har 7 element
  const normalizedTips = [...tips];
  while (normalizedTips.length < 7) {
    normalizedTips.push(null);
  }

  const updateTip = (index: number, value: string) => {
    const newTips = [...normalizedTips];
    newTips[index] = value.trim() || null;
    onChange(newTips);
  };

  return (
    <div className="space-y-4">
      <div className="flex items-center gap-2">
        <span className="text-lg">💡</span>
        <h3 className="font-semibold">Dagliga tips till klienten</h3>
      </div>
      <p className="text-sm text-gray-500">
        Skriv ett motiverande meddelande för varje dag. Lämna tomt för dagar utan tips.
      </p>
      
      <div className="space-y-3">
        {WEEKDAY_NAMES.map((day, index) => (
          <div key={index} className="space-y-1">
            <label className="text-sm font-medium text-gray-700">
              {day}
            </label>
            <textarea
              value={normalizedTips[index] || ''}
              onChange={(e) => updateTip(index, e.target.value)}
              placeholder={`Tips för ${day.toLowerCase()}...`}
              className="w-full px-3 py-2 border rounded-lg text-sm resize-none focus:ring-2 focus:ring-black focus:border-transparent"
              rows={2}
            />
          </div>
        ))}
      </div>
    </div>
  );
}
```

### 7.3 Rutin-redigerare med dag-schema

```tsx
interface RoutineEditorProps {
  routine: ProgramRoutine;
  onUpdate: (routine: ProgramRoutine) => void;
}

function RoutineEditor({ routine, onUpdate }: RoutineEditorProps) {
  return (
    <div className="border rounded-lg p-4 space-y-4">
      {/* Rutin-namn */}
      <input
        type="text"
        value={routine.title}
        onChange={(e) => onUpdate({ ...routine, title: e.target.value })}
        placeholder="Namn på passet (t.ex. Push, Pull, Ben)"
        className="w-full px-3 py-2 border rounded-lg font-medium"
      />
      
      {/* Dag-väljare */}
      <div className="space-y-2">
        <label className="text-sm font-medium text-gray-700">
          Vilka dagar ska detta pass köras?
        </label>
        <DayScheduler
          selectedDays={routine.scheduledDays || []}
          onChange={(days) => onUpdate({ ...routine, scheduledDays: days })}
        />
      </div>
      
      {/* Rutin-anteckning */}
      <textarea
        value={routine.note || ''}
        onChange={(e) => onUpdate({ ...routine, note: e.target.value || null })}
        placeholder="Anteckning för passet (valfritt)..."
        className="w-full px-3 py-2 border rounded-lg text-sm resize-none"
        rows={2}
      />
      
      {/* Övningar */}
      <div className="space-y-2">
        <h4 className="font-medium">Övningar</h4>
        {routine.exercises.map((exercise, index) => (
          <ExerciseEditor
            key={exercise.id}
            exercise={exercise}
            onUpdate={(updated) => {
              const newExercises = [...routine.exercises];
              newExercises[index] = updated;
              onUpdate({ ...routine, exercises: newExercises });
            }}
          />
        ))}
      </div>
    </div>
  );
}
```

---

## 8. ExerciseDB Integration

iOS-appen använder ExerciseDB för övningsbilder. Se till att:

1. **exerciseId** matchar ExerciseDB:s ID
2. **exerciseImage** används för bild-URL: `https://v2.exercisedb.io/image/{exerciseImage}`

Om ni redan använder ExerciseDB i Lovable, använd samma ID:n!

---

## 9. Verifikation - SQL Query

Kör denna query för att verifiera att data sparas korrekt:

```sql
SELECT 
  cp.id,
  cp.title,
  cp.daily_tips,
  cp.program_data->'routines' as routines,
  jsonb_array_length(cp.program_data->'routines') as routine_count
FROM coach_programs cp
WHERE cp.coach_id = 'COACH_UUID_HERE'
ORDER BY cp.updated_at DESC
LIMIT 5;
```

För att kolla en specifik rutin's scheduledDays:

```sql
SELECT 
  cp.title as program,
  r->>'title' as routine,
  r->'scheduledDays' as scheduled_days
FROM coach_programs cp,
     jsonb_array_elements(cp.program_data->'routines') as r
WHERE cp.id = 'PROGRAM_UUID_HERE';
```

---

## 10. Checklista

- [ ] Lägg till `daily_tips` kolumn i `coach_programs` (TEXT[])
- [ ] Uppdatera program-sparfunktionen att inkludera `scheduledDays` per rutin
- [ ] Uppdatera program-sparfunktionen att inkludera `daily_tips`
- [ ] Lägg till UI för dag-väljare på varje rutin
- [ ] Lägg till UI för dagliga tips
- [ ] Verifiera att `exerciseId` matchar ExerciseDB
- [ ] Testa att iOS visar rätt pass för rätt dag

---

## 11. Exempel: Komplett program-objekt

```json
{
  "id": "prog-abc-123",
  "coach_id": "coach-uuid",
  "title": "4-veckors styrkeprogram",
  "note": "Fokus på progressiv överbelastning",
  "duration_type": "weeks",
  "duration_weeks": 4,
  "daily_tips": [
    "Måndag = Push! Ät ordentligt innan passet 💪",
    "Vila och stretcha",
    "Ben-dag! Extra fokus på knäböj-teknik",
    null,
    "Pull-dag - kör hårt på marklyft!",
    "Lätt cardio om du orkar",
    "Total vila. Nästa vecka kör vi hårdare!"
  ],
  "program_data": {
    "routines": [
      {
        "id": "routine-1",
        "title": "Push (Bröst/Axlar)",
        "note": "Börja med compound, avsluta med isolation",
        "scheduledDays": [0],
        "exercises": [
          {
            "id": "ex-1",
            "exerciseId": "0025",
            "exerciseName": "Bänkpress med skivstång",
            "exerciseImage": "0025",
            "muscleGroup": "chest",
            "note": "Kontrollerad negativ, explosiv upp",
            "sets": [
              { "id": "s1", "reps": 8, "weight": 80 },
              { "id": "s2", "reps": 8, "weight": 80 },
              { "id": "s3", "reps": 8, "weight": 75 },
              { "id": "s4", "reps": 10, "weight": 70 }
            ]
          },
          {
            "id": "ex-2",
            "exerciseId": "0251",
            "exerciseName": "Axelpress med hantlar",
            "exerciseImage": "0251",
            "muscleGroup": "shoulders",
            "note": null,
            "sets": [
              { "id": "s1", "reps": 10, "weight": 24 },
              { "id": "s2", "reps": 10, "weight": 24 },
              { "id": "s3", "reps": 10, "weight": 22 }
            ]
          }
        ]
      },
      {
        "id": "routine-2",
        "title": "Ben",
        "note": "Prioritera ROM över vikt",
        "scheduledDays": [2],
        "exercises": [
          {
            "id": "ex-3",
            "exerciseId": "0043",
            "exerciseName": "Knäböj med skivstång",
            "exerciseImage": "0043",
            "muscleGroup": "quadriceps",
            "note": "Djupt ner, håll ryggen rak",
            "sets": [
              { "id": "s1", "reps": 8, "weight": 100 },
              { "id": "s2", "reps": 8, "weight": 100 },
              { "id": "s3", "reps": 8, "weight": 95 },
              { "id": "s4", "reps": 10, "weight": 90 }
            ]
          }
        ]
      },
      {
        "id": "routine-3",
        "title": "Pull (Rygg/Biceps)",
        "note": null,
        "scheduledDays": [4],
        "exercises": [
          {
            "id": "ex-4",
            "exerciseId": "0032",
            "exerciseName": "Marklyft",
            "exerciseImage": "0032",
            "muscleGroup": "back",
            "note": "Håll stången nära kroppen",
            "sets": [
              { "id": "s1", "reps": 5, "weight": 140 },
              { "id": "s2", "reps": 5, "weight": 140 },
              { "id": "s3", "reps": 5, "weight": 130 }
            ]
          }
        ]
      }
    ]
  }
}
```

---

## 12. iOS-integrationsguide (sammanfattning)

All data som iOS-appen behöver finns redan i databasen. När ändringarna ovan är klara kan iOS-appen:

### Dataflöde

```
┌─────────────────────────────────────────────────────────────────┐
│  1. Hämta aktivt program                                        │
│     Query: coach_program_assignments (status = 'active')        │
│     JOIN: coach_programs                                        │
└─────────────────────────────────────────────────────────────────┘
                              │
                              ▼
┌─────────────────────────────────────────────────────────────────┐
│  2. Läs scheduledDays                                           │
│     Plats: program_data.routines[].scheduledDays                │
│     Format: Array av 0-6, där 0 = Måndag                        │
└─────────────────────────────────────────────────────────────────┘
                              │
                              ▼
┌─────────────────────────────────────────────────────────────────┐
│  3. Läs daily_tips                                              │
│     Plats: daily_tips kolumnen                                  │
│     Format: TEXT[] med 7 element, index 0 = Måndag              │
└─────────────────────────────────────────────────────────────────┘
                              │
                              ▼
┌─────────────────────────────────────────────────────────────────┐
│  4. Konvertera veckodag i Swift                                 │
│     let ourWeekday = (Calendar.current.component(.weekday,      │
│                       from: Date()) + 5) % 7                    │
└─────────────────────────────────────────────────────────────────┘
                              │
                              ▼
┌─────────────────────────────────────────────────────────────────┐
│  5. Hitta dagens pass                                           │
│     Rutin där scheduledDays.contains(ourWeekday)                │
└─────────────────────────────────────────────────────────────────┘
                              │
                              ▼
┌─────────────────────────────────────────────────────────────────┐
│  6. Hitta dagens tips                                           │
│     dailyTips[ourWeekday]                                       │
└─────────────────────────────────────────────────────────────────┘
```

### Swift-kod som redan finns i appen

```swift
// Veckodag-konvertering (Swift)
let calendar = Calendar.current
let systemWeekday = calendar.component(.weekday, from: Date())
// System: 1=Sun, 2=Mon, ..., 7=Sat
// Vår mapping: 0=Mon, 1=Tue, ..., 6=Sun
let ourWeekday = (systemWeekday + 5) % 7

// Hitta dagens pass
func getTodaysRoutine(routines: [ProgramRoutine]) -> ProgramRoutine? {
    let ourWeekday = (Calendar.current.component(.weekday, from: Date()) + 5) % 7
    return routines.first { $0.scheduledDays?.contains(ourWeekday) == true }
}

// Hitta dagens tips
func getTodaysTip(dailyTips: [String?]) -> String? {
    let ourWeekday = (Calendar.current.component(.weekday, from: Date()) + 5) % 7
    guard ourWeekday < dailyTips.count else { return nil }
    return dailyTips[ourWeekday]
}
```

### SQL-query som iOS använder

```sql
SELECT 
  cpa.id as assignment_id,
  cpa.status,
  cpa.start_date,
  cp.id as program_id,
  cp.title,
  cp.note,
  cp.program_data,
  cp.daily_tips,
  cp.duration_type,
  cp.duration_weeks
FROM coach_program_assignments cpa
JOIN coach_programs cp ON cp.id = cpa.program_id
WHERE cpa.client_id = '<user_id>'
  AND cpa.status = 'active'
ORDER BY cpa.assigned_at DESC
LIMIT 1;
```

### Övningsbilder

iOS hämtar övningsbilder via ExerciseDB:
```
https://v2.exercisedb.io/image/{exerciseId}
```

---

## Push-notis vid schema-uppdatering

**VIKTIGT:** När tränaren sparar/uppdaterar ett veckoschema eller daily_tips, skicka en push-notis till klienten så de vet att schemat uppdaterats:

```typescript
// After updating the schedule/program, notify the client
const notifyClientOfScheduleUpdate = async (clientId: string, coachName: string) => {
  await supabase.functions.invoke('send-push-notification', {
    body: {
      user_id: clientId,
      title: `${coachName} uppdaterade ditt schema`,
      body: 'Ditt träningsprogram har uppdaterats. Kolla in det!',
      data: {
        type: 'coach_schedule_updated',
        coach_name: coachName,
      }
    }
  });
};
```

iOS-appen använder också **Supabase Realtime** för att automatiskt uppdatera Coach-tabben i realtid. Kör denna SQL om inte redan gjort:

```sql
ALTER PUBLICATION supabase_realtime ADD TABLE public.coach_programs;
ALTER PUBLICATION supabase_realtime ADD TABLE public.coach_program_assignments;
```

## Kontakt

Vid frågor, kontakta iOS-utvecklaren.
