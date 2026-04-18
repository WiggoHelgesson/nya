# AdMob — styr mot sportannonser

Det här dokumentet beskriver hur vi styr Google AdMob native-annonser i Up&Down-appen mot sport / träning / retail / lifestyle, och vad du ska göra i AdMob-konsolen.

## 1. Kontextuella signaler (i koden)

Hanteras i [`AdMobService.swift`](../riktiga/riktiga/Services/AdMobService.swift) via `makeTargetedRequest()`. På varje native ad-request skickar vi:

- `contentURL`: `https://upanddownapp.com/collections/up-down`
- `neighboringContentURLs`: våra sport-collection-sidor plus hemsidan
- `keywords`: lista med sport/retail-termer (nike, adidas, gym, padel, golf, …)

Google crawlar URL:erna och använder dem som kontext i auktionen. Fungerar även när användaren nekar ATT.

Effekten kickar in när Googles crawler hunnit indexera sidorna — typiskt 1–7 dagar efter första release.

## 2. AdMob-konsolen (manuellt, måste göras en gång)

Logga in på [apps.admob.com](https://apps.admob.com) → välj Up&Down-appen → **Blocking controls**.

### Sensitive categories — blockera

Slå på blockering för:

- Gambling & betting
- Dating
- Politics
- Religion
- Alcohol
- Tobacco
- Get-rich-quick schemes
- References to sex & sexuality

### General categories — blockera

Slå på blockering för:

- Finance → Credit & lending, Investment, Cryptocurrency
- Health → Pharmaceuticals, Medical, Weight loss
- Home & Garden
- Real estate
- Legal services

Lämna öppna (viktiga för fill rate):

- Shopping
- Sports
- Hobbies & Interests
- Style & Fashion
- Travel
- Food & Drink

### Advertiser URL allowlist (valfritt — sänker fill men maxar relevans)

Under **Blocking controls → Advertiser URLs** kan du lägga en allowlist med sport/retail-domäner, t.ex.:

```
nike.com
adidas.se
adidas.com
puma.com
stadium.se
xxl.se
intersport.se
sportamore.se
gymshark.com
jlindeberg.com
asics.com
newbalance.se
underarmour.se
reebok.se
```

> **OBS**: Allowlist gör att ENBART dessa advertisers kan servera i appen. Det ger hög relevans men kan sänka fill rate dramatiskt. Börja utan allowlist — använd bara blocking. Lägg till allowlist senare om auktionen ändå blandar in för mycket non-sport.

## 3. Förväntningar

- 100 % sport kan inte garanteras — målet är tydlig övervikt.
- Test-annonsen i DEBUG (`ca-app-pub-3940256099942544/3986624511`) ignorerar targeting. Du ser effekten först i produktionsbygget mot prod-unit `ca-app-pub-7998412098246140/3202590470`.
- Console-ändringar slår igenom inom minuter.
- Code-ändringar kräver ny TestFlight/App Store-release.

## 4. Framtida steg

Om fill rate är bra efter ovanstående men vi vill ha ännu mer personifiering: implementera **Publisher Provided Signals (PPS)** med IAB Audience Taxonomy — varje användare taggas med segment (t.ex. "Sports Enthusiasts → Golf") och signalerna skickas i `RequestConfiguration`. Kräver mappning av användardata och är ett separat projekt.
