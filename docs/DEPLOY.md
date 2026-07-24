# STRIDE — Deployment checklist (Android / Google Play)

Android-first. iOS is not set up (no `ios/` folder) — add later with
`flutter create --platforms=ios .` if/when you want it.

## 1. Upload keystore (you must do this — needs your passwords)
Generate a release upload key (keep the file + passwords safe and OUT of git):

```bash
keytool -genkey -v -keystore ~/stride-upload.jks \
  -keyalg RSA -keysize 2048 -validity 10000 -alias stride
```

Then create `android/key.properties` (already git-ignored via the gradle wiring;
verify it's in `.gitignore`):

```properties
storePassword=<the store password you chose>
keyPassword=<the key password you chose>
keyAlias=stride
storeFile=/Users/<you>/stride-upload.jks
```

`android/app/build.gradle.kts` already reads this file and uses it for the
release `signingConfig` (falls back to debug keys only when the file is absent).
Do **not** lose this key — Play ties your app to it permanently.

## 2. Application ID
Set to `com.shrujalsrinath.stride` in `android/app/build.gradle.kts`. **Permanent
once published.** The OAuth deep-link scheme is `io.stride.app://login-callback/`
(AndroidManifest + `auth_provider.dart`) — this exact string must be in the Supabase
dashboard's Auth → Redirect URLs for Google sign-in to complete.

## 3. Build the release artifact
The dev-access bypass (demo login → mock data) now **defaults to disabled** —
a plain release build is safe even if this flag is omitted:

```bash
flutter build appbundle
# output: build/app/outputs/bundle/release/app-release.aab
```

To test the demo-login shortcut locally, opt in explicitly instead:

```bash
flutter run --dart-define=ATLAS_DEV_ACCESS=true
```
(the flag name stays the internal codename `ATLAS_DEV_ACCESS` — display branding
and the code identifier are intentionally split, see root `CLAUDE.md` §1.)

## 4. Privacy policy & terms (store blocker)
- Host `docs/PRIVACY.md` and `docs/TERMS.md` at public URLs.
- Fill the `[CONTACT EMAIL]` placeholders in both.
- Update `_privacyPolicyUrl` and `_termsUrl` in
  `lib/features/settings/screens/settings_screen.dart` to the hosted URLs.

## 5. Play Console — Data Safety form
Declare the following (collected, linked to the user, not shared, not sold):

| Category | Data | Purpose |
|---|---|---|
| Personal info | Email, name | Account management |
| Health & fitness | Activity, nutrition, weight, mood/journal | App functionality |
| App activity | In-app actions (habits, logs) | App functionality |
| App info & performance | Crash logs / diagnostics | Diagnostics |
| Photos (optional) | Camera for barcode/photo | App functionality, not stored for other use |

- Data is **encrypted in transit**.
- Users **can request deletion** (in-app account deletion). Link the policy URL.

## 6. Final checks
- [ ] Run on a **real Android device** (web preview can't show true fonts /
      transitions; the "Inter font failed" message is web-only).
- [ ] Verify sign-up → onboarding → core flows with a brand-new account.
- [ ] Confirm `client_errors` migration is applied (crash reporting).
- [ ] Store listing: title "STRIDE", screenshots, short/full description, icon.
- [ ] `flutter analyze` clean · `flutter test` green (158 tests).
