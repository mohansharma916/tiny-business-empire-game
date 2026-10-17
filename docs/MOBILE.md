# Mobile build guide

Everything specific to shipping on Android (first) and iOS (later).
Store rules change often: check each item marked **(verify)** in the Play Console or App Store Connect before release.

---

## 1. Platform targets

| Setting | Android | iOS |
|---|---|---|
| Minimum OS | Android 8.0 (API 26) | iOS 15 |
| Target SDK | Google Play's current required level, raised every August **(verify)** | Latest Xcode SDK |
| CPU architectures | `arm64-v8a` + `armeabi-v7a` (many low-end phones in India are still 32-bit) | arm64 |
| Package format | Android App Bundle (`.aab`) for Play; `.apk` only for local testing | `.ipa` via Xcode |
| Orientation | Portrait | Portrait |
| Renderer | Godot Compatibility (OpenGL ES 3) | Compatibility |

Use a Godot 4 version whose Android export supports **16 KB memory pages**, which Google Play requires
for new apps and updates targeting Android 15+ **(verify)**.

---

## 2. One-time Android setup

1. Install **Android Studio** (for the Android SDK) and **JDK 17**.
2. In Godot: Editor → Editor Settings → Export → Android: set the SDK path and Java path.
3. Project → Install Android Build Template (needed for plugins).
4. Project → Export → Add **Android** preset:
   - Use Gradle Build: **on** (required for plugins)
   - Architectures: `arm64-v8a`, `armeabi-v7a`
   - Min SDK 26; target SDK as required by Play
   - Package name: `com.<yourstudio>.tinybusinessempire` (**cannot be changed after release**)
   - Permissions: see section 4
5. Create an **upload keystore** and keep it backed up outside the repo (never commit it):
   ```bash
   keytool -genkey -v -keystore upload.keystore -alias upload -keyalg RSA -keysize 2048 -validity 10000
   ```
   Enable **Play App Signing** in the Play Console, so Google holds the app signing key.
6. Add a **Web** export preset too: Antigravity tests gameplay in its browser with it.

### iOS (after soft launch)

- Requires a **Mac with Xcode** and an **Apple Developer Program** membership (paid, yearly).
- Godot exports an Xcode project; build and upload from Xcode.
- For push: create an APNs authentication key and upload it to Firebase.
- If ads use the advertising identifier, show Apple's App Tracking Transparency prompt.

---

## 3. Plugins and SDKs

Godot 4 uses Android plugins (v2). Check that each plugin is maintained and supports your
Godot version before adopting it **(verify)**.

| Need | Candidate | Release |
|---|---|---|
| Backend client | Nakama Godot SDK (`heroiclabs/nakama-godot`, official) | P1 |
| Crash reports, analytics, push | A maintained Godot 4 Firebase plugin; if none fits, Claude Code writes a small Kotlin Android plugin wrapping Firebase Crashlytics, Analytics and Messaging | P0 (crash, analytics), P1 (push) |
| Google Play Games sign-in | Community Godot 4 Play Games Services plugin | P1 |
| In-app purchase (remove ads) | Official Godot Google Play Billing plugin | P1 |
| Rewarded ads | A maintained Godot 4 AdMob plugin (with mediation) | P1 |

Every SDK adds download size and startup time. Measure each one against the budgets in `AGENTS.md`,
and initialize ad SDKs only after the tutorial.

Place `google-services.json` (Android) and `GoogleService-Info.plist` (iOS) where the Firebase plugin expects them.

---

## 4. Permissions

Ask for as little as possible. Each permission must also appear in the Play Data safety form.

| Permission | Why | Release |
|---|---|---|
| `INTERNET` | Analytics, crash reports, backend | P0 |
| `ACCESS_NETWORK_STATE` | Skip network calls when offline | P0 |
| `VIBRATE` | Haptics (can be turned off in Settings) | P0 |
| `POST_NOTIFICATIONS` | Push on Android 13+; request after the first milestone, never at launch | P1 |
| `com.google.android.gms.permission.AD_ID` | Only if ads use the advertising id, with consent | P1 |

