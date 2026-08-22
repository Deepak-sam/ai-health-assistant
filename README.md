# Family Health AI Assistant

A private, chat-first AI health assistant for one family (4-10 members).
Not a public product: no sign-up, no billing, no ads, no data sale. See
[`docs/ARCHITECTURE.md`](docs/ARCHITECTURE.md) for the full system design,
risk analysis, and cost estimates; [`docs/DATABASE_SCHEMA.md`](docs/DATABASE_SCHEMA.md)
and [`docs/API_SPEC.md`](docs/API_SPEC.md) for the on-device schema and
backend API contract.

```
mobile/    Flutter app (iOS + Android) — the primary product, chat-first
backend/   FastAPI service — AI proxy + ephemeral photo pipeline + alert compiler
docs/      Architecture, database schema, API spec
```

## Core privacy guarantee

Food photos are analyzed in memory and immediately discarded — never written
to disk, object storage, or logs, on the device or on the backend. Only the
structured nutrition result (calories, macros) is ever saved. See
`docs/ARCHITECTURE.md` §8/§15 and `backend/tests/test_photo_pipeline.py`,
which asserts this for every code path including errors.

## Development setup

### Prerequisites
- Flutter SDK (stable channel) — https://docs.flutter.dev/get-started/install
- Android Studio (Android SDK + an emulator, or a physical device with
  Health Connect installed — Android 14+ ships it by default, earlier
  versions need it from the Play Store)
- Xcode (for iOS builds/signing) — macOS only
- Python 3.11+ (backend)
- A Firebase project (Auth + Cloud Messaging enabled)
- A Gemini API key — https://aistudio.google.com/apikey
- (Optional, gated by approval) Garmin Connect Developer Program credentials

### 1. Firebase
1. Create a Firebase project.
2. Enable Authentication → Sign-in providers: Apple, Google.
3. Enable Cloud Messaging.
4. Add an iOS app and an Android app in Firebase console; download
   `GoogleService-Info.plist` into `mobile/ios/Runner/` and
   `google-services.json` into `mobile/android/app/`.
5. Create a service account key for the backend (Project Settings → Service
   Accounts) — used locally via `GOOGLE_APPLICATION_CREDENTIALS`; on Cloud
   Run the deployed service's own identity is used instead.
6. Decide the family allowlist (the exact sign-in emails allowed to use the
   app) and set `ALLOWLISTED_EMAILS` in the backend's `.env` (see
   `backend/.env.example`).

### 2. Backend
See [`backend/README.md`](backend/README.md) for full setup/run/test/deploy
instructions. Quick start:
```bash
cd backend
python3 -m venv .venv && source .venv/bin/activate
pip install -r requirements.txt
cp .env.example .env  # fill in GEMINI_API_KEY, FIREBASE_PROJECT_ID, ALLOWLISTED_EMAILS
uvicorn app.main:app --reload --port 8080
```

### 3. Mobile app
See [`mobile/README.md`](mobile/README.md) for full setup/run instructions,
including required `--dart-define` values (API base URL, feature flags) and
Health Connect / Garmin OAuth notes. Quick start once Flutter is installed:
```bash
cd mobile
flutter pub get
flutter pub run build_runner build --delete-conflicting-outputs   # generates Drift code
flutter run --dart-define=API_BASE_URL=http://localhost:8080
```

### 4. Android permissions (Health Connect)
The app requests only the read scopes listed in `docs/ARCHITECTURE.md` §7:
steps, heart rate, resting heart rate, sleep, active/total calories, weight,
distance, workouts. No write permissions are requested.

### 5. iOS permissions
`Info.plist` needs `NSCameraUsageDescription` (meal photos) and
`NSPhotoLibraryUsageDescription` (attaching an existing photo) — see
`mobile/README.md` for the exact entries.

### 6. Garmin (optional, Phase 1 behind a feature flag)
Garmin Health API / Connect Developer Program access requires Garmin's own
approval process, which is outside this repository's control (see
`docs/ARCHITECTURE.md` risk table). Until approved, run with the default
`FakeHealthProvider`/Health Connect only; `GarminProvider` and the backend's
`app/garmin/oauth.py` are ready to enable once credentials exist —
set `GARMIN_CLIENT_ID`/`GARMIN_CLIENT_SECRET`/`GARMIN_REDIRECT_URI` in the
backend `.env` and flip the mobile app's `garminEnabled` `--dart-define`.

## Production deployment

- **Backend**: Cloud Run, `gcloud run deploy --source .` — see
  `backend/README.md`. Keep `min-instances 0` for the scale-to-zero cost
  profile in `docs/ARCHITECTURE.md` §11.
- **Secrets**: store `GEMINI_API_KEY`, `GARMIN_CLIENT_SECRET`, and
  `ALLOWLISTED_EMAILS` in Secret Manager, referenced via `--set-secrets`,
  not plain env vars.
- **Mobile**: standard `flutter build appbundle` / `flutter build ipa`
  release builds, pointed at the deployed `BACKEND_URL` via `--dart-define`.
  Since this is a private family app, prefer TestFlight (internal) and the
  Play Console's internal testing track over public store listings.

## Environment variables

Backend: see `backend/.env.example`. Mobile: see `mobile/README.md`'s
`--dart-define` table. Never commit real values for either — both `.env`
files are gitignored.
