# Darzi Register (Flutter)

Tailor shop app: customer ka naap, orders, delivery, baqaya raqam, WhatsApp messages, aur WhatsApp ki tarah Google Drive auto backup.

## Auto backup setup (sirf ek dafa, 10 minute)

Google sirf unhi apps ko Drive istemal karne deta hai jo uske paas register hon. Ye kaam phone ke browser se bhi ho jata hai.

App ki maloomat (ye copy karke lagani hain):
- **Package name:** `com.darziregister.darzi_register`
- **SHA-1:** `3B:25:24:1C:F6:78:8C:9E:82:CF:45:F3:D1:91:8C:CE:CA:F4:66:28`

1. **console.cloud.google.com** kholein (apne Gmail se). Upar project list se **New Project** chunein, naam `Darzi Register` rakhein, phir **Create** dabayein.
2. Search bar mein **Google Drive API** likhein, usey kholein aur **Enable** dabayein.
3. Menu mein **Google Auth Platform** (ya "OAuth consent screen") kholein → **Get started**:
   - App name: `Darzi Register`, support email: apna Gmail
   - Audience: **External**
   - Contact email: apna Gmail → **Create**
4. **Audience** page par **Publish app** dabayein aur confirm karein. Is se login har hafte expire nahi hota. App sirf `drive.appdata` (app ka chhupa folder) mangti hai, is liye Google ki review ki zaroorat nahi.
5. **Clients** → **Create client**:
   - Application type: **Android**
   - Package name: `com.darziregister.darzi_register`
   - SHA-1: oopar wala
   - **Create** dabayein.
6. 5 se 10 minute intezar karein. Phir app mein **Settings → Google Drive se jorein** dabayein aur apna Gmail chunein.

Bas. Ab:
- Har tabdeeli ke 10 second baad backup khud Drive par chala jata hai.
- App band karte waqt bhi bacha hua data upload ho jata hai.
- Header mein ☁✓ ka matlab hai backup theek hai. ☁✗ ka matlab hai koi masla hai (Settings mein wajah likhi hoti hai).
- Backup Drive ke chhupe "app data" folder mein hota hai, bilkul WhatsApp ki tarah. Drive ki files list mein nazar nahi aata, lekin Drive → Settings → **Manage apps** mein "Darzi Register" dikhayi deta hai.

## Naye phone par data wapas
1. APK install karein.
2. **Settings → Google Drive se jorein** dabayein aur wohi Gmail chunein.
3. App khud batayegi ke "Drive par backup mila", phir **Haan, restore karein** dabayein.

## Agar "Google se judna nahi hua" aaye
- Package name aur SHA-1 dobara check karein. Ek bhi harf ghalat ho to Google mana kar deta hai.
- Drive API Enable hai ya nahi, check karein.
- Client banane ke baad 10 minute intezar karein.

## APK banana (Termux)
Code push karte hi GitHub Actions APK bana deta hai:
```bash
git add -A && git commit -m "update" && git push
gh run watch
gh release download --pattern "*.apk" --dir ~/storage/downloads --clobber
```
`darzi-release.keystore` kabhi delete na karein. SHA-1 isi file se banta hai. Agar ye file badal gayi to Drive backup aur purani app ke upar update, dono kaam karna band kar denge.
