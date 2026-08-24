# Family Health AI Assistant — System Architecture

This document is the pre-build analysis required before implementation: technical
risks, system architecture, integration design, AI orchestration, alert engine
design, cost estimates, and the phased roadmap. Where the product brief was
ambiguous, a decision is made here and called out explicitly (**Decision:**).

## 1. Technical Risks

| Risk | Impact | Mitigation |
|---|---|---|
| Garmin Health API requires business approval (can take weeks, may be denied to an individual) | Blocks Garmin sync entirely | `HealthProvider` abstraction (§7) so the app ships and works via Health Connect / manual entry while Garmin approval is pending. Garmin implemented behind a feature flag. |
| Health Connect is Android-only; no first-party equivalent abstraction on iOS from Google | iOS users get no Google-ecosystem data | iOS relies on Garmin (via Garmin Connect, which does support iOS) and Apple HealthKit as a future provider (same `HealthProvider` interface). Not required for MVP since the brief's two named integrations are Garmin + Google health data. |
| Food photo must never persist — a single missed code path (a stray `save()`, a framework auto-cache, a request log) breaks a hard privacy requirement | Privacy violation, reputational/legal risk in a health app | In-memory only handling end-to-end, `NamedTemporaryFile` + `try/finally` unlink if disk spill is unavoidable, no image bytes in logs, and a dedicated automated test (`test_photo_pipeline.py`) asserting the temp path is gone after every code path including exceptions. |
| Gemini (or any LLM) asked to do arithmetic on health data produces subtly wrong numbers | Wrong medical-adjacent advice, erodes trust | Hard rule (§42): all statistics (averages, stddev, trend, % change, rolling windows) are computed in Dart/Python, never by the LLM. The LLM only receives pre-computed numbers and explains them. |
| Sending full health history to the LLM on every message | Cost blowup, latency, privacy exposure | Intent classification narrows the metric types + date range before context assembly (§6); a context builder caps payload size. |
| Alert rules re-invoking the LLM on every evaluation tick | Unpredictable cost, non-deterministic alerting | LLM only compiles NL → structured rule once, at creation time. All evaluation is deterministic code on a schedule (§17-18). |
| Single-family app with real health data needs "enterprise-grade" auth without enterprise cost/complexity | Over-engineering risk, or under-securing risk | Firebase Auth (Apple/Google sign-in) + a small server-side allowlist table gating API access. No custom password stack. |
| 4–10 users but health data is sensitive (HIPAA-adjacent even if not covered) | Data breach impact is high despite small scale | Local-first storage (data mostly never leaves device except for AI calls), TLS everywhere, `flutter_secure_storage` for tokens, no third-party analytics SDKs. |
| Flutter + Health Connect + Garmin OAuth + native platform channels | Cannot be verified without a device/emulator or real Garmin credentials in this environment | Code is written against documented, stable plugin APIs (`health` package for Health Connect) behind the `HealthProvider` interface so it is swappable/testable via a fake provider; backend logic (the part that *can* run headless) ships with real automated tests. |
| One family member's data leaking to another | Privacy/trust breakdown inside the family itself | Every table is keyed by `user_id`; API requires the caller's own `user_id` context from their verified token; no query path accepts a foreign `user_id` from the client. |

## 2. System Architecture

```
┌─────────────────────────────┐
│         Flutter App          │  iOS + Android, single codebase
│                               │
│  Chat UI (primary screen)    │
│  History / Insights / Settings│
│                               │
│  Local SQLite (Drift)         │◄── source of truth for this device's user
│  - health_metrics             │
│  - conversations/messages     │
│  - nutrition_entries          │
│  - alert_rules / alert_events │
│                               │
│  HealthProvider (interface)   │
│   ├─ HealthConnectProvider    │  Android — Health Connect
│   └─ GarminProvider           │  iOS + Android — Garmin Connect OAuth
│                               │
│  Deterministic engines:       │
│   - BaselineCalculator        │  7/30/90-day avg, stddev, trend
│   - AlertRuleEvaluator        │  runs locally against local data
└──────────────┬────────────────┘
               │ HTTPS (TLS), Firebase ID token
               ▼
┌─────────────────────────────┐
│   Backend (Cloud Run, FastAPI)│  stateless, scales to zero
│                               │
│  /auth        allowlist check │
│  /chat        AI orchestrator │──► Gemini Flash (LLM)
│  /nutrition/photo  ephemeral  │──► Gemini Flash (vision)
│  /alerts/compile   NL→rule    │──► Gemini Flash
│  /notifications/send          │──► FCM
│                               │
│  No health-metric database.   │
│  No stored food photos.       │
└──────────────┬────────────────┘
               │
               ▼
      Firebase (Auth, FCM)   Gemini API   Garmin Health API (server-side OAuth)
```

