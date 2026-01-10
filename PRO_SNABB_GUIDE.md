# 💎 PRO MEDLEMSKAP - SNABB GUIDE

## 🎁 VAD FÅR PRO-MEDLEMMAR?

### ✅ **6 HUVUDFUNKTIONER:**

1. **🏆 Månadens pris**  
   Tävla om priser baserat på steg (icke-Pro ser bara blurrad vy)

2. **🗺️ Zonkriget 2x Poäng**  
   Dubbla poängen för erövrad area (icke-Pro får 1x)

3. **💪 Obegränsade Övningar**  
   Full statistik för alla gymövningar (icke-Pro: endast 3 gratis)

4. **🤖 Obegränsad AI-Coach**  
   Chatta obegränsat med UPPY (icke-Pro: begränsade meddelanden)

5. **📊 Full Veckostatistik**  
   Detaljerade grafer och analyser

6. **🏅 PRO-Badge**  
   Visuellt märke vid användarnamn överallt i appen

---

## ⚡ GE NÅGON PRO (30 SEKUNDER)

### **1. Öppna Supabase SQL Editor**

### **2. Kör denna query:**
```sql
UPDATE public.profiles
SET is_pro_member = true
WHERE email = 'ANGE_EMAIL_HÄR';
```

### **3. Verifiera:**
```sql
SELECT username, email, is_pro_member 
FROM public.profiles 
WHERE email = 'ANGE_EMAIL_HÄR';
```

### **4. Klart!** 🎉
Användaren har nu Pro när de öppnar appen nästa gång!

---

## 💡 EXEMPEL: GE 3 KREATÖRER PRO SAMTIDIGT

```sql
UPDATE public.profiles
SET is_pro_member = true
WHERE email IN (
    'kreator1@example.com',
    'kreator2@example.com',
    'kreator3@example.com'
);
```

---

## ❌ TA BORT PRO

```sql
UPDATE public.profiles
SET is_pro_member = false
WHERE email = 'ANGE_EMAIL_HÄR';
```

---

## 📋 SE ALLA PRO-MEDLEMMAR

```sql
SELECT username, email, is_pro_member
FROM public.profiles
WHERE is_pro_member = true
ORDER BY created_at DESC;
```

---

## ✨ VARFÖR GE KREATÖRER PRO?

- 🎨 **Högre synlighet** med PRO-badge
- 💪 **Bättre verktyg** för att skapa innehåll
- 🚀 **Snabbare progression** (2x poäng)
- 🎁 **Full upplevelse** = mer engagemang

---

**🔥 TIPS:** Systemet fungerar parallellt med RevenueCat - ingen konflikt!











