# 🚨 VIKTIGT: ExerciseID måste vara från ExerciseDB

## Problemet

När en klient startar ett coach-pass i iOS visas inte övningsbilderna. Felet:

```
📥 Image response status: 422 for exercise A88A3F7C-E112-4244-9712-6B31C6A6543D
⚠️ Non-200 status for URL: https://exercisedb.p.rapidapi.com/image?exerciseId=A88A3F7C-E112-4244-9712-6B31C6A6543D
```

**Orsak:** Lovable sparar sitt eget UUID som `exerciseId` istället för ExerciseDB:s ID.

---

## Fel vs Rätt

### ❌ FEL - Lovables interna UUID

```json
{
  "id": "A88A3F7C-E112-4244-9712-6B31C6A6543D",
  "exerciseId": "A88A3F7C-E112-4244-9712-6B31C6A6543D",
  "exerciseName": "Övning"
}
```

### ✅ RÄTT - ExerciseDB ID

```json
{
  "id": "A88A3F7C-E112-4244-9712-6B31C6A6543D",
  "exerciseId": "0025",
  "exerciseName": "Barbell Bench Press",
  "exerciseImage": "0025"
}
```

---

## Vad är skillnaden?

| Fält | Beskrivning | Exempel |
|------|-------------|---------|
| `id` | Ert interna ID för övningen i programmet. Kan vara UUID. | `"A88A3F7C-..."` |
| `exerciseId` | **ExerciseDB:s ID**. Används för att hämta bild/gif. | `"0025"` |
| `exerciseName` | Övningens namn från ExerciseDB | `"Barbell Bench Press"` |
| `exerciseImage` | Samma som exerciseId (för bild-URL) | `"0025"` |

---

## ExerciseDB ID-format

ExerciseDB använder **4-siffriga strängar** som ID:

```
"0001" - 3/4 sit-up
"0002" - 45° side bend
"0025" - barbell bench press
"0032" - barbell deadlift
"0043" - barbell full squat
"0251" - dumbbell shoulder press
...
```

**Bild-URL:** `https://v2.exercisedb.io/image/{exerciseId}`

Exempel: `https://v2.exercisedb.io/image/0025` → Bänkpress-gif

---

## Hur fixa i Lovable

### När tränaren väljer en övning från ExerciseDB:

```typescript
// När användaren väljer en övning från ExerciseDB
const handleSelectExercise = (exerciseFromDB: ExerciseDBExercise) => {
  const newExercise = {
    id: crypto.randomUUID(),              // ✅ Eget UUID för programmet
    exerciseId: exerciseFromDB.id,        // ✅ ExerciseDB ID (t.ex. "0025")
    exerciseName: exerciseFromDB.name,    // ✅ Namn från ExerciseDB
    exerciseImage: exerciseFromDB.id,     // ✅ Samma som exerciseId
    muscleGroup: exerciseFromDB.bodyPart, // ✅ Muskelgrupp
    note: null,
    sets: [
      { id: crypto.randomUUID(), reps: 10, weight: null }
    ]
  };
  
  addExerciseToRoutine(newExercise);
};
```

### ExerciseDB API-svar ser ut så här:

```json
{
  "id": "0025",
  "name": "barbell bench press",
  "bodyPart": "chest",
  "equipment": "barbell",
  "gifUrl": "https://v2.exercisedb.io/image/0025",
  "target": "pectorals",
  "secondaryMuscles": ["anterior deltoids", "triceps brachii"],
  "instructions": [...]
}
```

**Använd `id` ("0025") som `exerciseId`!**

---

## Komplett exempel på korrekt övning

```json
{
  "id": "prog-exercise-uuid-123",
  "exerciseId": "0025",
  "exerciseName": "barbell bench press",
  "exerciseImage": "0025",
  "muscleGroup": "chest",
  "note": "Kontrollerad negativ, 3 sekunder ner",
  "sets": [
    { "id": "set-1", "reps": 8, "weight": 80 },
    { "id": "set-2", "reps": 8, "weight": 80 },
    { "id": "set-3", "reps": 8, "weight": 75 }
  ]
}
```

---

## Checklista

- [ ] `exerciseId` = ExerciseDB:s ID (t.ex. `"0025"`)
- [ ] `exerciseName` = Namn från ExerciseDB
- [ ] `exerciseImage` = Samma som `exerciseId`
- [ ] `id` = Ert interna UUID (kan vara vad som helst)

---

## Test

Efter fix, verifiera att denna URL fungerar:

```
https://v2.exercisedb.io/image/{exerciseId}
```

Exempel:
- ✅ `https://v2.exercisedb.io/image/0025` → Visar bänkpress-gif
- ❌ `https://v2.exercisedb.io/image/A88A3F7C-E112-4244-9712-6B31C6A6543D` → 404/422 error
