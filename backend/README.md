# Backend — Family Health AI Assistant

Stateless FastAPI service: an AI proxy (Gemini) plus the ephemeral food-photo
pipeline and the natural-language alert-rule compiler. It does not store
health data — the mobile app is the source of truth (see
`../docs/ARCHITECTURE.md`).

## Local setup

```bash
cd backend
python3 -m venv .venv && source .venv/bin/activate
pip install -r requirements.txt
cp .env.example .env   # then fill in GEMINI_API_KEY, FIREBASE_PROJECT_ID, ALLOWLISTED_EMAILS
```

Firebase Admin SDK needs credentials to verify ID tokens. Locally, download a
service account key from Firebase Console → Project Settings → Service
Accounts, then:

```bash
export GOOGLE_APPLICATION_CREDENTIALS=/path/to/service-account.json
```

On Cloud Run, omit this — the service account attached to the Cloud Run
service is picked up automatically via Application Default Credentials.

## Run

```bash
uvicorn app.main:app --reload --port 8080
```

## Test

```bash
pytest -q
```

18+ tests cover: intent classification, the alert NL→rule compiler, chat
orchestration (including the safety-flag keyword guard and the guarantee
that only pre-computed context is forwarded, never recomputed), the
allowlist gate, and — most importantly — that food photo bytes are never
persisted or leaked anywhere during `/nutrition/photo` handling
(`tests/test_photo_pipeline.py`).

## Deploy (Cloud Run)

```bash
gcloud run deploy family-health-ai-backend \
  --source . \
  --region us-central1 \
  --min-instances 0 \
  --max-instances 3 \
  --set-env-vars "GEMINI_MODEL=gemini-2.5-flash,ALLOWED_ORIGINS=*" \
  --set-secrets "GEMINI_API_KEY=gemini-api-key:latest,FIREBASE_PROJECT_ID=firebase-project-id:latest,ALLOWLISTED_EMAILS=allowlisted-emails:latest"
```

Store secrets in Secret Manager rather than plain `--set-env-vars` for
anything sensitive (`GEMINI_API_KEY`, `GARMIN_CLIENT_SECRET`). A `Dockerfile`
is intentionally omitted — `gcloud run deploy --source` uses Cloud Native
Buildpacks to build directly from `requirements.txt`, which is simpler to
maintain for a project this size (§28).

`min-instances 0` is what keeps this at effectively $0 when idle — see
`../docs/ARCHITECTURE.md` §11 for the full cost breakdown.
