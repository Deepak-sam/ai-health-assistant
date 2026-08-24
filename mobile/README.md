# Family Health Assistant — Mobile (Phase 1)

Flutter app for the private family AI health assistant. Chat-first (never
dashboard-first), local-first (Drift/SQLite is the source of truth), with
all statistics computed on-device in Dart — never by the backend, never by
the LLM. See `../docs/ARCHITECTURE.md`, `../docs/DATABASE_SCHEMA.md`, and
`../docs/API_SPEC.md` for the contracts this code implements.

**Update: since this was first written, a Flutter SDK was installed and this
was actually verified** — `flutter pub get` (171 dependencies resolve
cleanly), `dart run build_runner build` (Drift codegen: 176 outputs, no
errors), `flutter analyze` (**0 issues**), and `flutter test`
(**24/24 passing**, both pure-Dart unit test suites). Two real compile
errors surfaced and were fixed: a missing `go_router` import in
`scaffold_with_nav.dart`, and a Dart type-inference edge case in
`health_connect_provider.dart` (a `.fold()` call whose accumulator type was
inferred as nullable from a ternary's other branch — fixed with an explicit
`<double>` type argument). All lint warnings were also cleaned up
(deprecated `withOpacity`/`RadioListTile.groupValue` APIs migrated to their
current replacements).

**What is still NOT verified, and can't be from this environment:** an
actual Android build (`flutter build apk`) — the Android SDK itself can't be
installed here (its download host is network-blocked in this container,
confirmed via `flutter doctor`) — and anything iOS (no macOS/Xcode
available). The Dart/Flutter-framework layer is now solid; the
native-platform layer (Health Connect, Garmin webview, camera/gallery,
FCM, local notifications) still needs a real device or emulator to confirm.
See "Known limitations & risks" below for specifics.

## Getting started

```bash
cd mobile
flutter pub get
dart run build_runner build --delete-conflicting-outputs   # generates *.g.dart for Drift
flutter run --dart-define-from-file=env.json
```

Drift's `@DriftDatabase`/`@DriftAccessor` classes need `build_runner` to
generate their `part '*.g.dart'` files before anything compiles. This has
been verified to work cleanly (176 generated files, no errors) — on a
recent build_runner version the `--delete-conflicting-outputs` flag is a
no-op (conflicts are handled automatically) but is harmless to pass.

### Required `--dart-define` values

Create `mobile/env.json` (gitignored) and pass it via
`--dart-define-from-file`, or pass each flag individually:

| Key | Example | Notes |
|---|---|---|
| `API_BASE_URL` | `https://health-api.example.com/api/v1` | Must include `/api/v1` (API_SPEC.md). |
| `GARMIN_ENABLED` | `false` | Feature flag — Garmin UI/OAuth is hidden entirely when false. |
| `USE_FAKE_HEALTH_PROVIDER` | `true` | Use `FakeHealthProvider` (deterministic sample data) instead of real Health Connect/Garmin. Turn off once testing on a device with real Health Connect data. |
| `GARMIN_AUTHORIZE_URL` | *(empty)* | Dev-only override — a static Garmin authorize URL instead of fetching a fresh one from the backend. Leave empty in production. |
| `GARMIN_REDIRECT_SCHEME` | `familyhealth` | Custom URL scheme this app registers to catch the end of the Garmin OAuth redirect chain. Must match native platform config (see below). |
| `API_TIMEOUT_MS` | `20000` | Dio request timeout. |

None of these are secrets — nothing secret is ever passed via `--dart-define`
or hardcoded in source (hard constraint). Firebase config and any Garmin
client secret live server-side / in platform config files, not here.

## Firebase setup steps

1. Create a Firebase project, add an iOS app and an Android app.
2. Run `flutterfire configure` from `mobile/` — this generates
   `lib/firebase_options.dart` (not committed here; generate it locally) and
   the platform config files below. This repo does **not** include a
   `firebase_options.dart` — `main.dart` currently calls
   `Firebase.initializeApp()` with no options, which works only once the
   native platform config files exist:
   - Android: `android/app/google-services.json`
   - iOS: `ios/Runner/GoogleService-Info.plist`
3. Enable **Google** and **Apple** sign-in providers in the Firebase console
   (Authentication → Sign-in method).
4. Add each family member's email to the backend's `allowed_users` allowlist
   table (per ARCHITECTURE.md §1) — Firebase sign-in alone does not grant API
   access; the backend returns `403 not_allowlisted` for a verified-but-
   unlisted account, and `AuthGate` shows that state (see
   `lib/features/auth/presentation/auth_gate.dart`).
5. Enable Firebase Cloud Messaging if you want push notifications; no
   backend endpoint currently exists to receive the device's FCM token (see
   "Known limitations" below) — `NotificationService.registerForPush()` gets
   the token but has nowhere documented to send it yet.

## Health Connect permission notes (Android)

- Requires Health Connect installed on the device (Android 14+ ships it
  in-box; earlier versions need it from the Play Store).
