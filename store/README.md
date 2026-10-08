# Releasing Kid Smile on Google Play

Everything the Play Console asks for is prepared in this folder. Work
through the steps in order.

| What | Where |
|---|---|
| App bundle to upload | `mobile/build/app/outputs/bundle/release/app-release.aab` (rebuild: see "New version") |
| Store text (English + Khmer) | [`listing.md`](listing.md) |
| Icon, feature graphic, screenshots | [`graphics/`](graphics/) |
| Privacy policy | [`../PRIVACY.md`](../PRIVACY.md), public link: https://github.com/Khoeun-ratha/kid-smile/blob/main/PRIVACY.md |
| Upload key | `D:\Mobile\kid_smile-release\` (**outside the repo — back it up!**) |
| Key fingerprints, restore steps | [`keystore-info.txt`](keystore-info.txt) |
| One-step release build | `.\store\build-release.ps1` (add `-Bump` for a new version) |
| Everything above as one text file | [`play-store-release.txt`](play-store-release.txt) |

---

## 0. Before you start

1. **Back up the upload key folder** `D:\Mobile\kid_smile-release\`
   (`upload-keystore.jks` + `key.properties.backup`, which holds the
   password) to a USB drive or private cloud storage. Never put it in git
   or share it. Without it you can't publish updates (Google can reset it,
   but that takes days).
2. Create a Google Play developer account at
   https://play.google.com/console (one-time US$25 fee, identity
   verification can take a few days).

> **New personal accounts must run a closed test first:** at least
> **12 testers opted in for 14 days in a row** before Google unlocks
> production. Plan for this (friends/family with Android phones).

## 1. Create the app

Play Console → **Create app**
- App name: `Kid Smile: Fun Kids Quiz`
- Default language: English (United States)
- App or game: **Game** (category *Educational*) — or **App** (category *Education*)
- Free or paid: **Free**
- Accept the declarations.

## 2. App content (Policy → App content)

| Section | Answer |
|---|---|
| **Privacy policy** | `https://github.com/Khoeun-ratha/kid-smile/blob/main/PRIVACY.md` |
| **App access** | All functionality is available without special access |
| **Ads** | **No**, my app does not contain ads |
| **Content rating** | Fill in the IARC questionnaire. Category: *Reference, News, or Educational* (or *Game* if you picked game). Answer **No** to every question (no violence, fear, sex, language, drugs, gambling, user interaction, sharing of location, purchases). Expected rating: **Everyone / PEGI 3**. |
| **Target audience and content** | Age groups: **5 and under** and **6–8**. Appeal to children: yes. This enrolls the app in the **Families policy** — it already complies (no ads, no data collection). |
| **Data safety** | Does your app collect or share any of the required user data types? **No.** (Scores and language are stored only on the device, which doesn't count as collection.) Then: no data shared, no data collected. |
| **Government app** | No |
| **Financial features** | None |
| **Health** | None |
| **News app** | No |

## 3. Store listing (Grow → Store presence → Main store listing)

Copy text from [`listing.md`](listing.md); upload:
- App icon: `graphics/app-icon-512.png`
- Feature graphic: `graphics/feature-graphic-1024x500.png`
- Phone screenshots: `graphics/phone-screenshot-1.png` … `-6.png`
- Then **Manage translations → Add Khmer** and paste the Khmer text.

Store settings: Category *Educational* / *Education*, contact email (required,
shown publicly).

## 4. Closed test → production

1. **Testing → Closed testing → Create track**, add your testers'
   Gmail addresses (or a Google Group).
2. **Create release** → upload `app-release.aab` → release name `1.0.0`.
   Accept **Play App Signing** (recommended: Google keeps the real
   signing key; yours is only the upload key).
3. Send testers the opt-in link. After 14 days with 12+ testers, apply for
   production access (Dashboard), then **Production → Create release**
   with the same bundle (or a newer one).

Google's review usually takes a few days, longer for apps for kids.

## New version (every later upload)

Each upload needs a higher version code. In `mobile/pubspec.yaml` bump
`version: 1.0.0+1` → e.g. `1.0.1+2` (the number after `+` must always
go up), then:

```
cd mobile
flutter build appbundle --release
```

The bundle is signed automatically with the upload key via
`mobile/android/key.properties` (gitignored). On a new computer, copy
`key.properties.backup` from the key folder to `mobile/android/key.properties`
and fix `storeFile` if the keystore path changed.

## What's in this build

- Offline-only (no `API_URL`): never contacts a server; 542 English + 517
  Khmer questions built in.
- Package name `com.kidsmile.kid_smile`, version 1.0.0 (1), target SDK 36,
  min SDK 24 (Android 7.0+).
- Permissions: INTERNET and ACCESS_NETWORK_STATE are declared (used only
  by sync builds); the Play build makes no network requests.
