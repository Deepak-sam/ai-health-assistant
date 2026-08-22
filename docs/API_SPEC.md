# Backend API Specification

Base URL: `{BACKEND_URL}/api/v1`
Auth: every endpoint except `/health` requires `Authorization: Bearer <Firebase ID token>`.
The backend verifies the token, extracts the email, and checks it against the
server-side allowlist (`allowed_users` table) before proceeding. A verified-but-
not-allowlisted caller gets `403`.

The backend never receives a user's full health history — the client always
narrows context first (§6/§29). No endpoint accepts a `user_id` from the
request body; the authenticated identity is always derived from the token.

---

## `GET /health`
Liveness probe, no auth. Returns `{"status": "ok"}`.

## `POST /chat`
Orchestrated chat turn.

Request:
```json
{
  "message": "Should I train today?",
  "context": {
    "metrics": {
      "resting_heart_rate": {"today": 58, "baseline_30d": 59.2, "stddev_30d": 2.1},
      "sleep_duration_min": {"today": 438, "baseline_30d": 421.0},
      "hrv_ms": {"today": 46, "baseline_30d": 44.8}
    },
    "recent_activities": [{"type": "run", "days_ago": 1, "duration_min": 40}]
  },
  "conversation_summary": "User has been asking about training readiness this week.",
  "recent_messages": [
    {"role": "user", "content": "How was my sleep?"},
    {"role": "assistant", "content": "You slept 7h18m, close to your baseline."}
  ]
}
```

`context` is built entirely client-side from local Drift data + the
`BaselineCalculator` — the backend performs no additional DB lookups.

Response:
```json
{
  "reply": "Yes. Your recovery indicators look reasonably good — you slept close to your normal amount and your resting heart rate is near baseline. I'd keep today's training moderate rather than maximal.",
  "cards": [],
  "suggested_followups": ["Log today's workout", "Show my recovery trend"],
  "safety_flag": null
}
```

`safety_flag` is set (e.g. `"seek_medical_attention"`) when the orchestrator's
safety layer (§24) detects language suggesting an acute concerning symptom;
the client shows a distinct, non-dismissible style for these replies.

## `POST /nutrition/photo`
`multipart/form-data` with a single `image` field (jpeg/png, capped at 8MB).
The image bytes exist only for the duration of this request — never written
to disk, never logged, never persisted. See `backend/app/nutrition/photo_pipeline.py`.

Response:
```json
{
  "meal_name": "Chicken rice bowl",
  "items": [
    {"name": "grilled chicken", "estimated_grams": 150, "calories": 250, "protein_g": 40, "carbs_g": 0, "fat_g": 8},
    {"name": "rice", "estimated_grams": 200, "calories": 260, "protein_g": 5, "carbs_g": 57, "fat_g": 1}
  ],
  "total_calories": 510,
  "protein_g": 45,
  "carbs_g": 57,
  "fat_g": 9,
  "confidence": 0.72,
  "clarifying_question": null
}
```

If confidence is low, `clarifying_question` is populated (e.g. "Was that
approximately one cup or two cups of rice?") and the client should re-submit
`POST /nutrition/text` with the user's clarification merged in rather than
re-uploading the photo.

## `POST /nutrition/text`
Request: `{"text": "I ate two eggs and toast", "prior_estimate": null}`
Response: same shape as `/nutrition/photo` minus `confidence`/`clarifying_question`
being photo-specific (confidence still returned, typically higher for text).

## `POST /alerts/compile`
Natural language → structured rule (compiled once, never re-invoked at
evaluation time — see ARCHITECTURE.md §10).

Request: `{"text": "Notify me if my resting HR increases more than 10% above my 30-day average for three days"}`

Response:
```json
{
  "rule": {
    "metric_type": "resting_heart_rate",
    "condition": {
      "type": "baseline_relative",
      "operator": ">",
      "baseline_window_days": 30,
      "baseline_multiplier": 1.10,
      "consecutive_count": 3
    },
    "window": "rolling"
  },
  "confirmation_text": "I'll alert you when your resting heart rate is more than 10% above your 30-day average for 3 consecutive days."
}
```

The client shows `confirmation_text` to the user before persisting `rule`
locally into `alert_rules`. No further backend calls happen when the rule
fires — that's evaluated entirely on-device by `AlertRuleEvaluator`.

## `GET /garmin/oauth/authorize-url`
Mints a fresh Garmin authorization URL for the authenticated caller, with a
server-generated PKCE challenge + `state` stored server-side (see
`backend/app/garmin/session_store.py` — an in-memory, Phase-1-scoped store;
see that module's docstring for the tradeoff). Response:
```json
{"authorize_url": "https://connect.garmin.com/oauth2Confirm?..."}
```

## `GET /garmin/oauth/callback`
**Unauthenticated** — Garmin's own redirect target, called from the user's
webview, not the app directly. Exchanges `code`/`state` for tokens
server-side, then 307-redirects the webview to the mobile app's custom URL
scheme: `{scheme}://oauth?status=connected&session_ref=...` on success, or
`{scheme}://oauth?status=error&error=...` on failure. The app never sees a
Garmin token, only the opaque `session_ref`.

Note: there is currently no endpoint that syncs actual Garmin health metrics
to the device — only the OAuth *connection* is functional in Phase 1. See
`docs/ARCHITECTURE.md` §12 and `mobile/README.md` "Garmin OAuth notes".

## Error format
```json
{"error": {"code": "not_allowlisted", "message": "This account is not authorized for this family instance."}}
```

Codes: `unauthorized` (401, bad/missing token), `not_allowlisted` (403),
`invalid_request` (422), `upstream_ai_error` (502), `rate_limited` (429).
