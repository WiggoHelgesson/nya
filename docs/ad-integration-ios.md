# Annonsintegration -- iOS

## Viktigt: Ingen personalisering

- **Inga targeted ads** -- Systemet samlar inte in anvandarprofiler, intressen eller beteendedata for att rikta annonser.
- **Alla anvandare ser samma pool** -- Samma annonser visas for alla, oavsett vem anvandaren ar.
- **Server-side ranking utan personalisering** -- Vilka annonser som visas bestams av tre faktorer som INTE har med anvandaren att gora:
  - Hur ny annonsen ar (freshness)
  - Hur bra annonsen presterar overlag (CTR for alla anvandare)
  - Annonsbudget (`daily_bid`)
- **Rotation via slump** -- Nar det finns fler annonser an som visas per laddning roteras urvalet slumpmassigt, inte baserat pa anvandarbeteende.
- **Ingen data skickas fran appen** -- API-anropet `POST /get-active-ads` skickar ingen anvandarinfo (inget user-id, ingen auth-token, ingen platsdata).
- **Appen behover inte samla in nagon data** om anvandaren for annonsernas skull.

---

## Annonsformat

| Format | Placering | Antal |
|--------|-----------|-------|
| `feed` | I sociala flodet, efter 4:e inlagget | Max 3 per laddning |
| `banner` | TabView-karusell hogst upp pa Rewards-fliken | Alla aktiva |

---

## API-anrop

### Hamta annonser

```
POST https://<project>.supabase.co/functions/v1/get-active-ads
Content-Type: application/json

{ "format": "feed" }
```

Svar:

```json
{
  "ads": [
    {
      "id": "uuid",
      "format": "feed",
      "title": "Annonsrubrik",
      "description": "Beskrivning eller null",
      "image_url": "https://... eller null",
      "cta_text": "Knaptext eller null",
      "cta_url": "https://...",
      "daily_bid": 50.00
    }
  ]
}
```

### Spara klicksparning

```
POST https://<project>.supabase.co/functions/v1/track-ad-click
Content-Type: application/json

{ "campaign_id": "uuid" }
```

---

## Swift-modell

```swift
struct AdCampaign: Identifiable, Codable {
    let id: String
    let format: String
    let title: String
    let description: String?
    let image_url: String?
    let cta_text: String?
    let cta_url: String?
    let daily_bid: Double?
}

private struct GetActiveAdsResponse: Codable {
    let ads: [AdCampaign]
}
```

---

## AdService

`AdService.swift` ar en singleton (`AdService.shared`) som hanterar hamtning och cachning:

- `fetchFeedAds()` -- Hamtar feed-annonser, cachar i 5 minuter.
- `fetchBannerAds()` -- Hamtar banner-annonser, cachar i 5 minuter.
- `trackClick(campaignId:)` -- Sparar klick via Edge Function.

Anrop sker via Supabase Swift SDK:

```swift
let response: GetActiveAdsResponse = try await SupabaseConfig.supabase.functions.invoke(
    "get-active-ads",
    options: FunctionInvokeOptions(body: ["format": format])
)
```

---

## Placering i UI

### Feed (SocialView)

Annonser visas efter det 4:e inlagget i det sociala flodet via `FeedAdCard`.

### Banner (RewardsView)

Annonser visas som en TabView-karusell hogst upp pa Rewards-fliken.

---

## Felsokningssteg

| Problem | Kontrollera |
|---------|-------------|
| Tom `ads`-array | Finns aktiva annonser i `ad_campaigns`? Kontrollera `status = 'active'`, `start_date`, `end_date`. |
| 400-fel | `format`-parametern saknas eller ar fel (bara `feed`, `banner`, `popup`). |
| 500-fel | Kolla Edge Function-loggar i Supabase Dashboard. |
| Annonser syns inte i UI | Kontrollera att `fetchFeedAds()`/`fetchBannerAds()` anropas. Cache varar 5 min. |
| Bilder laddas inte | `image_url` kan vara `null` -- hantera det i UI. |

---

## Sammanfattning

| Funktion | Edge Function | iOS |
|----------|---------------|-----|
| Visa annonser | `get-active-ads` | `AdService.fetchFeedAds()` / `fetchBannerAds()` |
| Spara klick | `track-ad-click` | `AdService.trackClick(campaignId:)` |
| Personalisering/targeting | Ej tillampligt | Ej tillampligt |
