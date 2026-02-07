# Lovable: Apple & Google Sign-In för Webb

Användare som skapat konto med Apple/Google i iOS-appen ska kunna logga in med samma konto på webben och få tillgång till samma data.

---

## Supabase-projekt

```
URL: https://xebatkodviqgkpsbyuiv.supabase.co
Anon Key: eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9.eyJpc3MiOiJzdXBhYmFzZSIsInJlZiI6InhlYmF0a29kdmlxZ2twc2J5dWl2Iiwicm9sZSI6ImFub24iLCJpYXQiOjE3NDQzMTY2MzIsImV4cCI6MjA1OTg5MjYzMn0.e4W2ut1w_AHiQ_Uhi3HmEXdeGIe4eX-ZhgvIqU_ld6Q
```

---

## 1. Google Sign-In för Webb

### 1.1 Existerande Google Client ID (iOS)

```
748390418907-05k79f4af3tcdftfeasfds1rq0behvoi.apps.googleusercontent.com
```

### 1.2 Skapa Webb Client ID i Google Cloud Console

1. Gå till [Google Cloud Console](https://console.cloud.google.com/)
2. Välj projektet (samma som iOS-appen använder)
3. Gå till **APIs & Services** → **Credentials**
4. Klicka **Create Credentials** → **OAuth client ID**
5. Välj **Web application**
6. Lägg till **Authorized JavaScript origins**:
   - `https://din-lovable-app.lovable.app`
   - `https://din-custom-domain.com` (om ni har en)
   - `http://localhost:3000` (för utveckling)
7. Lägg till **Authorized redirect URIs**:
   - `https://xebatkodviqgkpsbyuiv.supabase.co/auth/v1/callback`
8. Spara och kopiera **Client ID** och **Client Secret**

### 1.3 Konfigurera Supabase

1. Gå till [Supabase Dashboard](https://supabase.com/dashboard/project/xebatkodviqgkpsbyuiv)
2. Gå till **Authentication** → **Providers**
3. Aktivera **Google**
4. Fyll i:
   - **Client ID**: (från steg 1.2)
   - **Client Secret**: (från steg 1.2)
5. Spara

### 1.4 TypeScript-kod för Lovable

```typescript
import { createClient } from '@supabase/supabase-js';

const supabase = createClient(
  'https://xebatkodviqgkpsbyuiv.supabase.co',
  'eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9.eyJpc3MiOiJzdXBhYmFzZSIsInJlZiI6InhlYmF0a29kdmlxZ2twc2J5dWl2Iiwicm9sZSI6ImFub24iLCJpYXQiOjE3NDQzMTY2MzIsImV4cCI6MjA1OTg5MjYzMn0.e4W2ut1w_AHiQ_Uhi3HmEXdeGIe4eX-ZhgvIqU_ld6Q'
);

// Google Sign-In
async function signInWithGoogle() {
  const { data, error } = await supabase.auth.signInWithOAuth({
    provider: 'google',
    options: {
      redirectTo: window.location.origin + '/auth/callback',
      queryParams: {
        access_type: 'offline',
        prompt: 'consent',
      },
    },
  });

  if (error) {
    console.error('Google sign-in error:', error);
  }
}
```

---

## 2. Apple Sign-In för Webb

### 2.1 Förutsättningar

- Apple Developer Account (betalat, $99/år)
- Tillgång till [Apple Developer Portal](https://developer.apple.com/)

### 2.2 Skapa Service ID för Webb

1. Gå till [Apple Developer Portal](https://developer.apple.com/account/resources/identifiers/list/serviceId)
2. Klicka **+** för att skapa ny **Service ID**
3. Fyll i:
   - **Description**: `Up&Down Web`
   - **Identifier**: `com.upanddown.web` (eller liknande)
4. Aktivera **Sign In with Apple**
5. Klicka **Configure** och lägg till:
   - **Domains**: `xebatkodviqgkpsbyuiv.supabase.co`
   - **Return URLs**: `https://xebatkodviqgkpsbyuiv.supabase.co/auth/v1/callback`
6. Spara

### 2.3 Skapa Secret Key

1. I Apple Developer Portal, gå till **Keys**
2. Skapa en ny key med **Sign In with Apple** aktiverat
3. Välj rätt **Primary App ID** (iOS-appens bundle ID)
4. Ladda ner `.p8`-filen (spara säkert - kan bara laddas ner EN gång!)
5. Notera **Key ID**

### 2.4 Generera Client Secret

Apple kräver ett JWT som "client secret". Du kan generera det med detta script:

```javascript
// generate-apple-secret.js
// Kör med: node generate-apple-secret.js

const jwt = require('jsonwebtoken');
const fs = require('fs');

const privateKey = fs.readFileSync('AuthKey_XXXXX.p8'); // Din .p8-fil

const token = jwt.sign({}, privateKey, {
  algorithm: 'ES256',
  expiresIn: '180d', // Max 6 månader
  issuer: 'TEAM_ID',           // Ditt Apple Team ID
  audience: 'https://appleid.apple.com',
  subject: 'com.upanddown.web', // Service ID från steg 2.2
  header: {
    alg: 'ES256',
    kid: 'KEY_ID',  // Key ID från steg 2.3
  },
});

console.log('Apple Client Secret:');
console.log(token);
```

**OBS:** Client Secret måste regenereras var 6:e månad!

### 2.5 Konfigurera Supabase

1. Gå till [Supabase Dashboard](https://supabase.com/dashboard/project/xebatkodviqgkpsbyuiv)
2. Gå till **Authentication** → **Providers**
3. Aktivera **Apple**
4. Fyll i:
   - **Client ID**: `com.upanddown.web` (Service ID)
   - **Secret**: (JWT från steg 2.4)
5. Spara

### 2.6 TypeScript-kod för Lovable

```typescript
// Apple Sign-In
async function signInWithApple() {
  const { data, error } = await supabase.auth.signInWithOAuth({
    provider: 'apple',
    options: {
      redirectTo: window.location.origin + '/auth/callback',
    },
  });

  if (error) {
    console.error('Apple sign-in error:', error);
  }
}
```

---

## 3. Auth Callback-sida

Skapa en callback-sida som hanterar OAuth-redirecten:

```typescript
// pages/auth/callback.tsx (eller motsvarande i Lovable)
import { useEffect } from 'react';
import { useNavigate } from 'react-router-dom';
import { supabase } from '../lib/supabase';

export default function AuthCallback() {
  const navigate = useNavigate();

  useEffect(() => {
    const handleCallback = async () => {
      const { data: { session }, error } = await supabase.auth.getSession();
      
      if (error) {
        console.error('Auth callback error:', error);
        navigate('/login?error=auth_failed');
        return;
      }

      if (session) {
        // Kontrollera om användaren har en profil
        const { data: profile } = await supabase
          .from('profiles')
          .select('username')
          .eq('id', session.user.id)
          .single();

        if (profile?.username) {
          // Befintlig användare - gå till dashboard
          navigate('/dashboard');
        } else {
          // Ny användare - gå till onboarding
          navigate('/onboarding');
        }
      } else {
        navigate('/login');
      }
    };

    handleCallback();
  }, [navigate]);

  return (
    <div className="flex items-center justify-center min-h-screen">
      <p>Loggar in...</p>
    </div>
  );
}
```

---

## 4. Kompletta inloggningsknappar

```tsx
import { supabase } from '../lib/supabase';

function LoginButtons() {
  const handleGoogleSignIn = async () => {
    const { error } = await supabase.auth.signInWithOAuth({
      provider: 'google',
      options: {
        redirectTo: `${window.location.origin}/auth/callback`,
      },
    });
    if (error) console.error('Google error:', error);
  };

  const handleAppleSignIn = async () => {
    const { error } = await supabase.auth.signInWithOAuth({
      provider: 'apple',
      options: {
        redirectTo: `${window.location.origin}/auth/callback`,
      },
    });
    if (error) console.error('Apple error:', error);
  };

  return (
    <div className="space-y-4">
      <button
        onClick={handleGoogleSignIn}
        className="w-full flex items-center justify-center gap-3 px-4 py-3 border rounded-full hover:bg-gray-50"
      >
        <img src="/google-icon.svg" alt="Google" className="w-5 h-5" />
        <span>Fortsätt med Google</span>
      </button>

      <button
        onClick={handleAppleSignIn}
        className="w-full flex items-center justify-center gap-3 px-4 py-3 bg-black text-white rounded-full hover:bg-gray-900"
      >
        <svg className="w-5 h-5" viewBox="0 0 24 24" fill="currentColor">
          <path d="M18.71 19.5c-.83 1.24-1.71 2.45-3.05 2.47-1.34.03-1.77-.79-3.29-.79-1.53 0-2 .77-3.27.82-1.31.05-2.3-1.32-3.14-2.53C4.25 17 2.94 12.45 4.7 9.39c.87-1.52 2.43-2.48 4.12-2.51 1.28-.02 2.5.87 3.29.87.78 0 2.26-1.07 3.81-.91.65.03 2.47.26 3.64 1.98-.09.06-2.17 1.28-2.15 3.81.03 3.02 2.65 4.03 2.68 4.04-.03.07-.42 1.44-1.38 2.83M13 3.5c.73-.83 1.94-1.46 2.94-1.5.13 1.17-.34 2.35-1.04 3.19-.69.85-1.83 1.51-2.95 1.42-.15-1.15.41-2.35 1.05-3.11z"/>
        </svg>
        <span>Fortsätt med Apple</span>
      </button>
    </div>
  );
}
```

---

## 5. Lyssna på auth-state

```typescript
import { useEffect, useState } from 'react';
import { supabase } from '../lib/supabase';
import type { User } from '@supabase/supabase-js';

export function useAuth() {
  const [user, setUser] = useState<User | null>(null);
  const [loading, setLoading] = useState(true);

  useEffect(() => {
    // Hämta initial session
    supabase.auth.getSession().then(({ data: { session } }) => {
      setUser(session?.user ?? null);
      setLoading(false);
    });

    // Lyssna på ändringar
    const { data: { subscription } } = supabase.auth.onAuthStateChange(
      (_event, session) => {
        setUser(session?.user ?? null);
      }
    );

    return () => subscription.unsubscribe();
  }, []);

  return { user, loading };
}
```

---

## 6. Checklista

### Google Sign-In
- [ ] Skapa Web OAuth Client i Google Cloud Console
- [ ] Lägg till redirect URI: `https://xebatkodviqgkpsbyuiv.supabase.co/auth/v1/callback`
- [ ] Aktivera Google provider i Supabase Dashboard
- [ ] Fyll i Client ID och Client Secret

### Apple Sign-In
- [ ] Skapa Service ID i Apple Developer Portal
- [ ] Konfigurera domains och return URLs
- [ ] Skapa Sign In with Apple Key
- [ ] Generera Client Secret (JWT)
- [ ] Aktivera Apple provider i Supabase Dashboard
- [ ] Fyll i Service ID och Client Secret

### Lovable
- [ ] Implementera login-knappar
- [ ] Skapa `/auth/callback`-route
- [ ] Implementera `useAuth`-hook
- [ ] Hantera nya vs befintliga användare

---

## 7. Viktigt: Samma användare på iOS och Webb

När en användare loggar in med samma Google/Apple-konto på webben som de använde i iOS-appen, matchar Supabase automatiskt till samma `auth.users` post baserat på email.

**Det betyder:**
- Samma `user.id` (UUID)
- Samma data i `profiles`-tabellen
- Samma träningsprogram, viktdata, etc.

Ingen extra konfiguration behövs - Supabase hanterar detta automatiskt! 🎉

---

## 8. Felsökning

### "Redirect URI mismatch"
- Kontrollera att redirect URI i Google/Apple-konfigurationen matchar exakt:
  `https://xebatkodviqgkpsbyuiv.supabase.co/auth/v1/callback`

### "Invalid client" (Apple)
- Kontrollera att Service ID är korrekt
- Kontrollera att Client Secret (JWT) inte har gått ut
- Regenerera JWT om det är äldre än 6 månader

### Användare får nytt konto istället för befintligt
- Kontrollera att samma email används
- Supabase matchar på email - om iOS-användaren inte delade email med Apple, kan det bli problem

### Test
1. Logga in med Google/Apple på webben
2. Kolla att `user.id` i Supabase matchar iOS-användaren
3. Verifiera att profil-data (username, avatar, etc.) visas korrekt
