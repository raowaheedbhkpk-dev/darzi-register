# Darzi Register — GitHub se APK banane ka tareeqa

GitHub aap ke liye muft mein APK bana dega. Aap ko computer par Android Studio ki zaroorat nahi. Ye sab mobile ke browser se bhi ho sakta hai.

## Is zip mein kya hai
- `index.html`, `manifest.webmanifest`, `sw.js` — app
- `icon-*.png`, `maskable-512.png`, `launcher-*.png` — app ka icon
- `darzi-release.keystore` — APK ki "chabi" (signing key). **Isey kabhi delete na karein.** Har naya APK isi chabi se banta hai, isi wajah se update purane data ke upar install ho jata hai.
- `.github/workflows/build-apk.yml` — GitHub ko batata hai ke APK kaise banana hai

---

## Qadam 1: GitHub account aur repository
1. **github.com** par muft account banayein.
2. Upar **+** → **New repository** dabayein.
3. Naam likhein: `darzi-register`
4. **Private** chunein. Ye zaroori hai, kyun ke isme aap ki signing key hai.
5. **Create repository** dabayein.

## Qadam 2: Files upload karein
1. Zip ko phone ya computer par Extract karein.
2. Repository page par **"uploading an existing file"** link dabayein, ya **Add file → Upload files**.
3. Ye sab files chun kar upload karein (`.github` folder ke ilawa sab):
   `index.html, manifest.webmanifest, sw.js, icon-192.png, icon-512.png, maskable-512.png, launcher-mdpi.png, launcher-hdpi.png, launcher-xhdpi.png, launcher-xxhdpi.png, launcher-xxxhdpi.png, darzi-release.keystore, README.md`
4. Neeche **Commit changes** dabayein.

## Qadam 3: Build wali file banayein
`.github` folder chhupa (hidden) hota hai, is liye isey hath se banana aasaan hai:
1. **Add file → Create new file** dabayein.
2. File ke naam ki jagah bilkul ye likhein: `.github/workflows/build-apk.yml`
   (`/` likhte hi folder khud ban jata hai.)
3. Zip mein `.github/workflows/build-apk.yml` file kholein, saara text copy karein aur yahan paste kar dein.
4. **Commit changes** dabayein.

## Qadam 4: APK download karein
1. Repository mein upar **Actions** tab kholein. "APK banao" chal raha hoga (peela nishan).
2. 5 se 8 minute mein hara ✓ aa jayega.
3. Repository ke main page par daayein taraf **Releases** mein jayein, aur `Darzi-Register.apk` download karein.
   (Ya Actions → build par click → neeche **Artifacts** se zip download karein.)

## Qadam 5: Phone par install
1. Download hui `Darzi-Register.apk` kholein.
2. Agar phone pooche "Unknown apps install karne ki ijazat", to Chrome ko ijazat de dein.
3. **Install** dabayein. "Play Protect" warning aaye to **"Install anyway"** dabayein. Ye aap ki apni app hai, Play Store se nahi aayi, is liye warning aati hai.

---

## Backup (zaroor parhein)
- Data phone ke andar save hota hai. App uninstall karne se data mit jata hai.
- Backup lene ke liye **Settings → Drive par backup** dabayein. Share ki list mein **Drive** chunein, phir **Save** dabayein.
- Naye phone par APK install karein, phir **Settings → Backup file se wapas laein** dabayein aur Drive se file chunein.

## App mein tabdeeli ya update
`index.html` mein koi tabdeeli karein (GitHub par file kholein → ✏️ edit → Commit). GitHub khud naya APK bana dega. Naya APK purani app ke upar install karein. Data mehfooz rehta hai, kyun ke chabi (keystore) wohi hai.

## Agar build fail ho (laal ✗)
Actions mein laal ✗ wale build par click karein. Jis step par ✗ hai, uska text copy karke Claude ko bhej dein.
