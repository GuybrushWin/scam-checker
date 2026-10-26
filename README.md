# Scam Checker (Flutter MVP)

## Setup
1. Install Flutter, then in an empty folder run: `flutter create scam_checker`
2. Copy `pubspec.yaml` and `lib/` from this project over the generated ones; run `flutter pub get`.
3. Apply `android_snippets/AndroidManifest_additions.xml` to `android/app/src/main/AndroidManifest.xml`.
4. Deploy `backend/worker.js` to Cloudflare Workers, add the secret `ANTHROPIC_API_KEY`, and put the worker URL in `lib/main.dart` (`backendUrl`).
5. `flutter run`, then `flutter build appbundle` for the Play Store.

## Still to build before launch
- Persist the daily free-check counter and enforce it on the backend (per-user rate limit).
- Google Play Billing subscription (`in_app_purchase` package).
- Privacy policy page (don't store message content), Play Store listing, app icon.

## Family Shield (new tab)
- "Create family group" makes a random secret; relatives enter it on their phones ("Join"). Share it in person only.
- All phones with the same secret show the same 6-digit code, changing every 30 s (standard TOTP). Ask the caller to read theirs.
- Needs correct phone clocks (automatic time on). Secret is stored on-device only; no backend involved.
- Next: QR-code sharing, family chat forwarding, Italian translation, lock secret behind biometrics.