**Decision:** the backend is intentionally near-stateless. It does not maintain
a canonical copy of every user's health metrics — the device is the source of
truth. The backend only holds: the allowlist, Garmin OAuth tokens (must be
server-side because Garmin's OAuth flow requires a registered redirect + secret),
and short-lived per-request context the client sends it for AI calls. This
keeps cloud cost near zero and satisfies the local-first requirement (§9).

**Decision:** "optional encrypted sync" (§11) is out of scope for Phase 1. It
is listed as a Phase 2 item once device loss / multi-device is a real user need.

## 3. Database Schema (on-device, Drift/SQLite)

See [`DATABASE_SCHEMA.md`](./DATABASE_SCHEMA.md) for full DDL-equivalent Drift
table definitions. Summary:

- `users` — local record of the signed-in family member (id, email, display name, role).
- `health_metrics` — hybrid EAV table: `(id, user_id, provider, metric_type, value, unit, timestamp, metadata_json, created_at)`, indexed on `(user_id, metric_type, timestamp)`.
- `daily_health_summary` — pre-aggregated per-day rollup (steps, calories, sleep, RHR, HRV) for fast chat/chart queries without re-scanning `health_metrics`.
- `sleep_sessions`, `activities` — richer structured records for the two metric types complex enough to need their own shape (start/end, stages, laps).
- `heart_rate_samples` — high-frequency raw HR samples, separate from `health_metrics` to avoid bloating the generic table.
- `nutrition_entries` — structured meal data (never the source photo).
- `conversations`, `messages` — chat history with optional structured `card_json`.
- `alert_rules`, `alert_events` — compiled deterministic rules and their firing history.
- `device_connections` — per-provider OAuth/connection state (tokens live in secure storage, not this table — this table stores non-secret status only).
- `ai_insights` — cached, deduplicated insight strings with a `dismissed`/`surfaced_at` so insights don't repeat noisily.
- `sync_state` — last successful sync cursor per provider, for incremental sync.
- `settings` — key/value app settings (units, notification prefs, alert defaults).

## 4. API Specification

See [`API_SPEC.md`](./API_SPEC.md). Summary of endpoints (all under `/api/v1`,
all require `Authorization: Bearer <Firebase ID token>`):

- `POST /chat` — orchestrated chat turn. Body includes the user message, a
  client-computed `context` bundle (relevant metrics/baselines, not raw DB
  dumps), and rolling conversation summary. Returns structured reply + optional
  cards.
- `POST /nutrition/photo` — multipart image upload, held in memory only,
  returns structured nutrition JSON, never persists the image.
- `POST /nutrition/text` — parses a free-text food log into structured items.
- `POST /alerts/compile` — natural language → structured alert rule (§17-18),
  returns the rule for the client to confirm and store locally.
- `GET /health` — liveness probe (no auth).

## 5. Flutter Application Architecture

```
lib/
  core/
    config/        env-driven config (API base URL, feature flags)
    theme/         ChatGPT-style calm light/dark theme
    routing/        go_router: Chat (default) / History / Insights / Settings
    database/       Drift database + DAOs
    security/       secure token storage wrapper
    networking/     Dio client, auth interceptor
  features/
    auth/           Firebase sign-in (Apple/Google), allowlist gate
    chat/           conversation screen, message bubble, inline cards, input bar
    health/         HealthProvider interface, BaselineCalculator, repositories
    garmin/         GarminProvider (OAuth + REST mapping)
    health_connect/ HealthConnectProvider (via `health` plugin)
    nutrition/      photo capture, text logging, nutrition repository
    insights/       insight generation (deterministic pattern rules) + feed
    alerts/         AlertRuleEvaluator, local rule storage, NL rule creation flow
    settings/       connections, notification prefs, units, privacy info
  shared/
    widgets/        HealthCard, ChartCard, ChatBubble, QuickActionChip
    models/         freezed/plain Dart models mirroring API schemas
    services/       NotificationService (FCM), SyncService
    repositories/   thin façades over Drift DAOs used by features
```

**Decision:** state management uses `Riverpod` (lightweight, testable,
no code-gen requirement beyond what's already used for Drift) rather than
introducing BLoC + Riverpod + Provider simultaneously — one pattern, kept simple
per §31.

## 6. Garmin Integration Architecture

`HealthProvider` abstract interface (Dart):

```dart
abstract class HealthProvider {
  String get providerId;
  Future<bool> isConnected();
  Future<void> connect();
  Future<void> disconnect();
  Future<SyncResult> sync({DateTime? since});
  Future<DailySummary> getDailySummary(DateTime date);
  Future<List<SleepSession>> getSleep(DateRange range);
  Future<List<HeartRateSample>> getHeartRate(DateRange range);
  Future<List<Activity>> getActivities(DateRange range);
  Future<List<HealthMetric>> getMetrics(String metricType, DateRange range);
}
```

`GarminProvider` implements this against the **Garmin Connect Developer
Program** (Health API). Because Garmin's OAuth (1.0a for the older Health API,
OAuth2 PKCE for Connect Developer Program) requires a registered client
secret, the token exchange happens **server-side** (`backend/app/garmin/`):
the app opens a webview to Garmin's consent screen, Garmin redirects to the
backend's callback with a code, the backend exchanges it for tokens and hands
the app a short-lived session reference. The backend stores refresh tokens
encrypted at rest; access tokens are cached in memory only.

**Decision:** until Garmin Health API approval is granted, `GarminProvider`
ships as a working OAuth + REST client behind a `garmin_enabled` feature flag,
with a `FakeGarminProvider` for development/testing. This satisfies "build the
architecture so it can support official or alternative ingestion" (§7) without
blocking the rest of the app on a third-party approval process outside this
session's control.

### 6.1 Garmin data fetch is NOT a synchronous pull — corrected after research

An earlier revision of this document implied `getDailySummary`/`getSleep`/etc.
could be backed by a simple backend proxy that calls a Garmin REST endpoint
and returns JSON in the response. That assumption was checked against
Garmin's actual Health API model before writing the proxy, and it's wrong in
a way worth documenting rather than silently fixing, since it changes a
decision made elsewhere in this doc:

- Garmin's wellness data (dailies, sleeps, epochs/heart-rate, activities) is
  delivered **asynchronously via webhook**, not returned synchronously from a
  GET. An app requests a one-time **backfill** for a bounded historical
  window (commonly capped around 30 days, and typically once per data type),
  and/or receives **Push** callbacks going forward; Garmin's server calls
  *your* registered callback URL with the payload (or, in "Ping" mode, a
  callback URL your server then fetches).
- Each pushed record carries the Garmin user's `userAccessToken`, which is
  the correlation key back to a local user — meaning the backend must
  persist that token (already true here — see `garmin/session_store.py`)
  *and* have somewhere to land data that arrives on a schedule Garmin
  controls, not the device's.
- This means real Garmin data-sync needs a small server-side ingestion
  buffer (webhook receiver → transient storage → an endpoint the device
  polls to drain it) — a **deliberate, narrowly-scoped exception** to §2's
  "no health-metric database" decision, not a contradiction of it: the
  buffer would hold only Garmin's raw push payloads transiently until the
  owning device drains them, not become a second copy of the user's health
  history.

**Decision:** this is real, non-trivial scope — a webhook endpoint, payload
→ `userAccessToken` → local user correlation, a transient store, and a
drain/poll endpoint for the device — and is deferred to Phase 2 rather than
half-built now. Phase 1 ships the OAuth *connection* (§6, functional and
tested) with `GarminProvider`'s data-fetching methods left explicitly
unimplemented (`UnimplementedError`, not fabricated data) until this is
designed properly. See `mobile/README.md` "Garmin OAuth notes" for the
client-side implication.

## 7. Health Connect Integration

Android-only, via the `health` Flutter plugin (community-maintained wrapper
over Health Connect / HealthKit) or a direct platform channel to
`androidx.health.connect.client`. **Decision:** use the `health` package,
since it already targets Health Connect on modern Android and HealthKit on
iOS through one API, meaning `HealthConnectProvider` doubles as the iOS
HealthKit path later with minimal change — but only Health Connect scopes are
requested in Phase 1 (§8: "minimum permissions required").

Requested read scopes (Phase 1): `STEPS`, `HEART_RATE`, `RESTING_HEART_RATE`,
`SLEEP_SESSION`, `ACTIVE_CALORIES_BURNED`, `TOTAL_CALORIES_BURNED`, `WEIGHT`,
`DISTANCE`, `WORKOUT`/`EXERCISE`. No write scopes are requested.

## 8. Ephemeral Image Pipeline (§15)

```
Flutter: camera/gallery → bytes held in memory (Uint8List)
   → multipart POST /api/v1/nutrition/photo (HTTPS)
   → bytes never written to app disk cache (image_picker result used directly)

Backend: request bytes read into memory
   → passed directly to Gemini vision call as inline bytes (no disk write)
   → Gemini returns nutrition JSON
   → structured JSON returned to client
   → request-scoped bytes go out of scope; Python GC reclaims immediately
   → nothing written to logs, nothing written to object storage, no image_url ever exists
```

If a future provider SDK forces a temp file, it is created via
`tempfile.NamedTemporaryFile` inside a `try/finally` that unlinks it
unconditionally, verified in `backend/tests/test_photo_pipeline.py`.

## 9. AI Orchestration

```
User message + client context bundle
        │
        ▼
Intent classification (single cheap Gemini Flash call, or keyword/regex
fast-path for common intents like "how did I sleep" to skip an LLM call
entirely — Decision: keyword fast-path implemented first since it's free
and covers the majority of the example queries in §1)
        │
        ▼
Context retrieval — the CLIENT already narrowed this before the request
(only metric types + date range relevant to the intent are ever sent)
        │
        ▼
Deterministic computation (baselines, deltas, trend) — done in Dart before
the request is sent, so the backend never computes health statistics either
        │
        ▼
Specialist prompt selection (sleep / recovery / fitness / nutrition /
lifestyle system prompt, chosen by intent) — internal only, never exposed
as a separate persona to the user
        │
        ▼
Single Gemini Flash generation call with: system prompt (specialist) +
compact structured context + short rolling conversation summary
        │
        ▼
Structured response: { reply_text, cards: [...], suggested_followups: [...] }
```

**Decision:** model — `gemini-flash-latest`-class model (currently
`gemini-2.5-flash`), configurable via `GEMINI_MODEL` env var so it can be
bumped without a redeploy. A `GEMINI_MODEL_STRONG` env var is reserved for the
rare case (e.g. long-range multi-month correlation analysis) that needs a
stronger model — not used by default.

## 10. Alert Engine Architecture

Two-phase, matching §17-18 exactly:

1. **Compile (LLM, once):** `POST /alerts/compile` takes the user's natural
   language and returns a structured rule matching the `AlertRule` schema
   (metric, operator, threshold OR baseline-relative condition, window,
   consecutive-day count). The backend shows the compiled rule back to the
   user for confirmation before the client persists it locally.
2. **Evaluate (deterministic, always):** `AlertRuleEvaluator` (Dart, runs
   on-device against local `health_metrics`/`daily_health_summary`) — no LLM
   call. Runs on sync completion and on a periodic local timer/WorkManager job.
   A firing rule creates an `alert_events` row and triggers a local
   notification; if the app is backgrounded, a lightweight Cloud Run
   scheduled job (Cloud Scheduler → Cloud Run) can perform the same
   evaluation server-side against a minimal synced summary, for alerts that
   must fire even when the app isn't open — **Decision:** Phase 1 ships
   on-device evaluation only (works while app is installed and has synced
   recently); the server-side scheduled fallback is a Phase 2 item, since it
   requires deciding how much summary data to mirror server-side without
   violating the local-first/minimal-cloud-data principle.

Rule schema (shared shape, Dart + Python):

```json
{
  "id": "uuid",
  "user_id": "uuid",
  "metric_type": "resting_heart_rate",
  "condition": {
    "type": "threshold | baseline_relative | consecutive_day",
    "operator": ">|<|>=|<=",
    "threshold": 90.0,
    "baseline_window_days": 30,
    "baseline_multiplier": 1.10,
    "consecutive_count": 3
  },
  "window": "daily",
  "enabled": true,
  "created_from_text": "tell me if my resting heart rate goes above 90"
}
```

## 11. Cost Estimate

Assumptions: Cloud Run min-instances=0 (scale to zero), Gemini Flash pricing,
Firebase Auth/FCM free tier, no server-side health data storage.

| Users | Chat msgs/day/user | Photo analyses/day/user | Est. monthly Gemini cost | Est. Cloud Run cost | Est. Firebase cost | **Total/mo** |
|---|---|---|---|---|---|---|
| 4 | 10 | 2 | ~$1–2 | ~$0 (free tier covers low req/s, scale-to-zero) | $0 (free tier) | **< $3** |
| 6 | 10 | 2 | ~$2–3 | ~$0–1 | $0 | **< $5** |
| 10 | 15 | 3 | ~$4–6 | ~$1–2 | $0 | **< $10** |

This meets the §28 target of under $10/month at 10 users. Gemini Flash input
is priced per-token at a fraction of a cent per request when context is kept
compact (§6/§29), and photo analysis (vision input) is the single largest
per-request cost driver, which is why context minimization and caching matter.

**Things that could increase recurring cost** (§13):
- Sending full conversation history or full health tables to the LLM instead of narrowed context (violates §6/§29 — guarded against in the orchestrator by construction).
- Cloud Run min-instances > 0 (always-on) instead of scale-to-zero.
- Adding a managed vector DB, Redis, or always-on job queue "just in case" (explicitly disallowed by §28).
- Garmin/Health Connect sync polling too frequently instead of on app-open/background-sync intervals.
- Firebase Storage usage for photos (explicitly disallowed by §15/§25 — architecturally impossible since the image never reaches a storage bucket).
- Verbose Cloud Run logging of request bodies (also a privacy risk for health/photo data — logging middleware explicitly excludes bodies).

## 12. Implementation Roadmap

Matches §35-37, scoped to what a single build session can produce as real,
running code (backend fully testable in this environment; Flutter code is
written to compile against stable, documented plugin APIs but cannot be
compiled/run here since no Flutter SDK is installed — noted explicitly so
this isn't overstated as "verified").

**Phase 1 (this build):**
1. Project structure (`mobile/`, `backend/`, `docs/`).
2. Backend: config, auth allowlist, Gemini client, chat orchestrator with
   keyword-fast-path + specialist prompts, ephemeral nutrition photo pipeline,
   nutrition text parsing, alert NL-compile endpoint, tests.
3. Mobile: Drift schema (§3), HealthProvider abstraction + fake/HealthConnect/Garmin
   implementations, BaselineCalculator, AlertRuleEvaluator, chat UI (default
   screen) with inline cards, bottom nav (Chat/History/Insights/Settings),
   nutrition text + photo logging flow, basic charts, settings screen,
   Firebase Auth scaffold + allowlist gate, FCM registration scaffold.
4. Docs: this architecture doc, DB schema, API spec, setup instructions, `.env.example`.

**Phase 2 (future):** advanced correlations/recovery scoring, voice
conversation, meal history browsing, nutrition targets, weekly reports,
server-side alert fallback, **Garmin webhook + backfill data-sync (§6.1 —
the actual wearable data pull, beyond OAuth connection)**, additional
wearables (HealthKit, Oura, Whoop), optional encrypted sync, web client.