- Add the Health Connect permissions to `android/app/src/main/AndroidManifest.xml`
  per the [`health` package's setup docs](https://pub.dev/packages/health) —
  this repo does not include a generated Android project, so that manifest
  doesn't exist yet.
- Only the read scopes in ARCHITECTURE.md §7 are requested — no write
  scopes: `STEPS`, `HEART_RATE`, `RESTING_HEART_RATE`, `SLEEP_SESSION`,
  `ACTIVE_CALORIES_BURNED`, `TOTAL_CALORIES_BURNED`, `WEIGHT`, `DISTANCE`,
  `WORKOUT`. See `lib/features/health_connect/health_connect_provider.dart`.
- The `health` package's exact `HealthDataType` enum member names have moved
  across major versions. Run `flutter pub get` and let the analyzer confirm
  each name in `health_connect_provider.dart` resolves against whatever
  version `pubspec.yaml` actually locks — adjust `_typeForMetric`/
  `_metricForType` if one has been renamed.

## Garmin OAuth notes

`GarminProvider` (`lib/features/garmin/garmin_provider.dart`) implements the
OAuth2 PKCE **connection** flow exactly as ARCHITECTURE.md §6 describes: the
app opens a webview to a backend-provided authorization URL, Garmin redirects
to the *backend's* callback (never the app), the backend completes the token
exchange server-side, and finally redirects the webview to this app's custom
URL scheme (`GARMIN_REDIRECT_SCHEME`) with a short-lived session reference.
The app never sees a Garmin client secret, and never generates or holds a
PKCE verifier itself.

**Update:** `GET {API_BASE_URL}/garmin/oauth/authorize-url` and
`GET {API_BASE_URL}/garmin/oauth/callback` are now implemented
(`backend/app/api/garmin.py`, `docs/API_SPEC.md`) — `GarminProvider`'s
contract assumptions above matched what got built. One gap remains:

1. **There is no backend endpoint to fetch actual Garmin health data** onto
   the device. This was investigated (not just deferred) before writing this
   README: Garmin's wellness data is **not** a simple synchronous GET a
   backend could proxy — it's delivered async via a webhook/backfill model
   (see ARCHITECTURE.md §6.1), which needs a small server-side ingestion
   buffer that doesn't exist yet and is a real, separately-scoped Phase 2
   design item, not a quick add. `GarminProvider`'s data methods
   (`getDailySummary`, `getSleep`, `getHeartRate`, `getActivities`,
   `getMetrics`) therefore throw `UnimplementedError` rather than fabricate
   data or call an endpoint shape that wouldn't match how Garmin's API
   actually works. `SyncService` catches this per-provider and records
   `device_connections.status = 'error'` without breaking sync for other
   providers. Only the OAuth *connection status* is meaningfully functional
   today.

Native platform config still needed (not included — no native project
scaffolding in this environment):
- Android: an intent filter for `GARMIN_REDIRECT_SCHEME://` in
  `AndroidManifest.xml`.
- iOS: a `CFBundleURLTypes` entry for the same scheme in `Info.plist`.

## Known limitations & risks (for the next engineer)

- **`flutter pub get`, codegen, `flutter analyze`, and `flutter test` have
  now actually been run** (see the note at the top of this file) and are
  clean. What's *not* verified is anything requiring the Android SDK, Xcode,
  or a device/emulator — that download/toolchain isn't reachable from the
  environment this was built in.
- **`health` package API surface**: `HealthDataType` member names resolved
  correctly against `health: ^10.2.0` per `flutter analyze` — this risk is
  lower than originally flagged, but a real device run is still the final
  check for runtime permission-request behavior (as opposed to compile-time
  API surface).
- **Android native scaffolding exists** (`android/`) but has itself only
  been hand-authored and reviewed, never built with Gradle/the Android SDK —
  see `android/README_ICONS.md` and its manifest comments for specific
  points flagged as lower-confidence (the Health Connect rationale
  intent-filter shape in particular). **No iOS project scaffolding exists at
  all** — deliberately not hand-fabricated (an incorrect `.pbxproj` is worse
  than an honest gap); generate it with `flutter create --platforms=ios .`
  on a machine with Xcode, then add `GoogleService-Info.plist` and the
  `Info.plist` entries noted below.
- **`firebase_options.dart` is not included.** Generate it with
  `flutterfire configure` and wire it into `main.dart`'s
  `Firebase.initializeApp(options: ...)` call (currently unparameterized,
  which only works via native config files).
- **Garmin data fetch is a stub** (see "Garmin OAuth notes" — this is the
  single biggest functional gap, and it's a backend gap, not a mobile one).
- **No background sync scheduling.** Sync + alert evaluation currently run
  once on app foreground (`main.dart`'s `_bootstrap`). ARCHITECTURE.md §10
  explicitly scopes background/server-side evaluation to Phase 2, but even
  foreground periodic re-evaluation (e.g. a `Timer.periodic` while the app
  is open) isn't wired up yet — only "on launch."
- **FCM token registration has no backend endpoint to call.**
  `NotificationService.registerForPush()` works standalone; nothing currently
  uploads the token anywhere, since `API_SPEC.md` doesn't define that
  endpoint.
- **Chat `ChatCard` schema is a Phase 1 assumption.** `API_SPEC.md`'s
  `/chat` example only shows `"cards": []` — the per-card shape
  (`shared/models/chat_models.dart`'s `ChatCard`) is this app's own
  reasonable guess (`type`/`title`/`subtitle`/flat `metrics` map). Tighten
  this once the backend team finalizes a real schema.
- **Conversation summary is a naive placeholder**, not an LLM-generated
  rolling summary — `ChatContextBuilder.buildConversationSummary` just lists
  the last few user turns. This keeps the client cheap and LLM-call-free per
  the architecture's cost goals, but it's much dumber than a "real" summary.
- **No automated widget/integration tests** — only the two pure-Dart unit
  test suites (`test/baseline_calculator_test.dart`,
  `test/alert_rule_evaluator_test.dart`) exist, since those are the only
  logic that's meaningfully testable without a device/emulator in this
  environment.

## Project layout

See `../docs/ARCHITECTURE.md` §5 for the intended layout — `lib/` here
follows it exactly (`core/`, `features/`, `shared/`).