Never request contacts, location, camera, microphone or storage.

---

## 5. App lifecycle (must handle)

| Event | Godot hook | What to do |
|---|---|---|
| App goes to background | `NOTIFICATION_APPLICATION_PAUSED` | Stop the economy tick, save, submit score (P1), stop rendering work |
| App returns | `NOTIFICATION_APPLICATION_RESUMED` | Compute offline earnings, show the summary, restart the tick |
| Focus lost (call, notification shade) | `NOTIFICATION_APPLICATION_FOCUS_OUT` | Pause animations and audio |
| Android back button | `NOTIFICATION_WM_GO_BACK_REQUEST` | Close the top panel; on the city screen, ask before exiting (`quit_on_go_back` is off in `project.godot`) |
| Low memory | `NOTIFICATION_OS_MEMORY_WARNING` | Free cached panels and textures not on screen |
| App killed by the OS | (no event) | Rely on the 30-second autosave and the save on pause |

---

## 6. Screens and touch

- **Safe areas:** keep buttons out of notches and gesture bars using `DisplayServer.get_display_safe_area()`.
- **Aspect ratios:** test from 16:9 to 20:9 and taller. The project stretches with `canvas_items` + `expand`.
- **Touch targets:** at least 48 dp; leave space between buttons.
- **Text:** fonts must include Devanagari for Hindi; respect the system font-size setting.
- **Hold to repeat:** tap-and-hold serving, so players never need to tap rapidly.

---

## 7. Battery, data and performance

- 30 fps battery-saver mode (`Engine.max_fps = 30`), default on low-end devices and below 20% battery.
- Pause everything in the background; the game earns through offline earnings, not by running.
- **Offline-first:** the game must be fully playable with no internet. Queue network calls and retry
  with backoff; never block the UI on the network.
- Keep network use under 1 MB per hour of play; batch analytics.
- Keep the initial download under 80 MB. Godot doesn't support Google Play Asset Delivery out of the box;
  if later content pushes the size up, download extra `.pck` content packs from your own server after install.

### Reference devices (buy or borrow before production)

| Tier | Example spec |
|---|---|
| Low-end Android | 3 GB RAM, entry-level chipset from around 2020, Android 10–11 |
| Mid-range Android | 6 GB RAM, recent mid-range chipset |
| iPhone | A model from about four years ago |

Test every build on the low-end device. Use the Play Console's pre-launch report for broader coverage.

---

## 8. Networking on mobile

- Production backend must use **HTTPS**. Android blocks plain HTTP by default and iOS requires HTTPS.
  `server/docker-compose.prod.yml` adds HTTPS with Caddy.
- During development: the Android emulator reaches your computer at `10.0.2.2`. A physical phone on
  plain HTTP will be blocked, so test the backend from the desktop or web build, or use an HTTPS tunnel.
- Backend address and keys live in `config/backend.json` (the server key is not a secret).

---

## 9. Google Play release checklist

- [ ] Developer account created. New **personal** accounts must run a **closed test with at least 12 testers for 14 days** before production access **(verify current rule)**.
- [ ] Privacy policy URL (hosted web page).
- [ ] Data safety form matches every SDK.
- [ ] Content rating questionnaire (IARC).
- [ ] Target audience and content set; if under-18s may play, child-appropriate ad settings.
- [ ] Account deletion: in-app option (`delete_my_account`) **and** a web page or form explaining how to request deletion.
- [ ] Store listing in English and Hindi: icon, feature graphic, screenshots, short and full description.
- [ ] Internal testing track → closed testing → open testing / soft launch (India only) → production.
- [ ] Android vitals checked: crash rate and ANR rate below Play's bad-behavior thresholds.
- [ ] Monetization off by default until the core game tests well (remote config).
