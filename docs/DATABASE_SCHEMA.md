# On-Device Database Schema (Drift / SQLite)

Source of truth lives on-device (§9). This is the canonical schema; the Drift
table classes in `mobile/lib/core/database/tables/` implement it verbatim.

## users
| column | type | notes |
|---|---|---|
| id | text (uuid) | PK |
| email | text | unique |
| display_name | text | |
| role | text | `admin` \| `member` |
| created_at | datetime | |

## health_metrics
Hybrid EAV table — one row per data point, generic across metric types.

| column | type | notes |
|---|---|---|
| id | text (uuid) | PK |
| user_id | text | FK users.id |
| provider | text | `garmin` \| `health_connect` \| `manual` |
| metric_type | text | see enum below |
| value | real | |
| unit | text | |
| timestamp | datetime | when the measurement occurred |
| metadata_json | text | nullable, provider-specific extras |
| created_at | datetime | ingestion time |

Indexes: `(user_id, metric_type, timestamp)`, `(user_id, timestamp)`.

`metric_type` enum: `heart_rate`, `resting_heart_rate`, `hrv`, `steps`,
`sleep_duration`, `sleep_score`, `calories_active`, `calories_total`,
`distance`, `stress`, `body_battery`, `weight`, `vo2_max`, `blood_oxygen`,
`active_minutes`.

## daily_health_summary
Pre-aggregated per-day rollup for fast chat/chart reads.

| column | type | notes |
|---|---|---|
| id | text (uuid) | PK |
| user_id | text | FK |
| date | date | unique per (user_id, date) |
| steps | integer | nullable |
| calories_active | integer | nullable |
| calories_total | integer | nullable |
| active_minutes | integer | nullable |
| distance_m | real | nullable |
| resting_heart_rate | real | nullable |
| hrv_ms | real | nullable |
| sleep_duration_min | integer | nullable |
| sleep_score | integer | nullable |
| weight_kg | real | nullable |
| updated_at | datetime | |

## sleep_sessions
| column | type | notes |
|---|---|---|
| id | text (uuid) | PK |
| user_id | text | FK |
| provider | text | |
| start_time | datetime | |
| end_time | datetime | |
| duration_min | integer | |
| sleep_score | integer | nullable |
| stages_json | text | nullable, e.g. `{"deep":90,"light":240,"rem":80,"awake":15}` (minutes) |
| resting_heart_rate | real | nullable |
| hrv_ms | real | nullable |

## heart_rate_samples
High-frequency raw samples, kept separate from `health_metrics` to avoid
bloating the generic table with the highest-volume data type.

| column | type | notes |
|---|---|---|
| id | text (uuid) | PK |
| user_id | text | FK |
| timestamp | datetime | |
| bpm | integer | |
| context | text | nullable, e.g. `resting`, `activity` |

Index: `(user_id, timestamp)`.

## activities
| column | type | notes |
|---|---|---|
| id | text (uuid) | PK |
| user_id | text | FK |
| provider | text | |
| activity_type | text | e.g. `run`, `ride`, `strength` |
| start_time | datetime | |
| duration_min | integer | |
| distance_m | real | nullable |
| calories | integer | nullable |
| avg_heart_rate | real | nullable |
| max_heart_rate | real | nullable |
| training_load | real | nullable |
| metadata_json | text | nullable |

## nutrition_entries
Structured nutrition data only — **never** a photo or photo reference (§15).

| column | type | notes |
|---|---|---|
| id | text (uuid) | PK |
| user_id | text | FK |
| logged_at | datetime | |
| meal_name | text | |
| source | text | `photo` \| `text` \| `manual` |
| items_json | text | array of `{name, estimated_grams, calories, protein_g, carbs_g, fat_g}` |
| total_calories | real | |
| protein_g | real | |
| carbs_g | real | |
| fat_g | real | |
| fiber_g | real | nullable |
| confidence | real | nullable, 0.0-1.0, only set when source=photo |
| confirmed | boolean | user has confirmed/edited the AI estimate |

## conversations
| column | type | notes |
|---|---|---|
| id | text (uuid) | PK |
| user_id | text | FK |
| title | text | nullable, derived from first message |
| created_at | datetime | |
| updated_at | datetime | |

## messages
| column | type | notes |
|---|---|---|
| id | text (uuid) | PK |
| conversation_id | text | FK |
| role | text | `user` \| `assistant` |
| content | text | |
| card_json | text | nullable, structured card payload for rendering |
| related_query_json | text | nullable, the context bundle sent for this turn |
| safety_flag | text | nullable, API_SPEC.md `/chat` response `safety_flag` (e.g. `seek_medical_attention`), persisted so a reopened past conversation still renders it distinctly |
| created_at | datetime | |

## alert_rules
| column | type | notes |
|---|---|---|
| id | text (uuid) | PK |
| user_id | text | FK |
| metric_type | text | |
| condition_json | text | see `AlertRule.condition` schema in ARCHITECTURE.md §10 |
| window | text | `daily` \| `rolling` |
| enabled | boolean | |
| created_from_text | text | original NL request, for user reference |
| created_at | datetime | |

## alert_events
| column | type | notes |
|---|---|---|
| id | text (uuid) | PK |
| alert_rule_id | text | FK |
| user_id | text | FK |
| triggered_at | datetime | |
| message | text | notification text shown to user |
| metric_value | real | value that triggered it |
| acknowledged | boolean | |

## device_connections
Non-secret connection status only. Tokens live in `flutter_secure_storage`,
never in this table.

| column | type | notes |
|---|---|---|
| id | text (uuid) | PK |
| user_id | text | FK |
| provider | text | `garmin` \| `health_connect` |
| status | text | `connected` \| `disconnected` \| `error` |
| last_sync_at | datetime | nullable |
| last_error | text | nullable |

## ai_insights
| column | type | notes |
|---|---|---|
| id | text (uuid) | PK |
| user_id | text | FK |
| insight_text | text | |
| category | text | `sleep` \| `activity` \| `recovery` \| `nutrition` \| `trend` |
| dedup_key | text | stable hash so the same insight isn't resurfaced |
| surfaced_at | datetime | |
| dismissed | boolean | |

## sync_state
| column | type | notes |
|---|---|---|
| id | text (uuid) | PK |
| user_id | text | FK |
| provider | text | |
| last_cursor | text | nullable, provider-specific sync token/timestamp |
| last_synced_at | datetime | nullable |

## settings
| column | type | notes |
|---|---|---|
| user_id | text | FK, part of composite PK |
| key | text | part of composite PK |
| value | text | JSON-encoded |
